`timescale 1ns / 1ps
`include "constants.vh"
module stun_controller (
    input  clk, rst_game, game_ready,
    input  trigger,            // single-cycle pulse: right-click when bombs full
    input  [1:0]  facing,      // 0=R 1=L 2=D 3=U
    input  [6:0]  player_x,    // top-left pixel of attacker
    input  [5:0]  player_y,
    // stun range rectangle (pixel coords, valid when stun_active)
    output reg        stun_active,
    output [6:0]      stun_x0, stun_x1,
    output [5:0]      stun_y0, stun_y1,
    // whether the victim is currently stunned
    input  [6:0]  victim_x,
    input  [5:0]  victim_y,
    output reg        victim_stunned
);
    // Timing constants
    localparam HALF_TILE     = 3;                   // half a tile = 3 px
    localparam PW            = `PLAYER_WIDTH;        // 4
    localparam STUN_DURATION = `CLOCK_SPEED / 2;    // 0.5 s
    localparam COOLDOWN_TIME = `CLOCK_SPEED * 2;    // 2 s total (including active window)

    // FSM states
    localparam ST_READY    = 2'd0;
    localparam ST_ACTIVE   = 2'd1;
    localparam ST_COOLDOWN = 2'd2;
    reg [1:0] state = ST_READY;

    reg [26:0] counter = 0;

    // ----------------------------------------------------------------
    // Stun rect: purely combinatorial from player position + facing.
    // Always computed; only meaningful while stun_active is high.
    // ----------------------------------------------------------------
    reg [6:0] stun_x0_r, stun_x1_r;
    reg [5:0] stun_y0_r, stun_y1_r;
    assign stun_x0 = stun_x0_r;
    assign stun_x1 = stun_x1_r;
    assign stun_y0 = stun_y0_r;
    assign stun_y1 = stun_y1_r;

    always @(*) begin
        case (facing)
            2'd0: begin // facing right -> rect to the right of player
                stun_x0_r = player_x + PW;
                stun_x1_r = player_x + PW + HALF_TILE - 1;
                stun_y0_r = player_y;
                stun_y1_r = player_y + PW - 1;
            end
            2'd1: begin // facing left -> rect to the left of player
                stun_x0_r = player_x - HALF_TILE;
                stun_x1_r = player_x - 1;
                stun_y0_r = player_y;
                stun_y1_r = player_y + PW - 1;
            end
            2'd2: begin // facing down -> rect below player
                stun_x0_r = player_x;
                stun_x1_r = player_x + PW - 1;
                stun_y0_r = player_y + PW;
                stun_y1_r = player_y + PW + HALF_TILE - 1;
            end
            default: begin // facing up -> rect above player
                stun_x0_r = player_x;
                stun_x1_r = player_x + PW - 1;
                stun_y0_r = player_y - HALF_TILE;
                stun_y1_r = player_y - 1;
            end
        endcase
    end

    // ----------------------------------------------------------------
    // Combinatorial hit check: victim pixel bbox overlaps stun rect
    // ----------------------------------------------------------------
    wire hit = stun_active &&
               (victim_x + PW - 1 >= stun_x0_r) && (victim_x <= stun_x1_r) &&
               (victim_y + PW - 1 >= stun_y0_r) && (victim_y <= stun_y1_r);

    // ----------------------------------------------------------------
    // FSM
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_game) begin
            state          <= ST_READY;
            counter        <= 0;
            stun_active    <= 0;
            victim_stunned <= 0;
        end else if (game_ready) begin
            case (state)
                ST_READY: begin
                    stun_active <= 0;
                    if (trigger) begin
                        state       <= ST_ACTIVE;
                        counter     <= 0;
                        stun_active <= 1;
                    end
                end

                ST_ACTIVE: begin
                    stun_active <= 1;
                    if (hit) victim_stunned <= 1;   // latch stun on any overlap

                    if (counter == STUN_DURATION - 1) begin
                        state       <= ST_COOLDOWN;
                        counter     <= 0;
                        stun_active <= 0;
                    end else
                        counter <= counter + 1;
                end

                ST_COOLDOWN: begin
                    stun_active    <= 0;
                    victim_stunned <= 0;            // stun wears off once active window ends
                    if (counter == COOLDOWN_TIME - 1) begin
                        state   <= ST_READY;
                        counter <= 0;
                    end else
                        counter <= counter + 1;
                end

                default: state <= ST_READY;
            endcase
        end
    end
endmodule