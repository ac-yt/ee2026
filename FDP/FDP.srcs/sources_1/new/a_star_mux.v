`timescale 1ns / 1ps

module a_star_mux(input clk,
                  // input map_changed, // fast
                  input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,

                  input c0_update, c0_baw, // fast - check baw/goal change in movement control
                  input [3:0] c0_stx, c0_sty, c0_gtx, c0_gty,
                  output reg [4*`MAX_PATH_LEN-1:0] c0_pfx, c0_pfy,
//                  output c0_valid, // fast
                  output reg c0_valid, // fast
                  output reg [6:0] c0_len,
                  
                  
                  input c1_update, c1_baw,
                  input [3:0] c1_stx, c1_sty, c1_gtx, c1_gty,
                  output reg [4*`MAX_PATH_LEN-1:0] c1_pfx, c1_pfy,
                  output reg c1_valid,
//                  output c1_valid,
                  output reg [6:0] c1_len);
                  
    wire c0_req = c0_update;
    wire c1_req = c1_update;
        
    // a star inputs/outputs
    reg as_update = 0, as_baw = 0;
    reg [3:0] as_stx = 0, as_sty = 0, as_gtx = 0, as_gty = 0;
    wire [4*`MAX_PATH_LEN-1:0] as_pfx, as_pfy;
    wire as_valid;
    wire [6:0] as_len;
    
    a_star a_star_inst (
        .clk          (clk), //(clk_a_star),
        .update       (as_update),
        .blocks_as_walls(as_baw),
        .start_x      (as_stx),//(player_center_tx),
        .start_y      (as_sty),//(player_center_ty),
        .goal_x       (as_gtx),
        .goal_y       (as_gty),
        .tile_map_flat(tile_map_flat),
        .path_flat_x  (as_pfx),
        .path_flat_y  (as_pfy),
        .path_len     (as_len),
        .path_valid   (as_valid)
    );
    
    // fsm
    parameter QUEUE = 2'b00;
    parameter CLIENT_ONE = 2'b01;
    parameter CLIENT_TWO = 2'b10;
    reg [1:0] state = QUEUE;
    
    reg c0_pending = 0, c1_pending = 0;
    always @ (posedge clk) begin //clk_a_star) begin
        if (c0_req) c0_pending <= 1;
        if (c1_req) c1_pending <= 1;
 
        as_update <= 0;
        c0_valid <= 0;
        c1_valid <= 0;
        
        case (state)
            QUEUE: begin
                if (c0_pending) begin
                    c0_pending <= 0;
                    as_update <= 1;
                    as_baw <= c0_baw;
                    as_stx <= c0_stx;
                    as_sty <= c0_sty;
                    as_gtx <= c0_gtx;
                    as_gty <= c0_gty;
                    state <= CLIENT_ONE;
                end
                else if (c1_pending) begin
                    c1_pending <= 0;
                    as_update <= 1;
                    as_baw <= c1_baw;
                    as_stx <= c1_stx;
                    as_sty <= c1_sty;
                    as_gtx <= c1_gtx;
                    as_gty <= c1_gty;
                    state <= CLIENT_TWO;
                end
            end
            CLIENT_ONE: begin
                

                if (as_valid) begin
                    c0_pfx <= as_pfx;
                    c0_pfy <= as_pfy;
                    c0_len <= as_len;
                    c0_valid <= as_valid;
//                    c0_valid_latch <= HOLD_CYCLES; // hold valid_slow high for HOLD_CYCLES slow cycles
                    state <= QUEUE;
                end
            end
            CLIENT_TWO: begin
                
                if (as_valid) begin
                    c1_pfx <= as_pfx;
                    c1_pfy <= as_pfy;
                    c1_len <= as_len;
                    c1_valid <= as_valid;
//                    c1_valid_latch <= HOLD_CYCLES;
                    state <= QUEUE;
                end
            end
        endcase
    end
endmodule