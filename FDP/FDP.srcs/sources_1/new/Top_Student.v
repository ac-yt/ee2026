`timescale 1ns / 1ps

`include "constants.vh"

module Top_Student (
    input basys_clk,
    input btnC, btnL, btnR, btnU, btnD, UART_RX,
    inout ps2_clk, ps2_data,
    input [15:0] sw,
    output [7:0] JC,
    output UART_TX,
//    output reg [15:0] led,
    output [15:0] led,
    output [7:0] seg,
    output [3:0] an
);
    // =========================================================
    // COMMUNICATION
    // =========================================================
    wire busy_tx, busy_rx, received, tx_en_code, tx_en_game, player;
    wire [2:0] pair_state;
    
    wire clk;
    variable_clock #(.CLOCK_SPEED(`BASYS_CLOCK_SPEED), .OUT_SPEED(`CLOCK_SPEED)) clk_inst
                    (.clk(basys_clk), .clk_out(clk));

    reg [`DATA_BITS-1:0] data_tx = 0;
    wire [`CODE_BITS-1:0] data_tx_code;
    wire [`GAME_BITS-1:0] data_tx_game;
    wire [`DATA_BITS-1:0] data_rx;
    wire [`CODE_BITS-1:0] data_rx_code = data_rx[`CODE_BITS-1:0];
    wire [`GAME_BITS-1:0] data_rx_game = data_rx[`DATA_BITS-1:`CODE_BITS];
    wire tx_en = tx_en_code | (tx_en_game && pair_state == `PAIRED); //tx_en_game;

    uart_tx tx_inst (.clk(clk), .rst(0), .tx_en(tx_en), .data(data_tx), .tx(UART_TX), .busy(busy_tx));

    uart_rx rx_inst (.clk(clk), .rst(0), .rx(UART_RX), .data(data_rx), .busy(busy_rx), .valid(received));

    pairing_fsm pair_inst (.clk(clk), .received(received), .busy_tx(busy_tx), .btn_accept(btnU), .btn_cancel(btnD), .btn_pair_one(btnL), .btn_pair_two(btnR),
                           .data_rx_code(data_rx_code), .tx_en(tx_en_code), .data_tx_code(data_tx_code), .state(pair_state), .player(player));

    package_game_data game_inst (.clk(clk), .btnL(btnL), .btnR(btnR), .btnC(btnC), .btnU(btnU), .btnD(btnD), .sw(sw[7:0]),
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
    wire rst_game = sw[15]; // Connect to a switch so you can trigger generation
    lfsr_rng random_unit(.clk(basys_clk), .rnd(random_seed), .reset(1'b0));
    parameter three_quarter = 192;
    
    reg [1:0] gen_state = `RESET; 
    reg [3:0] tx = 0, ty = 0;
    parameter WALL_COLOR = `OLED_WHITE;
        
        
        
    // =========================================================
    // MAP STORAGE & CONSOLIDATED DRIVER
    // =========================================================
    
    reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];
    reg [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat;
    
    
    // flattening (Combinational Only)
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
            `MAP_BOMB:    expand_tile = (local_x >= 2 && local_x <= 3 && local_y >= 2 && local_y <= 3) ? `OLED_ORANGE : `OLED_BLACK;
            `MAP_POWERUP: expand_tile = `OLED_MAGENTA;
            default:      expand_tile = `OLED_BLACK;
        endcase
    end
    endfunction

    
    
    // =========================================================
    // MOUSE
    // =========================================================
    
    wire [11:0] mouse_xpos, mouse_ypos;
    wire [3:0] mouse_zpos;
    wire mouse_left, mouse_middle, mouse_right, mouse_new_event;
    
    reg mouse_setmax_x = 0, mouse_setmax_y = 0, mouse_setx = 0, mouse_sety = 0;
    reg [11:0] mouse_value = 0;
    reg [1:0] mouse_init_state = 0;
    
    wire [3:0] mouse_tx = (mouse_xpos >= `MIN_PIX_X && mouse_xpos <= `MAX_PIX_X) ? ((mouse_xpos - `MIN_PIX_X) * 7'd43) >> 8 : 4'hF;
    wire [3:0] mouse_ty = (mouse_ypos >= `MIN_PIX_Y && mouse_ypos <= `MAX_PIX_Y) ? ((mouse_ypos - `MIN_PIX_Y) * 7'd43) >> 8 : 4'hF;
    
    // one-time initialisation to set max x=95, max y=63
    always @(posedge clk) begin
        mouse_setmax_x <= 0;
        mouse_setmax_y <= 0;
        case (mouse_init_state)
            0: begin
                mouse_value <= 12'd95;   // max x = 95 (96 pixels wide)
                mouse_setmax_x <= 1;
                mouse_init_state <= 1;
            end
            1: begin
                mouse_value    <= 12'd63;   // max y = 63 (64 pixels tall)
                mouse_setmax_y <= 1;
                mouse_init_state <= 2;
            end
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
    
    // register pulses
    reg mouse_left_prev = 0, mouse_right_prev = 0, mouse_middle_prev = 0;
    wire mouse_left_pulse = mouse_left & ~mouse_left_prev;  // single cycle on press
    wire mouse_right_pulse = mouse_right & ~mouse_right_prev;  // single cycle on press
    wire mouse_middle_pulse = mouse_middle & ~mouse_middle_prev;  // single cycle on press
    
    always @ (posedge clk) begin
        mouse_left_prev <= mouse_left;
        mouse_right_prev <= mouse_right;
        mouse_middle_prev <= mouse_middle;
    end
    
    
    
    // =========================================================
    // PLAYER AND COMPUTER CONTROLLERS
    // =========================================================
    
    
    
    reg map_changed = 0;
                              
    wire [6:0] p1_x;
    wire [5:0] p1_y;
    wire [3:0] p1_tx, p1_ty;
    wire p1_dead;
    
    wire p1_place_bomb_req, p1_clear_bomb_req, p1_destroy_up_req, p1_destroy_down_req, p1_destroy_left_req, p1_destroy_right_req;
    wire [3:0] p1_place_bomb_tx, p1_place_bomb_ty, p1_clear_bomb_tx, p1_clear_bomb_ty, p1_destroy_up_tx, p1_destroy_up_ty,
               p1_destroy_down_tx, p1_destroy_down_ty, p1_destroy_left_tx, p1_destroy_left_ty, p1_destroy_right_tx, p1_destroy_right_ty;
    
    wire p1_bomb_active, p1_bomb_red;
    wire [3:0] p1_bomb_tx, p1_bomb_ty;
    
    wire p1_explosion_active;
    wire [3:0] p1_explosion_stage, p1_explode_up_len, p1_explode_down_len, p1_explode_left_len, p1_explode_right_len;
    
    wire p1_update, p1_baw, p1_valid;
    wire [4*`MAX_PATH_LEN-1:0] p1_pfx, p1_pfy;
    wire [6:0] p1_len;
    
    reg [3:0] p1_goal_tx = 0, p1_goal_ty = 0;
            
    always @ (posedge clk) begin
        if (mouse_left_pulse) begin
            p1_goal_tx <= mouse_tx;
            p1_goal_ty <= mouse_ty;
        end
    end
    
//    player_one_controller p12_ctrl_inst (
//      .clk(clk),
//      .goal_tx(p1_goal_tx),
//      .goal_ty(p1_goal_ty),
//      .mouse_left_pulse(mouse_left_pulse),
//      .mouse_right_pulse(mouse_right_pulse),
//      .mouse_middle_pulse(mouse_middle_pulse),
//      .tile_map_flat(tile_map_flat),
//      .speed_multiplier(sw[1:0]),
//      .map_changed(map_changed),
      
//      .p1_tx(p1_tx),
//      .p1_ty(p1_ty),
//      .p1_x(p1_x),
//      .p1_y(p1_y),
//      .p1_dead(p1_dead),

//      .place_bomb_req(p1_place_bomb_req),
//      .place_bomb_tx(p1_place_bomb_tx),
//      .place_bomb_ty(p1_place_bomb_ty),
//      .clear_bomb_req(p1_clear_bomb_req),
//      .clear_bomb_tx(p1_clear_bomb_tx),
//      .clear_bomb_ty(p1_clear_bomb_ty),
//      .destroy_up_req(p1_destroy_up_req),
//      .destroy_up_tx(p1_destroy_up_tx),
//      .destroy_up_ty(p1_destroy_up_ty),
//      .destroy_down_req(p1_destroy_down_req),
//      .destroy_down_tx(p1_destroy_down_tx),
//      .destroy_down_ty(p1_destroy_down_ty),
//      .destroy_left_req(p1_destroy_left_req),
//      .destroy_left_tx(p1_destroy_left_tx),
//      .destroy_left_ty(p1_destroy_left_ty),
//      .destroy_right_req(p1_destroy_right_req),
//      .destroy_right_tx(p1_destroy_right_tx),
//      .destroy_right_ty(p1_destroy_right_ty),
      
//      .bomb_active(p1_bomb_active),
//      .bomb_tx(p1_bomb_tx),
//      .bomb_ty(p1_bomb_ty),
//      .bomb_red(p1_bomb_red),
      
//      .explosion_active(p1_explosion_active),
//      .explosion_stage(p1_explosion_stage),
//      .explode_up_len(p1_explode_up_len),
//      .explode_down_len(p1_explode_down_len),
//      .explode_left_len(p1_explode_left_len),
//      .explode_right_len(p1_explode_right_len),
      
//      .update(p1_update),
//      .blocks_as_walls(p1_baw),
//      .path_flat_x(p1_pfx),
//      .path_flat_y(p1_pfy),
//      .path_valid(p1_valid),
//      .path_len(p1_len)
//  );                          

    player_controller p1_ctrl_inst (
        .clk(clk),
        .player_number(`PLAYER_1),
        .goal_tx(p1_goal_tx),
        .goal_ty(p1_goal_ty),
        .mouse_left_pulse(mouse_left_pulse),
        .mouse_right_pulse(mouse_right_pulse),
        .mouse_middle_pulse(mouse_middle_pulse),
        .tile_map_flat(tile_map_flat),
        .speed_multiplier(sw[1:0]),
        .map_changed(map_changed),
        
        .player_tx(p1_tx),
        .player_ty(p1_ty),
        .player_x(p1_x),
        .player_y(p1_y),
        .player_dead(p1_dead),

        .place_bomb_req(p1_place_bomb_req),
        .place_bomb_tx(p1_place_bomb_tx),
        .place_bomb_ty(p1_place_bomb_ty),
        .clear_bomb_req(p1_clear_bomb_req),
        .clear_bomb_tx(p1_clear_bomb_tx),
        .clear_bomb_ty(p1_clear_bomb_ty),
        .destroy_up_req(p1_destroy_up_req),
        .destroy_up_tx(p1_destroy_up_tx),
        .destroy_up_ty(p1_destroy_up_ty),
        .destroy_down_req(p1_destroy_down_req),
        .destroy_down_tx(p1_destroy_down_tx),
        .destroy_down_ty(p1_destroy_down_ty),
        .destroy_left_req(p1_destroy_left_req),
        .destroy_left_tx(p1_destroy_left_tx),
        .destroy_left_ty(p1_destroy_left_ty),
        .destroy_right_req(p1_destroy_right_req),
        .destroy_right_tx(p1_destroy_right_tx),
        .destroy_right_ty(p1_destroy_right_ty),
        
        .bomb_active(p1_bomb_active),
        .bomb_tx(p1_bomb_tx),
        .bomb_ty(p1_bomb_ty),
        .bomb_red(p1_bomb_red),
        
        .explosion_active(p1_explosion_active),
        .explosion_stage(p1_explosion_stage),
        .explode_up_len(p1_explode_up_len),
        .explode_down_len(p1_explode_down_len),
        .explode_left_len(p1_explode_left_len),
        .explode_right_len(p1_explode_right_len),
        
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
    wire p2_dead;
    
    wire p2_place_bomb_req, p2_clear_bomb_req, p2_destroy_up_req, p2_destroy_down_req, p2_destroy_left_req, p2_destroy_right_req;
    wire [3:0] p2_place_bomb_tx, p2_place_bomb_ty, p2_clear_bomb_tx, p2_clear_bomb_ty, p2_destroy_up_tx, p2_destroy_up_ty,
               p2_destroy_down_tx, p2_destroy_down_ty, p2_destroy_left_tx, p2_destroy_left_ty, p2_destroy_right_tx, p2_destroy_right_ty;
    
    wire p2_bomb_active, p2_bomb_red;
    wire [3:0] p2_bomb_tx, p2_bomb_ty;
    
    wire p2_explosion_active;
    wire [3:0] p2_explosion_stage, p2_explode_up_len, p2_explode_down_len, p2_explode_left_len, p2_explode_right_len;
    
    wire [11:0] p2_mouse_xpos, p2_mouse_ypos;
    wire p2_mouse_left, p2_mouse_middle, p2_mouse_right;
    
    wire [3:0] p2_mouse_tx = (p2_mouse_xpos >= `MIN_PIX_X && p2_mouse_xpos <= `MAX_PIX_X) ? ((p2_mouse_xpos - `MIN_PIX_X) * 7'd43) >> 8 : 4'hF;
    wire [3:0] p2_mouse_ty = (p2_mouse_ypos >= `MIN_PIX_Y && p2_mouse_ypos <= `MAX_PIX_Y) ? ((p2_mouse_ypos - `MIN_PIX_Y) * 7'd43) >> 8 : 4'hF;
    
    wire p2_update, p2_baw, p2_valid;
    wire [4*`MAX_PATH_LEN-1:0] p2_pfx, p2_pfy;
    wire [6:0] p2_len;
    
    // register pulses
    reg p2_mouse_left_prev = 0, p2_mouse_right_prev = 0, p2_mouse_middle_prev = 0;
    wire p2_mouse_left_pulse = p2_mouse_left & ~p2_mouse_left_prev;  // single cycle on press
    wire p2_mouse_right_pulse = p2_mouse_right & ~p2_mouse_right_prev;  // single cycle on press
    wire p2_mouse_middle_pulse = p2_mouse_middle & ~p2_mouse_middle_prev;  // single cycle on press
    
    always @ (posedge clk) begin
        p2_mouse_left_prev <= p2_mouse_left;
        p2_mouse_right_prev <= p2_mouse_right;
        p2_mouse_middle_prev <= p2_mouse_middle;
    end
    
    reg [3:0] p2_player_goal_tx = 0, p2_player_goal_ty = 0;
    
    wire single_player = (pair_state == `SINGLE);
  
    wire [3:0] p2_goal_tx = single_player ? p1_tx : p2_player_goal_tx; 
    wire [3:0] p2_goal_ty = single_player ? p1_ty : p2_player_goal_ty; 

    always @ (posedge clk) begin
        if (p2_mouse_left_pulse) begin
            p2_player_goal_tx <= p2_mouse_tx;
            p2_player_goal_ty <= p2_mouse_ty;
        end
    end
    
    player_two_controller p2_ctrl_inst (
        .clk(clk),
        .single_player(single_player),
        .goal_tx(p2_goal_tx),
        .goal_ty(p2_goal_ty),
        .mouse_left_pulse(p2_mouse_left_pulse),
        .mouse_right_pulse(p2_mouse_right_pulse),
        .mouse_middle_pulse(p2_mouse_middle_pulse),
        .tile_map_flat(tile_map_flat),
        .speed_multiplier(sw[1:0]),
        .map_changed(map_changed),
        
        .player_tx(p2_tx),
        .player_ty(p2_ty),
        .player_x(p2_x),
        .player_y(p2_y),
        .player_dead(p2_dead),

        .place_bomb_req(p2_place_bomb_req),
        .place_bomb_tx(p2_place_bomb_tx),
        .place_bomb_ty(p2_place_bomb_ty),
        .clear_bomb_req(p2_clear_bomb_req),
        .clear_bomb_tx(p2_clear_bomb_tx),
        .clear_bomb_ty(p2_clear_bomb_ty),
        .destroy_up_req(p2_destroy_up_req),
        .destroy_up_tx(p2_destroy_up_tx),
        .destroy_up_ty(p2_destroy_up_ty),
        .destroy_down_req(p2_destroy_down_req),
        .destroy_down_tx(p2_destroy_down_tx),
        .destroy_down_ty(p2_destroy_down_ty),
        .destroy_left_req(p2_destroy_left_req),
        .destroy_left_tx(p2_destroy_left_tx),
        .destroy_left_ty(p2_destroy_left_ty),
        .destroy_right_req(p2_destroy_right_req),
        .destroy_right_tx(p2_destroy_right_tx),
        .destroy_right_ty(p2_destroy_right_ty),
        
        .bomb_active(p2_bomb_active),
        .bomb_tx(p2_bomb_tx),
        .bomb_ty(p2_bomb_ty),
        .bomb_red(p2_bomb_red),
        
        .explosion_active(p2_explosion_active),
        .explosion_stage(p2_explosion_stage),
        .explode_up_len(p2_explode_up_len),
        .explode_down_len(p2_explode_down_len),
        .explode_left_len(p2_explode_left_len),
        .explode_right_len(p2_explode_right_len),
        
        .update(p2_update),
        .blocks_as_walls(p2_baw),
        .path_flat_x(p2_pfx),
        .path_flat_y(p2_pfy),
        .path_valid(p2_valid),
        .path_len(p2_len)
    );
    
    wire [6:0] comp_x;
    wire [5:0] comp_y;
    wire [3:0] comp_tx, comp_ty;
    wire comp_dead;
    
    wire comp_place_bomb_req, comp_clear_bomb_req, comp_destroy_up_req, comp_destroy_down_req, comp_destroy_left_req, comp_destroy_right_req;
    wire [3:0] comp_place_bomb_tx, comp_place_bomb_ty, comp_clear_bomb_tx, comp_clear_bomb_ty, comp_destroy_up_tx, comp_destroy_up_ty,
               comp_destroy_down_tx, comp_destroy_down_ty, comp_destroy_left_tx, comp_destroy_left_ty, comp_destroy_right_tx, comp_destroy_right_ty;
    
    wire comp_bomb_active, comp_bomb_red;
    wire [3:0] comp_bomb_tx, comp_bomb_ty;
    
    wire comp_explosion_active;
    wire [3:0] comp_explosion_stage, comp_explode_up_len, comp_explode_down_len, comp_explode_left_len, comp_explode_right_len;
    
    
    wire comp_update, comp_baw, comp_valid;
    wire [4*`MAX_PATH_LEN-1:0] comp_pfx, comp_pfy;
    wire [6:0] comp_len;
    
    a_star_mux as_mux_inst (.clk(clk),
                            .tile_map_flat(tile_map_flat),
                            .c0_update(p1_update), 
                            .c0_baw(p1_baw), 
                            .c0_stx(p1_tx), 
                            .c0_sty(p1_ty), 
                            .c0_gtx(p1_goal_tx), 
                            .c0_gty(p1_goal_ty),
                            .c0_pfx(p1_pfx), 
                            .c0_pfy(p1_pfy),
                            .c0_valid(p1_valid), 
                            .c0_len(p1_len),
                           
                            .c1_update(comp_update), 
                            .c1_baw(comp_baw),
                            .c1_stx(comp_tx), 
                            .c1_sty(comp_ty), 
                            .c1_gtx(p1_tx), 
                            .c1_gty(p1_ty),
                            .c1_pfx(comp_pfx), 
                            .c1_pfy(comp_pfy),
                            .c1_valid(comp_valid),
                            .c1_len(comp_len));

//    wire nib, nib2;
//    movement_controller computer_inst (.clk(clk),
////                              .led(0),
//                              .map_changed(map_changed),
//                            .spawn_tx(14), 
//                            .spawn_ty(8),
//                            .goal_tx(p1_tx), .goal_ty(p1_ty), // player for computer, mouse for player 
////                            .goal_tx(p1_goal_tx), .goal_ty(p1_goal_ty), // player for computer, mouse for player 
//                            .tile_map_flat(tile_map_flat), .speed(30),
//                            .is_player(0),
//                            .next_is_block(nib),
//                            .pos_tx_out(comp_tx), .pos_ty_out(comp_ty),
//                            .pos_x(comp_x), .pos_y(comp_y),
//                            .as_update(comp_update), .as_baw(comp_baw), 
//                            .path_flat_x(comp_pfx), .path_flat_y(comp_pfy),
//                            .path_valid(comp_valid), // fast
//                            .path_len(comp_len));
    
//    movement_controller player_inst (.clk(clk),
////                              .led(led),
//                              .map_changed(map_changed),
//                            .spawn_tx(0), 
//                            .spawn_ty(0),
////                            .goal_tx(comp_tx), .goal_ty(comp_ty), // player for computer, mouse for player 
//                            .goal_tx(p1_goal_tx), .goal_ty(p1_goal_ty), // player for computer, mouse for player 
//                            .tile_map_flat(tile_map_flat), .speed(30),
//                            .is_player(1),
//                            .next_is_block(nib2),
//                            .pos_tx_out(p1_tx), .pos_ty_out(p1_ty),
//                            .pos_x(p1_x), .pos_y(p1_y),
//                            .as_update(p1_update), .as_baw(p1_baw), 
//                            .path_flat_x(p1_pfx), .path_flat_y(p1_pfy),
//                            .path_valid(p1_valid), // fast
//                            .path_len(p1_len));
    
    computer_controller comp_ctrl_inst (
        .clk(clk),
        .goal_tx(p1_tx),
        .goal_ty(p1_ty),
        .tile_map_flat(tile_map_flat),
        .speed_multiplier(sw[1:0]),
        .map_changed(map_changed),
        
        .computer_tx(comp_tx),
        .computer_ty(comp_ty),
        .computer_x(comp_x),
        .computer_y(comp_y),
        .computer_dead(comp_dead),

        .place_bomb_req(comp_place_bomb_req),
        .place_bomb_tx(comp_place_bomb_tx),
        .place_bomb_ty(comp_place_bomb_ty),
        .clear_bomb_req(comp_clear_bomb_req),
        .clear_bomb_tx(comp_clear_bomb_tx),
        .clear_bomb_ty(comp_clear_bomb_ty),
        .destroy_up_req(comp_destroy_up_req),
        .destroy_up_tx(comp_destroy_up_tx),
        .destroy_up_ty(comp_destroy_up_ty),
        .destroy_down_req(comp_destroy_down_req),
        .destroy_down_tx(comp_destroy_down_tx),
        .destroy_down_ty(comp_destroy_down_ty),
        .destroy_left_req(comp_destroy_left_req),
        .destroy_left_tx(comp_destroy_left_tx),
        .destroy_left_ty(comp_destroy_left_ty),
        .destroy_right_req(comp_destroy_right_req),
        .destroy_right_tx(comp_destroy_right_tx),
        .destroy_right_ty(comp_destroy_right_ty),
        
        .bomb_active(comp_bomb_active),
        .bomb_tx(comp_bomb_tx),
        .bomb_ty(comp_bomb_ty),
        .bomb_red(comp_bomb_red),
        
        .explosion_active(comp_explosion_active),
        .explosion_stage(comp_explosion_stage),
        .explode_up_len(comp_explode_up_len),
        .explode_down_len(comp_explode_down_len),
        .explode_left_len(comp_explode_left_len),
        .explode_right_len(comp_explode_right_len),
        
        .update(comp_update),
        .blocks_as_walls(comp_baw),
        .path_flat_x(comp_pfx),
        .path_flat_y(comp_pfy),
        .path_valid(comp_valid),
        .path_len(comp_len)
    );



    // =========================================================
    // TILE MAP UPDATES
    // =========================================================
    
    
    
    always @(posedge clk)
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
                else if (tx == 0 && (ty == 0 || ty == 1)) tile_map[tx][ty] <= `MAP_EMPTY;
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
                map_changed <= p1_place_bomb_req | p1_clear_bomb_req | p1_destroy_up_req | p1_destroy_down_req | p1_destroy_left_req | p1_destroy_right_req | 
                               p2_place_bomb_req | p2_clear_bomb_req | p2_destroy_up_req | p2_destroy_down_req | p2_destroy_left_req | p2_destroy_right_req |
                               comp_place_bomb_req | comp_clear_bomb_req | comp_destroy_up_req | comp_destroy_down_req | comp_destroy_left_req | comp_destroy_right_req;
                  
                  
                // player 1
                if (p1_place_bomb_req) tile_map[p1_place_bomb_tx][p1_place_bomb_ty] <= `MAP_BOMB;
                if (p1_clear_bomb_req) tile_map[p1_clear_bomb_tx][p1_clear_bomb_ty] <= `MAP_EMPTY;
                    
                if (p1_destroy_up_req && tile_map[p1_destroy_up_tx][p1_destroy_up_ty] == `MAP_BLOCK) begin
                    if (random_seed[7:0] > three_quarter) tile_map[p1_destroy_up_tx][p1_destroy_up_ty] <= `MAP_EMPTY;
                    else tile_map[p1_destroy_up_tx][p1_destroy_up_ty] <= `MAP_POWERUP;
                end
                if (p1_destroy_down_req && tile_map[p1_destroy_down_tx][p1_destroy_down_ty] == `MAP_BLOCK) begin
                    if (random_seed[7:0] > three_quarter) tile_map[p1_destroy_down_tx][p1_destroy_down_ty] <= `MAP_EMPTY;
                    else tile_map[p1_destroy_down_tx][p1_destroy_down_ty] <= `MAP_POWERUP;
                end
                if (p1_destroy_left_req && tile_map[p1_destroy_left_tx][p1_destroy_left_ty] == `MAP_BLOCK) begin
                    if (random_seed[7:0] > three_quarter) tile_map[p1_destroy_left_tx][p1_destroy_left_ty] <= `MAP_EMPTY;
                    else tile_map[p1_destroy_left_tx][p1_destroy_left_ty] <= `MAP_POWERUP;
                end
                if (p1_destroy_right_req && tile_map[p1_destroy_right_tx][p1_destroy_right_ty] == `MAP_BLOCK) begin
                    if (random_seed[7:0] > three_quarter) tile_map[p1_destroy_right_tx][p1_destroy_right_ty] <= `MAP_EMPTY;
                    else tile_map[p1_destroy_right_tx][p1_destroy_right_ty] <= `MAP_POWERUP;
                end
                
                // computer
                if (comp_place_bomb_req) tile_map[comp_place_bomb_tx][comp_place_bomb_ty] <= `MAP_BOMB;
                if (comp_clear_bomb_req) tile_map[comp_clear_bomb_tx][comp_clear_bomb_ty] <= `MAP_EMPTY;
                   
                if (comp_destroy_up_req && tile_map[comp_destroy_up_tx][comp_destroy_up_ty] == `MAP_BLOCK) begin
                    if (random_seed[7:0] > three_quarter) tile_map[comp_destroy_up_tx][comp_destroy_up_ty] <= `MAP_EMPTY;
                    else tile_map[comp_destroy_up_tx][comp_destroy_up_ty] <= `MAP_POWERUP;
                end
                if (comp_destroy_down_req && tile_map[comp_destroy_down_tx][comp_destroy_down_ty] == `MAP_BLOCK) begin
                    if (random_seed[7:0] > three_quarter) tile_map[comp_destroy_down_tx][comp_destroy_down_ty] <= `MAP_EMPTY;
                    else tile_map[comp_destroy_down_tx][comp_destroy_down_ty] <= `MAP_POWERUP;
                end
                if (comp_destroy_left_req && tile_map[comp_destroy_left_tx][comp_destroy_left_ty] == `MAP_BLOCK) begin
                    if (random_seed[7:0] > three_quarter) tile_map[comp_destroy_left_tx][comp_destroy_left_ty] <= `MAP_EMPTY;
                    else tile_map[comp_destroy_left_tx][comp_destroy_left_ty] <= `MAP_POWERUP;
                end
                if (comp_destroy_right_req && tile_map[comp_destroy_right_tx][comp_destroy_right_ty] == `MAP_BLOCK) begin
                    if (random_seed[7:0] > three_quarter) tile_map[comp_destroy_right_tx][comp_destroy_right_ty] <= `MAP_EMPTY;
                    else tile_map[comp_destroy_right_tx][comp_destroy_right_ty] <= `MAP_POWERUP;
                end
            end
        endcase
    
   

    // =========================================================
    // SINGLE PLAYER OLED OVERLAY
    // =========================================================
    wire p1_region = (x >= p1_x) && (x < p1_x + `PLAYER_WIDTH) && (y >= p1_y) && (y < p1_y + `PLAYER_WIDTH);
    wire comp_region = (x >= comp_x) && (x < comp_x + `PLAYER_WIDTH) && (y >= comp_y) && (y < comp_y + `PLAYER_WIDTH);
    
    // lamped mouse cursor position
    wire [6:0] mouse_cx = (mouse_xpos[6:0] < 1) ? 1 : (mouse_xpos[6:0] > 94) ? 94 : mouse_xpos[6:0];
    wire [5:0] mouse_cy = (mouse_ypos[5:0] < 1) ? 1 : (mouse_ypos[5:0] > 62) ? 62 : mouse_ypos[5:0];
    
    wire mouse_region = (x >= mouse_cx - 1) && (x <= mouse_cx + 1) && (y >= mouse_cy - 1) && (y <= mouse_cy + 1);
//    wire mouse_region = (x >= mouse_xpos[6:0] - 1) && (x <= mouse_xpos[6:0] + 1) && (y >= mouse_ypos[5:0] - 1) && (y <= mouse_ypos[5:0] + 1);
       
    wire [3:0] tile_x_of_pixel = (x >= `MIN_PIX_X && x <= `MAX_PIX_X) ? ((x - `MIN_PIX_X) * 7'd43) >> 8 : 4'hF; // replace divider with reciprocal multiply + shift
    wire [3:0] tile_y_of_pixel = (y >= `MIN_PIX_Y && y <= `MAX_PIX_Y) ? ((y - `MIN_PIX_Y) * 7'd43) >> 8 : 4'hF;
    wire [2:0] local_x = (tile_x_of_pixel == 4'hF) ? 0 : (x - `MIN_PIX_X - tile_x_of_pixel * 6);
    wire [2:0] local_y = (tile_y_of_pixel == 4'hF) ? 0 : (y - `MIN_PIX_Y - tile_y_of_pixel * 6);
    
    always @(*) begin
        if (tile_x_of_pixel == 4'hF || tile_y_of_pixel == 4'hF) oled_data_single = `OLED_ORANGE;
        else oled_data_single = expand_tile(tile_map[tile_x_of_pixel][tile_y_of_pixel], local_x, local_y);

        // player 1 bomb and explosion
        if (p1_bomb_active) begin
            if (tile_x_of_pixel == p1_bomb_tx && tile_y_of_pixel == p1_bomb_ty)
                oled_data_single = p1_bomb_red ? `OLED_RED : `OLED_ORANGE;
        end

        if (p1_explosion_active) begin
            if (tile_x_of_pixel == p1_bomb_tx && tile_y_of_pixel == p1_bomb_ty)
                oled_data_single = `OLED_YELLOW;

            if ((p1_explosion_stage <= p1_explode_up_len) &&
                tile_x_of_pixel == p1_bomb_tx && tile_y_of_pixel == p1_bomb_ty-p1_explosion_stage)
                oled_data_single = `OLED_YELLOW;

            if ((p1_explosion_stage <= p1_explode_down_len) &&
                tile_x_of_pixel == p1_bomb_tx && tile_y_of_pixel == p1_bomb_ty+p1_explosion_stage)
                oled_data_single = `OLED_YELLOW;

            if ((p1_explosion_stage <= p1_explode_left_len) &&
                tile_x_of_pixel == p1_bomb_tx-p1_explosion_stage && tile_y_of_pixel == p1_bomb_ty)
                oled_data_single = `OLED_YELLOW;

            if ((p1_explosion_stage <= p1_explode_right_len) &&
                tile_x_of_pixel == p1_bomb_tx+p1_explosion_stage && tile_y_of_pixel == p1_bomb_ty)
                oled_data_single = `OLED_YELLOW;
        end
        
        // computer bomb and explosion
        if (comp_bomb_active) begin
            if (tile_x_of_pixel == comp_bomb_tx && tile_y_of_pixel == comp_bomb_ty)
                oled_data_single = comp_bomb_red ? `OLED_RED : `OLED_ORANGE;
        end

        if (comp_explosion_active) begin
            if (tile_x_of_pixel == comp_bomb_tx && tile_y_of_pixel == comp_bomb_ty)
                oled_data_single = `OLED_YELLOW;

            if ((comp_explosion_stage <= comp_explode_up_len) &&
                tile_x_of_pixel == comp_bomb_tx && tile_y_of_pixel == comp_bomb_ty-comp_explosion_stage)
                oled_data_single = `OLED_YELLOW;

            if ((comp_explosion_stage <= comp_explode_down_len) &&
                tile_x_of_pixel == comp_bomb_tx && tile_y_of_pixel == comp_bomb_ty+comp_explosion_stage)
                oled_data_single = `OLED_YELLOW;

            if ((comp_explosion_stage <= comp_explode_left_len) &&
                tile_x_of_pixel == comp_bomb_tx-comp_explosion_stage && tile_y_of_pixel == comp_bomb_ty)
                oled_data_single = `OLED_YELLOW;

            if ((comp_explosion_stage <= comp_explode_right_len) &&
                tile_x_of_pixel == comp_bomb_tx+comp_explosion_stage && tile_y_of_pixel == comp_bomb_ty)
                oled_data_single = `OLED_YELLOW;
        end


        // player
        if (comp_region) oled_data_single = `OLED_RED; //comp_dead ? `OLED_PINK : `OLED_RED;
        if (p1_region) oled_data_single = `OLED_BLUE; //p1_dead ? `OLED_CYAN : `OLED_BLUE;
        
        // draw walls
        if (x < `MIN_PIX_X || x > `MAX_PIX_X || y < `MIN_PIX_Y || y > `MAX_PIX_Y) oled_data_single = WALL_COLOR;
        if (mouse_region) oled_data_single = `OLED_ORANGE;
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
