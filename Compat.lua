local ADDON_NAME, ns = ...
local Compat = {}

ns.Compat = Compat

local AUCTION_API = {
    "SendBrowseQuery",
    "RequestMoreBrowseResults",
    "HasFullBrowseResults",
    "GetBrowseResults",
    "SendSearchQuery",
    "SendSellSearchQuery",
    "RequestMoreItemSearchResults",
    "RequestMoreCommoditySearchResults",
    "GetNumItemSearchResults",
    "GetItemSearchResultInfo",
    "GetNumCommoditySearchResults",
    "GetCommoditySearchResultInfo",
    "GetCommoditySearchResultsQuantity",
    "QueryOwnedAuctions",
    "GetNumOwnedAuctions",
    "GetOwnedAuctionInfo",
    "QueryBids",
    "GetNumBids",
    "GetBidInfo",
    "GetAuctionInfoByID",
    "PlaceBid",
    "StartCommoditiesPurchase",
    "ConfirmCommoditiesPurchase",
    "CancelCommoditiesPurchase",
    "GetQuoteDurationRemaining",
    "PostItem",
    "PostCommodity",
    "CancelAuction",
    "CanCancelAuction",
    "GetCancelCost",
    "GetAvailablePostCount",
    "CalculateItemDeposit",
    "CalculateCommodityDeposit",
    "IsSellItemValid",
    "GetItemCommodityStatus",
    "GetItemKeyFromItem",
    "MakeItemKey",
    "GetItemKeyInfo",
    "ShouldAutoPopulatePrice",
    "IsThrottledMessageSystemReady",
    "ReplicateItems",
    "CloseAuctionHouse",
    "IsAuctionHouseOpen",
}

local ENUMS = {
    "AuctionHouseSortOrder",
    "AuctionHouseFilter",
    "ItemCommodityStatus",
    "AuctionHouseAuctionStatus",
    "AuctionHouseCommodityStatus",
}

local function getGlobal(name)
    return rawget(_G, name)
end

local function trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Compat:GetBuildInfo()
    local ok, version, build, date, toc = pcall(GetBuildInfo)
    if not ok then
        return { version = "?", build = "?", date = "?", toc = "?" }
    end
    return {
        version = tostring(version or "?"),
        build = tostring(build or "?"),
        date = tostring(date or "?"),
        toc = tostring(toc or "?"),
    }
end

function Compat:GetBuildString()
    local info = self:GetBuildInfo()
    return info.version .. " / " .. info.toc
end

function Compat:IsForever()
    if self._isForever ~= nil then
        return self._isForever
    end

    local project = getGlobal("WOW_PROJECT_ID")
    local camelot = getGlobal("WOW_PROJECT_CAMELOT")
    local toc = tonumber(self:GetBuildInfo().toc)
    local isBuildRange = toc and toc >= 16000 and toc < 20000
    local isCamelot = project ~= nil and camelot ~= nil and project == camelot

    self._isForever = not not (isCamelot or isBuildRange)
    return self._isForever
end

function Compat:HasFunction(name)
    local api = getGlobal("C_AuctionHouse")
    return api ~= nil and type(api[name]) == "function"
end

