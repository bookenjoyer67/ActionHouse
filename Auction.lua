local ADDON_NAME, ns = ...
local Auction = {}

ns.Auction = Auction

local QUERY_TIMEOUT = 10
local DIRECT_LIMIT = 90
local DIRECT_WINDOW = 60
local THROTTLE_STUCK_AFTER = 10
local THROTTLE_STUCK_TEXT =
    "Auction house throttle is stuck (Forever client bug). Run :throttle reset or /reload to close the AH and reload."

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
    if ok then
        return text
    end
    return nil
end

local function trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function now()
    local getTime = rawget(_G, "GetTime")
    if type(getTime) == "function" then
        local ok, value = pcall(getTime)
        if ok and type(value) == "number" then
            return value
        end
    end
    local timeFn = rawget(_G, "time")
    if type(timeFn) == "function" then
        local ok, value = pcall(timeFn)
        if ok and type(value) == "number" then
            return value
        end
    end
    return 0
end

local function itemKeyString(itemKey)
    if type(itemKey) ~= "table" then
        return ""
    end
    return string.format(
        "%s:%s:%s:%s",
        tostring(itemKey.itemID or 0),
        tostring(itemKey.itemLevel or 0),
        tostring(itemKey.itemSuffix or 0),
        tostring(itemKey.battlePetSpeciesID or 0)
    )
end

local function enumSort(name, fallback)
    local enum = rawget(_G, "Enum")
    local orders = enum and enum.AuctionHouseSortOrder
    if orders and orders[name] ~= nil then
        return orders[name]
    end
    return fallback
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

local function formatTime(value)
    if type(value) ~= "number" then
        return ""
    end
    if value > 3 then
        return formatSeconds(value)
    end
    local text = rawget(_G, "AUCTION_TIME_LEFT" .. tostring(value))
    if text then
        return text
    end
    return tostring(value)
end

function Auction:Init()
    if self.frame then
        return
    end

    self.active = false
    self.mode = "browse"
    self.queryText = ""
    self.hasQueried = false
    self.rows = {}
    self.rawBrowse = {}
    self.browseSnapshot = {}
    self.detail = nil
    self.pending = nil
    self.pendingToken = nil
    self.lastError = nil
    self.quote = nil
    self.purchase = nil
    self.actionPending = false
    self.maxQuantity = nil
    self.itemMeta = {}
    self.keyInfo = {}
    self.keyWaiters = {}
    self.searchTimes = {}
    self.sortField = "price"
    self.sortAsc = true
    self.throttleDownSince = nil
    self.throttleDownFor = 0
    self.throttleStuck = false
    self.throttleWatchToken = 0

    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)

    local events = {
        "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
        "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
        "AUCTION_HOUSE_BROWSE_FAILURE",
        "COMMODITY_SEARCH_RESULTS_UPDATED",
        "COMMODITY_SEARCH_RESULTS_ADDED",
        "ITEM_SEARCH_RESULTS_UPDATED",
        "ITEM_SEARCH_RESULTS_ADDED",
        "COMMODITY_PRICE_UPDATED",
        "COMMODITY_PRICE_UNAVAILABLE",
        "COMMODITY_PURCHASE_SUCCEEDED",
        "COMMODITY_PURCHASE_FAILED",
        "ITEM_KEY_ITEM_INFO_RECEIVED",
        "GET_ITEM_INFO_RECEIVED",
        "BIDS_UPDATED",
        "AUCTION_CANCELED",
        "UI_ERROR_MESSAGE",
        "CHAT_MSG_SYSTEM",
        "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
        "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED",
        "AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED",
        "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED",
        "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT",
        "AUCTION_HOUSE_NEW_BID_RECEIVED",
    }

    for _, event in ipairs(events) do
        pcall(self.frame.RegisterEvent, self.frame, event)
    end
end

function Auction:IsActive()
    return self.active and true or false
end

function Auction:IsQueryPending()
    return self.pending ~= nil
end

function Auction:Notify(text, isError)
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

function Auction:Changed(reset)
    if ns.UI and ns.UI.OnAuctionDataChanged then
        ns.UI:OnAuctionDataChanged(reset)
    end
end

function Auction:Touch()
    if ns.UI and ns.UI:IsShown() and ns.UI.UpdateStatus then
        ns.UI:UpdateStatus()
    end
