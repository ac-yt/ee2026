`timescale 1ns / 1ps

module variable_clock #(parameter CLOCK_SPEED=100_000_000, OUT_SPEED=1)
                            (input clk,
                             output reg clk_out=0); 
    
    localparam integer M = CLOCK_SPEED / (2 * OUT_SPEED) - 1;
    reg [31:0] count = 0;
    
    always @ (posedge clk) begin
        count <= (count == M) ? 0 : count + 1;
        clk_out <= (count == 0) ? ~clk_out : clk_out;
    end
endmodule

//module variable_clock(input basys_clk, input [31:0] m,
//                      output reg clk_out = 0); 
//    reg [31:0] count = 0;
//    always @ (posedge basys_clk) begin
//        count <= (count == m) ? 0 : count + 1;
//        clk_out <= (count == 0) ? ~clk_out : clk_out;
//    end
//endmodule