`timescale 1ns / 1ps

`include "constants.vh"

module player_two_controller(input clk,
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
                                                     
                           output place_bomb_req,
                           output [3:0] place_bomb_tx,
                           output [3:0] place_bomb_ty,
                       
                           output clear_bomb_req,
                           output [3:0] clear_bomb_tx,
                           output [3:0] clear_bomb_ty,
                       
                           output destroy_up_req,
                           output [3:0] destroy_up_tx,
                           output [3:0] destroy_up_ty,
                       
                           output destroy_down_req,
                           output [3:0] destroy_down_tx,
                           output [3:0] destroy_down_ty,
                       
                           output destroy_left_req,
                           output [3:0] destroy_left_tx,
                           output [3:0] destroy_left_ty,
                       
                           output destroy_right_req,
                           output [3:0] destroy_right_tx,
                           output [3:0] destroy_right_ty,
                           
                           output bomb_active,
                           output [3:0] bomb_tx,
                           output [3:0] bomb_ty,
                           output bomb_red,
                       
                           output explosion_active,
                           output [3:0] explosion_stage,
                           output [3:0] explode_up_len,
                           output [3:0] explode_down_len,
                           output [3:0] explode_left_len,
                           output [3:0] explode_right_len,
                           
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
            bomb_trigger <= ~bomb_active & next_is_block; //((next_is_block & ~next_is_block_prev)); // | (near_player & ~near_player_prev)); 
        end
        else begin
            bomb_trigger <= mouse_right_pulse;
        end
    end
    
    // bomb controller
    wire bomb_passable;
    wire player_hit;
         
    bomb_controller bomb_ctrl_inst (
        .clk(clk),
        .trigger(bomb_trigger),
        .tile_map_flat(tile_map_flat),
        .player_x(p2_x),
        .player_y(p2_y),
        .player_tx(p2_tx),
        .player_ty(p2_ty),
        .player_dead(p2_dead),
        .bomb_active(bomb_active),
        .bomb_passable(bomb_passable),
        .bomb_tx(bomb_tx),
        .bomb_ty(bomb_ty),
        .bomb_red(bomb_red),
        .explosion_active(explosion_active),
        .explosion_stage(explosion_stage),
        .explode_up_len(explode_up_len),
        .explode_down_len(explode_down_len),
        .explode_left_len(explode_left_len),
        .explode_right_len(explode_right_len),
        .player_hit(player_hit),
        .place_bomb_req(place_bomb_req),
        .place_bomb_tx(place_bomb_tx),
        .place_bomb_ty(place_bomb_ty),
        .clear_bomb_req(clear_bomb_req),
        .clear_bomb_tx(clear_bomb_tx),
        .clear_bomb_ty(clear_bomb_ty),
        .destroy_up_req(destroy_up_req),
        .destroy_up_tx(destroy_up_tx),
        .destroy_up_ty(destroy_up_ty),
        .destroy_down_req(destroy_down_req),
        .destroy_down_tx(destroy_down_tx),
        .destroy_down_ty(destroy_down_ty),
        .destroy_left_req(destroy_left_req),
        .destroy_left_tx(destroy_left_tx),
        .destroy_left_ty(destroy_left_ty),
        .destroy_right_req(destroy_right_req),
        .destroy_right_tx(destroy_right_tx),
        .destroy_right_ty(destroy_right_ty)
    );
endmodule


module computer_controller(input clk, 
                           input [3:0] goal_tx, goal_ty,
                           input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                           input [1:0] speed_multiplier,
                           input map_changed,
                           
                           output [3:0] computer_tx, computer_ty,
                           output [6:0] computer_x,
                           output [5:0] computer_y,
                           output computer_dead,
                                                     
                           output place_bomb_req,
                           output [3:0] place_bomb_tx,
                           output [3:0] place_bomb_ty,
                       
                           output clear_bomb_req,
                           output [3:0] clear_bomb_tx,
                           output [3:0] clear_bomb_ty,
                       
                           output destroy_up_req,
                           output [3:0] destroy_up_tx,
                           output [3:0] destroy_up_ty,
                       
                           output destroy_down_req,
                           output [3:0] destroy_down_tx,
                           output [3:0] destroy_down_ty,
                       
                           output destroy_left_req,
                           output [3:0] destroy_left_tx,
                           output [3:0] destroy_left_ty,
                       
                           output destroy_right_req,
                           output [3:0] destroy_right_tx,
                           output [3:0] destroy_right_ty,
                           
                           output bomb_active,
                           output [3:0] bomb_tx,
                           output [3:0] bomb_ty,
                           output bomb_red,
                       
                           output explosion_active,
                           output [3:0] explosion_stage,
                           output [3:0] explode_up_len,
                           output [3:0] explode_down_len,
                           output [3:0] explode_left_len,
                           output [3:0] explode_right_len,
                           
                           output update, blocks_as_walls,
                           input [4*`MAX_PATH_LEN-1:0] path_flat_x, path_flat_y,
                           input path_valid, 
                           input [6:0] path_len);
                                                      
    wire [$clog2(`PLAYER_MAX_SPEED)-1:0] speed = `COMPUTER_DEFAULT_SPEED + speed_multiplier * `COMPUTER_SPEED_INCREMENT;
    
//    wire [3:0] mc_computer_tx, mc_computer_ty;
//    wire [6:0] mc_computer_x;
//    wire [5:0] mc_computer_y;
    
    // place bomb if blocked by block
    wire next_is_block;
//    reg next_is_block_prev = 0;
//    always @(posedge clk) next_is_block_prev <= next_is_block;
    
    movement_controller comp_move (.clk(clk), .map_changed(map_changed), .spawn_tx(14), .spawn_ty(8),
                                   .goal_tx(goal_tx), .goal_ty(goal_ty), .tile_map_flat(tile_map_flat), .speed(speed), .is_player(1),
                                   .next_is_block(next_is_block), .pos_tx_out(computer_tx), .pos_ty_out(computer_ty), .pos_x(computer_x), .pos_y(computer_y),
                                   .as_update(update), .as_baw(blocks_as_walls), .path_flat_x(path_flat_x), .path_flat_y(path_flat_y),
                                   .path_valid(path_valid), .path_len(path_len));
       
        
//    movement_controller comp_move (.clk(clk), .map_changed(map_changed), .spawn_tx(14), .spawn_ty(8), .goal_tx(player_tx), .goal_ty(player_ty),
//                                   .tile_map_flat(tile_map_flat), .speed(speed), .is_player(0),// .stop(next_is_block),
//                                   .pos_tx_out(computer_tx), .pos_ty_out(computer_ty), .pos_x(computer_x), .pos_y(computer_y),
//                                   .next_is_block(next_is_block));
//                                   .pos_tx_out(mc_computer_tx), .pos_ty_out(mc_computer_ty), .pos_x(mc_computer_x), .pos_y(mc_computer_y));
    
//     place bomb if near player
//    wire [4:0] dist_to_player = ((computer_tx > player_tx) ? computer_tx - player_tx : player_tx - computer_tx) +
//                                ((computer_ty > player_ty) ? computer_ty - player_ty : player_ty - computer_ty);
//    wire near_player = (dist_to_player <= 2); // within 2 tiles
//    reg near_player_prev = 0;
//    always @(posedge clk) near_player_prev <= near_player;
    
    wire bomb_trigger;// = ~bomb_active & next_is_block; //((next_is_block & ~next_is_block_prev)); // | (near_player & ~near_player_prev));
    
    // bomb controller
    wire bomb_passable;
    wire player_hit;
         
    bomb_controller bomb_ctrl_inst (
        .clk(clk),
        .trigger(bomb_trigger),
        .tile_map_flat(tile_map_flat),
        .player_x(computer_x),
        .player_y(computer_y),
        .player_tx(computer_tx),
        .player_ty(computer_ty),
        .player_dead(computer_dead),
        .bomb_active(bomb_active),
        .bomb_passable(bomb_passable),
        .bomb_tx(bomb_tx),
        .bomb_ty(bomb_ty),
        .bomb_red(bomb_red),
        .explosion_active(explosion_active),
        .explosion_stage(explosion_stage),
        .explode_up_len(explode_up_len),
        .explode_down_len(explode_down_len),
        .explode_left_len(explode_left_len),
        .explode_right_len(explode_right_len),
        .player_hit(player_hit),
        .place_bomb_req(place_bomb_req),
        .place_bomb_tx(place_bomb_tx),
        .place_bomb_ty(place_bomb_ty),
        .clear_bomb_req(clear_bomb_req),
        .clear_bomb_tx(clear_bomb_tx),
        .clear_bomb_ty(clear_bomb_ty),
        .destroy_up_req(destroy_up_req),
        .destroy_up_tx(destroy_up_tx),
        .destroy_up_ty(destroy_up_ty),
        .destroy_down_req(destroy_down_req),
        .destroy_down_tx(destroy_down_tx),
        .destroy_down_ty(destroy_down_ty),
        .destroy_left_req(destroy_left_req),
        .destroy_left_tx(destroy_left_tx),
        .destroy_left_ty(destroy_left_ty),
        .destroy_right_req(destroy_right_req),
        .destroy_right_tx(destroy_right_tx),
        .destroy_right_ty(destroy_right_ty)
    );
endmodule