`timescale 1ns / 1ps

`include "constants.vh"

module computer_controller(input clk,
                           input [3:0] player_tx,
                           input [3:0] player_ty,
                           // input [6:0] x,
                           // input [5:0] y,
                           input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                           output reg [6:0] computer_x=`MIN_PIX_X + 1,
                           output reg [5:0] computer_y=`MIN_PIX_Y + 1);
                           // output reg [15:0] oled_path=0);

    wire clk_a_star;
    variable_clock #(.CLOCK_SPEED(`CLOCK_SPEED), .OUT_SPEED(`PATH_SPEED)) clk_a_star_inst
                    (.clk(clk), .clk_out(clk_a_star));
 
    reg update_path = 0;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_x;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_y;
    wire [6:0] path_len;
    wire path_valid;
    // wire [10:0] path_cost;
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
   
    parameter integer COMPUTER_COUNT  = `CLOCK_SPEED / `COMPUTER_SPEED;
    reg [$clog2(COMPUTER_COUNT)-1:0] computer_counter = 0;
    wire computer_move_tick = (computer_counter == COMPUTER_COUNT - 1);
    always @(posedge clk) begin
        if (computer_counter == COMPUTER_COUNT - 1) computer_counter <= 0;
        else computer_counter <= computer_counter + 1;
    end
    
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
   
    reg [3:0] computer_tx_sync = 0, computer_ty_sync = 0;
        
    always @ (posedge clk_a_star) begin
        computer_tx_sync <= computer_tx;
        computer_ty_sync <= computer_ty;
    end
  
    always @ (posedge clk) begin
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
    
    // capture and unpack path data on safe pulse
    // path_flat_x/y are stable before path_valid is asserted, safe to sample ~2 fast cycles later when the sync pulse fires
    integer i;
    always @(posedge clk) begin
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
    
    // a_star instantiation (slow clock domain) runs on a divided clock, CDC is handled with a 2-FF synchronizer on path_valid
    a_star a_star_inst (
        .clk          (clk_a_star),
        .update       (update_path),
        .start_x      (computer_tx_sync),//(player_center_tx),
        .start_y      (computer_ty_sync),//(player_center_ty),
        .goal_x       (player_tx),
        .goal_y       (player_ty),
        .tile_map_flat(tile_map_flat),
        .path_flat_x  (path_flat_x),
        .path_flat_y  (path_flat_y),
        .path_len     (path_len),
        .path_valid   (path_valid)
        // .path_cost    (path_cost)
    );
endmodule