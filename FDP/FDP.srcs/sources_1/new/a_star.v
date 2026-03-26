`timescale 1ns / 1ps

`include "constants.vh"

module a_star (input clk, update, blocks_as_walls,
               input [3:0] start_x, start_y, goal_x, goal_y,
               input [3*`TILE_MAP_SIZE-1:0] tile_map_flat,
               output reg [4*`MAX_PATH_LEN-1:0] path_flat_x=0, path_flat_y=0,
               output reg [6:0] path_len=0,
               output reg path_valid=0);
               // output reg [10:0] path_cost=0);
    
    // parameters 
    parameter integer EMPTY_COST = 1;
    parameter integer BLOCK_COST = 3;
//    parameter integer BOMB_COST = 5;
    parameter integer MAX_COST = BLOCK_COST * `MAX_PATH_LEN;
//    parameter integer MAX_COST = BOMB_COST * `MAX_PATH_LEN;
    parameter integer MAX_F = MAX_COST + `TILE_MAP_WIDTH-1 + `TILE_MAP_HEIGHT-1;
    
    // BRAM 2D arrays - read latency is 1 cycle, write is same cycle
    (* ram_style = "block" *) reg [$clog2(MAX_COST):0] cost_array [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1]; // stores the cost of each node from the start node
    (* ram_style = "block" *) reg [3:0] parent_x [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1]; // stores the parent x of each node
    (* ram_style = "block" *) reg [3:0] parent_y [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1]; // stores the parent y of each node
    (* ram_style = "block" *) reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];

    // pipeline registers for BRAM read
    // must reread everytime so for cost_scan after every scan goes to BEST_WAIT (NEWLY ADDED)
    // for cost_curr/nb it auto goes back to NB_GEN
    // for par it goes back to PATH_BRAM_WAIT every path trace also (NEWLY ADDED)
    reg [$clog2(MAX_COST)-1:0] cost_curr = 0; // cost_array curr, loaded in NB_GEN (to use in NB_CHECK_GOAL + NB_CHECK_OPEN_DONE)
    reg [$clog2(MAX_COST)-1:0] cost_nb = 0; // cost_array nb, loaded in NB_CHECK_GOAL (to use in NB_CHECK_OPEN_DONE)
    reg [$clog2(MAX_COST)-1:0] cost_scan = 0; // cost_array scan, loaded in FIND_BEST_BRAM_WAIT (to use in FIND_BEST_SCAN)
    reg [$clog2(MAX_COST)-1:0] cost_goal = 0; // goal cost for DONE, loaded in NB_CHECK_GOAL
    reg [3:0] par_x_out = 0; // parent_x/y BRAM output registered in PATH_BRAM_WAIT
    reg [3:0] par_y_out = 0;
    reg [2:0] nb_is_wall = 0; // read in NB_BRAM_WAIT to use in NB_CHECK_VALID
    reg [2:0] nb_is_block = 0; // read in NB_BRAM_WAIT to use in NB_CHECK_VALID
    reg [2:0] tile_base_cost = 0; // read in NB_BRAM_WAIT to use in NB_CHECK_OPEN/CLOSED
    reg [$clog2(MAX_F)-1:0] nb_heuristic = 0;
    
    // reset and update map variables
    reg [7:0] init_index_x = 0, init_index_y = 0;
    reg [$clog2(`MAX_PATH_LEN*4)-1:0] init_index_i = 0;
    
    // open list
    reg [3:0] open_x [0:`MAX_NUM_NODES-1]; // maximum 81 ENTRIES
    reg [3:0] open_y [0:`MAX_NUM_NODES-1]; // open list to store nodes to visit next
    reg [$clog2(`MAX_NUM_NODES)-1:0] open_counter = 0; // count number of items in the open list
    
    // BRAM closed list
    reg [3:0] closed_x [0:`MAX_NUM_NODES-1]; // closed list to store visited nodes
    reg [3:0] closed_y [0:`MAX_NUM_NODES-1];
    reg [$clog2(`MAX_NUM_NODES)-1:0] closed_counter = 0; // count number of items in the open list

    // fsm registers
    reg [3:0] start_x_loc=0, start_y_loc=0, goal_x_loc=0, goal_y_loc=0; // store locally
    reg [$clog2(MAX_F)-1:0] best_f=0;
    reg [$clog2(`MAX_NUM_NODES)-1:0] scan_index=0, best_index=0, shift_index=0, path_index=0;
    reg [3:0] best_x=0, best_y=0, curr_x=0, curr_y=0, nb_x=0, nb_y=0, curr_path_x=0, curr_path_y=0;
    reg [1:0] nb_index=0;
    // reg [10:0] path_cost=0;
    
    // wires to FSM
    wire [3:0] scan_open_x = open_x[scan_index]; // FIND_BEST_SCAN, node on open list
    wire [3:0] scan_open_y = open_y[scan_index];
