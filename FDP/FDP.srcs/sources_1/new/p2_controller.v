`timescale 1ns / 1ps

`include "constants.vh"

module p2_controller(input clk, rst_game, game_ready,
                     input single_player, load_game,
                     input [3:0] p1_tx, p1_ty, p1_goal_tx, p1_goal_ty, mouse_tx, mouse_ty, sv_tx, sv_ty, // done in top student
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
                     
                     input [`MAX_BOMBS-1:0] sv_bomb_active,
                     input [`MAX_BOMBS-1:0] sv_explosion_active,
                     input [`MAX_BOMBS*4-1:0] sv_bomb_tx_flat, sv_bomb_ty_flat,
                     input [`MAX_BOMBS*2-1:0] sv_explosion_stage_flat,
                       
                     output update, blocks_as_walls, 
                     output reg bombs_as_walls,
                     input [4*`MAX_PATH_LEN-1:0] path_flat_x, path_flat_y,
                     input path_valid, 
                     input [6:0] path_len,
                     
                     // stun
                     input [6:0] p1_x,
                     input [5:0] p1_y,
                    
                     output stun_active, p1_stunned,
                     output [6:0] stun_x0, stun_x1,
                     output [5:0] stun_y0, stun_y1
);
                                                      
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
            bot_state <= BOT_HUNT;
            bot_goal_tx <= `P2_SPAWN_TX;
            bot_goal_ty <= `P2_SPAWN_TY;
            bomb_player <= 0;
            bomb_number <= 0;
        end
        else if (load_game) begin
            bot_state <= BOT_HUNT;
            bot_goal_tx <= sv_tx;
            bot_goal_ty <= sv_ty;
            bomb_player <= 0;
            bomb_number <= 0;
        end
        else if (game_ready) begin
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
                        else if ((bomb_active[1] || explosion_active[1])) begin
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
                    else if ((bomb_active[1] || explosion_active[1])) begin
                        bomb_player <= 1;
                        bomb_number <= 1;
                    end
                    else bot_state <= BOT_HUNT; // no bombs, shouldnt happen
                    
//                    bot_goal_tx <= escape_tx;
//                    bot_goal_ty <= escape_ty;
                    
                    if (escape_tx != bot_goal_tx || escape_ty != bot_goal_ty) begin
                        bot_goal_tx <= escape_tx;
                        bot_goal_ty <= escape_ty;
                    end
                    
                    if (!in_danger) begin // added this
                        if (bomb_player == 0 && !p1_bomb_active[bomb_number] && !p1_explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                        else if (bomb_player == 1 && !bomb_active[bomb_number] && !explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                    end
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
            player_goal_tx <= `P2_SPAWN_TX;
            player_goal_ty <= `P2_SPAWN_TY;
        end
        else if (load_game) begin
            player_goal_tx <= sv_tx;
            player_goal_ty <= sv_ty;
        end
        else if (game_ready) begin
            if (mouse_left_pulse) begin
                player_goal_tx <= mouse_tx;
                player_goal_ty <= mouse_ty;
            end
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
    
    wire [1:0] facing;
    
    movement_controller p2_move (
        .clk(clk), 
        .map_changed(map_changed), 
        .spawn_tx(`P2_SPAWN_TX), 
        .spawn_ty(`P2_SPAWN_TY), 
        .load_game(load_game),
        .sv_tx(sv_tx),
        .sv_ty(sv_ty),
        .rst_game(rst_game), 
        .game_ready(game_ready),
        .goal_tx(goal_tx), 
        .goal_ty(goal_ty), 
        .tile_map_flat(tile_map_flat), 
        .speed(speed), 
        .is_player(!single_player),
        .next_is_block(next_is_block), 
        .last_dir(facing),
        .pos_tx_out(mc_p2_tx), 
        .pos_ty_out(mc_p2_ty), 
        .pos_x(mc_p2_x), 
        .pos_y(mc_p2_y),
        .as_update(update), 
        .as_baw(blocks_as_walls), 
        .path_flat_x(path_flat_x), 
        .path_flat_y(path_flat_y),
        .path_valid(path_valid), 
        .path_len(path_len)
    );
//                                   .force_baw(in_danger_latch), .force_bmaw(checking_player_path), .as_bmaw(bombs_as_walls));
    
    bomb_controller p2_bomb_inst (
        .clk(clk),
        .rst_game(rst_game),
        .game_ready(game_ready),
        .load_game(load_game),
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
        .bomb_radius(bomb_radius),
        .sv_bomb_active(sv_bomb_active),
        .sv_explosion_active(sv_explosion_active),
        .sv_bomb_tx_flat(sv_bomb_tx_flat), 
        .sv_bomb_ty_flat(sv_bomb_ty_flat),
        .sv_explosion_stage_flat(sv_explosion_stage_flat)
    );
        
    wire [1:0] active_bombs = bomb_active[0] + bomb_active[1];
    wire stun_trigger = !p2_dead && (active_bombs >= bomb_count) && mouse_right_pulse;
    
    stun_controller p2_stun (
        .clk(clk), .rst_game(rst_game), .game_ready(game_ready),
        .trigger(stun_trigger),
        .facing(facing),
        .player_x(p2_x), .player_y(p2_y),
        .stun_active(stun_active),
        .stun_x0(stun_x0), .stun_x1(stun_x1),
        .stun_y0(stun_y0), .stun_y1(stun_y1),
        .victim_x(p1_x), .victim_y(p1_y),
        .victim_stunned(p1_stunned)
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
