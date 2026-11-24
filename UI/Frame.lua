local ADDON_NAME, ns = ...
local UI = ns.UI or {}

ns.UI = UI

local COLORS = {
    bg = { 0.025, 0.025, 0.03, 0.97 },
    border = { 0.45, 0.36, 0.16, 1 },
    text = { 0.85, 0.85, 0.85 },
    dim = { 0.55, 0.55, 0.55 },
    gold = { 1.0, 0.82, 0.0 },
    red = { 1.0, 0.35, 0.35 },
    green = { 0.4, 1.0, 0.4 },
    purple = { 0.72, 0.55, 1.0 },
}

local MODE_COLORS = {
    NORMAL = COLORS.text,
    VISUAL = COLORS.purple,
    INSERT = COLORS.green,
    SELLFORM = COLORS.green,
    COMMAND = COLORS.green,
    CONFIRM = COLORS.gold,
    HELP = COLORS.green,
    KEYTEST = COLORS.green,
}

local function fs(parent, template, layer)
    return parent:CreateFontString(nil, layer or "ARTWORK", template or "GameFontHighlight")
end

local function setColor(text, color)
    text:SetTextColor(color[1], color[2], color[3])
end

local function safeMoney()
    local ok, money = pcall(GetMoney)
    if ok and type(money) == "number" then
        return money
    end
    return 0
end

function UI:Init()
    if self.frame then
        return
    end

    self.state = ns.State.New()
    self.state.scrolloff = (ns.db and ns.db.scrolloff) or 3
    self.log = {}
    self.columnTab = nil

    if ns.Auction then
        ns.Auction:Init()
    end
    if ns.Sell then
        ns.Sell:Init()
    end
    if ns.Manage then
        ns.Manage:Init()
    end
    self:CreateFrame()
    self:CreateKeyCatcher()
    self:UpdateStatus()
end

