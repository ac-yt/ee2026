`timescale 1ns / 1ps

`include "constants.vh"

module movement_controller (input clk,
                            input map_changed,
                            input [3:0] spawn_tx, spawn_ty,
                            input [3:0] goal_tx, goal_ty, // player for computer, mouse for player 
                            input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                            input [$clog2(`PLAYER_MAX_SPEED)-1:0] speed,
                            input is_player,
                            output next_is_block,
                            output [3:0] pos_tx_out, pos_ty_out,
                            output reg [6:0] pos_x,
                            output reg [5:0] pos_y);
    
    wire clk_a_star;
    variable_clock #(.CLOCK_SPEED(`CLOCK_SPEED), .OUT_SPEED(`PATH_SPEED)) clk_a_star_inst
                    (.clk(clk), .clk_out(clk_a_star));
 
    reg update_path = 0;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_x;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_y;
    wire [6:0] path_len;
    wire path_valid;
    reg [3:0] path_x [0:`MAX_PATH_LEN-1];
    reg [3:0] path_y [0:`MAX_PATH_LEN-1];
    
    // synchronise path_valid
    reg path_valid_ff1 = 0, path_valid_ff2 = 0, path_valid_ff2_prev = 0;
    always @(posedge clk) begin
        path_valid_ff1 <= path_valid;
        path_valid_ff2 <= path_valid_ff1;
        path_valid_ff2_prev <= path_valid_ff2;
    end
    wire path_valid_sync_pulse = path_valid_ff2 & ~path_valid_ff2_prev; // single-cycle pulse in fast domain when path_valid safely rises
    
    // move tick
    parameter integer MAX_MOVE_COUNT = `CLOCK_SPEED / `COMPUTER_DEFAULT_SPEED;
    wire [31:0] move_count_thresh = `CLOCK_SPEED / speed; // changes based on speed
    reg [$clog2(MAX_MOVE_COUNT)-1:0] move_counter = 0;
    wire move_tick = (move_counter == move_count_thresh - 1);
    always @(posedge clk) begin
        if (move_counter == move_count_thresh - 1) move_counter <= 0;
        else move_counter <= move_counter + 1;
    end
    
    // calculate target step
    reg [6:0] path_step = 0;
    wire [3:0] pos_tx = ((pos_x - 1 - `MIN_PIX_X) * 7'd43) >> 8; // replace divide by reciprocal multiply + shift 1/6 ~ 43/256
    wire [3:0] pos_ty = ((pos_y - 1 - `MIN_PIX_Y) * 7'd43) >> 8; // uses the top left to see
    wire [3:0] target_tx = (path_step < path_len) ? path_x[path_step] : pos_tx;
    wire [3:0] target_ty = (path_step < path_len) ? path_y[path_step] : pos_ty;
    wire [6:0] target_x = `MIN_PIX_X + target_tx * `TILE_SIZE + 1;
    wire [5:0] target_y = `MIN_PIX_Y + target_ty * `TILE_SIZE + 1;
    
    assign pos_tx_out = pos_tx;
    assign pos_ty_out = pos_ty;
    assign next_is_block = tile_map_flat[(target_ty * `TILE_MAP_WIDTH + target_tx) * 3 +: 3] == `MAP_BLOCK;
    
    // latch goal changed
    reg [3:0] goal_tx_prev = 0, goal_ty_prev = 0;
    always @(posedge clk) begin
        goal_tx_prev <= goal_tx;
        goal_ty_prev <= goal_ty;
    end
    wire goal_changed = (goal_tx_prev != goal_tx) | (goal_ty_prev != goal_ty);
    
    // run A* twice if player cannot find unblocked path
    reg blocks_as_walls = 1, blocks_as_walls_prev = 1;
    reg baw_changed_latch = 0, map_changed_latch = 0;
    always @(posedge clk) begin
        blocks_as_walls_prev <= blocks_as_walls;
        if (!is_player) blocks_as_walls <= 0;
        else begin
            if (path_valid_sync_pulse && path_len == 0 && blocks_as_walls) blocks_as_walls <= 0;
            else if (goal_changed || map_changed) blocks_as_walls <= 1;
        end
        
        if (~blocks_as_walls & blocks_as_walls_prev) baw_changed_latch <= 1;
        else if (baw_changed_latch) baw_changed_latch <= 0;
        
        if (map_changed) map_changed_latch <= 1;
        else if (map_changed_latch) map_changed_latch <= 0;
    end
    
    // update if goal moves or map changes or baw changes
    reg [3:0] pos_tx_sync = 0, pos_ty_sync = 0, goal_tx_sync = 0, goal_ty_sync = 0;
    reg [3:0] goal_tx_sync_prev = 0, goal_ty_sync_prev = 0;
    reg map_changed_ff1 = 0, map_changed_ff2 = 0, map_changed_ff2_prev;
    reg baw_changed_ff1 = 0, baw_changed_ff2 = 0, baw_changed_ff2_prev;
    always @ (posedge clk_a_star) begin
        pos_tx_sync <= pos_tx;
        pos_ty_sync <= pos_ty;
        goal_tx_sync <= goal_tx;
        goal_ty_sync <= goal_ty;
        goal_tx_sync_prev <= goal_tx_sync;
        goal_ty_sync_prev <= goal_ty_sync;
        
        map_changed_ff1 <= map_changed_latch;
        map_changed_ff2 <= map_changed_ff1;
        map_changed_ff2_prev <= map_changed_ff2;
        
        baw_changed_ff1 <= baw_changed_latch;
        baw_changed_ff2 <= baw_changed_ff1;
        baw_changed_ff2_prev <= baw_changed_ff2;
    end
    wire goal_changed_sync = goal_tx_sync_prev != goal_tx_sync | goal_ty_sync_prev != goal_ty_sync;
    wire map_changed_sync = map_changed_ff2 & ~map_changed_ff2_prev;
    wire baw_changed_sync = baw_changed_ff2 & ~baw_changed_ff2_prev;
    
    always @ (posedge clk_a_star) begin
        if (goal_changed_sync | map_changed_sync | baw_changed_sync) update_path <= 1;
        else update_path <= 0;
    end 
    
    // unpack map
    integer i;
    
    always @(posedge clk) begin
        if (path_valid_sync_pulse) begin
            for (i = 0; i < `MAX_PATH_LEN; i = i+1) begin
                if (i < path_len) begin
                    path_x[i] <= path_flat_x[(`MAX_PATH_LEN-1-i)*4 +: 4];
                    path_y[i] <= path_flat_y[(`MAX_PATH_LEN-1-i)*4 +: 4];
                end
                else begin
                    path_x[i] <= 4'hF;
                    path_y[i] <= 4'hF;
                end
            end
        end
    end
    
    // update target based on map
    reg initialized = 0;
    reg new_path_pending = 0;
    reg [1:0] last_dir = 0;
    wire tile_aligned = (pos_x == `MIN_PIX_X + pos_tx * `TILE_SIZE + 1) &&
                        (pos_y == `MIN_PIX_Y + pos_ty * `TILE_SIZE + 1);
//    wire [6:0] snap_x = `MIN_PIX_X + pos_tx * `TILE_SIZE + 1;
//    wire [5:0] snap_y = `MIN_PIX_Y + pos_ty * `TILE_SIZE + 1;
    always @(posedge clk) begin
        if (!initialized) begin
            pos_x <= `MIN_PIX_X + spawn_tx * `TILE_SIZE + 1;
            pos_y <= `MIN_PIX_Y + spawn_ty * `TILE_SIZE + 1;
            initialized <= 1;
        end
        else begin
            if (path_valid_sync_pulse) begin
//                path_step <= 1;
                new_path_pending <= 1;
            end
            
            if (new_path_pending) begin
                if (tile_aligned) begin
                    new_path_pending <= 0;
                    path_step <= 1;
                end
                else begin
                    if (move_tick) begin
                    case(last_dir)
                        0: pos_x <= pos_x + 1; 
                        1: pos_x <= pos_x - 1;
                        2: pos_y <= pos_y + 1;
                        3: pos_y <= pos_y - 1;
                    endcase
                    end
                end
            end
            else if (move_tick && path_len > 0) begin
                // if next one is block, dont follow rest of path
                if (next_is_block) path_step <= path_len;
                else begin
                    if      (pos_x < target_x) begin last_dir <= 0; pos_x <= pos_x + 1; end
                    else if (pos_x > target_x) begin last_dir <= 1; pos_x <= pos_x - 1; end
                    else if (pos_x == target_x && pos_y < target_y) begin last_dir <= 2; pos_y <= pos_y + 1; end
                    else if (pos_x == target_x && pos_y > target_y) begin last_dir <= 3; pos_y <= pos_y - 1; end
                  
                    if (pos_x == target_x && pos_y == target_y && path_step < path_len - 1) path_step <= path_step + 1;
                end
            end 
        end
    end
    
    // a_star instantiation (slow clock domain) runs on a divided clock, CDC is handled with a 2-FF synchronizer on path_valid
    a_star a_star_inst (
        .clk          (clk_a_star),
        .update       (update_path),
        .blocks_as_walls(blocks_as_walls),
        .start_x      (pos_tx_sync),//(player_center_tx),
        .start_y      (pos_ty_sync),//(player_center_ty),
        .goal_x       (goal_tx_sync),
        .goal_y       (goal_ty_sync),
        .tile_map_flat(tile_map_flat),
        .path_flat_x  (path_flat_x),
        .path_flat_y  (path_flat_y),
        .path_len     (path_len),
        .path_valid   (path_valid)
    );
endmodule
