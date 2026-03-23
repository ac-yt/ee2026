`timescale 1ns / 1ps

`include "constants.vh"

module package_game_data (input clk, btnL, btnR, btnC, btnU, btnD, player, 
                          input [7:0] sw,
                          output reg tx_en,
                          output reg [`GAME_BITS-1:0] data_tx_game=0);
                          
    wire [4:0] btns = {btnL, btnD, btnC, btnU, btnR};
    reg [4:0] prev_btns = 0;
    reg [7:0] prev_sw = 0;
    
    //    wire deb_btnU, deb_btnD, deb_btnL, deb_btnR, deb_btnC;
    //    wire [4:0] btns = {deb_btnL, deb_btnD, deb_btnC, deb_btnU, deb_btnR};
    //    wire clean_btnU = btnU;
    //    wire clean_btnD = btnD;
    //    wire clean_btnL = btnL;
    //    wire clean_btnR = btnR;
    //    wire clean_btnC = btnC;
    //    debounce #(.MILLISECONDS(DEBOUNCE_MS), .CLOCK_SPEED(CLOCK_SPEED)) dbU (.clk(basys_clk), .btn_in(btnU), .btn_out(deb_btnU));
    //    debounce #(.MILLISECONDS(DEBOUNCE_MS), .CLOCK_SPEED(CLOCK_SPEED)) dbD (.clk(basys_clk), .btn_in(btnD), .btn_out(deb_btnD));
    //    debounce #(.MILLISECONDS(DEBOUNCE_MS), .CLOCK_SPEED(CLOCK_SPEED)) dbL (.clk(basys_clk), .btn_in(btnL), .btn_out(deb_btnL));
    //    debounce #(.MILLISECONDS(DEBOUNCE_MS), .CLOCK_SPEED(CLOCK_SPEED)) dbR (.clk(basys_clk), .btn_in(btnR), .btn_out(deb_btnR));
    //    debounce #(.MILLISECONDS(DEBOUNCE_MS), .CLOCK_SPEED(CLOCK_SPEED)) dbC (.clk(basys_clk), .btn_in(btnC), .btn_out(deb_btnC));
    
    always @ (posedge clk) begin
        tx_en <= 1'b0;
        if (player == `PLAYER_2) begin
            if (btns != prev_btns) begin
                tx_en <= 1'b1;
                data_tx_game <= btns; // header + 5 bits
                prev_btns <= btns;
            end
        end
        else begin
            if (sw != prev_sw) begin
                tx_en <= 1'b1;
                data_tx_game <= sw;
                prev_sw <= sw;
            end
        end
    end   
endmodule

module pairing_fsm (input clk, received, busy_tx, btn_accept, btn_cancel, btn_pair_one, btn_pair_two,
                    input [`CODE_BITS-1:0] data_rx_code,
                    output reg tx_en=0,
                    output reg [`CODE_BITS-1:0] data_tx_code=0,
                    output reg [2:0] state=0,
                    output reg player=0);

    reg [2:0] next_state = 0;
    
    parameter REQ_CODE = 8'hAA;
    parameter ACK_CODE = 8'hBB;
    parameter CONFIRM_CODE = 8'hCC;
    parameter CANCEL_CODE = 8'hDD;
    parameter HEARTBEAT_CODE = 8'hEE;
    reg ack_accepted = 1'b0;
    reg cancel_pair = 1'b0;
    
    parameter PAIR_TIME = 3 * `CLOCK_SPEED;
    parameter HB_INTERVAL = `CLOCK_SPEED / 10; // change this
    parameter HB_TIMEOUT = (`CLOCK_SPEED / 10) * 5;
    reg [$clog2(HB_INTERVAL)-1:0] hb_tx_counter = 0;
    reg [$clog2(HB_TIMEOUT)-1:0] hb_rx_counter = 0;
    reg [$clog2(PAIR_TIME)-1:0] pair_counter = 0;
    
    always @ (*) begin
        next_state = state;
        if (received && data_rx_code == CANCEL_CODE) next_state = `SINGLE;
        else begin
            case (state)
                `SINGLE: begin
                    if (pair_counter >= PAIR_TIME - 1) next_state = `REQUEST;
                    else if (received && data_rx_code == REQ_CODE) next_state = `ACKNOWLEDGE;
                end
                `REQUEST: if (!busy_tx) next_state = `WAIT_ACK;
                `WAIT_ACK: begin
                    if ((btn_cancel | cancel_pair) && !busy_tx) next_state = `SINGLE;
                    if (received) begin
                        if (data_rx_code == CANCEL_CODE) next_state = `SINGLE;
                        else if (data_rx_code == ACK_CODE) next_state = `CONFIRM;
                    end
                end
                `CONFIRM: if (!busy_tx) next_state = `PAIRED;
                `ACKNOWLEDGE: begin
                    if (!busy_tx) begin
                        if (btn_cancel | cancel_pair) next_state = `SINGLE;
                        else if (btn_accept | ack_accepted) next_state = `WAIT_CONFIRM;
                    end
                end
                `WAIT_CONFIRM: if (received && data_rx_code == CONFIRM_CODE) next_state = `PAIRED;
                `PAIRED: begin
                    if ((hb_rx_counter >= HB_TIMEOUT - 1) ||
                        (!busy_tx && cancel_pair)) next_state = `SINGLE;
                end
                default: next_state = `SINGLE;
            endcase
        end
    end
    
    always @ (posedge clk) begin
        tx_en <= 1'b0;
//        if (received && data_rx_code == CANCEL_CODE) state <= `SINGLE; // reset
        state <= next_state;

        case (state)
            `SINGLE: begin
                hb_tx_counter <= 0;
                hb_rx_counter <= 0;
                ack_accepted <= 0;
                cancel_pair <= 0;
                player <= `PLAYER_1;
                
                // pairing
                if (btn_pair_one & btn_pair_two) begin
//                    pair_counter <= pair_counter + 1;
                    pair_counter <= (pair_counter >= PAIR_TIME-1) ? 0 : pair_counter + 1;
                end
                else pair_counter <= 0;
                
//                if (pair_counter >= PAIR_TIME - 1) begin
//                    pair_counter <= 0;
//                    state <= `REQUEST;
//                end
//                else if (received && data_rx_code == REQ_CODE) state <= `ACKNOWLEDGE;
            end
            `REQUEST: begin
                player <= `PLAYER_2;
                if (!busy_tx) begin
                    data_tx_code <= REQ_CODE;
                    tx_en <= 1'b1;
//                    state <= `WAIT_ACK;
                end
            end
            `WAIT_ACK: begin
                if (btn_cancel) cancel_pair <= 1'b1;
                
                if ((btn_cancel | cancel_pair) && !busy_tx) begin
                    data_tx_code <= CANCEL_CODE;
                    tx_en   <= 1'b1;
//                    state <= `SINGLE;
                end
                
//                if (received) begin
//                    if (data_rx_code == CANCEL_CODE) state <= `SINGLE;
//                    else if (data_rx_code == ACK_CODE) state <= `CONFIRM;
//                end
            end
            `CONFIRM: begin
                if (!busy_tx) begin
                    data_tx_code <= CONFIRM_CODE;
                    tx_en <= 1'b1;
//                    state <= `PAIRED;
                end
            end
            `ACKNOWLEDGE: begin
                if (btn_cancel) cancel_pair <= 1'b1;
                else if (btn_accept) ack_accepted <= 1'b1;
                
                if (!busy_tx) begin
                    if (btn_cancel | cancel_pair) begin
                        data_tx_code <= CANCEL_CODE;
                        tx_en   <= 1'b1;
//                        state <= `SINGLE;
                    end
                    else 
                    if (btn_accept | ack_accepted) begin
                        data_tx_code <= ACK_CODE;
                        tx_en <= 1'b1;
//                        state <= `WAIT_CONFIRM;
                    end
                end
                
//                if (received && data_rx_code == CANCEL_CODE) state <= `SINGLE;
            end
//            `WAIT_CONFIRM: begin
//                if (received && data_rx_code == CONFIRM_CODE) begin
//                    state <= `PAIRED;
//                end
//            end
            `PAIRED: begin
                if (hb_tx_counter == HB_INTERVAL - 1) begin
                    hb_tx_counter <= 0;
                    if (!busy_tx) begin
                        data_tx_code <= HEARTBEAT_CODE;
                        tx_en   <= 1'b1;
                    end
                end else hb_tx_counter <= hb_tx_counter + 1;
                
                if (received && data_rx_code == HEARTBEAT_CODE) hb_rx_counter <= 0;
                else hb_rx_counter <= hb_rx_counter + 1;
        
//                if (hb_rx_counter >= HB_TIMEOUT - 1) state <= `SINGLE;
                
                // unpairing
                if (btn_pair_one & btn_pair_two) pair_counter <= pair_counter + 1;
                else pair_counter <= 0;
                        
                if (pair_counter >= PAIR_TIME - 1) begin
                    pair_counter <= 0;
                    cancel_pair <= 1'b1;
                end
                
                if (!busy_tx) begin
                    if (cancel_pair) begin
                        data_tx_code <= CANCEL_CODE;
                        tx_en   <= 1'b1;
//                        state <= `SINGLE;
                    end
                end
            end
        endcase
        
//        paired <= (pair_state == PAIRED) ? 1 : 0;
    end
endmodule

module pairing_oled(
    input clk,
    input [2:0] pair_state,
    input [6:0] x, input [5:0] y,
    output reg [15:0] oled_data
);
    
    parameter CHAR_WIDTH  = 5;
    parameter CHAR_HEIGHT = 7;
    
    reg [CHAR_WIDTH-1:0] font_rom [0:127][0:CHAR_HEIGHT-1];
    initial begin
        // SPACE
        font_rom[" "][0] = 5'b00000;
        font_rom[" "][1] = 5'b00000;
        font_rom[" "][2] = 5'b00000; 
        font_rom[" "][3] = 5'b00000;
        font_rom[" "][4] = 5'b00000; 
        font_rom[" "][5] = 5'b00000;
        font_rom[" "][6] = 5'b00000;
    
        // A
        font_rom["A"][0] = 5'b01110; 
        font_rom["A"][1] = 5'b10001;
        font_rom["A"][2] = 5'b10001; 
        font_rom["A"][3] = 5'b11111; 
        font_rom["A"][4] = 5'b10001; 
        font_rom["A"][5] = 5'b10001;
        font_rom["A"][6] = 5'b10001;
        
        // B
        font_rom["B"][0] = 5'b11110; 
        font_rom["B"][1] = 5'b10001;
        font_rom["B"][2] = 5'b10001; 
        font_rom["B"][3] = 5'b11110;
        font_rom["B"][4] = 5'b10001; 
        font_rom["B"][5] = 5'b10001;
        font_rom["B"][6] = 5'b11110;
    
        // C
        font_rom["C"][0] = 5'b01110; 
        font_rom["C"][1] = 5'b10001;
        font_rom["C"][2] = 5'b10000; 
        font_rom["C"][3] = 5'b10000;
        font_rom["C"][4] = 5'b10000; 
        font_rom["C"][5] = 5'b10001;
        font_rom["C"][6] = 5'b01110;
    
        // D
        font_rom["D"][0] = 5'b11100; 
        font_rom["D"][1] = 5'b10010;
        font_rom["D"][2] = 5'b10001; 
        font_rom["D"][3] = 5'b10001;
        font_rom["D"][4] = 5'b10001; 
        font_rom["D"][5] = 5'b10010;
        font_rom["D"][6] = 5'b11100;
    
        // E
        font_rom["E"][0] = 5'b11111;
        font_rom["E"][1] = 5'b10000;
        font_rom["E"][2] = 5'b10000;
        font_rom["E"][3] = 5'b11111;
        font_rom["E"][4] = 5'b10000;
        font_rom["E"][5] = 5'b10000;
        font_rom["E"][6] = 5'b11111;
        
        // F
        font_rom["F"][0] = 5'b11111;
        font_rom["F"][1] = 5'b10000;
        font_rom["F"][2] = 5'b10000;
        font_rom["F"][3] = 5'b11111;
        font_rom["F"][4] = 5'b10000;
        font_rom["F"][5] = 5'b10000;
        font_rom["F"][6] = 5'b10000;
    
        // G
        font_rom["G"][0] = 5'b01110;
        font_rom["G"][1] = 5'b10001;
        font_rom["G"][2] = 5'b10000;
        font_rom["G"][3] = 5'b10110;
        font_rom["G"][4] = 5'b10001; 
        font_rom["G"][5] = 5'b10001;
        font_rom["G"][6] = 5'b01110;
        
        // H
        font_rom["H"][0] = 5'b10001;
        font_rom["H"][1] = 5'b10001;
        font_rom["H"][2] = 5'b10001;
        font_rom["H"][3] = 5'b11111;
        font_rom["H"][4] = 5'b10001; 
        font_rom["H"][5] = 5'b10001;
        font_rom["H"][6] = 5'b10001;
    
        // I
        font_rom["I"][0] = 5'b11111;
        font_rom["I"][1] = 5'b00100;
        font_rom["I"][2] = 5'b00100;
        font_rom["I"][3] = 5'b00100;
        font_rom["I"][4] = 5'b00100;
        font_rom["I"][5] = 5'b00100;
        font_rom["I"][6] = 5'b11111;
        
        // J
        font_rom["J"][0] = 5'b00001;
        font_rom["J"][1] = 5'b00001;
        font_rom["J"][2] = 5'b00001;
        font_rom["J"][3] = 5'b00001;
        font_rom["J"][4] = 5'b10001;
        font_rom["J"][5] = 5'b10001;
        font_rom["J"][6] = 5'b01110;
        
        // K
        font_rom["K"][0] = 5'b10001; 
        font_rom["K"][1] = 5'b10010;
        font_rom["K"][2] = 5'b10100; 
        font_rom["K"][3] = 5'b11000;
        font_rom["K"][4] = 5'b10100; 
        font_rom["K"][5] = 5'b10010;
        font_rom["K"][6] = 5'b10001;
    
        // L
        font_rom["L"][0] = 5'b10000; 
        font_rom["L"][1] = 5'b10000;
        font_rom["L"][2] = 5'b10000; 
        font_rom["L"][3] = 5'b10000;
        font_rom["L"][4] = 5'b10000; 
        font_rom["L"][5] = 5'b10000;
        font_rom["L"][6] = 5'b11111;
        
        // M
        font_rom["M"][0] = 5'b01010; 
        font_rom["M"][1] = 5'b10101;
        font_rom["M"][2] = 5'b10101; 
        font_rom["M"][3] = 5'b10001;
        font_rom["M"][4] = 5'b10001; 
        font_rom["M"][5] = 5'b10001;
        font_rom["M"][6] = 5'b10001;
    
        // N
        font_rom["N"][0] = 5'b10001; 
        font_rom["N"][1] = 5'b11001;
        font_rom["N"][2] = 5'b11001; 
        font_rom["N"][3] = 5'b10101;
        font_rom["N"][4] = 5'b10011; 
        font_rom["N"][5] = 5'b10011;
        font_rom["N"][6] = 5'b10001;
        
        // O
        font_rom["O"][0] = 5'b01110; 
        font_rom["O"][1] = 5'b10001;
        font_rom["O"][2] = 5'b10001; 
        font_rom["O"][3] = 5'b10001;
        font_rom["O"][4] = 5'b10001; 
        font_rom["O"][5] = 5'b10001;
        font_rom["O"][6] = 5'b01110;

        // P
        font_rom["P"][0] = 5'b11110; 
        font_rom["P"][1] = 5'b10001;
        font_rom["P"][2] = 5'b10001; 
        font_rom["P"][3] = 5'b11110;
        font_rom["P"][4] = 5'b10000; 
        font_rom["P"][5] = 5'b10000;
        font_rom["P"][6] = 5'b10000;
    
        // Q
        font_rom["Q"][0] = 5'b01110; 
        font_rom["Q"][1] = 5'b10001;
        font_rom["Q"][2] = 5'b10001; 
        font_rom["Q"][3] = 5'b10001;
        font_rom["Q"][4] = 5'b10101; 
        font_rom["Q"][5] = 5'b10010;
        font_rom["Q"][6] = 5'b01101;
    
        // R
        font_rom["R"][0] = 5'b11110; 
        font_rom["R"][1] = 5'b10001;
        font_rom["R"][2] = 5'b10001; 
        font_rom["R"][3] = 5'b11110;
        font_rom["R"][4] = 5'b10010; 
        font_rom["R"][5] = 5'b10001;
        font_rom["R"][6] = 5'b10001;
    
        // S
        font_rom["S"][0] = 5'b01111; 
        font_rom["S"][1] = 5'b10000;
        font_rom["S"][2] = 5'b10000; 
        font_rom["S"][3] = 5'b01110;
        font_rom["S"][4] = 5'b00001; 
        font_rom["S"][5] = 5'b00001;
        font_rom["S"][6] = 5'b11110;
    
        // T
        font_rom["T"][0] = 5'b11111; 
        font_rom["T"][1] = 5'b00100;
        font_rom["T"][2] = 5'b00100; 
        font_rom["T"][3] = 5'b00100;
        font_rom["T"][4] = 5'b00100; 
        font_rom["T"][5] = 5'b00100;
        font_rom["T"][6] = 5'b00100;
    
        // U
        font_rom["U"][0] = 5'b10001; 
        font_rom["U"][1] = 5'b10001;
        font_rom["U"][2] = 5'b10001; 
        font_rom["U"][3] = 5'b10001;
        font_rom["U"][4] = 5'b10001; 
        font_rom["U"][5] = 5'b10001;
        font_rom["U"][6] = 5'b01110;
    
        // V
        font_rom["V"][0] = 5'b10001; 
        font_rom["V"][1] = 5'b10001;
        font_rom["V"][2] = 5'b10001; 
        font_rom["V"][3] = 5'b10001;
        font_rom["V"][4] = 5'b10001; 
        font_rom["V"][5] = 5'b01010;
        font_rom["V"][6] = 5'b00100;
    
        // W
        font_rom["W"][0] = 5'b10001; 
        font_rom["W"][1] = 5'b10001;
        font_rom["W"][2] = 5'b10001; 
        font_rom["W"][3] = 5'b10001;
        font_rom["W"][4] = 5'b10101; 
        font_rom["W"][5] = 5'b10101;
        font_rom["W"][6] = 5'b01010;
        
        // X
        font_rom["X"][0] = 5'b10001; 
        font_rom["X"][1] = 5'b10001;
        font_rom["X"][2] = 5'b01010; 
        font_rom["X"][3] = 5'b00100;
        font_rom["X"][4] = 5'b01010; 
        font_rom["X"][5] = 5'b10001;
        font_rom["X"][6] = 5'b10001;
        
        // Y
        font_rom["Y"][0] = 5'b10001; 
        font_rom["Y"][1] = 5'b10001;
        font_rom["Y"][2] = 5'b01010; 
        font_rom["Y"][3] = 5'b00100;
        font_rom["Y"][4] = 5'b00100; 
        font_rom["Y"][5] = 5'b00100;
        font_rom["Y"][6] = 5'b00100;
        
        // Z
        font_rom["Z"][0] = 5'b11111; 
        font_rom["Z"][1] = 5'b00001;
        font_rom["Z"][2] = 5'b00010; 
        font_rom["Z"][3] = 5'b00100;
        font_rom["Z"][4] = 5'b01000; 
        font_rom["Z"][5] = 5'b10000;
        font_rom["Z"][6] = 5'b11111;
        
        // ?
        font_rom["?"][0] = 5'b01110; 
        font_rom["?"][1] = 5'b10001;
        font_rom["?"][2] = 5'b00010; 
        font_rom["?"][3] = 5'b00100;
        font_rom["?"][4] = 5'b00100; 
        font_rom["?"][5] = 5'b00000;
        font_rom["?"][6] = 5'b00100;
        
        // [
        font_rom["["][0] = 5'b01110; 
        font_rom["["][1] = 5'b01000;
        font_rom["["][2] = 5'b01000; 
        font_rom["["][3] = 5'b01000;
        font_rom["["][4] = 5'b01000; 
        font_rom["["][5] = 5'b01000;
        font_rom["["][6] = 5'b01110;
        
        // ]
        font_rom["]"][0] = 5'b01110; 
        font_rom["]"][1] = 5'b00010;
        font_rom["]"][2] = 5'b00010; 
        font_rom["]"][3] = 5'b00010;
        font_rom["]"][4] = 5'b00010; 
        font_rom["]"][5] = 5'b00010;
        font_rom["]"][6] = 5'b01110;
    end
   
    always @ (posedge clk) begin
        oled_data <= 16'h0000;
        
        case (pair_state)
            `SINGLE: begin        
                if (draw_letter(x, y, 47-6*6, 31-8, "S") ||
                    draw_letter(x, y, 47-6*5, 31-8, "I") ||
                    draw_letter(x, y, 47-6*4, 31-8, "N") ||
                    draw_letter(x, y, 47-6*3, 31-8, "G") ||
                    draw_letter(x, y, 47-6*2, 31-8, "L") ||
                    draw_letter(x, y, 47-6, 31-8, "E") ||
                    draw_letter(x, y, 47, 31-8, " ") ||
                    draw_letter(x, y, 47+6, 31-8, "P") ||
                    draw_letter(x, y, 47+6*2, 31-8, "L") ||
                    draw_letter(x, y, 47+6*3, 31-8, "A") ||
                    draw_letter(x, y, 47+6*4, 31-8, "Y") ||
                    draw_letter(x, y, 47+6*5, 31-8, "E") ||
                    draw_letter(x, y, 47+6*6, 31-8, "R")) oled_data <= `OLED_WHITE;
                    
                if (draw_letter(x, y, 47-6*5, 31+4, "H") ||
                    draw_letter(x, y, 47-6*4, 31+4, "O") ||
                    draw_letter(x, y, 47-6*3, 31+4, "L") ||
                    draw_letter(x, y, 47-6*2, 31+4, "D") ||
                    draw_letter(x, y, 47-6, 31+4, " ") ||
                    draw_letter(x, y, 47, 31+4, "[") ||
                    draw_letter(x, y, 47+6, 31+4, "L") ||
                    draw_letter(x, y, 47+6*2, 31+4, "]") ||
                    draw_letter(x, y, 47+6*3, 31+4, "[") ||
                    draw_letter(x, y, 47+6*4, 31+4, "R") ||
                    draw_letter(x, y, 47+6*5, 31+4, "]")) oled_data <= `OLED_GREY;
                
                if (draw_letter(x, y, 47-6*3, 31+14, "T") ||
                    draw_letter(x, y, 47-6*2, 31+14, "O") ||
                    draw_letter(x, y, 47-6, 31+14, " ") ||
                    draw_letter(x, y, 47, 31+14, "P") ||
                    draw_letter(x, y, 47+6, 31+14, "A") ||
                    draw_letter(x, y, 47+6*2, 31+14, "I") ||
                    draw_letter(x, y, 47+6*3, 31+14, "R")) oled_data <= `OLED_GREY;
            end
            `PAIRED: begin
                if (draw_letter(x, y, 47-3-6*2, 31-8, "P") ||
                    draw_letter(x, y, 47-3-6, 31-8, "A") ||
                    draw_letter(x, y, 47-3, 31-8, "I") ||
                    draw_letter(x, y, 47+3, 31-8, "R") ||
                    draw_letter(x, y, 47+3+6, 31-8, "E") ||
                    draw_letter(x, y, 47+3+6*2, 31-8, "D")) oled_data <= `OLED_WHITE;
                
                if (draw_letter(x, y, 47-6*5, 31+4, "H") ||
                    draw_letter(x, y, 47-6*4, 31+4, "O") ||
                    draw_letter(x, y, 47-6*3, 31+4, "L") ||
                    draw_letter(x, y, 47-6*2, 31+4, "D") ||
                    draw_letter(x, y, 47-6, 31+4, " ") ||
                    draw_letter(x, y, 47, 31+4, "[") ||
                    draw_letter(x, y, 47+6, 31+4, "L") ||
                    draw_letter(x, y, 47+6*2, 31+4, "]") ||
                    draw_letter(x, y, 47+6*3, 31+4, "[") ||
                    draw_letter(x, y, 47+6*4, 31+4, "R") ||
                    draw_letter(x, y, 47+6*5, 31+4, "]")) oled_data <= `OLED_GREY;
                
                if (draw_letter(x, y, 47-6*4, 31+14, "T") ||
                    draw_letter(x, y, 47-6*3, 31+14, "O") ||
                    draw_letter(x, y, 47-6*2, 31+14, " ") ||
                    draw_letter(x, y, 47-6, 31+14, "U") ||
                    draw_letter(x, y, 47, 31+14, "N") ||
                    draw_letter(x, y, 47+6, 31+14, "P") ||
                    draw_letter(x, y, 47+6*2, 31+14, "A") ||
                    draw_letter(x, y, 47+6*3, 31+14, "I") ||
                    draw_letter(x, y, 47+6*4, 31+14, "R")) oled_data <= `OLED_GREY;
            end
            `WAIT_ACK: begin            
                if (draw_letter(x, y, 47-3-6*5, 31-6, "R") ||
                    draw_letter(x, y, 47-3-6*4, 31-6, "E") ||
                    draw_letter(x, y, 47-3-6*3, 31-6, "Q") ||
                    draw_letter(x, y, 47-3-6*2, 31-6, "U") ||
                    draw_letter(x, y, 47-3-6, 31-6, "E") ||
                    draw_letter(x, y, 47-3, 31-6, "S") ||
                    draw_letter(x, y, 47+3, 31-6, "T") ||
                    draw_letter(x, y, 47+3+6, 31-6, " ") ||
                    draw_letter(x, y, 47+3+6*2, 31-6, "S") ||
                    draw_letter(x, y, 47+3+6*3, 31-6, "E") ||
                    draw_letter(x, y, 47+3+6*4, 31-6, "N") ||
                    draw_letter(x, y, 47+3+6*5, 31-6, "T")) oled_data <= `OLED_WHITE;
                
                if (draw_letter(x, y, 47-6*6, 31+6, "[") ||
                    draw_letter(x, y, 47-6*5, 31+6, "D") ||
                    draw_letter(x, y, 47-6*4, 31+6, "]") ||
                    draw_letter(x, y, 47-6*3, 31+6, " ") ||
                    draw_letter(x, y, 47-6*2, 31+6, "T") ||
                    draw_letter(x, y, 47-6, 31+6, "O") ||
                    draw_letter(x, y, 47, 31+6, " ") ||
                    draw_letter(x, y, 47+6, 31+6, "C") ||
                    draw_letter(x, y, 47+6*2, 31+6, "A") ||
                    draw_letter(x, y, 47+6*3, 31+6, "N") ||
                    draw_letter(x, y, 47+6*4, 31+6, "C") ||
                    draw_letter(x, y, 47+6*5, 31+6, "E") ||
                    draw_letter(x, y, 47+6*6, 31+6, "L")) oled_data <= `OLED_GREY;
            end
            `ACKNOWLEDGE: begin
                if (draw_letter(x, y, 47-3-6*7, 31-8, "R") ||
                    draw_letter(x, y, 47-3-6*6, 31-8, "E") ||
                    draw_letter(x, y, 47-3-6*5, 31-8, "Q") ||
                    draw_letter(x, y, 47-3-6*4, 31-8, "U") ||
                    draw_letter(x, y, 47-3-6*3, 31-8, "E") ||
                    draw_letter(x, y, 47-3-6*2, 31-8, "S") ||
                    draw_letter(x, y, 47-3-6, 31-8, "T") ||
                    draw_letter(x, y, 47-3, 31-8, " ") ||
                    draw_letter(x, y, 47+3, 31-8, "R") ||
                    draw_letter(x, y, 47+3+6, 31-8, "E") ||
                    draw_letter(x, y, 47+3+6*2, 31-8, "C") ||
                    draw_letter(x, y, 47+3+6*3, 31-8, "E") ||
                    draw_letter(x, y, 47+3+6*4, 31-8, "I") ||
                    draw_letter(x, y, 47+3+6*5, 31-8, "V") ||
                    draw_letter(x, y, 47+3+6*6, 31-8, "E") ||
                    draw_letter(x, y, 47+3+6*7, 31-8, "D")) oled_data <= `OLED_WHITE;
                
                if (draw_letter(x, y, 47-3-6*7, 31+4, "A") ||
                    draw_letter(x, y, 47-3-6*6, 31+4, "C") ||
                    draw_letter(x, y, 47-3-6*5, 31+4, "C") ||
                    draw_letter(x, y, 47-3-6*4, 31+4, "E") ||
                    draw_letter(x, y, 47-3-6*3, 31+4, "P") ||
                    draw_letter(x, y, 47-3-6*2, 31+4, "T") ||
                    draw_letter(x, y, 47-3-6, 31+4, "?") ||
                    draw_letter(x, y, 47-3, 31+4, " ") ||
                    draw_letter(x, y, 47+3, 31+4, " ")) oled_data <= `OLED_GREY;
                
                if (draw_letter(x, y, 47+3+6, 31+4, "[") ||
                    draw_letter(x, y, 47+3+6*2, 31+4, "U") ||
                    draw_letter(x, y, 47+3+6*3, 31+4, "]") ||
                    draw_letter(x, y, 47+3+6*4, 31+4, " ") ||
                    draw_letter(x, y, 47+3+6*5, 31+4, "Y") ||
                    draw_letter(x, y, 47+3+6*6, 31+4, "E") ||
                    draw_letter(x, y, 47+3+6*7, 31+4, "S")) oled_data <= `OLED_GREEN;
                
                if (draw_letter(x, y, 47+3+6, 31+14, "[") ||
                    draw_letter(x, y, 47+3+6*2, 31+14, "D") ||
                    draw_letter(x, y, 47+3+6*3, 31+14, "]") ||
                    draw_letter(x, y, 47+3+6*4, 31+14, " ") ||
                    draw_letter(x, y, 47+3+6*5, 31+14, "N") ||
                    draw_letter(x, y, 47+3+6*6, 31+14, "O")) oled_data <= `OLED_RED;
            end
        endcase
    end
    
    function draw_letter;
        input [6:0] x, y;
        input integer xc, yc;
        input [7:0] letter;
        integer row, col;
        begin
            draw_letter = 0;
            row = y - (yc - 3);
            col = x - (xc - 2);
            if (row >= 0 && row < CHAR_HEIGHT && col >= 0 && col < CHAR_WIDTH) begin
                draw_letter = font_rom[letter][row][CHAR_WIDTH-1-col];
            end
        end
    endfunction
endmodule
