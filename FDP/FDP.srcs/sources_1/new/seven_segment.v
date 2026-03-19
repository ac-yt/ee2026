`timescale 1ns / 1ps

module seven_segment(input clk,
                     input [7:0] seg0, seg1, seg2, seg3, // left to rightmost
                     output reg [7:0] seg,
                     output reg [3:0] an);
    
    parameter integer SWITCH_TIME = 0.01 * `CLOCK_SPEED;
    
    reg [$clog2(SWITCH_TIME)-1:0] seg_counter = 0;
    reg [1:0] an_select = 0;
    
    always @ (posedge clk) begin
        seg_counter <= seg_counter + 1;
        if (seg_counter == 100_000) begin
            seg_counter <= 0;
            an_select <= an_select + 1;
        end
        
        case (an_select)
            2'b00: begin
                an <= 4'b0111;
                seg <= seg0;
            end
            2'b01: begin
                an <= 4'b1011;
                seg <= seg1;
            end
            2'b10: begin
                an <= 4'b1101;
                seg <= seg2;
            end
            2'b11: begin
                an <= 4'b1110;
                seg <= seg3;
            end
        endcase
    end
endmodule

