local ADDON_NAME, ns = ...

ns.addonName = ADDON_NAME
ns.version = "0.5.0"
ns.features = {
    demo = true,
    probe = true,
    buy = true,
    sell = true,
    owned = true,
    bids = true,
}
ns.disabled = false
ns.sawAuctionHouse = false

local DEFAULTS = {
    version = 2,
    autoShow = true,
    confirm = "always",
    scrolloff = 3,
    history = {
        cmd = {},
        search = {},
    },
    ui = {},
}

local CHAR_DEFAULTS = {
    version = 1,
}

local function applyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            applyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function initDatabase()
    local account = _G.ActionHouseDB
    if type(account) ~= "table" then
        account = {}
        _G.ActionHouseDB = account
    end
    local previousVersion = tonumber(account.version) or 0
    applyDefaults(account, DEFAULTS)
    if previousVersion < 2 then
        account.autoShow = true
    end
    account.version = 2
    account.loadedAt = time()
    account.loadedBuild = ns.Compat and ns.Compat:GetBuildString() or "?"
    account.loadedVersion = ns.version

    local character = _G.ActionHouseCharDB
    if type(character) ~= "table" then
        character = {}
        _G.ActionHouseCharDB = character
    end
    applyDefaults(character, CHAR_DEFAULTS)

    ns.db = account
    ns.charDB = character
end

function ns:IsReady()
    return not self.disabled and self.db ~= nil
end

function ns:Print(text)
    local message = "|cffd4af37ActionHouse|r: " .. tostring(text or "")
    local chat = _G.DEFAULT_CHAT_FRAME
    if chat and chat.AddMessage then
        chat:AddMessage(message)
    else
        print(message)
    end
end

function ns:PrintLong(lines)
    if type(lines) == "string" then
        local split = {}
        for line in lines:gmatch("[^\n]+") do
            split[#split + 1] = line
        end
        lines = split
    end
    for _, line in ipairs(lines or {}) do
        line = tostring(line)
        while #line > 220 do
            self:Print(line:sub(1, 220))
            line = line:sub(221)
        end
        self:Print(line)
    end
end

function ns:Notify(text, isError)
    if ns.UI and ns.UI:IsShown() then
        ns.UI:SetMessage(text, isError)
    else
        self:Print(text)
    end
end

function ns:SaveProbe(lines)
    if not self.db then
        return
    end
    local copy = {}
    for index, line in ipairs(lines or {}) do
        copy[index] = tostring(line)
    end
    self.db.probe = {
        at = time(),
        addon = self.version,
        lines = copy,
        text = table.concat(copy, "\n"),
    }
end

local function showUsage()
    ns:Print("commands: /ahv | live | demo [tab] | status | throttle | probe | keytest | toggle | help")
    ns:Print("in game: ? help  : commands  / search  Enter drill-in  b bid  B buyout")
    ns:Print("  :sell  :owned  :bids  :post  :cancel  :raise [money]  :price")
    ns:Print("  :search <text>  :filter <expr>  :sort <field> [asc|desc]  :set <key>=<value>")
    ns:Print("  :buy [qty]  :bid [money]  :messages  :version  :refresh  :more")
    ns:Print("  :back  :tab <name>  :b / :blizzard  :q  :reload")
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_MONEY")

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then
            initDatabase()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        if not ns.db then
            initDatabase()
        end
        if not ns.Compat:IsForever() then
            ns.disabled = true
            ns:Print("this build targets WoW Forever (wowf, Interface 16001). Client is not supported.")
            return
        end
        if ns.Auction then
            ns.Auction:Init()
        end
        if ns.Sell then
            ns.Sell:Init()
        end
        if ns.Manage then
            ns.Manage:Init()
        end
        if not ns.Compat:HasFunction("SendBrowseQuery") then
            ns:Print(
                "warning: C_AuctionHouse.SendBrowseQuery is not available yet; live Buy will retry when the AH opens."
            )
        end
        ns:Print(
            "loaded. Open the auction house or use |cffffff00/ahv demo|r; |cffffff00/ahv status|r shows diagnostics."
        )
        return
    end

    if ns.disabled then
        return
    end

    if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
        if ns.Auction and ns.Auction.PrepareForReload then
            ns.Auction:PrepareForReload()
        end
        return
    end

    if event == "AUCTION_HOUSE_SHOW" then
        if ns.Compat then
            ns.Compat.ahOpen = true
        end
        ns.UI:Init()
        ns.db.lastAuctionHouseShow = time()
        ns.db.lastShowBuild = ns.Compat and ns.Compat:GetBuildString() or "?"
        ns.UI:OnAuctionHouseShow()
        if not ns.db.autoShow and not ns.sawAuctionHouse then
            ns.sawAuctionHouse = true
            ns:Print("auction house detected. Use /ahv or :blizzard from the AH.")
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if ns.Compat then
            ns.Compat.ahOpen = false
        end
        ns.db.lastAuctionHouseClose = time()
        if ns.UI then
            ns.UI:OnAuctionHouseClosed()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if ns.UI then
            ns.UI:OnCombat(true)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.UI then
            ns.UI:OnCombat(false)
        end
    elseif event == "PLAYER_MONEY" then
        if ns.UI then
            ns.UI:OnMoney()
        end
    end
end)

local baseReloadUI = rawget(_G, "ReloadUI")
local reloadQueued = false

local function safeReloadUI(...)
    local args = { ... }
    if reloadQueued then
        return
    end
    reloadQueued = true

    local auction = ns.Auction
    local ahOpen = false
    if ns.Compat and ns.Compat.IsAuctionHouseOpen then
        local ok, open = pcall(ns.Compat.IsAuctionHouseOpen, ns.Compat)
        ahOpen = ok and open and true or false
    end
    if auction and auction.IsActive and auction:IsActive() then
        ahOpen = true
    end

    if not ns.disabled and auction and auction.PrepareForReload then
        pcall(auction.PrepareForReload, auction)
    end

    if ns.disabled or not ahOpen then
        reloadQueued = false
        if type(baseReloadUI) == "function" then
            return baseReloadUI(unpack(args))
        end
        return
    end

    C_Timer.After(0.5, function()
        reloadQueued = false
        if type(baseReloadUI) == "function" then
            baseReloadUI(unpack(args))
        end
    end)
end

if type(baseReloadUI) == "function" then
    _G.ReloadUI = safeReloadUI
end

SLASH_ACTIONHOUSE1 = "/ahv"
SLASH_ACTIONHOUSE2 = "/actionhouse"
SlashCmdList["ACTIONHOUSE"] = function(message)
    if not ns.db then
        initDatabase()
    end
    if ns.disabled then
        ns:Print("disabled: this build targets WoW Forever only.")
        return
    end

    message = tostring(message or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if message == "" then
        ns.UI:Toggle()
        return
    end
    if message:lower() == "help" then
        ns.UI:ShowHelp()
        return
    end
    if message:lower() == "usage" then
        showUsage()
        return
    end
    ns.Commands:Run(message)
end

function ActionHouse_Toggle()
    if not ns.db then
        return
    end
    if ns.disabled then
        ns:Print("disabled: this build targets WoW Forever only.")
        return
    end
    ns.UI:Toggle()
end

function ActionHouse_Help()
    if not ns.db or ns.disabled then
        return
    end
    ns.UI:ShowHelp()
end
