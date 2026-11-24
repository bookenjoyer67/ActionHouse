local ADDON_NAME, ns = ...
local List = {}
List.__index = List

ns.UI = ns.UI or {}
ns.UI.List = List

local ROW_HEIGHT = 18
local MAX_ROWS = 120
local GAP = 4
local ICON_SIZE = 16
local NAME_INDENT = ICON_SIZE + GAP

local COLUMNS = {
    buy = {
        { key = "index", label = "#", width = 0.05, align = "RIGHT" },
        { key = "name", label = "ITEM", width = 0.36, align = "LEFT" },
        { key = "level", label = "LVL", width = 0.06, align = "RIGHT" },
        { key = "qty", label = "QTY", width = 0.08, align = "RIGHT" },
        { key = "price", label = "UNIT / BID", width = 0.15, align = "RIGHT" },
        { key = "buyout", label = "BUYOUT", width = 0.20, align = "RIGHT" },
        { key = "time", label = "TIME", width = 0.10, align = "RIGHT" },
    },
    sell = {
        { key = "index", label = "#", width = 0.05, align = "RIGHT" },
        { key = "name", label = "ITEM", width = 0.45, align = "LEFT" },
        { key = "qty", label = "COUNT", width = 0.10, align = "RIGHT" },
        { key = "kind", label = "TYPE", width = 0.15, align = "LEFT" },
        { key = "status", label = "STATUS", width = 0.25, align = "LEFT" },
    },
    owned = {
        { key = "index", label = "#", width = 0.05, align = "RIGHT" },
        { key = "name", label = "ITEM", width = 0.32, align = "LEFT" },
        { key = "qty", label = "QTY", width = 0.07, align = "RIGHT" },
        { key = "price", label = "BID", width = 0.14, align = "RIGHT" },
        { key = "buyout", label = "BUYOUT", width = 0.14, align = "RIGHT" },
        { key = "time", label = "TIME", width = 0.10, align = "RIGHT" },
        { key = "status", label = "STATUS", width = 0.18, align = "LEFT" },
    },
    bids = {
        { key = "index", label = "#", width = 0.05, align = "RIGHT" },
        { key = "name", label = "ITEM", width = 0.32, align = "LEFT" },
        { key = "qty", label = "QTY", width = 0.07, align = "RIGHT" },
        { key = "price", label = "YOUR BID", width = 0.14, align = "RIGHT" },
        { key = "buyout", label = "BUYOUT", width = 0.14, align = "RIGHT" },
        { key = "time", label = "TIME", width = 0.10, align = "RIGHT" },
        { key = "status", label = "STATUS", width = 0.18, align = "LEFT" },
    },
    upgrades = {
        { key = "index", label = "#", width = 0.05, align = "RIGHT" },
        { key = "name", label = "ITEM", width = 0.33, align = "LEFT" },
        { key = "slot", label = "SLOT", width = 0.10, align = "LEFT" },
        { key = "spec", label = "SPEC", width = 0.12, align = "LEFT" },
        { key = "replaces", label = "REPLACES", width = 0.18, align = "LEFT" },
        { key = "upgrade", label = "UPGRADE", width = 0.08, align = "RIGHT" },
        { key = "price", label = "PRICE", width = 0.14, align = "RIGHT" },
    },
}

List.COLUMNS = COLUMNS

local QUALITY_FALLBACK = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.0, 1.0, 1.0 },
    [2] = { 0.12, 1.0, 0.0 },
    [3] = { 0.0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.0, 0.5, 0.0 },
    [6] = { 0.9, 0.8, 0.5 },
    [7] = { 0.9, 0.8, 0.5 },
}

local COLORS = {
    text = { 0.85, 0.85, 0.85 },
    dim = { 0.55, 0.55, 0.55 },
    gold = { 1.0, 0.82, 0.0 },
    red = { 1.0, 0.35, 0.35 },
    green = { 0.35, 1.0, 0.35 },
    selection = { 0.55, 0.42, 0.12, 0.55 },
    visual = { 0.25, 0.36, 0.58, 0.55 },
    stripe = { 0.07, 0.07, 0.08, 0.85 },
}

