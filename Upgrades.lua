local ADDON_NAME, ns = ...

local Upgrades = {}

ns.Upgrades = Upgrades

local function getCheapUpgrades()
    return rawget(_G, "CheapUpgrades")
end

local function itemIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

local function itemName(cu, link)
    if type(link) ~= "string" then
        return nil
    end
    local engine = cu.Engine
    local getInfo = engine and engine.GetItemInfo
    if type(getInfo) == "function" then
        local ok, name = pcall(getInfo, link)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return link:match("%[(.-)%]")
end

local function classToken(cu)
    if type(cu.GetClass) == "function" then
        local ok, class = pcall(cu.GetClass, cu)
        if ok and class then
            return class
        end
    end
    local unitClass = rawget(_G, "UnitClass")
    if type(unitClass) == "function" then
        local ok, _, class = pcall(unitClass, "player")
        if ok and class then
            return class
        end
    end
    return nil
end

local function shortSpecName(cu, spec)
    if not spec then
        return "?"
    end
    local scoring = cu.Scoring
    local class = classToken(cu)
    local short = scoring and scoring.SPEC_SHORT
    local label = class and spec.key and short and short[class .. "." .. spec.key]
    return label or spec.name or spec.key or "?"
end

local function currentSpec(cu)
    if type(cu.GetSpec) == "function" then
        local ok, spec = pcall(cu.GetSpec, cu)
        if ok then
            return spec
        end
    end
    return nil
end

local function pctText(gain, old)
    gain = tonumber(gain) or 0
    old = tonumber(old) or 0
    if old <= 0 then
        return gain > 0 and "NEW" or ""
    end
    local pct = gain / old * 100
    if pct >= 999 then
        return ">999%"
    end
    return string.format("%+.0f%%", pct)
end

local function upgradeStrength(info)
    if not info then
        return 0
    end
    local best = tonumber(info.pct) or 0
    for _, entry in ipairs(info.perSlot or {}) do
        local pct = 0
        if entry.old and entry.old > 0 then
            pct = (tonumber(entry.gain) or 0) / entry.old * 100
        elseif (tonumber(entry.gain) or 0) > 0 then
            pct = 999
        end
        if pct > best then
            best = pct
        end
    end
    return best
end

local function slotLabel(cu, info, result)
    if info then
        if info.slotName then
            return info.slotName
        end
        local scoring = cu.Scoring
        local names = scoring and scoring.SLOT_NAMES
        if names and info.slot and names[info.slot] then
            return names[info.slot]
        end
    end
    local scoring = cu.Scoring
    local names = scoring and scoring.SLOT_NAMES
    if result and names and result.slot and names[result.slot] then
        return names[result.slot]
    end
    return result and tostring(result.equipLoc or "") or ""
end

