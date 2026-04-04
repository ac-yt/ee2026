# ee2026 bomberman :(

good luck to us

## Links to Docs
Week 8 Submission: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBi3j6bE-0gSoHyuGnY5BGSAQrdWeo4YJe-6jXEB19_51A?e=OcpXZ0

Report: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBU9xSwJj5MQ6xbADAzMiu1AXfPLSG2szBlvLrRMgCU2-s?e=QDlhi6


## Latest Version Changes (V3.6, 4/4)
LUT Usage: 84%
* Added only show resume button during game for multi
* Added countdown and start game and game over display
* Added check all four corners for player dead
* Fixed bug where players sometimes did not get revived when game restarted
* Fixed bug where in multiplayer when one player clicks the other auto moves to its old path from previous game


## Important To-dos
* Fix power up bug
* Add show both powerups on P1
* (KIV) Fix bot following player if there is safe path while bomb is exploding
* Save state (save tile map, player positions, player stats) only for single state (do not do for multi-state because too many variables already)
* Make pairing FSM use debounced buttons (move debounce to separate module for organisation)
* Add dash/extra thing when the player runs out of bombs
* (KIV) Add second difficulty/toggle for only see certain radius around player in single mode
