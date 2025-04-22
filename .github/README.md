# Module DKP

(WIP) This is a module compatible for [AzerothCore](http://www.azerothcore.org) that implements a DKP system with modified ElunaLUA and AIO

https://github.com/user-attachments/assets/07f8fa4a-1a59-4ca6-8b88-098e2bb627f7


## Features
* GDKP without requiring loot master
* server-side logic to handle bids, trading, ~~cuts~~

 ## Requirements
AIO https://github.com/Rochet2/AIO/tree/master

apply diff to Eluna to allow for Loot methods

https://github.com/laasker/lua_aoe_loot/blob/main/azerothcore_eluna.diff


AOE Loot patch is used as a hack to access the created loot
```
local function OnLootFrameOpen(event, packet, player)
    local selection = player:GetSelection()
    local creature = selection:ToCreature()
    local loot = creature:GetLoot() <--
    local items = loot:GetItems() <--
```

## Tested with
AzerothCore

## Credits
https://github.com/Rochet2/AIO/tree/master
https://github.com/laasker/lua_aoe_loot/blob/main/azerothcore_eluna.diff

## How to create your own module

1. Use the script `create_module.sh` located in [`modules/`](https://github.com/azerothcore/azerothcore-wotlk/tree/master/modules) to start quickly with all the files you need and your git repo configured correctly (heavily recommended).
1. You can then use these scripts to start your project: https://github.com/azerothcore/azerothcore-boilerplates
1. Do not hesitate to compare with some of our newer/bigger/famous modules.
1. Edit the `README.md` and other files (`include.sh` etc...) to fit your module. Note: the README is automatically created from `README_example.md` when you use the script `create_module.sh`.
1. Publish your module to our [catalogue](https://github.com/azerothcore/modules-catalogue).
