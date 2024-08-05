
local ADDON_NAME = "AIODKP"
local AIO = AIO or require("AIO")
local DKPHandlers = {}
local DKP = {}
AIO.AddHandlers(ADDON_NAME, DKPHandlers)

local PLAYER_EVENT_ON_STORE_NEW_ITEM = 53
local PLAYER_EVENT_ON_COMMAND  = 42 -- (event, player, command, chatHandler) - player is nil if command used from console. Can return false

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
    local itemRow = {id=rowId, item=item, itemId=item:GetEntry(), guid=item:GetGUIDLow(), status=Status.PENDING}
    table.insert(sessions[instanceId].rows, rowId, itemRow)
    print(string.format("Added item (Entry: %d, GUIDLow: %d) to session instanceId %d", item:GetEntry(), item:GetGUIDLow(), instanceId))
    -- remove item from player
    item:SaveToDB() -- Save item to DB before we remove it from the player
    player:SaveToDB() -- must be called before RemoveItem else crash
    player:RemoveItem(item, count)
end

RegisterPlayerEvent(PLAYER_EVENT_ON_STORE_NEW_ITEM, OnPlayerEventOnStoreNewItem)

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

local function OnCommand(event, player, command)
    PrintInfo(string.format("%s:OnCommand %s by account-name (%d-%s)", ADDON_NAME, command, player:GetAccountId(), player:GetName()))
    if command == "dkp" then
        PrintInfo(string.format("%s:OnCommand .dkp by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
        AIO.Handle(player, ADDON_NAME, "ShowFrame")
        return false
    end
    if command == "dkpopen" then
        PrintInfo(string.format("%s:OnCommand .dkpopen by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
        -- DKPHandlers.RequestPayout(player, true)
        return false
    end
    if command == "dkpsync" then
        PrintInfo(string.format("%s:OnCommand .dkpsync by account-name (%d-%s)", ADDON_NAME, player:GetAccountId(), player:GetName()))
        DKPHandlers.RequestSync(player)
        return false
    end
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnCommand)
