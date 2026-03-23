`timescale 1ns / 1ps

`include "constants.vh"

module movement_controller(input clk,
                           input [3:0] goal_tx, goal_ty, // player for computer, mouse for player
                           input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                           input [$clog2(`PLAYER_MAX_SPEED)-1:0] speed,
                           input is_player,
                           output [3:0] pos_tx_out, pos_ty_out,
                           output reg [6:0] pos_x=`MIN_PIX_X + 1,
                           output reg [5:0] pos_y=`MIN_PIX_Y + 1);

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
    
    // 2-FF CDC synchronizer: path_valid (slow) -> fast domain
    reg path_valid_ff1 = 0, path_valid_ff2 = 0, path_valid_ff2_prev = 0;
    always @(posedge clk) begin
        path_valid_ff1 <= path_valid;
        path_valid_ff2 <= path_valid_ff1;
        path_valid_ff2_prev <= path_valid_ff2;
    end
    wire path_valid_sync_pulse = path_valid_ff2 & ~path_valid_ff2_prev; // single-cycle pulse in fast domain when path_valid safely rises
   
    parameter integer MAX_MOVE_COUNT = `CLOCK_SPEED / `COMPUTER_DEFAULT_SPEED;
    wire [31:0] move_count_thresh = `CLOCK_SPEED / speed; // changes based on speed
    reg [$clog2(MAX_MOVE_COUNT)-1:0] move_counter = 0;
    wire move_tick = (move_counter == move_count_thresh - 1);
    always @(posedge clk) begin
        if (move_counter == move_count_thresh - 1) move_counter <= 0;
        else move_counter <= move_counter + 1;
    end
    
    reg [6:0] path_step = 0;
    wire [3:0] pos_tx = ((pos_x - 1 - `MIN_PIX_X) * 7'd43) >> 8; // replace divide by reciprocal multiply + shift 1/6 ~ 43/256
    wire [3:0] pos_ty = ((pos_y - 1 - `MIN_PIX_Y) * 7'd43) >> 8; // uses the top left to see
    wire [3:0] target_tx = (path_step < path_len) ? path_x[path_step] : pos_tx;
    wire [3:0] target_ty = (path_step < path_len) ? path_y[path_step] : pos_ty;
    wire [6:0] target_x = `MIN_PIX_X + target_tx * `TILE_SIZE + 1;
    wire [5:0] target_y = `MIN_PIX_Y + target_ty * `TILE_SIZE + 1;
    
    assign pos_tx_out = pos_tx;
    assign pos_ty_out = pos_ty;
   
    reg [3:0] pos_tx_sync = 0, pos_ty_sync = 0, goal_tx_sync = 0, goal_ty_sync = 0;
    always @ (posedge clk_a_star) begin
        pos_tx_sync <= pos_tx;
        pos_ty_sync <= pos_ty;
        goal_tx_sync <= goal_tx;
        goal_ty_sync <= goal_ty;
    end
    
    // capture and unpack path data on safe pulse
    // path_flat_x/y are stable before path_valid is asserted, safe to sample ~2 fast cycles later when the sync pulse fires
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
    
    // pre-register movement decisions
    reg move_right = 0, move_left = 0, move_down = 0, move_up = 0;
    always @(posedge clk) begin
        move_right <= (pos_x < target_x);
        move_left  <= (pos_x > target_x);
        move_down  <= (pos_x == target_x && pos_y < target_y);
        move_up    <= (pos_x == target_x && pos_y > target_y);
    end
    
    always @(posedge clk) begin
        if (move_tick && path_len > 0 && (!is_player || (is_player && tile_map_flat[(target_ty*`TILE_MAP_WIDTH + target_tx)*3 +: 3] != `MAP_BLOCK))) begin
            if      (move_right) pos_x <= pos_x + 1;
            else if (move_left)  pos_x <= pos_x - 1;
            else if (move_down)  pos_y <= pos_y + 1;
            else if (move_up)    pos_y <= pos_y - 1;
    
            if (pos_x == target_x && pos_y == target_y && path_step < path_len - 1) path_step <= path_step + 1;
        end
        if (path_valid_sync_pulse) path_step <= 1; //best_step; // path_step <= 0;
    end

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
    
    reg blocks_as_walls = 1;
    always @(posedge clk) begin
        if (path_valid_sync_pulse && is_player) begin
            if (path_len == 0 && blocks_as_walls) blocks_as_walls <= 0;
            else blocks_as_walls <= 1;
        end
        
        if (!is_player) blocks_as_walls <= 0;
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
