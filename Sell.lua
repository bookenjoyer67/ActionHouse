local ADDON_NAME, ns = ...
local Sell = {}

ns.Sell = Sell

local BAG_IDS = { 0, 1, 2, 3, 4, 5 }
local DURATION_ORDER = { 1, 2, 3 }
local DURATION_LABEL = { [1] = "12h", [2] = "24h", [3] = "48h" }
local COPPER_PER_SILVER = 100
local PRICE_QUERY_TIMEOUT = 5
local PRICE_QUERY_RETRY = 1
local PRICE_QUERY_RETRY_DELAY = 1

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

local function trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
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
        return meta.name, meta.quality, meta.link or itemLink
    end

    local getInfo = _G.C_Item and _G.C_Item.GetItemInfo or _G.GetItemInfo
    if type(getInfo) == "function" then
        local values = { pcall(getInfo, itemLink or itemID) }
        if values[1] and values[2] then
            return values[2], values[4] or 1, values[3] or itemLink
        end
    end

    return itemNameFromLink(itemLink) or ("Item " .. tostring(itemID or "?")), 1, itemLink
end

local function commodityStatus(location)
    local ok, status = call("GetItemCommodityStatus", location)
    if not ok then
        return nil
    end
    local enum = rawget(_G, "Enum")
    local commodity = enum and enum.ItemCommodityStatus and enum.ItemCommodityStatus.Commodity or 2
    local item = enum and enum.ItemCommodityStatus and enum.ItemCommodityStatus.Item or 1
    if status == commodity then
        return "commodity"
    elseif status == item then
        return "item"
    end
    return nil
end

local function formatMoney(value)
    if not value or value <= 0 then
        return "—"
    end
    return ns.Money.Format(value)
end

local function enumSort(name, fallback)
    local enum = rawget(_G, "Enum")
    local orders = enum and enum.AuctionHouseSortOrder
    if orders and orders[name] ~= nil then
        return orders[name]
    end
    return fallback
end

local function getVendorPrice(itemLink)
    local cItem = rawget(_G, "C_Item")
    local getInfo = cItem and cItem.GetItemInfo or rawget(_G, "GetItemInfo")
    if type(getInfo) ~= "function" or itemLink == nil then
        return nil
    end
    local values = { pcall(getInfo, itemLink) }
    if not values[1] then
        return nil
    end
    return tonumber(values[12])
end

local function getDefaultPriceMultiplier()
    local constants = rawget(_G, "Constants")
    local auction = constants and constants.AuctionConstants
    local multiplier = auction and tonumber(auction.DEFAULT_AUCTION_PRICE_MULTIPLIER)
    return multiplier or 1.5
end

local function roundDefaultPrice(value)
    value = math.max(tonumber(value) or 0, 0)
    value = value + (COPPER_PER_SILVER - (value % COPPER_PER_SILVER))
    return math.max(value, COPPER_PER_SILVER)
end

local function undercutPrice(value, ownListing)
    value = math.floor(tonumber(value) or 0)
    if value <= 0 or ownListing then
        return value
    end
    return math.max(1, value - 1)
end

function Sell:Init()
    if self.frame then
        return
    end

    self.active = false
    self.rows = {}
    self.form = nil
    self.posting = false
    self.postForm = nil
    self.lastError = nil
    self.bagRefreshToken = 0

    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
    for _, event in ipairs({
        "BAG_UPDATE_DELAYED",
        "ITEM_LOCK_CHANGED",
        "AUCTION_HOUSE_AUCTION_CREATED",
        "AUCTION_MULTISELL_FAILURE",
        "AUCTION_MULTISELL_UPDATE",
        "COMMODITY_SEARCH_RESULTS_UPDATED",
        "ITEM_SEARCH_RESULTS_UPDATED",
        "UI_ERROR_MESSAGE",
    }) do
        pcall(self.frame.RegisterEvent, self.frame, event)
    end
end

function Sell:Notify(text, isError)
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

function Sell:Changed(reset)
    if ns.UI and ns.UI.OnSellDataChanged then
        ns.UI:OnSellDataChanged(reset)
    end
end

function Sell:IsActive()
    return self.active and true or false
end

function Sell:GetRows()
    return self.rows or {}
end

function Sell:GetForm()
    return self.form
end

function Sell:IsPosting()
    return self.posting
end

function Sell:ShouldAutoPopulatePrice()
    local fn = apiFunction("ShouldAutoPopulatePrice")
    if not fn then
        return false
    end
    local ok, value = pcall(fn)
    return ok and value == true
end

