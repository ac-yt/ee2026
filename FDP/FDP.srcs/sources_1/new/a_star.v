`timescale 1ns / 1ps

module a_star #(parameter CLOCK_SPEED=100_000_000)
               (input clk, update,// rst,
                input [3:0] start_x, start_y, goal_x, goal_y,
                input [3*`TILE_MAP_SIZE-1:0] tile_map_flat,
                output reg [4*`MAX_PATH_LEN-1:0] path_flat_x=0, path_flat_y=0,
                output reg [6:0] path_len=0,
                output reg path_valid=0,
                output reg [10:0] path_cost=0);
  
    localparam integer EMPTY_COST = 1;
    localparam integer BLOCK_COST = 3;
    
    reg [3:0] open_x [0:`MAX_NUM_NODES-1]; // maximum 81 ENTRIES
    reg [3:0] open_y [0:`MAX_NUM_NODES-1]; // open list to store nodes to visit next
    reg [3:0] closed_x [0:`MAX_NUM_NODES-1]; // closed list to store visited nodes
    reg [3:0] closed_y [0:`MAX_NUM_NODES-1];
    reg [7:0] open_counter=0; // count number of items in the open list
    reg [7:0] closed_counter=0; // count number of items in the open list
    
//    reg [7:0] base_cost [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1]; // stores the base cost of each node (cost more to move to block than empty tile)
    reg [7:0] cost_array [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1]; // stores the cost of each node from the start node
    reg [3:0] parent_x [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1]; // stores the parent x of each node
    reg [3:0] parent_y [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1]; // stores the parent y of each node
    
    reg [3:0] start_x_loc=0, start_y_loc=0, goal_x_loc=0, goal_y_loc=0; // store locally
    
    // parameters for FSM
    localparam integer MAX_F = BLOCK_COST * `MAX_PATH_LEN + `TILE_MAP_WIDTH-1 + `TILE_MAP_HEIGHT-1;
    reg [$clog2(MAX_F):0] best_f=0, f_val=0;
    reg [7:0] scan_index=0, best_index=0, shift_index=0, path_index=0;
    reg [3:0] best_x=0, best_y=0, curr_x=0, curr_y=0, nb_x=0, nb_y=0, curr_path_x=0, curr_path_y=0;
    reg [1:0] nb_index=0;
    
    // FSM
    localparam CHECK_OPEN             = 5'b00000;
    localparam FIND_BEST_INIT         = 5'b00001;
    localparam FIND_BEST_SCAN         = 5'b00010;
    localparam FIND_BEST_DONE         = 5'b00011;
    localparam POP_OPEN_INIT          = 5'b00100;
    localparam POP_OPEN_SHIFT         = 5'b00101;
    localparam POP_OPEN_DONE          = 5'b00110;
    localparam NB_INIT                = 5'b00111;
    localparam NB_GEN                 = 5'b01000;
    localparam NB_CHECK_VALID         = 5'b01001;
    localparam NB_CHECK_GOAL          = 5'b01010;
    localparam NB_NEXT                = 5'b01011;
    localparam NB_CHECK_CLOSED_INIT   = 5'b01100;
    localparam NB_CHECK_CLOSED_SCAN   = 5'b01101;
    localparam NB_CHECK_OPEN_INIT     = 5'b01110;
    localparam NB_CHECK_OPEN_SCAN     = 5'b01111;
    localparam NB_CHECK_OPEN_DONE     = 5'b10000;
    localparam PATH_INIT              = 5'b10001;
    localparam PATH_TRACE             = 5'b10010;
    localparam DONE                   = 5'b10011;
    localparam RESET_2D               = 5'b10100;
    localparam RESET_1D               = 5'b10101;
    localparam SET_START              = 5'b10110;
    reg [4:0] state = RESET_2D;
    reg [4:0] next_state = RESET_2D;
    reg [4:0] prev_state = RESET_2D;
    
    reg [2:0] tile_map [0:`TILE_MAP_WIDTH-1][0:`TILE_MAP_HEIGHT-1];
//    integer tx, ty, i;
    
    reg [7:0] init_index_x=0, init_index_y=0;
    reg [$clog2(`MAX_PATH_LEN*4)-1:0] init_index_i=0;
    
    wire [3:0] scan_open_x = open_x[scan_index];
    wire [3:0] scan_open_y = open_y[scan_index];
    
    wire [1:0] tile_base_cost = (tile_map[nb_x][nb_y] == `MAP_BLOCK) ? BLOCK_COST : EMPTY_COST;
    
    // NEXT STATE LOGIC
    always @ (*) begin
        next_state = state;
//        if (rst) next_state = RESET_2D;
        if (update) next_state = RESET_2D;
        else begin
            case (state)
                RESET_2D: begin
                    if (init_index_x == `TILE_MAP_WIDTH-1 && init_index_y == `TILE_MAP_HEIGHT-1) next_state = RESET_1D;
                end
                RESET_1D: begin
                    if (init_index_i == `MAX_PATH_LEN*4-1) next_state = SET_START;
                end
                SET_START: next_state = CHECK_OPEN;
                CHECK_OPEN: begin // check if open list has nodes
                    if (open_counter) next_state = FIND_BEST_INIT;
                    else next_state = DONE;
                end
                FIND_BEST_INIT: begin // reset scan of best node on open list
                    next_state = FIND_BEST_SCAN;
                end
                FIND_BEST_SCAN: begin // scan through entire open list to find lowest f cost on the list
                    if (scan_index == open_counter) next_state = FIND_BEST_DONE;
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
                    next_state = NB_CHECK_VALID;
                end
                NB_CHECK_VALID: begin // check if neighbor is within bounds and is not a wall
                    if (nb_x != 4'hF && nb_x < `TILE_MAP_WIDTH && nb_y != 4'hF && nb_y < `TILE_MAP_HEIGHT)
                        if (tile_map[nb_x][nb_y] != `MAP_WALL) next_state = NB_CHECK_GOAL;
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
                    next_state = PATH_TRACE;
                end
                PATH_TRACE: begin
                    if (curr_path_x == start_x_loc && curr_path_y == start_y_loc) begin
                        next_state = DONE;
                    end
                end
                DONE: next_state = DONE;
                default: next_state = RESET_2D;
            endcase
        end
    end
    
    wire [3:0] next_path_x = parent_x[curr_path_x][curr_path_y];
    wire [3:0] next_path_y = parent_y[curr_path_x][curr_path_y];
   
    // SEQUENTIAL LOGIC
    always @ (posedge clk) begin
        state <= next_state;
        prev_state <= state;
        
        /*if (rst) begin
            path_valid <= 0;
            path_len <= 0;
            path_cost <= 0;
            open_counter <= 0;
            closed_counter <= 0;
            path_valid <= 0;
            init_index_x <= 0;
            init_index_y <= 0;
            init_index_i <= 0;
        end*/
        if (update) begin
            init_index_x <= 0;
            init_index_y <= 0;
            init_index_i <= 0;
//            path_valid <= 0;
        end
        else begin
        case (state)
            RESET_2D: begin
                path_valid <= 0;
                tile_map[init_index_x][init_index_y] <= tile_map_flat[(init_index_y*`TILE_MAP_WIDTH + init_index_x)*3 +: 3];

//                base_cost[init_index_x][init_index_y] <= (tile_map_flat[(init_index_y*`TILE_MAP_WIDTH + init_index_x)*3 +: 3] == `MAP_BLOCK) ? BLOCK_COST : EMPTY_COST;
                                    
                cost_array[init_index_x][init_index_y] <= 8'hFF;
                parent_x[init_index_x][init_index_y] <= 4'hF;
                parent_y[init_index_x][init_index_y] <= 4'hF;
                
                if (init_index_x == `TILE_MAP_WIDTH-1) begin
                    init_index_x <= 0;
                    if (init_index_y < `TILE_MAP_HEIGHT-1) init_index_y <= init_index_y + 1;
                end
                else init_index_x <= init_index_x + 1;
            end
            RESET_1D: begin
                path_flat_x[init_index_i] <= 4'hF;
                path_flat_y[init_index_i] <= 4'hF;
                
                if (init_index_i < `MAX_NUM_NODES) begin
                    open_x[init_index_i]   <= 4'hF;
                    open_y[init_index_i]   <= 4'hF;
                    closed_x[init_index_i] <= 4'hF;
                    closed_y[init_index_i] <= 4'hF;
                end
                
                if (init_index_i < `MAX_PATH_LEN*4-1) init_index_i <= init_index_i + 1;
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
                
                //path_valid <= 0;
                path_len <= 0;
                path_cost <= 0;
            end
            FIND_BEST_INIT: begin // reset scan of best node on open list
                best_f <= 8'hFF;
                best_x <= 0;
                best_y <= 0;
                scan_index <= 0;
                best_index <= 0;
            end
            FIND_BEST_SCAN: begin // scan through entire open list to find lowest f cost on the list
                if (scan_index < open_counter) begin
                    if (cost_array[scan_open_x][scan_open_y] + heuristic(scan_open_x, scan_open_y, goal_x_loc, goal_y_loc) < best_f) begin
                        best_f <= cost_array[scan_open_x][scan_open_y] + heuristic(scan_open_x, scan_open_y, goal_x_loc, goal_y_loc);
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
            end
            NB_CHECK_GOAL: begin // check if neighbor is goal
                if (nb_x == goal_x_loc && nb_y == goal_y_loc) begin
                    parent_x[nb_x][nb_y] <= curr_x;
                    parent_y[nb_x][nb_y] <= curr_y;
                    cost_array[nb_x][nb_y] <= cost_array[curr_x][curr_y] + tile_base_cost;
                end
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
                    if (cost_array[curr_x][curr_y] + tile_base_cost < cost_array[nb_x][nb_y]) begin
                        cost_array[nb_x][nb_y] <= cost_array[curr_x][curr_y] + tile_base_cost;
                        parent_x[nb_x][nb_y] <= curr_x; // update parent node
                        parent_y[nb_x][nb_y] <= curr_y;
                    end
                end
                else begin
                    open_x[open_counter] <= nb_x; // push to open list
                    open_y[open_counter] <= nb_y;
                    cost_array[nb_x][nb_y] <= cost_array[curr_x][curr_y] + tile_base_cost;
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
                //path_valid <= 0;
                curr_path_x <= goal_x_loc;
                curr_path_y <= goal_y_loc;
            end
            PATH_TRACE: begin
                path_flat_x[path_index*4 +: 4] <= curr_path_x;
                path_flat_y[path_index*4 +: 4] <= curr_path_y;
                
                if (!(curr_path_x == start_x_loc && curr_path_y == start_y_loc)) begin
                    curr_path_x <= next_path_x;
                    curr_path_y <= next_path_y;
                    path_index <= path_index + 1;
                end
            end
            DONE: begin
                // add check
                if (prev_state == PATH_TRACE) begin
                    path_len <= path_index + 1;
                    path_cost <= cost_array[goal_x_loc][goal_y_loc];
                    path_valid <= 1; // pulse path_valid for 1 cycle
                end
                else path_valid <= 0;
            end
        endcase
        end
    end
    
    // always @ (*) path_valid <= (state == DONE && prev_state == PATH_TRACE) ? 1 : 0;
    
    function [4:0] heuristic;
        input [3:0] x, y;
        input [3:0] goal_x, goal_y;
    begin
        // use manhattan distance as a heuristic
        heuristic = (x > goal_x ? x - goal_x : goal_x - x) + (y > goal_y ? y - goal_y : goal_y - y);
    end
    endfunction
endmodule

/*

// Wrap your code into a module so we can instantiate it
module top_with_astar (
    input basys_clk, btnC, //rst,
    output [15:0] led
);
    wire clk_a_star;
    variable_clock #(.CLOCK_SPEED(`CLOCK_SPEED), .OUT_SPEED(`CLOCK_SPEED/2)) clk_a_star_inst
                    (.clk(basys_clk), .clk_out(clk_a_star)); 
    
    reg update_path = 0;
    reg [1:0] updated = 0;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_x;
    wire [4*`MAX_PATH_LEN-1:0] path_flat_y;
    reg [3:0] path_x [0:`MAX_PATH_LEN];
    reg [3:0] path_y [0:`MAX_PATH_LEN];
    wire [6:0] path_len;
    wire path_valid;
    reg prev_path_valid = 0;
    reg path_saved = 1;
    wire [10:0] path_cost;
    reg [4*`TILE_MAP_SIZE-1:0] path_flat_y_loc, path_flat_x_loc;
    reg [7:0] path_index = 0;
    reg [6:0] path_len_loc = 0;
    reg [10:0] path_cost_loc;
//        reg rst = 1;

    a_star #(.CLOCK_SPEED(`CLOCK_SPEED/2)) a_star_inst
        (.clk(clk_a_star), .update(update_path),// .rst(rst),
         .start_x(4'b0), .start_y(4'b0), .goal_x(4'b0001), .goal_y(4'b0001),
         .tile_map_flat({(`TILE_MAP_SIZE){3'b000}}),
         .path_flat_x(path_flat_x), .path_flat_y(path_flat_y),
         .path_len(path_len), .path_valid(path_valid), .path_cost(path_cost));

        // Synchronize btnC into slow domain (2-FF)
        reg btnC_ff1 = 0, btnC_ff2 = 0, btnC_ff2_prev = 0;
        always @(posedge clk_a_star) begin
            btnC_ff1      <= btnC;
            btnC_ff2      <= btnC_ff1;
            btnC_ff2_prev <= btnC_ff2;
        end
        
        // Single rising-edge pulse, fully in slow domain
        wire update_pulse = btnC_ff2 & ~btnC_ff2_prev;
        
        // Drive update_path from slow domain only
        always @(posedge clk_a_star) begin
            update_path <= update_pulse;
        end
        
        
        reg path_valid_ff1 = 0;   // first sync stage  (clocked by basys_clk)
        reg path_valid_ff2 = 0;   // second sync stage (clocked by basys_clk)
        reg path_valid_ff2_prev = 0; // for rising edge detection
        
        
        always @(posedge basys_clk) begin
            path_valid_ff1     <= path_valid;        // may be metastable, but resolves by next cycle
            path_valid_ff2     <= path_valid_ff1;    // stable by now
            path_valid_ff2_prev <= path_valid_ff2;
        end
        
        // Single-cycle pulse in the fast domain when path_valid safely goes high
        wire path_valid_sync_pulse = path_valid_ff2 & ~path_valid_ff2_prev;
        
        
        always @(posedge basys_clk) begin
            if (path_valid_sync_pulse) begin
                path_flat_x_loc <= path_flat_x;
                path_flat_y_loc <= path_flat_y;
                path_len_loc    <= path_len;
                path_cost_loc   <= path_cost;
                path_saved      <= 0;
                path_index      <= 0;
            end
            
            if (!path_saved) begin
//                led[15] <= 1;
                if (path_index < path_len_loc) begin
                    path_x[path_index] <= path_flat_x_loc[path_index*4 +: 4];
                    path_y[path_index] <= path_flat_y_loc[path_index*4 +: 4];
                    path_index <= path_index + 1;
                end
                else if (path_index < `MAX_PATH_LEN) begin
                    path_x[path_index] <= 4'hF;
                    path_y[path_index] <= 4'hF;
                    path_index <= path_index + 1;
                end
                else begin
                    path_saved <= 1;
                end
            end
            
        end

    assign led[0] = update_path;
    assign led[3:1] = path_len[3:1];
    assign led[7:4] = path_len_loc[3:0];
    assign led[11:8] = path_flat_x[3:0];
    assign led[15:12] = path_x[0];
endmodule
*/