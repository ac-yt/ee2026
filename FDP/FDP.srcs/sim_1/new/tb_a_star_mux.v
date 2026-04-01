`timescale 1ns / 1ps
`include "constants.vh"

module a_star_mux_movement_tb;

    reg clk = 0;
    localparam HALF = 10;
    always #HALF clk = ~clk;

    reg [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat;
    integer init_tx, init_ty;
    initial begin
        tile_map_flat = 0;
        for (init_tx = 0; init_tx < `TILE_MAP_WIDTH; init_tx = init_tx + 1) begin
            for (init_ty = 0; init_ty < `TILE_MAP_HEIGHT; init_ty = init_ty + 1)
                if ((init_tx % 2 == 1) && (init_ty % 2 == 1))
                    tile_map_flat[(init_ty * `TILE_MAP_WIDTH + 3) * 3 +: 3] = `MAP_WALL;
        end
    end

    reg map_changed = 0;

    // Player (c0)
    wire        p1_update, p1_baw, p1_valid;
    wire [3:0]  p1_tx, p1_ty;
    wire [6:0]  p1_x;
    wire [5:0]  p1_y;
    wire        p1_nib;
    wire [4*`MAX_PATH_LEN-1:0] p1_pfx, p1_pfy;
    wire [6:0]  p1_len;
    wire [15:0] p1_led;
    reg  [3:0]  mouse_tx = 0, mouse_ty = 0;

    reg [3:0] p1_start_tx = 0, p1_start_ty = 0;
    reg mouse_left_pulse = 0;
    always @(posedge clk)
        if (mouse_left_pulse || map_changed) begin
            p1_start_tx <= p1_tx;
            p1_start_ty <= p1_ty;
        end

    // Computer (c1)
    wire        comp_update, comp_baw, comp_valid;
    wire [3:0]  comp_tx, comp_ty;
    wire [6:0]  comp_x;
    wire [5:0]  comp_y;
    wire        comp_nib;
    wire [4*`MAX_PATH_LEN-1:0] comp_pfx, comp_pfy;
    wire [6:0]  comp_len;
    wire [15:0] comp_led;

    reg [3:0] comp_start_tx = 4'd14, comp_start_ty = 4'd8;
    always @(posedge clk)
        if (map_changed) begin
            comp_start_tx <= comp_tx;
            comp_start_ty <= comp_ty;
        end

    movement_controller uut_p1 (
        .clk(clk), .led(p1_led), .map_changed(map_changed),
        .spawn_tx(4'd0), .spawn_ty(4'd0),
        .goal_tx(mouse_tx), .goal_ty(mouse_ty),
        .tile_map_flat(tile_map_flat), .speed(`PLAYER_MAX_SPEED), .is_player(1'b1),
        .next_is_block(p1_nib), .pos_tx_out(p1_tx), .pos_ty_out(p1_ty),
        .pos_x(p1_x), .pos_y(p1_y),
        .as_update(p1_update), .as_baw(p1_baw),
        .path_flat_x(p1_pfx), .path_flat_y(p1_pfy),
        .path_valid(p1_valid), .path_len(p1_len)
    );
    defparam uut_p1.MAX_MOVE_COUNT = 500 / `BOT_DEFAULT_SPEED;

    movement_controller uut_comp (
        .clk(clk), .led(comp_led), .map_changed(map_changed),
        .spawn_tx(4'd14), .spawn_ty(4'd8),
        .goal_tx(p1_tx), .goal_ty(p1_ty),
        .tile_map_flat(tile_map_flat), .speed(6'd30), .is_player(1'b0),
        .next_is_block(comp_nib), .pos_tx_out(comp_tx), .pos_ty_out(comp_ty),
        .pos_x(comp_x), .pos_y(comp_y),
        .as_update(comp_update), .as_baw(comp_baw),
        .path_flat_x(comp_pfx), .path_flat_y(comp_pfy),
        .path_valid(comp_valid), .path_len(comp_len)
    );
    defparam uut_comp.MAX_MOVE_COUNT = 500 / `BOT_DEFAULT_SPEED;

    a_star_mux uut_mux (
        .clk(clk),
        .tile_map_flat(tile_map_flat),
        .c0_update(p1_update), .c0_baw(p1_baw),
        .c0_stx(p1_start_tx), .c0_sty(p1_start_ty),
        .c0_gtx(mouse_tx),    .c0_gty(mouse_ty),
        .c0_pfx(p1_pfx),      .c0_pfy(p1_pfy),
        .c0_valid(p1_valid),  .c0_len(p1_len),
        .c1_update(comp_update), .c1_baw(comp_baw),
        .c1_stx(comp_start_tx),  .c1_sty(comp_start_ty),
        .c1_gtx(p1_tx),          .c1_gty(p1_ty),
        .c1_pfx(comp_pfx),       .c1_pfy(comp_pfy),
        .c1_valid(comp_valid),   .c1_len(comp_len)
    );
    
    

    // Helpers
    integer pass_count = 0, fail_count = 0;
    task tick; input integer n; integer j;
        begin for (j = 0; j < n; j = j + 1) @(posedge clk); end
    endtask
    task assert_eq;
        input [31:0] got, exp; input [255:0] label;
        begin
            if (got === exp) begin $display("[PASS] %0s  got=%0d", label, got); pass_count=pass_count+1; end
            else begin $display("[FAIL] %0s  expected=%0d  got=%0d", label, exp, got); fail_count=fail_count+1; end
        end
    endtask

    reg p1_valid_seen = 0, comp_valid_seen = 0;
    always @(posedge clk) begin
        if (p1_valid)   p1_valid_seen   <= 1;
        if (comp_valid) comp_valid_seen <= 1;
    end

    task wait_p1_valid;
        input integer timeout; input [255:0] label; integer k;
        begin
            p1_valid_seen = 0;
            for (k = 0; k < timeout; k = k + 1) begin
                @(posedge clk);
                if (p1_valid_seen) begin
                    $display("[PASS] %0s after %0d cycles", label, k+1);
                    pass_count=pass_count+1; p1_valid_seen=0; disable wait_p1_valid;
                end
            end
            $display("[FAIL] %0s timed out (%0d cycles)", label, timeout);
            fail_count=fail_count+1;
        end
    endtask

    task wait_comp_valid;
        input integer timeout; input [255:0] label; integer k;
        begin
            comp_valid_seen = 0;
            for (k = 0; k < timeout; k = k + 1) begin
                @(posedge clk);
                if (comp_valid_seen) begin
                    $display("[PASS] %0s after %0d cycles", label, k+1);
                    pass_count=pass_count+1; comp_valid_seen=0; disable wait_comp_valid;
                end
            end
            $display("[FAIL] %0s timed out (%0d cycles)", label, timeout);
            fail_count=fail_count+1;
        end
    endtask

    task wait_reach_tile_p1;
        input [3:0] gtx, gty; input integer timeout; integer k;
        begin
            for (k = 0; k < timeout; k = k + 1) begin
                @(posedge clk);
                if (p1_tx == gtx && p1_ty == gty) begin
                    $display("[MOVE] P1 reached (%0d,%0d) after %0d cycles", gtx, gty, k+1);
                    disable wait_reach_tile_p1;
                end
            end
            $display("[MOVE] P1 TIMEOUT at (%0d,%0d), goal was (%0d,%0d)", p1_tx, p1_ty, gtx, gty);
        end
    endtask

    // -----------------------------------------------------------
    // Hierarchical probes into mux and A* internals
    // -----------------------------------------------------------
    wire [1:0]  mux_state      = uut_mux.state;
    wire        mux_c0_pending = uut_mux.c0_pending;
    wire        mux_c1_pending = uut_mux.c1_pending;
    wire        mux_as_update  = uut_mux.as_update;
    wire        mux_as_valid   = uut_mux.as_valid;
    wire [4:0]  astar_state    = uut_mux.a_star_inst.state;
    wire [4:0]  astar_next     = uut_mux.a_star_inst.next_state;
    wire        astar_path_valid = uut_mux.a_star_inst.path_valid;

    // track state changes
    reg [1:0]  mux_state_prev = 0;
    reg [4:0]  astar_state_prev = 0;
    reg        mux_as_update_prev = 0;
    reg [6:0]  p1_path_step_prev = 0;
    reg [6:0]  comp_path_step_prev = 0;
    always @(posedge clk) begin
        mux_state_prev      <= mux_state;
        astar_state_prev    <= astar_state;
        mux_as_update_prev  <= mux_as_update;
        p1_path_step_prev   <= uut_p1.path_step;
        comp_path_step_prev <= uut_comp.path_step;
    end

    // -----------------------------------------------------------
    // Monitor
    // -----------------------------------------------------------
    always @(posedge clk) begin
        // mux state transitions
        if (mux_state != mux_state_prev)
            $display("[MUX] @%0t  state %0d->%0d  c0p=%0b c1p=%0b",
                     $time, mux_state_prev, mux_state, mux_c0_pending, mux_c1_pending);

        // A* state transitions (only log key ones to avoid spam)
        if (astar_state != astar_state_prev) begin
            if (astar_state == 5'b10100)  // RESET_2D
                $display("[A*]  @%0t  -> RESET_2D", $time);
            if (astar_state == 5'b10110)  // SET_START
                $display("[A*]  @%0t  -> SET_START  start=(%0d,%0d) goal=(%0d,%0d)",
                         $time,
                         uut_mux.a_star_inst.start_x, uut_mux.a_star_inst.start_y,
                         uut_mux.a_star_inst.goal_x,  uut_mux.a_star_inst.goal_y);
            if (astar_state == 5'b00000)  // CHECK_OPEN
                $display("[A*]  @%0t  -> CHECK_OPEN  open_counter=%0d",
                         $time, uut_mux.a_star_inst.open_counter);
            if (astar_state == 5'b01101)  // NB_CHECK_CLOSED_SCAN
                $display("[A*]  @%0t  -> NB_CHECK_CLOSED_SCAN  nb=(%0d,%0d)  scan=%0d  closed_ctr=%0d",
                         $time,
                         uut_mux.a_star_inst.nb_x, uut_mux.a_star_inst.nb_y,
                         uut_mux.a_star_inst.scan_index,
                         uut_mux.a_star_inst.closed_counter);
            if (astar_state == 5'b10011)  // DONE
                $display("[A*]  @%0t  -> DONE  path_valid=%0b  len=%0d",
                         $time, astar_path_valid, uut_mux.as_len);
        end

        // Every 1000 cycles, if stuck in NB_CHECK_CLOSED_SCAN, dump state
        if (astar_state == 5'b01101 && ($time % 1000000 == 0))
            $display("[A*]  @%0t  STUCK in NB_CHECK_CLOSED_SCAN  nb=(%0d,%0d)  scan=%0d/%0d  closed[scan]=(%0d,%0d)  next=%0d",
                     $time,
                     uut_mux.a_star_inst.nb_x, uut_mux.a_star_inst.nb_y,
                     uut_mux.a_star_inst.scan_index,
                     uut_mux.a_star_inst.closed_counter,
                     uut_mux.a_star_inst.closed_x[uut_mux.a_star_inst.scan_index],
                     uut_mux.a_star_inst.closed_y[uut_mux.a_star_inst.scan_index],
                     uut_mux.a_star_inst.next_state);

        // as_update pulse to A*
        if (mux_as_update && !mux_as_update_prev)
            $display("[MUX] @%0t  as_update pulse -> A* starting", $time);

        // as_valid from A*
        if (mux_as_valid)
            $display("[MUX] @%0t  as_valid=1  len=%0d -> client %0d",
                     $time, uut_mux.as_len, mux_state);

        // client update requests
        if (p1_update)
            $display("[MUX] @%0t  C0 update  baw=%0b  start=(%0d,%0d)  goal=(%0d,%0d)",
                     $time, p1_baw, p1_start_tx, p1_start_ty, mouse_tx, mouse_ty);
        if (comp_update)
            $display("[MUX] @%0t  C1 update  baw=%0b  start=(%0d,%0d)  goal=(%0d,%0d)",
                     $time, comp_baw, comp_start_tx, comp_start_ty, p1_tx, p1_ty);

        // valid outputs
//        if (p1_valid)
//            $display("[MUX] @%0t  C0 valid  len=%0d", $time, p1_len);
//        if (comp_valid)
//            $display("[MUX] @%0t  C1 valid  len=%0d", $time, comp_len);

        // path step changes
        if (uut_p1.path_step != 0 && uut_p1.path_step != p1_path_step_prev)
            $display("[P1]  @%0t  step->%0d  pos=(%0d,%0d)", $time, uut_p1.path_step, p1_tx, p1_ty);
        if (uut_comp.path_step != 0 && uut_comp.path_step != comp_path_step_prev)
            $display("[CMP] @%0t  step->%0d  pos=(%0d,%0d)", $time, uut_comp.path_step, comp_tx, comp_ty);

        if (uut_p1.goal_changed)
            $display("[P1]  @%0t  goal->(%0d,%0d)", $time, uut_p1.goal_tx, uut_p1.goal_ty);
        if (uut_comp.goal_changed)
            $display("[CMP] @%0t  goal->(%0d,%0d)", $time, uut_comp.goal_tx, uut_comp.goal_ty);
    end

    initial begin
        $dumpfile("tb_a_star_mux.vcd");
        $dumpvars(0, a_star_mux_movement_tb);
    end

    initial begin
        #(HALF * 2 * 2000000);
        $display("[WATCHDOG] timed out");
        $finish;
    end

    localparam TIMEOUT_VALID = 200000;
    localparam TIMEOUT_MOVE  = 50000;

    initial begin
        $display("====================================================");
        $display(" TWO movement_controller + a_star_mux");
        $display("====================================================");
        tick(5);

        $display("\n-- TEST 1: Spawn positions --");
        assert_eq(p1_tx,   0,  "P1 spawn tile x");
        assert_eq(p1_ty,   0,  "P1 spawn tile y");
        assert_eq(comp_tx, 14, "COMP spawn tile x");
        assert_eq(comp_ty, 8,  "COMP spawn tile y");

        $display("\n-- TEST 2: P1 click to (2,1) --");
        @(posedge clk); mouse_tx <= 4'd2; mouse_ty <= 4'd1;
        mouse_left_pulse <= 1;
        @(posedge clk); mouse_left_pulse <= 0;

        $display("[INFO] Waiting for P1 path...");
        wait_p1_valid(TIMEOUT_VALID, "TEST 2: P1 path");
        $display("[INFO] Waiting for COMP path...");
        wait_comp_valid(TIMEOUT_VALID, "TEST 2: COMP path");

        $display("[INFO] Watching P1 move to (2,1)...");
        wait_reach_tile_p1(4'd2, 4'd1, TIMEOUT_MOVE);
        assert_eq(p1_tx, 2, "TEST 2: P1 x=2");
        assert_eq(p1_ty, 1, "TEST 2: P1 y=1");

        $display("\n-- TEST 3: P1 click to (5,3) --");
        @(posedge clk); mouse_tx <= 4'd5; mouse_ty <= 4'd3;
        mouse_left_pulse <= 1;
        @(posedge clk); mouse_left_pulse <= 0;
        wait_p1_valid(TIMEOUT_VALID, "TEST 3: P1 path");
        wait_reach_tile_p1(4'd5, 4'd3, TIMEOUT_MOVE);
        assert_eq(p1_tx, 5, "TEST 3: P1 x=5");
        assert_eq(p1_ty, 3, "TEST 3: P1 y=3");

        tick(10);
        $display("\n====================================================");
        $display(" RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        $display("====================================================");
        if (fail_count == 0) $display(" ALL TESTS PASSED");
        else $display(" SOME TESTS FAILED");
        $display("====================================================\n");
        $finish;
    end

endmodule

/*`timescale 1ns / 1ps
`include "constants.vh"

// ============================================================
// a_star_mux_movement_tb.v
// ============================================================
// Uses defparam uut_mc.SIM_CLOCK = 500 so move_tick fires every
// 500/51 = ~9 cycles instead of 50M/51 = ~980k cycles.
// One tile = 6 pixels * 9 cycles = 54 cycles -- visible in sim.
//
// Compile:
//   xvlog constants.vh variable_clock.v a_star.v a_star_mux.v tb_a_star_mux.v
// ============================================================

module a_star_mux_movement_tb;

    // -----------------------------------------------------------
    // Clock -- 20 ns period
    // -----------------------------------------------------------
    reg clk = 0;
    localparam HALF = 10;
    always #HALF clk = ~clk;

    // -----------------------------------------------------------
    // Tile map: wall column at x=3, gap at y=3
    // -----------------------------------------------------------
    reg [(`TILE_MAP_SIZE*3)-1:0] tile_map_flat;
    integer init_ty;
    initial begin
        tile_map_flat = 0;
        for (init_ty = 0; init_ty < `TILE_MAP_HEIGHT; init_ty = init_ty + 1)
            if (init_ty != 3)
                tile_map_flat[(init_ty * `TILE_MAP_WIDTH + 3) * 3 +: 3] = `MAP_WALL;
    end

    reg map_changed = 0;

    // -----------------------------------------------------------
    // DUT wires
    // -----------------------------------------------------------
    wire        p1_update, p1_baw;
    wire [3:0]  p1_tx, p1_ty;
    wire [6:0]  p1_x;
    wire [5:0]  p1_y;
    wire        p1_next_is_block;
    wire [4*`MAX_PATH_LEN-1:0] p1_pfx, p1_pfy;
    wire [6:0]  p1_len;
    wire        p1_valid;
    reg  [3:0]  mouse_tx = 0, mouse_ty = 0;

    // -----------------------------------------------------------
    // DUT: movement_control
    // SIM_CLOCK=500 -> move_count_thresh=500/51=9 cycles/pixel
    // -----------------------------------------------------------
    movement_control uut_mc (
        .clk          (clk),
        .map_changed  (map_changed),
        .spawn_tx     (4'd0),
        .spawn_ty     (4'd0),
        .goal_tx      (mouse_tx),
        .goal_ty      (mouse_ty),
        .tile_map_flat(tile_map_flat),
        .speed        (`PLAYER_MAX_SPEED),
        .is_player    (1'b1),
        .next_is_block(p1_next_is_block),
        .pos_tx_out   (p1_tx),
        .pos_ty_out   (p1_ty),
        .pos_x        (p1_x),
        .pos_y        (p1_y),
        .as_update    (p1_update),
        .as_baw       (p1_baw),
        .path_flat_x  (p1_pfx),
        .path_flat_y  (p1_pfy),
        .path_valid   (p1_valid),
        .path_len     (p1_len)
    );
    defparam uut_mc.SIM_CLOCK = 500; // fast move_tick for simulation

    // -----------------------------------------------------------
    // DUT: a_star_mux
    // -----------------------------------------------------------
    a_star_mux uut_mux (
        .clk          (clk),
        .map_changed  (map_changed),
        .tile_map_flat(tile_map_flat),
        .c0_update    (p1_update),
        .c0_baw       (p1_baw),
        .c0_stx       (p1_tx),
        .c0_sty       (p1_ty),
        .c0_gtx       (mouse_tx),
        .c0_gty       (mouse_ty),
        .c0_pfx       (p1_pfx),
        .c0_pfy       (p1_pfy),
        .c0_valid     (p1_valid),
        .c0_len       (p1_len),
        .c1_update    (1'b0), .c1_baw(1'b0),
        .c1_stx       (4'd0), .c1_sty(4'd0),
        .c1_gtx       (4'd0), .c1_gty(4'd0),
        .c1_pfx       (),     .c1_pfy(),
        .c1_valid     (),     .c1_len()
    );

    // -----------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------
    integer pass_count = 0, fail_count = 0;

    task tick; input integer n; integer j;
        begin for (j = 0; j < n; j = j + 1) @(posedge clk); end
    endtask

    task assert_eq;
        input [31:0] got, exp;
        input [255:0] label;
        begin
            if (got === exp) begin
                $display("[PASS] %0s  got=%0d", label, got);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s  expected=%0d  got=%0d", label, exp, got);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Sticky valid flag (avoids missing 1-cycle pulse in XSim)
    reg p1_valid_seen = 0;
    always @(posedge clk)
        if (p1_valid) p1_valid_seen <= 1;

    task wait_for_valid;
        input integer timeout;
        input [255:0] label;
        integer k;
        begin
            p1_valid_seen = 0;
            for (k = 0; k < timeout; k = k + 1) begin
                @(posedge clk);
                if (p1_valid_seen) begin
                    $display("[PASS] %0s  p1_valid after %0d cycles", label, k+1);
                    pass_count = pass_count + 1;
                    p1_valid_seen = 0;
                    disable wait_for_valid;
                end
            end
            $display("[FAIL] %0s  timed out after %0d cycles", label, timeout);
            fail_count = fail_count + 1;
        end
    endtask

    // Print the full unpacked path from movement_control's internal array
    task print_unpacked_path;
        integer s;
        reg [3:0] px, py;
        begin
            $display("[PATH] --- Unpacked path (len=%0d) ---", uut_mc.path_step > 0 ? p1_len : p1_len);
            for (s = 0; s < p1_len && s < `MAX_PATH_LEN; s = s + 1) begin
                px = uut_mc.path_x[s];
                py = uut_mc.path_y[s];
                if (px !== 4'hF)
                    $display("[PATH]   [%0d] tile=(%0d,%0d)  pixel=(%0d,%0d)",
                             s, px, py,
                             `MIN_PIX_X + px * `TILE_SIZE + 1,
                             `MIN_PIX_Y + py * `TILE_SIZE + 1);
            end
            $display("[PATH] ---");
        end
    endtask

    // Wait for player to reach a specific tile, printing each move
    task wait_reach_tile;
        input [3:0] goal_tx_t, goal_ty_t;
        input integer timeout;
        integer k;
        reg [6:0] last_x; reg [5:0] last_y;
        begin
            last_x = p1_x; last_y = p1_y;
            for (k = 0; k < timeout; k = k + 1) begin
                @(posedge clk);
                // Print on every pixel move
                if (p1_x !== last_x || p1_y !== last_y) begin
                    $display("[MOVE] @%0t  pos=(%0d,%0d)  tile=(%0d,%0d)  step=%0d/%0d",
                             $time, p1_x, p1_y, p1_tx, p1_ty,
                             uut_mc.path_step, p1_len);
                    last_x = p1_x; last_y = p1_y;
                end
                // Done when tile matches goal
                if (p1_tx == goal_tx_t && p1_ty == goal_ty_t) begin
                    $display("[MOVE] Reached goal tile (%0d,%0d) after %0d cycles",
                             goal_tx_t, goal_ty_t, k+1);
                    disable wait_reach_tile;
                end
            end
            $display("[MOVE] TIMEOUT: never reached tile (%0d,%0d) -- currently at (%0d,%0d)",
                     goal_tx_t, goal_ty_t, p1_tx, p1_ty);
        end
    endtask

    // -----------------------------------------------------------
    // Hierarchical references
    // -----------------------------------------------------------
    wire       mc_path_valid_pulse = uut_mc.path_valid_pulse;
    wire       mc_new_path_pending = uut_mc.new_path_pending;
    wire       mc_tile_aligned     = uut_mc.tile_aligned;
    wire       mc_move_tick        = uut_mc.move_tick;
    wire [6:0] mc_path_step        = uut_mc.path_step;
    wire [3:0] mc_target_tx        = uut_mc.target_tx;
    wire [3:0] mc_target_ty        = uut_mc.target_ty;
    wire [6:0] mc_target_x         = uut_mc.target_x;
    wire [5:0] mc_target_y         = uut_mc.target_y;
    wire       mc_goal_changed     = uut_mc.goal_changed;
    wire       mc_next_is_block    = uut_mc.next_is_block;

    reg        mc_new_path_pending_prev = 0;
    reg [6:0]  mc_path_step_prev = 0;
    reg [6:0]  p1_x_prev = 0;
    reg [5:0]  p1_y_prev = 0;
    always @(posedge clk) begin
        mc_new_path_pending_prev <= mc_new_path_pending;
        mc_path_step_prev        <= mc_path_step;
        p1_x_prev                <= p1_x;
        p1_y_prev                <= p1_y;
    end

    // -----------------------------------------------------------
    // Monitor -- fires on key events only (not every cycle)
    // -----------------------------------------------------------
    always @(posedge clk) begin
        if (p1_update)
            $display("[MUX] @%0t  update  baw=%0b  start=(%0d,%0d)  goal=(%0d,%0d)",
                     $time, p1_baw, p1_tx, p1_ty, mouse_tx, mouse_ty);

        if (p1_valid) begin
            $display("[MUX] @%0t  valid  len=%0d  first=(%0d,%0d)  last=(%0d,%0d)",
                     $time, p1_len,
                     p1_pfx[(`MAX_PATH_LEN-1)*4 +: 4],
                     p1_pfy[(`MAX_PATH_LEN-1)*4 +: 4],
                     p1_pfx[(`MAX_PATH_LEN-p1_len)*4 +: 4],
                     p1_pfy[(`MAX_PATH_LEN-p1_len)*4 +: 4]);
        end

        if (mc_path_valid_pulse)
            $display("[MC]  @%0t  path_valid_pulse  len=%0d", $time, p1_len);

        if (mc_new_path_pending && !mc_new_path_pending_prev)
            $display("[MC]  @%0t  new_path_pending SET  aligned=%0b  pos=(%0d,%0d)  target_tile=(%0d,%0d)",
                     $time, mc_tile_aligned, p1_x, p1_y, mc_target_tx, mc_target_ty);

        if (mc_new_path_pending && mc_tile_aligned && mc_new_path_pending_prev)
            $display("[MC]  @%0t  tile_aligned -> following path  step->1  pos=(%0d,%0d)",
                     $time, p1_x, p1_y);

        // path_step change (tile boundary crossed)
        if (mc_path_step != mc_path_step_prev)
            $display("[MC]  @%0t  step %0d->%0d/%0d  now targeting tile=(%0d,%0d)  pixel=(%0d,%0d)",
                     $time, mc_path_step_prev, mc_path_step, p1_len,
                     mc_target_tx, mc_target_ty, mc_target_x, mc_target_y);

        // pixel move
        if ((p1_x !== p1_x_prev || p1_y !== p1_y_prev) && mc_path_step_prev > 0)
            $display("[POS] @%0t  (%0d,%0d) tile=(%0d,%0d)  target_tile=(%0d,%0d)  step=%0d  nib=%0b",
                     $time, p1_x, p1_y, p1_tx, p1_ty,
                     mc_target_tx, mc_target_ty, mc_path_step, mc_next_is_block);

        if (mc_goal_changed)
            $display("[MC]  @%0t  goal->(%0d,%0d)", $time, uut_mc.goal_tx, uut_mc.goal_ty);
    end

    // -----------------------------------------------------------
    // Waveform dump
    // -----------------------------------------------------------
    initial begin
        $dumpfile("a_star_mux_movement_tb.vcd");
        $dumpvars(0, a_star_mux_movement_tb);
    end

    // -----------------------------------------------------------
    // Watchdog: large enough to cover A* + movement across map
    // A* ~80000 cycles + 25 tiles * 54 cycles/tile = ~81350 cycles per test
    // 6 tests * 100000 = 600000 cycles
    // -----------------------------------------------------------
    initial begin
        #(HALF * 2 * 700000);
        $display("[WATCHDOG] timed out");
        $finish;
    end

    localparam TIMEOUT_VALID = 80000; // cycles to wait for p1_valid
    localparam TIMEOUT_MOVE  = 20000; // cycles to wait for player to reach a tile

    // -----------------------------------------------------------
    // Tests
    // -----------------------------------------------------------
    initial begin
        $display("====================================================");
        $display(" a_star_mux + movement_control");
        $display(" SIM_CLOCK=500 -> move_tick every ~9 cycles");
        $display(" One tile (~6px) takes ~54 cycles");
        $display("====================================================");
        tick(5);

        // =======================================================
        // TEST 1: Spawn position
        // =======================================================
        $display("\n-- TEST 1: Spawn position --");
        assert_eq(p1_x,  `MIN_PIX_X + 0 * `TILE_SIZE + 1, "pos_x at spawn");
        assert_eq(p1_y,  `MIN_PIX_Y + 0 * `TILE_SIZE + 1, "pos_y at spawn");
        assert_eq(p1_tx, 0, "tile_x at spawn");
        assert_eq(p1_ty, 0, "tile_y at spawn");

        // =======================================================
        // TEST 2: Click to (2,1) -- simple open area, no walls
        // Short path so we can watch the whole movement
        // =======================================================
        $display("\n-- TEST 2: Click to (2,1) and watch movement --");
        @(posedge clk); mouse_tx <= 4'd2; mouse_ty <= 4'd1;
        $display("[INFO] Waiting for A* path...");
        wait_for_valid(TIMEOUT_VALID, "TEST 2: path arrived");

        // Print the full unpacked path array
        tick(3); // let path_x/y latch settle
        print_unpacked_path;

        $display("[INFO] Watching player move to tile (2,1)...");
        wait_reach_tile(4'd2, 4'd1, TIMEOUT_MOVE);
        assert_eq(p1_tx, 2, "TEST 2: reached tile x=2");
        assert_eq(p1_ty, 1, "TEST 2: reached tile y=1");

        // =======================================================
        // TEST 3: Click past wall to (5,3)
        // Must route through gap at y=3 in wall at x=3
        // =======================================================
        $display("\n-- TEST 3: Click to (5,3) through wall gap --");
        @(posedge clk); mouse_tx <= 4'd5; mouse_ty <= 4'd3;
        $display("[INFO] Waiting for A* path...");
        wait_for_valid(TIMEOUT_VALID, "TEST 3: path arrived");

        tick(3);
        print_unpacked_path;

        // Check no wall tiles in path
        begin : t3_wall
            integer s; reg wall_hit; reg [3:0] px, py;
            wall_hit = 0;
            for (s = 0; s < p1_len; s = s + 1) begin
                px = uut_mc.path_x[s];
                py = uut_mc.path_y[s];
                if (px == 4'd3 && py != 4'd3) begin
                    $display("[FAIL] TEST 3: path[%0d]=(%0d,%0d) is a wall tile", s, px, py);
                    wall_hit = 1; fail_count = fail_count + 1;
                end
            end
            if (!wall_hit) begin
                $display("[PASS] TEST 3: path avoids wall tiles");
                pass_count = pass_count + 1;
            end
        end

        $display("[INFO] Watching player move to (5,3)...");
        wait_reach_tile(4'd5, 4'd3, TIMEOUT_MOVE);
        assert_eq(p1_tx, 5, "TEST 3: reached tile x=5");
        assert_eq(p1_ty, 3, "TEST 3: reached tile y=3");

        // =======================================================
        // TEST 4: Verify path_step advances correctly
        // Click to (0,3), watch path_step increment messages
        // =======================================================
        $display("\n-- TEST 4: Watch path_step advance --");
        @(posedge clk); mouse_tx <= 4'd0; mouse_ty <= 4'd3;
        wait_for_valid(TIMEOUT_VALID, "TEST 4: path arrived");
        tick(3);
        print_unpacked_path;
        wait_reach_tile(4'd0, 4'd3, TIMEOUT_MOVE);

        // =======================================================
        // TEST 5: map_changed triggers replan mid-movement
        // =======================================================
        $display("\n-- TEST 5: map_changed while moving --");
        @(posedge clk); mouse_tx <= 4'd7; mouse_ty <= 4'd5;
        wait_for_valid(TIMEOUT_VALID, "TEST 5: initial path");
        tick(3);
        print_unpacked_path;

        // Let player move a few steps then fire map_changed
        tick(200);
        $display("[INFO] Firing map_changed mid-movement...");
        @(posedge clk); map_changed <= 1;
        @(posedge clk); map_changed <= 0;
        $display("[INFO] Waiting for replan...");
        wait_for_valid(TIMEOUT_VALID, "TEST 5: replan after map_changed");
        tick(3);
        print_unpacked_path;
        $display("[PASS] TEST 5: map_changed triggered replan");
        pass_count = pass_count + 1;

        // =======================================================
        // SUMMARY
        // =======================================================
        tick(10);
        $display("\n====================================================");
        $display(" RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        $display("====================================================");
        if (fail_count == 0) $display(" ALL TESTS PASSED");
        else                 $display(" SOME TESTS FAILED");
        $display("====================================================\n");
        $finish;
    end

endmodule*/