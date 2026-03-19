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

Important To-dos:
* Fix player controller timing issue (WNS is too high for the clock speed)
* Verify player/bomb controller and improve efficiency
* Finalize path planning for computer
  * Set start and goal positions to real ones (computer / player)
  * Modularize into its own module
  * Remove path drawing on screen
