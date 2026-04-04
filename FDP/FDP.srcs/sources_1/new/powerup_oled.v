`timescale 1ns / 1ps

module powerup_oled(input [6:0] pu_x, input [5:0] pu_y,
                    input [1:0] disp_bomb_radius, disp_bomb_count, disp_speed_incr,
                    output reg [15:0] oled_data_powerup);
    // Layout (96x64 px OLED, coordinates after 180° flip):
    // Icons  centred at x=33, 13x13 px (lx,ly in [0..12])
    // Digits centred at x=63, 5x7  px
    //
    // Row centres:
    // ROW0_CY = 20  (bomb  / bomb_radius)
    // ROW1_CY = 32  (fire  / bomb_count)
    // ROW2_CY = 44  (bolt  / speed_incr)
 
    // --- player stat mux ---
//    wire [1:0] disp_bomb_radius = (player == `PLAYER_1) ? p1_bomb_radius : p2_bomb_radius;
//    wire [1:0] disp_bomb_count  = (player == `PLAYER_1) ? p1_bomb_count  : p2_bomb_count;
//    wire [1:0] disp_speed_incr  = (player == `PLAYER_1) ? p1_speed_incr  : p2_speed_incr;
 
    // --- geometry constants ---
    localparam ICON_CX  = 7'd33;
    localparam DIGIT_CX = 7'd63;
    localparam ROW0_CY  = 6'd20;
    localparam ROW1_CY  = 6'd32;
    localparam ROW2_CY  = 6'd44;
 
    // ----------------------------------------------------------------
    // SHARED COLUMN CHECKS (computed once, reused across all rows)
    // ----------------------------------------------------------------
    wire in_icon_col  = (pu_x >= ICON_CX-6)  && (pu_x <= ICON_CX+6);
    wire in_digit_col = (pu_x >= DIGIT_CX-2) && (pu_x <= DIGIT_CX+2);
 
    // Shared icon x local coord (identical for every row since ICON_CX is fixed)
    wire [3:0] icon_lx = pu_x - (ICON_CX - 6);   // 0..12
 
    // Shared digit x local coord
    wire [2:0] dig_lx = pu_x - (DIGIT_CX - 2);   // 0..4
 
    // ----------------------------------------------------------------
    // ROW DETECTION  - which of the three rows is the current pixel in?
    // row_sel: 00=none, 01=row0(bomb), 10=row1(fire), 11=row2(bolt)
    // ----------------------------------------------------------------
    wire in_row0 = (pu_y >= ROW0_CY-6) && (pu_y <= ROW0_CY+6);
    wire in_row1 = (pu_y >= ROW1_CY-6) && (pu_y <= ROW1_CY+6);
    wire in_row2 = (pu_y >= ROW2_CY-6) && (pu_y <= ROW2_CY+6);
 
    wire in_dig_row0 = (pu_y >= ROW0_CY-3) && (pu_y <= ROW0_CY+3);
    wire in_dig_row1 = (pu_y >= ROW1_CY-3) && (pu_y <= ROW1_CY+3);
    wire in_dig_row2 = (pu_y >= ROW2_CY-3) && (pu_y <= ROW2_CY+3);
 
    // ----------------------------------------------------------------
    // SHARED LOCAL Y COORDS  - mux the active row's ly into one wire
    // ----------------------------------------------------------------
    // Icon ly: offset from top of whichever icon box is active
    wire [3:0] icon_ly = in_row0 ? (pu_y - (ROW0_CY - 6)) :
                         in_row1 ? (pu_y - (ROW1_CY - 6)) :
                                   (pu_y - (ROW2_CY - 6));
 
    // Digit ly: offset from top of whichever digit box is active
    wire [3:0] dig_ly  = in_dig_row0 ? (pu_y - (ROW0_CY - 3)) :
                         in_dig_row1 ? (pu_y - (ROW1_CY - 3)) :
                                       (pu_y - (ROW2_CY - 3));
 
    // Active digit value for the current row
    wire [1:0] dig_val = in_dig_row0 ? disp_bomb_count:
                         in_dig_row1 ? disp_bomb_radius :
                                       disp_speed_incr;
 
    // ----------------------------------------------------------------
    // BOMB ICON  13x13  (orange)
    //
    //  ly=0  .............
    //  ly=1  ......#......   fuse tip
    //  ly=2  .....#.#.....   fuse zigzag
    //  ly=3  ......#......   fuse base
    //  ly=4  ....#####....   circle top
    //  ly=5  ...#######...
    //  ly=6  ..#########..
    //  ly=7  ..#########..
    //  ly=8  ..#########..
    //  ly=9  ...#######...
    //  ly=10 ....#####....   circle bottom
    //  ly=11 .............
    //  ly=12 .............
    // ----------------------------------------------------------------
    function icon_bomb;
        input [3:0] lx, ly;
        reg circle, fuse;
        begin
            case (ly)
                4'd4:  circle = (lx >= 4'd4  && lx <= 4'd8);
                4'd5:  circle = (lx >= 4'd3  && lx <= 4'd9);
                4'd6:  circle = (lx >= 4'd2  && lx <= 4'd10);
                4'd7:  circle = (lx >= 4'd2  && lx <= 4'd10);
                4'd8:  circle = (lx >= 4'd2  && lx <= 4'd10);
                4'd9:  circle = (lx >= 4'd3  && lx <= 4'd9);
                4'd10: circle = (lx >= 4'd4  && lx <= 4'd8);
                default: circle = 0;
            endcase
            case (ly)
                4'd1:   fuse = (lx == 4'd6);
                4'd2:   fuse = (lx == 4'd5 || lx == 4'd7);
                4'd3:   fuse = (lx == 4'd6);
                default: fuse = 0;
            endcase
            icon_bomb = circle | fuse;
        end
    endfunction
 
    // ----------------------------------------------------------------
    // FIRE ICON  13x13  (red)
    //
    //  ly=0  ......#......   tip
    //  ly=1  .....###.....
    //  ly=2  ....#####....
    //  ly=3  ...#######...
    //  ly=4  ..#########..
    //  ly=5  ..#########..
    //  ly=6  ..###...###..   hollow centre
    //  ly=7  ..###...###..
    //  ly=8  ..###...###..
    //  ly=9  ...#######...
    //  ly=10 ....#####....
    //  ly=11 ...#######...   base glow
    //  ly=12 .............
    // ----------------------------------------------------------------
    function icon_fire;
        input [3:0] lx, ly;
        reg outer, inner;
        begin
            case (ly)
                4'd0:  outer = (lx == 4'd6);
                4'd1:  outer = (lx >= 4'd5  && lx <= 4'd7);
                4'd2:  outer = (lx >= 4'd4  && lx <= 4'd8);
                4'd3:  outer = (lx >= 4'd3  && lx <= 4'd9);
                4'd4:  outer = (lx >= 4'd2  && lx <= 4'd10);
                4'd5:  outer = (lx >= 4'd2  && lx <= 4'd10);
                4'd6:  outer = (lx >= 4'd2  && lx <= 4'd10);
                4'd7:  outer = (lx >= 4'd2  && lx <= 4'd10);
                4'd8:  outer = (lx >= 4'd2  && lx <= 4'd10);
                4'd9:  outer = (lx >= 4'd3  && lx <= 4'd9);
                4'd10: outer = (lx >= 4'd4  && lx <= 4'd8);
                4'd11: outer = (lx >= 4'd3  && lx <= 4'd9);
                default: outer = 0;
            endcase
            inner = (ly >= 4'd6 && ly <= 4'd8 && lx >= 4'd5 && lx <= 4'd7);
            icon_fire = outer & ~inner;
        end
    endfunction
 
    // ----------------------------------------------------------------
    // LIGHTNING BOLT ICON  13x13  (yellow)
    //
    //  ly=0  .....######.   top-right bar
    //  ly=1  ....#####...
    //  ly=2  ...#####....
    //  ly=3  ..#####.....
    //  ly=4  .#######....   wide centre
    //  ly=5  ..#######...
    //  ly=6  ...#######..
    //  ly=7  ....#####...
    //  ly=8  .....#####..
    //  ly=9  ......####..
    //  ly=10 .......###..   bottom-right tip
    //  ly=11 .............
    //  ly=12 .............
    // ----------------------------------------------------------------
    function icon_bolt;
        input [3:0] lx, ly;
        begin
            case (ly)
                4'd0:  icon_bolt = (lx >= 4'd5  && lx <= 4'd10);
                4'd1:  icon_bolt = (lx >= 4'd4  && lx <= 4'd8);
                4'd2:  icon_bolt = (lx >= 4'd3  && lx <= 4'd7);
                4'd3:  icon_bolt = (lx >= 4'd2  && lx <= 4'd6);
                4'd4:  icon_bolt = (lx >= 4'd1  && lx <= 4'd7);
                4'd5:  icon_bolt = (lx >= 4'd2  && lx <= 4'd8);
                4'd6:  icon_bolt = (lx >= 4'd3  && lx <= 4'd9);
                4'd7:  icon_bolt = (lx >= 4'd4  && lx <= 4'd8);
                4'd8:  icon_bolt = (lx >= 4'd5  && lx <= 4'd9);
                4'd9:  icon_bolt = (lx >= 4'd6  && lx <= 4'd9);
                4'd10: icon_bolt = (lx >= 4'd7  && lx <= 4'd9);
                default: icon_bolt = 0;
            endcase
        end
    endfunction
 
    // ----------------------------------------------------------------
    // DIGIT PIXEL  - flat case truth table, no dynamic bit-select.
    // Inputs: val (0-3), dx (0-4), dy (0-6).
    // Each case arm is a constant, giving the synthesiser a plain ROM.
    //
    // Glyphs (5 cols x 7 rows):
    //  0: 01110  1: 00100  2: 01110  3: 01110
    //     10001     01100     10001     10001
    //     10001     00100     00001     00001
    //     10001     00100     00110     00110
    //     10001     00100     01000     00001
    //     10001     00100     10000     10001
    //     01110     01110     11111     01110
    // ----------------------------------------------------------------
    function digit_pixel;
        input [1:0] val;
        input [2:0] dx;   // 0..4
        input [3:0] dy;   // 0..6
        begin
            case ({val, dy[2:0], dx})   // 8-bit key: [7:6]=val [5:3]=dy [2:0]=dx
                // ------- digit 0 -------
                {2'd0,3'd0,3'd1},{2'd0,3'd0,3'd2},{2'd0,3'd0,3'd3}: digit_pixel=1;
                {2'd0,3'd1,3'd0},{2'd0,3'd1,3'd4}: digit_pixel=1;
                {2'd0,3'd2,3'd0},{2'd0,3'd2,3'd4}: digit_pixel=1;
                {2'd0,3'd3,3'd0},{2'd0,3'd3,3'd4}: digit_pixel=1;
                {2'd0,3'd4,3'd0},{2'd0,3'd4,3'd4}: digit_pixel=1;
                {2'd0,3'd5,3'd0},{2'd0,3'd5,3'd4}: digit_pixel=1;
                {2'd0,3'd6,3'd1},{2'd0,3'd6,3'd2},{2'd0,3'd6,3'd3}: digit_pixel=1;
                // ------- digit 1 -------
                {2'd1,3'd0,3'd2}: digit_pixel=1;
                {2'd1,3'd1,3'd1},{2'd1,3'd1,3'd2}: digit_pixel=1;
                {2'd1,3'd2,3'd2}: digit_pixel=1;
                {2'd1,3'd3,3'd2}: digit_pixel=1;
                {2'd1,3'd4,3'd2}: digit_pixel=1;
                {2'd1,3'd5,3'd2}: digit_pixel=1;
                {2'd1,3'd6,3'd1},{2'd1,3'd6,3'd2},{2'd1,3'd6,3'd3}: digit_pixel=1;
                // ------- digit 2 -------
                {2'd2,3'd0,3'd1},{2'd2,3'd0,3'd2},{2'd2,3'd0,3'd3}: digit_pixel=1;
                {2'd2,3'd1,3'd0},{2'd2,3'd1,3'd4}: digit_pixel=1;
                {2'd2,3'd2,3'd4}: digit_pixel=1;
                {2'd2,3'd3,3'd2},{2'd2,3'd3,3'd3}: digit_pixel=1;
                {2'd2,3'd4,3'd1}: digit_pixel=1;
                {2'd2,3'd5,3'd0}: digit_pixel=1;
                {2'd2,3'd6,3'd0},{2'd2,3'd6,3'd1},{2'd2,3'd6,3'd2},{2'd2,3'd6,3'd3},{2'd2,3'd6,3'd4}: digit_pixel=1;
                // ------- digit 3 -------
                {2'd3,3'd0,3'd1},{2'd3,3'd0,3'd2},{2'd3,3'd0,3'd3}: digit_pixel=1;
                {2'd3,3'd1,3'd0},{2'd3,3'd1,3'd4}: digit_pixel=1;
                {2'd3,3'd2,3'd4}: digit_pixel=1;
                {2'd3,3'd3,3'd2},{2'd3,3'd3,3'd3}: digit_pixel=1;
                {2'd3,3'd4,3'd4}: digit_pixel=1;
                {2'd3,3'd5,3'd0},{2'd3,3'd5,3'd4}: digit_pixel=1;
                {2'd3,3'd6,3'd1},{2'd3,3'd6,3'd2},{2'd3,3'd6,3'd3}: digit_pixel=1;
                default: digit_pixel=0;
            endcase
        end
    endfunction
 
    // ----------------------------------------------------------------
    // POWERUP OLED PIXEL LOGIC
    // Each icon/digit function is called exactly once.
    // Row selection is handled by the shared ly/val muxes above.
    // ----------------------------------------------------------------
    always @(*) begin
        oled_data_powerup = `OLED_BLACK;
 
        // ---- ICON COLUMN ----
        if (in_icon_col) begin
            if (in_row0 && icon_bomb(icon_lx, icon_ly))
                oled_data_powerup = `OLED_ORANGE;
            if (in_row1 && icon_fire(icon_lx, icon_ly))
                oled_data_powerup = `OLED_RED;
            if (in_row2 && icon_bolt(icon_lx, icon_ly))
                oled_data_powerup = `OLED_YELLOW;
        end
 
        // ---- DIGIT COLUMN  (one call, shared mux selects row/val) ----
        if (in_digit_col && (in_dig_row0 || in_dig_row1 || in_dig_row2)
                && digit_pixel(dig_val, dig_lx, dig_ly[2:0]))
            oled_data_powerup = `OLED_WHITE;
    end
endmodule
