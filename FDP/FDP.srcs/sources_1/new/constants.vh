// constants.vh
`define BASYS_CLOCK_SPEED           100_000_000 //100_000_000
`define CLOCK_SPEED                 50_000_000 //100_000_000
`define BAUD_RATE                   115_200
`define DATA_BITS                   27 // 16 // 12 for mouse x, 12 for mouse y, 3 for mouse clicks
`define CODE_BITS                   8
`define GAME_BITS                   (`DATA_BITS - `CODE_BITS)

`define PLAYER_1                    0
`define PLAYER_2                    1

// pairing states
`define SINGLE                      3'b000
`define REQUEST                     3'b001
`define WAIT_ACK                    3'b010
`define CONFIRM                     3'b011
`define ACKNOWLEDGE                 3'b100
`define WAIT_CONFIRM                3'b101
`define PAIRED                      3'b110

// map gen state
`define RESET                       2'b00
`define GENERATION                  2'b01
`define GAMEPLAY                    2'b10

// map parameters
`define TILE_SIZE                   6 // size of each tile
`define TILE_MAP_WIDTH              15 // number of tiles along x axis
`define TILE_MAP_HEIGHT             9 // number of tiles along y axis
`define TILE_MAP_SIZE               135
`define PIX_WIDTH                   96 // number of pixels along x axis
`define PIX_HEIGHT                  64 // number of pixels along y axis
`define MIN_PIX_X                   3 // first pixel x in playable area (number of pixels padded left/right)
`define MIN_PIX_Y                   5 // first pixel y in playable area(number of pixels padded up/down)
`define MAX_PIX_X                   (`PIX_WIDTH-1 - `MIN_PIX_X) // >92, last pixel x in playable area
`define MAX_PIX_Y                   (`PIX_HEIGHT-1 - `MIN_PIX_Y) // >93, last pixel y in playable area

// tile codes
// 3 bits required to represent all the possible states (empty, wall, block, bomb, powerup1/2/3)
`define MAP_EMPTY                   3'b000 // code for empty tile/pixel
`define MAP_WALL                    3'b001 // code for wall tile/pixel
`define MAP_BLOCK                   3'b010 // code for block tile/pixel
`define MAP_BOMB                    3'b011 // code for bomb tile/pixel
`define MAP_POWERUP                 3'b100 // code for powerup tile/pixel
`define MAP_BLAST                   3'b101 // code for powerup tile/pixel

// bomb controller
`define MAX_BOMBS                   2
`define MAX_RADIUS                  2

// path parameters
`define MAX_PATH_LEN                40 // 81
`define MAX_OPEN_NODES              40//81 //40 // 81 // 107
`define MAX_CLOSED_NODES            135//81 //40 // 81 // 107

// player width
`define PLAYER_WIDTH                3'b100
`define PLAYER_HEIGHT               3'b100
`define PLAYER_DEFAULT_SPEED        35
`define PLAYER_SPEED_INCREMENT      8
`define PLAYER_MAX_SPEED            (`PLAYER_DEFAULT_SPEED + 2 * `PLAYER_SPEED_INCREMENT)

// single player
`define PATH_SPEED                  25_000_000
`define COMPUTER_DEFAULT_SPEED      25
`define COMPUTER_SPEED_INCREMENT    5
`define COMPUTER_MAX_SPEED          (`COMPUTER_DEFAULT_SPEED + 2 * `COMPUTER_SPEED_INCREMENT)
//`define PLAYER_UPDATE_TIME          (15 * `PATH_SPEED * `TILE_SIZE) / (10 * `PLAYER_DEFAULT_TIME) // 1.2 times the time taken to travel between tiles
//`define UPDATE_TIME                 (12 * `PATH_SPEED * `TILE_SIZE) / (10 * `COMPUTER_DEFAULT_SPEED) // 1.2 times the time taken to travel between tiles


// colors
`define OLED_RED          16'hF800
`define OLED_DARK_RED     16'hA000
`define OLED_LIGHT_RED    16'hFC10
`define OLED_MAROON       16'h6000
`define OLED_GREEN        16'h07E0
`define OLED_DARK_GREEN   16'h03E0
`define OLED_LIGHT_GREEN  16'h8FE0
`define OLED_LIME         16'h07C0
`define OLED_BLUE         16'h001F
`define OLED_DARK_BLUE    16'h000F
`define OLED_LIGHT_BLUE   16'h867F
`define OLED_NAVY         16'h0010
`define OLED_CYAN         16'h07FF
`define OLED_DARK_CYAN    16'h03EF
`define OLED_LIGHT_CYAN   16'h8FFF
`define OLED_MAGENTA      16'hF81F
`define OLED_DARK_MAGENTA 16'h8010
`define OLED_PINK         16'hFC1F
`define OLED_PURPLE       16'h601F
`define OLED_YELLOW       16'hFFE0
`define OLED_DARK_YELLOW  16'hA540
`define OLED_GOLD         16'hFD20
`define OLED_ORANGE       16'hFC60
`define OLED_WHITE        16'hFFFF
`define OLED_LIGHT_GREY   16'hC618
`define OLED_GREY         16'h8410
`define OLED_BLACK        16'h0000