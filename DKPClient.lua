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
    local itemLinkText = itemLink
    local id = item.id
    local highestBidder = "highestBidder"
    local minBid = 100

    -- Row background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    -- bg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
    row.bg = bg

    -- Icon
    -- LTR layout
    -- Watch button
    local watchButton = CreateFrame("Button", nil, row)
    local watchTexture = watchButton:CreateTexture()
    watchButton.texture = watchTexture;
    watchButton:SetSize(16, 16)
    watchTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9);
    watchTexture:SetAllPoints(watchButton);
    watchButton:SetNormalTexture(watchTexture);
    watchButton:SetHighlightTexture("Interface\\BUTTONS\\UI-Panel-MinimizeButton-Highlight");
    -- watchButton:SetPoint("LEFT", row, "RIGHT", 10, 0)
    watchButton:SetPoint("LEFT", -4, 0)
    watchButton.texture:SetTexture("Interface\\LFGFrame\\BattlenetWorking4")

    local image = row:CreateTexture(nil, "ARTWORK") -- OVERLAY
    image:SetSize(32, 32)
    image:SetPoint("LEFT", watchButton, "RIGHT", 8, 0)
    image:SetTexture(item.itemInfo and item.itemInfo.texture or "Interface/Icons/INV_Misc_QuestionMark")

    -- icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark") -- Replace with actual icon
    -- row.icon = icon

    local ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlText:SetTextColor(1, 1, 1)
    ilvlText:SetPoint("BOTTOMLEFT", image, 1, 1)
    ilvlText:SetPoint("BOTTOMRIGHT", image, -1, 1)
    ilvlText:SetJustifyH("CENTER")
    ilvlText:SetText(item.itemInfo and item.itemInfo.ilvl or "?")

    local linkText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    linkText:SetPoint("TOPLEFT", image, "TOPRIGHT", 8, 0)
    linkText:SetPoint("BOTTOMLEFT", image, "BOTTOMRIGHT", 8, 0)
    linkText:SetJustifyH("LEFT")
    linkText:SetText(itemLink)

    local tooltipRegion = CreateFrame("Button", nil, row)
    tooltipRegion:SetPoint("TOPLEFT", image)
    tooltipRegion:SetPoint("BOTTOMRIGHT", linkText)


    -- RTL layout
    local deleteButton = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    deleteButton:SetPoint("RIGHT", -4, 0)
    deleteButton:SetSize(24, 24)

    local bidButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    bidButton:SetText("Bid")
    bidButton:SetPoint("RIGHT", -8, 0)
    bidButton:SetSize(50, 32)

    local incrementButton = CreateFrame("Button", nil, row)
    incrementButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
    incrementButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    incrementButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
    incrementButton:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
    incrementButton:SetPoint("RIGHT", bidButton, "LEFT", -8, 0)
    incrementButton:SetSize(25, 25)

    local bidBox = CreateFrame("EditBox", "BidType".."BidBox"..id, row, "InputBoxTemplate")
    bidBox:SetAutoFocus(false)
    bidBox:SetNumeric(true)
    bidBox:SetMaxLetters(7)
    bidBox:SetTextInsets(0, 13, 0, 0)
    bidBox:SetJustifyH("CENTER")
    bidBox:SetPoint("RIGHT", incrementButton, "LEFT", 2, 0)
    bidBox:SetSize(75, 25)

    local minBidBox = CreateFrame("EditBox", "minBid".."MinBidBox"..id, row, "InputBoxTemplate")
    minBidBox:SetAutoFocus(false)
    minBidBox:SetNumeric(true)
    minBidBox:SetMaxLetters(7)
    minBidBox:SetTextInsets(0, 13, 0, 0)
    minBidBox:SetJustifyH("CENTER")
    minBidBox:SetPoint("RIGHT", deleteButton, "LEFT", 2, 0)
    minBidBox:SetSize(75, 25)

    local minButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    minButton:SetText("Min")
    minButton:SetNormalFontObject("GameFontNormalSmall")
    minButton:SetHighlightFontObject("GameFontNormalSmall")
    minButton:SetPoint("RIGHT", bidBox, "LEFT", -5, 0)
    minButton:SetPushedTextOffset(0, 0)
    minButton:SetSize(32, 20)

    local enterBidText = bidBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enterBidText:SetPoint("BOTTOMLEFT", bidBox, "TOPLEFT", -2, -3)
    enterBidText:SetJustifyH("LEFT")
    enterBidText:SetHeight(14)

    local enterMinBidText = minBidBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enterMinBidText:SetPoint("BOTTOMLEFT", minBidBox, "TOPLEFT", -2, -3)
    enterMinBidText:SetJustifyH("LEFT")
    enterMinBidText:SetHeight(14)

    local countdownButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    countdownButton:SetText("Countdown")
    countdownButton:SetPoint("RIGHT", -120, 8)
    countdownButton:SetSize(80, 16)

    local closeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    closeButton:SetText("Close")
    closeButton:SetPoint("RIGHT", -120, -8)
    closeButton:SetSize(80, 16)

    local reopenButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    reopenButton:SetText("Reopen")
    reopenButton:SetPoint("RIGHT", -120, 8)
    reopenButton:SetSize(80, 16)

    local restartAuctionButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    restartAuctionButton:SetText("Restart")
    restartAuctionButton:SetPoint("RIGHT", -120, -8)
    restartAuctionButton:SetSize(80, 16)
    --restartAuctionButton:Disable() -- Disabled since bug, ImportBids table index nil

    local errorText = bidBox:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    errorText:SetPoint("TOP", bidBox, "BOTTOM", 0, 3)
    errorText:SetJustifyH("LEFT")
    errorText:SetHeight(14)

    local bidBoxGold = bidBox:CreateTexture(nil, "OVERLAY")
    bidBoxGold:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    bidBoxGold:SetPoint("RIGHT", -6, 0)
    bidBoxGold:SetSize(13, 13)

    local minBidBoxGold = minBidBox:CreateTexture(nil, "OVERLAY")
    minBidBoxGold:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    minBidBoxGold:SetPoint("RIGHT", -6, 0)
    minBidBoxGold:SetSize(13, 13)

    local topBidText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    topBidText:SetJustifyH("LEFT")
    topBidText:SetPoint("TOP", enterBidText)
    topBidText:SetPoint("LEFT", minButton, "LEFT", -200, 0)
    topBidText:SetHeight(14)

    local topBidAmountText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    topBidAmountText:SetJustifyH("LEFT")
    topBidAmountText:SetPoint("LEFT", topBidText)
    topBidAmountText:SetPoint("RIGHT", topBidText)
    topBidAmountText:SetPoint("TOP", topBidText, "BOTTOM")
    topBidAmountText:SetHeight(22)

    -- SetBids(nil, nil, nil)
    -- SetErrorText(nil)
    -- SetMasterButtons(false)
    -- SetMasterControlsEnabled(false)
    reopenButton:Disable()
    reopenButton:Hide()
    restartAuctionButton:Disable()
    restartAuctionButton:Hide()
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