function Sell:GetDefaultPrice(form)
    if not form or not self:ShouldAutoPopulatePrice() then
        return 0
    end

    local vendorPrice = getVendorPrice(form.itemLink)
    if vendorPrice == nil then
        vendorPrice = getVendorPrice(form.itemID)
    end
    local defaultPrice = vendorPrice and (vendorPrice * getDefaultPriceMultiplier()) or COPPER_PER_SILVER
    return roundDefaultPrice(defaultPrice)
end

function Sell:GetItemKey(location, itemID)
    local ok, key = call("GetItemKeyFromItem", location)
    if not ok or type(key) ~= "table" then
        local madeOk, made = call("MakeItemKey", itemID)
        if madeOk and type(made) == "table" then
            key = made
        end
    end
    if type(key) ~= "table" then
        return nil, nil
    end

    local copy = {
        itemID = tonumber(key.itemID) or tonumber(itemID) or 0,
        itemLevel = tonumber(key.itemLevel) or 0,
        itemSuffix = tonumber(key.itemSuffix) or 0,
        battlePetSpeciesID = tonumber(key.battlePetSpeciesID) or 0,
    }
    local infoOk, info = call("GetItemKeyInfo", copy)
    if infoOk and type(info) == "table" then
        if info.isEquipment then
            copy.itemLevel = 0
            copy.itemSuffix = 0
        end
        return copy, info
    end
    return copy, nil
end

function Sell:GetPriceLabel(form)
    if not form then
        return "none"
    end
    if form.priceTouched then
        return "manual"
    end
    if form.priceQueryToken then
        return "searching AH"
    end
    if form.priceSource == "market" then
        return form.priceOwn and "own listing" or "lowest -1c"
    elseif form.priceSource == "vendor" then
        if form.priceLookup == "none" then
            return "vendor (no listings)"
        elseif form.priceLookup == "timeout" then
            return "vendor (timeout)"
        end
        return "vendor default"
    elseif form.priceSource == "off" then
        return "auto off"
    end
    return "none"
end

function Sell:ApplyDefaultPrice(form)
    if not form then
        return
    end

    form.autoPrice = self:ShouldAutoPopulatePrice()
    local defaultPrice = self:GetDefaultPrice(form)
    form.defaultPrice = defaultPrice
    form.priceTouched = false
    form.priceOwn = false
    form.priceLookup = nil
    form.priceSource = defaultPrice > 0 and "vendor" or "off"

    if form.commodity then
        local unitPrice = self:GetField(form, "unitPrice")
        if unitPrice then
            unitPrice.value = defaultPrice
        end
    else
        local bid = self:GetField(form, "bid")
        local buyout = self:GetField(form, "buyout")
        if bid then
            bid.value = 0
        end
        if buyout then
            buyout.value = defaultPrice
        end
    end
end

function Sell:ApplyMarketPrice(form, unitPrice, bid, buyout, ownListing)
    if self.form ~= form or form.priceTouched then
        return false
    end

    if form.commodity then
        local unit = self:GetField(form, "unitPrice")
        if not unit then
            return false
        end
        unit.value = math.max(1, math.floor(tonumber(unitPrice) or 0))
    else
        bid = math.max(0, math.floor(tonumber(bid) or 0))
        buyout = math.max(0, math.floor(tonumber(buyout) or 0))
        if bid <= 0 and buyout <= 0 then
            return false
        end
        local bidField = self:GetField(form, "bid")
        local buyoutField = self:GetField(form, "buyout")
        if bidField then
            bidField.value = bid
        end
        if buyoutField then
            buyoutField.value = buyout
        end
    end

    form.priceSource = "market"
    form.priceOwn = ownListing and true or false
    form.priceLookup = "done"
    self:RenderForm()
    return true
end

function Sell:RenderForm()
    if ns.UI and ns.UI.sellForm and ns.UI.sellForm:IsShown() then
        ns.UI.sellForm:Render()
    end
end

function Sell:SchedulePriceRetry(form)
    if not form or form ~= self.form or form.priceRetryScheduled then
        return
    end
    if (form.priceRetryCount or 0) >= PRICE_QUERY_RETRY or form.priceTouched then
        return
    end

    form.priceRetryCount = (form.priceRetryCount or 0) + 1
    form.priceRetryScheduled = true
    C_Timer.After(PRICE_QUERY_RETRY_DELAY, function()
        if self.form ~= form then
            return
        end
        form.priceRetryScheduled = nil
        if form.priceQueryToken or form.priceTouched then
            return
        end
        self:RequestPrice(form, true)
    end)
