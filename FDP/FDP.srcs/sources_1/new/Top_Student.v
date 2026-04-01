`timescale 1ns / 1ps

`include "constants.vh"

module Top_Student (
    input basys_clk,
    input btnC, btnL, btnR, btnU, btnD, UART_RX,
    inout ps2_clk, ps2_data,
    input [15:0] sw,
    output [7:0] JC,
    output UART_TX,
    output reg [15:0] led,
    output [7:0] seg,
    output [3:0] an
);
    
    wire game_active = sw[15];

    wire clk;
    variable_clock #(.CLOCK_SPEED(`BASYS_CLOCK_SPEED), .OUT_SPEED(`CLOCK_SPEED)) clk_inst
                    (.clk(basys_clk), .clk_out(clk));





    // =========================================================
    // MOUSE AND COMMUNICATION
    // =========================================================
    
    // own mouse
    wire [11:0] mouse_xpos, mouse_ypos;
    wire [3:0] mouse_zpos;
    wire mouse_left, mouse_middle, mouse_right, mouse_new_event;
    
    reg mouse_setmax_x = 0, mouse_setmax_y = 0, mouse_setx = 0, mouse_sety = 0;
    reg [11:0] mouse_value = 0;
    reg [1:0] mouse_init_state = 0;
    
//    wire [3:0] mouse_tx = (mouse_xpos >= `MIN_PIX_X && mouse_xpos <= `MAX_PIX_X) ? ((mouse_xpos - `MIN_PIX_X) * 7'd43) >> 8 : 4'hF;
//    wire [3:0] mouse_ty = (mouse_ypos >= `MIN_PIX_Y && mouse_ypos <= `MAX_PIX_Y) ? ((mouse_ypos - `MIN_PIX_Y) * 7'd43) >> 8 : 4'hF;
    
