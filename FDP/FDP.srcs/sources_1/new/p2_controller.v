`timescale 1ns / 1ps

`include "constants.vh"

module p2_controller(input clk,
                     input single_player,
                     input [3:0] goal_tx, goal_ty, // done in top student
                     input mouse_left_pulse, mouse_right_pulse, mouse_middle_pulse,
                     input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                     input [1:0] speed_multiplier,
                     input map_changed,
                       
                     output reg [3:0] p2_tx, p2_ty,
                     output reg [6:0] p2_x,
                     output reg [5:0] p2_y,
                     output p2_dead,
                     
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
                                                 `COMPUTER_DEFAULT_SPEED + speed_multiplier * `COMPUTER_SPEED_INCREMENT : 
                                                 `PLAYER_DEFAULT_SPEED + speed_multiplier * `PLAYER_SPEED_INCREMENT;
    
    // COMPUTER 
    wire next_is_block;
    reg next_is_block_prev = 0;
    always @(posedge clk) next_is_block_prev <= next_is_block;
    
    
        // place bomb if near player
    //    wire [4:0] dist_to_player = ((computer_tx > player_tx) ? computer_tx - player_tx : player_tx - computer_tx) +
    //                                ((computer_ty > player_ty) ? computer_ty - player_ty : player_ty - computer_ty);
    //    wire near_player = (dist_to_player <= 2); // within 2 tiles
    //    reg near_player_prev = 0;
    //    always @(posedge clk) near_player_prev <= near_player;
    
    
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
        if (single_player) begin
            bomb_trigger <= (next_is_block & ~next_is_block_prev); //~bomb_active & next_is_block; //((next_is_block & ~next_is_block_prev)); // | (near_player & ~near_player_prev)); 
        end
        else begin
            bomb_trigger <= mouse_right_pulse;
        end
    end
    
    bomb_controller p2_bomb_inst (
        .clk(clk),
        .trigger(bomb_trigger),
        .player_tx(p2_tx),
        .player_ty(p2_ty),
        .player_dead(p2_dead),
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