end

function Sell:RequestPrice(form, isRetry)
    if self.form ~= form or self.posting or form.priceQueryToken then
        return false
    end
    if not form.autoPrice or form.priceTouched or type(form.itemKey) ~= "table" then
        return false
    end

    if not form.itemKeyInfo then
        local infoOk, info = call("GetItemKeyInfo", form.itemKey)
        if infoOk and type(info) == "table" then
            form.itemKeyInfo = info
        else
            if not isRetry then
                self:SchedulePriceRetry(form)
            end
            return false
        end
    end

    local auction = ns.Auction
    if not auction or type(auction.CanQuery) ~= "function" then
        return false
    end
    local ok = auction:CanQuery(true)
    if not ok then
        local stuck = auction.IsThrottleStuck and auction:IsThrottleStuck()
        if not isRetry and not stuck then
            self:SchedulePriceRetry(form)
        end
        return false
    end

    local sorts
    if form.commodity then
        sorts = { { sortOrder = enumSort("Price", 0), reverseSort = false } }
    else
        sorts = { { sortOrder = enumSort("Buyout", 4), reverseSort = false } }
    end

    local sendName = "SendSearchQuery"
    local splitOwned = false
    if not form.commodity and form.itemKeyInfo and form.itemKeyInfo.isEquipment then
        sendName = "SendSellSearchQuery"
        splitOwned = true
    end

    local sent, sendErr = call(sendName, form.itemKey, sorts, splitOwned)
    if not sent then
        form.priceLookup = "failed"
        form.priceQueryError = tostring(sendErr or "unknown")
        if not isRetry then
            self:SchedulePriceRetry(form)
        end
        return false
    end
    if auction.RecordDirectSearch then
        auction:RecordDirectSearch()
    end

    local token = (form.priceQuerySeq or 0) + 1
    form.priceQuerySeq = token
    form.priceQueryToken = token
    form.priceLookup = "searching"
    C_Timer.After(PRICE_QUERY_TIMEOUT, function()
        if self.form ~= form or form.priceQueryToken ~= token then
            return
        end
        form.priceQueryToken = nil
        form.priceLookup = "timeout"
        self:RenderForm()
    end)
    return true
end

function Sell:IsPriceQueryPending()
    local form = self.form
    return form ~= nil and form.priceQueryToken ~= nil
end

function Sell:RefreshPrice()
    local form = self.form
    if not form then
        self:Notify("Open a sell form first.", true)
        return false
    end
    if self.posting then
        self:Notify("A post is still pending; wait for it to finish.", true)
        return false
    end
    if not form.autoPrice then
        self:Notify("Blizzard auto price is off.", true)
        return false
    end

    form.priceQueryToken = nil
    form.priceRetryScheduled = nil
    form.priceRetryCount = 0
    self:ApplyDefaultPrice(form)
    self:RenderForm()
    return self:RequestPrice(form, false)
end

function Sell:HandleCommodityPrice(itemID)
    local form = self.form
    if not form or not form.commodity or not form.priceQueryToken then
        return
    end
    if type(itemID) == "table" then
        itemID = itemID.itemID
    end
    if itemID ~= nil and tonumber(itemID) ~= form.itemID then
        return
    end

    form.priceQueryToken = nil
    if form.priceTouched then
        form.priceLookup = "done"
        return
    end

    local countOk, count = call("GetNumCommoditySearchResults", form.itemID)
    count = countOk and tonumber(count) or 0
    local best
    for index = 1, count do
        local got, result = call("GetCommoditySearchResultInfo", form.itemID, index)
        if got and type(result) == "table" then
            local unitPrice = tonumber(result.unitPrice) or 0
            if unitPrice > 0 and (not best or unitPrice < (tonumber(best.unitPrice) or math.huge)) then
                best = result
            end
        end
    end

    if not best then
        form.priceLookup = "none"
        self:RenderForm()
        return
    end

    local ownListing = best.containsOwnerItem or best.containsAccountItem
    local unitPrice = undercutPrice(best.unitPrice, ownListing)
    if unitPrice < 1 then
        unitPrice = 1
    end
    form.priceLookup = "done"
    self:ApplyMarketPrice(form, unitPrice, nil, nil, ownListing)
end

