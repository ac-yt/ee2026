`timescale 1ns / 1ps

`include "constants.vh"

module Top_Student (
    input basys_clk,
    input btnC, btnL, btnR, btnU, btnD, UART_RX,
    input [7:0] sw,
    output [7:0] JC,
    output UART_TX,
    output [13:0] led,
    output reg [15:14] led2,
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

    uart_tx tx_inst (
        .clk(basys_clk),
        .rst(0),
        .tx_en(tx_en),
        .data(data_tx),
        .tx(UART_TX),
        .busy(busy_tx)
    );

    uart_rx rx_inst (
        .clk(basys_clk),
        .rst(0),
        .rx(UART_RX),
        .data(data_rx),
        .busy(busy_rx),
        .valid(received)
    );

    pairing_fsm pair_inst (
        .clk(basys_clk),
        .received(received),
        .busy_tx(busy_tx),
        .btn_accept(btnU),
        .btn_cancel(btnD),
        .btn_pair_one(btnL),
        .btn_pair_two(btnR),
        .data_rx_code(data_rx_code),
        .tx_en(tx_en_code),
        .data_tx_code(data_tx_code),
        .state(pair_state),
        .player(player)
    );

    package_game_data game_inst (
        .clk(basys_clk),
        .btnL(btnL),
        .btnR(btnR),
        .btnC(btnC),
        .btnU(btnU),
        .btnD(btnD),
        .sw(sw),
        .tx_en(tx_en_game),
        .player(player),
        .data_tx_game(data_tx_game)
    );

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

    variable_clock #(
        .CLOCK_SPEED(`CLOCK_SPEED),
        .OUT_SPEED(6_250_000)
    ) clk_6p25m_inst (
        .clk(basys_clk),
        .clk_out(clk_6p25m)
    );

    pairing_oled pair_oled_inst (
        .clk(basys_clk),
        .pair_state(pair_state),
        .x(x),
        .y(y),
        .oled_data(oled_data_pair)
    );

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
    reg [15:0] pixel_map [0:`PIX_MAP_WIDTH-1][0:`PIX_MAP_HEIGHT-1];
    reg [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat;

    integer tx, ty, dx, dy, i;

    initial begin
        for (tx = 0; tx < `PIX_MAP_WIDTH; tx = tx + 1) begin
            for (ty = 0; ty < `PIX_MAP_HEIGHT; ty = ty + 1) begin
                pixel_map[tx][ty] = `OLED_BLACK;
            end
        end

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

        for (tx = 0; tx < `PIX_MAP_WIDTH; tx = tx + 1) begin
            for (ty = 0; ty < `PIX_MAP_HEIGHT; ty = ty + 1) begin
                if (tx < `MIN_PIX_X || tx > `MAX_PIX_X || ty < `MIN_PIX_Y || ty > `MAX_PIX_Y)
                    pixel_map[tx][ty] = WALL_COLOR;
            end
        end
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
        integer cx, cy;
    begin
        expand_tile = `OLED_BLACK;
        cx = local_x - 3;
        cy = local_y - 3;

        case (tile_type)
            `MAP_EMPTY:   expand_tile = `OLED_BLACK;
            `MAP_WALL:    expand_tile = WALL_COLOR;
            `MAP_BLOCK:   expand_tile = `OLED_GREY;
            `MAP_BOMB:    expand_tile = ((cx*cx + cy*cy) <= 9) ? `OLED_ORANGE : `OLED_BLACK;
            `MAP_POWERUP: expand_tile = `OLED_MAGENTA;
            default:      expand_tile = `OLED_BLACK;
        endcase
    end
    endfunction

    always @(*) begin
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
    end

    // =========================================================
    // PLAYER CONTROLLER
    // =========================================================
    wire [6:0] player_x;
    wire [5:0] player_y;
    wire [3:0] player_center_tx;
    wire [3:0] player_center_ty;
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
        .player_x(player_x),
        .player_y(player_y),
        .player_center_tx(player_center_tx),
        .player_center_ty(player_center_ty),
        .player_dead(player_dead)
    );

    bomb_controller bomb_ctrl_inst (
        .clk(basys_clk),
        .btnC(btnC),
        .tile_map_flat(tile_map_flat),
        .player_x(player_x),
        .player_y(player_y),
        .player_center_tx(player_center_tx),
        .player_center_ty(player_center_ty),
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
    function pixel_in_tile;
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
    endfunction

    wire player_region;
    assign player_region =
        (x >= player_x) && (x < player_x + `PLAYER_WIDTH) &&
        (y >= player_y) && (y < player_y + `PLAYER_WIDTH);
        
    // =========================================================
    // PATH PLANNING FOR SINGLE PLAYER
    // =========================================================

    reg update_path = 0;
    reg updated = 0;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_x;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_y;
    reg [3:0] path_x [0:`MAX_PATH_LEN];
    reg [3:0] path_y [0:`MAX_PATH_LEN];
    wire [6:0] path_len;
    wire path_valid;
    reg path_saved = 1;
    wire [10:0] path_cost;
    reg [4*`MAX_PATH_LEN-1:0] path_flat_y_loc, path_flat_x_loc;
    reg [7:0] path_index = 0;
    reg [6:0] path_len_loc = 0;
    reg [10:0] path_cost_loc;

    a_star #(.CLOCK_SPEED(`CLOCK_SPEED)) a_star_inst
        (.clk(basys_clk), .update(update_path),
         .start_x(0), .start_y(0), .goal_x(5), .goal_y(5),
         .tile_map_flat({(`TILE_MAP_SIZE*3){3'b000}}),
         .path_flat_x(path_flat_x), .path_flat_y(path_flat_y),
         .path_len(path_len), .path_valid(path_valid), .path_cost(path_cost));
     
    always @ (posedge basys_clk) begin
        if (path_valid) begin
            path_flat_y_loc <= path_flat_y;
            path_flat_x_loc <= path_flat_x;
            path_len_loc <= path_len;
            path_cost_loc <= path_cost;
            
            path_saved <= 0;
            path_index <= 0;
            led2[14] <= 1;
        end
    end

    always @ (posedge basys_clk) begin
        if (!updated) begin
            update_path <= 1;
            updated <= 1;
        end else update_path <= 0;

//        if (path_valid) begin
//            path_saved <= 0;
//            path_index <= 0;
//            led2[14] <= 1;
//        end

        if (!path_saved) begin
            led2[15] <= 1;
            if (path_index < path_len_loc) begin
                path_x[path_index] <= path_flat_x_loc[path_index*4 +: 4];
                path_y[path_index] <= path_flat_y_loc[path_index*4 +: 4];
                path_index <= path_index + 1;
            end
            else begin
            end
        end
    end
    
    assign led[4:1] = path_x[0];
    assign led[8:5] = path_x[1];
//    assign led[12:9] = path_x[2];

    // =========================================================
    // SINGLE PLAYER OLED OVERLAY
    // =========================================================
    always @(*) begin
        oled_data_single = pixel_map[x][y];

        // bomb
        if (bomb_active) begin
            if (pixel_in_tile(x, y, bomb_tx, bomb_ty))
                oled_data_single = bomb_red ? `OLED_RED : `OLED_ORANGE;
        end

        // explosion
        if (explosion_active) begin
            if (pixel_in_tile(x, y, bomb_tx, bomb_ty))
                oled_data_single = `OLED_YELLOW;

            if ((explosion_stage <= explode_up_len) &&
                pixel_in_tile(x, y, bomb_tx, bomb_ty - explosion_stage))
                oled_data_single = `OLED_YELLOW;

            if ((explosion_stage <= explode_down_len) &&
                pixel_in_tile(x, y, bomb_tx, bomb_ty + explosion_stage))
                oled_data_single = `OLED_YELLOW;

            if ((explosion_stage <= explode_left_len) &&
                pixel_in_tile(x, y, bomb_tx - explosion_stage, bomb_ty))
                oled_data_single = `OLED_YELLOW;

            if ((explosion_stage <= explode_right_len) &&
                pixel_in_tile(x, y, bomb_tx + explosion_stage, bomb_ty))
                oled_data_single = `OLED_YELLOW;
        end

        // path
//        if (path_mask[x/`TILE_SIZE][y/`TILE_SIZE]) oled_data_single = `OLED_MAGENTA;
        
        if (pixel_in_tile(x, y, path_x[0], path_y[0])) oled_data_single = `OLED_CYAN;
        if (pixel_in_tile(x, y, path_x[1], path_y[1])) oled_data_single = `OLED_CYAN;
        if (pixel_in_tile(x, y, path_x[2], path_y[2])) oled_data_single = `OLED_CYAN;
        if (pixel_in_tile(x, y, path_x[3], path_y[3])) oled_data_single = `OLED_CYAN;
        if (pixel_in_tile(x, y, path_x[4], path_y[4])) oled_data_single = `OLED_CYAN;
        if (pixel_in_tile(x, y, path_x[5], path_y[5])) oled_data_single = `OLED_CYAN;
        if (pixel_in_tile(x, y, path_x[6], path_y[6])) oled_data_single = `OLED_CYAN;
        if (pixel_in_tile(x, y, path_x[7], path_y[7])) oled_data_single = `OLED_CYAN;
        
        if (pixel_in_tile(x, y, path_x[path_index], path_y[path_index]))
            oled_data_single = `OLED_RED; // highlight current step

        // player
        if (player_region)
            oled_data_single = player_dead ? `OLED_GREEN : `OLED_BLUE;
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
    reg [7:0] seg_player, seg_state, seg_path, seg_2, seg_1, seg_path2;

    always @(*) begin
//        case (player)
//            1'b0: seg_player = 8'b11111001; // 1
//            1'b1: seg_player = 8'b10100100; // 2
//            default: seg_player = 8'b11111111;
//        endcase

//        case (pair_state)
//            `PAIRED: seg_state = 8'b11111001; // 1
//            default: seg_state = 8'b11000000; // 0
//        endcase
        
        case (path_len)
            0: seg_path = 8'b11000000;
            1: seg_path = 8'b11111001;
            2: seg_path = 8'b10100100;
            3: seg_path = 8'b10110000;
            4: seg_path = 8'b10011001;
            5: seg_path = 8'b10010010;
            6: seg_path = 8'b10000010;
            7: seg_path = 8'b11111000;
            8: seg_path = 8'b10000000;
            9: seg_path = 8'b10011000;
            default: seg_path = 8'b10001000;
        endcase
        
        case (path_len_loc)
                    0: seg_path2 = 8'b11000000;
                    1: seg_path2 = 8'b11111001;
                    2: seg_path2 = 8'b10100100;
                    3: seg_path2 = 8'b10110000;
                    4: seg_path2 = 8'b10011001;
                    5: seg_path2 = 8'b10010010;
                    6: seg_path2 = 8'b10000010;
                    7: seg_path2 = 8'b11111000;
                    8: seg_path2 = 8'b10000000;
                    9: seg_path2 = 8'b10011000;
                    default: seg_path2 = 8'b10001000;
                endcase
        
        case (path_x[2])
            0: seg_2 = 8'b11000000;
            1: seg_2 = 8'b11111001;
            2: seg_2 = 8'b10100100;
            3: seg_2 = 8'b10110000;
            4: seg_2 = 8'b10011001;
            5: seg_2 = 8'b10010010;
            6: seg_2 = 8'b10000010;
            7: seg_2 = 8'b11111000;
            8: seg_2 = 8'b10000000;
            9: seg_2 = 8'b10011000;
            default: seg_2 = 8'b10001000;
        endcase
        
        case (path_x[1])
            0: seg_1 = 8'b11000000;
            1: seg_1 = 8'b11111001;
            2: seg_1 = 8'b10100100;
            3: seg_1 = 8'b10110000;
            4: seg_1 = 8'b10011001;
            5: seg_1 = 8'b10010010;
            6: seg_1 = 8'b10000010;
            7: seg_1 = 8'b11111000;
            8: seg_1 = 8'b10000000;
            9: seg_1 = 8'b10011000;
            default: seg_1 = 8'b10001000;
        endcase
    end

    seven_segment seg_inst (
        .clk(basys_clk),
        .seg0(seg_1),
        .seg1(seg_2),
//        .seg0(seg_state),
//        .seg1(8'b11111111),
        .seg2(seg_path),
        //.seg2(8'b10001100),
        .seg3(seg_path2),
        .seg(seg),
        .an(an)
    );

endmodule

// Wrap your code into a module so we can instantiate it
module top_with_astar (
    input basys_clk, btnC, //rst,
    output [15:0] led
);
    reg update_path = 0;
    reg [1:0] updated = 0;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_x;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_y;
    reg [3:0] path_x [0:`MAX_PATH_LEN];
    reg [3:0] path_y [0:`MAX_PATH_LEN];
    wire [6:0] path_len;
    wire path_valid;
    reg prev_path_valid = 0;
    reg path_saved = 1;
    wire [10:0] path_cost;
    reg [4*`TILE_MAP_SIZE-1:0] path_flat_y_loc, path_flat_x_loc;
    reg [7:0] path_index = 0;
    reg [6:0] path_len_loc = 0;
    reg [10:0] path_cost_loc;
//        reg rst = 1;

    a_star #(.CLOCK_SPEED(`CLOCK_SPEED)) a_star_inst
        (.clk(basys_clk), .update(update_path),// .rst(rst),
         .start_x(4'b0), .start_y(4'b0), .goal_x(4'b1), .goal_y(4'b1),
         .tile_map_flat({(`TILE_MAP_SIZE){3'b000}}),
         .path_flat_x(path_flat_x), .path_flat_y(path_flat_y),
         .path_len(path_len), .path_valid(path_valid), .path_cost(path_cost));

//        reg [1:0] counter = 0;
    
//        always @(posedge basys_clk) begin
//            if (counter < 3) begin
//                rst <= 1;          // keep reset high
//                counter <= counter + 1;
//            end else begin
//                rst <= 0;          // release reset after 3 cycles
//            end
//        end



        always @ (posedge basys_clk) begin
            if (btnC) update_path <= 1;
            else update_path <= 0;
//            if (updated < 3) begin
//                updated <= updated + 1;
//                update_path <= 1;
//            end
//            else update_path <= 0;
        end
        
        always @(posedge basys_clk) begin
//        if (rst) begin
//            update_path   <= 0;
//            updated       <= 0;
//            path_len_loc  <= 0;
//            path_cost_loc <= 0;
//            led           <= 0;
//        end else begin
//            if (!updated) begin
//                update_path <= 1;
//                updated <= 1;
//            end else update_path <= 0;
            
            if (path_valid && !prev_path_valid) begin
                prev_path_valid <= 1;
                path_len_loc   <= path_len;
                path_cost_loc  <= path_cost;
                path_flat_x_loc <= path_flat_x;
                path_flat_y_loc <= path_flat_y;
                path_saved <= 0;
                path_index <= 0;
            end
            
//            path_len_loc <= path_len;
    
    //        if (path_valid) begin
    //            path_saved <= 0;
    //            path_index <= 0;
    //            path_len_loc <= path_len;
    //            path_flat_y_loc <= path_flat_y;
    //            path_flat_x_loc <= path_flat_x;
    //            led[14] <= 1;
    //        end
    
            if (!path_saved) begin
//                led[15] <= 1;
                if (path_index < path_len_loc) begin
                    path_x[path_index] <= path_flat_x_loc[path_index*4 +: 4];
                    path_y[path_index] <= path_flat_y_loc[path_index*4 +: 4];
                    path_index <= path_index + 1;
                end
                else if (path_index < `MAX_PATH_LEN) begin
                    path_x[path_index] <= 4'hF;
                    path_y[path_index] <= 4'hF;
                    path_index <= path_index + 1;
                end
                else begin
                    path_index = 0;
                    path_saved <= 1;
                end
            end
    
//            led[6:0]  <= path_len;
//            led[13:7]  <= path_len_loc;
    
    //        led[4:1]  <= path_x[0];
    //        led[8:5]  <= path_x[1];
    //        led[12:9] <= path_x[2];
        end
//    end

    assign led[0] = update_path;
    assign led[3:1] = path_len[3:1];
    assign led[7:4] = path_len_loc[3:0];
    assign led[11:8] = path_flat_x[3:0];
//    assign led[11:8] = path_x[0];
    assign led[15:12] = path_x[0];
//    assign led[15:12] = path_y[0];
endmodule