function UI:CreateFrame()
    local blocker = CreateFrame("Frame", nil, UIParent)
    self.blocker = blocker
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    blocker:SetFrameLevel(490)
    blocker:EnableMouse(true)
    blocker.bg = blocker:CreateTexture(nil, "BACKGROUND")
    blocker.bg:SetAllPoints()
    blocker.bg:SetColorTexture(0, 0, 0, 0.45)
    blocker:SetScript("OnMouseDown", function()
        self:FocusKeys()
    end)
    blocker:Hide()

    local frame = CreateFrame("Frame", "ActionHouseVimFrame", UIParent)
    self.frame = frame
    frame:SetFrameLevel(500)
    frame:SetSize(
        math.max(760, math.floor(UIParent:GetWidth() * 0.86)),
        math.max(520, math.floor(UIParent:GetHeight() * 0.82))
    )
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function()
        self:FocusKeys()
    end)
    frame:Hide()

    local dbUI = ns.db and ns.db.ui
    if dbUI and dbUI.point then
        frame:ClearAllPoints()
        frame:SetPoint(dbUI.point, UIParent, dbUI.relPoint or dbUI.point, dbUI.x or 0, dbUI.y or 0)
    end

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], COLORS.bg[4])

    local function edge(anchorA, anchorB, width, height)
        local tex = frame:CreateTexture(nil, "BORDER")
        tex:SetPoint(anchorA)
        tex:SetPoint(anchorB)
        if width then
            tex:SetWidth(width)
        end
        if height then
            tex:SetHeight(height)
        end
        tex:SetColorTexture(COLORS.border[1], COLORS.border[2], COLORS.border[3], COLORS.border[4])
        return tex
    end
    edge("TOPLEFT", "TOPRIGHT", nil, 1)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

    local titleBar = CreateFrame("Frame", nil, frame)
    self.titleBar = titleBar
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(28)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
        self:FocusKeys()
    end)

    titleBar.bg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBar.bg:SetAllPoints()
    titleBar.bg:SetColorTexture(0.05, 0.05, 0.06, 0.95)

    titleBar.title = fs(titleBar, "GameFontNormalLarge")
    titleBar.title:SetPoint("LEFT", 12, 0)
    titleBar.title:SetText("ActionHouse")
    setColor(titleBar.title, COLORS.gold)

    titleBar.badge = fs(titleBar, "GameFontNormalSmall")
    titleBar.badge:SetPoint("LEFT", titleBar.title, "RIGHT", 12, 0)
    setColor(titleBar.badge, COLORS.dim)

    titleBar.hint = fs(titleBar, "GameFontHighlightSmall")
    titleBar.hint:SetPoint("RIGHT", -36, 0)
    titleBar.hint:SetText("? help    :q quit")
    setColor(titleBar.hint, COLORS.dim)

    local close = CreateFrame("Button", nil, titleBar)
    close:SetSize(22, 22)
    close:SetPoint("RIGHT", -8, 0)
    close.text = fs(close, "GameFontNormal")
    close.text:SetAllPoints()
    close.text:SetText("x")
    close.text:SetJustifyH("CENTER")
    setColor(close.text, COLORS.dim)
    close:SetScript("OnClick", function()
        self:RequestClose()
    end)
    close:SetScript("OnEnter", function()
        setColor(close.text, COLORS.red)
    end)
    close:SetScript("OnLeave", function()
        setColor(close.text, COLORS.dim)
    end)
    self.closeButton = close

    local tabBar = CreateFrame("Frame", nil, frame)
    self.tabBar = tabBar
    tabBar:SetPoint("TOPLEFT", 1, -29)
    tabBar:SetPoint("TOPRIGHT", -1, -29)
    tabBar:SetHeight(24)

    self.tabButtons = {}
    local previous
    for index, tab in ipairs(ns.State.TABS) do
        local button = CreateFrame("Button", nil, tabBar)
        button:SetSize(90, 22)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            button:SetPoint("LEFT", 10, 0)
        end
        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints()
        button.text = fs(button, "GameFontNormalSmall")
        button.text:SetAllPoints()
        button.text:SetJustifyH("CENTER")
        button.text:SetText(ns.State.TAB_LABELS[tab])
        setColor(button.text, COLORS.dim)
        button:SetScript("OnClick", function()
            self:SetTab(tab)
            self:FocusKeys()
        end)
        self.tabButtons[tab] = button
        previous = button
    end

    local searchBar = CreateFrame("Frame", nil, frame)
    self.searchBar = searchBar
    searchBar:SetPoint("TOPLEFT", 1, -53)
    searchBar:SetPoint("TOPRIGHT", -1, -53)
    searchBar:SetHeight(22)

    searchBar.label = fs(searchBar, "GameFontNormalSmall")
    searchBar.label:SetPoint("LEFT", 12, 0)
    searchBar.label:SetText("SEARCH")
    setColor(searchBar.label, COLORS.dim)

    searchBar.query = fs(searchBar, "GameFontHighlightSmall")
    searchBar.query:SetPoint("LEFT", searchBar.label, "RIGHT", 10, 0)
    searchBar.query:SetPoint("RIGHT", searchBar, "RIGHT", -220, 0)
    searchBar.query:SetJustifyH("LEFT")
    searchBar.query:SetWordWrap(false)

    searchBar.stats = fs(searchBar, "GameFontHighlightSmall")
    searchBar.stats:SetPoint("RIGHT", -12, 0)
    searchBar.stats:SetWidth(210)
    searchBar.stats:SetJustifyH("RIGHT")
    setColor(searchBar.stats, COLORS.dim)

    local content = CreateFrame("Frame", nil, frame)
    self.content = content
    content:SetPoint("TOPLEFT", 10, -77)
    content:SetPoint("TOPRIGHT", -10, -77)
    content:SetPoint("BOTTOMLEFT", 10, 86)
    content:SetPoint("BOTTOMRIGHT", -10, 86)

    self.listArea = CreateFrame("Frame", nil, content)
    self.listArea:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    self.listArea:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)

    self.list = ns.UI.List:New(self.listArea, self.state)

    self.detail = fs(frame, "GameFontHighlightSmall")
    self.detail:SetPoint("BOTTOMLEFT", 12, 66)
    self.detail:SetPoint("BOTTOMRIGHT", -12, 66)
    self.detail:SetHeight(18)
    self.detail:SetJustifyH("LEFT")
    self.detail:SetWordWrap(false)
    setColor(self.detail, COLORS.text)

    self.message = fs(frame, "GameFontHighlightSmall")
    self.message:SetPoint("BOTTOMLEFT", 12, 46)
    self.message:SetPoint("BOTTOMRIGHT", -12, 46)
    self.message:SetHeight(18)
    self.message:SetJustifyH("LEFT")
    self.message:SetWordWrap(false)

    local status = CreateFrame("Frame", nil, frame)
    self.statusBar = status
    status:SetPoint("BOTTOMLEFT", 1, 1)
    status:SetPoint("BOTTOMRIGHT", -1, 1)
    status:SetHeight(22)
    status.bg = status:CreateTexture(nil, "BACKGROUND")
    status.bg:SetAllPoints()
    status.bg:SetColorTexture(0.05, 0.05, 0.06, 0.95)

    status.left = fs(status, "GameFontHighlightSmall")
    status.left:SetPoint("LEFT", 10, 0)
    status.left:SetPoint("RIGHT", status, "RIGHT", -300, 0)
    status.left:SetJustifyH("LEFT")
    status.left:SetWordWrap(false)

    status.right = fs(status, "GameFontHighlightSmall")
    status.right:SetPoint("RIGHT", -10, 0)
    status.right:SetWidth(290)
    status.right:SetJustifyH("RIGHT")
    setColor(status.right, COLORS.text)

    self.prompt = ns.UI.Prompt:New(frame)
    self.help = ns.UI.Help:New(frame)
    self.confirm = ns.UI.Confirm:New(frame)
    self.sellForm = ns.UI.SellForm:New(frame)

    frame:SetScript("OnShow", function()
        if self.blocker then
            self.blocker:Show()
        end
        self:FocusKeys()
    end)
    frame:SetScript("OnHide", function()
        if self.blocker then
            self.blocker:Hide()
        end
        self:ReleaseKeys()
    end)
end

function UI:CreateKeyCatcher()
    local catcher = CreateFrame("EditBox", "ActionHouseKeyCatcher", UIParent)
    self.catcher = catcher
    catcher:SetSize(1, 1)
    catcher:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    catcher:SetAutoFocus(false)
    catcher:SetAlpha(0)
    catcher:SetText("")
    catcher:EnableMouse(false)
    catcher:SetMaxLetters(1)
    catcher:Show()
    if catcher.EnableKeyboard then
        catcher:EnableKeyboard(true)
    end

    catcher:SetScript("OnKeyDown", function(self, key)
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(false)
        end
        if key ~= "TAB" and key ~= "ENTER" and key ~= "ESCAPE" and key ~= "NUMPADENTER" then
            local token = ns.Keys.FromEvent(key)
            local consumed = ns.Keymap:OnKey(token, key)
            if not consumed and self.SetPropagateKeyboardInput then
                self:SetPropagateKeyboardInput(true)
            end
        end
        self:SetText("")
    end)
    catcher:SetScript("OnChar", function(self)
        self:SetText("")
    end)
    catcher:SetScript("OnTabPressed", function(self)
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(false)
        end
        local shift = _G.IsShiftKeyDown and _G.IsShiftKeyDown() or false
        local token = shift and "S-Tab" or "Tab"
        ns.Keymap:OnKey(token, "TAB")
    end)
    catcher:SetScript("OnEnterPressed", function(self)
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(false)
        end
        ns.Keymap:OnKey("Enter", "ENTER")
        if ns.UI then
            ns.UI:FocusKeys()
        end
    end)
    catcher:SetScript("OnEscapePressed", function(self)
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(false)
        end
        ns.Keymap:OnKey("Esc", "ESCAPE")
        if ns.UI then
            ns.UI:FocusKeys()
        end
    end)
