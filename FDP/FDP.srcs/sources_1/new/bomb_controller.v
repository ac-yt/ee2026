`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.03.2026 17:15:13
// Design Name: 
// Module Name: bomb_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

`include "constants.vh"

module bomb_controller (
    input clk,
    input btnC,
    input [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat,
    input [6:0] player_x,
    input [5:0] player_y,
    input [3:0] player_center_tx,
    input [3:0] player_center_ty,
    input player_dead,

    output reg bomb_active = 0,
    output reg bomb_passable = 0,
    output reg [3:0] bomb_tx = 0,
    output reg [3:0] bomb_ty = 0,
    output reg bomb_red = 0,

    output reg explosion_active = 0,
    output reg [3:0] explosion_stage = 1,
    output reg [3:0] explode_up_len = 0,
    output reg [3:0] explode_down_len = 0,
    output reg [3:0] explode_left_len = 0,
    output reg [3:0] explode_right_len = 0,

    output reg player_hit = 0,

    output reg place_bomb_req = 0,
    output reg [3:0] place_bomb_tx = 0,
    output reg [3:0] place_bomb_ty = 0,

    output reg clear_bomb_req = 0,
    output reg [3:0] clear_bomb_tx = 0,
    output reg [3:0] clear_bomb_ty = 0,

    output reg destroy_up_req = 0,
    output reg [3:0] destroy_up_tx = 0,
    output reg [3:0] destroy_up_ty = 0,

    output reg destroy_down_req = 0,
    output reg [3:0] destroy_down_tx = 0,
    output reg [3:0] destroy_down_ty = 0,

    output reg destroy_left_req = 0,
    output reg [3:0] destroy_left_tx = 0,
    output reg [3:0] destroy_left_ty = 0,

    output reg destroy_right_req = 0,
    output reg [3:0] destroy_right_tx = 0,
    output reg [3:0] destroy_right_ty = 0
);

    parameter integer BOMB_COUNTDOWN_TIME  = 2 * `CLOCK_SPEED;
    parameter integer BOMB_BLINK_TIME      = `CLOCK_SPEED / 2;
    parameter integer EXPLOSION_TIME       = 1 * `CLOCK_SPEED;
    parameter integer EXPLOSION_RADIUS     = 1;
    parameter integer EXPLOSION_STAGE_TIME = EXPLOSION_TIME / EXPLOSION_RADIUS;

    reg [$clog2(BOMB_COUNTDOWN_TIME):0] bomb_counter = 0;
    reg [$clog2(BOMB_BLINK_TIME):0] blink_counter = 0;
    reg [$clog2(EXPLOSION_STAGE_TIME):0] explosion_stage_counter = 0;

    reg btnC_d = 0;
    wire btnC_pressed = btnC & ~btnC_d;

    always @(posedge clk) begin
        btnC_d <= btnC;
    end

    function [2:0] get_tile;
        input [3:0] tx;
        input [3:0] ty;
    begin
        get_tile = tile_map_flat[(ty*`TILE_MAP_WIDTH + tx)*3 +: 3];
    end
    endfunction

    function player_overlaps_tile;
        input [3:0] tx_in;
        input [3:0] ty_in;
        reg [6:0] tile_left;
        reg [6:0] tile_right;
        reg [5:0] tile_top;
        reg [5:0] tile_bottom;
        reg [6:0] player_right;
        reg [5:0] player_bottom;
    begin
        tile_left     = `MIN_PIX_X + tx_in * `TILE_SIZE;
        tile_right    = tile_left + `TILE_SIZE - 1;
        tile_top      = `MIN_PIX_Y + ty_in * `TILE_SIZE;
        tile_bottom   = tile_top + `TILE_SIZE - 1;
        player_right  = player_x + `PLAYER_WIDTH - 1;
        player_bottom = player_y + `PLAYER_HEIGHT - 1;

        player_overlaps_tile =
            !(player_right  < tile_left  ||
              player_x      > tile_right ||
              player_bottom < tile_top   ||
              player_y      > tile_bottom);
    end
    endfunction

    function [3:0] compute_reach_up;
        input [3:0] cx;
        input [3:0] cy;
        integer i;
        reg stop;
        reg [2:0] t;
    begin
        compute_reach_up = 0;
        stop = 0;
        for (i = 1; i <= EXPLOSION_RADIUS; i = i + 1) begin
            if (!stop) begin
                if (cy < i)
                    stop = 1;
                else begin
                    t = get_tile(cx, cy - i);
                    if (t == `MAP_WALL)
                        stop = 1;
                    else begin
                        compute_reach_up = i[3:0];
                        if (t == `MAP_BLOCK)
                            stop = 1;
                    end
                end
            end
        end
    end
    endfunction

    function [3:0] compute_reach_down;
        input [3:0] cx;
        input [3:0] cy;
        integer i;
        reg stop;
        reg [2:0] t;
    begin
        compute_reach_down = 0;
        stop = 0;
        for (i = 1; i <= EXPLOSION_RADIUS; i = i + 1) begin
            if (!stop) begin
                if ((cy + i) >= `TILE_MAP_HEIGHT)
                    stop = 1;
                else begin
                    t = get_tile(cx, cy + i);
                    if (t == `MAP_WALL)
                        stop = 1;
                    else begin
                        compute_reach_down = i[3:0];
                        if (t == `MAP_BLOCK)
                            stop = 1;
                    end
                end
            end
        end
    end
    endfunction

    function [3:0] compute_reach_left;
        input [3:0] cx;
        input [3:0] cy;
        integer i;
        reg stop;
        reg [2:0] t;
    begin
        compute_reach_left = 0;
        stop = 0;
        for (i = 1; i <= EXPLOSION_RADIUS; i = i + 1) begin
            if (!stop) begin
                if (cx < i)
                    stop = 1;
                else begin
                    t = get_tile(cx - i, cy);
                    if (t == `MAP_WALL)
                        stop = 1;
                    else begin
                        compute_reach_left = i[3:0];
                        if (t == `MAP_BLOCK)
                            stop = 1;
                    end
                end
            end
        end
    end
    endfunction

    function [3:0] compute_reach_right;
        input [3:0] cx;
        input [3:0] cy;
        integer i;
        reg stop;
        reg [2:0] t;
    begin
        compute_reach_right = 0;
        stop = 0;
        for (i = 1; i <= EXPLOSION_RADIUS; i = i + 1) begin
            if (!stop) begin
                if ((cx + i) >= `TILE_MAP_WIDTH)
                    stop = 1;
                else begin
                    t = get_tile(cx + i, cy);
                    if (t == `MAP_WALL)
                        stop = 1;
                    else begin
                        compute_reach_right = i[3:0];
                        if (t == `MAP_BLOCK)
                            stop = 1;
                    end
                end
            end
        end
    end
    endfunction

    always @(posedge clk) begin
        // default pulse outputs
        place_bomb_req   <= 0;
        clear_bomb_req   <= 0;
        destroy_up_req   <= 0;
        destroy_down_req <= 0;
        destroy_left_req <= 0;
        destroy_right_req<= 0;
        player_hit       <= 0;

        // allow player to step off own bomb once
        if (bomb_active && bomb_passable) begin
            if (!player_overlaps_tile(bomb_tx, bomb_ty))
                bomb_passable <= 0;
        end

        // place bomb
        if (!bomb_active && !explosion_active && !player_dead && btnC_pressed) begin
            if (get_tile(player_center_tx, player_center_ty) == `MAP_EMPTY ||
                get_tile(player_center_tx, player_center_ty) == `MAP_POWERUP) begin
                bomb_active    <= 1;
                bomb_passable  <= 1;
                bomb_tx        <= player_center_tx;
                bomb_ty        <= player_center_ty;
                bomb_counter   <= 0;
                blink_counter  <= 0;
                bomb_red       <= 0;

                place_bomb_req <= 1;
                place_bomb_tx  <= player_center_tx;
                place_bomb_ty  <= player_center_ty;
            end
        end

        // countdown
        if (bomb_active) begin
            if (bomb_counter == BOMB_COUNTDOWN_TIME - 1) begin
                bomb_active   <= 0;
                bomb_passable <= 0;
                bomb_counter  <= 0;
                blink_counter <= 0;
                bomb_red      <= 0;

                clear_bomb_req <= 1;
                clear_bomb_tx  <= bomb_tx;
                clear_bomb_ty  <= bomb_ty;

                explode_up_len    <= compute_reach_up(bomb_tx, bomb_ty);
                explode_down_len  <= compute_reach_down(bomb_tx, bomb_ty);
                explode_left_len  <= compute_reach_left(bomb_tx, bomb_ty);
                explode_right_len <= compute_reach_right(bomb_tx, bomb_ty);

                explosion_active        <= 1;
                explosion_stage         <= 1;
                explosion_stage_counter <= 0;
            end
            else begin
                bomb_counter <= bomb_counter + 1;

                if (blink_counter == BOMB_BLINK_TIME - 1) begin
                    blink_counter <= 0;
                    bomb_red <= ~bomb_red;
                end
                else begin
                    blink_counter <= blink_counter + 1;
                end
            end
        end

        // explosion
        if (explosion_active) begin
            // center tile
            if (!player_dead && player_overlaps_tile(bomb_tx, bomb_ty))
                player_hit <= 1;

            // up
            if (explosion_stage <= explode_up_len) begin
                if (get_tile(bomb_tx, bomb_ty - explosion_stage) == `MAP_BLOCK) begin
                    destroy_up_req <= 1;
                    destroy_up_tx  <= bomb_tx;
                    destroy_up_ty  <= bomb_ty - explosion_stage;
                end
                if (!player_dead && player_overlaps_tile(bomb_tx, bomb_ty - explosion_stage))
                    player_hit <= 1;
            end

            // down
            if (explosion_stage <= explode_down_len) begin
                if (get_tile(bomb_tx, bomb_ty + explosion_stage) == `MAP_BLOCK) begin
                    destroy_down_req <= 1;
                    destroy_down_tx  <= bomb_tx;
                    destroy_down_ty  <= bomb_ty + explosion_stage;
                end
                if (!player_dead && player_overlaps_tile(bomb_tx, bomb_ty + explosion_stage))
                    player_hit <= 1;
            end

            // left
            if (explosion_stage <= explode_left_len) begin
                if (get_tile(bomb_tx - explosion_stage, bomb_ty) == `MAP_BLOCK) begin
                    destroy_left_req <= 1;
                    destroy_left_tx  <= bomb_tx - explosion_stage;
                    destroy_left_ty  <= bomb_ty;
                end
                if (!player_dead && player_overlaps_tile(bomb_tx - explosion_stage, bomb_ty))
                    player_hit <= 1;
            end

            // right
            if (explosion_stage <= explode_right_len) begin
                if (get_tile(bomb_tx + explosion_stage, bomb_ty) == `MAP_BLOCK) begin
                    destroy_right_req <= 1;
                    destroy_right_tx  <= bomb_tx + explosion_stage;
                    destroy_right_ty  <= bomb_ty;
                end
                if (!player_dead && player_overlaps_tile(bomb_tx + explosion_stage, bomb_ty))
                    player_hit <= 1;
            end

            if (explosion_stage_counter == EXPLOSION_STAGE_TIME - 1) begin
                explosion_stage_counter <= 0;

                if (explosion_stage == EXPLOSION_RADIUS) begin
                    explosion_active <= 0;
                end
                else begin
                    explosion_stage <= explosion_stage + 1;
                end
            end
            else begin
                explosion_stage_counter <= explosion_stage_counter + 1;
            end
        end
    end

endmodule