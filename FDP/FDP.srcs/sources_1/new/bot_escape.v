`timescale 1ns / 1ps

`include "constants.vh"

module bot_escape(
    input clk, rst,
    input [3:0] bot_tx, bot_ty,
    input [3*`TILE_MAP_SIZE-1:0] tile_map_flat,
    output reg in_danger,
    output reg [3:0] escape_tx, escape_ty
);

    reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];
    integer ux, uy; // unpack map
    always @(*) begin
        for (uy = 0; uy < `TILE_MAP_HEIGHT; uy = uy + 1)
            for (ux = 0; ux < `TILE_MAP_WIDTH; ux = ux + 1)
                tile_map[ux][uy] = tile_map_flat[(uy*`TILE_MAP_WIDTH + ux)*3 +: 3];
    end
    
    parameter DIR_NONE  = 3'd0;
    parameter DIR_UP    = 3'd1;
    parameter DIR_DOWN  = 3'd2;
    parameter DIR_LEFT  = 3'd3;
    parameter DIR_RIGHT = 3'd4;

    // =========================================================
    // FUNCTIONS
    // =========================================================
    
    function automatic in_bounds;
        input [3:0] x;
        input [3:0] y;
        begin
            in_bounds = (x < `TILE_MAP_WIDTH) && (y < `TILE_MAP_HEIGHT);
        end
    endfunction
    
    function automatic is_passable;
        input [3:0] x;
        input [3:0] y;
        reg [2:0] t;
        begin
            if (!in_bounds(x, y)) is_passable = 1'b0;
            else begin
                t = tile_map[x][y];
                is_passable = (t == `MAP_EMPTY) || (t == `MAP_BOMB) || (t == `MAP_POWERUP);
//                is_passable = (t == `MAP_EMPTY) || (t == `MAP_POWERUP);
            end
        end
    endfunction
    
    function automatic is_dangerous;
        input [3:0] x;
        input [3:0] y;
        begin
            if (!in_bounds(x, y)) is_dangerous = 1'b0;
            else is_dangerous = (tile_map[x][y] == `MAP_BLAST || tile_map[x][y] == `MAP_BOMB);
        end
    endfunction
    
    // counts passable neighbours - penalises dead ends/corners
    function automatic [2:0] exit_count;
        input [3:0] x;
        input [3:0] y;
        begin
            exit_count = is_passable(x, y-1) + is_passable(x, y+1) + is_passable(x-1, y) + is_passable(x+1, y);
        end
    endfunction
    
    function automatic signed [3:0] score_tile;
        input [3:0] x;
        input [3:0] y;
        reg signed [3:0] s;
        reg [2:0] exits;
        begin
            if (!in_bounds(x, y) || !is_passable(x, y)) score_tile = -4'sd8;
            else begin
                s = 4'sd0;
    
                if (is_dangerous(x, y)) s = s - 4'sd6;
    
                exits = exit_count(x, y);
                if (exits == 0) s = s - 4'sd4;
                else if (exits == 1) s = s - 4'sd2;
                else if (exits >= 3) s = s + 4'sd1;
    
                score_tile = s;
            end
        end
    endfunction
    
    // =========================================================
    // COMBINATIONAL SCORING
    // =========================================================
    
    wire signed [3:0] score_up    = score_tile(bot_tx, bot_ty - 1);
    wire signed [3:0] score_down  = score_tile(bot_tx, bot_ty + 1);
    wire signed [3:0] score_left  = score_tile(bot_tx - 1, bot_ty);
    wire signed [3:0] score_right = score_tile(bot_tx + 1, bot_ty);
    
    // =========================================================
    // REGISTERED OUTPUT
    // =========================================================
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            in_danger  <= 1'b0;
            escape_tx <= bot_tx;
            escape_ty <= bot_ty;
        end 
        else begin
            in_danger <= is_dangerous(bot_tx, bot_ty) || is_dangerous(bot_tx-1, bot_ty) || is_dangerous(bot_tx+1, bot_ty) || is_dangerous(bot_tx, bot_ty-1) || is_dangerous(bot_tx, bot_ty+1);// ||
//                         is_dangerous(bot_tx-2, bot_ty) || is_dangerous(bot_tx+2, bot_ty) || is_dangerous(bot_tx, bot_ty-2) || is_dangerous(bot_tx, bot_ty+2);
            
            escape_tx <= bot_tx;
            escape_ty <= bot_ty;
    
            if (is_dangerous(bot_tx, bot_ty) || is_dangerous(bot_tx-1, bot_ty) || is_dangerous(bot_tx+1, bot_ty) || is_dangerous(bot_tx, bot_ty-1) || is_dangerous(bot_tx, bot_ty+1)) begin// ||
//                is_dangerous(bot_tx-2, bot_ty) || is_dangerous(bot_tx+2, bot_ty) || is_dangerous(bot_tx, bot_ty-2) || is_dangerous(bot_tx, bot_ty+2)) begin
                // normal path: pick best non-hard-blocked direction
                if (score_up >= score_down && score_up >= score_left && score_up >= score_right && score_up > -4'sd8) escape_ty <= bot_ty - 1;
                else if (score_down >= score_left && score_down >= score_right && score_down > -4'sd8) escape_ty <= bot_ty + 1;
                else if (score_left >= score_right && score_left > -4'sd8) escape_tx <= bot_tx - 1;
                else if (score_right > -4'sd8) escape_tx <= bot_tx + 1;
    
                else begin
                    // fully surrounded fallback
                    if (score_up >= score_down && score_up >= score_left && score_up >= score_right) escape_ty <= bot_ty - 1 ;
                    else if (score_down >= score_left && score_down >= score_right) escape_ty <= bot_ty + 1;
                    else if (score_left  >= score_right) escape_tx <= bot_tx - 1;
                    else escape_tx <= bot_tx + 1;
                end
            end 
            else begin
                escape_tx <= bot_tx;
                escape_ty <= bot_ty;
            end
        end
    end
endmodule