end

function Auction:ClearPending()
    self.pending = nil
    self.pendingToken = nil
end

function Auction:StartTimeout(token)
    C_Timer.After(QUERY_TIMEOUT, function()
        if self.pendingToken ~= token or not self.pending then
            return
        end
        self:ClearPending()
        self.lastError = "Auction house did not respond."
        self:Notify(self.lastError, true)
        self:Touch()
    end)
end

function Auction:GetItemMeta(itemID)
    if type(itemID) ~= "number" then
        return nil
    end
    local cached = self.itemMeta[itemID]
    if cached then
        return cached
    end

    local cItem = rawget(_G, "C_Item")
    local getInfo = cItem and cItem.GetItemInfo or rawget(_G, "GetItemInfo")
    if type(getInfo) ~= "function" then
        return nil
    end

    local values = { pcall(getInfo, itemID) }
    if not values[1] or not values[2] then
        return nil
    end

    local meta = {
        name = values[2],
        link = values[3],
        quality = values[4] or 1,
        itemLevel = values[5] or 0,
        icon = values[11],
    }
    self.itemMeta[itemID] = meta
    return meta
end

function Auction:ResolveKeyInfo(key, info)
    local waiter = self.keyWaiters[key]
    if not waiter then
        return
    end
    self.keyWaiters[key] = nil
    if info then
        self.keyInfo[key] = info
    end
    for _, callback in ipairs(waiter.callbacks) do
        pcall(callback, info)
    end
end

function Auction:TryKeyInfo(key)
    local waiter = self.keyWaiters[key]
    if not waiter then
        return
    end
    local ok, info = call("GetItemKeyInfo", waiter.itemKey)
    if ok and info then
        self:ResolveKeyInfo(key, info)
    end
end

