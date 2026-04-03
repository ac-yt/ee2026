# ee2026 bomberman :(

good luck to us

## Links to Docs
Week 8 Submission: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBi3j6bE-0gSoHyuGnY5BGSAQrdWeo4YJe-6jXEB19_51A?e=OcpXZ0

Report: https://nusu-my.sharepoint.com/:w:/g/personal/e1399074_u_nus_edu/IQBU9xSwJj5MQ6xbADAzMiu1AXfPLSG2szBlvLrRMgCU2-s?e=QDlhi6


## Latest Version Changes (V3.6, 4/4)
Changes:
* Integrated UI
  * Made pairing use a button, automatically unpair if leave game etc.
  * Added resetting based on UI to generate new map
* Added power up OLED as a module


## Important To-dos
* Fix power up bug
* Add sending power up data from P1/P2 or show both on P1
* Fix bot following player if there is safe path while bomb is exploding
* Save state (save tile map, player positions, player stats) only for single state (do not do for multi-state because too many variables already)
* Only show resume button when there is already a saved game (for single) or during the game (multi)
* Make pairing FSM use debounced buttons (move debounce to separate module for organisation)
* Add start game display (freeze players for short while) + game over display when someone dies
