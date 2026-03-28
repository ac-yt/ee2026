# ee2026 bomberman :(

good luck to us

## Links to Docs
Week 8 Submission: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBi3j6bE-0gSoHyuGnY5BGSAQrdWeo4YJe-6jXEB19_51A?e=OcpXZ0

Report: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBU9xSwJj5MQ6xbADAzMiu1AXfPLSG2szBlvLrRMgCU2-s?e=QDlhi6


## Latest Version Changes (V3.4, 29/3)
* Bomb controller updates
  * Allows place multiple bombs and radius up to 2 (currently use switches to decide)
  * Uses FSM now to switch between idle, countdown, explode
  * Removed redundant counter for bomb red, used countdown counter to decide when bomb is red
  * Maximum bomb count and radius is a constant in constants.vh
* Integration of bomb controller
  * Instantiated into p1/p2 controller
  * Top Student
    * Packed p1/p2 bomb parameters into a 2D array for indexing and for loop
    * Added sequential block to calculate reach of bombs (nested for loop loops over each player and then each bomb slot for the player), triggered every time a bomb is placed (only calculates reach when a bomb is placed)
    * Edited tile map update block to add for loop for updating of bombs on map
    * Edited rendering block to add for loop for rendering of bombs

## Important To-dos
* Add MAP_BLAST to tile map for use in bot logic
* Change bomb rendering to use MAP_BLAST and make bomb explosion fill
* Fix player dead (change from output to input in p1/p2 and use MAP_BLAST to check)
* Fix bug where player may run into explosion (using MAP_BLAST)
* Add in power up collection and connect it to each player bomb count/radius/speed
