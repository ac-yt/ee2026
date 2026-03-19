`timescale 1ns/1ps

`include "constants.vh"

module tb_debounce;

    localparam CLOCK_SPEED   = 100_000_000; // 100 MHz
    localparam MILLISECONDS  = 10;          // debounce window
    localparam CLK_PERIOD    = 10;          // 100 MHz clock = 10 ns

    reg clk = 0;
    reg btn_in = 0;
    wire btn_out;

    // DUT
    debounce #(.MILLISECONDS(MILLISECONDS), .CLOCK_SPEED(CLOCK_SPEED)) uut (
        .clk(clk),
        .btn_in(btn_in),
        .btn_out(btn_out)
    );

    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // Stimulus
    initial begin
        btn_in = 0;
        #1_000_000; // wait 1 ms

        // Simulate noisy press (bounce for a few microseconds)
        btn_in = 1; #1_000;   // 1 us
        btn_in = 0; #500;     // 0.5 us
        btn_in = 1; #2_000;   // 2 us
        btn_in = 0; #1_000;   // 1 us
        btn_in = 1; #20_000_000; // hold stable high for 20 ms

        // Simulate noisy release
        btn_in = 0; #1_000;   // 1 us
        btn_in = 1; #500;     // 0.5 us
        btn_in = 0; #2_000;   // 2 us
        btn_in = 1; #1_000;   // 1 us
        btn_in = 0; #20_000_000; // hold stable low for 20 ms

        #10_000_000; // wait 10 ms
        $finish;
    end

endmodule



module tb_uart_loopback;

    localparam BAUD_RATE   = 38400;
    localparam CLOCK_SPEED = 100_000_000;
    localparam DATA_BITS   = 12;

    // Common signals
    reg clk;
    reg rst;
    reg tx_en;
    reg [`DATA_BITS-1:0] tx_data;
    wire tx;
    wire tx_busy;

    wire [`DATA_BITS-1:0] rx_data;
    wire rx_busy;
    wire rx_valid;

    // Instantiate TX
    uart_tx #(
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_SPEED(CLOCK_SPEED),
        .DATA_BITS(DATA_BITS)
    ) tx_inst (
        .clk(clk),
        .rst(rst),
        .tx_en(tx_en),
        .data(tx_data),
        .tx(tx),
        .busy(tx_busy)
    );

    // Instantiate RX (loopback: tx -> rx)
    uart_rx #(
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_SPEED(CLOCK_SPEED),
        .DATA_BITS(DATA_BITS)
    ) rx_inst (
        .clk(clk),
        .rst(rst),
        .rx(tx),          // loopback connection
        .data(rx_data),
        .busy(rx_busy),
        .valid(rx_valid)
    );

    // Clock generation: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk;

    integer i;

    // Stimulus
    initial begin
        // Reset
        rst = 1;
        tx_en = 0;
        tx_data = 0;
        #100;
        rst = 0;

        // Loop through all possible 8-bit values
        for (i = 0; i < 255; i = i + 1) begin
            // Send byte
//            if (i == 1) rst = 1;
//            else rst = 0;
            
            tx_data = i[7:0];
            tx_en   = 1;
            #10;
            tx_en   = 0;

            // Wait until RX valid
//            if (i != 1) 
            wait(rx_valid);
            if (rx_data !== tx_data) begin
                $display("ERROR: TX=%h RX=%h at time %t", tx_data, rx_data, $time);
            end else begin
                $display("PASS:  TX=%h RX=%h at time %t", tx_data, rx_data, $time);
            end

            // Small gap between frames
            #1000;
        end

        $display("All test cases complete.");
        #100000;
        $stop;
    end

endmodule
