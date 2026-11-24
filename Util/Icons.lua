local ADDON_NAME, ns = ...

local function usable(value)
    if type(value) == "number" then
        return value > 0 and value or nil
    end
    if type(value) == "string" then
        return value ~= "" and value or nil
    end
    return nil
end

local function instantIcon(itemID)
    local cItem = rawget(_G, "C_Item")
    local instant = cItem and cItem.GetItemInfoInstant or rawget(_G, "GetItemInfoInstant")
    if type(instant) ~= "function" or itemID == nil then
        return nil
    end
    local values = { pcall(instant, itemID) }
    if not values[1] then
        return nil
    end
    return usable(values[6])
end

function ns.ItemIcon(itemID, itemLink, provided)
    local value = usable(provided)
    if value then
        return value
    end

    local cItem = rawget(_G, "C_Item")
    if type(itemID) == "number" and cItem and type(cItem.GetItemIconByID) == "function" then
        local ok, icon = pcall(cItem.GetItemIconByID, itemID)
        if ok then
            value = usable(icon)
            if value then
                return value
            end
        end
    end

    value = instantIcon(itemID)
    if value then
        return value
    end

    local getIcon = rawget(_G, "GetItemIcon")
    if type(getIcon) == "function" then
        local ok, icon = pcall(getIcon, itemLink or itemID)
        if ok then
            return usable(icon)
        end
    end
    return nil
end
