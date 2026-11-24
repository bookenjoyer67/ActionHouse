local ADDON_NAME, ns = ...
local Money = {}

ns.Money = Money

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 10000
local UNIT_VALUE = {
    c = 1,
    s = COPPER_PER_SILVER,
    g = COPPER_PER_GOLD,
}

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Money.Trim(text)
    return trim(text or "")
end

---Parse money text into copper.
---Accepts "1g 2s 3c", "1g2s3c", "1.5g", "2g50s", "15000c", or bare "15000" as copper.
---@param text string
---@return number|nil copper
---@return string|nil err
function Money.Parse(text)
    if type(text) ~= "string" then
        return nil, "money must be text"
    end

    local value = trim(text):lower()
    if value == "" then
        return nil, "empty money"
    end

    local total = 0
    local found = false
    local pos = 1

    while pos <= #value do
        local from, to, numberText, unit = value:find("(%d+%.?%d*)%s*([gsc])", pos)
        if not from then
            break
        end

        local gap = value:sub(pos, from - 1)
        if gap:find("%S") then
            return nil, "invalid money"
        end

        local number = tonumber(numberText)
        if not number then
            return nil, "invalid money"
        end

        total = total + (number * UNIT_VALUE[unit])
        found = true
        pos = to + 1
    end

    if found then
        if value:sub(pos):find("%S") then
            return nil, "invalid money"
        end
        return math.floor(total + 0.5)
    end

    local number = tonumber(value)
    if number and number >= 0 then
        return math.floor(number + 0.5)
    end

    return nil, "invalid money"
end

local function parts(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(copper / COPPER_PER_GOLD)
    local silver = math.floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    local rest = copper % COPPER_PER_SILVER
    return gold, silver, rest
end

---Full readable money string, omitting zero parts.
---@param copper number
---@return string
function Money.Format(copper)
    local gold, silver, rest = parts(copper)
    local out = {}
    if gold > 0 then
        out[#out + 1] = gold .. "g"
    end
    if silver > 0 then
        out[#out + 1] = silver .. "s"
    end
    if rest > 0 then
        out[#out + 1] = rest .. "c"
    end
    if #out == 0 then
        return "0c"
    end
    return table.concat(out, " ")
end

---Compact money string for table columns.
---@param copper number
---@return string
function Money.FormatShort(copper)
    local gold, silver, rest = parts(copper)
    if gold > 0 then
        if rest > 0 and silver == 0 then
            return gold .. "g " .. rest .. "c"
        end
        if silver > 0 then
            return gold .. "g " .. silver .. "s"
        end
        return gold .. "g"
    end
    if silver > 0 then
        if rest > 0 then
            return silver .. "s " .. rest .. "c"
        end
        return silver .. "s"
    end
    return rest .. "c"
end

---Parse a quantity, including all/max.
---@param text string
---@param maxQuantity number|nil
---@param allowZero boolean|nil
---@return number|nil quantity
---@return string|nil err
function Money.ParseQuantity(text, maxQuantity, allowZero)
    if type(text) ~= "string" then
        return nil, "quantity must be text"
    end

    local value = trim(text):lower()
    if value == "all" or value == "max" then
        if type(maxQuantity) ~= "number" then
            return nil, "no maximum quantity"
        end
        return math.max(0, math.floor(maxQuantity))
    end

    if not value:match("^%d+$") then
        return nil, "quantity must be a whole number"
    end

    local quantity = math.floor(tonumber(value))
    if not allowZero and quantity < 1 then
        return nil, "quantity must be at least 1"
    end

    if type(maxQuantity) == "number" and quantity > maxQuantity then
        return nil, "quantity exceeds maximum"
    end

    return quantity
end

---Apply a delta expression such as "+10%", "-1c", or "+5g" to a copper value.
---@param current number
---@param expression string
---@return number|nil value
---@return string|nil err
function Money.Delta(current, expression)
    current = math.max(0, math.floor(tonumber(current) or 0))
    if type(expression) ~= "string" then
        return nil, "delta must be text"
    end

    local value = trim(expression)
    if value == "" then
        return nil, "empty delta"
    end

    local percentText = value:match("^([%+%-]?%d+%.?%d*)%%$")
    if percentText then
        local percent = tonumber(percentText)
        if not percent then
            return nil, "invalid percentage"
        end
        local result = math.floor(current * (1 + (percent / 100)) + 0.5)
        if result < 0 then
            return nil, "result is negative"
        end
        return result
    end

    local sign = value:sub(1, 1)
    if sign == "+" or sign == "-" then
        local amount, err = Money.Parse(value:sub(2))
        if not amount then
            return nil, err
        end
        local result = sign == "+" and (current + amount) or (current - amount)
        if result < 0 then
            return nil, "result is negative"
        end
        return result
    end

    local absolute, err = Money.Parse(value)
    if not absolute then
        return nil, err
    end
    return absolute
end
