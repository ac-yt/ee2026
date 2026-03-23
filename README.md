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

### Version 2.1 (20/3/26 3am)

Changes Made:
* Added A* path planning for computer player (not yet fully integrated)
* Added A* into Top Student with map updates every 0.5s and screen drawing (to be removed later)
* Removed pixel map to reduce LUT usage (expand each pixel at the rendering step instead, manually draw border)
 
### Version 2.2 (21/3/26)

Changes Made:
* Moved A* into computer_controller module
* Changed tile_map_flat indexing to tile_map indexing in bomb/player controller

### Version 3.1 (24/3/26, Ashlee)

Changes Made:
* Changed player controller to use mouse and A* (plans path around blocks if possible, if cannot will run up to the closest block then stop)
* Created separate modules for player controller and computer controller (Movement controller is its own separate one now also)
* Made pairing work (did not work in previous versions) 

## Important To-dos
* Player/bomb controller
  * Make player dead work
  * Edit bomb controller to accept power up inputs

