local ADDON_NAME = "AIODKP"
local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end
local DKPHandlers = {}
local DKP = {}
AIO.AddHandlers(ADDON_NAME, DKPHandlers)

-- local find, format, gmatch, gsub, tolower, match, toupper, join, split, trim = string.find, string.format, string.gmatch, string.gsub, string.lower, string.match, string.upper, string.join, string.split, string.trim

DKP.Config = {
    addonMsgPrefix = "|TInterface/MoneyFrame/UI-GoldIcon:14:14:2:0|t|cfffff800DKP|r",
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

-- print with addon prefix
function DKP.print(message)
    print(DKP.Config.addonMsgPrefix .. " " .. message)
end
function DKP.Error(message)
    print(DKP.Config.addonMsgPrefix .. " ERROR: " .. message)
end

local frame = CreateFrame("Frame", "DKPFrame", UIParent)
frame:SetSize(800, 500)
frame:SetPoint("CENTER")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)

-- This enables saving of the position of the frame over reload of the UI or restarting game
AIO.SavePosition(frame)

-- baseframe: Enable dragging
frame:RegisterForDrag("LeftButton")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnHide", frame.StopMovingOrSizing)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

-- baseframe: Close button
frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
frame.closeButton:SetScript("OnClick", function(self)
    frame:Hide()
end)
-- baseframe: title
frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontNormalMed3")
frame.title:SetPoint("TOP", frame, "TOP", 0, -15)
frame.title:SetText("DKP")
frame:SetPoint("CENTER")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
-- baseframe: Set background
frame:SetBackdrop({
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
frame:SetBackdropColor(0, 0, 0, 1)

-- Handlers
function DKPHandlers.ShowFrame(player)
    frame:Show()
end

function DKP.Split(str, sep)
    print("DKP.Split")
    local t = {}
    for s in str:gmatch("([^"..sep.."]+)") do
        table.insert(t, s)
    end
    return t
end

local Item = {}
Item.__index = Item
DKP.Item = Item
function Item:CreateForId(itemId)
    itemId = tonumber(itemId)
    print("Item:CreateForId: ", itemId)
    local item = {id = itemId, isBound = false}
    setmetatable(item, Item)
    item:PopulateStaticProperties()
    return item
end

function Item:PopulateStaticProperties()
    print("Item:PopulateStaticProperties")
    print(self.id)
    self.name, self.link, self.quality, self.ilvl, self.minLevel, self.itemType, self.itemSubType, _, self.equipLoc, self.texture, _, self.classId, self.subclassId = GetItemInfo(self.id)
    if not self.name then
        DKP:Error("Invalid itemId", self.id)
    end
end

function DKP.DecodeRow(encodedStr)
    DKP.print("DKP.DecodeRow")
    print(encodedStr)
    local elements = DKP.Split(encodedStr, Separator.LIST_ELEMENT)
    local item = Item:CreateForId(elements[2])
    local row = {
        id = tonumber(elements[1]),
        status = tonumber(elements[3]),
    }
    item:PopulateStaticProperties()
    row.item = item
    return row
end

function DKPHandlers.SyncResponse(player, encodedItems)
    DKP.print("SyncResponse")
    print(encodedItems)
    local splitRows = DKP.Split(encodedItems, Separator.ELEMENT)
    DKP.rows = {}
    for _, row in pairs(splitRows) do
        print("Row: ", row)
        local decodedRow = DKP.DecodeRow(row)
        table.insert(DKP.rows, decodedRow)
        print(decodedRow.item.link)
    end
    -- print
    for _, row in pairs(DKP.rows) do
        DKP.print(string.format("%d %s", row.id, row.item.link))
    end
    frame:Show()
end

