`timescale 1ns / 1ps

`include "constants.vh"

module interface_fsm (input clk, btnL, btnR, btnC, btnU, btnD, [8:0] sw, [2:0] pair_state, player,
                      input [6:0] x, input [5:0] y,
                      output reg rst_game=0, game_active=0, send_pair_req=0, send_unpair_req=0,
                      output reg [15:0] oled_data=0,
                      output reg [2:0] state = 0);
    
    reg [2:0] next_state = `HOME;
    reg [2:0] prev_state = `HOME;

    // -------------------------------------------------------
    // CURSORS
    // home_cursor : 0 = SINGLE, 1 = MULTI
    // menu_cursor : 0 = HOME, 1 = RESUME, 2 = RESTART
    // wait_pair:    0 = HOME, 1 = PAIR/UNPAIR
    // -------------------------------------------------------
    parameter BUTTON_HOME_SINGLE = 0;
    parameter BUTTON_HOME_MULTI = 1;
    parameter BUTTON_MENU_BACK = 0;
    parameter BUTTON_MENU_RESUME = 1;
    parameter BUTTON_MENU_RESTART = 2;
    parameter BUTTON_PAIR_BACK = 0;
    parameter BUTTON_PAIR_START = 1;
    parameter BUTTON_PAIR_PAIR = 2;
//    parameter MENU_HOME    = 2'd0;
//    parameter MENU_RESUME  = 2'd1;
//    parameter MENU_RESTART = 2'd2;
//    parameter MENU_PAIR = 2'd1;
 
    reg home_cursor = BUTTON_HOME_SINGLE;
    reg next_home_cursor = BUTTON_HOME_SINGLE;
    reg [1:0] menu_cursor = BUTTON_MENU_RESUME;
    reg [1:0] next_menu_cursor = BUTTON_MENU_RESUME;
    reg [1:0] wait_pair_cursor = BUTTON_PAIR_BACK;
    reg [1:0] next_wait_pair_cursor = BUTTON_PAIR_BACK;
 
    // breadcrumb so RESUME/RESTART return to the right game mode