local function qualityColor(quality)
    local entry = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[quality]
    if entry and entry.color then
        return entry.color.r, entry.color.g, entry.color.b
    end
    local fallback = QUALITY_FALLBACK[quality] or QUALITY_FALLBACK[1]
    return fallback[1], fallback[2], fallback[3]
end

local function shortText(text, maxBytes)
    text = tostring(text or "")
    if #text <= maxBytes then
        return text
    end
    return text:sub(1, math.max(1, maxBytes - 3)) .. "..."
end

local function kindText(kind)
    if kind == "commodity" then
        return "commodity"
    elseif kind == "item" then
        return "item"
    end
    return tostring(kind or "")
end

local function moneyText(value)
    local number = tonumber(value)
    if not number or number <= 0 then
        return ""
    end
    return ns.Money.FormatShort(number)
end

local function cellText(key, row, slot)
    if key == "index" then
        return tostring(slot)
    elseif key == "name" then
        return shortText(row.name, 58)
    elseif key == "level" then
        return row.level and row.level > 0 and tostring(row.level) or ""
    elseif key == "qty" then
        return tostring(row.qty or row.quantity or "")
    elseif key == "price" then
        if row.kind == "commodity" then
            return moneyText(row.price or row.unitPrice)
        end
        return moneyText(row.bid or row.price)
    elseif key == "buyout" then
        return moneyText(row.buyout)
    elseif key == "time" then
        return tostring(row.time or "")
    elseif key == "kind" then
        return kindText(row.kind)
    elseif key == "status" then
        return tostring(row.status or "")
    elseif key == "slot" then
        return tostring(row.slot or "")
    elseif key == "pct" then
        local pct = tonumber(row.pct)
        return pct and string.format("%+.0f%%", pct) or ""
    elseif key == "spec" then
        return shortText(row.specText, 28)
    elseif key == "replaces" then
        return shortText(row.replacesText, 36)
    elseif key == "upgrade" then
        return shortText(row.upgradeText, 14)
    end
    return tostring(row[key] or "")
end

local function cellColor(key, row)
    if key == "name" then
        return qualityColor(row.quality or 1)
    elseif key == "price" or key == "buyout" then
        return COLORS.gold[1], COLORS.gold[2], COLORS.gold[3]
    elseif key == "pct" then
        return COLORS.green[1], COLORS.green[2], COLORS.green[3]
    elseif key == "slot" then
        return COLORS.dim[1], COLORS.dim[2], COLORS.dim[3]
    elseif key == "spec" then
        return COLORS.gold[1], COLORS.gold[2], COLORS.gold[3]
    elseif key == "replaces" then
        return COLORS.dim[1], COLORS.dim[2], COLORS.dim[3]
    elseif key == "upgrade" then
        if (tonumber(row.gain) or 0) > 0 then
            return COLORS.green[1], COLORS.green[2], COLORS.green[3]
        end
        return COLORS.red[1], COLORS.red[2], COLORS.red[3]
    elseif key == "status" then
        local status = tostring(row.status or ""):lower()
        if status == "sold" or status == "winning" or status == "ready" then
            return COLORS.green[1], COLORS.green[2], COLORS.green[3]
        elseif status == "outbid" or status == "expired" or status == "bound" then
            return COLORS.red[1], COLORS.red[2], COLORS.red[3]
        end
        return COLORS.dim[1], COLORS.dim[2], COLORS.dim[3]
    end
    return COLORS.text[1], COLORS.text[2], COLORS.text[3]
end