function Auction:GetKeyInfo(itemKey, callback)
    if type(itemKey) ~= "table" then
        callback(nil)
        return
    end
    local key = itemKeyString(itemKey)
    local cached = self.keyInfo[key]
    if cached then
        callback(cached)
        return
    end
    if self.keyWaiters[key] then
        self.keyWaiters[key].callbacks[#self.keyWaiters[key].callbacks + 1] = callback
        return
    end
    self.keyWaiters[key] = {
        itemKey = itemKey,
        callbacks = { callback },
    }
    self:TryKeyInfo(key)
    if self.keyWaiters[key] then
        C_Timer.After(3, function()
            if self.keyWaiters[key] then
                self:ResolveKeyInfo(key, nil)
            end
        end)
    end
end

function Auction:ResetThrottleTracking()
    self.throttleDownSince = nil
    self.throttleDownFor = 0
    self.throttleStuck = false
    self.throttleWatchToken = (self.throttleWatchToken or 0) + 1
end

function Auction:NoteThrottle(ready)
    if not self.active then
        self:ResetThrottleTracking()
        return
    end
    if ready ~= false then
        self:ResetThrottleTracking()
        return
    end

    local current = now()
    if not self.throttleDownSince then
        self.throttleDownSince = current
        self.throttleWatchToken = (self.throttleWatchToken or 0) + 1
        local token = self.throttleWatchToken
        C_Timer.After(THROTTLE_STUCK_AFTER + 0.5, function()
            if self.throttleWatchToken ~= token then
                return
            end
            self:GetThrottleState()
            self:Touch()
        end)
    end

    self.throttleDownFor = math.max(0, current - self.throttleDownSince)
    if self.throttleDownFor >= THROTTLE_STUCK_AFTER and not self.throttleStuck then
        self.throttleStuck = true
        self:Notify(THROTTLE_STUCK_TEXT, true)
        self:Touch()
    end
end

function Auction:GetThrottleState()
    local fn = apiFunction("IsThrottledMessageSystemReady")
    if not fn then
        self:ResetThrottleTracking()
        return nil
    end
    local ok, ready = pcall(fn)
    if ok and type(ready) == "boolean" then
        self:NoteThrottle(ready)
        return ready
    end
    self:ResetThrottleTracking()
    return nil
end

function Auction:IsThrottleStuck()
    return self.throttleStuck and true or false
end

function Auction:CheckThrottle()
    local ready = self:GetThrottleState()
    if self.throttleStuck then
        return false, THROTTLE_STUCK_TEXT
    end
    if ready == false then
        return false, "Auction house is busy; wait for the throttle."
    end
    return true
end

function Auction:GetThrottleLabel()
    if self.pending then
        return "thr: query"
    end
    local ready = self:GetThrottleState()
    if self.throttleStuck then
        return "thr: STUCK"
    end
    if ready == nil then
        return "thr: ?"
    end
    return ready and "thr: OK" or "thr: WAIT"
end

function Auction:PrepareForReload()
    self:ClearPending()
    self:CancelCommodityPurchase(true)
    self:ResetThrottleTracking()
    if ns.Compat and ns.Compat.CloseAuctionHouse then
        ns.Compat:CloseAuctionHouse()
    end
end

function Auction:PruneSearchTimes()
    local current = now()
    for index = #self.searchTimes, 1, -1 do
        if current - self.searchTimes[index] >= DIRECT_WINDOW then
            table.remove(self.searchTimes, index)
        end
    end
end

function Auction:GetDirectWait()
    self:PruneSearchTimes()
    if #self.searchTimes < DIRECT_LIMIT then
        return 0
    end
    return math.max(0, self.searchTimes[1] + DIRECT_WINDOW - now())
end

function Auction:RecordDirectSearch()
    self.searchTimes[#self.searchTimes + 1] = now()
end

function Auction:CanQuery(direct)
    if not self.active then
        return false, "Auction house is not open."
    end
    if self.pending then
        return false, "A query is already pending."
    end
    if ns.Manage and ns.Manage.IsQueryPending and ns.Manage:IsQueryPending() then
        return false, "Wait for the current auction query to finish."
    end
    if ns.Sell and ns.Sell.IsPriceQueryPending and ns.Sell:IsPriceQueryPending() then
        return false, "Wait for the sell price lookup to finish."
    end
    local throttleOk, throttleErr = self:CheckThrottle()
    if not throttleOk then
        return false, throttleErr
    end
    if direct then
        local wait = self:GetDirectWait()
        if wait > 0 then
            return false, string.format("Item search limit reached; wait %.0fs.", wait)
        end
    end
    return true
end

function Auction:GetBrowseSorts()
    local price = enumSort("Price", 0)
    local name = enumSort("Name", 1)
    if self.sortField == "price" then
        return { { sortOrder = price, reverseSort = not self.sortAsc } }
    elseif self.sortField == "name" then
        return { { sortOrder = name, reverseSort = not self.sortAsc } }
    end
    return {
        { sortOrder = name, reverseSort = false },
        { sortOrder = price, reverseSort = true },
    }
end

function Auction:GetDetailQuery()
    local price = enumSort("Price", 0)
    local name = enumSort("Name", 1)
    if self.detail and self.detail.isCommodity then
        local sortOrder = self.sortField == "name" and name or price
        return { sortOrder = sortOrder, reverseSort = not self.sortAsc }, false
    end
    local sortOrder = self.sortField == "name" and name or enumSort("Buyout", 4)
    return { { sortOrder = sortOrder, reverseSort = not self.sortAsc } }, true
end

function Auction:SetSort(field, asc)
    self.sortField = field or "name"
    self.sortAsc = asc ~= false
    if self.mode == "detail" and self.detail then
        self:SendDetailSearch()
    elseif self.hasQueried then
        self:SendBrowseSearch()
    else
        self:Notify("Sort: " .. self.sortField .. " " .. (self.sortAsc and "asc" or "desc"))
    end
end

function Auction:GetSortLabel()
    return self.sortField .. " " .. (self.sortAsc and "asc" or "desc")
end

function Auction:GetQueryText()
    return self.queryText or ""
end

function Auction:GetQueryLabel()
    if self.mode == "detail" and self.detail then
        return self.detail.name or "item"
    elseif self.queryText ~= "" then
        return "/" .. self.queryText
    end
    return "no search"
end

function Auction:GetResultLabel()
    local text = string.format("%d rows", #self.rows)
    if self.pending then
        text = text .. "  loading"
    end
    if self.mode == "detail" and self.detail and self.detail.isCommodity and self.maxQuantity then
        text = text .. "  avail " .. tostring(self.maxQuantity)
    end
    return text
end

function Auction:GetStatusLines()
    local detail = "none"
    if self.detail then
        detail = tostring(self.detail.name or "?") .. " " .. (self.detail.isCommodity and "commodity" or "item")
    end
    local quote = "none"
    if self.quote then
        quote = string.format(
            "%s x %s = %s",
            tostring(self.quote.quantity),
            tostring(self.quote.unitPrice),
            tostring(self.quote.totalPrice)
        )
    end
    return {
        "active=" .. tostring(self.active),
        "mode=" .. tostring(self.mode),
        "query=" .. tostring(self.queryText or ""),
        "rows=" .. tostring(#self.rows),
        "pending=" .. tostring(self.pending or "none"),
        "throttle=" .. tostring(self:GetThrottleState()),
        "throttleDownFor=" .. string.format("%.0f", self.throttleDownFor or 0),
        "throttleStuck=" .. tostring(self.throttleStuck and true or false),
        "sort=" .. self:GetSortLabel(),
        "detail=" .. detail,
        "quote=" .. quote,
        "purchase=" .. (self.purchase and "pending" or "none"),
        "lastError=" .. tostring(self.lastError or "none"),
    }
end

function Auction:OnShow()
    self:Init()
    self.active = true
    self:ClearPending()
    self:ResetThrottleTracking()
    self:GetThrottleState()
    self:CancelCommodityPurchase(true)
    self.mode = "browse"
    self.queryText = ""
    self.hasQueried = false
    self.rows = {}
    self.rawBrowse = {}
    self.browseSnapshot = {}
    self.detail = nil
    self.lastError = nil
    self.maxQuantity = nil
    self.actionPending = false
    self:Changed(true)
end

function Auction:OnClose()
    self:CancelCommodityPurchase(true)
    self:ClearPending()
    self:ResetThrottleTracking()
    self.active = false
    self.rows = {}
    self.rawBrowse = {}
    self.browseSnapshot = {}
    self.detail = nil
    self.mode = "browse"
    self.quote = nil
    self.purchase = nil
    self.actionPending = false
    self.keyWaiters = {}
end

function Auction:Search(text)
    self:Init()
    if not self.active then
        self:Notify("Open the auction house first.", true)
        return
    end
    if self.pending then
        self:Notify("A query is already pending; wait for it or press Esc.", true)
        return
    end
    text = trim(text):gsub("^/", "")
    self.queryText = text
    self.hasQueried = true
    self.mode = "browse"
    self.detail = nil
    self.rows = {}
    self.rawBrowse = {}
    self.browseSnapshot = {}
    self.lastError = nil
    self.maxQuantity = nil
    if ns.db and text ~= "" then
        ns.db.lastBuySearch = text
    end
    self:Changed(true)
    self:SendBrowseSearch()
end

function Auction:SendBrowseSearch()
    local ok, err = self:CanQuery(false)
    if not ok then
        self:Notify(err, true)
        return
    end

    local query = {
        searchString = self.queryText or "",
        sorts = self:GetBrowseSorts(),
        filters = {},
        itemClassFilters = {},
    }

    local sent, sendErr = call("SendBrowseQuery", query)
    if not sent then
        self.lastError = "Browse query failed: " .. tostring(sendErr)
        self:Notify(self.lastError, true)
        return
    end

    self.pending = "browse"
    self.requestSeq = (self.requestSeq or 0) + 1
    self.pendingToken = self.requestSeq
    self:StartTimeout(self.pendingToken)
    self:Notify("Searching auction house...")
    self:Touch()
end

function Auction:OpenItem(row)
    if not self.active then
        self:Notify("Open the auction house first.", true)
        return
    end
    if not row or not row.itemKey then
        self:Notify("No item selected.", true)
        return
    end
    if self.pending then
        self:Notify("A query is already pending; wait for it.", true)
        return
    end

    self.browseSnapshot = self.rows
    self.mode = "detail"
    self.detail = {
        itemKey = row.itemKey,
        keyString = itemKeyString(row.itemKey),
        itemID = row.itemKey.itemID,
        name = row.name,
        itemLink = row.itemLink,
        isCommodity = row.kind == "commodity",
    }
    self.rows = {}
    self.rawBrowse = {}
    self.maxQuantity = nil
    self.lastError = nil
    self:Changed(true)
    self:Notify("Loading " .. tostring(row.name or "item") .. "...")

    self:GetKeyInfo(row.itemKey, function(info)
        if not self.active or not self.detail or self.detail.keyString ~= itemKeyString(row.itemKey) then
            return
        end
        if not info then
            self:Notify("Item information is not available.", true)
            self.mode = "browse"
            self.detail = nil
            self.rows = self.browseSnapshot or {}
            self:Changed(true)
            return
        end
        self.detail.name = info.itemName or self.detail.name
        self.detail.isCommodity = info.isCommodity and true or false
        self:SendDetailSearch()
    end)
end

function Auction:SendDetailSearch()
    if not self.active or not self.detail then
        return
    end
    local ok, err = self:CanQuery(true)
    if not ok then
        self:Notify(err, true)
        return
    end
    local sorts, splitOwned = self:GetDetailQuery()
    local sent, sendErr = call("SendSearchQuery", self.detail.itemKey, sorts, splitOwned)
    if not sent then
        self.lastError = "Item search failed: " .. tostring(sendErr)
        self:Notify(self.lastError, true)
        return
    end
    self:RecordDirectSearch()
    self.pending = "detail"
    self.requestSeq = (self.requestSeq or 0) + 1
    self.pendingToken = self.requestSeq
    self:StartTimeout(self.pendingToken)
    self:Notify("Loading lots for " .. tostring(self.detail.name or "item") .. "...")
    self:Touch()
end

function Auction:Back()
    if self.mode ~= "detail" then
        self:Notify("Already showing search results.")
        return
    end
    self:ClearPending()
    self.mode = "browse"
    self.detail = nil
    self.rows = self.browseSnapshot or {}
    self.maxQuantity = nil
    self:Changed(true)
    self:Notify("Back to search results.")
end

function Auction:Refresh()
    if self.mode == "detail" and self.detail then
        self:SendDetailSearch()
    elseif self.hasQueried then
        self:SendBrowseSearch()
    else
        self:Notify("Press / to search first.")
    end
end

function Auction:RequestMore()
    if self.pending then
        self:Notify("A query is already pending.")
        return
    end
    if not self.active then
        self:Notify("Open the auction house first.", true)
        return
    end

    local throttleOk, throttleErr = self:CheckThrottle()
    if not throttleOk then
        self:Notify(throttleErr, true)
        return
    end

    if self.mode == "browse" then
        if not self.hasQueried then
            self:Notify("Press / to search first.")
            return
        end
        local ok, full = call("HasFullBrowseResults")
        if ok and full then
            self:Notify("All browse results are loaded.")
            return
        end
        local sent, err = call("RequestMoreBrowseResults")
        if not sent then
            self:Notify("Load more failed: " .. tostring(err), true)
            return
        end
    elseif self.mode == "detail" and self.detail then
        if self.detail.isCommodity then
            local ok, full = call("HasFullCommoditySearchResults", self.detail.itemID)
            if ok and full then
                self:Notify("All commodity results are loaded.")
                return
            end
            local sent, err = call("RequestMoreCommoditySearchResults", self.detail.itemID)
            if not sent then
                self:Notify("Load more failed: " .. tostring(err), true)
                return
            end
        else
            local ok, full = call("HasFullItemSearchResults", self.detail.itemKey)
            if ok and full then
                self:Notify("All item results are loaded.")
                return
            end
            local sent, err = call("RequestMoreItemSearchResults", self.detail.itemKey)
            if not sent then
                self:Notify("Load more failed: " .. tostring(err), true)
                return
            end
        end
    end

    self.pending = "more"
    self.requestSeq = (self.requestSeq or 0) + 1
    self.pendingToken = self.requestSeq
    self:StartTimeout(self.pendingToken)
    self:Notify("Loading more results...")
    self:Touch()
end

function Auction:BuildRows()
    local rows = {}

    if self.mode == "browse" then
        for _, result in ipairs(self.rawBrowse or {}) do
            local itemKey = result.itemKey
            if type(itemKey) == "table" then
                local itemID = itemKey.itemID
                local meta = self:GetItemMeta(itemID)
                local info = self.keyInfo[itemKeyString(itemKey)]
                if not info then
                    local infoOk, value = call("GetItemKeyInfo", itemKey)
                    if infoOk and value then
                        info = value
                        self.keyInfo[itemKeyString(itemKey)] = value
                    end
                end
                local name = (meta and meta.name) or (info and info.itemName) or ("Item " .. tostring(itemID or "?"))
                local quality = (meta and meta.quality) or (info and info.quality) or 1
                local minPrice = result.minPrice or result.buyout or result.minBid or 0
                rows[#rows + 1] = {
                    view = "browse",
                    itemKey = itemKey,
                    itemID = itemID,
                    itemLink = (meta and meta.link) or result.itemLink,
                    name = name,
                    quality = quality,
                    level = itemKey.itemLevel or (meta and meta.itemLevel) or 0,
                    qty = result.totalQuantity or result.quantity or 0,
                    price = minPrice,
                    buyout = nil,
                    time = "",
                    timeValue = 0,
                    kind = (info and info.isCommodity) and "commodity" or "item",
                    status = result.containsOwnerItem and "yours" or "active",
                    seller = result.containsOwnerItem and "You" or "",
                }
            end
        end
    elseif self.mode == "detail" and self.detail and self.detail.isCommodity then
        local itemID = self.detail.itemID
        local ok, count = call("GetNumCommoditySearchResults", itemID)
        count = ok and tonumber(count) or 0
        local meta = self:GetItemMeta(itemID)
        local info = self.keyInfo[self.detail.keyString]
        local name = (meta and meta.name)
            or (info and info.itemName)
            or self.detail.name
            or ("Item " .. tostring(itemID))
        local quality = (meta and meta.quality) or (info and info.quality) or 1
        local total = 0
        for index = 1, count do
            local got, result = call("GetCommoditySearchResultInfo", itemID, index)
            if got and type(result) == "table" then
                local quantity = tonumber(result.quantity) or 0
                total = total + quantity
                rows[#rows + 1] = {
                    view = "commodity",
                    auctionID = result.auctionID,
                    itemID = itemID,
                    itemKey = self.detail.itemKey,
                    itemLink = (meta and meta.link) or self.detail.itemLink,
                    name = name,
                    quality = quality,
                    level = 0,
                    qty = quantity,
                    price = tonumber(result.unitPrice) or 0,
                    buyout = nil,
                    time = formatSeconds(result.timeLeftSeconds),
                    timeValue = tonumber(result.timeLeftSeconds) or 0,
                    kind = "commodity",
                    status = (result.containsOwnerItem or result.containsAccountItem) and "yours" or "active",
                    seller = (result.owners and result.owners[1]) or "",
                }
            end
        end
        local qok, quantity = call("GetCommoditySearchResultsQuantity", itemID)
        self.maxQuantity = qok and tonumber(quantity) or total
    elseif self.mode == "detail" and self.detail then
        local itemKey = self.detail.itemKey
        local ok, count = call("GetNumItemSearchResults", itemKey)
        count = ok and tonumber(count) or 0
        local meta = self:GetItemMeta(self.detail.itemID)
        local info = self.keyInfo[self.detail.keyString]
        local baseName = (meta and meta.name)
            or (info and info.itemName)
            or self.detail.name
            or ("Item " .. tostring(self.detail.itemID))
        local baseQuality = (meta and meta.quality) or (info and info.quality) or 1
        for index = 1, count do
            local got, result = call("GetItemSearchResultInfo", itemKey, index)
            if got and type(result) == "table" then
                local resultKey = result.itemKey or itemKey
                local resultMeta = self:GetItemMeta(resultKey.itemID) or meta
                rows[#rows + 1] = {
                    view = "item",
                    auctionID = result.auctionID,
                    itemKey = resultKey,
                    itemID = resultKey.itemID,
                    itemLink = result.itemLink or (resultMeta and resultMeta.link) or self.detail.itemLink,
                    name = (resultMeta and resultMeta.name) or baseName,
                    quality = (resultMeta and resultMeta.quality) or baseQuality,
                    level = resultKey.itemLevel or (resultMeta and resultMeta.itemLevel) or 0,
                    qty = tonumber(result.quantity) or 1,
                    price = tonumber(result.bidAmount) or 0,
                    buyout = tonumber(result.buyoutAmount) or 0,
                    currentBid = tonumber(result.bidAmount) or 0,
                    bidAmount = tonumber(result.minBid) or tonumber(result.bidAmount) or 0,
                    time = formatTime(result.timeLeft or result.timeLeftSeconds),
                    timeValue = tonumber(result.timeLeftSeconds) or 0,
                    kind = "item",
                    status = (result.containsOwnerItem or result.containsAccountItem) and "yours" or "active",
                    seller = (result.owners and result.owners[1]) or "",
                    bidder = result.bidder,
                }
            end
        end
        self.maxQuantity = nil
    end

    self.rows = rows
end

function Auction:GetRows()
    return self.rows or {}
end

function Auction:GetCommodityMaxQuantity()
    return self.maxQuantity
end

function Auction:StartCommodityPurchase(row, quantity)
    if not self.active or not self.detail or not self.detail.isCommodity then
        self:Notify("Select a commodity lot first.", true)
        return
    end
    if self.purchase or self.quote then
        self:Notify("A commodity purchase is already in progress.", true)
        return
    end
    quantity = math.floor(tonumber(quantity) or 0)
    if quantity < 1 then
        self:Notify("Quantity must be at least 1.", true)
        return
    end
    if self.maxQuantity and quantity > self.maxQuantity then
        self:Notify("Only " .. tostring(self.maxQuantity) .. " available.", true)
        return
    end
    local sent, err = call("StartCommoditiesPurchase", self.detail.itemID, quantity)
    if not sent then
        self:Notify("Purchase request failed: " .. tostring(err), true)
        return
    end
    self.purchase = {
        itemID = self.detail.itemID,
        quantity = quantity,
        name = self.detail.name,
    }
    self.quote = nil
    self.lastError = nil
    local purchase = self.purchase
    self:Notify("Requesting price quote...")
    self:Touch()
    C_Timer.After(12, function()
        if self.purchase == purchase and not self.quote then
            self:CancelCommodityPurchase(true)
            self:Notify("Commodity quote timed out.", true)
            self:Touch()
        end
    end)
end

function Auction:ConfirmCommodityPurchase()
    if not self.purchase then
        return
    end
    local sent, err = call("ConfirmCommoditiesPurchase", self.purchase.itemID, self.purchase.quantity)
    if not sent then
        self:Notify("Purchase failed: " .. tostring(err), true)
        return
    end
    self.purchase.confirming = true
    self:Notify("Purchasing...")
    self:Touch()
end

function Auction:CancelCommodityPurchase(silent)
    if not self.purchase then
        self.quote = nil
        return
    end
    call("CancelCommoditiesPurchase")
    self.purchase = nil
    self.quote = nil
    if not silent then
        self:Notify("Purchase cancelled.")
        self:Touch()
    end
end

function Auction:PlaceBid(auctionID, amount, kind)
    if not self.active then
        self:Notify("Open the auction house first.", true)
        return
    end
    amount = math.floor(tonumber(amount) or 0)
    if not auctionID or amount < 1 then
        self:Notify("That auction has no valid price.", true)
        return
    end
    if self.actionPending then
        self:Notify("An auction action is already pending.", true)
        return
    end
    local sent, err = call("PlaceBid", auctionID, amount)
    if not sent then
        self:Notify("Auction action failed: " .. tostring(err), true)
        return
    end
    self.actionPending = true
    self.lastError = nil
    self:Notify(kind == "buyout" and "Buyout sent; refreshing..." or "Bid sent; refreshing...")
    self:Touch()
    C_Timer.After(1.2, function()
        if self.actionPending and self.active then
            self.actionPending = false
            self:Refresh()
        end
    end)
end

function Auction:OnEvent(event, ...)
    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        if not self.active or self.mode ~= "browse" or not self.pending then
            return
        end
        self:ClearPending()
        self.lastError = nil
        local ok, results = call("GetBrowseResults")
        self.rawBrowse = (ok and type(results) == "table") and results or {}
        self:BuildRows()
        self:Changed(event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
        if #self.rows == 0 then
            self:Notify("No results.")
        else
            self:Notify(string.format("%d results.", #self.rows))
        end
        return
    end

    if event == "AUCTION_HOUSE_BROWSE_FAILURE" then
        if not self.active or self.mode ~= "browse" or not self.pending then
            return
        end
        self:ClearPending()
        self.lastError = "Auction house browse failed."
        self:Notify(self.lastError, true)
        self:Touch()
        return
    end

    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "COMMODITY_SEARCH_RESULTS_ADDED" then
        local itemID = ...
        if not self.active or self.mode ~= "detail" or not self.detail or not self.pending then
            return
        end
        if type(itemID) == "number" and tonumber(itemID) ~= self.detail.itemID then
            return
        end
        self.detail.isCommodity = true
        self:ClearPending()
        self.lastError = nil
        self:BuildRows()
        self:Changed(event == "COMMODITY_SEARCH_RESULTS_UPDATED")
        if #self.rows == 0 then
            self:Notify("No commodity lots found.")
        else
            self:Notify(string.format("%d commodity lots.", #self.rows))
        end
        return
    end

    if event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
        local itemKey = ...
        if not self.active or self.mode ~= "detail" or not self.detail or not self.pending then
            return
        end
        if type(itemKey) == "table" and itemKeyString(itemKey) ~= self.detail.keyString then
            return
        end
        self.detail.isCommodity = false
        self:ClearPending()
        self.lastError = nil
        self:BuildRows()
        self:Changed(event == "ITEM_SEARCH_RESULTS_UPDATED")
        if #self.rows == 0 then
            self:Notify("No item lots found.")
        else
            self:Notify(string.format("%d item lots.", #self.rows))
        end
        return
    end

    if event == "COMMODITY_PRICE_UPDATED" then
        local unitPrice, totalPrice = ...
        if not self.purchase then
            return
        end
        self.quote = {
            itemID = self.purchase.itemID,
            quantity = self.purchase.quantity,
            unitPrice = tonumber(unitPrice) or 0,
            totalPrice = tonumber(totalPrice) or 0,
            name = self.purchase.name,
        }
        self:Notify("Price quote received.")
        if ns.UI and ns.UI.ShowCommodityQuote then
            ns.UI:ShowCommodityQuote(self.quote)
        end
        self:Touch()
        return
    end

    if event == "COMMODITY_PRICE_UNAVAILABLE" then
        if self.purchase then
            call("CancelCommoditiesPurchase")
            self.purchase = nil
            self.quote = nil
            self:Notify("That commodity is no longer available.", true)
            self:Touch()
        end
        return
    end

    if event == "COMMODITY_PURCHASE_SUCCEEDED" then
        self.purchase = nil
        self.quote = nil
        self:Notify("Commodity purchase complete.")
        self:Touch()
        C_Timer.After(0.6, function()
            if self.active then
                self:Refresh()
            end
        end)
        return
    end

    if event == "COMMODITY_PURCHASE_FAILED" then
        self.purchase = nil
        self.quote = nil
        self:Notify("Commodity purchase failed.", true)
        self:Touch()
        return
    end

    if event == "ITEM_KEY_ITEM_INFO_RECEIVED" then
        local itemID = ...
        local keys = {}
        for key, waiter in pairs(self.keyWaiters) do
            if waiter.itemKey.itemID == itemID then
                keys[#keys + 1] = key
            end
        end
        for _, key in ipairs(keys) do
            self:TryKeyInfo(key)
        end
        self:BuildRows()
        self:Changed(false)
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = ...
        if type(itemID) == "number" then
            self.itemMeta[itemID] = nil
            self:BuildRows()
            self:Changed(false)
        end
        return
    end

    if event == "BIDS_UPDATED" or event == "AUCTION_CANCELED" then
        if self.actionPending then
            self.actionPending = false
            self:Notify("Auction action completed.")
            self:Refresh()
        end
        return
    end

    if event == "UI_ERROR_MESSAGE" then
        local message = safeText(...)
        if not message or message == "" then
            return
        end
        if self.pending or self.purchase or self.actionPending then
            self.lastError = message
            self:Notify(message, true)
            if self.pending and message:lower():find("database", 1, true) then
                self:ClearPending()
            end
            self:Touch()
        end
        return
    end

    if event == "AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" then
        if self.pending then
            self:ClearPending()
            self.lastError = "Auction house dropped the query; try again."
            self:Notify(self.lastError, true)
            self:Touch()
        end
        return
    end

    if event == "CHAT_MSG_SYSTEM" then
        local message = safeText(...)
        if not message then
            return
        end
        if self.actionPending and message ~= "" then
            self.lastError = nil
        end
        return
    end

    if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        self:ResetThrottleTracking()
        self:Touch()
        return
    end

    if
        event == "AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED"
        or event == "AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED"
        or event == "AUCTION_HOUSE_THROTTLED_MESSAGE_SENT"
        or event == "AUCTION_HOUSE_NEW_BID_RECEIVED"
    then
        self:Touch()
    end
end
