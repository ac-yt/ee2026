`timescale 1ns / 1ps

`include "constants.vh"

module p2_controller(input clk, rst_game, game_ready_in,
                     input single_player, load_game,
                     input [3:0] p1_tx, p1_ty, p1_goal_tx, p1_goal_ty, mouse_tx, mouse_ty, sv_tx, sv_ty, // done in top student
                     input mouse_left_pulse, mouse_right_pulse, mouse_middle_pulse,
                     input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                     input [1:0] speed_multiplier,
                     input map_changed,
                     
                     output reg [2:0] led,
                     
                     output [3:0] goal_tx, goal_ty,
                     output reg [3:0] p2_tx, p2_ty, //mc_p2_x, mc_p2_y,
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
                     input p2_stunned,
                    
                     output stun_active, p1_stunned,
                     output [6:0] stun_x0, stun_x1,
                     output [5:0] stun_y0, stun_y1
);

    wire game_ready = game_ready_in && !p2_stunned;
    
    reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];
    integer ux, uy; // unpack map
    always @(*) begin
        for (uy = 0; uy < `TILE_MAP_HEIGHT; uy = uy + 1)
            for (ux = 0; ux < `TILE_MAP_WIDTH; ux = ux + 1)
                tile_map[ux][uy] = tile_map_flat[(uy*`TILE_MAP_WIDTH + ux)*3 +: 3];
    end
                                                      
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
    reg bomb_player = 0, hunt_bomb_player = 0;
    reg bomb_number = 0, hunt_bomb_number = 0;
//    reg p1_bait_escape = 0;
    
    parameter BOT_HUNT = 3'b000; // normal chase
    parameter BOT_ESCAPE = 3'b001; // escape if bomb
    parameter BOT_ESCAPE_PATH = 3'b010;
    parameter BOT_ESCAPE_HUNT = 3'b011;
    parameter BOT_BOMB = 3'b100;
    parameter BOT_POWERUP = 3'b101;
    reg [2:0] bot_state = BOT_HUNT;
    reg [2:0] bot_state_after_bomb = BOT_HUNT;
    
    reg bot_trigger = 0;
    wire next_is_block;
    reg next_is_block_prev = 0;
    always @(posedge clk) next_is_block_prev <= next_is_block;
    
    // chase bot while empty path to player
    wire at_escape = (p2_tx == escape_tx) && (p2_ty == escape_ty);
    reg bot_force_baw = 0;
    reg path_valid_prev = 0;
    always @(posedge clk) path_valid_prev <= path_valid;
    wire path_valid_pulse = path_valid & ~path_valid_prev;
    
    // dist from player to every bomb
    genvar bi;
    generate
        for (bi = 0; bi < `MAX_BOMBS; bi = bi + 1) begin : bomb_unpack
            assign p1_bomb_dist[bi] = (p1_bomb_active[bi] || p1_explosion_active[bi]) ? 
                                       manhattan_dist(p2_tx, p2_ty, p1_bomb_tx_flat[bi*4 +: 4], p1_bomb_ty_flat[bi*4 +: 4]) : 5'h1F;
            assign p2_bomb_dist[bi] = (bomb_active[bi] || explosion_active[bi]) ? 
                                       manhattan_dist(p2_tx, p2_ty, bomb_tx_flat[bi*4 +: 4], bomb_ty_flat[bi*4 +: 4]) : 5'h1F;
        end
    endgenerate
    
    wire powerup_left = (p2_tx > 0 && tile_map[p2_tx-1][p2_ty] == `MAP_POWERUP);
    wire powerup_right = (p2_tx < 14 && tile_map[p2_tx+1][p2_ty] == `MAP_POWERUP);
    wire powerup_up = (p2_ty > 0 && tile_map[p2_tx][p2_ty-1] == `MAP_POWERUP);
    wire powerup_down = (p2_ty < 8 && tile_map[p2_tx][p2_ty+1] == `MAP_POWERUP);
    
    always @ (posedge clk) begin
        bot_trigger <= 0;
        bombs_as_walls <= 0;
        bot_force_baw <= 0;
//        led[2:0] <= bot_state;
//        led[2] <= p1_bait_escape;
        
        // track closest bomb to figure out which is the danger
        if (game_ready) begin
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
        end
        
        if (rst_game) begin
            bot_state <= BOT_HUNT;
            bot_goal_tx <= `P2_SPAWN_TX;
            bot_goal_ty <= `P2_SPAWN_TY;
            bomb_player <= 0;
            bomb_number <= 0;
            hunt_bomb_player = 0;
            hunt_bomb_number = 0;
//            p1_bait_escape <= 0;
        end
        else if (load_game) begin
            bot_state <= BOT_HUNT;
            bot_goal_tx <= sv_tx;
            bot_goal_ty <= sv_ty;
            bomb_player <= 0;
            bomb_number <= 0;
            hunt_bomb_player = 0;
            hunt_bomb_number = 0;
//            p1_bait_escape <= 0;
        end
        else if (game_ready) begin
            case (bot_state)
                BOT_HUNT: begin
//                    p1_bait_escape <= 0;
                    
                    // go to p1 goal if closer to it than p1, else chase p1
                    if (manhattan_dist(p1_tx, p1_ty, p1_goal_tx, p1_goal_ty) <= manhattan_dist(p2_tx, p2_ty, p1_goal_tx, p1_goal_ty)) begin // p1 closer
                        bot_goal_tx <= p1_tx;
                        bot_goal_ty <= p1_ty;
                    end
                    else begin // bot closer
                        bot_goal_tx <= p1_goal_tx;
                        bot_goal_ty <= p1_goal_ty;
                    end
                    
                    if (powerup_left || powerup_right || powerup_up || powerup_down) begin
                        bot_state <= BOT_POWERUP;
                        
                        bot_goal_tx <= p2_tx;
                        bot_goal_ty <= p2_ty;
                        
                        if (powerup_left) bot_goal_tx <= p2_tx - 1;
                        else if (powerup_right) bot_goal_tx <= p2_tx + 1;
                        else if (powerup_up) bot_goal_ty <= p2_ty - 1;
                        else if (powerup_down) bot_goal_ty <= p2_ty + 1;
                    end
                    
                    if ((next_is_block & ~next_is_block_prev) ||
                        (p2_tx == p1_goal_tx && p2_ty == p1_goal_ty) ||
                        (manhattan_dist(p2_tx, p2_ty, p1_tx, p1_ty) <= bomb_radius && (p2_tx == p1_tx || p2_ty == p1_ty))) begin
                        bot_state_after_bomb <= BOT_HUNT;
                        bot_state <= BOT_BOMB; // close to p1
                    end
                    
                    if (in_danger) begin
                        bot_state <= BOT_ESCAPE;
                        bot_goal_tx <= escape_tx;
                        bot_goal_ty <= escape_ty;
                    end
                end
                BOT_ESCAPE: begin
                    if (escape_tx != bot_goal_tx || escape_ty != bot_goal_ty) begin
                        bot_goal_tx <= escape_tx;
                        bot_goal_ty <= escape_ty;
                    end
                    
                    if (bomb_player == 0 && !p1_bomb_active[bomb_number] && !p1_explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                    else if (bomb_player == 1 && !bomb_active[bomb_number] && !explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                    else if (at_escape) bot_state <= BOT_ESCAPE_PATH;
                end
                BOT_ESCAPE_PATH: begin // see if there is empty path
                    // take bombs as walls
                    bombs_as_walls <= 1;
                    bot_force_baw <= 1;
                    
                    bot_goal_tx <= p1_tx; // update req will be sent when new goal is set
                    bot_goal_ty <= p1_ty;
                    
                    if (bomb_player == 0 && !p1_bomb_active[bomb_number] && !p1_explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                    else if (bomb_player == 1 && !bomb_active[bomb_number] && !explosion_active[bomb_number]) bot_state <= BOT_HUNT;    
//                    else if (p1_bait_escape) bot_state <= BOT_ESCAPE;                
                    else if (path_valid_pulse) begin
                        bot_state <= (path_len == 0) ? BOT_ESCAPE : BOT_ESCAPE_HUNT;
                        hunt_bomb_player <= bomb_player;  // which bomb we planned around
                        hunt_bomb_number <= bomb_number;
                    end
                end
                BOT_ESCAPE_HUNT: begin
                    // take bombs as walls
                    bombs_as_walls <= 1;
                    bot_force_baw <= 1;
                    
                    bot_goal_tx <= p1_tx; // update req will be sent when new goal is set
                    bot_goal_ty <= p1_ty;
                    
                    // allow to place bombs
                    if ((next_is_block & ~next_is_block_prev) ||
                        (p2_tx == p1_goal_tx && p2_ty == p1_goal_ty) ||
                        (manhattan_dist(p2_tx, p2_ty, p1_tx, p1_ty) <= bomb_radius && (p2_tx == p1_tx || p2_ty == p1_ty))) begin
                        bot_state_after_bomb <= BOT_ESCAPE_HUNT;
                        bot_state <= BOT_BOMB; // close to p1
                    end
                    
                    if (bomb_player == 0 && !p1_bomb_active[bomb_number] && !p1_explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                    else if (bomb_player == 1 && !bomb_active[bomb_number] && !explosion_active[bomb_number]) bot_state <= BOT_HUNT;
                    else if (in_danger) begin
                        if (bomb_player != hunt_bomb_player || bomb_number != hunt_bomb_number) bot_state <= BOT_ESCAPE; // escape if player placed a new bomb in the way
                        else if (path_valid_pulse && path_len == 0) bot_state <= BOT_ESCAPE; // if player runs across bomb run away
//                        else if (p2_tx == p1_tx && p2_ty == p1_ty) begin
//                            bot_state <= BOT_ESCAPE; // run away if player tries to bait it
//                            p1_bait_escape <= 1;
//                        end
                    end
                end
                BOT_BOMB: begin
                    bot_trigger <= game_ready; // prevent placement when not ready
                    bot_state <= bot_state_after_bomb; //BOT_HUNT;
                end
                BOT_POWERUP: begin
                    if (bot_goal_tx == p2_tx && bot_goal_ty == p2_ty) bot_state <= BOT_HUNT;
                    else if (in_danger) bot_state <= BOT_ESCAPE;
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
        .path_len(path_len),
        .bot_force_baw(bot_force_baw)
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
//    wire player_stun_trigger = !p2_dead && (active_bombs >= bomb_count) && mouse_right_pulse;
    
    // which direction p1 is relative to p2
    wire p1_is_right = (p1_tx > p2_tx) && (p2_ty == p1_ty);
    wire p1_is_left = (p1_tx < p2_tx) && (p2_ty == p1_ty);
    wire p1_is_down = (p1_ty > p2_ty) && (p2_tx == p1_tx);
    wire p1_is_up = (p1_ty < p2_ty) && (p2_tx == p1_tx);
    
    wire facing_player = (facing == `FACE_RIGHT && p1_is_right) ||
                         (facing == `FACE_LEFT && p1_is_left) ||
                         (facing == `FACE_DOWN && p1_is_down) ||
                         (facing == `FACE_UP && p1_is_up);
    
    wire bot_stun_trigger = (manhattan_dist(p2_tx, p2_ty, p1_tx, p1_ty) == 1) && facing_player; // next to player and facing player
    wire player_stun_trigger = mouse_right_pulse;

    wire stun_trigger = (!p2_dead && active_bombs >= bomb_count) ? (single_player ? bot_stun_trigger : player_stun_trigger) : 0;
    
    stun_controller p2_stun (
        .clk(clk), .rst_game(rst_game), .game_ready(game_ready_in),
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
