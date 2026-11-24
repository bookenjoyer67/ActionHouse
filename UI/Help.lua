local ADDON_NAME, ns = ...
local Help = {}
Help.__index = Help

ns.UI = ns.UI or {}
ns.UI.Help = Help

local VISIBLE_LINES = 24
local LINE_HEIGHT = 16

local LINES = {
    "ActionHouse — Vim-mode auction house for WoW Forever",
    "",
    "MODES",
    "  NORMAL   navigation and actions",
    "  INSERT   search, filter, commands, form fields",
    "  SELLFORM edit a posting form",
    "  VISUAL   select rows",
    "  COMMAND  : command line",
    "  CONFIRM  y confirms, n or Esc cancels",
    "",
    "NAVIGATION",
    "  j k             down / up (count works: 5j)",
    "  gg G Home End   first / last (5G = row 5)",
    "  Ctrl-d Ctrl-u   half page",
    "  Ctrl-f Ctrl-b   full page",
    "  H M L           top / middle / bottom of the screen",
    "  gt gT Tab S-Tab next / previous tab (h / l also work)",
    "  /               search Buy, filter Sell/Owned/Bids",
    "                  grey suffix previews a recent search; Tab accepts",
    "                  Shift-Tab restores the previous prefix",
    "  n N             next / previous match",
    "  * #             search the selected item name",
    "  m               load more Buy results",
    "  Backspace -     back; Esc closes the Sell form",
    "",
    "LIVE BUY",
    "  /               server search; Enter submits",
    "  Enter o         drill into a search row",
    "  B               buyout an item; commodity opens a quantity prompt",
    "                  qty starts at 1, selected: just type the new amount",
    "  b               bid on an item auction",
    "  :buy 20         buy 20 of a commodity directly",
    "  :bid 5g         place a custom bid",
    "  m               request more results",
    "  Backspace -     return from item detail",
    "  r R             re-run the current buying query",
    "  :b / :blizzard  hide ActionHouse and show Blizzard's AH",
    "",
    "SELL",
    "  p Enter         open the posting form for the selected bag item",
    "  j k Tab         move between form fields",
    "  i e             edit a form field",
    "  + -             adjust the current field",
    "  Enter p         post the form immediately",
    "  :price          retry the lowest-listing price lookup",
    "  Esc             close the form and unlock the item",
    "  r               refresh the bag list",
    "",
    "OWNED",
    "  x               cancel the selected active auction",
    "  r               refresh owned auctions",
    "  sold/expired    collect at the mailbox",
    "",
    "BIDS",
    "  Enter b         raise the selected bid",
    "  B               buyout the selected bid when a buyout exists",
    "  r               refresh bids",
    "",
    "UPGRADES (Cheap Upgrades)",
    "  Enter o         search the selected upgrade in Buy",
    "  r               re-read CheapUpgrades results",
    "  / :filter       filter by item, spec, or replaced item",
    "  SPEC/REPLACES   specs it upgrades and gear it beats",
    "  Shift (hold)    Blizzard item comparison for the chosen upgrade",
    "  hover           item tooltip; hold Shift to compare",
    "  Scan from /cu first; ActionHouse does not run scans.",
    "",
    "COMMANDS",
    "  :help  :demo [buy|sell|owned|bids]  :probe [live]",
    "  :probedump  :keytest  :toggle  :focus  :b / :blizzard  :q",
    "  :status  :back  :refresh  :live  :more",
    "  :sell  :owned  :bids  :upgrades  :tab <name>",
    "  :search <text>  :clear  :filter <expr>",
    "  :sort <field> [asc|desc]  :set <key>=<value>",
    "  :buy [qty]  :bid [money]  :raise [money]",
    "  :post  :price  :cancel  :messages  :version",
    "",
    "DEMO MODE",
    "  /ahv demo opens fixtures and never touches the real AH.",
    "  Every buy/cancel/post asks y/n so the modal flow can be tested.",
    "",
    "CURRENT BUILD",
    "  Buy, Sell, Owned, and Bids are live.",
    "  ActionHouse auto-opens on Buy; :blizzard returns to Blizzard.",
    "  Buy, bid, buyout, and cancel ask y/n first.",
    "  Sell posts immediately on Enter; Blizzard may ask for confirmation.",
    "  Posts are one keypress; confirm Blizzard's dialog if it appears.",
    "  Sell prices auto-fill when auto-price is on (lowest listing minus 1c).",
}