function List.CreateHeader(parent, spec)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(ROW_HEIGHT)
    header.texts = {}
    header.spec = spec

    local width = math.max(1, header:GetWidth())
    local x = 0
    for index, column in ipairs(spec) do
        local text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        local cellWidth = width * column.width
        local indent = column.key == "name" and NAME_INDENT or 0
        text:SetPoint("TOPLEFT", header, "TOPLEFT", x + 6 + indent, 0)
        text:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", x + 6 + indent, 0)
        text:SetWidth(math.max(8, cellWidth - GAP - indent))
        text:SetJustifyH(column.align or "LEFT")
        text:SetJustifyV("MIDDLE")
        text:SetWordWrap(false)
        text:SetText(column.label)
        text:SetTextColor(COLORS.dim[1], COLORS.dim[2], COLORS.dim[3])
        header.texts[index] = text
        x = x + cellWidth
    end

    header.Layout = function(self)
        local total = math.max(1, self:GetWidth())
        local offset = 0
        for index, column in ipairs(self.spec) do
            local text = self.texts[index]
            local cellWidth = total * column.width
            local indent = column.key == "name" and NAME_INDENT or 0
            text:ClearAllPoints()
            text:SetPoint("TOPLEFT", self, "TOPLEFT", offset + 6 + indent, 0)
            text:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", offset + 6 + indent, 0)
            text:SetWidth(math.max(8, cellWidth - GAP - indent))
            offset = offset + cellWidth
        end
    end

    header:HookScript("OnSizeChanged", function(self)
        self:Layout()
    end)

    return header
end

function List:New(parent, state)
    local self = setmetatable({}, List)
    self.state = state
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    self.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.rowFrames = {}
    self.columns = COLUMNS.buy
    self.layoutWidth = 0
    self.frame:EnableMouseWheel(true)
    self.frame:SetScript("OnSizeChanged", function()
        self:Refresh()
    end)
    self.frame:SetScript("OnMouseWheel", function(_, delta)
        self.state:Move(delta > 0 and -3 or 3)
        self:Refresh()
        if ns.UI and ns.UI.RefreshDetails then
            ns.UI:RefreshDetails()
        end
    end)
    self:SetColumns(self.columns)
    return self
end

function List:SetColumns(spec)
    self.columns = spec or COLUMNS.buy
    for _, row in ipairs(self.rowFrames) do
        self:LayoutRow(row)
    end
end

function List:LayoutRow(row)
    local total = math.max(1, self.frame:GetWidth())
    local offset = 0
    for index, column in ipairs(self.columns) do
        local text = row.texts[index]
        if not text then
            text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.texts[index] = text
        end
        local cellWidth = total * column.width
        local indent = column.key == "name" and NAME_INDENT or 0
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", row, "TOPLEFT", 6 + offset + indent, 0)
        text:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 6 + offset + indent, 0)
        text:SetWidth(math.max(8, cellWidth - GAP - indent))
        text:SetJustifyH(column.align or "LEFT")
        text:SetJustifyV("MIDDLE")
        text:SetWordWrap(false)
        text:Show()
        if column.key == "name" and row.icon then
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", row, "LEFT", 6 + offset, 0)
        end
        offset = offset + cellWidth
    end
    for index = #self.columns + 1, #row.texts do
        row.texts[index]:Hide()
    end
    row:SetHeight(ROW_HEIGHT)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -((row.index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, -((row.index - 1) * ROW_HEIGHT))
end

function List:CreateRow(index)
    local row = CreateFrame("Frame", nil, self.frame)
    row.index = index
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.selection = row:CreateTexture(nil, "BACKGROUND")
    row.selection:SetAllPoints()
    row.selection:SetColorTexture(COLORS.selection[1], COLORS.selection[2], COLORS.selection[3], COLORS.selection[4])
    row.selection:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.icon:Hide()

    row.texts = {}
    for columnIndex = 1, #self.columns do
        row.texts[columnIndex] = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    end

    row:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then
            return
        end
        local dataIndex = row.dataIndex
        if dataIndex then
            self.state:SetCursor(dataIndex)
            self:Refresh()
            if ns.UI and ns.UI.RefreshDetails then
                ns.UI:RefreshDetails()
            end
            if ns.UI and ns.UI.FocusKeys then
                ns.UI:FocusKeys()
            end
        end
    end)

    row:SetScript("OnEnter", function()
        local dataIndex = row.dataIndex
        local data = dataIndex and self.state.rows[dataIndex]
        if ns.UI then
            ns.UI.hoverUpgrade = data
            ns.UI.hoverUpgradeRow = row
        end
        if data and data.view == "upgrade" and data.itemLink and ns.UI and ns.UI.ShowUpgradeTooltip then
            ns.UI:ShowUpgradeTooltip(data, row)
        end
    end)

    row:SetScript("OnLeave", function()
        local dataIndex = row.dataIndex
        local data = dataIndex and self.state.rows[dataIndex]
        if ns.UI and ns.UI.hoverUpgrade == data then
            ns.UI.hoverUpgrade = nil
            ns.UI.hoverUpgradeRow = nil
        end
        local tooltip = rawget(_G, "GameTooltip")
        if tooltip then
            tooltip:Hide()
        end
    end)

    self:LayoutRow(row)
    self.rowFrames[index] = row
    return row
