`timescale 1ns / 1ps

`include "constants.vh"

module interface_fsm (input clk, btnL, btnR, btnC, btnU, btnD,
                      input [8:0] sw, 
                      input [2:0] pair_state,
                      input player, p1_dead, p2_dead,
                      input [6:0] x, input [5:0] y,
                      output reg rst_game=0, game_active=0, game_start=0, send_pair_req=0, send_unpair_req=0, game_over=0,
                      output reg [15:0] oled_data=0,
                      output reg [2:0] state = 0);
    
    `include "font.vh"
    
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
 
    reg home_cursor = BUTTON_HOME_SINGLE;
    reg next_home_cursor = BUTTON_HOME_SINGLE;
    reg [1:0] menu_cursor = BUTTON_MENU_RESUME;
    reg [1:0] next_menu_cursor = BUTTON_MENU_RESUME;
    reg [1:0] wait_pair_cursor = BUTTON_PAIR_BACK;
    reg [1:0] next_wait_pair_cursor = BUTTON_PAIR_BACK;
    
    reg single_game_saved = 0;
    reg multi_game_saved = 0;
    
//    reg game_over = 0;
    reg game_over_single = 0; // 1 = from single, 0 = from multi
    
    parameter integer DEATH_PAUSE_TIME = 3 * `CLOCK_SPEED; // 3 seconds
    reg [$clog2(DEATH_PAUSE_TIME)-1:0] death_counter = 0;
    
    reg [1:0] winner = 0; // 0 player 1, 1 player 2, 2 draw
 
    // -------------------------------------------------------
    // BUTTON
    // -------------------------------------------------------
    
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
                        BUTTON_MENU_RESTART: next_menu_cursor = (single_game_saved && !game_over) ? BUTTON_MENU_RESUME : BUTTON_MENU_BACK;
                        default: next_menu_cursor = BUTTON_MENU_BACK;
                    endcase
                end
 
                if (pulse_btnD) begin
                    case (menu_cursor)
                        BUTTON_MENU_BACK: next_menu_cursor = (single_game_saved && !game_over) ? BUTTON_MENU_RESUME : BUTTON_MENU_RESTART;
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
                            BUTTON_MENU_RESTART: next_menu_cursor = (multi_game_saved && !game_over) ? BUTTON_MENU_RESUME : BUTTON_MENU_BACK;
                            default: next_menu_cursor = BUTTON_MENU_BACK;
                        endcase
                    end
     
                    if (pulse_btnD) begin
                        case (menu_cursor)
                            BUTTON_MENU_BACK: next_menu_cursor = (multi_game_saved && !game_over) ? BUTTON_MENU_RESUME : BUTTON_MENU_RESTART;
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
                
                if ((p1_dead || p2_dead) && !game_over && !game_start) next_state = `DEATH_PAUSE;
            end
            `MULTI_GAME: begin
                if (pulse_btnC) begin
                    next_state = `MULTI_HOME;
                    next_menu_cursor = BUTTON_MENU_RESUME;
                end

                if ((p1_dead || p2_dead) && !game_over && !game_start) next_state = `DEATH_PAUSE;
                
                // return to wait for pair if connection lost
                if (pair_state != `PAIRED) next_state = `MULTI_WAIT_PAIR; 
            end
            `DEATH_PAUSE: begin
                if (death_counter == DEATH_PAUSE_TIME-1) next_state = `GAME_OVER;
            end
            `GAME_OVER: begin
                if (pulse_btnC) begin
                    next_state = game_over_single ? `SINGLE_HOME : `MULTI_HOME;
                end
            end
        endcase
    end
    
    always @ (posedge clk) begin
        rst_game <= 0;
        game_active <= 0;
        game_start <= 0;
        
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
                multi_game_saved <= 0;
                single_game_saved <= 0;
            end
            `SINGLE_HOME: begin
                if (pulse_btnC) begin
                    case (menu_cursor)
                        BUTTON_MENU_RESUME: begin
                            game_start <= 1;
                            // TODO: restore saved single-player tile_map snapshot
                            // TODO: restore player_x, player_y to saved position
                        end
                        BUTTON_MENU_RESTART: begin // rst game
                            rst_game <= 1;
                            game_start <= 1;
                            game_over <= 0;
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
                            game_start <= 1;
                            // TODO: restore saved multi-player tile_map snapshot
                            // TODO: restore both player positions
                        end
                        BUTTON_MENU_RESTART: begin // rst game
                            rst_game <= 1;
                            game_start <= 1;
                            game_over <= 0;
                            // TODO: reset tile_map to default layout
                            // TODO: reset both player spawn positions
                            // TODO: clear bombs / explosions / scores
                        end
                        default: begin end
                    endcase
                end
            end
            `SINGLE_GAME: begin
                game_active <= 1;
                single_game_saved <= 1;
                
                if (p1_dead || p2_dead) begin
                    winner <= (!p1_dead && p2_dead) ? 0 : ((p1_dead && !p2_dead) ? 1 : 2);
                    game_over_single <= 1;
                    death_counter <= 0;
                end
            end
            `MULTI_GAME: begin
                game_active <= 1;
                multi_game_saved <= 1;
                
                if (p1_dead || p2_dead) begin
                    winner <= (!p1_dead && p2_dead) ? 0 : ((p1_dead && !p2_dead) ? 1 : 2);
                    game_over_single <= 0;
                    death_counter <= 0;
                end
            end
            `DEATH_PAUSE: begin
                game_active <= 1;
                death_counter <= death_counter + 1;
            end
            `GAME_OVER: begin
                game_over <= 1;
                death_counter <= 0;
            end
            default: begin end
        endcase
    end
    
    integer big_row;
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
                    big_row = y - (15 - (`CHAR_HEIGHT_BIG-1)/2);  // 15 is your yc
                
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
                        if (((state == `SINGLE_HOME && single_game_saved) || (state == `MULTI_HOME && multi_game_saved)) && !game_over) begin
                            if (draw_rect(x, y, 23, 25, 50, 13))
                                oled_data <= (menu_cursor == BUTTON_MENU_RESUME) ? `OLED_YELLOW : `OLED_WHITE;
                            if (draw_letter(x, y, 33, 31, "R") ||
                                draw_letter(x, y, 39, 31, "E") ||
                                draw_letter(x, y, 45, 31, "S") ||
                                draw_letter(x, y, 51, 31, "U") ||
                                draw_letter(x, y, 57, 31, "M") ||
                                draw_letter(x, y, 63, 31, "E"))
                                oled_data <= (menu_cursor == BUTTON_MENU_RESUME) ? `OLED_YELLOW : `OLED_WHITE;
                        end
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
                `GAME_OVER: begin
                    big_row = y - (15 - (`CHAR_HEIGHT_BIG-1)/2); // yc=32, vertically centred
                
                    if (draw_letter_big(x, y, 8+10*0+3, 15, "G") ||
                        draw_letter_big(x, y, 8+10*1+3, 15, "A") ||
                        draw_letter_big(x, y, 8+10*2+3, 15, "M") ||
                        draw_letter_big(x, y, 8+10*3+3, 15, "E") ||
                        // draw_letter_big(x, y, 8+10*4, 15, " ") ||
                        draw_letter_big(x, y, 8+10*5-3, 15, "O") ||
                        draw_letter_big(x, y, 8+10*6-3, 15, "V") ||
                        draw_letter_big(x, y, 8+10*7-3, 15, "E") ||
                        draw_letter_big(x, y, 8+10*8-3, 15, "R")) begin
                        case (big_row)
                            0:       oled_data <= 16'hFFE0;
                            1:       oled_data <= 16'hFFE0;
                            2:       oled_data <= 16'hFEE0;
                            3:       oled_data <= 16'hFD60;
                            4:       oled_data <= 16'hFC80;
                            5:       oled_data <= 16'hFC40;
                            6:       oled_data <= 16'hFB80;
                            7:       oled_data <= 16'hFA00;
                            8:       oled_data <= 16'hF900;
                            9:       oled_data <= 16'hF800;
                            10:      oled_data <= 16'hF800;
                            default: oled_data <= 16'hFFE0;
                        endcase
                    end
                    
                    // bomb O override - grey fill for the circle part, keeps gradient on fuse rows
                    if (draw_letter_big(x, y, 8+10*5-3, 15, "O") && big_row >= 2)
                        oled_data <= 16'hAD55;
                    
                    // white glint top-left of bomb O
                    if (x == (8+10*5)-3-2 && y == 15-2)
                        oled_data <= `OLED_WHITE;
                
                    // winner line below in small font
                    if (winner == 1) begin
                        if (draw_letter(x, y, 30, 30, "P") ||
                            draw_letter(x, y, 36, 30, "2") ||
                            draw_letter(x, y, 42, 30, " ") ||
                            draw_letter(x, y, 48, 30, "W") || 
                            draw_letter(x, y, 54, 30, "I") ||
                            draw_letter(x, y, 60, 30, "N") || 
                            draw_letter(x, y, 66, 30, "S"))
                            oled_data <= `OLED_RED;
                    end 
                    else if (winner == 0) begin
                        if (draw_letter(x, y, 30, 30, "P") ||
                            draw_letter(x, y, 36, 30, "1") ||
                            draw_letter(x, y, 42, 30, " ") ||
                            draw_letter(x, y, 48, 30, "W") || 
                            draw_letter(x, y, 54, 30, "I") ||
                            draw_letter(x, y, 60, 30, "N") || 
                            draw_letter(x, y, 66, 30, "S"))
                            oled_data <= `OLED_BLUE;
                    end 
                    else begin
                        if (draw_letter(x, y, 39, 30, "D") || 
                            draw_letter(x, y, 45, 30, "R") ||
                            draw_letter(x, y, 51, 30, "A") || 
                            draw_letter(x, y, 57, 30, "W"))
                            oled_data <= `OLED_MAGENTA;
                    end
                    
                    if (draw_rect(x, y, 23, 44, 50, 13))
                        oled_data <= `OLED_YELLOW;
                    if (draw_letter(x, y, 39, 50, "E") ||
                        draw_letter(x, y, 45, 50, "X") ||
                        draw_letter(x, y, 51, 50, "I") ||
                        draw_letter(x, y, 57, 50, "T"))
                        oled_data <= `OLED_YELLOW;
                end
                default: begin end
            endcase
        end
endmodule