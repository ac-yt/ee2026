`timescale 1ns / 1ps

module lfsr_rng(
    input clk,reset,
    output reg [15:0] rnd 
    );
    initial rnd = 16'hACE1;
    always @(posedge clk or posedge reset) begin
            if (reset)
                rnd <= 16'hACE1; // Seed value (cannot be 0)
            else
                // A 16-bit LFSR polynomial: x^16 + x^14 + x^13 + x^11 + 1
                rnd <= {rnd[14:0], rnd[15] ^ rnd[13] ^ rnd[12] ^ rnd[10]};
        end
    
endmodule