end

function List:EnsureRows(count)
    for index = #self.rowFrames + 1, math.min(count, MAX_ROWS) do
        self:CreateRow(index)
    end
end

function List:GetRowsVisible()
    local height = self.frame:GetHeight()
    return math.max(1, math.floor(height / ROW_HEIGHT))
end

function List:Refresh()
    local width = math.max(1, self:GetWidth())
    local height = math.max(1, self:GetHeight())

    if width ~= self.layoutWidth then
        self.layoutWidth = width
        for _, row in ipairs(self.rowFrames) do
            self:LayoutRow(row)
        end
    end

    local visible = math.max(1, math.floor(height / ROW_HEIGHT))
    self:EnsureRows(visible)

    self.state:EnsureVisible(visible, ns.db and ns.db.scrolloff or 3)
    local first = self.state.top
    local last = math.min(#self.state.rows, first + visible - 1)
    local visualFrom, visualTo = self.state:GetVisualRange()

    for index, row in ipairs(self.rowFrames) do
        local dataIndex = first + index - 1
        if dataIndex <= last then
            local data = self.state.rows[dataIndex]
            row.dataIndex = dataIndex
            row:Show()
            row.bg:SetColorTexture(COLORS.stripe[1], COLORS.stripe[2], COLORS.stripe[3], COLORS.stripe[4])
            if dataIndex % 2 == 0 then
                row.bg:SetColorTexture(0.10, 0.10, 0.11, 0.85)
            end

            local selected = dataIndex == self.state.cursor
            local inVisual = self.state.mode == "VISUAL" and dataIndex >= visualFrom and dataIndex <= visualTo
            if selected then
                row.selection:SetColorTexture(
                    COLORS.selection[1],
                    COLORS.selection[2],
                    COLORS.selection[3],
                    COLORS.selection[4]
                )
                row.selection:Show()
            elseif inVisual then
                row.selection:SetColorTexture(COLORS.visual[1], COLORS.visual[2], COLORS.visual[3], COLORS.visual[4])
                row.selection:Show()
            else
                row.selection:Hide()
            end

            local icon = ns.ItemIcon and ns.ItemIcon(data.itemID, data.itemLink, data.icon)
            if icon then
                row.icon:SetTexture(icon)
                row.icon:Show()
            else
                row.icon:Hide()
            end

            for columnIndex, column in ipairs(self.columns) do
                local text = row.texts[columnIndex]
                if text then
                    text:Show()
                    text:SetText(cellText(column.key, data, dataIndex))
                    local r, g, b = cellColor(column.key, data)
                    text:SetTextColor(r, g, b)
                end
            end
        else
            row.dataIndex = nil
            row:Hide()
        end
    end
end

function List:GetWidth()
    return self.frame:GetWidth()
end

function List:GetHeight()
    return self.frame:GetHeight()
end
