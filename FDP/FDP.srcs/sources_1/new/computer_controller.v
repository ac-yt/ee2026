`timescale 1ns / 1ps

`include "constants.vh"

module computer_controller(input clk,
                           input [3:0] player_tx,
                           input [3:0] player_ty,
                           input bomb_active, explosion_active,
                           // input [3:0] bomb_radius,
                           // input [6:0] x,
                           // input [5:0] y,
                           input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                           output reg [6:0] computer_x=`MIN_PIX_X + 1,
                           output reg [5:0] computer_y=`MIN_PIX_Y + 1);
                           // output reg [15:0] oled_path=0);
    // A* clock
   wire clk_a_star;
   variable_clock #(.CLOCK_SPEED(`CLOCK_SPEED), .OUT_SPEED(`PATH_SPEED)) clk_inst (.clk(clk), .clk_out(clk_a_star));

    reg update_path = 0;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_x;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_y;
    wire [6:0] path_len;
    wire path_valid;
    // wire [10:0] path_cost;
    reg [3:0] path_x [0:`MAX_PATH_LEN-1];
    reg [3:0] path_y [0:`MAX_PATH_LEN-1];
    
    // path_valid check (2FF synchronizer)
    reg path_valid_ff1 = 0, path_valid_ff2 = 0, path_valid_ff2_prev = 0;
    always @(posedge clk) begin
        path_valid_ff1 <= path_valid;
        path_valid_ff2 <= path_valid_ff1;
        path_valid_ff2_prev <= path_valid_ff2;
    end
    wire path_valid_sync_pulse = path_valid_ff2 & ~path_valid_ff2_prev; // single-cycle pulse in fast domain when path_valid safely rises
   
    // computer movement tick
    parameter integer COMPUTER_COUNT  = `CLOCK_SPEED / `COMPUTER_SPEED;
    reg [$clog2(COMPUTER_COUNT)-1:0] computer_counter = 0;
    wire computer_move_tick = (computer_counter == COMPUTER_COUNT - 1);
    always @(posedge clk) begin
        if (computer_counter == COMPUTER_COUNT - 1) computer_counter <= 0;
        else computer_counter <= computer_counter + 1;
    end
    
    // FOLLOW PATH
    // wires for path following algo
    reg [6:0] path_step = 0;
    wire [3:0] computer_tx = ((computer_x - 1 - `MIN_PIX_X) * 7'd43) >> 8; // replace divide by reciprocal multiply + shift 1/6 ~ 43/256
    wire [3:0] computer_ty = ((computer_y - 1 - `MIN_PIX_Y) * 7'd43) >> 8; // uses the top left to see
//    wire [3:0] computer_tx = (computer_x - 1 - `MIN_PIX_X) / `TILE_SIZE;
//    wire [3:0] computer_ty = (computer_y - 1 - `MIN_PIX_Y) / `TILE_SIZE;
    
    wire [3:0] target_tx = (path_step < path_len) ? path_x[path_step] : computer_tx;
    wire [3:0] target_ty = (path_step < path_len) ? path_y[path_step] : computer_ty;
    wire [6:0] target_px = `MIN_PIX_X + target_tx * `TILE_SIZE + 1;
    wire [5:0] target_py = `MIN_PIX_Y + target_ty * `TILE_SIZE + 1;
//    wire [6:0] target_px = `MIN_PIX_X + (target_tx << 2) + (target_tx << 1) + 1; // center of target tile
//    wire [5:0] target_py = `MIN_PIX_Y + (target_ty << 2) + (target_ty << 1) + 1;

    // pre-register movement decisions
    reg move_right_r=0, move_left_r=0, move_down_r=0, move_up_r=0;
    always @(posedge clk) begin
        move_right_r <= (computer_x < target_px);
        move_left_r  <= (computer_x > target_px);
        move_down_r  <= (computer_x == target_px && computer_y < target_py);
        move_up_r    <= (computer_x == target_px && computer_y > target_py);
    end
    
    always @(posedge clk) begin
        if (computer_move_tick && path_len > 0) begin
            if      (move_right_r) computer_x <= computer_x + 1;
            else if (move_left_r)  computer_x <= computer_x - 1;
            else if (move_down_r)  computer_y <= computer_y + 1;
            else if (move_up_r)    computer_y <= computer_y - 1;
    
            if (computer_x == target_px && computer_y == target_py &&
                path_step < path_len - 1)
                path_step <= path_step + 1;
        end
        if (path_valid_sync_pulse) path_step <= 0;
//        if (path_valid) path_step <= 0;
    end
  
    // path following
    /*always @ (posedge clk) begin
        if (computer_move_tick && path_len > 0) begin
            if (computer_x < target_px) computer_x <= computer_x + 1;
            else if (computer_x > target_px) computer_x <= computer_x - 1;
            else if (computer_y < target_py) computer_y <= computer_y + 1;
            else if (computer_y > target_py) computer_y <= computer_y - 1;
 
            if (computer_x == target_px && computer_y == target_py && path_step < path_len - 1)
                path_step <= path_step + 1;
        end
        
        // if (path_valid_sync_pulse) path_step <= (path_len > 1) ? 1 : 0;
        if (path_valid_sync_pulse) path_step <= 0;
    end*/
    
    // update path every 1.2* time taken for computer to travel one tile
    reg [$clog2(`UPDATE_TIME)-1:0] update_counter = 0;
    always @ (posedge clk_a_star) begin
        if (update_counter == `UPDATE_TIME-1) begin
            update_counter <= 0;
            update_path <= 1;
        end
        else begin
            update_counter <= update_counter + 1;
            update_path <= 0;
        end
    end
    
    // capture and unpack path data on safe pulse
    // path_flat_x/y are stable before path_valid is asserted, safe to sample ~2 fast cycles later when the sync pulse fires
    integer i;
    always @(posedge clk) begin
//        if (path_valid) begin
        if (path_valid_sync_pulse) begin
            for (i = 0; i < `MAX_PATH_LEN; i = i+1) begin
                if (i < path_len) begin
                    path_x[i] <= path_flat_x[(`MAX_PATH_LEN-1-i)*4 +: 4];
                    path_y[i] <= path_flat_y[(`MAX_PATH_LEN-1-i)*4 +: 4];
//                    path_x[i] <= path_flat_x[(path_len-1-i)*4 +: 4];
//                    path_y[i] <= path_flat_y[(path_len-1-i)*4 +: 4];
                end
                else begin
                    path_x[i] <= 4'hF;
                    path_y[i] <= 4'hF;
                end
            end
        end
    end
    
//    // BOMB AVOIDANCE
//    reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];
//    integer ux, uy; // unpack map
//    always @(*) begin
//        for (uy = 0; uy < `TILE_MAP_HEIGHT; uy = uy + 1)
//            for (ux = 0; ux < `TILE_MAP_WIDTH; ux = ux + 1)
//                tile_map[ux][uy] = tile_map_flat[(uy*`TILE_MAP_WIDTH + ux)*3 +: 3];
//    end

//    function [2:0] get_tile;
//        input [3:0] tx;
//        input [3:0] ty;
//    begin
//        get_tile = tile_map[tx][ty];
//    end
//    endfunction
    
    // check if any adjacent tile or current tile has a bomb
//    wire bomb_at_curr  = get_tile(computer_tx, computer_ty)     == `MAP_BOMB;
//    wire bomb_at_up    = (computer_ty > 0)                    && get_tile(computer_tx,     computer_ty - 1) == `MAP_BOMB;
//    wire bomb_at_down  = (computer_ty < `TILE_MAP_HEIGHT - 1) && get_tile(computer_tx,     computer_ty + 1) == `MAP_BOMB;
//    wire bomb_at_left  = (computer_tx > 0)                    && get_tile(computer_tx - 1, computer_ty)     == `MAP_BOMB;
//    wire bomb_at_right = (computer_tx < `TILE_MAP_WIDTH - 1)  && get_tile(computer_tx + 1, computer_ty)     == `MAP_BOMB;
//    wire bomb_nearby = bomb_at_curr || bomb_at_up || bomb_at_down || bomb_at_left || bomb_at_right;
    
////    wire [4:0] dist_tl = computer_tx + computer_ty;
////    wire [4:0] dist_tr = (`TILE_MAP_WIDTH - 1 - computer_tx) + computer_ty;
////    wire [4:0] dist_bl = computer_tx + (`TILE_MAP_HEIGHT - 1 - computer_ty);
////    wire [4:0] dist_br = (`TILE_MAP_WIDTH - 1 - computer_tx) + (`TILE_MAP_HEIGHT - 1 - computer_ty);
    
//    // if bomb above/below run left/right, if bomb left/right run up/down, bomb on tile run to opposite corner
//    wire [3:0] flee_tx = (bomb_at_up || bomb_at_down) ? (computer_tx < `TILE_MAP_WIDTH/2 ? 14 : 0) : 
//                         (bomb_at_left || bomb_at_right) ? computer_tx : (`TILE_MAP_WIDTH - 1 - computer_tx);
//    wire [3:0] flee_ty = (bomb_at_up || bomb_at_down) ? computer_ty : 
//                         (bomb_at_left || bomb_at_right) ? (computer_ty < `TILE_MAP_HEIGHT/2 ? 8 : 0) : (`TILE_MAP_HEIGHT - 1 - computer_ty);
////    wire [3:0] flee_tx = (dist_tl >= dist_tr && dist_tl >= dist_bl && dist_tl >= dist_br) ? 0 :
////                         (dist_bl >= dist_tr && dist_bl >= dist_br) ? 0 : 14;
////    wire [3:0] flee_ty = (dist_tl >= dist_tr && dist_tl >= dist_bl && dist_tl >= dist_br) ? 0 :
////                         (dist_tr >= dist_bl && dist_tr >= dist_br) ? 0 : 8;
                         
//    reg [3:0] flee_tx_lat = 0, flee_ty_lat = 0;
    
////    wire [3:0] flee_tx = `TILE_MAP_WIDTH - 1 - computer_tx;
////    wire [3:0] flee_ty = `TILE_MAP_HEIGHT - 1 - computer_ty;
    
//    reg flee = 0;
//    always @ (posedge clk) begin
//        if (bomb_nearby) begin
//            flee <= 1;
//            flee_tx_lat <= flee_tx;
//            flee_ty_lat <= flee_ty;
//        end
//        else if (!bomb_active && !explosion_active) flee <= 0;
//    end
    
//    // ASSIGN GOAL
    wire [3:0] goal_tx = player_tx;
//    wire [3:0] goal_tx = flee ? flee_tx_lat : player_tx;
//    wire [3:0] goal_ty = flee ? flee_ty_lat : player_ty;
    wire [3:0] goal_ty = player_ty;
    
    reg [3:0] goal_tx_sync = 0, goal_ty_sync = 0;
    reg [3:0] computer_tx_sync = 0, computer_ty_sync = 0;
    always @ (posedge clk_a_star) begin // 1 FF synchronizer
        computer_tx_sync <= computer_tx;
        computer_ty_sync <= computer_ty;
        goal_tx_sync <= goal_tx;
        goal_ty_sync <= goal_ty;
    end
        
    // a_star instantiation (slow clock domain) runs on a divided clock, CDC is handled with a 2-FF synchronizer on path_valid
    a_star a_star_inst (
        .clk          (clk_a_star),
        .update       (update_path),
        .start_x      (computer_tx), //_sync),//(player_center_tx),
        .start_y      (computer_ty), //_sync),//(player_center_ty),
        .goal_x       (goal_tx), //_sync),
        .goal_y       (goal_ty), //_sync),
        .tile_map_flat(tile_map_flat),
        .path_flat_x  (path_flat_x),
        .path_flat_y  (path_flat_y),
        .path_len     (path_len),
        .path_valid   (path_valid)
        // .path_cost    (path_cost)
    );
endmodule