end

function UI:SavePosition()
    if not ns.db or not self.frame then
        return
    end
    local point, _, relPoint, x, y = self.frame:GetPoint(1)
    ns.db.ui = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y,
    }
end

function UI:IsShown()
    return self.frame and self.frame:IsShown()
end

function UI:IsLive()
    return ns.Auction ~= nil and not self.state.demo and self.state.tab == "buy"
end

function UI:ConfirmRequired()
    local mode = ns.db and ns.db.confirm or "always"
    return mode ~= "off"
end

function UI:IsPromptOpen()
    return self.prompt and self.prompt:IsShown()
end

function UI:HasFocus()
    local focus = _G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus() or nil
    return focus == self.catcher or (self.prompt and self.prompt:HasFocus())
end

function UI:FocusKeys()
    if not self.frame or not self.frame:IsShown() or self.state.paused then
        return
    end
    if self.prompt and self.prompt:IsShown() then
        return
    end
    if not self.catcher then
        return
    end
    local function focus()
        if self.frame and self.frame:IsShown() and not self.state.paused and self.catcher then
            if not (self.prompt and self.prompt:IsShown()) then
                self.catcher:SetFocus()
            end
        end
    end
    C_Timer.After(0, focus)
    C_Timer.After(0.25, focus)
    C_Timer.After(0.6, focus)
end

function UI:ReleaseKeys()
    if self.catcher then
        self.catcher:ClearFocus()
    end
end

function UI:SetMessage(text, isError)
    text = tostring(text or "")
    self.messageText = text
    self.messageIsError = not not isError
    if text ~= "" then
        self.log[#self.log + 1] = text
        if #self.log > 100 then
            table.remove(self.log, 1)
        end
    end
    self:UpdateStatus()
end

function UI:GetLog()
    return self.log
end

function UI:ColumnsForTab()
    local columns = ns.UI.List.COLUMNS
    return columns[self.state.tab] or columns.buy
end

local function defaultSortFor(tab)
    if tab == "sell" then
        return "name", true
    elseif tab == "owned" or tab == "bids" then
        return "time", true
    end
    return "price", true
end

function UI:SetTab(tab)
    if not self.state:SetTab(tab) then
        self:SetMessage("Unknown tab: " .. tostring(tab), true)
        return
    end
    if self.sellForm and self.sellForm:IsShown() then
        self.sellForm:Hide()
    end

    self.state:ClearTransient()
    self.state:StopVisual()
    self.state.search = ""
    self.state.filter = ""
    local field, asc = defaultSortFor(tab)
    self.state.sort.field = field
    self.state.sort.asc = asc

    self:LoadRows(true)
    local hints = {
        buy = "Buy: / search, Enter drill, b bid, B buyout.",
        sell = "Sell: select a bag item, p to post.",
        owned = "Owned: x cancel, r refresh.",
        bids = "Bids: Enter/b raise, B buyout, r refresh.",
    }
    self:SetMessage(hints[tab] or ("Tab: " .. ns.State.TAB_LABELS[self.state.tab]))
    self:Refresh()

    if not self.state.demo then
        if tab == "sell" and ns.Sell then
            ns.Sell:RefreshBags()
        elseif tab == "owned" and ns.Manage then
            ns.Manage:RefreshOwned()
        elseif tab == "bids" and ns.Manage then
            ns.Manage:RefreshBids()
        end
    end
end

function UI:NextTab(delta)
    local index = self.state:TabIndex() + (delta or 1)
    while index > #ns.State.TABS do
        index = index - #ns.State.TABS
    end
    while index < 1 do
        index = index + #ns.State.TABS
    end
    self:SetTab(ns.State.TABS[index])
end

function UI:LoadRows(reset)
    reset = reset ~= false
    if self.state.demo then
        self.state.live = false
        self.state:SetRows(ns.Demo.GetRows(self.state.tab), reset)
    elseif self.state.tab == "buy" then
        self.state.live = true
        self.state:SetRows(ns.Auction:GetRows(), reset)
    elseif self.state.tab == "sell" then
        self.state.live = false
        self.state:SetRows(ns.Sell:GetRows(), reset)
    elseif self.state.tab == "owned" then
        self.state.live = false
        self.state:SetRows(ns.Manage:GetOwnedRows(), reset)
    elseif self.state.tab == "bids" then
        self.state.live = false
        self.state:SetRows(ns.Manage:GetBidRows(), reset)
    end
end

function UI:Refresh()
    if not self.frame then
        return
    end

    for tab, button in pairs(self.tabButtons) do
        if tab == self.state.tab then
            button.bg:SetColorTexture(0.18, 0.14, 0.06, 0.95)
            setColor(button.text, COLORS.gold)
        else
            button.bg:SetColorTexture(0, 0, 0, 0)
            setColor(button.text, COLORS.dim)
        end
    end

    local spec = self:ColumnsForTab()
    if self.columnTab ~= self.state.tab then
        self.columnTab = self.state.tab
        if self.listHeader then
            self.listHeader:Hide()
        end
        self.listHeader = ns.UI.List.CreateHeader(self.content, spec)
        self.listHeader:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, 0)
        self.listHeader:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, 0)
        self.listHeader:SetHeight(18)

        self.listArea:ClearAllPoints()
        self.listArea:SetPoint("TOPLEFT", self.listHeader, "BOTTOMLEFT", 0, -2)
        self.listArea:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", 0, 0)
        self.list:SetColumns(spec)
    end

    if self.listHeader then
        self.listHeader:Layout()
    end
    self.list:SetColumns(spec)
    self.list:Refresh()
    self:RefreshDetails()
    self:UpdateStatus()
end

