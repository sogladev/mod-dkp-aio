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
  CLAIMED = 4,
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
    DKP.client.window:Show()
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

-- Define ForceLoadItemData outside of ItemSlotRightCheck
local hiddenTooltip = CreateFrame("GameTooltip", "HiddenTooltipFrame", UIParent, "GameTooltipTemplate")
hiddenTooltip:SetSize(1, 1)
hiddenTooltip:SetPoint("CENTER", UIParent, "CENTER")
hiddenTooltip:Hide()
function DKP.ForceLoadItemData(itemID)
    hiddenTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    hiddenTooltip:SetHyperlink("item:" .. itemID)
end

function Item:PopulateStaticProperties()
    self.name, self.link, self.quality, self.ilvl, self.minLevel, self.itemType, self.itemSubType, _, self.equipLoc, self.texture, _, self.classId, self.subclassId = GetItemInfo(self.id)
    if not self.name then
        DKP.Error(string.format("Item id: %d not in cache, force loading data..., fixed on next reload or manually sync (.dkp sync)", self.id))
        DKP.ForceLoadItemData(self.id)
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
        bid = tonumber(elements[4]),
        topBidder = elements[5] or "n",
        expiration = elements[6] and tonumber(elements[6]) or 0,
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
        DKP.print(string.format("Status %d", item.status))
        DKP.print(string.format("Expiration %d", item.expiration))
        DKP.print(string.format("time %d", time()))
        DKP.print(string.format("Expiration-Time %d", item.expiration-time()))
    end
    DKP.client.window:Show()
    DKP.client:Populate(DKP.items)
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
    rows = {},
    -- filter = DKP.Filter:CreateComposite(),
    -- classFilter = DKP.Filter:CreateForPlayerClassId(DKP.playerClass),
    -- watchedFilter = DKP.Filter:CreateForWatched()
  }
  setmetatable(client, Client)
  return client
end

local scrollWidth = 585
function Client:CreateWindow()
    local frame = CreateFrame("Frame", "DKPFrame", UIParent)
    frame:SetSize(650, 500)
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

    -- Create status text
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetJustifyH("LEFT")
    statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 12)
    statusText:SetHeight(22)
    statusText:SetText("Total Bidding Status | some status | more text")
    return frame
end


local CountdownBar = {}
CountdownBar.__index = CountdownBar
DKP.CountdownBar = CountdownBar
local function UpdateCountdownBar(self, dt)
    local item = self.item
    if not item or not self.rawValue then
        self:Hide()
        return
    end
    if item.status ~= Status.BIDDING then
        self:Hide()
        return
    end
    local remaining = math.max(0, self.rawValue - (dt or 0))
    self.rawValue = remaining
    if not self.isCountingDown and math.floor(remaining) < (item.countdown or 0) then
        self.isCountingDown = true
        self:SetMinMaxValues(0, item.countdown)
        self:SetAlpha(0.2)
        if self.topBidder == UnitName("player") then
            self:SetStatusBarColor(0, 1, 0)
        else
            self:SetStatusBarColor(1, 0, 0)
        end
    end
    if remaining == 0 then
        self:Hide()
    else
        self:Show()
        self:SetValue(remaining)
    end
end

function CountdownBar:Create(parent)
  local countdownBar = CreateFrame("StatusBar", nil, parent)
  countdownBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8", "BACKGROUND")
  countdownBar:SetScript("OnUpdate", function(self, dt) UpdateCountdownBar(self, dt) end)

  -- Add inheritence from CountdownBar
  local meta = getmetatable(countdownBar)
  setmetatable(countdownBar, {
    __index = function(t, k)
      return CountdownBar[k] or meta.__index[k]
    end
  })

--   Floot:AddMessageSystem(countdownBar)

  return countdownBar
end

function CountdownBar:CountdownItem(item)
  self.item = item
  self.topBidder = item.topBidder
  self.rawValue = (item and item.expiration or 0) - time()
  self.isCountingDown = false

--   local duration = item and item.bidDuration or 0
--   local countdown = item and item.countdown or 0
  local duration = 15
  local countdown = 5
  item.duration = duration
  item.countdown = countdown

  self:SetMinMaxValues(countdown, duration)
  self:SetStatusBarColor(1, 1, 1)
  self:SetAlpha(0.06)

  UpdateCountdownBar(self)
end

function Client:ConfigureRow(row, item)
    local minBid = 100
    row.watchButton.texture:SetTexture("Interface\\LFGFrame\\BattlenetWorking4")
    row.image:SetTexture(item.itemInfo and item.itemInfo.texture or "Interface/Icons/INV_Misc_QuestionMark")
    row.ilvlText:SetText(item.itemInfo and item.itemInfo.ilvl or "?")
    row.linkText:SetText(item.itemInfo.link)

    print("ITEM STATUS")
    print(item.status)
    print(item.Status)
    if item.status == Status.BIDDING then
        row.bidButton:Enable()
        row.bidButton:SetText("Bid")
    elseif item.status == Status.ASSIGNED then
        if item.topBidder == UnitName("player") then
            row.bidButton:SetText("Claim")
            row.bidButton:Enable()
        else
            row.bidButton:SetText("")
            row.bidButton:Disable()
        end
    elseif item.status == Status.CLAIMED then
        row.bidButton:SetText("Claimed")
        row.bidButton:Disable()
    else
        row.bidButton:Disable()
        row.bidButton:SetText("Pending")
    end

    row.topBidText:SetText(item.topBidder ~= "n" and "Top Bid: "..item.topBidder or "")
    row.topBidAmountText:SetText(item.bid ~= 0 and item.bid or "No bid")

    row.countdownBar:CountdownItem(item)
