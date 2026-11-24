local ADDON_NAME, ns = ...
local Manage = {}

ns.Manage = Manage

local QUERY_TIMEOUT = 10
local BAND_LABEL = {
    [0] = "30m",
    [1] = "2h",
    [2] = "12h",
    [3] = "2d",
}

local function getAPI()
    return rawget(_G, "C_AuctionHouse")
end

local function apiFunction(name)
    local api = getAPI()
    if api and type(api[name]) == "function" then
        return api[name]
    end
    return nil
end

local function call(name, ...)
    local fn = apiFunction(name)
    if not fn then
        return false, "missing " .. name
    end
    local values = { pcall(fn, ...) }
    if not values[1] then
        return false, tostring(values[2])
    end
    return true, values[2], values[3], values[4]
end

local function safeText(value)
    local isSecret = rawget(_G, "issecretvalue")
    if type(isSecret) == "function" then
        local ok, secret = pcall(isSecret, value)
        if ok and secret then
            return nil
        end
    end
    local ok, text = pcall(tostring, value)
    return ok and text or nil
end

local function itemNameFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return link:match("%[(.-)%]")
end

local function itemDetails(itemID, itemLink)
    local meta = ns.Auction and ns.Auction:GetItemMeta(itemID)
    if meta then
        return meta.name, meta.quality, meta.link or itemLink, meta.icon
    end

    local getInfo = _G.C_Item and _G.C_Item.GetItemInfo or _G.GetItemInfo
    if type(getInfo) == "function" then
        local values = { pcall(getInfo, itemLink or itemID) }
        if values[1] and values[2] then
            return values[2], values[4] or 1, values[3] or itemLink, values[11]
        end
    end

    return itemNameFromLink(itemLink) or ("Item " .. tostring(itemID or "?")), 1, itemLink, nil
end

