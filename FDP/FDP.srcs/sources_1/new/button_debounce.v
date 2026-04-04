`timescale 1ns / 1ps

module debounce (input clk, btn_in, output reg btn_out);
    parameter integer DEBOUNCE_COUNT = (`CLOCK_SPEED / 1000) * 200;

    reg btn_sync_0 = 0;
    reg btn_sync_1 = 0;
    
    always @(posedge clk) begin
        btn_sync_0 <= btn_in;
        btn_sync_1 <= btn_sync_0;
    end
    
    wire btn_raw = btn_sync_1;
    
    reg [$clog2(DEBOUNCE_COUNT):0] counter = 0;
    reg debounce_active = 0;
    reg debounced_state = 0;   // stable debounced level

    always @(posedge clk) begin
        btn_out <= 0; // default

        if (debounce_active) begin
            if (counter < DEBOUNCE_COUNT) counter <= counter + 1;
            else begin
                debounce_active <= 0;
                counter <= 0;
            end
        end
        else if (btn_raw != debounced_state) begin
            debounced_state <= btn_raw;
            debounce_active <= 1;
            
            if (btn_raw == 1) btn_out <= 1;
        end
    end
endmodule