//    wire [6:0] mouse_cx = (mouse_xpos[6:0] < 1) ? 1 : (mouse_xpos[6:0] > 94) ? 94 : mouse_xpos[6:0];
//    wire [5:0] mouse_cy = (mouse_ypos[5:0] < 1) ? 1 : (mouse_ypos[5:0] > 62) ? 62 : mouse_ypos[5:0];
    wire [6:0] mouse_cx = (mouse_xpos[7:1] < 1) ? 1 : (mouse_xpos[7:1] > 94) ? 94 : mouse_xpos[7:1];
    wire [5:0] mouse_cy = (mouse_ypos[6:1] < 1) ? 1 : (mouse_ypos[6:1] > 62) ? 62 : mouse_ypos[6:1];
    
    wire [3:0] mouse_tx = (mouse_cx >= `MIN_PIX_X && mouse_cx <= `MAX_PIX_X) ? ((mouse_cx - `MIN_PIX_X) * 7'd43) >> 8 : 4'hF;
    wire [3:0] mouse_ty = (mouse_cy >= `MIN_PIX_Y && mouse_cy <= `MAX_PIX_Y) ? ((mouse_cy - `MIN_PIX_Y) * 7'd43) >> 8 : 4'hF;
    
    // one-time initialisation to set max x=95, max y=63
    always @(posedge clk) begin
        mouse_setmax_x <= 0;
        mouse_setmax_y <= 0;
        case (mouse_init_state)
            0: begin
                mouse_value <= `PIX_WIDTH * 2 - 1; //12'd95;   // max x = 95 (96 pixels wide)
                mouse_setmax_x <= 1;
                mouse_init_state <= 1;
            end
            1: begin
                mouse_value    <= `PIX_HEIGHT * 2 - 1; //12'd63;   // max y = 63 (64 pixels tall)
                mouse_setmax_y <= 1;
                mouse_init_state <= 2;
            end
            /*2: begin
                mouse_value <= 0;
                mouse_setx <= 1;
                mouse_init_state <= 3;
            end
            3: begin
                mouse_value <= 0;
                mouse_sety <= 1;
                mouse_init_state <= 4;
            end*/
            default: begin end              // stay here forever
        endcase
    end
    
    MouseCtl #(.SYSCLK_FREQUENCY_HZ(`CLOCK_SPEED)) mouse_inst (
        .clk      (clk),
        .rst      (1'b0),
        .xpos     (mouse_xpos),
        .ypos     (mouse_ypos),
        .zpos     (mouse_zpos),
        .left     (mouse_left),
        .middle   (mouse_middle),
        .right    (mouse_right),
        .new_event(mouse_new_event),
        .value    (mouse_value),
        .setx     (mouse_setx),
        .sety     (mouse_sety),
        .setmax_x (mouse_setmax_x),
        .setmax_y (mouse_setmax_y),
        .ps2_clk  (ps2_clk),
        .ps2_data (ps2_data)
    );
    
    wire busy_tx, busy_rx, received, tx_en_code, tx_en_game, player;
    wire [2:0] pair_state;
    wire single_player = (pair_state == `SINGLE);

    reg [`DATA_BITS-1:0] data_tx = 0;
    wire [`CODE_BITS-1:0] data_tx_code;
    wire [`GAME_BITS-1:0] data_tx_game;
    wire [`DATA_BITS-1:0] data_rx;
    wire [`CODE_BITS-1:0] data_rx_code = data_rx[`CODE_BITS-1:0];
    wire [`GAME_BITS-1:0] data_rx_game = data_rx[`DATA_BITS-1:`CODE_BITS];
    wire tx_en = tx_en_code | (tx_en_game && pair_state == `PAIRED); //tx_en_game;

    uart_tx tx_inst (.clk(clk), .rst(0), .tx_en(tx_en), .data(data_tx), .tx(UART_TX), .busy(busy_tx));

    uart_rx rx_inst (.clk(clk), .rst(0), .rx(UART_RX), .data(data_rx), .busy(busy_rx), .valid(received));

    pairing_fsm pair_inst (
        .clk(clk), 
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
        .clk(clk), 
        .mouse_cx(mouse_cx), 
        .mouse_cy(mouse_cy), 
        .mouse_left(mouse_left), 
        .mouse_middle(mouse_middle), 
        .mouse_right(mouse_right), 
        .tx_en(tx_en_game), 
        .player(player), 
        .data_tx_game(data_tx_game)
    );
    
    // received from other player
    wire [6:0] rec_mouse_cx;
    wire [5:0] rec_mouse_cy;
    wire rec_mouse_left, rec_mouse_middle, rec_mouse_right;
    assign {rec_mouse_cx, rec_mouse_cy, rec_mouse_left, rec_mouse_middle, rec_mouse_right} = data_rx_game;
    
    wire [3:0] rec_mouse_tx = (rec_mouse_cx >= `MIN_PIX_X && rec_mouse_cx <= `MAX_PIX_X) ? ((rec_mouse_cx - `MIN_PIX_X) * 7'd43) >> 8 : 4'hF;
    wire [3:0] rec_mouse_ty = (rec_mouse_cy >= `MIN_PIX_Y && rec_mouse_cy <= `MAX_PIX_Y) ? ((rec_mouse_cy - `MIN_PIX_Y) * 7'd43) >> 8 : 4'hF;
    
    // register pulses
    reg mouse_left_prev = 0, mouse_right_prev = 0, mouse_middle_prev = 0;
    wire mouse_left_pulse = mouse_left & ~mouse_left_prev;  // single cycle on press
    wire mouse_right_pulse = mouse_right & ~mouse_right_prev;  // single cycle on press
    wire mouse_middle_pulse = mouse_middle & ~mouse_middle_prev;  // single cycle on press 
    reg rec_mouse_left_prev = 0, rec_mouse_right_prev = 0, rec_mouse_middle_prev = 0;
    wire rec_mouse_left_pulse = rec_mouse_left & ~rec_mouse_left_prev;  // single cycle on press
    wire rec_mouse_right_pulse = rec_mouse_right & ~rec_mouse_right_prev;  // single cycle on press
    wire rec_mouse_middle_pulse = rec_mouse_middle & ~rec_mouse_middle_prev;  // single cycle on press
    
    always @ (posedge clk) begin
        mouse_left_prev <= mouse_left;
        mouse_right_prev <= mouse_right;
        mouse_middle_prev <= mouse_middle;
        rec_mouse_left_prev <= rec_mouse_left;
        rec_mouse_right_prev <= rec_mouse_right;
        rec_mouse_middle_prev <= rec_mouse_middle;
    end
    
    wire p1_left = mouse_left_pulse & game_active;
    wire p1_middle = mouse_right_pulse & game_active;
    wire p1_right = mouse_right_pulse & game_active;
    wire p2_left = rec_mouse_left_pulse & game_active;
    wire p2_middle = rec_mouse_right_pulse & game_active;
    wire p2_right = rec_mouse_right_pulse & game_active;



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

    wire [6:0] x = pixel_index % `PIX_WIDTH;
    wire [5:0] y = pixel_index / `PIX_WIDTH;

    variable_clock #(.CLOCK_SPEED(`CLOCK_SPEED), .OUT_SPEED(6_250_000)) clk_6p25m_inst (.clk(clk), .clk_out(clk_6p25m));

    pairing_oled pair_oled_inst (.clk(clk), .pair_state(pair_state), .x(x), .y(y), .oled_data(oled_data_pair));

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

    parameter DISPLAY_TIME = 3 * `CLOCK_SPEED; // for the displaying of PAIRED
    reg [$clog2(DISPLAY_TIME):0] display_counter = 0;
    reg display_text = 0;
    
    
    
    
    
    // =========================================================
    // RANDOM SEED & GENERATION
    // =========================================================
    
    wire [15:0] random_seed;
    wire rst_game = btnC; // connect to switch
    lfsr_rng random_unit(.clk(basys_clk), .rnd(random_seed), .reset(1'b0));
    
    reg [1:0] gen_state = `RESET; 
    reg [3:0] tx = 0, ty = 0;
    parameter WALL_COLOR = `OLED_WHITE;
        
        
        
        
        
    // =========================================================
    // MAP STORAGE & CONSOLIDATED DRIVER
    // =========================================================
    
    reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];
    reg [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat;
    
    // flattening
    integer fx, fy;
    always @(*) begin
        for (fy = 0; fy < `TILE_MAP_HEIGHT; fy = fy + 1) begin
            for (fx = 0; fx < `TILE_MAP_WIDTH; fx = fx + 1) begin
                tile_map_flat[(fy*`TILE_MAP_WIDTH + fx)*3 +: 3] = tile_map[fx][fy];
            end
        end
    end
    
    
    
    
    
    // =========================================================
    // RENDERING
    // =========================================================
    
    function [15:0] expand_tile;
        input [2:0] tile_type;
        input [2:0] local_x;
        input [2:0] local_y;
    begin
        case (tile_type)
            `MAP_EMPTY:   expand_tile = `OLED_BLACK;
            `MAP_WALL:    expand_tile = WALL_COLOR;
            `MAP_BLOCK:   expand_tile = `OLED_GREY;
//            `MAP_BOMB:    expand_tile = (local_x >= 2 && local_x <= 3 && local_y >= 2 && local_y <= 3) ? `OLED_ORANGE : `OLED_BLACK;
            `MAP_POWERUP: expand_tile = `OLED_MAGENTA;
            `MAP_BLAST: expand_tile = `OLED_YELLOW;
            default:      expand_tile = `OLED_BLACK;
        endcase
    end
    endfunction

    function [15:0] cursor_region;
        input [6:0] x, px;
        input [5:0] y, py;
        
        reg [6:0] dx;
        reg [5:0] dy;
        reg [5:0] row;
        begin
            if (x < px || y < py) cursor_region = 0;
            else begin
                dx = x - px;
                dy = y - py;
                case (dy)
                    4'd0:  row = 6'b110000;
                    4'd1:  row = 6'b111000;
                    4'd2:  row = 6'b111100;
                    4'd3:  row = 6'b111110;
                    4'd4:  row = 6'b111000;
                    4'd5:  row = 6'b100100;
                    4'd6:  row = 6'b000010;
                    default: row = 6'b000000;
                endcase
                cursor_region = (x >= px && dx <= 5 && y >= py && dy <= 6 && row[5 - dx]);
            end
        end
    endfunction
    
    function cursor_border;
        input [6:0] x, px;
        input [5:0] y, py;
        begin
            cursor_border = (cursor_region(x, px, y, py) == 0 && // not inside cursor
                            (cursor_region(x+1, px, y, py) == 1 || // and neighbor is inside the cursor
                             cursor_region(x-1, px, y, py) == 1 ||
                             cursor_region(x, px, y+1, py) == 1 ||
                             cursor_region(x, px, y-1, py) == 1));
        end
    endfunction
    
    
    
    
    
    // =========================================================
    // PLAYER 1 AND 2 CONTROLLERS
    // =========================================================
    
    reg map_changed = 0;
                              
    wire [6:0] p1_x;
    wire [5:0] p1_y;
    wire [3:0] p1_tx, p1_ty;
    reg p1_dead;
    
    reg[1:0] p1_bomb_radius = 1, p1_bomb_count = 1, p1_speed_incr = 1;
    
    wire [`MAX_BOMBS-1:0] p1_place_bomb_req, p1_bomb_active, p1_bomb_red, p1_explosion_active;
    wire [`MAX_BOMBS*4-1:0] p1_bomb_tx_flat, p1_bomb_ty_flat;
    wire [`MAX_BOMBS*2-1:0] p1_explosion_stage_flat;
    
    reg [`MAX_BOMBS-1:0] p1_explosion_active_prev = 0;
    wire [`MAX_BOMBS-1:0] p1_explosion_start = p1_explosion_active & ~p1_explosion_active_prev;
    wire [`MAX_BOMBS-1:0] p1_explosion_end = ~p1_explosion_active & p1_explosion_active_prev;
    always @ (posedge clk) p1_explosion_active_prev <= p1_explosion_active;
    
    wire p1_update, p1_baw, p1_valid;
    wire [4*`MAX_PATH_LEN-1:0] p1_pfx, p1_pfy;
    wire [6:0] p1_len;
    
    wire [3:0] p1_goal_tx, p1_goal_ty;
    
    p1_controller p1_ctrl_inst (
        .clk(clk),
        .goal_tx(p1_goal_tx),
        .goal_ty(p1_goal_ty),
        .mouse_tx(mouse_tx),
        .mouse_ty(mouse_ty),
        .mouse_left_pulse(p1_left),//mouse_left_pulse),
        .mouse_right_pulse(p1_middle),//mouse_right_pulse),
        .mouse_middle_pulse(p1_right),//mouse_middle_pulse),
        .tile_map_flat(tile_map_flat),
        .speed_multiplier(p1_speed_incr),
        .map_changed(map_changed),
        
        .p1_tx(p1_tx),
        .p1_ty(p1_ty),
        .p1_x(p1_x),
        .p1_y(p1_y),
        .p1_dead(p1_dead),        
        
        .place_bomb_req(p1_place_bomb_req),
        .bomb_active(p1_bomb_active),
        .bomb_tx_flat(p1_bomb_tx_flat),
        .bomb_ty_flat(p1_bomb_ty_flat),
        .bomb_red(p1_bomb_red),
        
        .explosion_active(p1_explosion_active),
        .explosion_stage_flat(p1_explosion_stage_flat),
        
        .bomb_count(p1_bomb_count),
        .bomb_radius(p1_bomb_radius),
        
        .update(p1_update),
        .blocks_as_walls(p1_baw),
        .path_flat_x(p1_pfx),
        .path_flat_y(p1_pfy),
        .path_valid(p1_valid),
        .path_len(p1_len)
    );
    
    wire [6:0] p2_x;
    wire [5:0] p2_y;
    wire [3:0] p2_tx, p2_ty;
    reg p2_dead;
    
    reg [1:0] p2_bomb_radius = 1, p2_bomb_count = 1, p2_speed_incr = 1;
    
    wire [`MAX_BOMBS-1:0] p2_place_bomb_req, p2_bomb_active, p2_bomb_red, p2_explosion_active;
    wire [`MAX_BOMBS*4-1:0] p2_bomb_tx_flat, p2_bomb_ty_flat;
    wire [`MAX_BOMBS*2-1:0] p2_explosion_stage_flat;
    
    reg [`MAX_BOMBS-1:0] p2_explosion_active_prev = 0;
    wire [`MAX_BOMBS-1:0] p2_explosion_start = p2_explosion_active & ~p2_explosion_active_prev;
    wire [`MAX_BOMBS-1:0] p2_explosion_end = ~p2_explosion_active & p2_explosion_active_prev;
    always @ (posedge clk) p2_explosion_active_prev <= p2_explosion_active;
    
    wire p2_update, p2_baw, p2_valid;
    wire [4*`MAX_PATH_LEN-1:0] p2_pfx, p2_pfy;
    wire [6:0] p2_len;
          
    wire [3:0] p2_goal_tx, p2_goal_ty;
    
    p2_controller p2_ctrl_inst (
        .clk(clk),
        .single_player(1), // change this later on
        .p1_tx(p1_tx),
        .p1_ty(p1_ty),
        .goal_tx(p2_goal_tx),
        .goal_ty(p2_goal_ty),
        .mouse_tx(rec_mouse_tx),
        .mouse_ty(rec_mouse_ty),
        .mouse_left_pulse(p2_left),//rec_mouse_left_pulse),
        .mouse_right_pulse(p2_middle),//rec_mouse_right_pulse),
        .mouse_middle_pulse(p2_right),//rec_mouse_middle_pulse),
        .tile_map_flat(tile_map_flat),
        .speed_multiplier(p2_speed_incr),
        .map_changed(map_changed),
        
        .p2_tx(p2_tx),
        .p2_ty(p2_ty),
        .p2_x(p2_x),
        .p2_y(p2_y),
        .p2_dead(p2_dead),

        .place_bomb_req(p2_place_bomb_req),
        .bomb_active(p2_bomb_active),
        .bomb_tx_flat(p2_bomb_tx_flat),
        .bomb_ty_flat(p2_bomb_ty_flat),
        .bomb_red(p2_bomb_red),
        
        .explosion_active(p2_explosion_active),
        .explosion_stage_flat(p2_explosion_stage_flat),
        
        .bomb_count(p2_bomb_count),
        .bomb_radius(p2_bomb_radius),
        
        .update(p2_update),
        .blocks_as_walls(p2_baw),
        .path_flat_x(p2_pfx),
        .path_flat_y(p2_pfy),
        .path_valid(p2_valid),
        .path_len(p2_len)
    );
    
    a_star_mux as_mux_inst (
        .clk(clk),
        .tile_map_flat(tile_map_flat),
        .c0_update(p1_update & game_active), 
        .c0_baw(p1_baw), 
        .c0_stx(p1_tx), 
        .c0_sty(p1_ty), 
        .c0_gtx(p1_goal_tx), 
        .c0_gty(p1_goal_ty),
        .c0_pfx(p1_pfx), 
        .c0_pfy(p1_pfy),
        .c0_valid(p1_valid), 
        .c0_len(p1_len),
       
        .c1_update(p2_update & game_active), 
        .c1_baw(p2_baw),
        .c1_stx(p2_tx), 
        .c1_sty(p2_ty), 
        .c1_gtx(p2_goal_tx), 
        .c1_gty(p2_goal_ty),
        .c1_pfx(p2_pfx), 
        .c1_pfy(p2_pfy),
        .c1_valid(p2_valid),
        .c1_len(p2_len)
    );




    
    // =========================================================
    // REACH CALCULATION FOR P1/P2 BOMBS
    // =========================================================
    
    wire [3:0] b_tx [0:1][0:`MAX_BOMBS-1];
    wire [3:0] b_ty [0:1][0:`MAX_BOMBS-1];
    wire [1:0] b_stage [0:1][0:`MAX_BOMBS-1]; //reg [1:0] b_stage_prev [0:1][0:`MAX_BOMBS-1];
    wire [1:0] b_radius [0:1];
    wire [`MAX_BOMBS-1:0] b_place_req [0:1];
    wire [`MAX_BOMBS-1:0] b_bomb_active [0:1];
    wire [`MAX_BOMBS-1:0] b_bomb_red [0:1];
    wire [`MAX_BOMBS-1:0] b_explosion_active [0:1];
    wire [`MAX_BOMBS-1:0] b_explosion_start [0:1];
    wire [`MAX_BOMBS-1:0] b_explosion_end [0:1];
    
    assign b_radius[0] = p1_bomb_radius;
    assign b_radius[1] = p2_bomb_radius;
    assign b_bomb_active[0] = p1_bomb_active;
    assign b_bomb_active[1] = p2_bomb_active;
    assign b_place_req[0] = p1_place_bomb_req;
    assign b_place_req[1] = p2_place_bomb_req;
    assign b_bomb_red[0] = p1_bomb_red;
    assign b_bomb_red[1] = p2_bomb_red;
    assign b_explosion_active[0] = p1_explosion_active;
    assign b_explosion_active[1] = p2_explosion_active;
    assign b_explosion_start[0] = p1_explosion_start;
    assign b_explosion_start[1] = p2_explosion_start;
    assign b_explosion_end[0] = p1_explosion_end;
    assign b_explosion_end[1] = p2_explosion_end;
    
    genvar pi, gi;
    generate
        for (pi = 0; pi < 2; pi = pi + 1) begin : player_unpack
            for (gi = 0; gi < `MAX_BOMBS; gi = gi + 1) begin : bomb_unpack
               assign b_tx[pi][gi] = (pi == 0) ? p1_bomb_tx_flat[gi*4 +: 4] : p2_bomb_tx_flat[gi*4 +: 4];
               assign b_ty[pi][gi] = (pi == 0) ? p1_bomb_ty_flat[gi*4 +: 4] : p2_bomb_ty_flat[gi*4 +: 4];
               assign b_stage[pi][gi] = (pi == 0) ? p1_explosion_stage_flat[gi*2 +: 2] : p2_explosion_stage_flat[gi*2 +: 2];
           end
        end
    endgenerate
    
    integer player_i, bomb_i, rad_i;
    integer stop_u, stop_d, stop_l, stop_r;
    reg [3:0] up_len   [0:1][0:`MAX_BOMBS-1];
    reg [3:0] down_len [0:1][0:`MAX_BOMBS-1];
    reg [3:0] left_len [0:1][0:`MAX_BOMBS-1];
    reg [3:0] right_len[0:1][0:`MAX_BOMBS-1];
    
    always @(posedge clk) begin
        for (player_i = 0; player_i < 2; player_i = player_i + 1) begin
            for (bomb_i = 0; bomb_i < `MAX_BOMBS; bomb_i = bomb_i + 1) begin
                if (b_place_req[player_i][bomb_i]) begin
                    stop_u = 0;
                    stop_d = 0;
                    stop_l = 0;
                    stop_r = 0;
     
                    up_len   [player_i][bomb_i] <= 0;
                    down_len [player_i][bomb_i] <= 0;
                    left_len [player_i][bomb_i] <= 0;
                    right_len[player_i][bomb_i] <= 0;
     
                    for (rad_i = 1; rad_i <= `MAX_RADIUS; rad_i = rad_i + 1) begin
                        if (rad_i <= b_radius[player_i]) begin
                            // UP
                            if (!stop_u) begin
                                if (b_ty[player_i][bomb_i] < rad_i ||
                                    tile_map[b_tx[player_i][bomb_i]][b_ty[player_i][bomb_i] - rad_i] == `MAP_WALL) stop_u = 1;
                                else begin
                                    up_len[player_i][bomb_i] <= rad_i[3:0];
                                    if (tile_map[b_tx[player_i][bomb_i]][b_ty[player_i][bomb_i] - rad_i] == `MAP_BLOCK) stop_u = 1;
                                end
                            end
     
                            // DOWN
                            if (!stop_d) begin
                                if ((b_ty[player_i][bomb_i] + rad_i) >= `TILE_MAP_HEIGHT ||
                                    tile_map[b_tx[player_i][bomb_i]][b_ty[player_i][bomb_i] + rad_i] == `MAP_WALL) stop_d = 1;
                                else begin
                                    down_len[player_i][bomb_i] <= rad_i[3:0];
                                    if (tile_map[b_tx[player_i][bomb_i]][b_ty[player_i][bomb_i] + rad_i] == `MAP_BLOCK) stop_d = 1;
                                end
                            end
     
                            // LEFT
                            if (!stop_l) begin
                                if (b_tx[player_i][bomb_i] < rad_i ||
                                    tile_map[b_tx[player_i][bomb_i] - rad_i][b_ty[player_i][bomb_i]] == `MAP_WALL) stop_l = 1;
                                else begin
                                    left_len[player_i][bomb_i] <= rad_i[3:0];
                                    if (tile_map[b_tx[player_i][bomb_i] - rad_i][b_ty[player_i][bomb_i]] == `MAP_BLOCK) stop_l = 1;
                                end
                            end
     
                            // RIGHT
                            if (!stop_r) begin
                                if ((b_tx[player_i][bomb_i] + rad_i) >= `TILE_MAP_WIDTH ||
                                    tile_map[b_tx[player_i][bomb_i] + rad_i][b_ty[player_i][bomb_i]] == `MAP_WALL) stop_r = 1;
                                else begin
                                    right_len[player_i][bomb_i] <= rad_i[3:0];
                                    if (tile_map[b_tx[player_i][bomb_i] + rad_i][b_ty[player_i][bomb_i]] == `MAP_BLOCK)  stop_r = 1;
                                end
                            end
     
                        end
                    end // rad_i
                end // trigger
            end
        end
    end
    
    
    
    
 
    // =========================================================
    // DEATH DETECTION
    // =========================================================
    
    always @(posedge clk) begin
        if (rst_game) begin
            p1_dead <= 0;
            p2_dead <= 0;
        end 
        else begin
            if (tile_map[p1_tx][p1_ty] == `MAP_BLAST) p1_dead <= 1;
            if (tile_map[p2_tx][p2_ty] == `MAP_BLAST) p2_dead <= 1;
        end
    end
    
    
    
    

    // =========================================================
    // TILE MAP UPDATES
    // =========================================================
    
    wire p1_collecting = (tile_map[p1_tx][p1_ty] == `MAP_POWERUP);
    wire p2_collecting = (tile_map[p2_tx][p2_ty] == `MAP_POWERUP);
    
    reg [1:0] b_stage_prev [0:1][0:`MAX_BOMBS-1];
    always @(posedge clk) begin
        for (player_i = 0; player_i < 2; player_i = player_i + 1)
            for (bomb_i = 0; bomb_i < `MAX_BOMBS; bomb_i = bomb_i + 1)
                b_stage_prev[player_i][bomb_i] <= b_stage[player_i][bomb_i];
    end
    
    wire b_stage_changed [0:1][0:`MAX_BOMBS-1];
    genvar sp, sb;
    generate
        for (sp = 0; sp < 2; sp = sp + 1) begin: b_stage_player
            for (sb = 0; sb < `MAX_BOMBS; sb = sb + 1) begin: b_stage_bomb
                assign b_stage_changed[sp][sb] = b_stage[sp][sb] != b_stage_prev[sp][sb];
            end
        end
    endgenerate
    
    // =========================================================
    // BLAST FSM DECLARATIONS
    // =========================================================
    reg [1:0] bomb_state = 0;
    reg [3:0] curr_tx = 0, curr_ty = 0;
    reg [3:0] curr_up_len = 0, curr_down_len = 0, curr_left_len = 0, curr_right_len = 0;
    reg [1:0] curr_stage = 0;
    reg [1:0] curr_mode = 0; // 0 place, 1 blast stage changed, 2 explosion ended
    reg [1:0] curr_pi = 0, curr_bi = 0;

    reg destroy_up   [0:1][0:`MAX_BOMBS-1];
    reg destroy_down [0:1][0:`MAX_BOMBS-1];
    reg destroy_left [0:1][0:`MAX_BOMBS-1];
    reg destroy_right[0:1][0:`MAX_BOMBS-1];

    reg blast_stage_pending [0:1][0:`MAX_BOMBS-1];
    reg end_pending [0:1][0:`MAX_BOMBS-1];
    reg place_pending [0:1][0:`MAX_BOMBS-1];
    
    parameter STORE_DATA = 0;
    parameter UPDATE = 1;
    
