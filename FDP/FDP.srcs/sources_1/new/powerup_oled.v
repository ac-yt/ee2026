`timescale 1ns / 1ps
module powerup_oled(input [6:0] pu_x, input [5:0] pu_y,
                    // P1 stats
                    input [1:0] p1_bomb_radius, p1_bomb_count, p1_speed_incr,
                    // P2 stats
                    input [1:0] p2_bomb_radius, p2_bomb_count, p2_speed_incr,
                    output reg [15:0] oled_data_powerup);

    // ----------------------------------------------------------------
    // LAYOUT  (96x64 px OLED, coordinates after 180-degree flip)
    //
    //  LEFT  HALF  x =  0..47  -> P1 power-ups
    //  RIGHT HALF  x = 48..95  -> P2 power-ups
    //
    //  Within each 48-wide half:
    //    Icons  centred at local_x = 16  (13x13 px)
    //    Digits centred at local_x = 36  ( 5x 7 px)
    //
    //  Row centres (shared):
    //    ROW0_CY = 16  (bomb  / bomb_radius)
    //    ROW1_CY = 32  (fire  / bomb_count)
    //    ROW2_CY = 48  (bolt  / speed_incr)
    //
    //  Divider: white vertical line at x = 47
    // ----------------------------------------------------------------

    // --- which half? ---
    wire in_left_half  = (pu_x < 7'd48);
    wire in_right_half = (pu_x >= 7'd48);

    // Local x within each half (0..47)
    wire [5:0] local_x = in_left_half ? pu_x[5:0] : (pu_x[5:0] - 6'd0); // see below
    // Note: pu_x[5:0] gives bits [5:0]; for right half we subtract 48
    wire [5:0] local_x_w = in_left_half ? pu_x[5:0] : (pu_x - 6'd48);

    // --- geometry constants (within a half) ---
    localparam ICON_LCX  = 6'd16;
    localparam DIGIT_LCX = 6'd36;

    localparam ROW0_CY  = 6'd16;
    localparam ROW1_CY  = 6'd32;
    localparam ROW2_CY  = 6'd48;

    // ----------------------------------------------------------------
    // COLUMN CHECKS  (based on local_x_w)
    // ----------------------------------------------------------------
    wire in_icon_col  = (local_x_w >= ICON_LCX  - 6) && (local_x_w <= ICON_LCX  + 6);
    wire in_digit_col = (local_x_w >= DIGIT_LCX - 2) && (local_x_w <= DIGIT_LCX + 2);

    wire [3:0] icon_lx = local_x_w - (ICON_LCX - 6);
    wire [2:0] dig_lx  = local_x_w - (DIGIT_LCX - 2);

    // ----------------------------------------------------------------
    // ROW DETECTION
    // ----------------------------------------------------------------
    wire in_row0 = (pu_y >= ROW0_CY - 6) && (pu_y <= ROW0_CY + 6);
    wire in_row1 = (pu_y >= ROW1_CY - 6) && (pu_y <= ROW1_CY + 6);
    wire in_row2 = (pu_y >= ROW2_CY - 6) && (pu_y <= ROW2_CY + 6);

    wire in_dig_row0 = (pu_y >= ROW0_CY - 3) && (pu_y <= ROW0_CY + 3);
    wire in_dig_row1 = (pu_y >= ROW1_CY - 3) && (pu_y <= ROW1_CY + 3);
    wire in_dig_row2 = (pu_y >= ROW2_CY - 3) && (pu_y <= ROW2_CY + 3);

    // ----------------------------------------------------------------
    // LOCAL Y COORDS
    // ----------------------------------------------------------------
    wire [3:0] icon_ly = in_row0 ? (pu_y - (ROW0_CY - 6)) :
                         in_row1 ? (pu_y - (ROW1_CY - 6)) :
                                   (pu_y - (ROW2_CY - 6));

    wire [3:0] dig_ly  = in_dig_row0 ? (pu_y - (ROW0_CY - 3)) :
                         in_dig_row1 ? (pu_y - (ROW1_CY - 3)) :
                                       (pu_y - (ROW2_CY - 3));

    // Stat mux: left=P1, right=P2
    wire [1:0] val_bomb_radius = in_left_half ? p1_bomb_radius : p2_bomb_radius;
    wire [1:0] val_bomb_count  = in_left_half ? p1_bomb_count  : p2_bomb_count;
    wire [1:0] val_speed_incr  = in_left_half ? p1_speed_incr  : p2_speed_incr;

    wire [1:0] dig_val = in_dig_row0 ? val_bomb_count  :
                         in_dig_row1 ? val_bomb_radius :
                                       val_speed_incr;

    // ----------------------------------------------------------------
    // PLAYER LABEL: "P1" / "P2"
    // Rendered at local_x = 20..26, pu_y = 2..6 (5 rows tall, 7 cols wide)
    // ----------------------------------------------------------------
    wire in_label_row = (pu_y >= 6'd2) && (pu_y <= 6'd6);
    wire in_P_col     = (local_x_w >= 6'd20) && (local_x_w <= 6'd22);
    wire in_num_col   = (local_x_w >= 6'd24) && (local_x_w <= 6'd26);
    wire [2:0] lbl_ly     = pu_y - 6'd2;
    wire [2:0] lbl_lx_P   = local_x_w - 6'd20;
    wire [2:0] lbl_lx_num = local_x_w - 6'd24;

    // "P" glyph 3x5
    function letter_P;
        input [2:0] lx; input [2:0] ly;
        begin
            case ({ly, lx})
                {3'd0,3'd0},{3'd0,3'd1},{3'd0,3'd2}: letter_P=1;
                {3'd1,3'd0},{3'd1,3'd2}:             letter_P=1;
                {3'd2,3'd0},{3'd2,3'd1},{3'd2,3'd2}: letter_P=1;
                {3'd3,3'd0}:                         letter_P=1;
                {3'd4,3'd0}:                         letter_P=1;
                default:                             letter_P=0;
            endcase
        end
    endfunction

    // "1" glyph 3x5
    function letter_1;
        input [2:0] lx; input [2:0] ly;
        begin
            case ({ly, lx})
                {3'd0,3'd1}:                         letter_1=1;
                {3'd1,3'd0},{3'd1,3'd1}:             letter_1=1;
                {3'd2,3'd1}:                         letter_1=1;
                {3'd3,3'd1}:                         letter_1=1;
                {3'd4,3'd0},{3'd4,3'd1},{3'd4,3'd2}: letter_1=1;
                default:                             letter_1=0;
            endcase
        end
    endfunction

    // "2" glyph 3x5
    function letter_2;
        input [2:0] lx; input [2:0] ly;
        begin
            case ({ly, lx})
                {3'd0,3'd0},{3'd0,3'd1},{3'd0,3'd2}: letter_2=1;
                {3'd1,3'd2}:                         letter_2=1;
                {3'd2,3'd0},{3'd2,3'd1},{3'd2,3'd2}: letter_2=1;
                {3'd3,3'd0}:                         letter_2=1;
                {3'd4,3'd0},{3'd4,3'd1},{3'd4,3'd2}: letter_2=1;
                default:                             letter_2=0;
            endcase
        end
    endfunction

    wire draw_P  = in_label_row && in_P_col   && letter_P(lbl_lx_P, lbl_ly);
    wire draw_N1 = in_label_row && in_num_col && in_left_half  && letter_1(lbl_lx_num, lbl_ly);
    wire draw_N2 = in_label_row && in_num_col && in_right_half && letter_2(lbl_lx_num, lbl_ly);

    // ----------------------------------------------------------------
    // BOMB ICON  13x13  (orange)
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

    // LIGHTNING BOLT ICON  13x13  (yellow)
    //
    //  ly=0   .......###..   upper diagonal (top-right, stepping left)
    //  ly=1   ......###...
    //  ly=2   ......###...
    //  ly=3   .....###....
    //  ly=4   ....###.....
    //  ly=5   ...###......
    //  ly=6   ..###.......
    //  ly=7   .#########..   wide horizontal bar
    //  ly=8   .########...
    //  ly=9   .....###....   lower diagonal (continuing down-left)
    //  ly=10  ....###.....
    //  ly=11  ...###......
    //  ly=12  .###........   bottom-left tip
    // ----------------------------------------------------------------
    function icon_bolt;
        input [3:0] lx, ly;
        begin
            case (ly)
                4'd0:  icon_bolt = (lx >= 4'd7 && lx <= 4'd9);
                4'd1:  icon_bolt = (lx >= 4'd6 && lx <= 4'd8);
                4'd2:  icon_bolt = (lx >= 4'd6 && lx <= 4'd8);
                4'd3:  icon_bolt = (lx >= 4'd5 && lx <= 4'd7);
                4'd4:  icon_bolt = (lx >= 4'd4 && lx <= 4'd6);
                4'd5:  icon_bolt = (lx >= 4'd3 && lx <= 4'd5);
                4'd6:  icon_bolt = (lx >= 4'd2 && lx <= 4'd4);
                4'd7:  icon_bolt = (lx >= 4'd1 && lx <= 4'd9);
                4'd8:  icon_bolt = (lx >= 4'd1 && lx <= 4'd8);
                4'd9:  icon_bolt = (lx >= 4'd5 && lx <= 4'd7);
                4'd10: icon_bolt = (lx >= 4'd4 && lx <= 4'd6);
                4'd11: icon_bolt = (lx >= 4'd3 && lx <= 4'd5);
                4'd12: icon_bolt = (lx >= 4'd1 && lx <= 4'd3);
                default: icon_bolt = 0;
            endcase
        end
    endfunction

    // ----------------------------------------------------------------
    // DIGIT PIXEL  (5x7 ROM, values 0-3)
    // ----------------------------------------------------------------
    function digit_pixel;
        input [1:0] val;
        input [2:0] dx;
        input [3:0] dy;
        begin
            case ({val, dy[2:0], dx})
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
    // PIXEL OUTPUT
    // ----------------------------------------------------------------
    always @(*) begin
        oled_data_powerup = `OLED_BLACK;

        // Vertical divider at x=47
        if (pu_x == 7'd47)
            oled_data_powerup = `OLED_WHITE;

        // Player labels
        if (draw_P || draw_N1 || draw_N2)
            oled_data_powerup = `OLED_WHITE;

        // ---- ICON COLUMN ----
        if (in_icon_col) begin
            if (in_row0 && icon_bomb(icon_lx, icon_ly))
                oled_data_powerup = `OLED_ORANGE;
            if (in_row1 && icon_fire(icon_lx, icon_ly))
                oled_data_powerup = `OLED_RED;
            if (in_row2 && icon_bolt(icon_lx, icon_ly))
                oled_data_powerup = `OLED_YELLOW;
        end

        // ---- DIGIT COLUMN ----
        if (in_digit_col && (in_dig_row0 || in_dig_row1 || in_dig_row2)
                && digit_pixel(dig_val, dig_lx, dig_ly[2:0]))
            oled_data_powerup = `OLED_WHITE;
    end
endmodule