local function formatSeconds(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then
        return ""
    end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days > 0 then
        return days .. "d"
    elseif hours > 0 then
        return hours .. "h"
    elseif minutes > 0 then
        return minutes .. "m"
    end
    return "<1m"
end

local function timeText(info)
    if info.timeLeftSeconds then
        return formatSeconds(info.timeLeftSeconds)
    end
    if info.timeLeft ~= nil then
        return BAND_LABEL[info.timeLeft] or tostring(info.timeLeft)
    end
    return ""
end

local function playerGUID()
    local fn = rawget(_G, "UnitGUID")
    if type(fn) ~= "function" then
        return nil
    end
    local ok, guid = pcall(fn, "player")
    return ok and guid or nil
end

function Manage:Init()
    if self.frame then
        return
    end

    self.active = false
    self.ownedRows = {}
    self.bidRows = {}
    self.pendingKind = nil
    self.pendingToken = nil
    self.requestSeq = 0
    self.lastError = nil
    self.cancelPending = nil
    self.bidPending = nil
    self.refreshToken = 0

    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
    for _, event in ipairs({
        "OWNED_AUCTIONS_UPDATED",
        "BIDS_UPDATED",
        "AUCTION_CANCELED",
        "AUCTION_HOUSE_NEW_BID_RECEIVED",
        "GET_ITEM_INFO_RECEIVED",
        "UI_ERROR_MESSAGE",
    }) do
        pcall(self.frame.RegisterEvent, self.frame, event)
    end
end

function Manage:Notify(text, isError)
    text = tostring(text or "")
    if text == "" then
        return
    end
    if ns.UI and ns.UI.SetMessage and ns.UI:IsShown() then
        ns.UI:SetMessage(text, isError)
    else
        ns:Print(text)
    end
end

function Manage:Changed(tab, reset)
    if ns.UI and ns.UI.OnManageDataChanged then
        ns.UI:OnManageDataChanged(tab, reset)
    end
end

function Manage:Touch()
    if ns.UI and ns.UI:IsShown() and ns.UI.UpdateStatus then
        ns.UI:UpdateStatus()
    end
end

function Manage:IsActive()
    return self.active and true or false
end

function Manage:IsQueryPending()
    return self.pendingKind ~= nil
end

function Manage:GetOwnedRows()
    return self.ownedRows or {}
end

function Manage:GetBidRows()
    return self.bidRows or {}
end

function Manage:GetThrottleLabel()
    if self.pendingKind then
        return "thr: query"
    end
    local auction = ns.Auction
    if not auction or type(auction.GetThrottleState) ~= "function" then
        return "thr: ?"
    end
    local ready = auction:GetThrottleState()
    if auction.IsThrottleStuck and auction:IsThrottleStuck() then
        return "thr: STUCK"
    end
    if ready == nil then
        return "thr: ?"
    end
    return ready and "thr: OK" or "thr: WAIT"
end

function Manage:OnShow()
    self:Init()
    self.active = true
    self:ClearPending()
    self.ownedRows = {}
    self.bidRows = {}
    self.cancelPending = nil
    self.bidPending = nil
    self.lastError = nil
end

function Manage:OnClose()
    self.active = false
    self:ClearPending()
    self.ownedRows = {}
    self.bidRows = {}
    self.cancelPending = nil
    self.bidPending = nil
end

function Manage:ClearPending()
    self.pendingKind = nil
    self.pendingToken = nil
end

function Manage:StartTimeout(token, kind)
    C_Timer.After(QUERY_TIMEOUT, function()
        if self.pendingToken ~= token or self.pendingKind ~= kind then
            return
        end
        self:ClearPending()
        self.lastError = "Auction house did not respond."
        self:Notify(self.lastError, true)
        self:Touch()
    end)
end

function Manage:CanQuery()
    if not self.active then
        return false, "Open the auction house first."
    end
    if self.pendingKind then
        return false, "An auction query is already pending."
    end
    if ns.Auction and type(ns.Auction.IsQueryPending) == "function" and ns.Auction:IsQueryPending() then
        return false, "Wait for the current auction query to finish."
    end
    if ns.Sell and type(ns.Sell.IsPriceQueryPending) == "function" and ns.Sell:IsPriceQueryPending() then
        return false, "Wait for the sell price lookup to finish."
    end
    if ns.Auction and type(ns.Auction.CheckThrottle) == "function" then
        local throttleOk, throttleErr = ns.Auction:CheckThrottle()
        if not throttleOk then
            return false, throttleErr
        end
    end
    return true
end

function Manage:RefreshOwned()
    local ok, err = self:CanQuery()
    if not ok then
        self:Notify(err, true)
        return false
    end

    local enum = rawget(_G, "Enum")
    local nameSort = enum and enum.AuctionHouseSortOrder and enum.AuctionHouseSortOrder.Name or 1
    local sent, sendErr = call("QueryOwnedAuctions", { { sortOrder = nameSort, reverseSort = false } })
    if not sent then
        self.lastError = "Owned query failed: " .. tostring(sendErr)
        self:Notify(self.lastError, true)
        return false
    end

    self.pendingKind = "owned"
    self.requestSeq = self.requestSeq + 1
    self.pendingToken = self.requestSeq
    self.lastError = nil
    self:StartTimeout(self.pendingToken, "owned")
    self:Notify("Loading owned auctions...")
    self:Touch()
    return true
end

function Manage:RefreshBids()
    local ok, err = self:CanQuery()
    if not ok then
        self:Notify(err, true)
        return false
    end

    local enum = rawget(_G, "Enum")
    local timeSort = enum and enum.AuctionHouseSortOrder and enum.AuctionHouseSortOrder.TimeRemaining or 5
    local sent, sendErr = call("QueryBids", { { sortOrder = timeSort, reverseSort = false } })
    if not sent then
        sent, sendErr = call("QueryBids", {})
    end
    if not sent then
        self.lastError = "Bids query failed: " .. tostring(sendErr)
        self:Notify(self.lastError, true)
        return false
    end

    self.pendingKind = "bids"
    self.requestSeq = self.requestSeq + 1
    self.pendingToken = self.requestSeq
    self.lastError = nil
    self:StartTimeout(self.pendingToken, "bids")
    self:Notify("Loading bids...")
    self:Touch()
    return true
end

function Manage:BuildOwnedRows()
    local rows = {}
    local ok, count = call("GetNumOwnedAuctions")
    count = ok and tonumber(count) or 0
    for index = 1, count do
        local infoOk, info = call("GetOwnedAuctionInfo", index)
        if infoOk and type(info) == "table" and info.itemKey then
            local name, quality, link, icon = itemDetails(info.itemKey.itemID, info.itemLink)
            local canCancel = false
            if info.status ~= 1 and info.auctionID then
                local cancelOk, cancel = call("CanCancelAuction", info.auctionID)
                canCancel = cancelOk and cancel and true or false
            end
            local cancelCost = nil
            if canCancel then
                local costOk, cost = call("GetCancelCost", info.auctionID)
                cancelCost = costOk and tonumber(cost) or nil
            end
            local status
            if info.status == 1 then
                status = "sold"
            elseif info.timeLeftSeconds ~= nil and (tonumber(info.timeLeftSeconds) or 0) <= 0 and not info.bidder then
                status = "expired"
            elseif info.bidder and info.bidder ~= "" then
                status = "bid"
            else
                status = "active"
            end
            rows[#rows + 1] = {
                view = "owned",
                auctionID = info.auctionID,
                index = index,
                itemKey = info.itemKey,
                itemID = info.itemKey.itemID,
                itemLink = link or info.itemLink,
                name = name,
                quality = quality or 1,
                icon = icon,
                qty = tonumber(info.quantity) or 1,
                price = tonumber(info.bidAmount) or 0,
                bidAmount = tonumber(info.bidAmount) or 0,
                buyout = tonumber(info.buyoutAmount) or 0,
                time = timeText(info),
                timeValue = tonumber(info.timeLeftSeconds) or tonumber(info.timeLeft) or 0,
                status = status,
                bidder = info.bidder,
                canCancel = canCancel,
                cancelCost = cancelCost,
            }
        end
    end
    self.ownedRows = rows
end

local function quantityForAuction(auctionID)
    local ok, info = call("GetAuctionInfoByID", auctionID)
    if ok and type(info) == "table" then
        return tonumber(info.quantity)
    end
    return nil
end

function Manage:GetAllBids()
    local ok, bids = call("GetBids")
    if ok and type(bids) == "table" then
        return bids
    end
    local result = {}
    local countOk, count = call("GetNumBids")
    count = countOk and tonumber(count) or 0
    for index = 1, count do
        local infoOk, info = call("GetBidInfo", index)
        if infoOk and type(info) == "table" then
            result[#result + 1] = info
        end
    end
    return result
end

function Manage:BuildBidRows()
    local rows = {}
    local guid = playerGUID()
    for _, info in ipairs(self:GetAllBids()) do
        if type(info) == "table" and info.itemKey then
            local name, quality, link, icon = itemDetails(info.itemKey.itemID, info.itemLink)
            local qty = quantityForAuction(info.auctionID)
            local bidder = info.bidder
            local playerName = UnitName and UnitName("player") or nil
            local winning = bidder ~= nil
                and ((guid ~= nil and bidder == guid) or (playerName ~= nil and bidder == playerName))
            local status
            if winning then
                status = "winning"
            elseif bidder and bidder ~= "" then
                status = "outbid"
            else
                status = "bid"
            end
            rows[#rows + 1] = {
                view = "bids",
                auctionID = info.auctionID,
                itemKey = info.itemKey,
                itemID = info.itemKey.itemID,
                itemLink = link or info.itemLink,
                name = name,
                quality = quality or 1,
                icon = icon,
                qty = qty,
                price = tonumber(info.bidAmount) or tonumber(info.minBid) or 0,
                bidAmount = tonumber(info.bidAmount) or 0,
                minBid = tonumber(info.minBid) or tonumber(info.bidAmount) or 0,
                buyout = tonumber(info.buyoutAmount) or 0,
                time = timeText(info),
                timeValue = tonumber(info.timeLeft) or 0,
                status = status,
                bidder = bidder,
                winning = winning,
            }
        end
    end
    self.bidRows = rows
end

function Manage:CancelOwned(row)
    if not self.active then
        self:Notify("Open the auction house first.", true)
        return false
    end
    if self.cancelPending then
        self:Notify("A cancellation is already pending.", true)
        return false
    end
    if not row or row.view ~= "owned" or not row.auctionID then
        self:Notify("Select an owned auction first.", true)
        return false
    end
    if row.status == "sold" then
        self:Notify("That auction is sold; collect it at the mailbox.", true)
        return false
    end
    if row.status == "expired" then
        self:Notify("That auction expired; collect it at the mailbox.", true)
        return false
    end
    if not row.canCancel then
        self:Notify("That auction cannot be cancelled right now.", true)
        return false
    end

    local sent, err = call("CancelAuction", row.auctionID)
    if not sent then
        self:Notify("Cancel failed: " .. tostring(err), true)
        return false
    end

    self.cancelPending = row.auctionID
    self.lastError = nil
    self:Notify("Cancelling auction...")
    self:Touch()
    C_Timer.After(4, function()
        if self.cancelPending == row.auctionID then
            self.cancelPending = nil
            self:Notify("Cancel status unknown; refreshing owned auctions.", true)
            self:RefreshOwned()
        end
    end)
    return true
end

function Manage:RaiseBid(row, amount)
    if not self.active then
        self:Notify("Open the auction house first.", true)
        return false
    end
    if self.bidPending then
        self:Notify("A bid is already pending.", true)
        return false
    end
    if not row or row.view ~= "bids" or not row.auctionID then
        self:Notify("Select a bid first.", true)
        return false
    end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then
        self:Notify("That auction has no valid bid price.", true)
        return false
    end

    local sent, err = call("PlaceBid", row.auctionID, amount)
    if not sent then
        self:Notify("Bid failed: " .. tostring(err), true)
        return false
    end

    self.bidPending = row.auctionID
    self.lastError = nil
    self:Notify("Bid sent; refreshing...")
    self:Touch()
    C_Timer.After(2, function()
        if self.bidPending == row.auctionID then
            self.bidPending = nil
            self:RefreshBids()
        end
    end)
    return true
end

function Manage:ScheduleCurrentRefresh()
    if not self.active or self.pendingKind then
        return
    end
    local tab = ns.UI and ns.UI.state and ns.UI.state.tab
    if tab ~= "owned" and tab ~= "bids" then
        return
    end
    self.refreshToken = (self.refreshToken or 0) + 1
    local token = self.refreshToken
    C_Timer.After(0.5, function()
        if self.refreshToken ~= token or not self.active or self.pendingKind then
            return
        end
        if tab == "owned" then
            self:RefreshOwned()
        elseif tab == "bids" then
            self:RefreshBids()
        end
    end)
end

function Manage:OnEvent(event, ...)
    if event == "OWNED_AUCTIONS_UPDATED" then
        if not self.active then
            return
        end
        local wasPending = self.pendingKind == "owned"
        if wasPending then
            self:ClearPending()
        end
        self:BuildOwnedRows()
        self.lastError = nil
        if wasPending then
            self:Notify(string.format("%d owned auctions.", #self.ownedRows))
        end
        if wasPending or (ns.UI and ns.UI.state and ns.UI.state.tab == "owned") then
            self:Changed("owned", true)
        end
        self:Touch()
        return
    end

    if event == "BIDS_UPDATED" then
        if not self.active then
            return
        end
        local wasPending = self.pendingKind == "bids"
        if wasPending then
            self:ClearPending()
        end
        self:BuildBidRows()
        self.lastError = nil
        if self.bidPending then
            self.bidPending = nil
            self:Notify("Bid action completed.")
        elseif wasPending then
            self:Notify(string.format("%d active bids.", #self.bidRows))
        end
        if wasPending or self.bidPending or (ns.UI and ns.UI.state and ns.UI.state.tab == "bids") then
            self:Changed("bids", true)
        end
        self:Touch()
        return
    end

    if event == "AUCTION_CANCELED" then
        local auctionID = ...
        if self.cancelPending and tonumber(auctionID) == self.cancelPending then
            self.cancelPending = nil
            self:Notify("Auction cancelled.")
        end
        if self.active then
            self:BuildOwnedRows()
            if ns.UI and ns.UI.state and ns.UI.state.tab == "owned" then
                self:Changed("owned", true)
            end
        end
        self:Touch()
        return
    end

    if event == "AUCTION_HOUSE_NEW_BID_RECEIVED" then
        self:ScheduleCurrentRefresh()
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        if not self.active or self.metaRefresh then
            return
        end
        self.metaRefresh = true
        C_Timer.After(0, function()
            self.metaRefresh = nil
            if not self.active then
                return
            end
            local tab = ns.UI and ns.UI.state and ns.UI.state.tab
            if #self.ownedRows > 0 then
                self:BuildOwnedRows()
                if tab == "owned" then
                    self:Changed("owned", false)
                end
            end
            if #self.bidRows > 0 then
                self:BuildBidRows()
                if tab == "bids" then
                    self:Changed("bids", false)
                end
            end
        end)
        return
    end

    if event == "UI_ERROR_MESSAGE" then
        local message = safeText(...)
        if not message or message == "" then
            return
        end
        if self.cancelPending or self.bidPending or self.pendingKind then
            self.lastError = message
            self:Notify(message, true)
            if self.cancelPending then
                self.cancelPending = nil
            end
            if self.bidPending then
                self.bidPending = nil
            end
            if self.pendingKind and message:lower():find("database", 1, true) then
                self:ClearPending()
            end
            self:Touch()
        end
        return
    end
end

function Manage:GetStatusLines()
    return {
        "active=" .. tostring(self.active),
        "owned=" .. tostring(#self.ownedRows),
        "bids=" .. tostring(#self.bidRows),
        "pending=" .. tostring(self.pendingKind or "none"),
        "cancelPending=" .. tostring(self.cancelPending or "none"),
        "bidPending=" .. tostring(self.bidPending or "none"),
        "lastError=" .. tostring(self.lastError or "none"),
    }
end
