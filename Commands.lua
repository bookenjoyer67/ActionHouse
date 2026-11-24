local ADDON_NAME, ns = ...
local Commands = {}

ns.Commands = Commands

local COMMANDS = {
    {
        name = "help",
        aliases = { "h" },
        usage = "help",
        desc = "Show the keymap and command reference.",
        run = function()
            ns.UI:ShowHelp()
        end,
    },
    {
        name = "demo",
        usage = "demo [buy|sell|owned|bids]",
        desc = "Show fixture data without touching the real auction house.",
        complete = function()
            return { "buy", "sell", "owned", "bids" }
        end,
        run = function(rest)
            local tab = rest ~= "" and rest or "buy"
            if not ns.State.TAB_LABELS[tab] then
                ns.UI:SetMessage("Unknown demo tab: " .. tab, true)
                return
            end
            ns.UI:ShowDemo(tab)
        end,
    },
    {
        name = "probe",
        usage = "probe [live]",
        desc = "Dump client and API details into chat and SavedVariables.",
        complete = function()
            return { "live" }
        end,
        run = function(rest)
            ns.Compat:Probe(rest:lower() == "live")
        end,
    },
    {
        name = "probedump",
        usage = "probedump",
        desc = "Print the last probe stored in SavedVariables.",
        run = function()
            if not ns.db or not ns.db.probe or not ns.db.probe.lines then
                ns.UI:SetMessage("No saved probe. Run :probe first.", true)
                return
            end
            ns:PrintLong(ns.db.probe.lines)
        end,
    },
    {
        name = "keytest",
        usage = "keytest",
        desc = "Show normalized key tokens. Esc exits.",
        run = function()
            ns.UI:StartKeytest()
        end,
    },
    {
        name = "status",
        usage = "status",
        desc = "Print ActionHouse load, auction, query, and UI state.",
        run = function()
            if ns.Auction then
                ns.Auction:Init()
            end
            ns:Print(string.format("ActionHouse %s | %s", ns.version, ns.Compat:GetBuildString()))
            ns:Print(
                string.format(
                    "UI shown=%s demo=%s tab=%s mode=%s autoShow=%s",
                    tostring(ns.UI:IsShown()),
                    tostring(ns.UI.state.demo),
                    tostring(ns.UI.state.tab),
                    tostring(ns.UI.state.mode),
                    tostring(ns.db.autoShow)
                )
            )
            ns:Print(
                string.format(
                    "AH open=%s focus=%s",
                    tostring(ns.Compat:IsAuctionHouseOpen()),
                    tostring(ns.UI:GetKeyFocusName())
                )
            )
            if ns.Auction then
                for _, line in ipairs(ns.Auction:GetStatusLines()) do
                    ns:Print("  " .. line)
                end
            end
            if ns.Sell then
                for _, line in ipairs(ns.Sell:GetStatusLines()) do
                    ns:Print("  sell." .. line)
                end
            end
            if ns.Manage then
                for _, line in ipairs(ns.Manage:GetStatusLines()) do
                    ns:Print("  manage." .. line)
                end
            end
            if ns.db and ns.db.probe then
                ns:Print("probe saved at " .. tostring(ns.db.probe.at))
            end
        end,
    },
    {
        name = "throttle",
        usage = "throttle",
        desc = "Show auction house throttle status and recovery steps.",
        run = function()
            local auction = ns.Auction
            if auction then
                auction:Init()
            end
            local ready
            if auction then
                ready = auction:GetThrottleState()
            end
            local stuck = auction and auction.IsThrottleStuck and auction:IsThrottleStuck() or false
            local downFor = auction and auction.throttleDownFor or 0
            ns:Print(
                string.format(
                    "throttle ready=%s stuck=%s downFor=%.0fs AH open=%s",
                    tostring(ready),
                    tostring(stuck),
                    downFor,
                    tostring(ns.Compat:IsAuctionHouseOpen())
                )
            )
            if stuck then
                ns:Print("The client throttle is frozen. Log out and back in; /reload may not clear it.")
            elseif ready == false then
                ns:Print("Waiting for the auction house throttle.")
            end
        end,
    },
    {
        name = "back",
        usage = "back",
        desc = "Return from item detail to search results.",
        run = function()
            ns.UI:Back()
        end,
    },
    {
        name = "refresh",
        usage = "refresh",
        desc = "Refresh live auction results, owned data, or demo data.",
        run = function()
            ns.UI:RefreshAll()
        end,
    },
    {
        name = "price",
        usage = "price",
        desc = "Refill the open Sell form from the lowest matching listing.",
        run = function()
            ns.Sell:RefreshPrice()
        end,
    },
    {
        name = "live",
        usage = "live",
        desc = "Show the live Buy view while the auction house is open.",
        run = function()
            if not ns.Compat:IsAuctionHouseOpen() then
                ns.UI:SetMessage("Open the auction house first.", true)
                return
            end
            ns.UI:ShowReal()
        end,
    },
    {
        name = "toggle",
        usage = "toggle",
        desc = "Show or hide the ActionHouse window.",
        run = function()
            ns.UI:Toggle()
        end,
    },
    {
        name = "focus",
        usage = "focus",
        desc = "Return keyboard focus to ActionHouse.",
        run = function()
            ns.UI:FocusKeys()
            ns.UI:SetMessage("Keyboard focus requested.")
        end,
    },
    {
        name = "q",
        aliases = { "quit", "close" },
        usage = "q",
        desc = "Close ActionHouse and the auction house.",
        run = function()
            ns.UI:CloseAH()
        end,
    },
    {
        name = "blizzard",
        aliases = { "default", "b" },
        usage = "blizzard | b",
        desc = "Hide ActionHouse and return to the normal AH UI.",
        run = function()
            ns.UI:ShowBlizzard()
        end,
    },
    {
        name = "tab",
        usage = "tab <buy|sell|owned|bids>",
        desc = "Switch tabs.",
        complete = function()
            return { "buy", "sell", "owned", "bids" }
        end,
        run = function(rest)
            local tab = rest:lower()
            if not ns.State.TAB_LABELS[tab] then
                ns.UI:SetMessage("Unknown tab: " .. rest, true)
                return
            end
            ns.UI:SetTab(tab)
        end,
    },
    {
        name = "sell",
        usage = "sell",
        desc = "Switch to the Sell tab.",
        run = function()
            ns.UI:SetTab("sell")
        end,
    },
    {
        name = "owned",
        usage = "owned",
        desc = "Switch to the Owned auctions tab.",
        run = function()
            ns.UI:SetTab("owned")
        end,
    },
    {
        name = "bids",
        usage = "bids",
        desc = "Switch to the Bids tab.",
        run = function()
            ns.UI:SetTab("bids")
        end,
    },
    {
        name = "raise",
        usage = "raise [money]",
        desc = "Raise the selected bid.",
        run = function(rest)
            local amount
            if rest ~= "" then
                local err
                amount, err = ns.Money.Parse(rest)
                if not amount then
                    ns.UI:SetMessage(err or "Invalid money.", true)
                    return
                end
            end
            if ns.UI.state.demo then
                ns.UI:PrimaryAction("bid", 1)
            else
                ns.UI:BidSelected(amount)
            end
        end,
    },
    {
        name = "search",
        usage = "search <text>",
        desc = "Set the current search text.",
        run = function(rest)
            ns.UI:SetSearch(rest)
            ns.UI:SetMessage(rest == "" and "Search cleared." or ("Search: " .. rest))
        end,
    },
    {
        name = "filter",
        usage = "filter <expression>",
        desc = "Filter rows locally: quality=epic kind=commodity qty>=20 -bound.",
        run = function(rest)
            if ns.UI:IsLive() then
                ns.UI:SetFilter(rest)
                return
            end
            ns.UI:SetFilter(rest)
            ns.UI:SetMessage(rest == "" and "Filter cleared." or ("Filter: " .. rest))
        end,
    },
    {
        name = "clear",
        usage = "clear",
        desc = "Clear search and filter.",
        run = function()
            if ns.UI:IsLive() then
                ns.UI:SetMessage("Use :search to change the live query; Backspace returns from detail.")
                return
            end
            ns.UI.state.search = ""
            ns.UI.state.filter = ""
            ns.UI.state:ApplyView(true)
            ns.UI:SetMessage("Search and filter cleared.")
            ns.UI:Refresh()
        end,
    },
    {
        name = "sort",
        usage = "sort <price|buyout|name|level|qty|time|status> [asc|desc]",
        desc = "Sort the current list.",
        complete = function()
            return { "price", "buyout", "name", "level", "qty", "time", "status" }
        end,
        run = function(rest)
            local field, direction = rest:match("^(%S+)%s*(%S*)$")
            field = (field or ""):lower()
            direction = (direction or ""):lower()
            if not field:match("^[%a_]+$") then
                ns.UI:SetMessage("Usage: :sort <field> [asc|desc]", true)
                return
            end
            if direction ~= "" and direction ~= "asc" and direction ~= "desc" then
                ns.UI:SetMessage("Direction must be asc or desc.", true)
                return
            end
            if ns.UI:IsLive() and field ~= "name" and field ~= "price" then
                ns.UI:SetMessage("Live Buy sorting supports name or price.", true)
                return
            end
            ns.UI:SetSort(field, direction ~= "desc")
            ns.UI:SetMessage("Sort: " .. field .. " " .. (direction == "desc" and "desc" or "asc"))
        end,
    },
    {
        name = "set",
        usage = "set <key>=<value>",
        desc = "Change settings: auto, confirm, scrolloff.",
        complete = function()
            return { "auto=", "confirm=", "scrolloff=" }
        end,
        run = function(rest)
            local key, value = rest:match("^([%w_]+)%s*=%s*(.*)$")
            if not key then
                ns.UI:SetMessage("Usage: :set <key>=<value>", true)
                return
            end
            key = key:lower()
            value = value:lower():gsub("%s+$", "")

            if key == "auto" then
                ns.db.autoShow = value == "on" or value == "true" or value == "1"
                ns.UI:SetMessage("autoShow = " .. tostring(ns.db.autoShow))
            elseif key == "confirm" then
                if value ~= "always" and value ~= "off" and value ~= "threshold" then
                    ns.UI:SetMessage("confirm must be always, threshold, or off.", true)
                    return
                end
                ns.db.confirm = value
                ns.UI:SetMessage("confirm = " .. value)
            elseif key == "scrolloff" then
                local number = tonumber(value)
                if not number or number < 0 or number > 20 then
                    ns.UI:SetMessage("scrolloff must be 0-20.", true)
                    return
                end
                ns.db.scrolloff = math.floor(number)
                ns.UI.state.scrolloff = ns.db.scrolloff
                ns.UI:SetMessage("scrolloff = " .. ns.db.scrolloff)
                ns.UI:Refresh()
            else
                ns.UI:SetMessage("Unknown setting: " .. key, true)
            end
        end,
    },
    {
        name = "messages",
        usage = "messages",
        desc = "Print the recent ActionHouse message log.",
        run = function()
            local log = ns.UI:GetLog()
            local start = math.max(1, #log - 20)
            if #log == 0 then
                ns.UI:SetMessage("No messages.")
                return
            end
            for index = start, #log do
                ns:Print(log[index])
            end
        end,
    },
    {
        name = "version",
        usage = "version",
        desc = "Show the addon version and target client.",
        run = function()
            ns:Notify(string.format("ActionHouse %s for WoW Forever %s", ns.version, ns.Compat:GetBuildString()))
        end,
    },
    {
        name = "buy",
        usage = "buy [qty]",
        desc = "Buy the selected commodity quantity.",
        run = function(rest)
            local quantity
            if rest ~= "" then
                local err
                quantity, err = ns.Money.ParseQuantity(rest, 999999)
                if not quantity then
                    ns.UI:SetMessage(err or "Invalid quantity.", true)
                    return
                end
            end
            if ns.UI:IsLive() then
                ns.UI:BuySelected(quantity)
            else
                ns.UI:PrimaryAction("buy", quantity or 1)
            end
        end,
    },
    {
        name = "bid",
        usage = "bid [money]",
        desc = "Bid on the selected Buy auction or raise the selected bid.",
        run = function(rest)
            local amount
            if rest ~= "" then
                local err
                amount, err = ns.Money.Parse(rest)
                if not amount then
                    ns.UI:SetMessage(err or "Invalid money.", true)
                    return
                end
            end
            if ns.UI.state.demo then
                ns.UI:PrimaryAction("bid", 1)
            elseif ns.UI:IsLive() or ns.UI.state.tab == "bids" then
                ns.UI:BidSelected(amount)
            else
                ns.UI:PrimaryAction("bid", 1)
            end
        end,
    },
    {
        name = "post",
        usage = "post",
        desc = "Open the posting form or submit it.",
        run = function()
            if ns.UI.sellForm and ns.UI.sellForm:IsShown() then
                ns.UI.sellForm:Post()
                return
            end
            ns.UI:PrimaryAction("post", 1)
        end,
    },
    {
        name = "cancel",
        usage = "cancel",
        desc = "Cancel the selected owned auction.",
        run = function()
            ns.UI:PrimaryAction("cancel", 1)
        end,
    },
    {
        name = "more",
        usage = "more",
        desc = "Load more browse or item results.",
        run = function()
            ns.UI:RequestMore()
        end,
    },
}

local LOOKUP = {}
for _, command in ipairs(COMMANDS) do
    LOOKUP[command.name] = command
    for _, alias in ipairs(command.aliases or {}) do
        LOOKUP[alias] = command
    end
end

function Commands:Complete(text)
    text = tostring(text or "")
    local leading = text:match("^%s*") or ""
    local body = text:sub(#leading + 1)
    local word, rest = body:match("^(%S*)%s*(.*)$")
    word = word or ""
    rest = rest or ""
    local prefix = leading
    local hasTrailingSpace = body:match("%s$") ~= nil

    if rest == "" and not hasTrailingSpace then
        local results = {}
        local lowerWord = word:lower()
        for _, command in ipairs(COMMANDS) do
            if command.name:sub(1, #lowerWord) == lowerWord then
                results[#results + 1] = prefix .. command.name
            end
        end
        return results
    end

    local command = LOOKUP[word:lower()]
    if not command or not command.complete then
        return {}
    end

    local results = {}
    local lowerRest = rest:lower()
    for _, candidate in ipairs(command.complete()) do
        if candidate:sub(1, #lowerRest) == lowerRest then
            results[#results + 1] = prefix .. word .. " " .. candidate
        end
    end
    return results
end

function Commands:Run(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    ns.UI:Init()
    if text == "" then
        ns.UI:SetMessage("Type :help for commands.")
        return
    end

    local word, rest = text:match("^(%S+)%s*(.*)$")
    word = (word or ""):lower()
    rest = rest or ""
    local command = LOOKUP[word]
    if not command then
        ns.UI:SetMessage("Unknown command: " .. word .. " (try :help)", true)
        return
    end

    local ok, err = pcall(command.run, rest)
    if not ok then
        ns.UI:SetMessage("Command error: " .. tostring(err), true)
    end
end
