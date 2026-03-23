`timescale 1ns / 1ps

`include "constants.vh"

module Top_Student (
    input basys_clk,
    input btnC, btnL, btnR, btnU, btnD, UART_RX,
    input [15:0] sw,
    output [7:0] JC,
    output UART_TX,
    output reg [15:0] led,
    output [7:0] seg,
    output [3:0] an
);
    // =========================================================
    // COMMUNICATION
    // =========================================================
    wire busy_tx, busy_rx, received, tx_en_code, tx_en_game, player;
    wire [2:0] pair_state;

    reg [`DATA_BITS-1:0] data_tx = 0;
    wire [`CODE_BITS-1:0] data_tx_code;
    wire [`GAME_BITS-1:0] data_tx_game;
    wire [`DATA_BITS-1:0] data_rx;
    wire [`CODE_BITS-1:0] data_rx_code = data_rx[`CODE_BITS-1:0];
    wire [`GAME_BITS-1:0] data_rx_game = data_rx[`DATA_BITS-1:`CODE_BITS];
    wire tx_en = tx_en_code | tx_en_game;

    uart_tx tx_inst (.clk(basys_clk), .rst(0), .tx_en(tx_en), .data(data_tx), .tx(UART_TX), .busy(busy_tx));

    uart_rx rx_inst (.clk(basys_clk), .rst(0), .rx(UART_RX), .data(data_rx), .busy(busy_rx), .valid(received));

    pairing_fsm pair_inst (.clk(basys_clk), .received(received), .busy_tx(busy_tx), .btn_accept(btnU), .btn_cancel(btnD), .btn_pair_one(btnL), .btn_pair_two(btnR),
                           .data_rx_code(data_rx_code), .tx_en(tx_en_code), .data_tx_code(data_tx_code), .state(pair_state), .player(player));

    package_game_data game_inst (.clk(basys_clk), .btnL(btnL), .btnR(btnR), .btnC(btnC), .btnU(btnU), .btnD(btnD), .sw(sw[7:0]),
                                 .tx_en(tx_en_game), .player(player), .data_tx_game(data_tx_game));

    // =========================================================
    // OLED
    // =========================================================
    wire clk_6p25m;
    wire frame_begin, sending_pixels, sample_pixel;
    wire [12:0] pixel_index;

    reg [15:0] oled_data = 16'h0000;
    wire [15:0] oled_data_pair;
    reg [15:0] oled_data_single = 16'h0000;
    reg [15:0] oled_data_multi  = 16'hFFFF;

    wire [6:0] x = pixel_index % 96;
    wire [5:0] y = pixel_index / 96;

    variable_clock #(.CLOCK_SPEED(`CLOCK_SPEED), .OUT_SPEED(6_250_000)) clk_6p25m_inst (.clk(basys_clk), .clk_out(clk_6p25m));

    pairing_oled pair_oled_inst (.clk(basys_clk), .pair_state(pair_state), .x(x), .y(y), .oled_data(oled_data_pair));

    Oled_Display oled1 (
        .clk(clk_6p25m),
        .reset(1'b0),
        .frame_begin(frame_begin),
        .sending_pixels(sending_pixels),
        .sample_pixel(sample_pixel),
        .pixel_index(pixel_index),
        .pixel_data(oled_data),
        .cs(JC[0]),
        .sdin(JC[1]),
        .sclk(JC[3]),
        .d_cn(JC[4]),
        .resn(JC[5]),
        .vccen(JC[6]),
        .pmoden(JC[7])
    );

    parameter DISPLAY_TIME = 3 * `CLOCK_SPEED;
    reg [$clog2(DISPLAY_TIME):0] display_counter = 0;
    reg display_text = 0;

    // =========================================================
    // MAP STORAGE
    // =========================================================
    parameter WALL_COLOR = `OLED_WHITE;

    reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];
