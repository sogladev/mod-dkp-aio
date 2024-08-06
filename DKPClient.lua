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
    local itemInfo = {id = itemId, isBound = false}
    setmetatable(itemInfo, Item)
    itemInfo:PopulateStaticProperties()
    return itemInfo
end


function Item:PopulateStaticProperties()
    print("Item:PopulateStaticProperties")
    print(self.id)
    self.name, self.link, self.quality, self.ilvl, self.minLevel, self.itemType, self.itemSubType, _, self.equipLoc, self.texture, _, self.classId, self.subclassId = GetItemInfo(self.id)
    if not self.name then
        DKP.Error(string.format("Invalid name, item likely not in cache:  %d", self.id))
    end
end


function Item:Decode(encodedStr)
    DKP.print("Item:Decode")
    print(encodedStr)
    local elements = DKP.Split(encodedStr, Separator.LIST_ELEMENT)
    local itemInfo = Item:CreateForId(elements[2])
    local item = {
        id = tonumber(elements[1]),
        status = tonumber(elements[3]),
    }
    itemInfo:PopulateStaticProperties()
    item.itemInfo = itemInfo
    return item
end


function DKPHandlers.SyncResponse(player, encodedSession)
    DKP.print("SyncResponse")
    print(encodedSession)
    local splitItems = DKP.Split(encodedSession, Separator.ELEMENT)
    DKP.items = {}
    for _, itemStr in pairs(splitItems) do
        print("Item: ", itemStr)
        local decodedItem = Item:Decode(itemStr)
        table.insert(DKP.items, decodedItem)
        print(decodedItem.itemInfo.link)
    end
    -- print
    for _, item in pairs(DKP.items) do
        DKP.print(string.format("%d %s", item.id, item.itemInfo.link or ""))
    end
    DKP.client.window:Show()
end


function DKPHandlers.NewItemsAdded(player, encodedItems)
    DKP.print("NewItems")
    local splitItems = DKP.Split(encodedItems, Separator.ELEMENT)
    local newItems = {}
    for _, itemStr in pairs(splitItems) do
        local decodedItem = Item:Decode(itemStr)
        table.insert(newItems, decodedItem)
        print(decodedItem.itemInfo.link)
    end
    for _, item in pairs(newItems) do
        DKP.print(string.format("added %s", item.itemInfo.link))
    end
end


-- GUI
local Client = {}
Client.__index = Client
DKP.Client = Client

function Client:Create()
  local client = {
    sessions = {},
    activeSession = nil,
    -- filter = DKP.Filter:CreateComposite(),
    -- classFilter = DKP.Filter:CreateForPlayerClassId(DKP.playerClass),
    -- watchedFilter = DKP.Filter:CreateForWatched()
  }
  setmetatable(client, Client)
  return client
end

local scrollWidth = 735
function Client:CreateWindow()
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

    -- Create the scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "DKPScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(scrollWidth, 400)
    scrollFrame:SetPoint("LEFT", frame, "LEFT", 20, 00)

    -- Create the content frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(scrollWidth, 400)
    scrollFrame:SetScrollChild(content)
    frame.content = content



    return frame
end

-- Create auction rows
function Client:CreateRow(parent, item)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(scrollWidth, 40)

    local itemLink = item.itemInfo.link
    local highestBidder = "highestBidder"
    local minBid = 100

    -- Row background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    -- bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
    row.bg = bg

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", 5, 0)
    icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark") -- Replace with actual icon
    row.icon = icon

    -- Item link
    local itemLinkText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemLinkText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    itemLinkText:SetText(itemLink)
    row.itemLinkText = itemLinkText

    -- Highest bidder
    local highestBidderText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    highestBidderText:SetPoint("LEFT", itemLinkText, "RIGHT", 5, 0)
    highestBidderText:SetText("Highest Bidder: " .. highestBidder)
    row.highestBidderText = highestBidderText

    -- Minimum bid
    local minBidText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minBidText:SetPoint("LEFT", highestBidderText, "RIGHT", 5, 0)
    minBidText:SetText("Min Bid: " .. minBid)
    row.minBidText = minBidText

    -- Bid amount input
    local bidInput = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    bidInput:SetSize(50, 30)
    bidInput:SetPoint("LEFT", minBidText, "RIGHT", 5, 0)
    bidInput:SetAutoFocus(false)
    bidInput:SetNumeric(true)
    bidInput:SetText(minBid)
    row.bidInput = bidInput

    -- Up button
    local upButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    upButton:SetSize(30, 30)
    upButton:SetPoint("LEFT", bidInput, "RIGHT", 5, 0)
    upButton:SetText("Up")
    upButton:SetScript("OnClick", function()
        local currentBid = tonumber(bidInput:GetText())
        if currentBid then
            bidInput:SetText(currentBid + 1)
        end
    end)
    row.upButton = upButton

    -- Bid button
    local bidButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    bidButton:SetSize(50, 30)
    bidButton:SetPoint("LEFT", upButton, "RIGHT", 5, 0)
    bidButton:SetText("Bid")
    bidButton:SetScript("OnClick", function()
        print("Bidding on auction ID: " .. id)
    end)
    row.bidButton = bidButton

    return row
end

function Client:Populate(items)
    local previousRow
    for i, item in ipairs(items) do
        local row = self:CreateRow(self.window.content, item)
        if previousRow then
            row:SetPoint("TOP", previousRow, "BOTTOM", 0, -5)
        else
            row:SetPoint("TOP", self.window.content, "TOP", 0, -5)
        end
        previousRow = row
    end
end


local client = Client:Create()
DKP.client = client
client.window = client:CreateWindow()
-- add test items
local testStr = "1^39252^1+2^39251^1+3^23070^1"
-- local testStr = "1^39252^1+2^39251^1+3^23070^1+4^23000^1+5^22801^1+6^22808^1+7^22803^1+8^22353^1+9^22804^1+10^22805^1" -- cache
DKPHandlers.SyncResponse(nil, testStr)

client:Populate(DKP.items)
print(DKP.items)
