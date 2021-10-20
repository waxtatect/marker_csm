## marker

CSM for Minetest, compatible with v0.4.16 (limited HUD support through `/mrkr` if  provided) until v5.0.0+*

*May require server CSM restriction flags adjustment for chat_messages

### Usage examples

`.mrkr Space`: save the current position as "Space"  
`.go Space`: display HUD for "Space" marker  
`.go Space`: remove HUD for "Space" marker  
`.hud Space`: display HUD for "Space" marker and save it - allow to display multiple HUDs if still present in marker list  
`.mrkr del Space`: delete "Space" from marker list

`.hud here`: display a temporary HUD at the current position - up to "here9"  
`.hud here`: remove HUD "here"

### Going further . . .

Read available help thanks to the following chat commands: `.mrkr help`, `.hud help`