//    reg came_from_multi = 0;
//    reg next_came_from_multi = 0;
 
    // -------------------------------------------------------
    // BUTTON + SW[0] EDGE DETECTION
    // -------------------------------------------------------
    reg prev_sw0 = 0;
    wire pulse_sw0  = sw[0] & ~prev_sw0;
    
    wire pulse_btnL, pulse_btnR, pulse_btnC, pulse_btnU, pulse_btnD; // debounced buttons
    debounce dbL_inst (.clk(clk), .btn_in(btnL), .btn_out(pulse_btnL));
    debounce dbR_inst (.clk(clk), .btn_in(btnR), .btn_out(pulse_btnR));
    debounce dbC_inst (.clk(clk), .btn_in(btnC), .btn_out(pulse_btnC));
    debounce dbU_inst (.clk(clk), .btn_in(btnU), .btn_out(pulse_btnU));
    debounce dbD_inst (.clk(clk), .btn_in(btnD), .btn_out(pulse_btnD));
    
    // next state logic
    always @ (*) begin
        next_state = state;
        next_home_cursor = home_cursor;
        next_menu_cursor = menu_cursor;
        next_wait_pair_cursor = wait_pair_cursor;
 
        case (state)
            `HOME: begin // single and multi buttons
                if (pulse_btnL || pulse_btnR) next_home_cursor = ~home_cursor; // only two options, rollover toggle
 
                if (pulse_btnC) begin
                    next_menu_cursor = BUTTON_MENU_BACK; // set default menu button to be on RESUME
                    if (home_cursor == BUTTON_HOME_SINGLE) next_state = `SINGLE_HOME;
                    else next_state = `MULTI_WAIT_PAIR;
                end
            end
            `SINGLE_HOME: begin // same shared nav for single and multi
                if (pulse_btnU) begin
                    case (menu_cursor)
                        BUTTON_MENU_BACK: next_menu_cursor = BUTTON_MENU_RESTART;
                        BUTTON_MENU_RESUME: next_menu_cursor = BUTTON_MENU_BACK;
                        BUTTON_MENU_RESTART: next_menu_cursor = BUTTON_MENU_RESUME;
                        default: next_menu_cursor = BUTTON_MENU_BACK;
                    endcase
                end
 
                if (pulse_btnD) begin
                    case (menu_cursor)
                        BUTTON_MENU_BACK: next_menu_cursor = BUTTON_MENU_RESUME;
                        BUTTON_MENU_RESUME: next_menu_cursor = BUTTON_MENU_RESTART;
                        BUTTON_MENU_RESTART: next_menu_cursor = BUTTON_MENU_BACK;
                        default: next_menu_cursor = BUTTON_MENU_BACK;
                    endcase
                end
 
                if (pulse_btnC) begin
                    next_menu_cursor = BUTTON_MENU_BACK;
                    case (menu_cursor)
                        BUTTON_MENU_BACK: next_state = `HOME;
                        BUTTON_MENU_RESUME: next_state = `SINGLE_GAME;
                        BUTTON_MENU_RESTART: next_state = `SINGLE_GAME;
                        default: next_state = `HOME;
                    endcase
                end
            end
            `MULTI_WAIT_PAIR: begin // wait for pairing
//                if (pair_state == `PAIRED) next_state = `MULTI_HOME;
                
                if (pulse_btnU) begin
                    case (wait_pair_cursor)
                        BUTTON_PAIR_BACK: next_wait_pair_cursor = (pair_state == `PAIRED) ? BUTTON_PAIR_START : BUTTON_PAIR_PAIR;
                        BUTTON_PAIR_PAIR: next_wait_pair_cursor = BUTTON_PAIR_BACK;
                        BUTTON_PAIR_START: next_wait_pair_cursor = BUTTON_PAIR_PAIR;
                        default: next_wait_pair_cursor = BUTTON_PAIR_BACK;
                    endcase
                end
 
                if (pulse_btnD) begin
                    case (wait_pair_cursor)
                        BUTTON_PAIR_BACK: next_wait_pair_cursor = BUTTON_PAIR_PAIR;
                        BUTTON_PAIR_PAIR: next_wait_pair_cursor = (pair_state == `PAIRED) ? BUTTON_PAIR_START : BUTTON_PAIR_BACK;
                        BUTTON_PAIR_START: next_wait_pair_cursor = BUTTON_PAIR_BACK;
                        default: next_wait_pair_cursor = BUTTON_PAIR_BACK;
                    endcase
                end
                
//                if (pulse_btnU || pulse_btnD) next_wait_pair_cursor = ~wait_pair_cursor;
                
                if (pulse_btnC) begin
                    next_wait_pair_cursor = BUTTON_PAIR_BACK;
                    if (wait_pair_cursor == BUTTON_PAIR_BACK) next_state = `HOME;
                    else if (wait_pair_cursor == BUTTON_PAIR_START && pair_state == `PAIRED) next_state = `MULTI_HOME;
                end
            end
            `MULTI_HOME: begin
                if (player == `PLAYER_1) begin
                    if (pulse_btnU) begin
                        case (menu_cursor)
                            BUTTON_MENU_BACK: next_menu_cursor = BUTTON_MENU_RESTART;
                            BUTTON_MENU_RESUME: next_menu_cursor = BUTTON_MENU_BACK;
                            BUTTON_MENU_RESTART: next_menu_cursor = BUTTON_MENU_RESUME;
                            default: next_menu_cursor = BUTTON_MENU_BACK;
                        endcase
                    end
     
                    if (pulse_btnD) begin
                        case (menu_cursor)
                            BUTTON_MENU_BACK: next_menu_cursor = BUTTON_MENU_RESUME;
                            BUTTON_MENU_RESUME: next_menu_cursor = BUTTON_MENU_RESTART;
                            BUTTON_MENU_RESTART: next_menu_cursor = BUTTON_MENU_BACK;
                            default: next_menu_cursor = BUTTON_MENU_BACK;
                        endcase
                    end
    
                    if (pulse_btnC) begin
                        next_menu_cursor = BUTTON_MENU_BACK;
                        case (menu_cursor)
                            BUTTON_MENU_BACK: next_state = `MULTI_WAIT_PAIR;
                            BUTTON_MENU_RESUME: next_state = `MULTI_GAME;
                            BUTTON_MENU_RESTART: next_state = `MULTI_GAME;
                            default: next_state = `MULTI_WAIT_PAIR;
                        endcase
                    end
                end
                else begin
                    next_menu_cursor = BUTTON_MENU_BACK;
                    if (pulse_btnC) next_state = `MULTI_WAIT_PAIR;
                end
                
                // return to wait for pair if connection is lost
                if (pair_state != `PAIRED) next_state = `MULTI_WAIT_PAIR; 
            end
            `SINGLE_GAME: begin
                if (pulse_btnC) begin
                    next_state = `SINGLE_HOME;
                    next_menu_cursor = BUTTON_MENU_RESUME;
                end
            end
            `MULTI_GAME: begin
                if (pulse_btnC) begin
                    next_state = `MULTI_HOME;
                    next_menu_cursor = BUTTON_MENU_RESUME;
                end
                
                // return to wait for pair if connection lost
                if (pair_state != `PAIRED) next_state = `MULTI_WAIT_PAIR; 
            end
        endcase
    end
    
    always @ (posedge clk) begin
        rst_game <= 0;
        game_active <= 0;
        
        prev_sw0  <= sw[0];
        
        send_pair_req <= 0;
        send_unpair_req <= 0;

        state <= next_state;
        prev_state <= state;
        home_cursor <= next_home_cursor;
        menu_cursor <= next_menu_cursor;
        wait_pair_cursor <= next_wait_pair_cursor;
 
        case (state)
            `HOME: begin
                if (prev_state != `HOME) send_unpair_req <= 1;
            end
            `SINGLE_HOME: begin
                if (pulse_btnC) begin
                    case (menu_cursor)
                        BUTTON_MENU_RESUME: begin
                            // TODO: restore saved single-player tile_map snapshot
                            // TODO: restore player_x, player_y to saved position
                        end
                        BUTTON_MENU_RESTART: begin // rst game
                            rst_game <= 1;
                            // TODO: reset tile_map to default layout
                            // TODO: reset player_x, player_y to spawn corner
                            // TODO: clear active bombs and explosions
                        end
                        default: begin end
                    endcase
                end
            end
            `MULTI_WAIT_PAIR: begin
                if (pulse_btnC && wait_pair_cursor == BUTTON_PAIR_PAIR) begin
                    if (pair_state == `SINGLE) send_pair_req <= 1;
                    else if (pair_state == `PAIRED) send_unpair_req <= 1;
                end
                
                if (prev_state != `MULTI_WAIT_PAIR) send_unpair_req <= 1;
            end
            `MULTI_HOME: begin
                if (pulse_btnC) begin
                    case (menu_cursor)
                        BUTTON_MENU_RESUME: begin
                            // TODO: restore saved multi-player tile_map snapshot
                            // TODO: restore both player positions
                        end
                        BUTTON_MENU_RESTART: begin // rst game
                            rst_game <= 1;
                            // TODO: reset tile_map to default layout
                            // TODO: reset both player spawn positions
                            // TODO: clear bombs / explosions / scores
                        end
                        default: begin end
                    endcase
                end
            end
            `SINGLE_GAME: game_active <= 1;
            `MULTI_GAME: game_active <= 1;
            default: begin end
        endcase
    end
    
    parameter CHAR_WIDTH_BIG = 9; // must be odd
    parameter CHAR_HEIGHT_BIG = 11;

    parameter CHAR_WIDTH_SMALL  = 5;
    parameter CHAR_HEIGHT_SMALL = 7;
    
    reg [CHAR_WIDTH_SMALL-1:0] font_rom [0:127][0:CHAR_HEIGHT_SMALL-1];
    reg [CHAR_WIDTH_BIG-1:0] font_rom_big [0:127][0:CHAR_HEIGHT_BIG-1];
    
    integer big_row;
    initial begin
        // Large font for Bomberman
        // SPACE
        font_rom_big[" "][0]  = 9'b000000000;
        font_rom_big[" "][1]  = 9'b000000000;
        font_rom_big[" "][2]  = 9'b000000000;
        font_rom_big[" "][3]  = 9'b000000000;
        font_rom_big[" "][4]  = 9'b000000000;
        font_rom_big[" "][5]  = 9'b000000000;
        font_rom_big[" "][6]  = 9'b000000000;
        font_rom_big[" "][7]  = 9'b000000000;
        font_rom_big[" "][8]  = 9'b000000000;
        font_rom_big[" "][9]  = 9'b000000000;
        font_rom_big[" "][10] = 9'b000000000;
        
        // B
        font_rom_big["B"][0]  = 9'b111111100;
        font_rom_big["B"][1]  = 9'b111111110;
        font_rom_big["B"][2]  = 9'b110000011;
        font_rom_big["B"][3]  = 9'b110000011;
        font_rom_big["B"][4]  = 9'b110000011;
        font_rom_big["B"][5]  = 9'b111111110;
        font_rom_big["B"][6]  = 9'b111111100;
        font_rom_big["B"][7]  = 9'b110000011;
        font_rom_big["B"][8]  = 9'b110000011;
        font_rom_big["B"][9]  = 9'b111111110;
        font_rom_big["B"][10] = 9'b111111100;
        
        // O
        // O as bomb - round body, white glint top-left, fuse top-right
        font_rom_big["O"][0]  = 9'b000001100;  // fuse tip (top right)
        font_rom_big["O"][1]  = 9'b000011000;  // fuse curves left
        font_rom_big["O"][2]  = 9'b001111100;  // top of circle
        font_rom_big["O"][3]  = 9'b011111110;  // upper body
        font_rom_big["O"][4]  = 9'b111111111;  // full circle
        font_rom_big["O"][5]  = 9'b111111111;  // full circle
        font_rom_big["O"][6]  = 9'b111111111;  // full circle
        font_rom_big["O"][7]  = 9'b011111110;  // lower body
        font_rom_big["O"][8]  = 9'b001111100;  // bottom curve
        font_rom_big["O"][9]  = 9'b000111000;  // bottom tip
        font_rom_big["O"][10] = 9'b000000000;  // clear
        
        // M
        font_rom_big["M"][0]  = 9'b110000011;
        font_rom_big["M"][1]  = 9'b111000111;
        font_rom_big["M"][2]  = 9'b111101111;
        font_rom_big["M"][3]  = 9'b110111011;
        font_rom_big["M"][4]  = 9'b110010011;
        font_rom_big["M"][5]  = 9'b110000011;
        font_rom_big["M"][6]  = 9'b110000011;
        font_rom_big["M"][7]  = 9'b110000011;
        font_rom_big["M"][8]  = 9'b110000011;
        font_rom_big["M"][9]  = 9'b110000011;
        font_rom_big["M"][10] = 9'b110000011;
        
        // E
        font_rom_big["E"][0]  = 9'b111111111;
        font_rom_big["E"][1]  = 9'b111111111;
        font_rom_big["E"][2]  = 9'b110000000;
        font_rom_big["E"][3]  = 9'b110000000;
        font_rom_big["E"][4]  = 9'b111111111;
        font_rom_big["E"][5]  = 9'b111111111;
        font_rom_big["E"][6]  = 9'b110000000;
        font_rom_big["E"][7]  = 9'b110000000;
        font_rom_big["E"][8]  = 9'b110000000;
        font_rom_big["E"][9]  = 9'b111111111;
        font_rom_big["E"][10] = 9'b111111111;
        
        // R
        font_rom_big["R"][0]  = 9'b111111100;
        font_rom_big["R"][1]  = 9'b111111110;
        font_rom_big["R"][2]  = 9'b110000011;
        font_rom_big["R"][3]  = 9'b110000011;
        font_rom_big["R"][4]  = 9'b110000011;
        font_rom_big["R"][5]  = 9'b111111110;
        font_rom_big["R"][6]  = 9'b111111100;
        font_rom_big["R"][7]  = 9'b110110000;
        font_rom_big["R"][8]  = 9'b110011000;
        font_rom_big["R"][9]  = 9'b110001100;
        font_rom_big["R"][10] = 9'b110000110;
        
        // A
        font_rom_big["A"][0]  = 9'b000111000;
        font_rom_big["A"][1]  = 9'b001111100;
        font_rom_big["A"][2]  = 9'b011000110;
        font_rom_big["A"][3]  = 9'b110000011;
        font_rom_big["A"][4]  = 9'b110000011;
        font_rom_big["A"][5]  = 9'b111111111;
        font_rom_big["A"][6]  = 9'b111111111;
        font_rom_big["A"][7]  = 9'b110000011;
        font_rom_big["A"][8]  = 9'b110000011;
        font_rom_big["A"][9]  = 9'b110000011;
        font_rom_big["A"][10] = 9'b110000011;
        
        // N
        font_rom_big["N"][0]  = 9'b110000011;
        font_rom_big["N"][1]  = 9'b111000011;
        font_rom_big["N"][2]  = 9'b111100011;
        font_rom_big["N"][3]  = 9'b110110011;
        font_rom_big["N"][4]  = 9'b110011011;
        font_rom_big["N"][5]  = 9'b110001111;
        font_rom_big["N"][6]  = 9'b110000111;
        font_rom_big["N"][7]  = 9'b110000011;
        font_rom_big["N"][8]  = 9'b110000011;
        font_rom_big["N"][9]  = 9'b110000011;
        font_rom_big["N"][10] = 9'b110000011;
        
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
            oled_data <= `OLED_BLACK;
     
            case (state)
                // ????????????????????????????????????????????????
                // HOME SCREEN
                // OLED: 96x64px
                // Title BOMBERMAN: big font, y=15
                // SINGLE: rect left=3,  top=37, w=43, h=19 | text y=46
                // MULTI:  rect left=51, top=37, w=43, h=19 | text y=46
                // ????????????????????????????????????????????????
                `HOME: begin
                    //extra stuff for astetics
                    big_row = y - (15 - (CHAR_HEIGHT_BIG-1)/2);  // 15 is your yc
                
                    if (draw_letter_big(x, y, 8+10*0, 15, "B") ||
                        draw_letter_big(x, y, 8+10*1, 15, "O") ||
                        draw_letter_big(x, y, 8+10*2, 15, "M") ||
                        draw_letter_big(x, y, 8+10*3, 15, "B") ||
                        draw_letter_big(x, y, 8+10*4, 15, "E") ||
                        draw_letter_big(x, y, 8+10*5, 15, "R") ||
                        draw_letter_big(x, y, 8+10*6, 15, "M") ||
                        draw_letter_big(x, y, 8+10*7, 15, "A") ||
                        draw_letter_big(x, y, 8+10*8, 15, "N")) begin
                        case (big_row)
                            0:       oled_data <= 16'hFFE0; // bright yellow
                            1:       oled_data <= 16'hFFE0; // bright yellow
                            2:       oled_data <= 16'hFEE0; // yellow-orange
                            3:       oled_data <= 16'hFD60; // light orange
                            4:       oled_data <= 16'hFC80; // orange
                            5:       oled_data <= 16'hFC40; // deeper orange
                            6:       oled_data <= 16'hFB80; // orange-red
                            7:       oled_data <= 16'hFA00; // red-orange
                            8:       oled_data <= 16'hF900; // light red
                            9:       oled_data <= 16'hF800; // pure red
                            10:      oled_data <= 16'hF800; // pure red
                            default: oled_data <= 16'hFFE0;
                        endcase
                    end
                
                    // bomb O override - light grey fill, keeps fuse rows as gradient
                    if (draw_letter_big(x, y, 8+10*1, 15, "O") && big_row >= 2)
                        oled_data <= 16'hAD55; // light grey (R=21, G=42, B=21 in RGB565)
                
                    // white glint top-left of bomb
                    if (x == (8+10*1) - 2 && y == 15 - 2)
                        oled_data <= `OLED_WHITE;
                        
                    // Title
                    /*
                    if (draw_letter_big(x, y, 8+10*0, 15, "B") ||
                        draw_letter_big(x, y, 8+10*1, 15, "O") ||
                        draw_letter_big(x, y, 8+10*2, 15, "M") ||
                        draw_letter_big(x, y, 8+10*3, 15, "B") ||
                        draw_letter_big(x, y, 8+10*4, 15, "E") ||
                        draw_letter_big(x, y, 8+10*5, 15, "R") ||
                        draw_letter_big(x, y, 8+10*6, 15, "M") ||
                        draw_letter_big(x, y, 8+10*7, 15, "A") ||
                        draw_letter_big(x, y, 8+10*8, 15, "N"))
                        oled_data <= `OLED_WHITE;
                        
                      */
     
                    // LEFT - SINGLE
                    if (draw_rect(x, y, 3, 37, 43, 19))
                        oled_data <= (home_cursor == BUTTON_HOME_SINGLE) ? `OLED_YELLOW : `OLED_WHITE;
                    if (draw_letter(x, y, 9,  46, "S") ||
                        draw_letter(x, y, 15, 46, "I") ||
                        draw_letter(x, y, 21, 46, "N") ||
                        draw_letter(x, y, 27, 46, "G") ||
                        draw_letter(x, y, 33, 46, "L") ||
                        draw_letter(x, y, 39, 46, "E"))
                        oled_data <= (home_cursor == 0) ? `OLED_YELLOW : `OLED_WHITE;
     
                    // RIGHT - MULTI
                    if (draw_rect(x, y, 51, 37, 43, 19))
                        oled_data <= (home_cursor == BUTTON_HOME_MULTI) ? `OLED_YELLOW : `OLED_WHITE;
                    if (draw_letter(x, y, 60, 46, "M") ||
                        draw_letter(x, y, 66, 46, "U") ||
                        draw_letter(x, y, 72, 46, "L") ||
                        draw_letter(x, y, 78, 46, "T") ||
                        draw_letter(x, y, 84, 46, "I"))
                        oled_data <= (home_cursor == 1) ? `OLED_YELLOW : `OLED_WHITE;
                end
                `MULTI_WAIT_PAIR: begin
                    case (pair_state)
                        `SINGLE, `PAIRED: begin
                            if (draw_rect(x, y, 23, 7, 50, 13))
                                oled_data <= (wait_pair_cursor == BUTTON_PAIR_BACK) ? `OLED_YELLOW : `OLED_WHITE;
                            if (draw_letter(x, y, 39, 13, "E") ||
                                draw_letter(x, y, 45, 13, "X") ||
                                draw_letter(x, y, 51, 13, "I") ||
                                draw_letter(x, y, 57, 13, "T"))
                                oled_data <= (wait_pair_cursor == BUTTON_PAIR_BACK) ? `OLED_YELLOW : `OLED_WHITE;
                            
                            if (pair_state == `PAIRED) begin
                                if (draw_rect(x, y, 23, 25, 50, 13))
                                    oled_data <= (wait_pair_cursor == BUTTON_PAIR_PAIR) ? `OLED_YELLOW : `OLED_GREEN;
                                if (draw_letter(x, y, 33, 31, "P") ||
                                    draw_letter(x, y, 39, 31, "A") ||
                                    draw_letter(x, y, 45, 31, "I") ||
                                    draw_letter(x, y, 51, 31, "R") ||
                                    draw_letter(x, y, 57, 31, "E") ||
                                    draw_letter(x, y, 63, 31, "D"))
                                    oled_data <= (wait_pair_cursor == BUTTON_PAIR_PAIR) ? `OLED_YELLOW : `OLED_GREEN;
                                                                
                                
                                if (draw_rect(x, y, 23, 43, 50, 13))
                                    oled_data <= (wait_pair_cursor == BUTTON_PAIR_START) ? `OLED_YELLOW : `OLED_WHITE;
                                if (draw_letter(x, y, 36, 49, "R") ||
                                    draw_letter(x, y, 42, 49, "E") ||
                                    draw_letter(x, y, 48, 49, "A") ||
                                    draw_letter(x, y, 54, 49, "D") ||
                                    draw_letter(x, y, 60, 49, "Y"))
                                    oled_data <= (wait_pair_cursor == BUTTON_PAIR_START) ? `OLED_YELLOW : `OLED_WHITE;
                            end
                            else begin
                                if (draw_rect(x, y, 23, 25, 50, 13))
                                    oled_data <= (wait_pair_cursor == BUTTON_PAIR_PAIR) ? `OLED_YELLOW : `OLED_RED;
                                if (draw_letter(x, y, 27, 31, "U") ||
                                    draw_letter(x, y, 33, 31, "N") ||
                                    draw_letter(x, y, 39, 31, "P") ||
                                    draw_letter(x, y, 45, 31, "A") ||
                                    draw_letter(x, y, 51, 31, "I") ||
                                    draw_letter(x, y, 57, 31, "R") ||
                                    draw_letter(x, y, 63, 31, "E") ||
                                    draw_letter(x, y, 69, 31, "D"))
                                    oled_data <= (wait_pair_cursor == BUTTON_PAIR_PAIR) ? `OLED_YELLOW : `OLED_RED;
                            end
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
                        `CONFIRM: oled_data <= `OLED_ORANGE;
                        `WAIT_CONFIRM: oled_data <= `OLED_CYAN;
                    endcase
                end
                
     
                // ????????????????????????????????????????????????
                // SINGLE_HOME and MULTI_HOME - centered 3-button menu
                // OLED: 96x64px
                // All buttons: left=23, width=50
                // HOME    rect top=7,  h=13 | text y-center=13
                // RESUME  rect top=25, h=13 | text y-center=31
                // RESTART rect top=43, h=13 | text y-center=49
                // Gap between buttons = 6px
                // ????????????????????????????????????????????????
                `SINGLE_HOME,
                `MULTI_HOME: begin
                    // ?? HOME button ??
                    if (draw_rect(x, y, 23, 7, 50, 13))
                        oled_data <= (menu_cursor == BUTTON_MENU_BACK) ? `OLED_YELLOW : `OLED_WHITE;
                    if (draw_letter(x, y, 39, 13, "E") ||
                        draw_letter(x, y, 45, 13, "X") ||
                        draw_letter(x, y, 51, 13, "I") ||
                        draw_letter(x, y, 57, 13, "T"))
                        oled_data <= (menu_cursor == BUTTON_MENU_BACK) ? `OLED_YELLOW : `OLED_WHITE;
     
                    // ?? RESUME button ??
                    if (player == `PLAYER_1) begin
                        if (draw_rect(x, y, 23, 25, 50, 13))
                            oled_data <= (menu_cursor == BUTTON_MENU_RESUME) ? `OLED_YELLOW : `OLED_WHITE;
                        if (draw_letter(x, y, 33, 31, "R") ||
                            draw_letter(x, y, 39, 31, "E") ||
                            draw_letter(x, y, 45, 31, "S") ||
                            draw_letter(x, y, 51, 31, "U") ||
                            draw_letter(x, y, 57, 31, "M") ||
                            draw_letter(x, y, 63, 31, "E"))
                            oled_data <= (menu_cursor == BUTTON_MENU_RESUME) ? `OLED_YELLOW : `OLED_WHITE;
         
                        // ?? RESTART button ??
                        if (draw_rect(x, y, 23, 43, 50, 13))
                            oled_data <= (menu_cursor == BUTTON_MENU_RESTART) ? `OLED_YELLOW : `OLED_WHITE;
                        if (draw_letter(x, y, 30, 49, "R") ||
                            draw_letter(x, y, 36, 49, "E") ||
                            draw_letter(x, y, 42, 49, "S") ||
                            draw_letter(x, y, 48, 49, "T") ||
                            draw_letter(x, y, 54, 49, "A") ||
                            draw_letter(x, y, 60, 49, "R") ||
                            draw_letter(x, y, 66, 49, "T"))
                            oled_data <= (menu_cursor == BUTTON_MENU_RESTART) ? `OLED_YELLOW : `OLED_WHITE;
                    end
                end
                default: begin end
            endcase
        end
    
    function draw_letter;
        input [6:0] x, y;
        input integer xc, yc;
        input [7:0] letter;
        integer row, col;
        begin
            draw_letter = 0;
            row = y - (yc - (CHAR_HEIGHT_SMALL-1)/2); 
            col = x - (xc - (CHAR_WIDTH_SMALL-1)/2);
            if (row >= 0 && row < CHAR_HEIGHT_SMALL && col >= 0 && col < CHAR_WIDTH_SMALL) begin
                draw_letter = font_rom[letter][row][CHAR_WIDTH_SMALL-1-col];
            end
        end
    endfunction
    
    function draw_letter_big;
        input [6:0] x, y;
        input integer xc, yc;
        input [7:0] letter;
        integer row, col;
        begin
            draw_letter_big = 0;
            row = y - (yc - (CHAR_HEIGHT_BIG-1)/2); 
            col = x - (xc - (CHAR_WIDTH_BIG-1)/2);
            if (row >= 0 && row < CHAR_HEIGHT_BIG && col >= 0 && col < CHAR_WIDTH_BIG) begin
                draw_letter_big = font_rom_big[letter][row][CHAR_WIDTH_BIG-1-col];
            end
        end
    endfunction
    
    function draw_rect;
        input [6:0] x;
        input [5:0] y;
        input integer left, top, width, height;
        begin
            draw_rect =
                ((x >= left) && (x < left + width) && (y == top)) ||
                ((x >= left) && (x < left + width) && (y == top + height - 1)) ||
                ((y >= top) && (y < top + height) && (x == left)) ||
                ((y >= top) && (y < top + height) && (x == left + width - 1));
        end
    endfunction
    
endmodule


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