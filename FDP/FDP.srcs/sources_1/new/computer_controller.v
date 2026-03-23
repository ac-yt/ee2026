`timescale 1ns / 1ps

`include "constants.vh"

module computer_controller(input clk,
                           input [3:0] player_tx,
                           input [3:0] player_ty,
                           input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                           input [1:0] speed_multiplier,
                           
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
                           output [3:0] explode_right_len);
                                                      
    wire [$clog2(`PLAYER_MAX_SPEED)-1:0] speed = `COMPUTER_DEFAULT_SPEED + speed_multiplier * `COMPUTER_SPEED_INCREMENT;
    
//    wire [3:0] mc_computer_tx, mc_computer_ty;
//    wire [6:0] mc_computer_x;
//    wire [5:0] mc_computer_y;
    
    wire [3:0] next_tx, next_ty;
    movement_controller comp_move (.clk(clk), .goal_tx(player_tx), .goal_ty(player_ty), .tile_map_flat(tile_map_flat), .speed(speed), .is_player(0),
                                   .pos_tx_out(computer_tx), .pos_ty_out(computer_ty), .pos_x(computer_x), .pos_y(computer_y));
//                                   .pos_tx_out(mc_computer_tx), .pos_ty_out(mc_computer_ty), .pos_x(mc_computer_x), .pos_y(mc_computer_y));
                           
    // bomb controller
    wire bomb_passable;
    wire player_hit;
    wire trigger = 0;
         
    bomb_controller bomb_ctrl_inst (
        .clk(clk),
        .trigger(trigger),
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