local function isBetterItemResult(candidate, current)
    if not current then
        return true
    end
    if candidate.buyoutAmount ~= nil and current.buyoutAmount ~= nil then
        return candidate.buyoutAmount < current.buyoutAmount
    end
    if (candidate.buyoutAmount ~= nil) ~= (current.buyoutAmount ~= nil) then
        return candidate.buyoutAmount ~= nil
    end
    if candidate.bidAmount ~= nil and current.bidAmount ~= nil then
        return candidate.bidAmount < current.bidAmount
    end
    if (candidate.bidAmount ~= nil) ~= (current.bidAmount ~= nil) then
        return candidate.bidAmount ~= nil
    end
    return false
end

function Sell:HandleItemPrice(itemKey)
    local form = self.form
    if not form or form.commodity or not form.priceQueryToken then
        return
    end
    if type(itemKey) == "table" and tonumber(itemKey.itemID) ~= form.itemID then
        return
    end

    form.priceQueryToken = nil
    if form.priceTouched then
        form.priceLookup = "done"
        return
    end

    local itemLevel = tonumber(form.itemKey and form.itemKey.itemLevel) or 0
    local quality = tonumber(form.quality) or 0
    local cItem = rawget(_G, "C_Item")
    if cItem and type(cItem.GetCurrentItemLevel) == "function" then
        local ok, value = pcall(cItem.GetCurrentItemLevel, form.location)
        if ok and tonumber(value) then
            itemLevel = tonumber(value)
        end
    end
    if cItem and type(cItem.GetItemQuality) == "function" then
        local ok, value = pcall(cItem.GetItemQuality, form.location)
        if ok and tonumber(value) then
            quality = tonumber(value)
        end
    end

    local keyInfo = form.itemKeyInfo
    local ignoreItemLevel = quality == 2 or (keyInfo and keyInfo.isPet)
    local countOk, count = call("GetNumItemSearchResults", form.itemKey)
    count = countOk and tonumber(count) or 0
    local best
    for index = 1, count do
        local got, result = call("GetItemSearchResultInfo", form.itemKey, index)
        if got and type(result) == "table" then
            local resultLevel = tonumber(result.itemKey and result.itemKey.itemLevel) or 0
            if (ignoreItemLevel or resultLevel == itemLevel) and isBetterItemResult(result, best) then
                best = result
            end
        end
    end

    if not best then
        form.priceLookup = "none"
        self:RenderForm()
        return
    end

    local ownListing = best.containsOwnerItem or best.containsAccountItem
    local bid = tonumber(best.bidAmount) or 0
    local buyout = tonumber(best.buyoutAmount) or 0
    if not ownListing then
        if buyout > 0 then
            buyout = undercutPrice(buyout, false)
            if bid > 0 and bid >= buyout then
                bid = math.max(0, buyout - 1)
            end
        elseif bid > 0 then
            bid = undercutPrice(bid, false)
        end
    end

    form.priceLookup = "done"
    self:ApplyMarketPrice(form, nil, bid, buyout, ownListing)
end

function Sell:OnShow()
    self:Init()
    self.active = true
    self:RefreshBags()
end

function Sell:OnClose()
    self.active = false
    self:CloseForm()
    self.rows = {}
    self.lastError = nil
    self.posting = false
    self.postForm = nil
    self:Changed(true)
end

function Sell:GetBagLocation(bag, slot)
    local itemLocation = rawget(_G, "ItemLocation")
    if not itemLocation or type(itemLocation.CreateFromBagAndSlot) ~= "function" then
        return nil
    end
    local location = itemLocation:CreateFromBagAndSlot(bag, slot)
    if not location or (location.IsValid and not location:IsValid()) then
        return nil
    end
    return location
end