//    wire [1:0] tile_base_cost = (tile_map[nb_x][nb_y] == `MAP_BLOCK) ? BLOCK_COST : EMPTY_COST;
//    wire [2:0] tile_base_cost = (tile_map[nb_x][nb_y] == `MAP_BLOCK) ? BLOCK_COST : 
//                                (tile_map[nb_x][nb_y] == `MAP_BOMB) ? BOMB_COST : EMPTY_COST;
    
    // FSM
    parameter CHECK_OPEN             = 5'd0;
    parameter FIND_BEST_INIT         = 5'd1;
    parameter FIND_BEST_SCAN         = 5'd2;
    parameter FIND_BEST_DONE         = 5'd3;
    parameter POP_OPEN_INIT          = 5'd4;
    parameter POP_OPEN_SHIFT         = 5'd5;
    parameter POP_OPEN_DONE          = 5'd6;
    parameter NB_INIT                = 5'd7;
    parameter NB_GEN                 = 5'd8;
    parameter NB_CHECK_VALID         = 5'd9;
    parameter NB_CHECK_GOAL          = 5'd10;
    parameter NB_NEXT                = 5'd11;
    parameter NB_CHECK_CLOSED_INIT   = 5'd12;
    parameter NB_CHECK_CLOSED_SCAN   = 5'd13;
    parameter NB_CHECK_OPEN_INIT     = 5'd14;
    parameter NB_CHECK_OPEN_SCAN     = 5'd15;
    parameter NB_CHECK_OPEN_DONE     = 5'd16;
    parameter PATH_INIT              = 5'd17;
    parameter PATH_TRACE             = 5'd18;
    parameter DONE                   = 5'd19;
    parameter RESET_2D               = 5'd20;
    parameter RESET_1D               = 5'd21;
    parameter SET_START              = 5'd22;
    parameter FIND_BEST_BRAM_WAIT    = 5'd23;
    parameter PATH_BRAM_WAIT         = 5'd24;
    parameter NB_BRAM_WAIT           = 5'd25;
    // parameter FIND_BEST_COORDS       = 5'b11010;
    reg [4:0] state = RESET_2D;
    reg [4:0] next_state = RESET_2D;
    reg [4:0] prev_state = RESET_2D;
    
    // NEXT STATE LOGIC
    always @ (*) begin
        next_state = state;
        if (update) next_state = RESET_2D;
        else begin
            case (state)
                RESET_2D: begin
                    if (init_index_x == `TILE_MAP_WIDTH-1 && init_index_y == `TILE_MAP_HEIGHT-1) next_state = RESET_1D;
                end
                RESET_1D: begin
                    if (init_index_i == `MAX_NUM_NODES-1) next_state = SET_START;
                end
                SET_START: next_state = CHECK_OPEN;
                CHECK_OPEN: begin // check if open list has nodes
                    if (open_counter) next_state = FIND_BEST_INIT;
                    else next_state = DONE;
                end
                FIND_BEST_INIT: begin // reset scan of best node on open list
                    next_state = FIND_BEST_BRAM_WAIT;
                end
//                FIND_BEST_COORDS: begin
//                    next_state = FIND_BEST_BRAM_WAIT;
//                end
                FIND_BEST_BRAM_WAIT: begin
                    next_state = FIND_BEST_SCAN;
                end
                FIND_BEST_SCAN: begin // scan through entire open list to find lowest f cost on the list
                    if (scan_index == open_counter) next_state = FIND_BEST_DONE;
                    else next_state = FIND_BEST_BRAM_WAIT;
                end
                FIND_BEST_DONE: begin // latch best node to currx/y
                    next_state = POP_OPEN_INIT;
                end
                POP_OPEN_INIT: begin // reset shifting of queue down (to remove the curr node from open list)
                    next_state = POP_OPEN_SHIFT;
                end
                POP_OPEN_SHIFT: begin // shift down all
                    if (shift_index == open_counter-1) next_state = POP_OPEN_DONE;
                end
                POP_OPEN_DONE: begin
                    next_state = NB_INIT;
                end
                NB_INIT: begin // reset neighbor scanning
                    next_state = NB_GEN;
                end
                NB_GEN: begin // find neighbours LRUD of current node
                    next_state = NB_BRAM_WAIT;
                end
                NB_BRAM_WAIT: begin
                    next_state = NB_CHECK_VALID;
                end
                NB_CHECK_VALID: begin // check if neighbor is within bounds and is not a wall
                    if (nb_x != 4'hF && nb_x < `TILE_MAP_WIDTH && nb_y != 4'hF && nb_y < `TILE_MAP_HEIGHT)
                        if (!nb_is_wall && (!blocks_as_walls || !nb_is_block)) next_state = NB_CHECK_GOAL;
//                        if (tile_map[nb_x][nb_y] != `MAP_WALL && (!blocks_as_walls && tile_map[nb_x][nb_y] != `MAP_BLOCK)) next_state = NB_CHECK_GOAL;
//                        if (tile_map[nb_x][nb_y] != `MAP_WALL && (!blocks_as_walls || tile_map[nb_x][nb_y] != `MAP_BLOCK)) next_state = NB_CHECK_GOAL;
                        else next_state = NB_NEXT;
                    else next_state = NB_NEXT;
                end
                NB_CHECK_GOAL: begin // check if neighbor is goal
                    if (nb_x == goal_x_loc && nb_y == goal_y_loc) begin
                        next_state = PATH_INIT; // finish expansion and reconstruct path if goal
                    end
                    else next_state = NB_CHECK_CLOSED_INIT;
                end
                NB_CHECK_CLOSED_INIT: begin // reset scan of closed list
                    next_state = NB_CHECK_CLOSED_SCAN;
                end
                NB_CHECK_CLOSED_SCAN: begin
                    if (scan_index < closed_counter) begin
                        if (closed_x[scan_index] == nb_x && closed_y[scan_index] == nb_y) next_state = NB_NEXT; // if neighbor is on closed list skip neighbor
                    end
                    else next_state = NB_CHECK_OPEN_INIT;
                end
                NB_CHECK_OPEN_INIT: begin // reset scan of open list
                    next_state = NB_CHECK_OPEN_SCAN;
                end
                NB_CHECK_OPEN_SCAN: begin // scan until found on open list
                    if (scan_index < open_counter) begin
                        if (open_x[scan_index] == nb_x && open_y[scan_index] == nb_y) next_state = NB_CHECK_OPEN_DONE; // neighbor was found, escape loop
                    end
                    else next_state = NB_CHECK_OPEN_DONE;
                end
                NB_CHECK_OPEN_DONE: begin
                    next_state = NB_NEXT;
                end
                NB_NEXT: begin
                    if (nb_index == 3) next_state = CHECK_OPEN;
                    else begin // check next nb
                        next_state = NB_GEN;
                    end
                end
                PATH_INIT: begin
                    next_state = PATH_BRAM_WAIT;
                end
                PATH_BRAM_WAIT: begin
                    next_state = PATH_TRACE;
                end
                PATH_TRACE: begin
                    if (curr_path_x == start_x_loc && curr_path_y == start_y_loc) next_state = DONE;
                    else next_state = PATH_BRAM_WAIT;
                end
                DONE: next_state = DONE;
                default: next_state = RESET_2D;
            endcase
        end
    end
   
    // SEQ LOGIC 1 - check for update and increment reset counters
    always @ (posedge clk) begin
        if (update) begin
            init_index_x <= 0;
            init_index_y <= 0;
            init_index_i <= 0;
        end
        else if (state == RESET_2D) begin
            if (init_index_x == `TILE_MAP_WIDTH-1) begin
                init_index_x <= 0;
                if (init_index_y < `TILE_MAP_HEIGHT-1) init_index_y <= init_index_y + 1;
            end
            else init_index_x <= init_index_x + 1;
        end
        else if (state == RESET_1D) init_index_i <= init_index_i + 1;
    end
    
    // SQ LOGIC 2 - update path_valid
    always @ (posedge clk) begin
        if (update) path_valid <= 0;
        else if (state == DONE) path_valid <= (prev_state == PATH_TRACE || prev_state == CHECK_OPEN);
    end
    
    // SQ LOGIC 3 - update states
    always @ (posedge clk) begin
        state <= next_state;
        prev_state <= state;
    end
    
    // SQ LOGIC 4 - finite state machine
    // splitting from 1 SQ to 4 blocks removes the if/else on the update check, reducing LUTs used
    always @ (posedge clk) begin
        if (!update) begin
            case (state)
                RESET_2D: begin
                    tile_map[init_index_x][init_index_y] <= tile_map_flat[(init_index_y*`TILE_MAP_WIDTH + init_index_x)*3 +: 3];
                    cost_array[init_index_x][init_index_y] <= 8'hFF;
                    parent_x[init_index_x][init_index_y] <= 4'hF;
                    parent_y[init_index_x][init_index_y] <= 4'hF;
                end
                RESET_1D: begin
                    open_x[init_index_i]   <= 4'hF;
                    open_y[init_index_i]   <= 4'hF;
                    closed_x[init_index_i] <= 4'hF;
                    closed_y[init_index_i] <= 4'hF;
                end
                SET_START: begin
                    // clear lists
                    open_counter <= 0;
                    closed_counter <= 0;
                    
                    // initialize start node
                    open_x[0] <= start_x;
                    open_y[0] <= start_y;
                    open_counter <= 1;
                    cost_array[start_x][start_y] <= 0;
                    
                    // store start/goal location
                    start_x_loc <= start_x;
                    start_y_loc <= start_y;
                    goal_x_loc <= goal_x;
                    goal_y_loc <= goal_y;
                end
                CHECK_OPEN: begin end // nothing done here
                FIND_BEST_INIT: begin // reset scan of best node on open list
                    best_f <= 8'hFF;
                    best_x <= 0;
                    best_y <= 0;
                    scan_index <= 0;
                    best_index <= 0;
                end
                FIND_BEST_BRAM_WAIT: begin // load BRAM cost_array
                    cost_scan <= cost_array[scan_open_x][scan_open_y]; // scan_index incremented in FIND_BEST_SCAN
                    nb_heuristic <= heuristic(scan_open_x, scan_open_y, goal_x_loc, goal_y_loc);
                end
                FIND_BEST_SCAN: begin // scan through entire open list to find lowest f cost on the list
                    if (scan_index < open_counter) begin
                        if (cost_scan + nb_heuristic < best_f) begin
                            best_f <= cost_scan + nb_heuristic;
                            best_x <= scan_open_x;
                            best_y <= scan_open_y;
                            best_index <= scan_index;
                        end
                        scan_index <= scan_index + 1;
                    end
                end
                FIND_BEST_DONE: begin // latch best node to currx/y
                    curr_x <= best_x;
                    curr_y <= best_y;
                end
                POP_OPEN_INIT: begin // reset shifting of queue down (to remove the curr node from open list)
                    shift_index <= best_index;
                end
                POP_OPEN_SHIFT: begin // shift down all
                    open_x[shift_index] <= open_x[shift_index+1];
                    open_y[shift_index] <= open_y[shift_index+1];
                    shift_index <= shift_index + 1;
                end
                POP_OPEN_DONE: begin
                    open_x[open_counter-1] <= 4'hF; // assign last node to invalid entry
                    open_y[open_counter-1] <= 4'hF;
                    open_counter <= open_counter - 1;
                    
                    closed_x[closed_counter] <= curr_x; // push current node to closed list
                    closed_y[closed_counter] <= curr_y;
                    closed_counter <= closed_counter + 1;
                end
                NB_INIT: begin // reset neighbor scanning
                    nb_index <= 0;
                end
                NB_GEN: begin // find neighbours LRUD of current node
                    case (nb_index)
                        0: begin // up
                            nb_x <= curr_x;
                            nb_y <= curr_y - 1;
                        end
                        1: begin // down
                            nb_x <= curr_x;
                            nb_y <= curr_y + 1;
                        end
                        2: begin // left
                            nb_x <= curr_x - 1;
                            nb_y <= curr_y;
                        end
                        default: begin // right
                            nb_x <= curr_x + 1;
                            nb_y <= curr_y;
                        end
                    endcase
                    
                    cost_curr <= cost_array[curr_x][curr_y]; // pre-load for NB_CHECK_GOAL and OPEN_DONE
                end
                NB_BRAM_WAIT: begin
                    nb_is_wall <= (tile_map[nb_x][nb_y] == `MAP_WALL);
                    nb_is_block <= (tile_map[nb_x][nb_y] == `MAP_BLOCK);
                    tile_base_cost <= (tile_map[nb_x][nb_y] == `MAP_BLOCK) ? BLOCK_COST : EMPTY_COST;
                end
                NB_CHECK_VALID: begin end // nothing done here
                NB_CHECK_GOAL: begin // check if neighbor is goal
                    if (nb_x == goal_x_loc && nb_y == goal_y_loc) begin
                        parent_x[nb_x][nb_y] <= curr_x;
                        parent_y[nb_x][nb_y] <= curr_y;
                        cost_array[nb_x][nb_y] <= cost_curr + tile_base_cost;
                        cost_goal <= cost_curr + tile_base_cost; // latch for DONE if neighbor = goal
                    end
                    
                    cost_nb <= cost_array[nb_x][nb_y]; // preload for use in NB_CHECK_OPEN_DONE
                end
                NB_CHECK_CLOSED_INIT: begin // reset scan of closed list
                    scan_index <= 0;
                end
                NB_CHECK_CLOSED_SCAN: begin
                    if (scan_index < closed_counter) begin
                        if (!(closed_x[scan_index] == nb_x && closed_y[scan_index] == nb_y)) scan_index <= scan_index + 1;
                    end
                end
                NB_CHECK_OPEN_INIT: begin // reset scan of open list
                    scan_index <= 0;
                end
                NB_CHECK_OPEN_SCAN: begin // scan until found on open list
                    if (scan_index < open_counter) begin
                        if (!(open_x[scan_index] == nb_x && open_y[scan_index] == nb_y)) scan_index <= scan_index + 1;
                    end
                end
                NB_CHECK_OPEN_DONE: begin
                    if (open_x[scan_index] == nb_x && open_y[scan_index] == nb_y) begin // neighbor was found on open list
                        // check if current nb cost is less than parents cost + cost to move
                        if (cost_curr + tile_base_cost < cost_nb) begin
                            cost_array[nb_x][nb_y] <= cost_curr + tile_base_cost;
                            parent_x[nb_x][nb_y] <= curr_x; // update parent node
                            parent_y[nb_x][nb_y] <= curr_y;
                        end
                    end
                    else begin
                        open_x[open_counter] <= nb_x; // push to open list
                        open_y[open_counter] <= nb_y;
                        cost_array[nb_x][nb_y] <= cost_curr + tile_base_cost;
                        parent_x[nb_x][nb_y] <= curr_x; // update parent node
                        parent_y[nb_x][nb_y] <= curr_y;
                        
                        open_counter <= open_counter + 1;
                    end
                end
                NB_NEXT: begin
                    if (nb_index < 3) nb_index <= nb_index + 1;
                end
                PATH_INIT: begin
                    path_index <= 0;
                    curr_path_x <= goal_x_loc;
                    curr_path_y <= goal_y_loc;
                end
                PATH_BRAM_WAIT: begin
                    par_x_out <= parent_x[curr_path_x][curr_path_y]; // load BRAM
                    par_y_out <= parent_y[curr_path_x][curr_path_y];
                end
                PATH_TRACE: begin
                    // path_flat_x[path_index*4 +: 4] <= curr_path_x;
                    // path_flat_y[path_index*4 +: 4] <= curr_path_y;
                    
                    // use shift to write path to save LUTS (saves ~1000)
                    path_flat_x <= {curr_path_x, path_flat_x[4*`MAX_PATH_LEN-1:4]}; // path ends up at MSB side
                    path_flat_y <= {curr_path_y, path_flat_y[4*`MAX_PATH_LEN-1:4]};
                    
                    if (!(curr_path_x == start_x_loc && curr_path_y == start_y_loc)) begin
                        curr_path_x <= par_x_out;
                        curr_path_y <= par_y_out;
                        path_index <= path_index + 1;
                    end
                end
                DONE: begin
                    // add check
                    if (prev_state == PATH_TRACE) begin
                        path_len <= path_index + 1;
                        // path_cost <= cost_array[goal_x_loc][goal_y_loc];
                    end
                    else if (prev_state == CHECK_OPEN) path_len <= 0;
                end
            endcase
        end
    end
    
    function [4:0] heuristic;
        input [3:0] x, y;
        input [3:0] goal_x, goal_y;
    begin
        // use manhattan distance as a heuristic
        heuristic = (x > goal_x ? x - goal_x : goal_x - x) + (y > goal_y ? y - goal_y : goal_y - y);
    end
    endfunction
endmodule
