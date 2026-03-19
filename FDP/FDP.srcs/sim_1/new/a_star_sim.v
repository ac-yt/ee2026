`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.03.2026 01:38:44
// Design Name: 
// Module Name: a_star_sim
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




// Testbench
module tb_top_with_astar;
    reg basys_clk = 0;
    wire [15:0] led;
    integer i;
    

    // Instantiate wrapper
    top_with_astar uut (
        .basys_clk(basys_clk),
        .led(led)
    );

    // Clock generation
    always #5 basys_clk = ~basys_clk;
    
    initial begin
        $monitor("t=%0t state=%b path_valid=%b saved=%b path_idx=%d path_len=%b flat_x=%h flat_y=%h, path_lenl=%b flat_xl=%h flat_yl=%h, path_x=%h, path_y=%h",
            $time, uut.a_star_inst.state, uut.path_valid, uut.path_saved, uut.path_index,
            uut.path_len, uut.path_flat_x[23:0], uut.path_flat_y[23:0],
            uut.path_len_loc, uut.path_flat_x_loc[23:0], uut.path_flat_y_loc[23:0], uut.path_x[0:15], uut.path_y[0:15]);//, uut.init_index_i);
    end


    initial begin
        $display("=== Starting testbench ===");

        // Run long enough for solver to finish
        #10000000;

        $display("Latched path_len_loc = %0d", uut.path_len_loc);
        $display("Latched path_cost_loc = %0d", uut.path_cost_loc);

        $display("Path coordinates:");
        for (i = 0; i < uut.path_len_loc; i = i+1) begin
            $display("Step %0d: (%0d,%0d)",
                i,
                uut.path_x[i],
                uut.path_y[i]
            );
        end
        
        

        $stop;
    end
endmodule
