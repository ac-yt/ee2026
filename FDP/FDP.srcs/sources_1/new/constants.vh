// constants.vh
`define CLOCK_SPEED   100_000_000
`define BAUD_RATE     115200
`define DATA_BITS     16
`define CODE_BITS     8
`define GAME_BITS     (`DATA_BITS - `CODE_BITS)

`define PLAYER_1      0
`define PLAYER_2      1

// pairing states
`define SINGLE          3'b000
`define REQUEST         3'b001
`define WAIT_ACK        3'b010
`define CONFIRM         3'b011
`define ACKNOWLEDGE     3'b100
`define WAIT_CONFIRM    3'b101
`define PAIRED          3'b110

// map parameters
`define TILE_SIZE       6 // size of each tile
`define TILE_MAP_WIDTH  15 // number of tiles along x axis
`define TILE_MAP_HEIGHT 9 // number of tiles along y axis
`define TILE_MAP_SIZE   135
`define PIX_MAP_WIDTH   96 // number of pixels along x axis
`define PIX_MAP_HEIGHT  64 // number of pixels along y axis
`define MIN_PIX_X       3 // first pixel x in playable area (number of pixels padded left/right)
`define MIN_PIX_Y       5 // first pixel y in playable area(number of pixels padded up/down)
`define MAX_PIX_X       (`PIX_MAP_WIDTH-1 - `MIN_PIX_X) // >92, last pixel x in playable area
`define MAX_PIX_Y       (`PIX_MAP_HEIGHT-1 - `MIN_PIX_Y) // >93, last pixel y in playable area

// tile codes
// 3 bits required to represent all the possible states (empty, wall, block, bomb, powerup1/2/3)
`define MAP_EMPTY       3'b000 // code for empty tile/pixel
`define MAP_WALL        3'b001 // code for wall tile/pixel
`define MAP_BLOCK       3'b010 // code for block tile/pixel
`define MAP_BOMB        3'b011 // code for bomb tile/pixel
`define MAP_POWERUP     3'b100 // code for powerup tile/pixel

// path parameters
`define MAX_PATH_LEN    40 // 81
`define MAX_NUM_NODES   40 // 81 // 107

// oled colors
`define OLED_WHITE      16'hFFFF
`define OLED_BLACK      0
`define OLED_RED        16'hF800
`define OLED_ORANGE     16'b11111_100000_00000
`define OLED_YELLOW     16'b11111_111111_00000
`define OLED_GREEN      16'h07E0
`define OLED_CYAN       16'b00000_111111_11111
`define OLED_BLUE       16'b00000_000000_11111
`define OLED_MAGENTA    16'b11111_000000_11111
`define OLED_GREY       16'b01011_010111_01011

// player width
`define PLAYER_WIDTH    3'b100
`define PLAYER_HEIGHT   3'b100

// single player
`define PATH_SPEED      (`CLOCK_SPEED / 2)
`define COMPUTER_SPEED  15
`define UPDATE_TIME     (12 * `PATH_SPEED * `TILE_SIZE) / (10 * `COMPUTER_SPEED) // 1.2 times the time taken to travel between tiles