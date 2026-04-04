// font.vh

`include "constants.vh"

reg [`CHAR_WIDTH_SMALL-1:0] font_rom [0:127][0:`CHAR_HEIGHT_SMALL-1];
reg [`CHAR_WIDTH_BIG-1:0] font_rom_big [0:127][0:`CHAR_HEIGHT_BIG-1];

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
    
    // 3
    font_rom_big["3"][0]  = 9'b001111100;
    font_rom_big["3"][1]  = 9'b011111111;
    font_rom_big["3"][2]  = 9'b110000011;
    font_rom_big["3"][3]  = 9'b000000110;
    font_rom_big["3"][4]  = 9'b001111100;
    font_rom_big["3"][5]  = 9'b001111100;
    font_rom_big["3"][6]  = 9'b000000110;
    font_rom_big["3"][7]  = 9'b110000011;
    font_rom_big["3"][8]  = 9'b110000011;
    font_rom_big["3"][9]  = 9'b011111111;
    font_rom_big["3"][10] = 9'b001111100;
    
    // 2
    font_rom_big["2"][0]  = 9'b001111110;
    font_rom_big["2"][1]  = 9'b011111111;
    font_rom_big["2"][2]  = 9'b110000011;
    font_rom_big["2"][3]  = 9'b110000111;
    font_rom_big["2"][4]  = 9'b000001110;
    font_rom_big["2"][5]  = 9'b000011100;
    font_rom_big["2"][6]  = 9'b000111000;
    font_rom_big["2"][7]  = 9'b001110000;
    font_rom_big["2"][8]  = 9'b011100000;
    font_rom_big["2"][9]  = 9'b111111111;
    font_rom_big["2"][10] = 9'b111111111;
    
    // 1
    font_rom_big["1"][0]  = 9'b000011000;
    font_rom_big["1"][1]  = 9'b001111000;
    font_rom_big["1"][2]  = 9'b011011000;
    font_rom_big["1"][3]  = 9'b110011000;
    font_rom_big["1"][4]  = 9'b000011000;
    font_rom_big["1"][5]  = 9'b000011000;
    font_rom_big["1"][6]  = 9'b000011000;
    font_rom_big["1"][7]  = 9'b000011000;
    font_rom_big["1"][8]  = 9'b000011000;
    font_rom_big["1"][9]  = 9'b111111111;
    font_rom_big["1"][10] = 9'b111111111;
    
    // 0
    font_rom_big["0"][0]  = 9'b001111100;
    font_rom_big["0"][1]  = 9'b011111110;
    font_rom_big["0"][2]  = 9'b111000111;
    font_rom_big["0"][3]  = 9'b110000011;
    font_rom_big["0"][4]  = 9'b110000011;
    font_rom_big["0"][5]  = 9'b110000011;
    font_rom_big["0"][6]  = 9'b110000011;
    font_rom_big["0"][7]  = 9'b110000011;
    font_rom_big["0"][8]  = 9'b111000111;
    font_rom_big["0"][9]  = 9'b011111110;
    font_rom_big["0"][10] = 9'b001111100;
    
    // G
    font_rom_big["G"][0]  = 9'b001111110;
    font_rom_big["G"][1]  = 9'b011111111;
    font_rom_big["G"][2]  = 9'b111000000;
    font_rom_big["G"][3]  = 9'b110000000;
    font_rom_big["G"][4]  = 9'b110001110;
    font_rom_big["G"][5]  = 9'b110001111;
    font_rom_big["G"][6]  = 9'b110000011;
    font_rom_big["G"][7]  = 9'b110000011;
    font_rom_big["G"][8]  = 9'b111000011;
    font_rom_big["G"][9]  = 9'b011111111;
    font_rom_big["G"][10] = 9'b001111110;
    
    // V
    font_rom_big["V"][0]  = 9'b110000011;
    font_rom_big["V"][1]  = 9'b110000011;
    font_rom_big["V"][2]  = 9'b110000011;
    font_rom_big["V"][3]  = 9'b110000011;
    font_rom_big["V"][4]  = 9'b011000110;
    font_rom_big["V"][5]  = 9'b011000110;
    font_rom_big["V"][6]  = 9'b001101100;
    font_rom_big["V"][7]  = 9'b001101100;
    font_rom_big["V"][8]  = 9'b000111000;
    font_rom_big["V"][9]  = 9'b000111000;
    font_rom_big["V"][10]  = 9'b000010000;
    
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
    
    // !
    font_rom["!"][0] = 5'b00100; 
    font_rom["!"][1] = 5'b01110;
    font_rom["!"][2] = 5'b01110; 
    font_rom["!"][3] = 5'b01110;
    font_rom["!"][4] = 5'b00100; 
    font_rom["!"][5] = 5'b00000;
    font_rom["!"][6] = 5'b00100;
    
    // 2
    font_rom["2"][0] = 5'b01110; 
    font_rom["2"][1] = 5'b10001;
    font_rom["2"][2] = 5'b00010; 
    font_rom["2"][3] = 5'b00100;
    font_rom["2"][4] = 5'b01000; 
    font_rom["2"][5] = 5'b10000;
    font_rom["2"][6] = 5'b11111;
    
    // 1
    font_rom["1"][0] = 5'b00100; 
    font_rom["1"][1] = 5'b01100;
    font_rom["1"][2] = 5'b10100; 
    font_rom["1"][3] = 5'b00100;
    font_rom["1"][4] = 5'b00100; 
    font_rom["1"][5] = 5'b00100;
    font_rom["1"][6] = 5'b11111;
    
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

function draw_letter;
    input [6:0] x, y;
    input integer xc, yc;
    input [7:0] letter;
    integer row, col;
    begin
        draw_letter = 0;
        row = y - (yc - (`CHAR_HEIGHT_SMALL-1)/2); 
        col = x - (xc - (`CHAR_WIDTH_SMALL-1)/2);
        if (row >= 0 && row < `CHAR_HEIGHT_SMALL && col >= 0 && col < `CHAR_WIDTH_SMALL) begin
            draw_letter = font_rom[letter][row][`CHAR_WIDTH_SMALL-1-col];
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
        row = y - (yc - (`CHAR_HEIGHT_BIG-1)/2); 
        col = x - (xc - (`CHAR_WIDTH_BIG-1)/2);
        if (row >= 0 && row < `CHAR_HEIGHT_BIG && col >= 0 && col < `CHAR_WIDTH_BIG) begin
            draw_letter_big = font_rom_big[letter][row][`CHAR_WIDTH_BIG-1-col];
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