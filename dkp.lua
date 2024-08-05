
local PLAYER_EVENT_ON_STORE_NEW_ITEM = 53

local isEntryOnBlacklist = {
    [47241]=true, -- Emblem of Triumph
}

local Status = {
  PENDING = 1,
  BIDDING = 2,
  ASSIGNED = 3,
}

local sessions = {}

local function OnPlayerEventOnStoreNewItem(event, player, item, count)
    print("OnPlayerEventOnStoreNewItem")
	print(player:GetName() .. " won " .. item:GetName() .. " (x" .. count .. ")")
    -- check if item is on blacklist
    if isEntryOnBlacklist[item:GetEntry()] then print("OnPlayerEventOnStoreNewItem:blacklist") return end
    -- add item to session tied to instance
    local instanceId = player:GetInstanceId()
    -- get session from instanceId
    local session = sessions[instanceId] or {} -- new session if not exists
    session.rows = session.rows or {}
    local rowId = #session.rows+1
    local itemRow = {id=rowId, item=item, status=Status.PENDING}
    table.insert(session.rows, rowId, itemRow)
    print(string.format("Added item (Entry: %d GUIDLow: %d) to session instanceId %d", item:GetEntry(), item:GetGUIDLow(), instanceId))
    -- remove item from player
    item:SaveToDB() -- Save item to DB before we remove it from the player
    player:SaveToDB() -- must be called before RemoveItem else crash
    player:RemoveItem(item, count)
end

RegisterPlayerEvent(PLAYER_EVENT_ON_STORE_NEW_ITEM, OnPlayerEventOnStoreNewItem)
