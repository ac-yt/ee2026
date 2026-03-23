`timescale 1ns / 1ps

`include "constants.vh"

module player_controller (
    input clk,
    input btnL,
    input btnR,
    input btnU,
    input btnD,
    input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
    input bomb_active,
    input bomb_passable,
    input [3:0] bomb_tx,
    input [3:0] bomb_ty,
    input player_hit,
    input [1:0] player_speed_multiplier,
    output reg [6:0] player_x = `MIN_PIX_X,
    output reg [5:0] player_y = `MIN_PIX_Y,
    output reg [3:0] player_tx,
    output reg [3:0] player_ty,
    output reg player_dead = 0
);  
    // added this to unpack tile map
    reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];
    integer ux, uy; // unpack map
    always @(*) begin
        for (uy = 0; uy < `TILE_MAP_HEIGHT; uy = uy + 1)
            for (ux = 0; ux < `TILE_MAP_WIDTH; ux = ux + 1)
                tile_map[ux][uy] = tile_map_flat[(uy*`TILE_MAP_WIDTH + ux)*3 +: 3];
    end
    
    // variable player speed
    parameter PLAYER_COUNT_MAX = `CLOCK_SPEED / `PLAYER_DEFAULT_SPEED;
    reg [$clog2(PLAYER_COUNT_MAX)-1:0] player_counter = 0;
    wire [31:0] player_count_thresh = `CLOCK_SPEED / (`PLAYER_DEFAULT_SPEED + player_speed_multiplier * `PLAYER_SPEED_INCREMENT); // changes based on speed
    wire move_tick = (player_counter == player_count_thresh - 1);

    always @(posedge clk) begin
        if (player_counter == player_count_thresh - 1)
            player_counter <= 0;
        else
            player_counter <= player_counter + 1;
    end

    function [3:0] pixel_to_tile_x;
        input [6:0] px;
    begin
        pixel_to_tile_x = ((px - `MIN_PIX_X) * 7'd43) >> 8; //(px - `MIN_PIX_X) / `TILE_SIZE;
    end
    endfunction

    function [3:0] pixel_to_tile_y;
        input [5:0] py;
    begin
        pixel_to_tile_y = ((py - `MIN_PIX_Y) * 7'd43) >> 8; //(py - `MIN_PIX_Y) / `TILE_SIZE;
    end
    endfunction

    function is_walkable_tile;
        input [3:0] tx_in;
        input [3:0] ty_in;
        reg [2:0] tile_val;
    begin
        if (tx_in >= `TILE_MAP_WIDTH || ty_in >= `TILE_MAP_HEIGHT)
            is_walkable_tile = 0;
        else begin
            tile_val = tile_map[tx_in][ty_in];//tile_map_flat[(ty_in*`TILE_MAP_WIDTH + tx_in)*3 +: 3]; // [tx_in][ty_in];
            case (tile_val)
                `MAP_EMPTY,
                `MAP_POWERUP: is_walkable_tile = 1;
                default:      is_walkable_tile = 0;
            endcase
        end
    end
    endfunction

    function bomb_tile_is_exception;
        input [3:0] tx_in;
        input [3:0] ty_in;
    begin
        bomb_tile_is_exception = bomb_active && bomb_passable && (tx_in == bomb_tx) && (ty_in == bomb_ty);
    end
    endfunction
    
    // tile edge coords
    reg [3:0] tx_left_r=0,  tx_right_r=0;
    reg [3:0] ty_top_r=0,   ty_bot_r=0;
    reg [3:0] tx_ll_r=0,    tx_lr_r=0;  // lead left, lead right
    reg [3:0] ty_lu_r=0,    ty_ld_r=0;  // lead up, lead down
    
    always @(posedge clk) begin
        tx_left_r  <= pixel_to_tile_x(player_x);
        tx_right_r <= pixel_to_tile_x(player_x + `PLAYER_WIDTH  - 1);
        ty_top_r   <= pixel_to_tile_y(player_y);
        ty_bot_r   <= pixel_to_tile_y(player_y + `PLAYER_HEIGHT - 1);
        tx_ll_r    <= pixel_to_tile_x(player_x - 1);
        tx_lr_r    <= pixel_to_tile_x(player_x + `PLAYER_WIDTH);
        ty_lu_r    <= pixel_to_tile_y(player_y - 1);
        ty_ld_r    <= pixel_to_tile_y(player_y + `PLAYER_HEIGHT);
    end
    
    // use registered to reduce wns
    wire can_left  = (player_x > `MIN_PIX_X) &&
                     (is_walkable_tile(tx_ll_r,  ty_top_r) || bomb_tile_is_exception(tx_ll_r,  ty_top_r)) &&
                     (is_walkable_tile(tx_ll_r,  ty_bot_r) || bomb_tile_is_exception(tx_ll_r,  ty_bot_r));
    
    wire can_right = (player_x + `PLAYER_WIDTH - 1 < `MAX_PIX_X) &&
                     (is_walkable_tile(tx_lr_r,  ty_top_r) || bomb_tile_is_exception(tx_lr_r,  ty_top_r)) &&
                     (is_walkable_tile(tx_lr_r,  ty_bot_r) || bomb_tile_is_exception(tx_lr_r,  ty_bot_r));
    
    wire can_up    = (player_y > `MIN_PIX_Y) &&
                     (is_walkable_tile(tx_left_r, ty_lu_r) || bomb_tile_is_exception(tx_left_r, ty_lu_r)) &&
                     (is_walkable_tile(tx_right_r, ty_lu_r) || bomb_tile_is_exception(tx_right_r, ty_lu_r));
    
    wire can_down  = (player_y + `PLAYER_HEIGHT - 1 < `MAX_PIX_Y) &&
                     (is_walkable_tile(tx_left_r, ty_ld_r) || bomb_tile_is_exception(tx_left_r, ty_ld_r)) &&
                     (is_walkable_tile(tx_right_r, ty_ld_r) || bomb_tile_is_exception(tx_right_r, ty_ld_r));
    
    // breaks the combinational feedback into player_x/y CE
    reg can_left_r=0, can_right_r=0, can_up_r=0, can_down_r=0;
    always @(posedge clk) begin
        can_left_r       <= can_left;
        can_right_r      <= can_right;
        can_up_r         <= can_up;
        can_down_r       <= can_down;
        player_tx <= pixel_to_tile_x(player_x + `PLAYER_WIDTH/2); // center of player
        player_ty <= pixel_to_tile_y(player_y + `PLAYER_HEIGHT/2);
    end
    
    always @(posedge clk) begin
        if (player_hit) player_dead <= 1;
        if (!player_dead && move_tick) begin
            if      (btnL && can_left_r)  player_x <= player_x - 1;
            else if (btnR && can_right_r) player_x <= player_x + 1;
            else if (btnU && can_up_r)    player_y <= player_y - 1;
            else if (btnD && can_down_r)  player_y <= player_y + 1;
        end
    end
endmodule