function Help:New(parent)
    local self = setmetatable({}, Help)
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -12)
    self.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 12)
    self.frame:SetFrameLevel(parent:GetFrameLevel() + 70)
    self.frame:Hide()

    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0.02, 0.02, 0.025, 0.985)

    self.title = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 14, -12)
    self.title:SetText("ActionHouse Help")

    self.close = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.close:SetPoint("TOPRIGHT", -14, -14)
    self.close:SetText("q / Esc closes")
    self.close:SetTextColor(0.55, 0.55, 0.55)

    self.lines = {}
    for index = 1, VISIBLE_LINES do
        local line = self.frame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
        line:SetPoint("TOPLEFT", 16, -40 - ((index - 1) * LINE_HEIGHT))
        line:SetPoint("TOPRIGHT", -16, -40 - ((index - 1) * LINE_HEIGHT))
        line:SetHeight(LINE_HEIGHT)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        line:SetWordWrap(false)
        line:SetTextColor(0.82, 0.82, 0.82)
        self.lines[index] = line
    end

    self.footer = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.footer:SetPoint("BOTTOMLEFT", 16, 10)
    self.footer:SetTextColor(0.55, 0.55, 0.55)

    self.scroll = 1
    return self
end

function Help:IsShown()
    return self.frame and self.frame:IsShown()
end

function Help:Render()
    local maxScroll = math.max(1, #LINES - VISIBLE_LINES + 1)
    if self.scroll > maxScroll then
        self.scroll = maxScroll
    end
    if self.scroll < 1 then
        self.scroll = 1
    end

    for index = 1, VISIBLE_LINES do
        local text = LINES[self.scroll + index - 1] or ""
        local line = self.lines[index]
        line:SetText(text)
        if text:match("^%u") and not text:match("^ActionHouse") then
            line:SetTextColor(0.95, 0.82, 0.35)
        elseif text:match("^%s%s") then
            line:SetTextColor(0.82, 0.82, 0.82)
        else
            line:SetTextColor(0.62, 0.62, 0.62)
        end
    end

    self.footer:SetText(string.format("%d/%d  j k scroll  q close", self.scroll, maxScroll))
end

function Help:Show()
    self.scroll = 1
    self:Render()
    self.frame:Show()
    if ns.UI then
        self.previousMode = ns.UI.state.mode
        ns.UI.state.mode = "HELP"
        ns.UI:UpdateStatus()
    end
end

function Help:Hide()
    self.frame:Hide()
    if ns.UI then
        if ns.UI.state.mode == "HELP" then
            local returnMode = self.previousMode
            if returnMode == nil or returnMode == "HELP" then
                returnMode = "NORMAL"
            end
            ns.UI.state.mode = returnMode
        end
        self.previousMode = nil
        ns.UI:UpdateStatus()
        ns.UI:FocusKeys()
    end
end

function Help:Scroll(delta)
    self.scroll = self.scroll + (delta or 1)
    self:Render()
end

function Help:Key(token)
    if token == "Esc" or token == "q" or token == "Q" or token == "?" then
        self:Hide()
    elseif token == "j" or token == "Down" then
        self:Scroll(1)
    elseif token == "k" or token == "Up" then
        self:Scroll(-1)
    elseif token == "C-d" or token == "PageDown" then
        self:Scroll(8)
    elseif token == "C-u" or token == "PageUp" then
        self:Scroll(-8)
    elseif token == "g" then
        self.scroll = 1
        self:Render()
    elseif token == "G" then
        self.scroll = math.max(1, #LINES - VISIBLE_LINES + 1)
        self:Render()
    elseif token == ":" then
        self:Hide()
        ns.UI:OpenCommand()
    elseif token == "/" then
        self:Hide()
        ns.UI:OpenSearch()
    end
    return true
end
