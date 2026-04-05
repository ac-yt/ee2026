`timescale 1ns / 1ps

`include "constants.vh"

module p1_controller (input clk, rst_game, game_ready,
                      input [3:0] mouse_tx, mouse_ty, //goal_tx, goal_ty,
                      input mouse_left_pulse, mouse_right_pulse, mouse_middle_pulse,
                      input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                      input [1:0] speed_multiplier,
                      input map_changed,
                      
                      output reg [3:0] goal_tx, goal_ty,
                      output reg [3:0] p1_tx, p1_ty,
                      output reg [6:0] p1_x,
                      output reg [5:0] p1_y,
                      output [1:0] facing,   // 0=right 1=left 2=down 3=up
                      input p1_dead, 
                      input p1_stunned,
                      
                      output [`MAX_BOMBS-1:0] place_bomb_req, bomb_active, bomb_red, explosion_active,
                      output [`MAX_BOMBS*4-1:0] bomb_tx_flat, bomb_ty_flat,
                      output [`MAX_BOMBS*2-1:0] explosion_stage_flat,
                      
                      input [1:0] bomb_count, // number of bombs that can be placed
                      input [1:0] bomb_radius, // radius of bom
                      
                      output update, blocks_as_walls, //bombs_as_walls,
                      input [4*`MAX_PATH_LEN-1:0] path_flat_x, path_flat_y,
                      input path_valid, 
                      input [6:0] path_len);
      
    always @ (posedge clk) begin
        if (rst_game) begin
            goal_tx <= 0;
            goal_ty <= 0;
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
   
    movement_controller player_move (.clk(clk), .map_changed(map_changed), .spawn_tx(0), .spawn_ty(0), .rst_game(rst_game), .game_ready(game_ready & ~p1_stunned),
                                     .goal_tx(goal_tx), .goal_ty(goal_ty), .tile_map_flat(tile_map_flat), .speed(speed), .is_player(1),
                                     .next_is_block(next_is_block), .pos_tx_out(mc_p1_tx), .pos_ty_out(mc_p1_ty), .pos_x(mc_p1_x), .pos_y(mc_p1_y), .facing(facing),
                                     .as_update(update), .as_baw(blocks_as_walls), .path_flat_x(path_flat_x), .path_flat_y(path_flat_y),
                                     .path_valid(path_valid), .path_len(path_len));
//                                     .force_baw(0), .force_bmaw(0), .as_bmaw(bombs_as_walls));
    
    wire bomb_trigger = p1_dead ? 0 : mouse_right_pulse;
    
    bomb_controller p1_bomb_inst (
        .clk(clk),
        .rst_game(rst_game),
        .game_ready(game_ready & ~p1_stunned),
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
        .bomb_radius(bomb_radius)
    );
    
endmodule