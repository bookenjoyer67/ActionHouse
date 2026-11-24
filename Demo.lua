local ADDON_NAME, ns = ...
local Demo = {}

ns.Demo = Demo

local function row(name, quality, level, qty, price, buyout, time, timeValue, kind, status, seller)
    return {
        name = name,
        quality = quality or 1,
        level = level or 0,
        qty = qty or 1,
        price = price or 0,
        bid = price or 0,
        buyout = buyout or 0,
        time = time or "12h",
        timeValue = timeValue or 12,
        kind = kind or "item",
        status = status or "active",
        seller = seller or "Demo Seller",
        id = 0,
    }
end

local BUY = {
    row("Copper Ore", 1, 1, 20, 1200, 24000, "12h", 12, "commodity", "active", "Prospector"),
    row("Copper Ore", 1, 1, 40, 1100, 44000, "24h", 24, "commodity", "active", "Ore Baron"),
    row("Tin Ore", 1, 65, 10, 2000, 20000, "48h", 48, "commodity", "active", "Prospector"),
    row("Iron Ore", 2, 125, 20, 5500, 110000, "12h", 12, "commodity", "active", "Miner"),
    row("Mithril Ore", 2, 175, 20, 9000, 180000, "24h", 24, "commodity", "active", "Miner"),
    row("Thorium Ore", 2, 250, 10, 15000, 150000, "48h", 48, "commodity", "active", "Miner"),
    row("Peacebloom", 1, 1, 20, 3000, 60000, "12h", 12, "commodity", "active", "Herbalist"),
    row("Silverleaf", 1, 1, 20, 2500, 50000, "24h", 24, "commodity", "active", "Herbalist"),
    row("Swiftthistle", 2, 1, 5, 20000, 100000, "48h", 48, "commodity", "active", "Herbalist"),
    row("Linen Cloth", 1, 1, 20, 800, 16000, "12h", 12, "commodity", "active", "Tailor"),
    row("Wool Cloth", 1, 1, 20, 1500, 30000, "24h", 24, "commodity", "active", "Tailor"),
    row("Mageweave Cloth", 2, 1, 20, 4000, 80000, "48h", 48, "commodity", "active", "Tailor"),
    row("Runecloth", 2, 1, 20, 6000, 120000, "12h", 12, "commodity", "active", "Tailor"),
    row("Light Leather", 1, 1, 20, 1000, 20000, "24h", 24, "commodity", "active", "Skinner"),
    row("Heavy Leather", 1, 1, 20, 4000, 80000, "48h", 48, "commodity", "active", "Skinner"),
    row("Black Lotus", 4, 1, 1, 500000, 500000, "12h", 12, "commodity", "active", "Alchemist"),
    row("Arcane Crystal", 3, 1, 5, 120000, 600000, "24h", 24, "commodity", "active", "Enchanter"),
    row("Large Fang", 1, 1, 10, 3500, 35000, "48h", 48, "commodity", "active", "Hunter"),
    row("Staff of the Monkey", 3, 32, 1, 120000, 3500000, "12h", 12, "item", "active", "Wanderer"),
    row("Traveler's Backpack", 3, 45, 1, 0, 900000, "24h", 24, "item", "active", "Nomad"),
    row("Recipe: Elixir of the Mongoose", 2, 1, 1, 0, 150000, "48h", 48, "item", "active", "Alchemist"),
    row("Sixteen Slot Bag", 2, 1, 1, 0, 400000, "12h", 12, "item", "active", "Tailor"),
    row("Blue Sapphire", 3, 1, 1, 0, 250000, "24h", 24, "item", "active", "Jeweler"),
    row("Righteous Orb", 4, 1, 1, 0, 1200000, "48h", 48, "item", "active", "Crusader"),
    row("Pattern: Robe of the Archmage", 4, 1, 1, 0, 5000000, "12h", 12, "item", "active", "Tailor"),
}

local SELL = {
    row("Copper Ore", 1, 1, 60, 0, 0, "", 0, "commodity", "ready", "You"),
    row("Linen Cloth", 1, 1, 80, 0, 0, "", 0, "commodity", "ready", "You"),
    row("Heavy Leather", 1, 1, 40, 0, 0, "", 0, "commodity", "ready", "You"),
    row("Small Radiant Shard", 2, 1, 5, 0, 0, "", 0, "commodity", "ready", "You"),
    row("Staff of the Monkey", 3, 32, 1, 0, 0, "", 0, "item", "ready", "You"),
    row("Traveler's Backpack", 3, 45, 1, 0, 0, "", 0, "item", "ready", "You"),
    row("Sixteen Slot Bag", 2, 1, 3, 0, 0, "", 0, "item", "ready", "You"),
    row("Blue Sapphire", 3, 1, 2, 0, 0, "", 0, "item", "ready", "You"),
    row("Soulbound Test Sword", 3, 60, 1, 0, 0, "", 0, "item", "bound", "You"),
    row("Conjured Purified Water", 1, 55, 20, 0, 0, "", 0, "commodity", "bound", "You"),
}

local OWNED = {
    row("Copper Ore", 1, 1, 20, 1100, 22000, "11h", 11, "commodity", "active", "You"),
    row("Iron Ore", 2, 125, 20, 5000, 100000, "23h", 23, "commodity", "active", "You"),
    row("Staff of the Monkey", 3, 32, 1, 95000, 3200000, "47h", 47, "item", "active", "You"),
    row("Sixteen Slot Bag", 2, 1, 1, 0, 390000, "11h", 11, "item", "sold", "You"),
    row("Blue Sapphire", 3, 1, 2, 0, 240000, "23h", 23, "item", "sold", "You"),
    row("Linen Cloth", 1, 1, 40, 700, 15000, "47h", 47, "commodity", "expired", "You"),
}

local BIDS = {
    row("Staff of the Monkey", 3, 32, 1, 110000, 3500000, "12h", 12, "item", "winning", "Wanderer"),
    row("Traveler's Backpack", 3, 45, 1, 0, 900000, "24h", 24, "item", "outbid", "Nomad"),
    row("Blue Sapphire", 3, 1, 1, 0, 250000, "48h", 48, "item", "winning", "Jeweler"),
    row("Righteous Orb", 4, 1, 1, 0, 1200000, "12h", 12, "item", "outbid", "Crusader"),
    row("Pattern: Robe of the Archmage", 4, 1, 1, 0, 5000000, "24h", 24, "item", "winning", "Tailor"),
}

local DATA = {
    buy = BUY,
    sell = SELL,
    owned = OWNED,
    bids = BIDS,
}

function Demo.GetRows(tab)
    local source = DATA[tab] or BUY
    local result = {}
    for index, entry in ipairs(source) do
        local copy = {}
        for key, value in pairs(entry) do
            copy[key] = value
        end
        copy.id = index
        result[#result + 1] = copy
    end
    return result
end
