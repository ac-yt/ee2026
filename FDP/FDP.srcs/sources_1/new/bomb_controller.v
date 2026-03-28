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

    parameter integer BOMB_COUNTDOWN_TIME = 2 * `CLOCK_SPEED;
    parameter integer BOMB_BLINK_TIME = `CLOCK_SPEED / 2;
    parameter integer EXPLOSION_TIME = 1 * `CLOCK_SPEED;
    parameter integer EXPLOSION_STAGE_TIME = EXPLOSION_TIME / 3;
    
    reg [$clog2(BOMB_COUNTDOWN_TIME)-1:0] countdown_counter [0:`MAX_BOMBS-1];
    reg [$clog2(EXPLOSION_STAGE_TIME)-1:0] explode_counter [0:`MAX_BOMBS-1];

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
                    if (countdown_counter[i] == BOMB_COUNTDOWN_TIME-1) begin
                        state[i]             <= ST_EXPLODE;
                        explode_counter[i]   <= 0;
                        stage_r[i]           <= 2'd1;
                        countdown_counter[i] <= 0;
                    end 
                    else begin
                        countdown_counter[i] <= countdown_counter[i] + 1;
                        bomb_red_r[i]        <= countdown_counter[i][$clog2(BOMB_BLINK_TIME)];
                    end
                end
    
                ST_EXPLODE: begin
                    if (explode_counter[i] == EXPLOSION_STAGE_TIME-1 && stage_r[i] >= bomb_radius_r) begin
                        state[i]   <= ST_IDLE;
                        stage_r[i] <= 0;
                    end
                    else begin
                        if (explode_counter[i] == EXPLOSION_STAGE_TIME - 1) begin
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

/*module bomb_controller (
    input clk,
    input [3:0] player_tx, player_ty,
    input trigger,
    input player_dead,

    output reg [`MAX_BOMBS-1:0] place_bomb_req, bomb_active, bomb_red, explosion_active,
    output reg [`MAX_BOMBS*4-1:0] bomb_tx_flat, bomb_ty_flat,
    output reg [`MAX_BOMBS*2-1:0] explosion_stage_flat,

    input [1:0] bomb_count, // number of bombs that can be placed
    input [1:0] bomb_radius
);

    parameter integer BOMB_COUNTDOWN_TIME = 2 * `CLOCK_SPEED;
    parameter integer BOMB_BLINK_TIME = `CLOCK_SPEED / 2;
    parameter integer EXPLOSION_TIME = 1 * `CLOCK_SPEED;
    parameter integer EXPLOSION_STAGE_TIME = EXPLOSION_TIME / 3;
    
    reg [$clog2(BOMB_COUNTDOWN_TIME)-1:0] countdown_counter [0:`MAX_BOMBS-1];
    reg [$clog2(EXPLOSION_STAGE_TIME)-1:0] explode_counter [0:`MAX_BOMBS-1];

    parameter [1:0] ST_IDLE      = 2'd0;
    parameter [1:0] ST_COUNTDOWN = 2'd1;
    parameter [1:0] ST_EXPLODE   = 2'd2;

    reg [1:0] state [0:`MAX_BOMBS-1];
    reg [1:0] next_state [0:`MAX_BOMBS-1];

    integer i;
    reg [1:0] active_count_r;
    reg found;
    reg [1:0] alloc_idx;
    
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
        place_bomb_req <= 0;
    
        for (i = 0; i < `MAX_BOMBS; i = i + 1) begin
            bomb_active[i] <= (state[i] == ST_COUNTDOWN);
            explosion_active[i] <= (state[i] == ST_EXPLODE);
            case (state[i])
                ST_IDLE: begin
                    if (trigger && found && alloc_idx == i[1:0] && active_count_r < bomb_count) begin
                        state[i] <= ST_COUNTDOWN;
                        explosion_stage_flat[i*2 +: 2] <= 0;
                        countdown_counter[i] <= 0;
                        explode_counter[i] <= 0;
                        place_bomb_req[i]<= 1;
                        bomb_tx_flat[i*4 +: 4] <= player_tx;
                        bomb_ty_flat[i*4 +: 4] <= player_ty;
                    end
                end
    
                ST_COUNTDOWN: begin
                    if (countdown_counter[i] == BOMB_COUNTDOWN_TIME-1) begin
                        state[i] <= ST_EXPLODE;
                        explode_counter[i] <= 0;
                        explosion_stage_flat[i*2 +: 2] <= 2'd1;
                        countdown_counter[i] <= 0;
                    end 
                    else begin
                        countdown_counter[i] <= countdown_counter[i] + 1;
                        bomb_red[i] <= countdown_counter[i][$clog2(BOMB_BLINK_TIME)];
                    end
                end
    
                ST_EXPLODE: begin
                    if (explode_counter[i] == EXPLOSION_STAGE_TIME-1 && explosion_stage_flat[i*2 +: 2] >= bomb_radius) begin
                        state[i] <= ST_IDLE;
                        explosion_stage_flat[i*2 +: 2] <= 0;
                    end
                    else begin
                        if (explode_counter[i] == EXPLOSION_STAGE_TIME - 1) begin
                            explode_counter[i] <= 0;
                            explosion_stage_flat[i*2 +: 2] <= explosion_stage_flat[i*2 +: 2] + 1;
                        end else begin
                            explode_counter[i] <= explode_counter[i] + 1;
                        end
                    end
                end
    
                default: state[i] <= ST_IDLE;
            endcase
        end
    end
endmodule*/