end


-- Create auction rows
function Client:CreateRow(parent, item)
    local row = CreateFrame("Frame", nil, parent)

    row:SetSize(scrollWidth, 40)

    local id = item.id
    row.item = item

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
    row.watchButton = watchButton

    local image = row:CreateTexture(nil, "ARTWORK") -- OVERLAY
    image:SetSize(32, 32)
    image:SetPoint("LEFT", watchButton, "RIGHT", 8, 0)
    row.image = image

    -- icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark") -- Replace with actual icon
    -- row.icon = icon

    local ilvlText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ilvlText:SetTextColor(1, 1, 1)
    ilvlText:SetPoint("BOTTOMLEFT", image, 1, 1)
    ilvlText:SetPoint("BOTTOMRIGHT", image, -1, 1)
    ilvlText:SetJustifyH("CENTER")
    row.ilvlText = ilvlText

    local linkText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    linkText:SetPoint("TOPLEFT", image, "TOPRIGHT", 8, 0)
    linkText:SetPoint("BOTTOMLEFT", image, "BOTTOMRIGHT", 8, 0)
    linkText:SetJustifyH("LEFT")
    row.linkText = linkText

    local tooltipRegion = CreateFrame("Button", nil, row)
    tooltipRegion:SetPoint("TOPLEFT", image)
    tooltipRegion:SetPoint("BOTTOMRIGHT", linkText)

    tooltipRegion:HookScript("OnEnter", function() row:ShowItemTooltip() end)
    tooltipRegion:HookScript("OnLeave", function() GameTooltip:Hide() end)
    tooltipRegion:HookScript("OnClick", function(_, button) row:OnTooltipClicked(button) end)
    function row:ShowItemTooltip()
        local item = self.item
        if not item or not item.itemInfo or not item.itemInfo.link then return end
        GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(item.itemInfo.link)
    end
    function row:OnTooltipClicked(button)
        -- An unmodified click would open the default item tooltip frame
        -- This seems unnecessary, so is disabled for now
        if not IsModifiedClick() then return end
        local item = self.item
        if not item or not item.itemInfo or not item.itemInfo.link then return end
        -- Handles pasting link to chat frame, dressup, etc.
        SetItemRef(item.itemInfo.link, item.itemInfo.link, button)
    end

    -- RTL layout
    local bidButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    bidButton:SetPoint("RIGHT", -8, 0)
    bidButton:SetPoint("RIGHT", -4, 0)
    bidButton:SetSize(50, 32)
    row.bidButton = bidButton
    bidButton:HookScript("OnClick", function() row:OnBidPressed() end)
    function row:OnBidPressed(button)
        self.bidBox:ClearFocus()
        local item = self.item
        if not item then return end
        if self.bidButton:GetText() == "Claim" then
            AIO.Handle(ADDON_NAME, "RequestClaim", item.id)
        else
            item.pendingBid = 69 -- TODO: read value set from bidBox
            AIO.Handle(ADDON_NAME, "RequestBid", item.id, item.pendingBid)
        end
    end

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
    -- bidBox:SetTextInsets(0, 13, 0, 0)
    bidBox:SetJustifyH("CENTER")
    bidBox:SetPoint("RIGHT", incrementButton, "LEFT", 2, 0)
    bidBox:SetSize(75, 25)
    row.bidBox = bidBox

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

    local errorText = bidBox:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    errorText:SetPoint("TOP", bidBox, "BOTTOM", 0, 3)
    errorText:SetJustifyH("LEFT")
    errorText:SetHeight(14)

    local bidBoxGold = bidBox:CreateTexture(nil, "OVERLAY")
    bidBoxGold:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    bidBoxGold:SetPoint("RIGHT", -6, 0)
    bidBoxGold:SetSize(13, 13)

    local topBidText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    topBidText:SetJustifyH("LEFT")
    topBidText:SetPoint("TOP", enterBidText)
    topBidText:SetPoint("RIGHT", minButton, "LEFT", -15, 0)
    topBidText:SetHeight(14)
    row.topBidText = topBidText

    local topBidAmountText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    topBidAmountText:SetJustifyH("LEFT")
    -- topBidAmountText:SetPoint("LEFT", topBidText)
    topBidAmountText:SetPoint("RIGHT", topBidText, "RIGHT")
    topBidAmountText:SetPoint("TOP", topBidText, "BOTTOM")
    topBidAmountText:SetHeight(22)
    row.topBidAmountText = topBidAmountText

    row.countdownBar = CountdownBar:Create(row)
    row.countdownBar:SetAllPoints()

    return row
end


function Client:HideRows()
    for i, row in ipairs(self.rows) do
        row:Hide()
    end
end


function Client:Populate(items)
    self:HideRows()
    local previousRow
    for i, item in ipairs(items) do
        -- delete row at index
        local row = self.rows[i] or self:CreateRow(self.window.content, item)
        row:Show()
        self:ConfigureRow(row, item)
        self.rows[i] = row
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
-- local testStr = "1^39252^1+2^39251^1+3^23070^1"
local testStr = "1^39252^1+2^39251^1+3^23070^1+4^23000^1+5^22801^1+6^22808^1+7^22803^1+8^22353^1+9^22804^1+10^22805^1" -- cache
DKPHandlers.SyncResponse(nil, testStr)

print(DKP.items)