local function replacesText(cu, info)
    local parts = {}
    for _, link in ipairs(info and info.replaced or {}) do
        local name = itemName(cu, link)
        if name then
            parts[#parts + 1] = name
        end
    end
    if #parts > 0 then
        return table.concat(parts, " + ")
    end
    if info and (tonumber(info.gain) or 0) > 0 and (not info.old or (tonumber(info.old) or 0) <= 0) then
        return "NEW"
    end
    return ""
end

function Upgrades:Available()
    return type(getCheapUpgrades()) == "table"
end

function Upgrades:EnsureLoaded()
    local cu = getCheapUpgrades()
    if not cu then
        return
    end
    if type(cu.results) == "table" and #cu.results > 0 then
        return
    end
    if cu.Engine and cu.Engine.preparing then
        return
    end
    if type(cu.LoadSaved) == "function" then
        pcall(cu.LoadSaved, cu)
    end
end

function Upgrades:ItemInfos(link)
    local cu = getCheapUpgrades()
    if not cu or type(link) ~= "string" then
        return {}
    end

    local list = {}
    local seen = {}
    local function add(ctx, info)
        if not ctx or not info then
            return
        end
        local key = (ctx.spec and ctx.spec.key) or tostring(ctx)
        if seen[key] then
            return
        end
        seen[key] = true
        list[#list + 1] = { ctx = ctx, info = info }
    end

    local spec = currentSpec(cu)
    local watched = {}
    if type(cu.WatchedInfo) == "function" then
        local ok, entries = pcall(cu.WatchedInfo, cu, link)
        if ok and type(entries) == "table" then
            watched = entries
        end
    end

    local currentKey = spec and spec.key
    local hasCurrent = false
    for _, entry in ipairs(watched) do
        if currentKey and entry.ctx and entry.ctx.spec and entry.ctx.spec.key == currentKey then
            hasCurrent = true
            break
        end
    end

    if not hasCurrent then
        local ctx
        if spec and type(cu.SpecContext) == "function" then
            local ok, value = pcall(cu.SpecContext, cu, spec)
            if ok then
                ctx = value
            end
        end
        if not ctx then
            ctx = cu.ctx
        end
        if ctx and type(cu.UpgradeInfo) == "function" then
            local ok, info = pcall(cu.UpgradeInfo, cu, link, ctx)
            if ok then
                add(ctx, info)
            end
        end
    end

    for _, entry in ipairs(watched) do
        if type(entry) == "table" then
            add(entry.ctx, entry.info)
        end
    end
    return list
end

function Upgrades:BuildComparison(cu, result, infos)
    local spec = currentSpec(cu)
    local currentKey = spec and spec.key

    local currentEntry, bestUpgrade
    local upgradeEntries = {}
    for _, entry in ipairs(infos or {}) do
        local info = entry.info
        if currentKey and entry.ctx and entry.ctx.spec and entry.ctx.spec.key == currentKey then
            currentEntry = entry
        end
        if info and info.state == "upgrade" then
            upgradeEntries[#upgradeEntries + 1] = entry
            if not bestUpgrade or upgradeStrength(info) > upgradeStrength(bestUpgrade.info) then
                bestUpgrade = entry
            end
        end
    end

    local primary
    if currentEntry and currentEntry.info and currentEntry.info.state == "upgrade" then
        primary = currentEntry
    elseif bestUpgrade then
        primary = bestUpgrade
    elseif currentEntry then
        primary = currentEntry
    else
        primary = (infos or {})[1]
    end
    local primaryInfo = primary and primary.info or nil

    local specSource = #upgradeEntries > 0 and upgradeEntries or (primary and { primary } or {})
    local shortParts, fullParts, seenSpec = {}, {}, {}
    for _, entry in ipairs(specSource) do
        local entrySpec = entry.ctx and entry.ctx.spec
        local key = entrySpec and entrySpec.key or "?"
        if not seenSpec[key] then
            seenSpec[key] = true
            shortParts[#shortParts + 1] = shortSpecName(cu, entrySpec)
            fullParts[#fullParts + 1] = entrySpec and entrySpec.name or key
        end
    end
    if #shortParts == 0 and spec then
        shortParts[1] = shortSpecName(cu, spec)
        fullParts[1] = spec.name or spec.key or "?"
    end

    local infoSlot = primaryInfo and slotLabel(cu, primaryInfo, result) or slotLabel(cu, nil, result)
    local infoGain = primaryInfo and tonumber(primaryInfo.gain) or tonumber(result.gain)
    local infoOld = primaryInfo and tonumber(primaryInfo.old) or tonumber(result.old)
    local infoPct = primaryInfo and tonumber(primaryInfo.pct)
    if not infoPct and infoGain and infoOld and infoOld > 0 then
        infoPct = infoGain / infoOld * 100
    end
    if not infoPct then
        infoPct = tonumber(result.pct) or 0
    end

    local replacement = replacesText(cu, primaryInfo)
    if replacement == "" and (not infoOld or infoOld <= 0) and (infoGain or 0) > 0 then
        replacement = "NEW"
    end
    local upgrade = primaryInfo and pctText(infoGain, infoOld) or pctText(result.gain, result.old)
    if upgrade == "" then
        upgrade = pctText(result.gain, result.old)
    end

    return {
        infos = infos,
        primary = primary,
        primaryInfo = primaryInfo,
        specText = table.concat(shortParts, ", "),
        specFullText = table.concat(fullParts, ", "),
        specSort = table.concat(shortParts, ", "):lower(),
        slot = infoSlot,
        pct = infoPct,
        gain = infoGain,
        old = infoOld,
        upgradeText = upgrade,
        replacesText = replacement,
        reqLevel = primaryInfo and tonumber(primaryInfo.reqLevel) or tonumber(result.reqLevel),
    }
end

function Upgrades:GetRows()
    local cu = getCheapUpgrades()
    if not cu or type(cu.results) ~= "table" then
        return {}
    end

    local spec = currentSpec(cu)
    local watchedKeys = {}
    if type(cu.GetWatchedSpecs) == "function" then
        local ok, specs = pcall(cu.GetWatchedSpecs, cu)
        if ok and type(specs) == "table" then
            for _, watched in ipairs(specs) do
                if watched and watched.key then
                    watchedKeys[#watchedKeys + 1] = watched.key
                end
            end
        end
    end
    local cacheKey = string.format(
        "%s|%s|%s|%s|%s",
        tostring(cu.results),
        tostring(cu.lastFullEval),
        tostring(spec and spec.key),
        tostring(#cu.results),
        table.concat(watchedKeys, ",")
    )
    if self.cacheKey == cacheKey and self.cacheRows then
        return self.cacheRows
    end

    local rows = {}
    for index, result in ipairs(cu.results) do
        if type(result) == "table" then
            local infos = self:ItemInfos(result.link)
            local comparison = self:BuildComparison(cu, result, infos)
            rows[#rows + 1] = {
                view = "upgrade",
                rank = index,
                name = result.name or "?",
                quality = result.quality or 1,
                icon = result.icon,
                itemID = itemIDFromLink(result.link),
                itemLink = result.link,
                slot = comparison.slot,
                spec = comparison.specSort,
                specText = comparison.specText,
                specFullText = comparison.specFullText,
                specSort = comparison.specSort,
                replaces = comparison.replacesText,
                pct = comparison.pct,
                gain = comparison.gain,
                old = comparison.old,
                upgradeText = comparison.upgradeText,
                replacesText = comparison.replacesText,
                price = tonumber(result.price) or 0,
                cost = tonumber(result.cost),
                sell = tonumber(result.sell),
                reqLevel = comparison.reqLevel,
            }
        end
    end
    self.cacheKey = cacheKey
    self.cacheRows = rows
    return rows
end

function Upgrades:Signature()
    local cu = getCheapUpgrades()
    if not cu then
        return "none"
    end
    local spec = currentSpec(cu)
    local count = type(cu.results) == "table" and #cu.results or 0
    return string.format(
        "%d:%s:%s:%s:%s",
        count,
        tostring(cu.lastFullEval),
        tostring(cu.Engine and cu.Engine.preparing),
        tostring(spec and spec.key),
        tostring(cu.status)
    )
end

function Upgrades:StatusLabel()
    local cu = getCheapUpgrades()
    if not cu then
        return "CU: off"
    end
    if cu.Engine and cu.Engine.preparing then
        return "CU: loading"
    end
    local count = type(cu.results) == "table" and #cu.results or 0
    if count == 0 then
        return "CU: no scan"
    end
    return string.format("CU: %d upgrades", count)
end

function Upgrades:Refresh()
    self:EnsureLoaded()
    if ns.UI and ns.UI.LoadRows and ns.UI.state and ns.UI.state.tab == "upgrades" then
        ns.UI:LoadRows(false)
        ns.UI:Refresh()
    end
end