function UI:RefreshDetails()
    if not self.detail then
        return
    end
    local row = self.state:GetSelected()
    if not row then
        self.detail:SetText("No rows.")
        setColor(self.detail, COLORS.dim)
        return
    end

    local bits = {}
    bits[#bits + 1] = row.name or "?"
    if row.level and row.level > 0 then
        bits[#bits + 1] = "lvl " .. row.level
    end
    if row.qty and row.qty > 0 then
        bits[#bits + 1] = "qty " .. row.qty
    end
    if row.kind then
        bits[#bits + 1] = row.kind
    end
    if row.price and row.price > 0 then
        bits[#bits + 1] = "price " .. ns.Money.Format(row.price)
    end
    if row.buyout and row.buyout > 0 then
        bits[#bits + 1] = "buyout " .. ns.Money.Format(row.buyout)
    end
    if row.seller and row.seller ~= "" then
        bits[#bits + 1] = row.seller
    end
    if row.status and row.status ~= "active" then
        bits[#bits + 1] = row.status
    end
    if row.view == "sell" then
        bits[#bits + 1] = string.format("bag %s slot %s", tostring(row.bag), tostring(row.slot))
        if row.available then
            bits[#bits + 1] = "available " .. tostring(row.available)
        end
    elseif row.view == "owned" then
        if row.cancelCost then
            bits[#bits + 1] = "cancel fee " .. ns.Money.Format(row.cancelCost)
        end
        if row.bidder and row.bidder ~= "" then
            bits[#bits + 1] = "bidder " .. tostring(row.bidder)
        end
    elseif row.view == "bids" then
        if row.minBid and row.minBid > 0 then
            bits[#bits + 1] = "next bid " .. ns.Money.Format(row.minBid)
        end
    end
    self.detail:SetText(table.concat(bits, "  ·  "))
    setColor(self.detail, COLORS.text)
end

local function throttleLabel()
    if not ns.Compat then
        return "thr: ?"
    end
    local ready = ns.Compat:IsThrottled()
    if ready == nil then
        return "thr: ?"
    end
    return ready and "thr: OK" or "thr: WAIT"
end

function UI:UpdateStatus()
    if not self.statusBar then
        return
    end

    local mode = self.state.mode
    if self.prompt and self.prompt:IsShown() then
        mode = "INSERT"
    end
    local modeColor = MODE_COLORS[mode] or COLORS.text
    local left = string.format("-- %s --", mode)

    if self.state.count ~= "" then
        left = left .. "  count:" .. self.state.count
    end
    if self.state.pending ~= "" then
        left = left .. "  pending:" .. self.state.pending
    end
    if self.state.paused then
        left = left .. "  [combat paused]"
    end

    left = left .. string.format("  %d/%d", self.state.cursor, self.state:GetRowCount())
    if self.state.visualAnchor then
        local from, to = self.state:GetVisualRange()
        left = left .. string.format("  sel:%d-%d", from, to)
    end
    self.statusBar.left:SetText(left)
    setColor(self.statusBar.left, modeColor)

    local live = self:IsLive()
    local tab = self.state.tab
    local throttle
    if not self.state.demo and tab == "buy" then
        throttle = ns.Auction:GetThrottleLabel()
    elseif not self.state.demo and (tab == "owned" or tab == "bids") then
        throttle = ns.Manage:GetThrottleLabel()
    elseif not self.state.demo and tab == "sell" then
        throttle = ns.Sell:IsPriceQueryPending() and "thr: price" or "thr: local"
    else
        throttle = throttleLabel()
    end
    local right = string.format("%s   %s", throttle, ns.Money.FormatShort(safeMoney()))
    if self.state.demo then
        right = "demo   " .. right
    end
    self.statusBar.right:SetText(right)
    setColor(self.statusBar.right, COLORS.text)

    local badge = "LIVE"
    if self.state.keytest then
        badge = "KEY TEST"
    elseif self.state.demo then
        badge = "DEMO"
    end
    self.titleBar.badge:SetText(badge)
    setColor(
        self.titleBar.badge,
        self.state.keytest and COLORS.green or (self.state.demo and COLORS.gold or COLORS.dim)
    )

    if self.message then
        self.message:SetText(self.messageText or "")
        setColor(self.message, self.messageIsError and COLORS.red or COLORS.dim)
    end

    if self.searchBar then
        local query
        local stats
        if live then
            query = ns.Auction:GetQueryLabel()
            stats = ns.Auction:GetResultLabel() .. "   sort: " .. ns.Auction:GetSortLabel()
        else
            query = "—"
            if self.state.search ~= "" then
                query = "/" .. self.state.search
            elseif self.state.filter ~= "" then
                query = ":filter " .. self.state.filter
            end
            local label = tab == "sell" and "bags" or tab
            stats = string.format(
                "%s: %d   sort: %s %s",
                label,
                self.state:GetRowCount(),
                self.state.sort.field,
                self.state.sort.asc and "asc" or "desc"
            )
        end
        self.searchBar.query:SetText(query)
        setColor(self.searchBar.query, COLORS.text)
        self.searchBar.stats:SetText(stats)
    end
end

function UI:GetRowsVisible()
    if self.list then
        return self.list:GetRowsVisible()
    end
    return 20
end

function UI:ShowDefaultView()
    if ns.Compat and ns.Compat:IsAuctionHouseOpen() and ns.features and ns.features.buy then
        self:ShowReal()
    else
        self:ShowDemo(self.state.tab)
    end
end

function UI:OpenCommand()
    self:Init()
    if not self:IsShown() then
        self:ShowDefaultView()
    end
    self.prompt:Open(":", "", "cmd", function(text)
        ns.Commands:Run(text)
    end, function(text)
        return ns.Commands:Complete(text)
    end)
end

function UI:OpenSearch()
    self:Init()
    if not self:IsShown() then
        self:ShowDefaultView()
    end
    if self:IsLive() then
        self.prompt:Open("/", ns.Auction:GetQueryText(), "search", function(text)
            ns.Auction:Search(text)
        end)
        return
    end
    self.prompt:Open("/", self.state.search, "search", function(text)
        self.state:SetSearch(text)
        self.state.cursor = 1
        self:SetMessage(text == "" and "Search cleared." or ("Search: " .. text))
        self:Refresh()
    end)
end

function UI:SetSearch(text)
    if self:IsLive() then
        ns.Auction:Search(text)
        return
    end
    self.state:SetSearch(text)
    self:Refresh()
end

function UI:SetFilter(text)
    if self:IsLive() then
        self:SetMessage("Live server filters come next; use / to search the auction house.", true)
        return
    end
    self.state:SetFilter(text)
    self:Refresh()
end

function UI:SetSort(field, asc)
    self.state.sort.field = field
    self.state.sort.asc = asc ~= false
    if self:IsLive() then
        ns.Auction:SetSort(field, asc)
        self:Refresh()
        return
    end
    self.state:SetSort(field, asc)
    self:Refresh()
end

function UI:CanUse()
    local inCombat = _G.InCombatLockdown and _G.InCombatLockdown() or false
    if inCombat then
        ns:Notify("ActionHouse cannot open in combat.")
        return false
    end
    return true
end

function UI:ShowDemo(tab)
    self:Init()
    if not self:CanUse() then
        return
    end
    if ns.Auction and not self.state.demo then
        ns.Auction:CancelCommodityPurchase(true)
    end
    if self.sellForm and self.sellForm:IsShown() then
        self.sellForm:Hide()
    end
    self.state.demo = true
    self.state.live = false
    self.state.keytest = false
    self.state.paused = false
    if tab then
        if not self.state:SetTab(tab) then
            self.state:SetTab("buy")
        end
    end
    self.state.mode = "NORMAL"
    self:LoadRows()
    self.frame:Show()
    self:SetMessage("Demo mode: fixtures only. y/n confirmations work; no AH actions are sent.")
    self:Refresh()
    self:FocusKeys()
end

function UI:ShowReal()
    self:Init()
    if not self:CanUse() then
        return
    end
    if self.sellForm and self.sellForm:IsShown() then
        self.sellForm:Hide()
    end
    self.state.demo = false
    self.state.live = true
    self.state.keytest = false
    self.state.paused = false
    self.state.mode = "NORMAL"
    if ns.Auction and not ns.Auction:IsActive() then
        ns.Auction:OnShow()
    end
    if ns.Sell and not ns.Sell:IsActive() then
        ns.Sell:OnShow()
    end
    if ns.Manage and not ns.Manage:IsActive() then
        ns.Manage:OnShow()
    end
    self.state.search = ""
    self.state.filter = ""
    self.state.sort.field = "price"
    self.state.sort.asc = true
    self.state:SetTab("buy")
    self:LoadRows(true)
    self.frame:Show()
    if #ns.Auction:GetRows() == 0 then
        self:SetMessage("Live Buy. Press / to search the auction house. :blizzard for the normal AH.")
    else
        self:SetMessage("Live Buy. Press / to search; Enter drills in; b bid; B buyout.")
    end
    self:Refresh()
    self:FocusKeys()
end

function UI:Toggle()
    if self:IsShown() then
        self:Hide()
        return
    end
    if not self:CanUse() then
        return
    end
    if ns.Compat and ns.Compat:IsAuctionHouseOpen() then
        self:ShowDefaultView()
    else
        self:ShowDemo("buy")
    end
end

function UI:StartKeytest()
    self:Init()
    if not self:CanUse() then
        return
    end
    if ns.Auction and not self.state.demo then
        ns.Auction:CancelCommodityPurchase(true)
    end
    if self.sellForm and self.sellForm:IsShown() then
        self.sellForm:Hide()
    end
    self.state.demo = true
    self.state.live = false
    self.state.keytest = true
    self.state:SetTab("buy")
    self:LoadRows()
    self.state.mode = "NORMAL"
    self.keytestLog = {}
    self.frame:Show()
    self:SetMessage("Key test: press keys. Esc exits. The log is saved to ActionHouseDB.")
    self:Refresh()
    self:FocusKeys()
end

function UI:KeytestKey(token, raw)
    if token == "Esc" then
        self.state.keytest = false
        self:SetMessage("Key test ended. Last token: " .. tostring(token))
        self:Refresh()
        return true
    end

    self.keytestLog = self.keytestLog or {}
    local entry = string.format("%s => %s", tostring(raw or "?"), tostring(token or "?"))
    self.keytestLog[#self.keytestLog + 1] = entry
    if #self.keytestLog > 60 then
        table.remove(self.keytestLog, 1)
    end
    if ns.db then
        local copy = {}
        for index, value in ipairs(self.keytestLog) do
            copy[index] = value
        end
        ns.db.keytest = {
            at = time(),
            log = copy,
        }
    end
    self:SetMessage("Key test  raw: " .. tostring(raw) .. "   token: " .. tostring(token))
    return true
end

function UI:SetMode(mode)
    self.state.mode = mode
    self:UpdateStatus()
end

function UI:ShowHelp()
    self:Init()
    if not self:IsShown() then
        if not self:CanUse() then
            return
        end
        self:ShowDefaultView()
    end
    self.help:Show()
end

function UI:HideHelp()
    self.help:Hide()
end

function UI:OpenConfirm(text, onYes, onNo, returnMode)
    self:Init()
    self.confirm:Open(text, onYes, onNo, returnMode)
end

function UI:ResolveConfirm(accepted)
    self.confirm:Resolve(accepted)
end

function UI:GetKeyFocusName()
    local focus = _G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus() or nil
    if not focus then
        return "none"
    end
    if focus.GetName then
        local ok, name = pcall(focus.GetName, focus)
        if ok and name then
            return name
        end
    end
    return "unnamed"
end

function UI:DemoPrimaryAction()
    local row = self.state:GetSelected()
    if not row then
        self:SetMessage("No row selected.", true)
        return
    end
    local action = "buyout"
    if self.state.tab == "sell" then
        action = "post"
    elseif self.state.tab == "owned" then
        action = "cancel"
    elseif self.state.tab == "bids" then
        action = "bid"
    elseif self.state.tab == "buy" and row.kind == "commodity" then
        action = "buy"
    elseif row.buyout == 0 then
        action = "bid"
    end
    self:DemoAction(action, 1)
end

function UI:DemoAction(action, count)
    local row = self.state:GetSelected()
    if not row then
        self:SetMessage("No row selected.", true)
        return
    end

    count = math.max(1, tonumber(count) or 1)
    local name = row.name or "?"
    local text
    local detail

    if action == "buyout" then
        local price = row.buyout or 0
        if price <= 0 then
            self:SetMessage("That lot has no buyout; use b to bid.", true)
            return
        end
        text = string.format("Demo buyout: %s for %s?", name, ns.Money.FormatShort(price))
        detail = "Demo buyout confirmed: " .. name
    elseif action == "bid" then
        local price = row.bid or row.price or 0
        text = string.format("Demo bid: %s on %s?", ns.Money.FormatShort(price), name)
        detail = "Demo bid confirmed: " .. name
    elseif action == "buy" then
        local unit = row.price or 0
        text = string.format("Demo buy: %dx %s for %s?", count, name, ns.Money.FormatShort(unit * count))
        detail = string.format("Demo purchase confirmed: %dx %s", count, name)
    elseif action == "post" then
        text = string.format("Demo post: %s (deposit shown in the real form)?", name)
        detail = "Demo post confirmed: " .. name
    elseif action == "cancel" then
        text = string.format("Demo cancel: %s (cancel fee shown in the real view)?", name)
        detail = "Demo cancel confirmed: " .. name
    else
        text = string.format("Demo action %s on %s?", tostring(action), name)
        detail = "Demo action confirmed: " .. name
    end

    self.lastAction = { action = action, count = count }
    self:OpenConfirm(text, function()
        self:SetMessage(detail)
        self:Refresh()
    end, function()
        self:SetMessage("Demo action cancelled.")
        self:Refresh()
    end)
end

function UI:DemoVisualAction(action)
    local selection = self.state:GetSelection()
    if #selection == 0 then
        self:SetMessage("Nothing selected.", true)
        return
    end
    local selected = #selection
    local label = action == "cancel" and "cancel" or "post"
    local text = string.format("Demo %s: %d selected %s?", label, selected, selected == 1 and "auction" or "auctions")
    self.state:StopVisual()
    self:OpenConfirm(text, function()
        self:SetMessage(string.format("Demo %s confirmed for %d selected rows.", label, selected))
        self:Refresh()
    end, function()
        self:SetMessage("Demo visual action cancelled.")
        self:Refresh()
    end)
end

function UI:OnAuctionDataChanged(reset)
    if not self.frame or not self:IsShown() then
        return
    end
    if self.state.demo or self.state.tab ~= "buy" then
        return
    end
    self.state.live = true
    self.state:SetRows(ns.Auction:GetRows(), reset ~= false)
    self:Refresh()
end

function UI:OnSellDataChanged(reset)
    if not self.frame or not self:IsShown() then
        return
    end
    if self.state.demo or self.state.tab ~= "sell" then
        return
    end
    self.state.live = false
    self.state:SetRows(ns.Sell:GetRows(), reset ~= false)
    self:Refresh()
end

function UI:OnManageDataChanged(tab, reset)
    if not self.frame or not self:IsShown() then
        return
    end
    if self.state.demo or self.state.tab ~= tab then
        return
    end
    local rows = tab == "owned" and ns.Manage:GetOwnedRows() or ns.Manage:GetBidRows()
    self.state.live = false
    self.state:SetRows(rows, reset ~= false)
    self:Refresh()
end

function UI:ShowSellForm(form)
    if self.sellForm then
        self.sellForm:Show(form)
    end
end

function UI:HideSellForm()
    if self.sellForm and self.sellForm:IsShown() then
        self.sellForm:Hide()
        self:LoadRows(false)
        self:Refresh()
    end
end

function UI:ConfirmCancelOwned(row)
    if not row or row.view ~= "owned" then
        self:SetMessage("Select an owned auction first.", true)
        return
    end
    if row.status == "sold" then
        self:SetMessage("That auction is sold; collect it at the mailbox.", true)
        return
    end
    if row.status == "expired" then
        self:SetMessage("That auction expired; collect it at the mailbox.", true)
        return
    end
    if not row.canCancel then
        self:SetMessage("That auction cannot be cancelled right now.", true)
        return
    end
    if not self:ConfirmRequired() then
        ns.Manage:CancelOwned(row)
        return
    end
    local cost = row.cancelCost and ns.Money.Format(row.cancelCost) or "unknown"
    local text = string.format("Cancel %s? Fee: %s", tostring(row.name or "auction"), cost)
    self:OpenConfirm(text, function()
        ns.Manage:CancelOwned(row)
    end, function()
        self:SetMessage("Cancel cancelled.")
    end)
end

function UI:ConfirmRaiseBid(row, amount)
    if not row or row.view ~= "bids" then
        self:SetMessage("Select a bid first.", true)
        return
    end
    amount = math.floor(tonumber(amount) or tonumber(row.minBid) or tonumber(row.price) or 0)
    if amount < 1 then
        self:SetMessage("That bid has no valid amount.", true)
        return
    end
    if not self:ConfirmRequired() then
        ns.Manage:RaiseBid(row, amount)
        return
    end
    local text = string.format(
        "Raise bid to %s on %s? Current bid: %s",
        ns.Money.Format(amount),
        tostring(row.name or "auction"),
        ns.Money.Format(row.price or 0)
    )
    self:OpenConfirm(text, function()
        ns.Manage:RaiseBid(row, amount)
    end, function()
        self:SetMessage("Bid cancelled.")
    end)
end

function UI:PromptCommodityQuantity(row, defaultQuantity)
    if not row or row.view ~= "commodity" then
        self:SetMessage("Select a commodity lot first.", true)
        return
    end
    local maxQuantity = ns.Auction:GetCommodityMaxQuantity()
    defaultQuantity = math.max(1, math.floor(tonumber(defaultQuantity) or 1))
    if maxQuantity and defaultQuantity > maxQuantity then
        defaultQuantity = maxQuantity
    end
    self.prompt:Open("qty", tostring(defaultQuantity), "qty", function(text)
        local quantity, err
        if text:match("^%s*$") then
            quantity = defaultQuantity
        else
            quantity, err = ns.Money.ParseQuantity(text, maxQuantity)
        end
        if not quantity then
            self:SetMessage(err or "Invalid quantity.", true)
            return
        end
        ns.Auction:StartCommodityPurchase(row, quantity)
    end, nil, true)
end

function UI:ConfirmBid(row, amount)
    if not row or row.view ~= "item" or not row.auctionID then
        self:SetMessage("Select an item auction first.", true)
        return
    end
    amount = math.floor(tonumber(amount) or tonumber(row.bidAmount) or 0)
    if amount < 1 then
        self:SetMessage("That auction has no valid bid price.", true)
        return
    end
    if not self:ConfirmRequired() then
        ns.Auction:PlaceBid(row.auctionID, amount, "bid")
        return
    end
    local text = string.format(
        "Place bid of %s on %s? Current bid: %s",
        ns.Money.Format(amount),
        tostring(row.name or "item"),
        ns.Money.FormatShort(row.currentBid or row.bidAmount or 0)
    )
    self:OpenConfirm(text, function()
        ns.Auction:PlaceBid(row.auctionID, amount, "bid")
    end, function()
        self:SetMessage("Bid cancelled.")
    end)
end

function UI:ConfirmBuyout(row)
    if not row or row.view ~= "item" or not row.auctionID then
        self:SetMessage("Select an item auction first.", true)
        return
    end
    local amount = math.floor(tonumber(row.buyout) or 0)
    if amount < 1 then
        self:SetMessage("That auction has no buyout.", true)
        return
    end
    if not self:ConfirmRequired() then
        ns.Auction:PlaceBid(row.auctionID, amount, "buyout")
        return
    end
    local text = string.format("Buy out %s for %s?", tostring(row.name or "item"), ns.Money.Format(amount))
    self:OpenConfirm(text, function()
        ns.Auction:PlaceBid(row.auctionID, amount, "buyout")
    end, function()
        self:SetMessage("Buyout cancelled.")
    end)
end

function UI:ShowCommodityQuote(quote)
    if not quote or not self:IsShown() then
        return
    end
    if not self:IsLive() or self.state.tab ~= "buy" then
        ns.Auction:CancelCommodityPurchase(true)
        return
    end
    if not self:ConfirmRequired() then
        ns.Auction:ConfirmCommodityPurchase()
        return
    end
    local text = string.format(
        "Buy %dx %s for %s (%s each)?",
        quote.quantity,
        tostring(quote.name or "commodity"),
        ns.Money.Format(quote.totalPrice),
        ns.Money.FormatShort(quote.unitPrice)
    )
    self:OpenConfirm(text, function()
        ns.Auction:ConfirmCommodityPurchase()
    end, function()
        ns.Auction:CancelCommodityPurchase()
    end)
end

function UI:Back()
    if self.sellForm and self.sellForm:IsShown() then
        self:HideSellForm()
        return
    end
    if self:IsLive() then
        ns.Auction:Back()
        return
    end
    self:SetMessage("Nothing to go back to.")
end

function UI:RefreshAll()
    if self.state.demo then
        self:LoadRows(true)
        self:Refresh()
        return
    end
    if self.state.tab == "buy" then
        ns.Auction:Refresh()
    elseif self.state.tab == "sell" then
        ns.Sell:RefreshBags()
        self:SetMessage("Refreshing bags.")
    elseif self.state.tab == "owned" then
        ns.Manage:RefreshOwned()
    elseif self.state.tab == "bids" then
        ns.Manage:RefreshBids()
    end
end

function UI:RequestMore()
    if self.state.tab == "buy" and not self.state.demo then
        ns.Auction:RequestMore()
        return
    end
    self:SetMessage("Load more is only available on live Buy results.")
end

function UI:BidSelected(amount)
    if self.state.tab == "bids" and not self.state.demo then
        self:ConfirmRaiseBid(self.state:GetSelected(), amount)
        return
    end
    if not self:IsLive() then
        self:SetMessage("Bids are only wired for live Buy results.", true)
        return
    end
    local row = self.state:GetSelected()
    if not row or row.view ~= "item" then
        self:SetMessage("Select an item auction to bid.", true)
        return
    end
    self:ConfirmBid(row, amount)
end

function UI:BuySelected(quantity)
    if not self:IsLive() then
        self:SetMessage("Buying is only wired for live Buy results.", true)
        return
    end
    local row = self.state:GetSelected()
    if not row then
        self:SetMessage("No row selected.", true)
        return
    end
    if row.view == "commodity" then
        if quantity and quantity > 0 then
            ns.Auction:StartCommodityPurchase(row, quantity)
        else
            self:PromptCommodityQuantity(row, 1)
        end
    elseif row.view == "item" then
        if (row.buyout or 0) > 0 then
            self:ConfirmBuyout(row)
        else
            self:ConfirmBid(row)
        end
    elseif row.view == "browse" then
        ns.Auction:OpenItem(row)
    end
end

function UI:RepeatLast()
    if not self.state.demo then
        self:SetMessage("Repeat is not wired for live actions yet.", true)
        return
    end
    if not self.lastAction then
        self:SetMessage("No action to repeat.")
        return
    end
    self:DemoAction(self.lastAction.action, self.lastAction.count)
end

function UI:PrimaryAction(action, count)
    if self.state.demo then
        if action then
            self:DemoAction(action, count)
        else
            self:DemoPrimaryAction()
        end
        return
    end

    local tab = self.state.tab
    local row = self.state:GetSelected()

    if tab == "buy" then
        if not self:IsLive() then
            self:SetMessage("Live Buy is unavailable.", true)
            return
        end
        if not row then
            self:SetMessage("No row selected.", true)
            return
        end
        count = math.max(1, tonumber(count) or 1)
        if action == nil then
            if row.view == "browse" then
                ns.Auction:OpenItem(row)
            elseif row.view == "commodity" then
                self:PromptCommodityQuantity(row, count)
            elseif row.view == "item" then
                if (row.buyout or 0) > 0 then
                    self:ConfirmBuyout(row)
                else
                    self:ConfirmBid(row)
                end
            end
            return
        end
        if action == "buy" or action == "buyout" then
            if row.view == "commodity" then
                self:PromptCommodityQuantity(row, count)
            elseif row.view == "item" then
                if action == "buy" and (row.buyout or 0) <= 0 then
                    self:ConfirmBid(row)
                else
                    self:ConfirmBuyout(row)
                end
            elseif row.view == "browse" then
                ns.Auction:OpenItem(row)
            end
            return
        end
        if action == "bid" then
            if row.view == "item" then
                self:ConfirmBid(row)
            else
                self:SetMessage("Select an item auction to bid; Enter opens a search row.", true)
            end
            return
        end
        self:SetMessage("Action not available in the Buy tab.", true)
        return
    end

    if tab == "sell" then
        if action ~= nil and action ~= "post" then
            self:SetMessage("Sell uses p to open the posting form.", true)
            return
        end
        if not row then
            self:SetMessage("No bag item selected.", true)
            return
        end
        if not ns.Sell:OpenForm(row) then
            return
        end
        return
    end

    if tab == "owned" then
        if action == "cancel" then
            self:ConfirmCancelOwned(row)
        else
            self:SetMessage("Owned: x cancels, r refreshes.", true)
        end
        return
    end

    if tab == "bids" then
        if action == nil or action == "bid" then
            self:ConfirmRaiseBid(row)
        elseif action == "buy" or action == "buyout" then
            if row and (row.buyout or 0) > 0 then
                self:ConfirmRaiseBid(row, row.buyout)
            else
                self:SetMessage("That bid has no buyout.", true)
            end
        else
            self:SetMessage("Bids: Enter/b raise, B buyout, r refresh.", true)
        end
        return
    end
end

function UI:SearchSelected()
    local row = self.state:GetSelected()
    if not row then
        self:SetMessage("No row selected.", true)
        return
    end
    if self:IsLive() then
        ns.Auction:Search(row.name or "")
        return
    end
    self.state:SetSearch(row.name or "")
    self:SetMessage("Search: " .. (row.name or ""))
    self:Refresh()
end

function UI:RequestClose()
    if self.confirm and self.confirm:IsShown() then
        self.confirm:Resolve(false)
        return
    end
    if self.help and self.help:IsShown() then
        self.help:Hide()
        return
    end
    self:CloseAH()
end

function UI:CloseAH()
    local wasReal = not self.state.demo
    self:Hide()
    if wasReal and ns.Compat then
        ns.Compat:CloseAuctionHouse()
    end
end

function UI:Hide()
    if self.sellForm and self.sellForm:IsShown() then
        self.sellForm:Hide()
    end
    if not self.state.demo and ns.Auction then
        ns.Auction:CancelCommodityPurchase(true)
    end
    if self.prompt then
        self.prompt:Close(false)
    end
    if self.confirm then
        self.confirm:Close()
    end
    if self.help then
        self.help:Hide()
    end
    self:ReleaseKeys()
    if self.frame then
        self.frame:Hide()
    end
    if self.state then
        self.state.mode = "NORMAL"
        self.state:ClearTransient()
        self.state:StopVisual()
    end
    if self.statusBar then
        self:UpdateStatus()
    end
end

function UI:ShowBlizzard()
    self:Hide()
    if ns.Compat then
        ns.Compat:RevealBlizzard()
    end
    ns:Print("Returned to the normal auction house UI. Use /ahv or :live to bring ActionHouse back.")
end

function UI:OnCombat(disabled)
    if not self.frame then
        return
    end
    self.state.paused = disabled
    if disabled then
        self:ReleaseKeys()
        self:SetMessage("Combat detected: keyboard capture paused.", true)
    else
        self:SetMessage("Combat ended: keyboard capture resumed.")
        if self.frame:IsShown() then
            self:FocusKeys()
        end
    end
    self:UpdateStatus()
end

function UI:OnAuctionHouseShow()
    self:Init()
    if ns.Auction then
        ns.Auction:OnShow()
    end
    if ns.Sell then
        ns.Sell:OnShow()
    end
    if ns.Manage then
        ns.Manage:OnShow()
    end
    if ns.db and ns.db.autoShow then
        if ns.features and ns.features.buy then
            self:ShowReal()
        else
            ns:Print("auction house detected, but live Buy is unavailable. Use /ahv demo.")
        end
    end
end

function UI:OnAuctionHouseClosed()
    if not self.frame then
        return
    end
    if ns.Auction then
        ns.Auction:OnClose()
    end
    if ns.Sell then
        ns.Sell:OnClose()
    end
    if ns.Manage then
        ns.Manage:OnClose()
    end
    if self.frame:IsShown() and not self.state.demo then
        self:Hide()
    end
end

function UI:OnMoney()
    if self.frame and self.frame:IsShown() then
        self:UpdateStatus()
    end
end
