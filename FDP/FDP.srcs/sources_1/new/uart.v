`timescale 1ns / 1ps

// https://www.analog.com/en/resources/analog-dialogue/articles/uart-a-hardware-communication-protocol.html
// https://medium.com/@aishwaryasuryawanshi2021/building-a-uart-communication-system-from-scratch-a-deep-dive-into-serial-communication-25d903f43bb7
// data format : 8N1 (8 data bits, no parity, 1 stop bit)

`include "constants.vh"

module uart_tx (input clk, rst, tx_en,
                input [`DATA_BITS-1:0] data,
                output reg tx=1'b1, busy=1'b0);
    // for a baud rate of BAUD_RATE, number of cycles per baud tick is
    parameter integer DIV = `CLOCK_SPEED / `BAUD_RATE;
    
    // state machine states
    parameter WAIT = 1'b0;
    parameter TRANSMIT = 1'b1;
    reg state = WAIT;
    reg next_state = WAIT;
    
    parameter integer TOTAL_BITS = `DATA_BITS + 2;
    parameter integer COUNTER_BITS = $clog2(DIV);
    parameter integer INDEX_BITS = $clog2(TOTAL_BITS);
    reg [COUNTER_BITS-1:0] counter = 0; // increments after each baud tick
    reg [TOTAL_BITS-1:0] packet = 0;
    reg [INDEX_BITS-1:0] bit_index = 0;
    
    always @ (*) begin
        case (state)
            WAIT: next_state = (!busy && tx_en) ? TRANSMIT : WAIT;
            TRANSMIT: if (busy && counter == DIV-1) next_state = (bit_index == TOTAL_BITS) ? WAIT : TRANSMIT;
        endcase
    end
    
//    always @ (posedge clk) begin
//        if (rst) state <= WAIT;
//        else begin
//            case (state)
//                WAIT: state <= (!busy && tx_en) ? TRANSMIT : WAIT;
//                TRANSMIT: begin
//                    if (busy && counter == DIV-1) state <= (bit_index == TOTAL_BITS) ? WAIT : TRANSMIT;
//                end
//            endcase
//        end
//    end
    
    always @ (posedge clk, posedge rst) begin
        if (rst) begin
            state <= WAIT;
            
            tx <= 1'b1;
            busy <= 1'b0;
            bit_index <= 0;
            counter <= 0;
            packet <= 0;
        end
        else begin
            state <= next_state;
            
            case (state)
                WAIT: begin
                    tx <= 1'b1;
                    busy <= 1'b0;
                    bit_index <= 0;
                    counter <= 0;
                    packet <= 0;
                end
                TRANSMIT: begin
                    if (!busy) begin
                        // first loop
                        packet <= {1'b1, data, 1'b0}; // stop, start, stop
                        busy <= 1'b1;
                        bit_index <= 0;
                        counter <= 0;
                    end
                    else begin
                        if (counter == DIV-1) begin
                            // one baud tick
                            counter <= 0;
                            tx <= packet[bit_index];
                            bit_index <= bit_index + 1;
                        end
                        else counter <= counter + 1;
                    end
                end
            endcase
        end
    end
endmodule

module uart_rx (input clk, rst, rx,
                output reg [`DATA_BITS-1:0] data=0,
                output reg busy=1'b0,
                output reg valid=1'b0);
    // for a baud rate of BAUD_RATE, number of cycles per baud tick is
    parameter integer DIV = `CLOCK_SPEED / `BAUD_RATE;
    
    // state machine states
    parameter WAIT = 2'b00;
    parameter RECEIVE = 2'b01;
    parameter EXPORT = 2'b10;
    reg [1:0] state = WAIT;
    reg [1:0] next_state = WAIT;
    
    parameter integer TOTAL_BITS = `DATA_BITS + 2;
    parameter integer COUNTER_BITS = $clog2(DIV);
    parameter integer INDEX_BITS = $clog2(TOTAL_BITS);
    reg [COUNTER_BITS:0] counter = 0; // increments after each baud tick
    reg [`DATA_BITS:0] packet = 0;
    reg [INDEX_BITS-1:0] bit_index = 0;
    
    always @ (*) begin
        case (state)
            WAIT: next_state = (rx == 0) ? RECEIVE : WAIT;
            RECEIVE: if (busy && counter == DIV-1) next_state = (bit_index == `DATA_BITS+1) ? EXPORT: RECEIVE;
            EXPORT: next_state = WAIT;
        endcase
    end
    
//    always @ (posedge clk) begin
//        case (state)
//            WAIT: state <= (rx == 0) ? RECEIVE : WAIT;
//            RECEIVE: begin
//                if (busy && counter == DIV-1) state <= (bit_index == `DATA_BITS+1) ? EXPORT : RECEIVE;
//            end
//            EXPORT: state <= WAIT;
//        endcase
//    end
    
    always @ (posedge clk, posedge rst) begin
        if (rst) begin
            state <= WAIT;
            
            busy <= 0;
            bit_index <= 0;
            counter <= 0;
            packet <= 0;
            valid <= 0;
        end
        else begin
            state <= next_state;

            case (state)
                WAIT: begin
                    busy <= 0;
                    bit_index <= 0;
                    counter <= 0;
                    packet <= 0;
                    valid <= 0;
                end
                RECEIVE: begin
                    if (!busy) begin
                        // first loop
                        if (counter == DIV/2) begin // sample in the middle of the bit
                            busy <= 1;
                            counter <= 0;
                        end
                        else counter <= counter + 1;
                    end
                    else begin
                        if (counter == DIV-1) begin
                            counter <= 0;
                            packet[bit_index] <= rx;
                            bit_index <= bit_index + 1;
                        end
                        else counter <= counter + 1;
                    end
                end
                EXPORT: begin
                    busy <= 0;
                    if (packet[`DATA_BITS] == 1'b1) begin
                        data <= packet[`DATA_BITS-1:0];
                        valid <= 1'b1;
                    end
                    else valid <= 1'b0;
                end
            endcase
        end
    end
endmodule