`timescale 1ns / 1ps

`include "constants.vh"

module bomb_controller (
    input clk,
    input [3:0] player_tx, player_ty,
    input trigger,
    input player_dead,

    output [`MAX_BOMBS-1:0] place_bomb_req, bomb_active, bomb_red, explosion_active,
    output [`MAX_BOMBS*4-1:0] bomb_tx_flat, bomb_ty_flat,
    output [`MAX_BOMBS*2-1:0] explosion_stage_flat,

    input [1:0] bomb_count, // number of bombs that can be placed
    input [1:0] bomb_radius
);

//    parameter integer BOMB_COUNTDOWN_TIME = 2 * `CLOCK_SPEED;
//    parameter integer BOMB_BLINK_TIME = `CLOCK_SPEED / 2;
//    parameter integer EXPLOSION_TIME = 1 * `CLOCK_SPEED;
//    parameter integer EXPLOSION_STAGE_TIME = EXPLOSION_TIME / 3;
    // replace old time parameters
    parameter integer TICK_DIV               = `CLOCK_SPEED / 100;
    parameter integer BOMB_COUNTDOWN_TICKS   = 200;
    parameter integer BOMB_BLINK_TICKS       = 50;
    parameter integer EXPLOSION_STAGE_TICKS  = 33;
    
    // shared tick counter
    reg [$clog2(TICK_DIV)-1:0] tick_ctr = 0;
//    wire game_tick = (tick_ctr == TICK_DIV -1);
//    always @(posedge clk) begin
//        if (tick_ctr == TICK_DIV - 1) tick_ctr  <= 0;
//        else tick_ctr  <= tick_ctr + 1;
//    end
    reg game_tick = 0;
    always @(posedge clk) begin
        if (game_tick) begin
            tick_ctr  <= TICK_DIV - 2; // reload to count down
            game_tick <= 0;
        end else if (tick_ctr == 0) begin
            game_tick <= 1;
            tick_ctr  <= TICK_DIV - 2;
        end else begin
            tick_ctr <= tick_ctr - 1;
        end
    end
    
//    reg [$clog2(BOMB_COUNTDOWN_TIME):0] countdown_r [0:`MAX_BOMBS-1];
//    reg [$clog2(EXPLOSION_STAGE_TIME):0] explode_tick_r [0:`MAX_BOMBS-1];
    reg [$clog2(BOMB_COUNTDOWN_TICKS):0] countdown_counter [0:`MAX_BOMBS-1];
    reg [$clog2(EXPLOSION_STAGE_TICKS):0] explode_counter [0:`MAX_BOMBS-1];

    parameter [1:0] ST_IDLE      = 2'd0;
    parameter [1:0] ST_COUNTDOWN = 2'd1;
    parameter [1:0] ST_EXPLODE   = 2'd2;

    reg [1:0] state [0:`MAX_BOMBS-1];
    reg [1:0] next_state [0:`MAX_BOMBS-1];
    reg [3:0] bomb_tx_r [0:`MAX_BOMBS-1];
    reg [3:0] bomb_ty_r [0:`MAX_BOMBS-1];
    reg [1:0] stage_r   [0:`MAX_BOMBS-1];
    reg [`MAX_BOMBS-1:0] place_bomb_req_r;
    reg [`MAX_BOMBS-1:0] bomb_red_r;

    integer i;
//    integer alloc_idx;
    reg [1:0] active_count_r;
    reg found;
    reg [1:0] alloc_idx;
    
    reg [1:0] bomb_count_r, bomb_radius_r;
    always @(posedge clk) begin
        bomb_count_r  <= bomb_count;
        bomb_radius_r <= bomb_radius;
    end
    
    always @(*) begin
        found          = 0;
        alloc_idx      = 0;
        active_count_r = 0;
        for (i = 0; i < `MAX_BOMBS; i = i + 1) begin
            if (!found && state[i] == ST_IDLE) begin
                alloc_idx = i[1:0];
                found     = 1;
            end
            if (state[i] == ST_COUNTDOWN)
                active_count_r = active_count_r + 1'b1;
        end
    end
    
    always @(posedge clk) begin
        place_bomb_req_r <= 0;
    
        for (i = 0; i < `MAX_BOMBS; i = i + 1) begin
            case (state[i])
                ST_IDLE: begin
                    if (trigger && found && alloc_idx == i[1:0] && active_count_r < bomb_count_r) begin
                        state[i]             <= ST_COUNTDOWN;
                        stage_r[i]           <= 0;
                        countdown_counter[i] <= 0;
                        explode_counter[i]   <= 0;
                        place_bomb_req_r[i]  <= 1;
                        bomb_tx_r[i]         <= player_tx;
                        bomb_ty_r[i]         <= player_ty;
                    end
                end
    
                ST_COUNTDOWN: begin
                    if (countdown_counter[i] >= BOMB_COUNTDOWN_TICKS-1) begin
                        state[i]             <= ST_EXPLODE;
                        explode_counter[i]   <= 0;
                        stage_r[i]           <= 2'd1;
                        countdown_counter[i] <= 0;
                    end else if (game_tick) begin
                        countdown_counter[i] <= countdown_counter[i] + 1;
                        bomb_red_r[i]        <= countdown_counter[i][$clog2(BOMB_BLINK_TICKS)];
                    end
                end
    
                ST_EXPLODE: begin
                    if (explode_counter[i] >= EXPLOSION_STAGE_TICKS-1 && stage_r[i] >= bomb_radius_r) begin
                        state[i]   <= ST_IDLE;
                        stage_r[i] <= 0;
                    end else if (game_tick) begin
                        if (explode_counter[i] >= EXPLOSION_STAGE_TICKS - 1) begin
                            explode_counter[i] <= 0;
                            stage_r[i]         <= stage_r[i] + 1;
                        end else begin
                            explode_counter[i] <= explode_counter[i] + 1;
                        end
                    end
                end
    
                default: state[i] <= ST_IDLE;
            endcase
        end
    end
    
    /*always @(*) begin
        found = 0;
        alloc_idx = 0;
        active_count_r = 0;
        for (i = 0; i < `MAX_BOMBS; i = i + 1) begin
            if (!found && state[i] == ST_IDLE) begin
                alloc_idx = i[1:0];
                found = 1;
            end
            if (state[i] == ST_COUNTDOWN) active_count_r = active_count_r + 1'b1;
        end
        
        // next state logic
        for (i = 0; i < `MAX_BOMBS; i = i + 1) begin
            next_state[i] = state[i];
            case (state[i])
                ST_IDLE:
                    if (trigger && found && alloc_idx == i[1:0] && active_count_r < bomb_count)
                        next_state[i] = ST_COUNTDOWN;
                ST_COUNTDOWN:
                    if (countdown_counter[i] >= BOMB_COUNTDOWN_TICKS-1)
//                    if (countdown_r[i] >= BOMB_COUNTDOWN_TIME - 1)
                        next_state[i] = ST_EXPLODE;
                ST_EXPLODE:
                    if (explode_counter[i] >= EXPLOSION_STAGE_TICKS-1 && stage_r[i] >= bomb_radius)
//                    if (explode_tick_r[i] >= EXPLOSION_STAGE_TIME - 1 && stage_r[i] >= bomb_radius)
                        next_state[i] = ST_IDLE;
            endcase
        end
    end
    
    // separate block - only fires on placement, no other logic
    always @(posedge clk) begin
        for (i = 0; i < `MAX_BOMBS; i = i + 1) begin
            if (state[i] == ST_IDLE && next_state[i] == ST_COUNTDOWN) begin
                bomb_tx_r[i] <= player_tx;
                bomb_ty_r[i] <= player_ty;
            end
        end
    end
    
    always @(posedge clk) begin
        place_bomb_req_r <= 0;
        
        for (i = 0; i < `MAX_BOMBS; i = i + 1) begin
            state[i] <= next_state[i];
    
            case (state[i])
                ST_IDLE: begin
                    if (next_state[i] == ST_COUNTDOWN) begin
                        stage_r[i]        <= 0;
//                        countdown_r[i]    <= 0;
                        countdown_counter[i]    <= 0;
//                        explode_tick_r[i] <= 0;
                        explode_counter[i] <= 0;
                        place_bomb_req_r[i] <= 1;
                    end
                end
    
                ST_COUNTDOWN: begin
                    if (next_state[i] == ST_EXPLODE) begin
//                        explode_tick_r[i] <= 0;
                        explode_counter[i] <= 0;
                        stage_r[i]        <= 2'd1;
                        countdown_counter[i]    <= 0;
                    end
                    else if (game_tick) begin
                        countdown_counter[i] <= countdown_counter[i] + 1;
//                        countdown_r[i] <= countdown_r[i] + 1;
                        bomb_red_r[i] <= countdown_counter[i][$clog2(BOMB_BLINK_TICKS)];
//                        bomb_red_r <= countdown_r[i][$clog2(BOMB_BLINK_TIME)];
                    end
                end
    
                ST_EXPLODE: begin
                    if (next_state[i] == ST_IDLE) stage_r[i] <= 0;
                    else if (game_tick) begin
                        if (explode_counter[i] >= EXPLOSION_STAGE_TICKS - 1) begin
                            explode_counter[i] <= 0;
                            stage_r[i]        <= stage_r[i] + 1;
                        end else begin
                            explode_counter[i] <= explode_counter[i] + 1;
                        end
//                        // staying in explode
//                        if (explode_tick_r[i] >= EXPLOSION_STAGE_TIME - 1) begin
//                            explode_tick_r[i] <= 0;
//                            stage_r[i]        <= stage_r[i] + 1;
//                        end else begin
//                            explode_tick_r[i] <= explode_tick_r[i] + 1;
//                        end
                    end
                end
            endcase
        end
    end*/

    genvar k;
    generate
        for (k = 0; k < `MAX_BOMBS; k = k + 1) begin
            assign bomb_active[k] = (state[k] == ST_COUNTDOWN);
            assign explosion_active[k] = (state[k] == ST_EXPLODE);
            assign bomb_tx_flat[k*4 +: 4] = bomb_tx_r[k];
            assign bomb_ty_flat[k*4 +: 4] = bomb_ty_r[k];
            assign explosion_stage_flat[k*2 +: 2] = stage_r[k];
            assign place_bomb_req[k] = place_bomb_req_r[k];
            assign bomb_red[k] = bomb_red_r[k];
        end
    endgenerate
endmodule
