
local ADDON_NAME = "AIODKP"
local AIO = AIO or require("AIO")
local DKPHandlers = {}
local DKP = {}
AIO.AddHandlers(ADDON_NAME, DKPHandlers)

local PLAYER_EVENT_ON_COMMAND  = 42 -- (event, player, command, chatHandler) - player is nil if command used from console. Can return false
local PACKET_EVENT_ON_PACKET_RECEIVE = 5 -- (event, packet, player) - Player only if accessible. Can return false, newPacket
local CMSG_LOOT = 0x15D

local Sessions = {}

local BlacklistItems = {
    [47241] = true, -- Emblem of Triumph
}

local Status = {
  PENDING = 1,
  BIDDING = 2,
  ASSIGNED = 3,
  CLAIMED = 4,
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


local Item = {}
Item.__index = Item
DKP.Item = Item
function Item:CreateForId(index, id)
    local item = {id=index, itemId=id, status=Status.PENDING}
    setmetatable(item, Item)
    return item
end


function Item:Encode()
  return table.concat({self.id, self.itemId, self.status}, Separator.LIST_ELEMENT)
end


local Session = {}
Session.__index = Session
DKP.Session = Session
function Session:CreateForPlayer(player)
    local instanceId = player:GetInstanceId()
    if Sessions[instanceId] then return Sessions[instanceId] end
    print("Session:CreateForInstanceId: ", instanceId)
    local session = {id = instanceId, items = {}}
    -- TODO: add session defaults like expiration, minIncrement, minPrice
    -- add participants
    local group = player:GetGroup()
    local groupPlayers = group:GetMembers()
    local playerGUIDs = {}
    for _, player in pairs(groupPlayers) do
        table.insert(playerGUIDs, player:GetGUID())
    end
    session.playerGUIDs = playerGUIDs
    setmetatable(session, Session)
    Sessions[instanceId] = session
    return session
end


function Session:GetNextIndex()
  local maxIndex = 0
  for index, _ in pairs(self.items) do
    maxIndex = math.max(maxIndex, index)
  end
  return maxIndex + 1
end


function Session:AddItemById(itemId)
    print("Session:AddItem")
    print(itemId)
    local index = self:GetNextIndex()
    local item = Item:CreateForId(index, itemId)
    self.items[index] = item
    print("#self.items", #self.items)
    print(string.format("Added item (Entry: %d) to session instanceId %d", itemId, self.id))
    return item
end


function Session:SetItemClaimed(itemId)
    self.items[itemId].status = Status.CLAIMED
end


function Session:Encode()
  local encodedItems = {}
  for _, item in pairs(self.items) do
    local encodedItem = item:Encode()
    table.insert(encodedItems, encodedItem)
  end
  return table.concat(encodedItems, Separator.ELEMENT)
end


function Session:OnNewItems(newItems)
    -- Encode new items
    local encodedItems = {}
    for _, item in pairs(newItems) do
        local encodedItem = item:Encode()
        table.insert(encodedItems, encodedItem)
    end
    local encodedItemsStr = table.concat(encodedItems, Separator.ELEMENT)
    -- Announce new items
    for i, playerGUID in pairs(self.playerGUIDs) do
        local player = GetPlayerByGUID(playerGUID)
        player:SendAreaTriggerMessage("New items added to loot session")
        AIO.Handle(player, ADDON_NAME, "NewItemsAdded", encodedItemsStr)
    end
end


function Session:OnChange()
    for i, playerGUID in pairs(self.playerGUIDs) do
        local player = GetPlayerByGUID(playerGUID)
        DKPHandlers.RequestSync(player)
    end
end


local function OnLootFrameOpen(event, packet, player)
    local selection = player:GetSelection()
    local creature = selection:ToCreature()
    print("Creature ", creature:GetName())
    local loot = creature:GetLoot()
    print("GetItems")
    local items = loot:GetItems()
    local nItems = #loot:GetItems()
    -- prints
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
    local session = Session:CreateForPlayer(player)
    local newItems = {}
    for _, loot_data in pairs(items) do
        if not loot_data.needs_quest and not BlacklistItems[loot_data.id] then
            local item = session:AddItemById(loot_data.id)
            table.insert(newItems, item)
            loot:RemoveItem(loot_data.id)
            nItems = nItems - 1
        end
    end
    loot:UpdateItemIndex()
    loot:SetUnlootedCount(nItems) -- update loot item count
    session:OnNewItems(newItems)
    session:OnChange()
end


function DKPHandlers.RequestSync(player)
    PrintInfo(string.format("%s:DKPHandlers.RequestSync(player) by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
    local session = Session:CreateForPlayer(player)
    print("#session.rows", #session.items)
    print("session id ", session.id)
    local encodedSession = session:Encode()
    print("Encoded session: ", encodedSession)
    AIO.Handle(player, ADDON_NAME, "SyncResponse", encodedSession)
end


function DKPHandlers.RequestClaim(player, id)
    PrintInfo(string.format("%s:DKPHandlers.RequestClaim(player) by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
    local session = Session:CreateForPlayer(player)
    if not session then
        PrintError("No session found")
        return
    end
    -- select item
    local item = session.items[id] -- take first item for testing
    local itemId = item.itemId
    -- add item
    if item.status ~= Status.CLAIMED then
        player:AddItem(itemId, 1) -- (entry, count)
        session:SetItemClaimed(id)
    end
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
        DKPHandlers.RequestClaim(player, 1) -- id 1 for testing
        return false
    elseif cmd == "dkp" and arg == "test" then
        PrintInfo(string.format("%s:OnCommand '.dkp test' by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
        return false
    elseif cmd == "dkp" then
        PrintInfo(string.format("%s:OnCommand .dkp by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
        AIO.Handle(player, ADDON_NAME, "ShowFrame")
        return false
    end
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnCommand)
RegisterPacketEvent(CMSG_LOOT, PACKET_EVENT_ON_PACKET_RECEIVE, OnLootFrameOpen)