function Compat:IsAddOnLoaded(name)
    local cAddOns = getGlobal("C_AddOns")
    if cAddOns and type(cAddOns.IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(cAddOns.IsAddOnLoaded, name)
        if ok then
            return loaded and true or false
        end
    end
    local isLoaded = getGlobal("IsAddOnLoaded")
    if type(isLoaded) == "function" then
        local ok, loaded = pcall(isLoaded, name)
        if ok then
            return loaded and true or false
        end
    end
    return false
end

function Compat:LoadAddOn(name)
    if self:IsAddOnLoaded(name) then
        return true
    end
    local cAddOns = getGlobal("C_AddOns")
    if cAddOns and type(cAddOns.LoadAddOn) == "function" then
        local ok, loaded = pcall(cAddOns.LoadAddOn, name)
        return ok and loaded and true or false
    end
    local loadAddOn = getGlobal("LoadAddOn")
    if type(loadAddOn) == "function" then
        local ok, loaded = pcall(loadAddOn, name)
        return ok and loaded and true or false
    end
    return false
end

function Compat:LoadAuctionHouseUI()
    return self:LoadAddOn("Blizzard_AuctionHouseUI")
end

function Compat:IsAuctionHouseOpen()
    if self.ahOpen ~= nil then
        return self.ahOpen
    end

    local api = getGlobal("C_AuctionHouse")
    if api and type(api.IsAuctionHouseOpen) == "function" then
        local ok, open = pcall(api.IsAuctionHouseOpen)
        if ok and type(open) == "boolean" then
            return open
        end
    end

    local frame = getGlobal("AuctionHouseFrame")
    if frame and frame.IsShown then
        local ok, shown = pcall(frame.IsShown, frame)
        if ok then
            return shown and true or false
        end
    end
    return false
end

function Compat:CloseAuctionHouse()
    local api = getGlobal("C_AuctionHouse")
    if api and type(api.CloseAuctionHouse) == "function" then
        local ok = pcall(api.CloseAuctionHouse)
        if ok then
            return true
        end
    end

    local close = getGlobal("CloseAuctionHouse")
    if type(close) == "function" then
        local ok = pcall(close)
        if ok then
            return true
        end
    end

    local frame = getGlobal("AuctionHouseFrame")
    if frame and frame.Hide then
        pcall(frame.Hide, frame)
        return true
    end
    return false
end

function Compat:RevealBlizzard()
    self:LoadAuctionHouseUI()
    local frame = getGlobal("AuctionHouseFrame")
    if frame and frame.Show then
        pcall(frame.Show, frame)
    end
end

---@return boolean|nil ready
function Compat:IsThrottled()
    local api = getGlobal("C_AuctionHouse")
    if not api or type(api.IsThrottledMessageSystemReady) ~= "function" then
        return nil
    end
    local ok, ready = pcall(api.IsThrottledMessageSystemReady)
    if ok and type(ready) == "boolean" then
        return ready
    end
    return nil
end

local function safeIsSecret(value)
    local isSecret = getGlobal("issecretvalue")
    if type(isSecret) ~= "function" then
        return false
    end
    local ok, secret = pcall(isSecret, value)
    return ok and secret and true or false
end

local function describeValue(value, depth, seen)
    if safeIsSecret(value) then
        return "<secret>"
    end

    local kind = type(value)
    if kind == "nil" then
        return "nil"
    elseif kind == "boolean" or kind == "number" then
        return tostring(value)
    elseif kind == "string" then
        local text = value:gsub("\n", "\\n"):gsub("\r", "\\r")
        if #text > 180 then
            text = text:sub(1, 177) .. "..."
        end
        return string.format("%q", text)
    elseif kind == "function" then
        return "<function>"
    elseif kind ~= "table" then
        return "<" .. kind .. ">"
    end

    if depth <= 0 then
        return "<table>"
    end
    seen = seen or {}
    if seen[value] then
        return "<cycle>"
    end
    seen[value] = true

    local keys = {}
    local count = 0
    local ok = pcall(function()
        for key in pairs(value) do
            keys[#keys + 1] = key
            count = count + 1
            if count >= 30 then
                break
            end
        end
    end)
    if not ok then
        return "<table>"
    end

    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)

    local parts = {}
    for index, key in ipairs(keys) do
        if index > 16 then
            parts[#parts + 1] = "..."
            break
        end
        parts[#parts + 1] = tostring(key) .. "=" .. describeValue(value[key], depth - 1, seen)
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function safeCall(api, name, ...)
    if not api or type(api[name]) ~= "function" then
        return false, "missing"
    end
    local ok, result = pcall(api[name], ...)
    if not ok then
        return false, tostring(result)
    end
    return true, result
end

local function enumDump(name)
    local enum = getGlobal("Enum")
    local value = enum and enum[name]
    if not value then
        return "missing"
    end

    local parts = {}
    local ok = pcall(function()
        for key in pairs(value) do
            parts[#parts + 1] = tostring(key) .. "=" .. describeValue(value[key], 0)
        end
    end)
    if not ok then
        return "<unreadable>"
    end
    table.sort(parts)
    return table.concat(parts, ", ")
end

local function frameTree()
    local frame = getGlobal("AuctionHouseFrame")
    if not frame then
        return { "AuctionHouseFrame = nil" }
    end

    local lines = {}
    lines[#lines + 1] = "AuctionHouseFrame type=" .. type(frame)
    local ok, name = pcall(function()
        return frame:GetName()
    end)
    lines[#lines + 1] = "name=" .. tostring(ok and name or "?")
    local shownOk, shown = pcall(frame.IsShown, frame)
    lines[#lines + 1] = "shown=" .. tostring(shownOk and shown or "?")
    local scaleOk, scale = pcall(frame.GetScale, frame)
    lines[#lines + 1] = "scale=" .. tostring(scaleOk and scale or "?")
    local strataOk, strata = pcall(frame.GetFrameStrata, frame)
    lines[#lines + 1] = "strata=" .. tostring(strataOk and strata or "?")

    local children = {}
    local childOk = pcall(function()
        for _, child in ipairs({ frame:GetChildren() }) do
            local childName = nil
            if child.GetName then
                local nameOk, value = pcall(child.GetName, child)
                if nameOk then
                    childName = value
                end
            end
            children[#children + 1] = childName or "<unnamed>"
            if #children >= 40 then
                break
            end
        end
    end)
    if childOk then
        table.sort(children)
        lines[#lines + 1] = "children: " .. table.concat(children, ", ")
    else
        lines[#lines + 1] = "children: <unreadable>"
    end
    return lines
end

function Compat:Probe(live)
    self:LoadAuctionHouseUI()

    local lines = {}
    local function add(text)
        lines[#lines + 1] = tostring(text)
    end

    local build = self:GetBuildInfo()
    local project = getGlobal("WOW_PROJECT_ID")
    local camelot = getGlobal("WOW_PROJECT_CAMELOT")
    local realm = "?"
    if type(getGlobal("GetRealmName")) == "function" then
        local realmOk, realmValue = pcall(getGlobal("GetRealmName"))
        if realmOk then
            realm = tostring(realmValue)
        end
    end
    local playerName = "?"
    if type(getGlobal("UnitName")) == "function" then
        local nameOk, nameValue = pcall(getGlobal("UnitName"), "player")
        if nameOk then
            playerName = tostring(nameValue)
        end
    end

    add("ActionHouse probe for WoW Forever")
    add("time=" .. tostring(time and time() or "?") .. " addon=" .. tostring(ns.version))
    add(
        string.format(
            "client version=%s build=%s date=%s interface=%s",
            build.version,
            build.build,
            build.date,
            build.toc
        )
    )
    add(
        string.format(
            "project=%s camelot=%s isForever=%s",
            tostring(project),
            tostring(camelot),
            tostring(self:IsForever())
        )
    )
    add(string.format("player=%s realm=%s", playerName, realm))
    add("Blizzard_AuctionHouseUI loaded=" .. tostring(self:IsAddOnLoaded("Blizzard_AuctionHouseUI")))
    add(
        "TSM loaded="
            .. tostring(self:IsAddOnLoaded("TradeSkillMaster"))
            .. " Auctionator loaded="
            .. tostring(self:IsAddOnLoaded("Auctionator"))
    )
    add("AH open=" .. tostring(self:IsAuctionHouseOpen()) .. " throttledReady=" .. tostring(self:IsThrottled()))
    add("keyboard focus=" .. tostring(ns.UI and ns.UI:GetKeyFocusName() or "ui-not-created"))

    add("")
    add("C_AuctionHouse API status")
    local api = getGlobal("C_AuctionHouse")
    if not api then
        add("C_AuctionHouse = nil")
    else
        for _, name in ipairs(AUCTION_API) do
            add(string.format("  %-38s %s", name, type(api[name])))
        end
    end

    if api then
        local functions = {}
        local ok = pcall(function()
            for key, value in pairs(api) do
                if type(value) == "function" then
                    functions[#functions + 1] = tostring(key)
                end
            end
        end)
        if ok then
            table.sort(functions)
            add("")
            add("all C_AuctionHouse functions")
            add("  " .. table.concat(functions, ", "))
        end
    end

    add("")
    add("Enums")
    for _, name in ipairs(ENUMS) do
        add(string.format("  %s: %s", name, enumDump(name)))
    end

    add("")
    add("AuctionHouseFrame")
    for _, line in ipairs(frameTree()) do
        add("  " .. line)
    end

    if api then
        add("")
        add("Cached auction data (non-mutating)")
        local ok, value = safeCall(api, "HasFullBrowseResults")
        add("  HasFullBrowseResults=" .. tostring(ok and value or ("error: " .. tostring(value))))
        ok, value = safeCall(api, "GetQuoteDurationRemaining")
        add("  GetQuoteDurationRemaining=" .. tostring(ok and value or ("missing/error: " .. tostring(value))))

        local ownedOk, ownedCount = safeCall(api, "GetNumOwnedAuctions")
        add("  GetNumOwnedAuctions=" .. tostring(ownedOk and ownedCount or ("missing/error: " .. tostring(ownedCount))))
        if ownedOk and type(ownedCount) == "number" and ownedCount > 0 then
            local infoOk, info = safeCall(api, "GetOwnedAuctionInfo", 1)
            add("  GetOwnedAuctionInfo(1)=" .. tostring(infoOk and describeValue(info, 3) or info))
        end

        local bidsOk, bidsCount = safeCall(api, "GetNumBids")
        add("  GetNumBids=" .. tostring(bidsOk and bidsCount or ("missing/error: " .. tostring(bidsCount))))
        if bidsOk and type(bidsCount) == "number" and bidsCount > 0 then
            local infoOk, info = safeCall(api, "GetBidInfo", 1)
            add("  GetBidInfo(1)=" .. tostring(infoOk and describeValue(info, 3) or info))
        end

        local browseOk, browse = safeCall(api, "GetBrowseResults")
        if browseOk and type(browse) == "table" then
            add("  GetBrowseResults count=" .. tostring(#browse))
            for index = 1, math.min(#browse, 3) do
                add("    browse[" .. index .. "]=" .. describeValue(browse[index], 3))
            end
        else
            add("  GetBrowseResults=" .. tostring(browseOk and browse or ("missing/error: " .. tostring(browse))))
        end
    end

    add("")
    add("Events expected: AUCTION_HOUSE_SHOW, AUCTION_HOUSE_CLOSED, AUCTION_HOUSE_BROWSE_RESULTS_UPDATED,")
    add("  AUCTION_HOUSE_BROWSE_RESULTS_ADDED, AUCTION_HOUSE_BROWSE_FAILURE, COMMODITY_SEARCH_RESULTS_UPDATED,")
    add("  COMMODITY_SEARCH_RESULTS_ADDED, ITEM_SEARCH_RESULTS_UPDATED, ITEM_SEARCH_RESULTS_ADDED,")
    add("  OWNED_AUCTIONS_UPDATED, BIDS_UPDATED, COMMODITY_PRICE_UPDATED, COMMODITY_PRICE_UNAVAILABLE,")
    add("  COMMODITY_PURCHASE_SUCCEEDED, COMMODITY_PURCHASE_FAILED, AUCTION_HOUSE_AUCTION_CREATED,")
    add("  AUCTION_MULTISELL_UPDATE, AUCTION_MULTISELL_FAILURE, AUCTION_CANCELED, BIDS_UPDATED,")
    add("  AUCTION_HOUSE_THROTTLED_* , AUCTION_HOUSE_NEW_BID_RECEIVED")

    if live then
        add("")
        add("live=true (no mutating calls were made by this probe)")
    end

    if ns.SaveProbe then
        ns:SaveProbe(lines)
    end

    ns:Print(
        string.format("Probe saved: %d lines. Run /reload to write ActionHouse.lua, then share that file.", #lines)
    )
    for index = 1, math.min(#lines, 28) do
        ns:Print(lines[index])
    end
    if #lines > 28 then
        ns:Print(string.format("... %d more lines saved. Use :probedump or read the SavedVariables file.", #lines - 28))
    end

    return lines, trim(table.concat(lines, "\n"))
end
