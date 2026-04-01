# ee2026 bomberman :(

good luck to us

## Links to Docs
Week 8 Submission: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBi3j6bE-0gSoHyuGnY5BGSAQrdWeo4YJe-6jXEB19_51A?e=OcpXZ0

Report: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBU9xSwJj5MQ6xbADAzMiu1AXfPLSG2szBlvLrRMgCU2-s?e=QDlhi6


## Latest Version Changes (V3.4, 29/3)
Changes:
* Added power up collection
  * Made power up spawn rate a constant, made spawn rate 50%
* Added MAP_BLAST, made bomb explosion fill, changed bomb rendering to use expand tile
  * Changed to use FSM queue request instead of for loop to reduce LUT usage
* Added player dead
* Added MAP_BLAST as obstacle in A*
* Slowed down mouse movement to half the speed
* Moved the player goal position calculation inside the respective player controllers
* Made multiplayer mode show the game instead of a white screen

To do:
* Powerup OLED
* Integrate user interface
* Fix bot escape logic
* Add bot bomb player logic
