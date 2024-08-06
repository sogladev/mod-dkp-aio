
local ADDON_NAME = "AIODKP"
local AIO = AIO or require("AIO")
local DKPHandlers = {}
local DKP = {}
AIO.AddHandlers(ADDON_NAME, DKPHandlers)

local PLAYER_EVENT_ON_STORE_NEW_ITEM = 53
local PLAYER_EVENT_ON_COMMAND  = 42 -- (event, player, command, chatHandler) - player is nil if command used from console. Can return false
local PACKET_EVENT_ON_PACKET_RECEIVE = 5 -- (event, packet, player) - Player only if accessible. Can return false, newPacket

local Blacklist = {
    [47241]=true, -- Emblem of Triumph
}


local Status = {
  PENDING = 1,
  BIDDING = 2,
  ASSIGNED = 3,
}

local Separator = {
  ARG = ";",
  ELEMENT = "+",
  LIST_ELEMENT = "^",
  MESSAGE = "&",
  SUBLIST_ELEMENT = "/",
}

function DKP.Split(str, sep)
    local t = {}
    for s in str:gmatch("([^"..sep.."]+)") do
        table.insert(t, s)
    end
    return t
end

local sessions = {}

local function OnPlayerEventOnStoreNewItem(event, player, item, count)
    print("OnPlayerEventOnStoreNewItem")
	print(player:GetName() .. " won " .. item:GetName() .. " (x" .. count .. ")")
    -- check if item is on blacklist
    if Blacklist[item:GetEntry()] then print("OnPlayerEventOnStoreNewItem:blacklist") return end
    -- add item to session tied to instance
    local instanceId = player:GetInstanceId()
    -- get session from instanceId
    sessions[instanceId] = sessions[instanceId] or {} -- new session if not exists
    sessions[instanceId].rows = sessions[instanceId].rows or {} -- new rows if not exists
    local rowId = #sessions[instanceId].rows+1
    local itemRow = {id=rowId, itemId=item:GetEntry(), status=Status.PENDING} -- add item_soulbound_trade_data (player low guids)
    table.insert(sessions[instanceId].rows, rowId, itemRow)
    print(string.format("Added item (Entry: %d, GUIDLow: %d) to session instanceId %d", item:GetEntry(), item:GetGUIDLow(), instanceId))
    -- remove item from player
    -- item:SaveToDB() -- Save item to DB before we remove it from the player
    player:SaveToDB() -- must be called before RemoveItem else crash
    player:RemoveItem(item, count) -- remove item becomes ghost? can no longer select
    player:SaveToDB() -- save again to remove item from item_instance ?
    -- add item to trading blacklist
end

-- RegisterPlayerEvent(PLAYER_EVENT_ON_STORE_NEW_ITEM, OnPlayerEventOnStoreNewItem)

local function AddItemToSession(player, itemId)
    local instanceId = player:GetInstanceId()
    -- get session from instanceId
    sessions[instanceId] = sessions[instanceId] or {} -- new session if not exists
    sessions[instanceId].rows = sessions[instanceId].rows or {} -- new rows if not exists
    local rowId = #sessions[instanceId].rows+1
    local itemRow = {id=rowId, itemId=itemId, status=Status.PENDING} -- add item_soulbound_trade_data (player low guids)
    table.insert(sessions[instanceId].rows, rowId, itemRow)
    print(string.format("Added item (Entry: %d) to session instanceId %d", itemId, instanceId))
end

local function OnLootFrameOpen(event, packet, player)
    local selection = player:GetSelection()
    local creature = selection:ToCreature()
    print("Creature ", creature:GetName())
    local loot = creature:GetLoot()
    print("GetItems")
    local items = loot:GetItems()
    local nItems = #loot:GetItems()
    print("Printing items")
    for i, loot_data in ipairs(items) do
        print("------------", i)
        print(loot_data)
        print(type(loot_data))
        for k, v in pairs(loot_data) do
            print(k)
            print(v)
        end
    end
    -- filter and add items to session
    for _, loot_data in pairs(items) do
        if not loot_data.needs_quest and not Blacklist[loot_data.id] then
            AddItemToSession(player, loot_data.id) -- add item by id to session
            loot:RemoveItem(loot_data.id)
            nItems = nItems - 1
            loot:UpdateItemIndex()
        end
    end
    loot:SetUnlootedCount(nItems) -- update loot item count
  end

function DKP.EncodeRow(row)
  return table.concat({row.id, row.itemId, row.status}, Separator.LIST_ELEMENT)
end

function DKP.EncodeSession(session)
  local encodedRows = {}
  local rows = session.rows or {}
  for _, row in pairs(rows) do
    local encodedRow = DKP.EncodeRow(row)
    table.insert(encodedRows, encodedRow)
  end
  return table.concat(encodedRows, Separator.ELEMENT)
end

function DKPHandlers.RequestSync(player)
    PrintInfo(string.format("%s:DKPHandlers.RequestSync(player) by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
    local instanceId = player:GetInstanceId()
    local session = sessions[instanceId] or {} -- new session if not exists
    local encodedSession = DKP.EncodeSession(session)
    AIO.Handle(player, ADDON_NAME, "SyncResponse", encodedSession)
end

function DKPHandlers.RequestClaim(player)
    PrintInfo(string.format("%s:DKPHandlers.RequestClaim(player) by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
    local instanceId = player:GetInstanceId()
    local session = sessions[instanceId]
    if not session then
        PrintError("No session found")
        return
    end
    -- select item
    local row = session.rows[1] -- take first item for testing
    local itemId = row.itemId
    -- add item
    if not row.claimed then
        player:AddItem(itemId, 1)
    end
    -- set tradeable item
    sessions[instanceId].rows[1].claimed = true -- set claimed
end


local function OnCommand(event, player, command)
    PrintInfo(string.format("%s:OnCommand %s by account-name (%d-%s)", ADDON_NAME, command, player:GetAccountId(), player:GetName()))
    local splitCommand = DKP.Split(command, " ")
    local cmd, arg = splitCommand[1], splitCommand[2]
    if cmd == "dkp" and arg == "open" then
        PrintInfo(string.format("%s:OnCommand '.dkp open' by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
        -- DKPHandlers.RequestPayout(player, true)
        return false
    elseif cmd == "dkp" and arg == "sync" then
        PrintInfo(string.format("%s:OnCommand '.dkp sync' by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
        DKPHandlers.RequestSync(player)
        return false
    elseif cmd == "dkp" and arg == "claim" then
        PrintInfo(string.format("%s:OnCommand '.dkp claim' by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
        DKPHandlers.RequestClaim(player)
        return false
    elseif cmd == "dkp" then
        PrintInfo(string.format("%s:OnCommand .dkp by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
        AIO.Handle(player, ADDON_NAME, "ShowFrame")
        return false
    end
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnCommand)
RegisterPacketEvent(0x15D, PACKET_EVENT_ON_PACKET_RECEIVE, OnLootFrameOpen)