//    reg [15:0] pixel_map [0:`PIX_MAP_WIDTH-1][0:`PIX_MAP_HEIGHT-1];
    reg [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat;

    integer tx, ty, dx, dy, i;

    initial begin
//        for (tx = 0; tx < `PIX_MAP_WIDTH; tx = tx + 1) begin
//            for (ty = 0; ty < `PIX_MAP_HEIGHT; ty = ty + 1) begin
//                pixel_map[tx][ty] = `OLED_BLACK;
//            end
//        end

        for (tx = 0; tx < `TILE_MAP_WIDTH; tx = tx + 1) begin
            for (ty = 0; ty < `TILE_MAP_HEIGHT; ty = ty + 1) begin
                if ((tx % 2 == 1) && (ty % 2 == 1))
                    tile_map[tx][ty] = `MAP_WALL;
                else
                    tile_map[tx][ty] = `MAP_EMPTY;
            end
        end

        // Test blocks
        tile_map[1][0]  = `MAP_BLOCK;
        tile_map[1][2]  = `MAP_BLOCK;
        tile_map[3][2]  = `MAP_BLOCK;
        tile_map[5][6]  = `MAP_BLOCK;
        tile_map[8][4]  = `MAP_BLOCK;
        tile_map[12][0] = `MAP_BLOCK;
        tile_map[14][7] = `MAP_BLOCK;

        // Spawn zone open
        tile_map[0][0] = `MAP_EMPTY;
        tile_map[0][1] = `MAP_EMPTY;

        // Example powerup
        tile_map[2][6] = `MAP_POWERUP;

//        for (tx = 0; tx < `PIX_MAP_WIDTH; tx = tx + 1) begin
//            for (ty = 0; ty < `PIX_MAP_HEIGHT; ty = ty + 1) begin
//                if (tx < `MIN_PIX_X || tx > `MAX_PIX_X || ty < `MIN_PIX_Y || ty > `MAX_PIX_Y)
//                    pixel_map[tx][ty] = WALL_COLOR;
//            end
//        end
    end

    // Flatten tile map for submodules
    integer fx, fy;
    always @(*) begin
        for (fy = 0; fy < `TILE_MAP_HEIGHT; fy = fy + 1) begin
            for (fx = 0; fx < `TILE_MAP_WIDTH; fx = fx + 1) begin
                tile_map_flat[(fy*`TILE_MAP_WIDTH + fx)*3 +: 3] = tile_map[fx][fy];
            end
        end
    end

    // =========================================================
    // TILE -> PIXEL BACKGROUND RENDERING
    // =========================================================
    function [15:0] expand_tile;
        input [2:0] tile_type;
        input [2:0] local_x;
        input [2:0] local_y;
    begin
        expand_tile = `OLED_BLACK;
        case (tile_type)
            `MAP_EMPTY:   expand_tile = `OLED_BLACK;
            `MAP_WALL:    expand_tile = WALL_COLOR;
            `MAP_BLOCK:   expand_tile = `OLED_GREY;
            `MAP_BOMB:    expand_tile = (local_x >= 2 && local_x <= 3 && local_y >= 2 && local_y <= 3) ? `OLED_ORANGE : `OLED_BLACK; // same as the circle
            `MAP_POWERUP: expand_tile = `OLED_MAGENTA;
            default:      expand_tile = `OLED_BLACK;
        endcase
    end
    endfunction

    /*always @(*) begin
        for (tx = 0; tx < `TILE_MAP_WIDTH; tx = tx + 1) begin
            for (ty = 0; ty < `TILE_MAP_HEIGHT; ty = ty + 1) begin
                for (dx = 0; dx < `TILE_SIZE; dx = dx + 1) begin
                    for (dy = 0; dy < `TILE_SIZE; dy = dy + 1) begin
                        pixel_map[`MIN_PIX_X + (`TILE_SIZE*tx) + dx][`MIN_PIX_Y + (`TILE_SIZE*ty) + dy]
                            = expand_tile(tile_map[tx][ty], dx[2:0], dy[2:0]);
                    end
                end
            end
        end
    end*/

    // =========================================================
    // PLAYER CONTROLLER
    // =========================================================
    wire [6:0] player_x;
    wire [5:0] player_y;
    wire [3:0] player_tx;
    wire [3:0] player_ty;
    wire player_dead;

    // =========================================================
    // BOMB CONTROLLER
    // =========================================================
    wire bomb_active;
    wire bomb_passable;
    wire [3:0] bomb_tx;
    wire [3:0] bomb_ty;
    wire bomb_red;

    wire explosion_active;
    wire [3:0] explosion_stage;
    wire [3:0] explode_up_len;
    wire [3:0] explode_down_len;
    wire [3:0] explode_left_len;
    wire [3:0] explode_right_len;

    wire player_hit;

    wire place_bomb_req;
    wire [3:0] place_bomb_tx;
    wire [3:0] place_bomb_ty;

    wire clear_bomb_req;
    wire [3:0] clear_bomb_tx;
    wire [3:0] clear_bomb_ty;

    wire destroy_up_req, destroy_down_req, destroy_left_req, destroy_right_req;
    wire [3:0] destroy_up_tx, destroy_up_ty;
    wire [3:0] destroy_down_tx, destroy_down_ty;
    wire [3:0] destroy_left_tx, destroy_left_ty;
    wire [3:0] destroy_right_tx, destroy_right_ty;

    player_controller player_ctrl_inst (
        .clk(basys_clk),
        .btnL(btnL),
        .btnR(btnR),
        .btnU(btnU),
        .btnD(btnD),
        .tile_map_flat(tile_map_flat),
        .bomb_active(bomb_active),
        .bomb_passable(bomb_passable),
        .bomb_tx(bomb_tx),
        .bomb_ty(bomb_ty),
        .player_hit(player_hit),
        .player_speed_multiplier(sw[1:0]),
        .player_x(player_x),
        .player_y(player_y),
        .player_tx(player_tx),
        .player_ty(player_ty),
        .player_dead(player_dead)
    );

    bomb_controller bomb_ctrl_inst (
        .clk(basys_clk),
        .trigger(btnC),
        .tile_map_flat(tile_map_flat),
        .player_x(player_x),
        .player_y(player_y),
        .player_tx(player_tx),
        .player_ty(player_ty),
        .player_dead(player_dead),
        .bomb_active(bomb_active),
        .bomb_passable(bomb_passable),
        .bomb_tx(bomb_tx),
        .bomb_ty(bomb_ty),
        .bomb_red(bomb_red),
        .explosion_active(explosion_active),
        .explosion_stage(explosion_stage),
        .explode_up_len(explode_up_len),
        .explode_down_len(explode_down_len),
        .explode_left_len(explode_left_len),
        .explode_right_len(explode_right_len),
        .player_hit(player_hit),
        .place_bomb_req(place_bomb_req),
        .place_bomb_tx(place_bomb_tx),
        .place_bomb_ty(place_bomb_ty),
        .clear_bomb_req(clear_bomb_req),
        .clear_bomb_tx(clear_bomb_tx),
        .clear_bomb_ty(clear_bomb_ty),
        .destroy_up_req(destroy_up_req),
        .destroy_up_tx(destroy_up_tx),
        .destroy_up_ty(destroy_up_ty),
        .destroy_down_req(destroy_down_req),
        .destroy_down_tx(destroy_down_tx),
        .destroy_down_ty(destroy_down_ty),
        .destroy_left_req(destroy_left_req),
        .destroy_left_tx(destroy_left_tx),
        .destroy_left_ty(destroy_left_ty),
        .destroy_right_req(destroy_right_req),
        .destroy_right_tx(destroy_right_tx),
        .destroy_right_ty(destroy_right_ty)
    );

    // =========================================================
    // MAP UPDATE REQUESTS FROM BOMB CONTROLLER
    // =========================================================
    always @(posedge basys_clk) begin
        if (place_bomb_req)
            tile_map[place_bomb_tx][place_bomb_ty] <= `MAP_BOMB;

        if (clear_bomb_req)
            tile_map[clear_bomb_tx][clear_bomb_ty] <= `MAP_EMPTY;

        if (destroy_up_req && tile_map[destroy_up_tx][destroy_up_ty] == `MAP_BLOCK)
            tile_map[destroy_up_tx][destroy_up_ty] <= `MAP_EMPTY;

        if (destroy_down_req && tile_map[destroy_down_tx][destroy_down_ty] == `MAP_BLOCK)
            tile_map[destroy_down_tx][destroy_down_ty] <= `MAP_EMPTY;

        if (destroy_left_req && tile_map[destroy_left_tx][destroy_left_ty] == `MAP_BLOCK)
            tile_map[destroy_left_tx][destroy_left_ty] <= `MAP_EMPTY;

        if (destroy_right_req && tile_map[destroy_right_tx][destroy_right_ty] == `MAP_BLOCK)
            tile_map[destroy_right_tx][destroy_right_ty] <= `MAP_EMPTY;
    end

    // =========================================================
    // RENDER HELPERS
    // =========================================================
    /*function pixel_in_tile;
        input [6:0] px;
        input [5:0] py;
        input [3:0] tx_in;
        input [3:0] ty_in;
        reg [6:0] tile_left;
        reg [5:0] tile_top;
    begin
        tile_left = `MIN_PIX_X + tx_in * `TILE_SIZE;
        tile_top  = `MIN_PIX_Y + ty_in * `TILE_SIZE;
        pixel_in_tile =
            (px >= tile_left) && (px < tile_left + `TILE_SIZE) &&
            (py >= tile_top)  && (py < tile_top + `TILE_SIZE);
    end
    endfunction*/

    wire player_region = (x >= player_x) && (x < player_x + `PLAYER_WIDTH) && (y >= player_y) && (y < player_y + `PLAYER_WIDTH);
        
    // =========================================================
    // COMPUTER CONTROLLER
    // =========================================================
    
    wire [6:0] computer_x;
    wire [5:0] computer_y;
    wire computer_region = (x >= computer_x) && (x < computer_x + `PLAYER_WIDTH) && (y >= computer_y) && (y < computer_y + `PLAYER_WIDTH);
    
    computer_controller comp_inst (.clk(basys_clk),
                                   .player_tx(player_tx), 
                                   .player_ty(player_ty), 
                                   // .bomb_active(bomb_active),
                                   // .explosion_active(explosion_active),
                                   .tile_map_flat(tile_map_flat),
                                   .computer_x(computer_x),
                                   .computer_y(computer_y));

    // =========================================================
    // SINGLE PLAYER OLED OVERLAY
    // =========================================================
    
    wire [3:0] tile_x_of_pixel = (x >= `MIN_PIX_X && x <= `MAX_PIX_X) ? ((x - `MIN_PIX_X) * 7'd43) >> 8 : 4'hF; // replace divider with reciprocal multiply + shift
    wire [3:0] tile_y_of_pixel = (y >= `MIN_PIX_Y && y <= `MAX_PIX_Y) ? ((y - `MIN_PIX_Y) * 7'd43) >> 8 : 4'hF;
    wire [2:0] local_x = (tile_x_of_pixel == 4'hF) ? 0 : (x - `MIN_PIX_X - tile_x_of_pixel * 6);
    wire [2:0] local_y = (tile_y_of_pixel == 4'hF) ? 0 : (y - `MIN_PIX_Y - tile_y_of_pixel * 6);
    
    always @(*) begin
        if (tile_x_of_pixel == 4'hF || tile_y_of_pixel == 4'hF) oled_data_single = `OLED_ORANGE;
        else oled_data_single = expand_tile(tile_map[tile_x_of_pixel][tile_y_of_pixel], local_x, local_y);

        // bomb
        if (bomb_active) begin
            if (tile_x_of_pixel == bomb_tx && tile_y_of_pixel == bomb_ty) 
//            if (pixel_in_tile(x, y, bomb_tx, bomb_ty))
                oled_data_single = bomb_red ? `OLED_RED : `OLED_ORANGE;
        end

        // explosion
        if (explosion_active) begin
            if (tile_x_of_pixel == bomb_tx && tile_y_of_pixel == bomb_ty) 
//            if (pixel_in_tile(x, y, bomb_tx, bomb_ty))
                oled_data_single = `OLED_YELLOW;

            if ((explosion_stage <= explode_up_len) &&
                tile_x_of_pixel == bomb_tx && tile_y_of_pixel == bomb_ty-explosion_stage)
//                pixel_in_tile(x, y, bomb_tx, bomb_ty - explosion_stage))
                oled_data_single = `OLED_YELLOW;

            if ((explosion_stage <= explode_down_len) &&
                tile_x_of_pixel == bomb_tx && tile_y_of_pixel == bomb_ty+explosion_stage)
//                pixel_in_tile(x, y, bomb_tx, bomb_ty + explosion_stage))
                oled_data_single = `OLED_YELLOW;

            if ((explosion_stage <= explode_left_len) &&
                tile_x_of_pixel == bomb_tx-explosion_stage && tile_y_of_pixel == bomb_ty)
//                pixel_in_tile(x, y, bomb_tx - explosion_stage, bomb_ty))
                oled_data_single = `OLED_YELLOW;

            if ((explosion_stage <= explode_right_len) &&
                tile_x_of_pixel == bomb_tx+explosion_stage && tile_y_of_pixel == bomb_ty)
//                pixel_in_tile(x, y, bomb_tx + explosion_stage, bomb_ty))
                oled_data_single = `OLED_YELLOW;
        end
        

        // player
        if (player_region) oled_data_single = player_dead ? `OLED_GREEN : `OLED_BLUE;
        if (computer_region) oled_data_single = `OLED_MAGENTA;
        
        // draw walls
        if (x < `MIN_PIX_X || x > `MAX_PIX_X || y < `MIN_PIX_Y || y > `MAX_PIX_Y) oled_data_single = WALL_COLOR;
    end

    // =========================================================
    // MAIN LOOP
    // =========================================================
    always @(posedge basys_clk) begin
        data_tx <= {data_tx_game, data_tx_code};

        case (pair_state)
            `SINGLE: begin
                display_counter <= 0;
                display_text <= 0;
                oled_data <= oled_data_single;
//                led <= 8'b0;
            end

            `PAIRED: begin
                if (display_counter >= DISPLAY_TIME - 1) begin
                    display_text <= 0;
                end
                else begin
                    display_counter <= display_counter + 1;
                    display_text <= 1;
                end

                if (display_text)
                    oled_data <= oled_data_pair;
                else
                    oled_data <= oled_data_multi;

//                led <= data_rx_game;
            end

            default: begin
                oled_data <= oled_data_pair;
//                led <= 8'b0;
            end
        endcase
    end

    // =========================================================
    // DEBUGGING
    // =========================================================
    reg [7:0] seg_player, seg_state;

    always @(*) begin
        case (player)
            1'b0: seg_player = 8'b11111001; // 1
            1'b1: seg_player = 8'b10100100; // 2
            default: seg_player = 8'b11111111;
        endcase

        case (pair_state)
            `PAIRED: seg_state = 8'b11111001; // 1
            default: seg_state = 8'b11000000; // 0
        endcase
    end

    seven_segment seg_inst (
        .clk(basys_clk),
        .seg0(seg_state),
        .seg1(8'b11111111),
        .seg2(8'b10001100),
        .seg3(seg_player),
        .seg(seg),
        .an(an)
    );

endmodule
