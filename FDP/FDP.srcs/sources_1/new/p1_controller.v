`timescale 1ns / 1ps

`include "constants.vh"

module p1_controller (input clk,
                      input [3:0] goal_tx, goal_ty,
                      input mouse_left_pulse, mouse_right_pulse, mouse_middle_pulse,
                      input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                      input [1:0] speed_multiplier,
                      input map_changed,
                      
                      output reg [3:0] p1_tx, p1_ty,
                      output reg [6:0] p1_x,
                      output reg [5:0] p1_y,
                      output p1_dead, 
                      
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
    
    reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];
    integer ux, uy; // unpack map
    always @(*) begin
        for (uy = 0; uy < `TILE_MAP_HEIGHT; uy = uy + 1)
            for (ux = 0; ux < `TILE_MAP_WIDTH; ux = ux + 1)
                tile_map[ux][uy] = tile_map_flat[(uy*`TILE_MAP_WIDTH + ux)*3 +: 3];
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
   
    movement_controller player_move (.clk(clk), .map_changed(map_changed), .spawn_tx(0), .spawn_ty(0),
                                     .goal_tx(goal_tx), .goal_ty(goal_ty), .tile_map_flat(tile_map_flat), .speed(speed), .is_player(1),
                                     .next_is_block(next_is_block), .pos_tx_out(mc_p1_tx), .pos_ty_out(mc_p1_ty), .pos_x(mc_p1_x), .pos_y(mc_p1_y),
                                     .as_update(update), .as_baw(blocks_as_walls), .path_flat_x(path_flat_x), .path_flat_y(path_flat_y),
                                     .path_valid(path_valid), .path_len(path_len));
         
    
    // bomb controller
    wire bomb_passable;
    wire player_hit;
        
    bomb_controller bomb_ctrl_inst (
        .clk(clk),
        .trigger(mouse_right_pulse),
        .tile_map_flat(tile_map_flat),
        .player_x(p1_x),
        .player_y(p1_y),
        .player_tx(p1_tx),
        .player_ty(p1_ty),
        .player_dead(p1_dead),
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