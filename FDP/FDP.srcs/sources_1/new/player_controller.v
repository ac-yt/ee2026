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
    output reg [6:0] player_x = `MIN_PIX_X,
    output reg [5:0] player_y = `MIN_PIX_Y,
    output [3:0] player_center_tx,
    output [3:0] player_center_ty,
    output reg player_dead = 0
);

    parameter PLAYER_SPEED  = 35;
    parameter PLAYER_COUNT  = `CLOCK_SPEED / PLAYER_SPEED;

    reg [$clog2(PLAYER_COUNT)-1:0] player_counter = 0;
    wire move_tick = (player_counter == PLAYER_COUNT - 1);

    always @(posedge clk) begin
        if (player_counter == PLAYER_COUNT - 1)
            player_counter <= 0;
        else
            player_counter <= player_counter + 1;
    end

    function [2:0] get_tile;
        input [3:0] tx;
        input [3:0] ty;
    begin
        get_tile = tile_map_flat[(ty*`TILE_MAP_WIDTH + tx)*3 +: 3];
    end
    endfunction

    function [3:0] pixel_to_tile_x;
        input [6:0] px;
    begin
        pixel_to_tile_x = (px - `MIN_PIX_X) / `TILE_SIZE;
    end
    endfunction

    function [3:0] pixel_to_tile_y;
        input [5:0] py;
    begin
        pixel_to_tile_y = (py - `MIN_PIX_Y) / `TILE_SIZE;
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
            tile_val = get_tile(tx_in, ty_in);
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
        bomb_tile_is_exception =
            bomb_active &&
            bomb_passable &&
            (tx_in == bomb_tx) &&
            (ty_in == bomb_ty);
    end
    endfunction

    function can_move_to;
        input [6:0] next_x;
        input [5:0] next_y;
        reg [6:0] right_x;
        reg [5:0] bottom_y;
        reg [3:0] tl_tx, tr_tx, bl_tx, br_tx;
        reg [3:0] tl_ty, tr_ty, bl_ty, br_ty;
        reg tl_ok, tr_ok, bl_ok, br_ok;
    begin
        if (next_x < `MIN_PIX_X ||
            next_y < `MIN_PIX_Y ||
            (next_x + `PLAYER_WIDTH  - 1) > `MAX_PIX_X ||
            (next_y + `PLAYER_HEIGHT - 1) > `MAX_PIX_Y) begin
            can_move_to = 0;
        end
        else begin
            right_x  = next_x + `PLAYER_WIDTH  - 1;
            bottom_y = next_y + `PLAYER_HEIGHT - 1;

            tl_tx = pixel_to_tile_x(next_x);
            tr_tx = pixel_to_tile_x(right_x);
            bl_tx = pixel_to_tile_x(next_x);
            br_tx = pixel_to_tile_x(right_x);

            tl_ty = pixel_to_tile_y(next_y);
            tr_ty = pixel_to_tile_y(next_y);
            bl_ty = pixel_to_tile_y(bottom_y);
            br_ty = pixel_to_tile_y(bottom_y);

            tl_ok = is_walkable_tile(tl_tx, tl_ty) || bomb_tile_is_exception(tl_tx, tl_ty);
            tr_ok = is_walkable_tile(tr_tx, tr_ty) || bomb_tile_is_exception(tr_tx, tr_ty);
            bl_ok = is_walkable_tile(bl_tx, bl_ty) || bomb_tile_is_exception(bl_tx, bl_ty);
            br_ok = is_walkable_tile(br_tx, br_ty) || bomb_tile_is_exception(br_tx, br_ty);

            can_move_to = tl_ok && tr_ok && bl_ok && br_ok;
        end
    end
    endfunction

    assign player_center_tx = pixel_to_tile_x(player_x + `PLAYER_WIDTH/2);
    assign player_center_ty = pixel_to_tile_y(player_y + `PLAYER_HEIGHT/2);

    always @(posedge clk) begin
        if (player_hit)
            player_dead <= 1;

        if (!player_dead && move_tick) begin
            if (btnL && can_move_to(player_x - 1, player_y))
                player_x <= player_x - 1;
            else if (btnR && can_move_to(player_x + 1, player_y))
                player_x <= player_x + 1;
            else if (btnU && can_move_to(player_x, player_y - 1))
                player_y <= player_y - 1;
            else if (btnD && can_move_to(player_x, player_y + 1))
                player_y <= player_y + 1;
        end
    end

endmodule