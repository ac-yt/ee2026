# ee2026 bomberman :(

good luck to us

## Links to Docs
Week 8 Submission: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBi3j6bE-0gSoHyuGnY5BGSAQrdWeo4YJe-6jXEB19_51A?e=OcpXZ0

Report: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBU9xSwJj5MQ6xbADAzMiu1AXfPLSG2szBlvLrRMgCU2-s?e=QDlhi6


## Version History

### Version 1 (pre-Git)

Changes Made:
* Map setup + initialization of different map objects (empty, wall, block, bomb, powerup)
* Player movement (**need to fix)
* Bomb placing + bomb explosion

### Version 2.1 (20/3/26 3am, Ashlee)

Changes Made:
* Added A* path planning for computer player (not yet fully integrated)
* Added A* into Top Student with map updates every 0.5s and screen drawing (to be removed later)
* Removed pixel map to reduce LUT usage (expand each pixel at the rendering step instead, manually draw border)
 
### Version 2.2 (21/3/26, Ashlee)

Changes Made:
* Moved A* into computer_controller module
* Changed tile_map_flat indexing to tile_map indexing in bomb/player controller

## Important To-dos
* Player/bomb controller
  * Fix player controller timing issue (WNS is too high for the clock speed)
  * Verify player/bomb controller and improve efficiency
  * Make bomb controller compatible with computer
* Computer controller
  * Change to use BRAM to try and reduce LUT usage

