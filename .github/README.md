# Module DKP

(WIP) This is a module compatible for [AzerothCore](http://www.azerothcore.org) that implements a DKP system with modified ElunaLUA and AIO



## Features
* GDKP without requiring loot master
* server-side logic to handle bids, trading, cuts

 ## Requirements
AIO https://github.com/Rochet2/AIO/tree/master

apply diff to Eluna to allow for Loot methods
https://github.com/iThorgrim/lua_aoe_loot/blob/main/eluna_modifications/azerothcore_eluna.diff

## Tested with
AzerothCore

## Credits
https://github.com/Rochet2/AIO/tree/master
https://github.com/iThorgrim/lua_aoe_loot/blob/main/eluna_modifications/azerothcore_eluna.diff

## How to create your own module

1. Use the script `create_module.sh` located in [`modules/`](https://github.com/azerothcore/azerothcore-wotlk/tree/master/modules) to start quickly with all the files you need and your git repo configured correctly (heavily recommended).
1. You can then use these scripts to start your project: https://github.com/azerothcore/azerothcore-boilerplates
1. Do not hesitate to compare with some of our newer/bigger/famous modules.
1. Edit the `README.md` and other files (`include.sh` etc...) to fit your module. Note: the README is automatically created from `README_example.md` when you use the script `create_module.sh`.
1. Publish your module to our [catalogue](https://github.com/azerothcore/modules-catalogue).
