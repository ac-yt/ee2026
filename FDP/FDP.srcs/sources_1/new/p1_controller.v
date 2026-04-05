`timescale 1ns / 1ps

`include "constants.vh"

module p1_controller (input clk, rst_game, game_ready, load_game,
                      input [3:0] mouse_tx, mouse_ty, sv_tx, sv_ty,//goal_tx, goal_ty,
                      input mouse_left_pulse, mouse_right_pulse, mouse_middle_pulse,
                      input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                      input [1:0] speed_multiplier,
                      input map_changed,
                      
                      output reg [3:0] goal_tx, goal_ty,
                      output reg [3:0] p1_tx, p1_ty,
                      output reg [6:0] p1_x,
                      output reg [5:0] p1_y,
                      input p1_dead, 
                      
                      output [`MAX_BOMBS-1:0] place_bomb_req, bomb_active, bomb_red, explosion_active,
                      output [`MAX_BOMBS*4-1:0] bomb_tx_flat, bomb_ty_flat,
                      output [`MAX_BOMBS*2-1:0] explosion_stage_flat,
                      
                      input [1:0] bomb_count, // number of bombs that can be placed
                      input [1:0] bomb_radius, // radius of bom
                      
                      input [`MAX_BOMBS-1:0] sv_bomb_active,
                      input [`MAX_BOMBS-1:0] sv_explosion_active,
                      input [`MAX_BOMBS*4-1:0] sv_bomb_tx_flat, sv_bomb_ty_flat,
                      input [`MAX_BOMBS*2-1:0] sv_explosion_stage_flat,
                      
                      output update, blocks_as_walls, //bombs_as_walls,
                      input [4*`MAX_PATH_LEN-1:0] path_flat_x, path_flat_y,
                      input path_valid, 
                      input [6:0] path_len,
                      
                      // stun
                      input [6:0] p2_x,
                      input [5:0] p2_y,
                      
                      output stun_active, p2_stunned,
                      output [6:0] stun_x0, stun_x1,
                      output [5:0] stun_y0, stun_y1
);
      
    always @ (posedge clk) begin
        if (rst_game) begin
            goal_tx <= `P1_SPAWN_TX;
            goal_ty <= `P1_SPAWN_TY;
        end
        else if (load_game) begin
            goal_tx <= sv_tx;
            goal_ty <= sv_ty;
        end
        else if (game_ready) begin
            if (mouse_left_pulse) begin
                goal_tx <= mouse_tx;
                goal_ty <= mouse_ty;
            end
        end
    end
    
    // variable speed based on power ups
    wire [$clog2(`PLAYER_MAX_SPEED)-1:0] speed = `PLAYER_DEFAULT_SPEED + speed_multiplier * `PLAYER_SPEED_INCREMENT;
    
    wire [3:0] mc_p1_tx, mc_p1_ty;
    wire [6:0] mc_p1_x;
    wire [5:0] mc_p1_y;
    
    always @ (posedge clk) begin
        if (!p1_dead) begin
            p1_tx <= mc_p1_tx;
            p1_ty <= mc_p1_ty;
            p1_x <= mc_p1_x;
            p1_y <= mc_p1_y;
        end
    end
    
    wire next_is_block;
    wire [1:0] facing;
   
    movement_controller player_move (
        .clk(clk), 
        .map_changed(map_changed), 
        .spawn_tx(`P1_SPAWN_TX), 
        .spawn_ty(`P1_SPAWN_TY), 
        .load_game(load_game),
        .sv_tx(sv_tx),
        .sv_ty(sv_ty),
        .rst_game(rst_game), 
        .game_ready(game_ready),
        .goal_tx(goal_tx), 
        .goal_ty(goal_ty), 
        .tile_map_flat(tile_map_flat), 
        .speed(speed), 
        .is_player(1),
        .next_is_block(next_is_block), 
        .last_dir(facing),
        .pos_tx_out(mc_p1_tx), 
        .pos_ty_out(mc_p1_ty), 
        .pos_x(mc_p1_x), 
        .pos_y(mc_p1_y),
        .as_update(update), 
        .as_baw(blocks_as_walls), 
        .path_flat_x(path_flat_x), 
        .path_flat_y(path_flat_y),
        .path_valid(path_valid), 
        .path_len(path_len)
    );
//                                     .force_baw(0), .force_bmaw(0), .as_bmaw(bombs_as_walls));
    
    wire bomb_trigger = p1_dead ? 0 : mouse_right_pulse;
    
    bomb_controller p1_bomb_inst (
        .clk(clk),
        .rst_game(rst_game),
        .game_ready(game_ready),
        .load_game(load_game),
        .trigger(bomb_trigger),
        .player_tx(p1_tx),
        .player_ty(p1_ty),
//        .player_dead(p1_dead),
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
    wire stun_trigger = !p1_dead && (active_bombs >= bomb_count) && mouse_right_pulse;
    
    stun_controller p1_stun (
        .clk(clk), .rst_game(rst_game), .game_ready(game_ready),
        .trigger(stun_trigger),
        .facing(facing),
        .player_x(p1_x), .player_y(p1_y),
        .stun_active(stun_active),
        .stun_x0(stun_x0), .stun_x1(stun_x1),
        .stun_y0(stun_y0), .stun_y1(stun_y1),
        .victim_x(p2_x), .victim_y(p2_y),
        .victim_stunned(p2_stunned)
    );
    
endmodule