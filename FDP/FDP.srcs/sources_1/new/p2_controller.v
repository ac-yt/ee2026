`timescale 1ns / 1ps

`include "constants.vh"

module p2_controller(input clk,
                     input single_player,
                     input [3:0] p1_tx, p1_ty, mouse_tx, mouse_ty,  // done in top student
                     input mouse_left_pulse, mouse_right_pulse, mouse_middle_pulse,
                     input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                     input [1:0] speed_multiplier,
                     input map_changed,
                     
                     output [3:0] goal_tx, goal_ty,
                     output reg [3:0] p2_tx, p2_ty,
                     output reg [6:0] p2_x,
                     output reg [5:0] p2_y,
                     input p2_dead,
                     
                     output [`MAX_BOMBS-1:0] place_bomb_req, bomb_active, bomb_red, explosion_active,
                     output [`MAX_BOMBS*4-1:0] bomb_tx_flat, bomb_ty_flat,
                     output [`MAX_BOMBS*2-1:0] explosion_stage_flat,
                                             
                     input [1:0] bomb_count, // number of bombs that can be placed
                     input [1:0] bomb_radius, // radius of bom
                       
                     output update, blocks_as_walls,
                     input [4*`MAX_PATH_LEN-1:0] path_flat_x, path_flat_y,
                     input path_valid, 
                     input [6:0] path_len);
                                                      
    wire [$clog2(`PLAYER_MAX_SPEED)-1:0] speed = single_player ? 
                                                 `BOT_DEFAULT_SPEED + speed_multiplier * `BOT_SPEED_INCREMENT : 
                                                 `PLAYER_DEFAULT_SPEED + speed_multiplier * `PLAYER_SPEED_INCREMENT;
    
    // BOT FSM
    wire in_danger;
    wire [3:0] escape_tx, escape_ty;
    bot_escape bot_escape_inst (.clk(clk), .rst(0), .bot_tx(p2_tx), .bot_ty(p2_ty), .tile_map_flat(tile_map_flat),
                                .in_danger(in_danger), .escape_tx(escape_tx), .escape_ty(escape_ty));
                                
    /*parameter BOT_HUNT = 0;
    parameter BOT_PLACED = 1;
    parameter BOT_ESCAPE = 2;
    
    reg [1:0] bot_state = BOT_HUNT;
    
    parameter integer BOMB_COOLDOWN = `CLOCK_SPEED; // wait 1s in between placing bombs
    reg [$clog2(BOMB_COOLDOWN)-1:0] bomb_cooldown_ctr = 0;
    wire bomb_ready = (bomb_cooldown_ctr == 0);*/
                                    
    // GOAL
    reg [3:0] bot_goal_tx = 0, bot_goal_ty = 0, player_goal_tx = 0, player_goal_ty = 0;
    always @ (posedge clk) begin
        if (mouse_left_pulse) begin
            player_goal_tx <= mouse_tx;
            player_goal_ty <= mouse_ty;
        end
        
        bot_goal_tx <= in_danger ? escape_tx : p1_tx;
        bot_goal_ty <= in_danger ? escape_ty : p1_ty;
    end
    
    assign goal_tx = single_player ? bot_goal_tx : player_goal_tx; 
    assign goal_ty = single_player ? bot_goal_ty : player_goal_ty;
    
    // BOT 
    wire next_is_block;
    reg next_is_block_prev = 0;
    always @(posedge clk) next_is_block_prev <= next_is_block;
    
    // BOTH
    wire [3:0] mc_p2_tx, mc_p2_ty;
    wire [6:0] mc_p2_x;
    wire [5:0] mc_p2_y;
    
    always @ (posedge clk) begin
        if (!p2_dead) begin
            p2_tx <= mc_p2_tx;
            p2_ty <= mc_p2_ty;
            p2_x <= mc_p2_x;
            p2_y <= mc_p2_y;
        end
    end
    
    movement_controller p2_move (.clk(clk), .map_changed(map_changed), .spawn_tx(14), .spawn_ty(8),
                                   .goal_tx(goal_tx), .goal_ty(goal_ty), .tile_map_flat(tile_map_flat), .speed(speed), .is_player(!single_player),
                                   .next_is_block(next_is_block), .pos_tx_out(mc_p2_tx), .pos_ty_out(mc_p2_ty), .pos_x(mc_p2_x), .pos_y(mc_p2_y),
                                   .as_update(update), .as_baw(blocks_as_walls), .path_flat_x(path_flat_x), .path_flat_y(path_flat_y),
                                   .path_valid(path_valid), .path_len(path_len));
    
    reg bomb_trigger = 0;
    always @ (posedge clk) begin
        if (p2_dead) bomb_trigger <= 0;
        else bomb_trigger <= single_player ? (next_is_block & ~next_is_block_prev) : mouse_right_pulse;
    end
    
    bomb_controller p2_bomb_inst (
        .clk(clk),
        .trigger(bomb_trigger),
        .player_tx(p2_tx),
        .player_ty(p2_ty),
//        .player_dead(p2_dead),
        .bomb_active(bomb_active),
        .bomb_tx_flat(bomb_tx_flat),
        .bomb_ty_flat(bomb_ty_flat),
        .bomb_red(bomb_red),
        .explosion_active(explosion_active),
        .explosion_stage_flat(explosion_stage_flat),
        .place_bomb_req(place_bomb_req),
        .bomb_count(bomb_count),
        .bomb_radius(bomb_radius)
    );
    
endmodule





// bot escape
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
    
    wire signed [3:0] score_up    = score_tile(bot_tx,     bot_ty - 1);
    wire signed [3:0] score_down  = score_tile(bot_tx,     bot_ty + 1);
    wire signed [3:0] score_left  = score_tile(bot_tx - 1, bot_ty    );
    wire signed [3:0] score_right = score_tile(bot_tx + 1, bot_ty    );
    
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
            in_danger <= is_dangerous(bot_tx, bot_ty);
            escape_tx <= bot_tx;
            escape_ty <= bot_ty;
    
            if (is_dangerous(bot_tx, bot_ty) || is_dangerous(bot_tx-1, bot_ty) || is_dangerous(bot_tx+1, bot_ty) || is_dangerous(bot_tx, bot_ty-1) || is_dangerous(bot_tx, bot_ty+1)) begin
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
