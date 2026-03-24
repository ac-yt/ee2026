`timescale 1ns / 1ps

`include "constants.vh"

module player_controller (input clk,
                          input player_number,
                          input [3:0] mouse_tx,
                          input [3:0] mouse_ty,
                          input mouse_left, mouse_right, mouse_middle,
                          input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
                          input [1:0] speed_multiplier,
                          input map_changed,
                          
                          output reg [3:0] player_tx, player_ty,
                          output reg [6:0] player_x,
                          output reg [5:0] player_y,
                          output player_dead, 
                          
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
    
    reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];
    integer ux, uy; // unpack map
    always @(*) begin
        for (uy = 0; uy < `TILE_MAP_HEIGHT; uy = uy + 1)
            for (ux = 0; ux < `TILE_MAP_WIDTH; ux = ux + 1)
                tile_map[ux][uy] = tile_map_flat[(uy*`TILE_MAP_WIDTH + ux)*3 +: 3];
    end
    
    // variable speed based on power ups
    wire [$clog2(`PLAYER_MAX_SPEED)-1:0] speed = `PLAYER_DEFAULT_SPEED + speed_multiplier * `PLAYER_SPEED_INCREMENT;
    
    reg mouse_left_prev = 0, mouse_right_prev = 0, mouse_middle_prev = 0;
    wire mouse_left_pulse = mouse_left & ~mouse_left_prev;  // single cycle on press
    wire mouse_right_pulse = mouse_right & ~mouse_right_prev;  // single cycle on press
    wire mouse_middle_pulse = mouse_middle & ~mouse_middle_prev;  // single cycle on press
    
    reg [3:0] goal_tx = 0, goal_ty = 0;
    
    always @ (posedge clk) begin
        mouse_left_prev <= mouse_left;
        mouse_right_prev <= mouse_right;
        mouse_middle_prev <= mouse_middle;
        
        if (mouse_left_pulse) begin
            goal_tx <= mouse_tx;
            goal_ty <= mouse_ty;
        end
    end
    
    wire [3:0] mc_player_tx, mc_player_ty;
    wire [6:0] mc_player_x;
    wire [5:0] mc_player_y;
    
    always @ (posedge clk) begin
        if (!player_dead) begin
            player_tx <= mc_player_tx;
            player_ty <= mc_player_ty;
            player_x <= mc_player_x;
            player_y <= mc_player_y;
        end
    end
    
    wire [3:0] spawn_tx = (player_number == `PLAYER_1) ? 0 : 14;
    wire [3:0] spawn_ty = (player_number == `PLAYER_1) ? 0 : 8;
    wire next_is_block;
    
    movement_controller player_move (.clk(clk), .map_changed(map_changed), .spawn_tx(spawn_tx), .spawn_ty(spawn_ty), .goal_tx(goal_tx), .goal_ty(goal_ty),
                                     .tile_map_flat(tile_map_flat), .speed(speed), .is_player(1),
                                     .pos_tx_out(mc_player_tx), .pos_ty_out(mc_player_ty), .pos_x(mc_player_x), .pos_y(mc_player_y),
                                     .next_is_block(next_is_block));
//                                     .pos_tx_out(player_tx), .pos_ty_out(player_ty), .pos_x(player_x), .pos_y(player_y));
    
    // bomb controller
    wire bomb_passable;
    wire player_hit;
        
    bomb_controller bomb_ctrl_inst (
        .clk(clk),
        .trigger(mouse_right),
        .tile_map_flat(tile_map_flat),
        .player_x(player_x),
        .player_y(player_y),
        .player_tx(player_tx),
        .player_ty(player_ty),
        .player_dead(player_dead),
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