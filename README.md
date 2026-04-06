# ee2026 bomberman :(

good luck to us

## Links to Docs
Week 8 Submission: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBi3j6bE-0gSoHyuGnY5BGSAQrdWeo4YJe-6jXEB19_51A?e=OcpXZ0

Report: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBU9xSwJj5MQ6xbADAzMiu1AXfPLSG2szBlvLrRMgCU2-s?e=QDlhi6


## Latest Version Changes (V3.6, 4/4)
LUT Usage: 95%
* Bot chases after player if there is empty path
  * Tiles adjacent to bombs are blocked (modified A* for the bombs_as_walls condition)
  * Bot leaves escape hunt if in danger AND a new bomb is placed in front of it OR no longer has a path to the player
* Added bot stun player
* Added stunned screen to powerup OLED


## Important To-dos
* If P1 stays in danger zone after bot reaches it should run away
* Allow placing bomb while escape hunt
* Add powerup collection for bot
* Double check that running A* in escape path/hunt works perfectly
