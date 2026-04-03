`timescale 1ns / 1ps

`include "constants.vh"

module p2_controller(input clk, rst_game, game_ready,
                     input single_player,
                     input [3:0] p1_tx, p1_ty, p1_goal_tx, p1_goal_ty, mouse_tx, mouse_ty,  // done in top student
                     input mouse_left_pulse, mouse_right_pulse, mouse_middle_pulse,
                     input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                     input [1:0] speed_multiplier,
                     input map_changed,
                     
                     output reg [1:0] led,
                     
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
                     
                     input [`MAX_BOMBS*4-1:0] p1_bomb_tx_flat, p1_bomb_ty_flat,
                     input [`MAX_BOMBS-1:0] p1_bomb_active, p1_explosion_active,
                       
                     output update, blocks_as_walls, 
                     output reg bombs_as_walls,
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
                                    
    // GOAL
    reg [3:0] bot_goal_tx = 0, bot_goal_ty = 0, player_goal_tx = 0, player_goal_ty = 0;
    reg in_danger_latch = 0;
    
    reg [3:0] bot_default_goal_tx = 0, bot_default_goal_ty = 0;
    
    wire [4:0] p1_bomb_dist [0:`MAX_BOMBS-1];
    wire [4:0] p2_bomb_dist [0:`MAX_BOMBS-1];
    reg bomb_player = 0;
    reg bomb_number = 0;
    
    parameter BOT_HUNT = 3'b000; // normal chase
    parameter BOT_ESCAPE = 3'b001; // escape if bomb
    parameter BOT_ESCAPE_PATH = 3'b010;
    parameter BOT_ESCAPE_HUNT = 3'b011;
    parameter BOT_BOMB = 3'b100;
    reg [2:0] bot_state = BOT_HUNT;
    
    reg bot_trigger = 0;
    wire next_is_block;
    reg next_is_block_prev = 0;
    always @(posedge clk) next_is_block_prev <= next_is_block;
    
    wire at_escape = (p2_tx == escape_tx) && (p2_ty == escape_ty);
    
    // dist from player to every bomb
    genvar bi;
    generate
        for (bi = 0; bi < `MAX_BOMBS; bi = bi + 1) begin : bomb_unpack
            assign p1_bomb_dist[bi] = manhattan_dist(p2_tx, p2_ty, p1_bomb_tx_flat[bi*4 +: 4], p1_bomb_ty_flat[bi*4 +: 4]);
            assign p2_bomb_dist[bi] = manhattan_dist(p2_tx, p2_ty, bomb_tx_flat[bi*4 +: 4], bomb_ty_flat[bi*4 +: 4]);
        end
    endgenerate
    
    always @ (posedge clk) begin
        bot_trigger <= 0;
        bombs_as_walls <= 0;
        led <= bot_state;
        
        if (rst_game) begin
            bot_state    <= BOT_HUNT;
            bot_goal_tx  <= p2_tx;
            bot_goal_ty  <= p2_ty;
            bomb_player  <= 0;
            bomb_number  <= 0;
        end
        else begin
            case (bot_state)
                BOT_HUNT: begin
                    // go to p1 goal if closer to it than p1, else chase p1
    //                bot_goal_tx <= p1_tx;
    //                bot_goal_ty <= p1_ty;
                    if (manhattan_dist(p1_tx, p1_ty, p1_goal_tx, p1_goal_ty) <= manhattan_dist(p2_tx, p2_ty, p1_goal_tx, p1_goal_ty)) begin // p1 closer
                        bot_goal_tx <= p1_tx;
                        bot_goal_ty <= p1_ty;
                    end
                    else begin // bot closer
                        bot_goal_tx <= p1_goal_tx;
                        bot_goal_ty <= p1_goal_ty;
                    end
                    
                    if (next_is_block & ~next_is_block_prev) bot_state <= BOT_BOMB; // place bomb if block on path
                    if (p2_tx == p1_goal_tx && p2_ty == p1_goal_ty) bot_state <= BOT_BOMB; // at p1s goal
                    if (manhattan_dist(p2_tx, p2_ty, p1_tx, p1_ty) <= bomb_radius && (p2_tx == p1_tx || p2_ty == p1_ty)) bot_state <= BOT_BOMB; // close to p1
                    
                    if (in_danger) begin
                        bot_state <= BOT_ESCAPE;
                        
                        // figure out which bomb is the danger on the first cycle
                        if ((p1_bomb_active[0] || p1_explosion_active[0]) && p1_bomb_dist[0] <= p1_bomb_dist[1] && p1_bomb_dist[0] <= p2_bomb_dist[0] && p1_bomb_dist[0] <= p2_bomb_dist[1]) begin
                            bomb_player <= 0;
                            bomb_number <= 0;
                        end
                        else if ((p1_bomb_active[1] || p1_explosion_active[1]) && p1_bomb_dist[1] <= p2_bomb_dist[0] && p1_bomb_dist[1] <= p2_bomb_dist[1]) begin
                            bomb_player <= 0;
                            bomb_number <= 1;
                        end
                        else if ((bomb_active[0] || explosion_active[0]) && p2_bomb_dist[0] <= p2_bomb_dist[1]) begin
                            bomb_player <= 1;
                            bomb_number <= 0;
                        end
                        else if ((bomb_active[0] || explosion_active[0])) begin
                            bomb_player <= 1;
                            bomb_number <= 1;
                        end
                        
                        bot_goal_tx <= escape_tx;
                        bot_goal_ty <= escape_ty;
                    end
                end
                BOT_ESCAPE: begin
                    // figure out which bomb is the danger
                    if ((p1_bomb_active[0] || p1_explosion_active[0]) && p1_bomb_dist[0] <= p1_bomb_dist[1] && p1_bomb_dist[0] <= p2_bomb_dist[0] && p1_bomb_dist[0] <= p2_bomb_dist[1]) begin
                        bomb_player <= 0;
                        bomb_number <= 0;
                    end
                    else if ((p1_bomb_active[1] || p1_explosion_active[1]) && p1_bomb_dist[1] <= p2_bomb_dist[0] && p1_bomb_dist[1] <= p2_bomb_dist[1]) begin
                        bomb_player <= 0;
                        bomb_number <= 1;
                    end
                    else if ((bomb_active[0] || explosion_active[0]) && p2_bomb_dist[0] <= p2_bomb_dist[1]) begin
                        bomb_player <= 1;
                        bomb_number <= 0;
                    end
                    else if ((bomb_active[0] || explosion_active[0])) begin
                        bomb_player <= 1;
                        bomb_number <= 1;
                    end
                    
                    bot_goal_tx <= escape_tx;
                    bot_goal_ty <= escape_ty;
                    
                    if (bomb_player == 0 && !p1_bomb_active[bomb_number] && !p1_explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                    else if (bomb_player == 1 && !bomb_active[bomb_number] && !explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                    
    //                if (at_escape) bot_state <= BOT_ESCAPE_HUNT;
                end
                BOT_ESCAPE_PATH: begin // see if there is empty path
                    // take bombs as walls
                    bombs_as_walls <= 1;
                    
                    bot_goal_tx <= p1_tx; // update req will be sent when new goal is set
                    bot_goal_ty <= p1_ty;
                    
                    if (path_valid) bot_state <= (path_len == 0) ? BOT_ESCAPE : BOT_ESCAPE_HUNT;
                end
                BOT_ESCAPE_HUNT: begin
                    // take bombs as walls
                    bombs_as_walls <= 1;
                    
                    bot_goal_tx <= p1_tx; // update req will be sent when new goal is set
                    bot_goal_ty <= p1_ty;
                    
                    if (bomb_player == 0 && !p1_bomb_active[bomb_number] && !p1_explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                    else if (bomb_player == 1 && !bomb_active[bomb_number] && !explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                end
                BOT_BOMB: begin
                    bot_trigger <= game_ready; // prevent placement when not ready
                    bot_state <= BOT_HUNT;
                end
            endcase
        end
    end
        
    always @ (posedge clk) begin
        if (rst_game) begin
            player_goal_tx <= p2_tx;
            player_goal_ty <= p2_ty;
        end
        
        if (mouse_left_pulse) begin
            player_goal_tx <= mouse_tx;
            player_goal_ty <= mouse_ty;
        end
    end
    
    assign goal_tx = single_player ? bot_goal_tx : player_goal_tx; 
    assign goal_ty = single_player ? bot_goal_ty : player_goal_ty;

    wire player_trigger = mouse_right_pulse;
    wire bomb_trigger = p2_dead ? 0 : (single_player ? bot_trigger : player_trigger);
        
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
    
    movement_controller p2_move (.clk(clk), .map_changed(map_changed), .spawn_tx(14), .spawn_ty(8), .rst_game(rst_game), .game_ready(game_ready),
                                   .goal_tx(goal_tx), .goal_ty(goal_ty), .tile_map_flat(tile_map_flat), .speed(speed), .is_player(!single_player),
                                   .next_is_block(next_is_block), .pos_tx_out(mc_p2_tx), .pos_ty_out(mc_p2_ty), .pos_x(mc_p2_x), .pos_y(mc_p2_y),
                                   .as_update(update), .as_baw(blocks_as_walls), .path_flat_x(path_flat_x), .path_flat_y(path_flat_y),
                                   .path_valid(path_valid), .path_len(path_len));
//                                   .force_baw(in_danger_latch), .force_bmaw(checking_player_path), .as_bmaw(bombs_as_walls));
    
    bomb_controller p2_bomb_inst (
        .clk(clk),
        .rst_game(rst_game),
        .game_ready(game_ready),
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
    
    function [4:0] manhattan_dist;
        input [3:0] x, y;
        input [3:0] goal_x, goal_y;
    begin
        // use manhattan distance as a heuristic
        manhattan_dist = (x > goal_x ? x - goal_x : goal_x - x) + (y > goal_y ? y - goal_y : goal_y - y);
    end
    endfunction
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
