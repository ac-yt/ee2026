`timescale 1ns / 1ps

`include "constants.vh"

module movement_controller (input clk, rst_game, game_ready,// output reg [15:0] led,
                            input map_changed,
                            input [3:0] spawn_tx, spawn_ty,
                            input [3:0] goal_tx, goal_ty, // player for computer, mouse for player 
                            input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                            input [$clog2(`PLAYER_MAX_SPEED)-1:0] speed,
                            input is_player,
                            output next_is_block,
                            output [3:0] pos_tx_out, pos_ty_out,
                            output reg [6:0] pos_x,
                            output reg [5:0] pos_y,
                            output [1:0] facing,   // 0=right 1=left 2=down 3=up
                            
//                            input force_baw, force_bmaw,
                             
                            output reg as_update=0, as_baw=1, //as_bmaw=0, // fast - check baw/goal change in movement control
                            input [4*`MAX_PATH_LEN-1:0] path_flat_x, path_flat_y,
                            input path_valid, // fast
                            input [6:0] path_len);
 
    reg [3:0] path_x [0:`MAX_PATH_LEN-1];
    reg [3:0] path_y [0:`MAX_PATH_LEN-1];

    // synchronise path_valid
    reg path_valid_prev = 0;
    always @(posedge clk) begin
        path_valid_prev <= path_valid;
    end
    wire path_valid_pulse = path_valid & ~path_valid_prev; // single-cycle pulse in fast domain when path_valid safely rises
    
    // move tick
    parameter integer MAX_MOVE_COUNT = `CLOCK_SPEED / `BOT_DEFAULT_SPEED;
    wire [31:0] move_count_thresh = `CLOCK_SPEED / speed; // changes based on speed
    reg [$clog2(MAX_MOVE_COUNT)-1:0] move_counter = 0;
    wire move_tick = (move_counter == move_count_thresh - 1);
    always @(posedge clk) begin
        if (rst_game) move_counter <= 0;
        else if (game_ready) begin
            if (move_counter == move_count_thresh - 1) move_counter <= 0;
            else move_counter <= move_counter + 1;
        end
    end
    
    // unpack map
    integer i;
    always @(posedge clk) begin
        if (path_valid_pulse) begin
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
    
    reg [6:0] path_len_r = 0; // zero on rst game to stop bot and player from moving
    always @ (posedge clk) begin
        if (rst_game) path_len_r <= 0;
        else if (path_valid_pulse) path_len_r <= path_len;
    end
    
    // calculate target step
    reg [6:0] path_step = 0;
    wire [3:0] pos_tx = ((pos_x - 1 - `MIN_PIX_X) * 7'd43) >> 8; // replace divide by reciprocal multiply + shift 1/6 ~ 43/256
    wire [3:0] pos_ty = ((pos_y - 1 - `MIN_PIX_Y) * 7'd43) >> 8; // uses the top left to see
    wire [3:0] target_tx = (path_step < path_len_r) ? path_x[path_step] : pos_tx;
    wire [3:0] target_ty = (path_step < path_len_r) ? path_y[path_step] : pos_ty;
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
    reg as_baw_prev = 1;
    always @(posedge clk) begin        
        as_baw_prev <= as_baw;
        
        /*as_bmaw <= force_bmaw; // bombs as walls
        
        if (!is_player && !force_baw) as_baw <= 0;
        else begin
            if (path_valid_pulse && path_len == 0 && as_baw && !force_baw) as_baw <= 0;
            else if (goal_changed || map_changed || force_baw) as_baw <= 1;
        end*/
        
        if (!is_player) as_baw <= 0;
        else begin
            if (path_valid_pulse && path_len == 0 && as_baw) as_baw <= 0;
//            else if ((goal_changed || map_changed) && !blocked) as_baw <= 1;
            else if (goal_changed || map_changed) as_baw <= 1;
        end
    end
    wire baw_changed = ~as_baw & as_baw_prev;
    
    // update map
    wire tile_aligned = (pos_x == `MIN_PIX_X + pos_tx * `TILE_SIZE + 1) && (pos_y == `MIN_PIX_Y + pos_ty * `TILE_SIZE + 1);
    reg update_pending = 0;
    always @ (posedge clk) begin
//        if (goal_changed || baw_changed || map_changed) update_pending <= 1;
        if (rst_game || goal_changed || baw_changed || map_changed) update_pending <= 1;
        
        if (update_pending && tile_aligned) begin // only update when when the 
            as_update <= 1;
            update_pending <= 0;
        end
        else as_update <= 0;
    end
    
    // update target based on map
    reg initialized = 0;
    reg new_path_pending = 0;
    reg [1:0] last_dir = 0;
    assign facing = last_dir;

    always @(posedge clk) begin
        if (!initialized) begin
            pos_x <= `MIN_PIX_X + spawn_tx * `TILE_SIZE + 1;
            pos_y <= `MIN_PIX_Y + spawn_ty * `TILE_SIZE + 1;
            initialized <= 1;
        end
        else if (rst_game) begin
            pos_x <= `MIN_PIX_X + spawn_tx * `TILE_SIZE + 1;
            pos_y <= `MIN_PIX_Y + spawn_ty * `TILE_SIZE + 1;
            // add clearing the path
            
            new_path_pending <= 0;
            path_step <= 0;
        end
        else begin
            if (path_valid_pulse) new_path_pending <= 1;
            
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
            else if (move_tick && path_len_r > 0) begin
                // if next one is block, dont follow rest of path
                if (next_is_block) path_step <= path_len_r;
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
endmodule