//    always @ (posedge clk) begin
//    end

    // latch pending flags
//    always @(posedge clk) begin
        
//        if (p1_collecting) tile_map[p1_tx][p1_ty] <= `MAP_EMPTY;
//        if (p2_collecting) tile_map[p2_tx][p2_ty] <= `MAP_EMPTY;
        
//        if (gen_state == `GAMEPLAY) begin
            
//        end
//    end

    always @(posedge clk) begin
        case (gen_state)
            `RESET: begin
                if (rst_game) begin
                    tx <= 0;
                    ty <= 0;
                    gen_state <= `GENERATION;
                end
            end
            `GENERATION: begin // PHASE: GENERATION
                if ((tx % 2 == 1) && (ty % 2 == 1)) tile_map[tx][ty] <= `MAP_WALL;
                else if ((tx == 0 && (ty == 0 || ty == 1 || ty == 2)) || (ty == 0 && (tx == 0 || tx == 1 || tx == 2))) tile_map[tx][ty] <= `MAP_EMPTY; // protect p1 spawn
                else if ((tx == 14 && (ty == 8 || ty == 7 || ty == 6)) || (ty == 8 && (tx == 14 || tx == 13 || tx == 12))) tile_map[tx][ty] <= `MAP_EMPTY; // protect p1 spawn
                else if (random_seed[7:0] <= 100) tile_map[tx][ty] <= `MAP_BLOCK;
                else tile_map[tx][ty] <= `MAP_EMPTY;

                if (tx < `TILE_MAP_WIDTH - 1) tx <= tx + 1;
                else if (ty < `TILE_MAP_HEIGHT - 1) begin
                    tx <= 0;
                    ty <= ty + 1;
                end
                else gen_state <= `GAMEPLAY;
            end
            `GAMEPLAY: begin // PHASE: GAMEPLAY (One driver for all updates!), blocks generate powerups ~75% of the time
                if (rst_game) gen_state <= `RESET;
                
                map_changed <= game_active && (|p1_place_bomb_req | |p1_explosion_start | |p1_explosion_end |
                                               |p2_place_bomb_req | |p2_explosion_start | |p2_explosion_end |
                                               p1_collecting | p2_collecting);
                
                if (p1_collecting) tile_map[p1_tx][p1_ty] <= `MAP_EMPTY;
                if (p2_collecting) tile_map[p2_tx][p2_ty] <= `MAP_EMPTY;
                                               
                if (b_place_req[0][0]) place_pending[0][0] <= 1;
                if (b_place_req[0][1]) place_pending[0][1] <= 1;
                if (b_place_req[1][0]) place_pending[1][0] <= 1;
                if (b_place_req[1][1]) place_pending[1][1] <= 1;
                
                if (b_explosion_active[0][0] && b_stage_changed[0][0]) blast_stage_pending[0][0] <= 1;
                if (b_explosion_active[0][1] && b_stage_changed[0][1]) blast_stage_pending[0][1] <= 1;
                if (b_explosion_active[1][0] && b_stage_changed[1][0]) blast_stage_pending[1][0] <= 1;
                if (b_explosion_active[1][1] && b_stage_changed[1][1]) blast_stage_pending[1][1] <= 1;
                
                if (b_explosion_end[0][0]) end_pending[0][0] <= 1;
                if (b_explosion_end[0][1]) end_pending[0][1] <= 1;
                if (b_explosion_end[1][0]) end_pending[1][0] <= 1;
                if (b_explosion_end[1][1]) end_pending[1][1] <= 1;
                
                case (bomb_state)
                    STORE_DATA: begin
                        if (place_pending[0][0] || blast_stage_pending[0][0] || end_pending[0][0]) begin
                            curr_pi <= 0;
                            curr_bi <= 0;
                            curr_tx <= b_tx[0][0];
                            curr_ty <= b_ty[0][0];
                            curr_up_len <= up_len[0][0];
                            curr_down_len <= down_len[0][0];
                            curr_left_len <= left_len[0][0];
                            curr_right_len <= right_len[0][0];
                            curr_stage <= b_stage[0][0];
                            curr_mode <= place_pending[0][0] ? 2'd0 : (blast_stage_pending[0][0] ? 2'd1 : 2'd2);
                           
                            bomb_state <= UPDATE;
                        end
                        else if (place_pending[0][1] || blast_stage_pending[0][1] || end_pending[0][1]) begin
                            curr_pi <= 0;
                            curr_bi <= 1;
                            curr_tx <= b_tx[0][1];
                            curr_ty <= b_ty[0][1];
                            curr_up_len <= up_len[0][1];
                            curr_down_len <= down_len[0][1];
                            curr_left_len <= left_len[0][1];
                            curr_right_len <= right_len[0][1];
                            curr_stage <= b_stage[0][1];
                            curr_mode <= place_pending[0][1] ? 2'd0 : (blast_stage_pending[0][1] ? 2'd1 : 2'd2);
                            
                            bomb_state <= UPDATE;
                        end
                        else if (place_pending[1][0] || blast_stage_pending[1][0] || end_pending[1][0]) begin
                            curr_pi <= 1;
                            curr_bi <= 0;
                            curr_tx <= b_tx[1][0];
                            curr_ty <= b_ty[1][0];
                            curr_up_len <= up_len[1][0];
                            curr_down_len <= down_len[1][0];
                            curr_left_len <= left_len[1][0];
                            curr_right_len <= right_len[1][0];
                            curr_stage <= b_stage[1][0];
                            curr_mode <= place_pending[1][0] ? 2'd0 : (blast_stage_pending[1][0] ? 2'd1 : 2'd2);
                            
                            bomb_state <= UPDATE;
                        end
                        else if (place_pending[1][1] || blast_stage_pending[1][1] || end_pending[1][1]) begin
                            curr_pi <= 1;
                            curr_bi <= 1;
                            curr_tx <= b_tx[1][1];
                            curr_ty <= b_ty[1][1];
                            curr_up_len <= up_len[1][1];
                            curr_down_len <= down_len[1][1];
                            curr_left_len <= left_len[1][1];
                            curr_right_len <= right_len[1][1];
                            curr_stage <= b_stage[1][1];
                            curr_mode <= place_pending[1][1] ? 2'd0 : (blast_stage_pending[1][1] ? 2'd1 : 2'd2);
                            
                            bomb_state <= UPDATE;
                        end
                    end
                    UPDATE: begin
                        bomb_state <= STORE_DATA;
                       
                        if (curr_mode == 2'd0) begin
                            tile_map[curr_tx][curr_ty] <= `MAP_BOMB;
                           
                            place_pending[curr_pi][curr_bi] <= 0;
                        end
                        else if (curr_mode == 2'd1) begin
                            if (curr_stage == 1) begin
                                tile_map[curr_tx][curr_ty] <= `MAP_BLAST;
                            
                                if (curr_up_len >= 1) tile_map[curr_tx][curr_ty-1] <= `MAP_BLAST;
                                if (curr_down_len >= 1) tile_map[curr_tx][curr_ty+1] <= `MAP_BLAST;
                                if (curr_left_len >= 1) tile_map[curr_tx-1][curr_ty] <= `MAP_BLAST;
                                if (curr_right_len >= 1) tile_map[curr_tx+1][curr_ty] <= `MAP_BLAST;
                                
                                // check bomb destroy
                                destroy_up[curr_pi][curr_bi] <= (tile_map[curr_tx][curr_ty-curr_up_len] == `MAP_BLOCK);
                                destroy_down[curr_pi][curr_bi] <= (tile_map[curr_tx][curr_ty+curr_down_len] == `MAP_BLOCK);
                                destroy_left[curr_pi][curr_bi] <= (tile_map[curr_tx-curr_left_len][curr_ty] == `MAP_BLOCK);
                                destroy_right[curr_pi][curr_bi] <= (tile_map[curr_tx+curr_right_len][curr_ty] == `MAP_BLOCK);
                            end
                            else if (curr_stage == 2) begin
                                if (curr_up_len >= 2) tile_map[curr_tx][curr_ty-2] <= `MAP_BLAST;
                                if (curr_down_len >= 2) tile_map[curr_tx][curr_ty+2] <= `MAP_BLAST;
                                if (curr_left_len >= 2) tile_map[curr_tx-2][curr_ty] <= `MAP_BLAST;
                                if (curr_right_len >= 2) tile_map[curr_tx+2][curr_ty] <= `MAP_BLAST;
                            end
                            
                            blast_stage_pending[curr_pi][curr_bi] <= 0;
                        end
                        else begin
                            // clear current bomb tiles
                            tile_map[curr_tx][curr_ty] <= `MAP_EMPTY;
                            if (curr_up_len >= 1) tile_map[curr_tx][curr_ty-1] <= `MAP_EMPTY; 
                            if (curr_up_len >= 2) tile_map[curr_tx][curr_ty-2] <= `MAP_EMPTY; 
                            if (curr_down_len >= 1) tile_map[curr_tx][curr_ty+1] <= `MAP_EMPTY; 
                            if (curr_down_len >= 2) tile_map[curr_tx][curr_ty+2] <= `MAP_EMPTY; 
                            if (curr_left_len >= 1) tile_map[curr_tx-1][curr_ty] <= `MAP_EMPTY; 
                            if (curr_left_len >= 2) tile_map[curr_tx-2][curr_ty] <= `MAP_EMPTY; 
                            if (curr_right_len >= 1) tile_map[curr_tx+1][curr_ty] <= `MAP_EMPTY; 
                            if (curr_right_len >= 2) tile_map[curr_tx+2][curr_ty] <= `MAP_EMPTY;
                            
                            if (destroy_up[curr_pi][curr_bi] && random_seed[7:0] < `POWER_UP_SPAWN_RATE) tile_map[curr_tx][curr_ty-curr_up_len] <= `MAP_POWERUP;
                            if (destroy_down[curr_pi][curr_bi] && random_seed[7:0] < `POWER_UP_SPAWN_RATE) tile_map[curr_tx][curr_ty+curr_down_len] <= `MAP_POWERUP;
                            if (destroy_left[curr_pi][curr_bi] && random_seed[7:0] < `POWER_UP_SPAWN_RATE) tile_map[curr_tx-curr_left_len][curr_ty] <= `MAP_POWERUP;
                            if (destroy_right[curr_pi][curr_bi] && random_seed[7:0] < `POWER_UP_SPAWN_RATE) tile_map[curr_tx+curr_right_len][curr_ty] <= `MAP_POWERUP;
                            
                            // check other bombs to make sure their blast didnt get overwritten
                            // re-queue other active bombs to restore their blast tiles
                            if (b_explosion_active[0][0] && !(curr_pi == 0 && curr_bi==0)) blast_stage_pending[0][0] <= 1;
                            if (b_explosion_active[0][1] && !(curr_pi == 0 && curr_bi == 1)) blast_stage_pending[0][1] <= 1;
                            if (b_explosion_active[1][0] && !(curr_pi == 1 && curr_bi == 0)) blast_stage_pending[1][0] <= 1;
                            if (b_explosion_active[1][1] && !(curr_pi == 1 && curr_bi == 1)) blast_stage_pending[1][1] <= 1;
                            
                            end_pending[curr_pi][curr_bi] <= 0;
                        end            
                    end
                endcase
            end
        endcase
    end
    
    
    
    
    
    // =========================================================
    // POWERUP COLLECTION
    // =========================================================   
    parameter one_third = 85; 
    parameter two_third = 170;
    
    always @ (posedge clk) begin
        if (game_active && gen_state == `GAMEPLAY) begin
            led[15:14] <= p1_bomb_radius;
            led[13:12] <= p1_bomb_count;
            led[11:10] <= p1_speed_incr;
            led[9:8] <= p2_bomb_radius;
            led[7:6] <= p2_bomb_count;
            led[5:4] <= p2_speed_incr;
            
            if (p1_collecting) begin
                if (random_seed[7:0] < one_third) begin
                    // preference - bomb_radius -> bomb_count -> player_speed
                    if (p1_bomb_radius < `MAX_RADIUS) p1_bomb_radius <= p1_bomb_radius + 1;
                    else if (p1_bomb_count < `MAX_BOMBS) p1_bomb_count <= p1_bomb_count + 1;
                    else if (p1_speed_incr < `MAX_SPEED_INCR) p1_speed_incr <= p1_speed_incr + 1;
                end
                else if (random_seed[7:0] < two_third) begin
                    // preference - bomb_count -> player_speed -> bomb_radius
                    if (p1_bomb_count < `MAX_BOMBS) p1_bomb_count <= p1_bomb_count + 1;
                    else if (p1_speed_incr < `MAX_SPEED_INCR) p1_speed_incr <= p1_speed_incr + 1;
                    else if (p1_bomb_radius < `MAX_RADIUS) p1_bomb_radius <= p1_bomb_radius + 1;
                end
                else begin
                    // preference -player_speed -> bomb_radius -> bomb_count             
                    if (p1_speed_incr < `MAX_SPEED_INCR) p1_speed_incr <= p1_speed_incr + 1;
                    else if (p1_bomb_radius < `MAX_RADIUS) p1_bomb_radius <= p1_bomb_radius + 1;   
                    else if (p1_bomb_count < `MAX_BOMBS) p1_bomb_count <= p1_bomb_count + 1;             
                end
            end        
            if (p2_collecting) begin
                if (random_seed[7:0] < one_third) begin
                    // preference - bomb_radius -> bomb_count -> player_speed
                    if (p2_bomb_radius < `MAX_RADIUS) p2_bomb_radius <= p2_bomb_radius + 1;
                    else if (p2_bomb_count < 2'b11) p2_bomb_count <= p2_bomb_count + 1;
                    else if (p2_speed_incr < `MAX_SPEED_INCR) p2_speed_incr <= p2_speed_incr + 1;
                end
                else if (random_seed[7:0] < two_third) begin
                    // preference - bomb_count -> player_speed -> bomb_radius
                    if (p2_bomb_count < `MAX_BOMBS) p2_bomb_count <= p2_bomb_count + 1;
                    else if (p2_speed_incr < `MAX_SPEED_INCR) p2_speed_incr <= p2_speed_incr + 1;
                    else if (p2_bomb_radius < `MAX_RADIUS) p2_bomb_radius <= p2_bomb_radius+1;
                end
                else begin
                    // preference -player_speed -> bomb_radius -> bomb_count             
                    if (p2_speed_incr < `MAX_SPEED_INCR) p2_speed_incr <= p2_speed_incr + 1;
                    else if (p2_bomb_radius < `MAX_RADIUS) p2_bomb_radius <= p2_bomb_radius + 1;   
                    else if (p2_bomb_count < `MAX_BOMBS) p2_bomb_count <= p2_bomb_count + 1;             
                end    
            end
        end
    end 
    
   




    // =========================================================
    // SINGLE PLAYER OLED OVERLAY
    // =========================================================
    wire p1_region = (x >= p1_x) && (x < p1_x + `PLAYER_WIDTH) && (y >= p1_y) && (y < p1_y + `PLAYER_WIDTH);
    wire p2_region = (x >= p2_x) && (x < p2_x + `PLAYER_WIDTH) && (y >= p2_y) && (y < p2_y + `PLAYER_WIDTH);
    
    wire p1_mouse_region = cursor_region(x, mouse_cx, y, mouse_cy); // (x >= mouse_cx - 1) && (x <= mouse_cx + 1) && (y >= mouse_cy - 1) && (y <= mouse_cy + 1);
    wire p1_mouse_border = cursor_border(x, mouse_cx, y, mouse_cy); // (x >= mouse_cx - 1) && (x <= mouse_cx + 1) && (y >= mouse_cy - 1) && (y <= mouse_cy + 1);
    wire p2_mouse_region = cursor_region(x, rec_mouse_cx, y, rec_mouse_cy); //(x >= rec_mouse_cx - 1) && (x <= rec_mouse_cx + 1) && (y >= rec_mouse_cy - 1) && (y <= rec_mouse_cy + 1);
    wire p2_mouse_border = cursor_border(x, rec_mouse_cx, y, rec_mouse_cy); //(x >= rec_mouse_cx - 1) && (x <= rec_mouse_cx + 1) && (y >= rec_mouse_cy - 1) && (y <= rec_mouse_cy + 1);
       
    wire [3:0] tile_x_of_pixel = (x >= `MIN_PIX_X && x <= `MAX_PIX_X) ? ((x - `MIN_PIX_X) * 7'd43) >> 8 : 4'hF; // replace divider with reciprocal multiply + shift
    wire [3:0] tile_y_of_pixel = (y >= `MIN_PIX_Y && y <= `MAX_PIX_Y) ? ((y - `MIN_PIX_Y) * 7'd43) >> 8 : 4'hF;
    wire [2:0] local_x = (tile_x_of_pixel == 4'hF) ? 0 : (x - `MIN_PIX_X - tile_x_of_pixel * 6);
    wire [2:0] local_y = (tile_y_of_pixel == 4'hF) ? 0 : (y - `MIN_PIX_Y - tile_y_of_pixel * 6);
    
    always @(*) begin
        if (tile_x_of_pixel == 4'hF || tile_y_of_pixel == 4'hF) oled_data_single = `OLED_ORANGE;
        else oled_data_single = expand_tile(tile_map[tile_x_of_pixel][tile_y_of_pixel], local_x, local_y);
        
        if (b_bomb_active[0][0] && tile_x_of_pixel == b_tx[0][0] && tile_y_of_pixel == b_ty[0][0]) oled_data_single = b_bomb_red[0][0] ? `OLED_RED : `OLED_ORANGE;
        if (b_bomb_active[0][1] && tile_x_of_pixel == b_tx[0][1] && tile_y_of_pixel == b_ty[0][1]) oled_data_single = b_bomb_red[0][1] ? `OLED_RED : `OLED_ORANGE;
        if (b_bomb_active[1][0] && tile_x_of_pixel == b_tx[1][0] && tile_y_of_pixel == b_ty[1][0]) oled_data_single = b_bomb_red[1][0] ? `OLED_RED : `OLED_ORANGE;
        if (b_bomb_active[1][1] && tile_x_of_pixel == b_tx[1][1] && tile_y_of_pixel == b_ty[1][1]) oled_data_single = b_bomb_red[1][1] ? `OLED_RED : `OLED_ORANGE;

        // player
        if (p1_region) oled_data_single = p1_dead ? `OLED_CYAN : `OLED_BLUE;
        if (p2_region) oled_data_single = p2_dead ? `OLED_PINK : `OLED_RED;

        // draw walls
        if (x < `MIN_PIX_X || x > `MAX_PIX_X || y < `MIN_PIX_Y || y > `MAX_PIX_Y) oled_data_single = WALL_COLOR;
        
        // cursor
        if (p1_mouse_region) oled_data_single = `OLED_NAVY;
        if (p1_mouse_border) oled_data_single = `OLED_LIGHT_BLUE;
        if (!single_player && p2_mouse_region) oled_data_single = `OLED_MAROON;
        if (!single_player && p2_mouse_border) oled_data_single = `OLED_LIGHT_RED;
    end





    // =========================================================
    // MAIN LOOP
    // =========================================================
    always @(posedge clk) begin
        data_tx <= {data_tx_game, data_tx_code};

        case (pair_state)
            `SINGLE: begin
                display_counter <= 0;
                display_text <= 0;
                oled_data <= oled_data_single;
            end

            `PAIRED: begin
                led[0] <= rec_mouse_right;
                led[1] <= rec_mouse_middle;
                led[2] <= rec_mouse_left;
            
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
                    if (player == `PLAYER_1) oled_data <= oled_data_single;
                    else oled_data <= `OLED_BLACK;
//                    oled_data <= oled_data_multi;
            end

            default: begin
                oled_data <= oled_data_pair;
            end
        endcase
    end





    // =========================================================
    // SEVEN SEG DISPLAY
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
        .clk(clk),
        .seg0(seg_state),
        .seg1(8'b11111111),
        .seg2(8'b10001100),
        .seg3(seg_player),
        .seg(seg),
        .an(an)
    );

endmodule