function Sell:RefreshBags(reset)
    local shouldReset = reset == true
    if not self.active then
        return
    end

    local container = rawget(_G, "C_Container")
    if not container then
        self.rows = {}
        self:Changed(shouldReset)
        return
    end

    local rows = {}
    for _, bag in ipairs(BAG_IDS) do
        local slots = 0
        local ok, count = pcall(container.GetContainerNumSlots, bag)
        if ok then
            slots = tonumber(count) or 0
        end
        for slot = 1, slots do
            local infoOk, info = pcall(container.GetContainerItemInfo, bag, slot)
            if infoOk and type(info) == "table" and info.hyperlink and info.itemID then
                local location = self:GetBagLocation(bag, slot)
                if
                    location
                    and C_Item
                    and type(C_Item.DoesItemExist) == "function"
                    and C_Item.DoesItemExist(location)
                then
                    local validOk, valid = call("IsSellItemValid", location, false)
                    local kind = commodityStatus(location)
                    if validOk and valid and kind then
                        local postOk, available = call("GetAvailablePostCount", location)
                        available = postOk and tonumber(available) or 0
                        local stackCount = tonumber(info.stackCount) or 0
                        if available > 0 and stackCount > 0 then
                            local name, quality, link = itemDetails(info.itemID, info.hyperlink)
                            rows[#rows + 1] = {
                                view = "sell",
                                bag = bag,
                                slot = slot,
                                itemID = info.itemID,
                                itemLink = link or info.hyperlink,
                                name = name or info.hyperlink,
                                quality = info.quality or quality or 1,
                                qty = stackCount,
                                available = math.min(available, stackCount),
                                kind = kind,
                                status = "ready",
                                icon = info.iconFileID,
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(rows, function(left, right)
        if left.bag ~= right.bag then
            return left.bag < right.bag
        end
        return left.slot < right.slot
    end)

    self.rows = rows
    self:Changed(shouldReset)
end

function Sell:ScheduleBagRefresh()
    if not self.active or self.posting then
        return
    end
    self.bagRefreshToken = (self.bagRefreshToken or 0) + 1
    local token = self.bagRefreshToken
    C_Timer.After(0.15, function()
        if self.bagRefreshToken == token and self.active and not self.posting then
            self:RefreshBags(false)
        end
    end)
end

function Sell:GetField(form, key)
    if not form then
        return nil
    end
    for _, field in ipairs(form.fields) do
        if field.key == key then
            return field
        end
    end
    return nil
end

function Sell:FieldDisplay(form, field)
    if not field then
        return ""
    end
    if field.kind == "duration" then
        return DURATION_LABEL[field.value] or tostring(field.value)
    elseif field.kind == "money" then
        return formatMoney(field.value)
    end
    return tostring(field.value)
end

function Sell:FieldLabel(field)
    return field and field.label or "?"
end

function Sell:SetField(form, key, value)
    local field = self:GetField(form, key)
    if not field then
        return false, "Unknown field."
    end

    if field.kind == "quantity" then
        value = math.floor(tonumber(value) or 0)
        if value < 1 then
            return false, "Quantity must be at least 1."
        end
        if field.max and value > field.max then
            return false, "Quantity exceeds the available amount."
        end
    elseif field.kind == "duration" then
        value = tonumber(value)
        if not value or value < 1 or value > 3 then
            return false, "Duration must be 12, 24, or 48 hours."
        end
        value = math.floor(value)
    elseif field.kind == "money" then
        value = math.floor(tonumber(value) or -1)
        if value < 0 then
            return false, "Price cannot be negative."
        end
    end

    field.value = value
    if field.kind == "money" then
        form.priceTouched = true
        form.priceSource = "manual"
    end
    return true
end

function Sell:SetFieldFromText(form, key, text)
    local field = self:GetField(form, key)
    if not field then
        return false, "Unknown field."
    end
    text = trim(text)
    if field.kind == "quantity" then
        local value, err = ns.Money.ParseQuantity(text, field.max)
        if not value then
            return false, err or "Invalid quantity."
        end
        return self:SetField(form, key, value)
    elseif field.kind == "duration" then
        local value = tonumber(text:match("^%d+"))
        if value == 12 then
            value = 1
        elseif value == 24 then
            value = 2
        elseif value == 48 then
            value = 3
        end
        if not value or value < 1 or value > 3 then
            return false, "Duration must be 12, 24, or 48 hours."
        end
        return self:SetField(form, key, math.floor(value))
    elseif field.kind == "money" then
        local value, err = ns.Money.Parse(text)
        if not value then
            return false, err or "Invalid price."
        end
        return self:SetField(form, key, value)
    end
    return false, "Unsupported field."
end

function Sell:AdjustField(form, key, delta)
    local field = self:GetField(form, key)
    if not field then
        return false
    end
    delta = tonumber(delta) or 0
    if field.kind == "quantity" then
        return self:SetField(form, key, field.value + delta)
    elseif field.kind == "duration" then
        local index = 1
        for position, value in ipairs(DURATION_ORDER) do
            if value == field.value then
                index = position
                break
            end
        end
        index = index + delta
        while index < 1 do
            index = index + #DURATION_ORDER
        end
        while index > #DURATION_ORDER do
            index = index - #DURATION_ORDER
        end
        return self:SetField(form, key, DURATION_ORDER[index])
    elseif field.kind == "money" then
        return self:SetField(form, key, math.max(0, field.value + (delta * 100)))
    end
    return false
end

function Sell:GetDeposit(form)
    if not form then
        return nil
    end
    local quantityField = self:GetField(form, "quantity")
    local durationField = self:GetField(form, "duration")
    if not quantityField or not durationField then
        return nil
    end
    if form.commodity then
        local ok, value = call("CalculateCommodityDeposit", form.itemID, durationField.value, quantityField.value)
        return ok and tonumber(value) or nil
    end
    local ok, value = call("CalculateItemDeposit", form.location, durationField.value, quantityField.value)
    return ok and tonumber(value) or nil
end

function Sell:GetTotal(form)
    if not form then
        return 0
    end
    local quantity = self:GetField(form, "quantity")
    if not quantity then
        return 0
    end
    if form.commodity then
        local unit = self:GetField(form, "unitPrice")
        return (unit and unit.value or 0) * quantity.value
    end
    local buyout = self:GetField(form, "buyout")
    local bid = self:GetField(form, "bid")
    local unit = (buyout and buyout.value) or (bid and bid.value) or 0
    return unit * quantity.value
end

function Sell:SupportsCopper()
    local fn = apiFunction("SupportsCopperValues")
    if not fn then
        return true
    end
    local ok, value = pcall(fn)
    if ok and type(value) == "boolean" then
        return value
    end
    return true
end

function Sell:NormalizePrice(value)
    value = math.floor(tonumber(value) or 0)
    if value <= 0 or self:SupportsCopper() then
        return value, false
    end
    return math.ceil(value / 100) * 100, true
end

function Sell:Validate(form)
    if not form then
        return "No item selected."
    end
    if not form.location or (form.location.IsValid and not form.location:IsValid()) then
        return "That item is no longer in your bags."
    end
    if C_Item and type(C_Item.DoesItemExist) == "function" and not C_Item.DoesItemExist(form.location) then
        return "That item is no longer in your bags."
    end
    local quantity = self:GetField(form, "quantity")
    local duration = self:GetField(form, "duration")
    if not quantity or quantity.value < 1 then
        return "Quantity must be at least 1."
    end
    local availableOk, available = call("GetAvailablePostCount", form.location)
    available = availableOk and tonumber(available) or quantity.max
    if available and quantity.value > available then
        return "Quantity exceeds the available amount."
    end
    if not duration or duration.value < 1 or duration.value > 3 then
        return "Invalid duration."
    end

    if ns.Auction and type(ns.Auction.CheckThrottle) == "function" then
        local throttleOk, throttleErr = ns.Auction:CheckThrottle()
        if not throttleOk then
            return throttleErr
        end
    end

    if form.commodity then
        local unit = self:GetField(form, "unitPrice")
        if not unit or unit.value < 1 then
            return "Enter a unit price."
        end
    else
        local bid = self:GetField(form, "bid")
        local buyout = self:GetField(form, "buyout")
        if (not bid or bid.value < 1) and (not buyout or buyout.value < 1) then
            return "Enter a starting bid or buyout."
        end
        if bid and buyout and bid.value > 0 and buyout.value > 0 and bid.value >= buyout.value then
            return "Starting bid must be lower than the buyout."
        end
    end
    return nil
end

function Sell:OpenForm(row)
    if not self.active then
        self:Notify("Open the auction house first.", true)
        return false
    end
    if self.form then
        self:Notify("A sell form is already open.", true)
        return false
    end
    if self.posting then
        self:Notify("A post is still pending; wait for it to finish.", true)
        return false
    end
    if not row or not row.bag or not row.slot then
        self:Notify("No bag item selected.", true)
        return false
    end

    local location = self:GetBagLocation(row.bag, row.slot)
    local validOk, valid = call("IsSellItemValid", location, false)
    if not location or not validOk or not valid then
        self:Notify("That item cannot be auctioned.", true)
        self:RefreshBags()
        return false
    end

    local container = rawget(_G, "C_Container")
    local infoOk, info = pcall(container.GetContainerItemInfo, row.bag, row.slot)
    if not infoOk or type(info) ~= "table" then
        self:Notify("That item is no longer in your bags.", true)
        self:RefreshBags()
        return false
    end

    local kind = commodityStatus(location)
    if not kind then
        self:Notify("That item has an unknown auction type.", true)
        return false
    end

    local postOk, available = call("GetAvailablePostCount", location)
    available = postOk and tonumber(available) or 0
    local stackCount = tonumber(info.stackCount) or 0
    available = math.min(available, stackCount)
    if available < 1 then
        self:Notify("That item cannot be posted right now.", true)
        return false
    end

    if C_Item and type(C_Item.LockItem) == "function" then
        pcall(C_Item.LockItem, location)
    end

    local name, quality, link = itemDetails(info.itemID, info.hyperlink)
    local duration = tonumber(ns.charDB and ns.charDB.sellDuration) or 2
    if duration < 1 or duration > 3 then
        duration = 2
    end

    local fields
    if kind == "commodity" then
        fields = {
            { key = "quantity", label = "Quantity", kind = "quantity", value = available, max = available },
            { key = "duration", label = "Duration", kind = "duration", value = duration },
            { key = "unitPrice", label = "Unit price", kind = "money", value = 0 },
        }
    else
        fields = {
            { key = "quantity", label = "Stack size", kind = "quantity", value = available, max = available },
            { key = "duration", label = "Duration", kind = "duration", value = duration },
            { key = "bid", label = "Starting bid", kind = "money", value = 0 },
            { key = "buyout", label = "Buyout", kind = "money", value = 0 },
        }
    end

    self.form = {
        row = row,
        location = location,
        itemID = info.itemID,
        itemLink = link or info.hyperlink,
        name = name or info.hyperlink,
        quality = info.quality or quality or 1,
        commodity = kind == "commodity",
        available = available,
        fields = fields,
        selected = 1,
        bag = row.bag,
        slot = row.slot,
        autoPrice = self:ShouldAutoPopulatePrice(),
        priceRetryCount = 0,
    }
    self.form.itemKey, self.form.itemKeyInfo = self:GetItemKey(location, info.itemID)
    self:ApplyDefaultPrice(self.form)

    if ns.UI and ns.UI.ShowSellForm then
        ns.UI:ShowSellForm(self.form)
    end
    self:RequestPrice(self.form, false)
    return true
end

function Sell:CloseForm()
    local form = self.form
    if not form then
        return
    end
    form.priceQueryToken = nil
    if C_Item and type(C_Item.UnlockItem) == "function" and form.location then
        pcall(C_Item.UnlockItem, form.location)
    end
    if self.postForm == form then
        self.posting = false
        self.postForm = nil
    end
    self.form = nil
end

function Sell:SaveDefaults(form)
    if not form or not ns.charDB then
        return
    end
    local duration = self:GetField(form, "duration")
    if duration then
        ns.charDB.sellDuration = duration.value
    end
end

function Sell:GetFormConfirmation(form)
    if not form then
        return ""
    end
    local quantity = self:GetField(form, "quantity")
    local duration = self:GetField(form, "duration")
    local deposit = self:GetDeposit(form)
    if form.commodity then
        local unit = self:GetField(form, "unitPrice")
        return string.format(
            "Post %dx %s for %s each (%s total), %s? Deposit: %s",
            quantity.value,
            tostring(form.name),
            formatMoney(unit and unit.value),
            formatMoney(self:GetTotal(form)),
            DURATION_LABEL[duration.value] or "?",
            deposit and ns.Money.Format(deposit) or "unknown"
        )
    end
    local bid = self:GetField(form, "bid")
    local buyout = self:GetField(form, "buyout")
    return string.format(
        "Post %dx %s, %s, bid %s, buyout %s? Deposit: %s",
        quantity.value,
        tostring(form.name),
        DURATION_LABEL[duration.value] or "?",
        formatMoney(bid and bid.value),
        formatMoney(buyout and buyout.value),
        deposit and ns.Money.Format(deposit) or "unknown"
    )
end

local function cachePendingPost(commodity, ...)
    local frame = rawget(_G, "AuctionHouseFrame")
    local sellFrame
    if frame then
        sellFrame = commodity and frame.CommoditiesSellFrame or frame.ItemSellFrame
    end
    if not sellFrame or type(sellFrame.CachePendingPost) ~= "function" then
        return false
    end
    local ok = pcall(sellFrame.CachePendingPost, sellFrame, ...)
    return ok
end

function Sell:PostForm(form)
    if not form or form ~= self.form then
        return false
    end
    if self.posting then
        self:Notify("A post is already pending.", true)
        return false
    end

    local err = self:Validate(form)
    if err then
        self:Notify(err, true)
        return false
    end

    local quantity = self:GetField(form, "quantity")
    local duration = self:GetField(form, "duration")
    local normalized = false
    local confirmationRequired = false

    if form.commodity then
        local unit = self:GetField(form, "unitPrice")
        local value, changed = self:NormalizePrice(unit.value)
        unit.value = value
        normalized = normalized or changed
        local sent, result = call("PostCommodity", form.location, duration.value, quantity.value, value)
        if not sent then
            self.lastError = "Post failed: " .. tostring(result)
            self:Notify(self.lastError, true)
            return false
        end
        if result == true then
            if not cachePendingPost(true, form.location, duration.value, quantity.value, value) then
                self:Notify("Post needs Blizzard's confirmation, but the AH confirmation frame is unavailable.", true)
                return false
            end
            confirmationRequired = true
        end
    else
        local bidField = self:GetField(form, "bid")
        local buyoutField = self:GetField(form, "buyout")
        local bid, bidChanged = 0, false
        if bidField.value > 0 then
            bid, bidChanged = self:NormalizePrice(bidField.value)
        end
        local buyout, buyoutChanged = 0, false
        if buyoutField.value > 0 then
            buyout, buyoutChanged = self:NormalizePrice(buyoutField.value)
        end
        bidField.value = bid
        buyoutField.value = buyout
        normalized = normalized or bidChanged or buyoutChanged
        local bidParam = bid > 0 and bid or nil
        local buyoutParam = buyout > 0 and buyout or nil
        local sent, result = call("PostItem", form.location, duration.value, quantity.value, bidParam, buyoutParam)
        if not sent then
            self.lastError = "Post failed: " .. tostring(result)
            self:Notify(self.lastError, true)
            return false
        end
        if result == true then
            if not cachePendingPost(false, form.location, duration.value, quantity.value, bidParam, buyoutParam) then
                self:Notify("Post needs Blizzard's confirmation, but the AH confirmation frame is unavailable.", true)
                return false
            end
            confirmationRequired = true
        end
    end

    if normalized then
        self:Notify("Prices were rounded up to silver for this post.")
    end

    self:SaveDefaults(form)
    self.posting = true
    self.postForm = form
    self.lastError = nil
    if confirmationRequired then
        self:Notify("Confirm the post in Blizzard's confirmation dialog.")
    else
        self:Notify("Posting auction...")
    end
    local timeout = confirmationRequired and 30 or 5
    C_Timer.After(timeout, function()
        if self.posting and self.postForm == form then
            self.posting = false
            self.postForm = nil
            self:Notify("Post status unknown; returning to bags.", true)
            self:CloseForm()
            if ns.UI and ns.UI.HideSellForm then
                ns.UI:HideSellForm()
            end
            self:RefreshBags()
        end
    end)
    return true
end

function Sell:HandlePostSuccess()
    if not self.posting then
        return
    end
    local form = self.postForm
    self.posting = false
    self.postForm = nil
    self.lastError = nil
    self:CloseForm()
    if ns.UI and ns.UI.HideSellForm then
        ns.UI:HideSellForm()
    end
    self:Notify("Auction posted.")
    C_Timer.After(0.2, function()
        if self.active then
            self:RefreshBags()
        end
    end)
end

function Sell:HandlePostFailure(message)
    if not self.posting then
        return
    end
    self.posting = false
    self.postForm = nil
    self.lastError = message or "Auction post failed."
    self:Notify(self.lastError, true)
    self:RefreshBags()
end

function Sell:OnEvent(event, ...)
    if event == "BAG_UPDATE_DELAYED" then
        if self.active then
            self:ScheduleBagRefresh()
        end
        return
    end

    if event == "ITEM_LOCK_CHANGED" then
        if self.active and not self.form then
            self:ScheduleBagRefresh()
        end
        return
    end

    if event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        self:HandleCommodityPrice(...)
        return
    end

    if event == "ITEM_SEARCH_RESULTS_UPDATED" then
        self:HandleItemPrice(...)
        return
    end

    if event == "AUCTION_HOUSE_AUCTION_CREATED" then
        self:HandlePostSuccess()
        return
    end

    if event == "AUCTION_MULTISELL_FAILURE" then
        self:HandlePostFailure("Auction post failed.")
        return
    end

    if event == "AUCTION_MULTISELL_UPDATE" then
        return
    end

    if event == "UI_ERROR_MESSAGE" then
        local message = safeText(...)
        if self.posting and message and message ~= "" then
            self:HandlePostFailure(message)
        end
        return
    end
end

function Sell:GetStatusLines()
    local form = self.form
    local formText = "none"
    if form then
        formText = string.format("%s %s", form.name, form.commodity and "commodity" or "item")
    end
    local autoPrice = self:ShouldAutoPopulatePrice()
    if form then
        autoPrice = form.autoPrice
    end
    return {
        "active=" .. tostring(self.active),
        "rows=" .. tostring(#self.rows),
        "form=" .. formText,
        "autoprice=" .. tostring(autoPrice),
        "price=" .. (form and self:GetPriceLabel(form) or "none"),
        "posting=" .. tostring(self.posting),
        "lastError=" .. tostring(self.lastError or "none"),
    }
end
