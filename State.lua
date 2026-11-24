local ADDON_NAME, ns = ...
local State = {}
State.__index = State

ns.State = State

State.TABS = { "buy", "sell", "owned", "bids" }
State.TAB_LABELS = {
    buy = "Buy",
    sell = "Sell",
    owned = "Owned",
    bids = "Bids",
}

local function clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

local function lower(value)
    return tostring(value or ""):lower()
end

---@return table
function State.New()
    local self = setmetatable({}, State)
    self.mode = "NORMAL"
    self.tab = "buy"
    self.rawRows = {}
    self.rows = {}
    self.cursor = 1
    self.top = 1
    self.rowsVisible = 20
    self.scrolloff = 3
    self.count = ""
    self.pending = ""
    self.visualAnchor = nil
    self.search = ""
    self.filter = ""
    self.sort = { field = "price", asc = true }
    self.demo = false
    self.live = false
    self.keytest = false
    self.paused = false
    self.lastAction = nil
    return self
end

function State:TabIndex()
    for index, tab in ipairs(State.TABS) do
        if tab == self.tab then
            return index
        end
    end
    return 1
end

function State:SetTab(tab)
    if not State.TAB_LABELS[tab] then
        return false
    end
    self.tab = tab
    self.cursor = 1
    self.top = 1
    self.visualAnchor = nil
    return true
end

function State:NextTab(delta)
    local index = self:TabIndex() + (delta or 1)
    while index > #State.TABS do
        index = index - #State.TABS
    end
    while index < 1 do
        index = index + #State.TABS
    end
    return self:SetTab(State.TABS[index])
end

local function freeTextMatches(row, needle)
    if needle == "" then
        return true
    end
    if lower(row.name):find(needle, 1, true) then
        return true
    end
    if lower(row.seller):find(needle, 1, true) then
        return true
    end
    return false
end

local function compareToken(row, token)
    local key, operator, value = token:match("^([%w_]+)([<>=~]+)(.+)$")
    if not key then
        return nil
    end

    local rowValue = row[key]
    if rowValue == nil then
        return false
    end

    local rowNumber = tonumber(rowValue)
    local valueNumber = tonumber(value)
    if rowNumber and valueNumber then
        if operator == "=" or operator == "==" then
            return rowNumber == valueNumber
        elseif operator == "~=" then
            return rowNumber ~= valueNumber
        elseif operator == ">" then
            return rowNumber > valueNumber
        elseif operator == ">=" then
            return rowNumber >= valueNumber
        elseif operator == "<" then
            return rowNumber < valueNumber
        elseif operator == "<=" then
            return rowNumber <= valueNumber
        end
        return false
    end

    local left = lower(rowValue)
    local right = lower(value)
    if operator == "=" or operator == "==" then
        return left == right
    elseif operator == "~=" then
        return left ~= right
    elseif operator == "~" then
        return left:find(right, 1, true) ~= nil
    end
    return false
end

local function matchesFilter(row, filter)
    if filter == "" then
        return true
    end

    for token in filter:gmatch("%S+") do
        local negated = token:sub(1, 1) == "-"
        if negated then
            token = token:sub(2)
        end

        local matched = compareToken(row, token)
        if matched == nil then
            matched = freeTextMatches(row, lower(token))
        end

        if negated then
            matched = not matched
        end

        if not matched then
            return false
        end
    end

    return true
end

function State:FilteredRows()
    local result = {}
    local needle = lower(self.search)
    for _, row in ipairs(self.rawRows) do
        if freeTextMatches(row, needle) and matchesFilter(row, lower(self.filter)) then
            result[#result + 1] = row
        end
    end
    return result
end

local function sortValue(row, field)
    if field == "price" then
        return row.bid or row.price or row.unitPrice or 0
    elseif field == "buyout" then
        return row.buyout or 0
    elseif field == "qty" then
        return row.qty or row.quantity or 0
    elseif field == "level" then
        return row.level or 0
    elseif field == "time" then
        return row.timeValue or row.timeSeconds or 0
    elseif field == "name" then
        return lower(row.name)
    elseif field == "status" then
        return lower(row.status)
    end
    return row[field]
end

function State:SortRows(rows)
    local field = self.sort.field or "price"
    local asc = self.sort.asc ~= false
    for index, row in ipairs(rows) do
        row._order = index
    end
    table.sort(rows, function(left, right)
        local a = sortValue(left, field)
        local b = sortValue(right, field)
        if a == nil and b ~= nil then
            return false
        elseif a ~= nil and b == nil then
            return true
        end
        if a == b then
            return (left._order or 0) < (right._order or 0)
        end
        if asc then
            return a < b
        end
        return a > b
    end)
    for _, row in ipairs(rows) do
        row._order = nil
    end
end

function State:ApplyView(resetCursor)
    if self.live then
        self.rows = self.rawRows or {}
        if resetCursor then
            self.cursor = 1
            self.top = 1
        end
        self:ClampCursor()
        self.visualAnchor = nil
        return
    end

    local rows = self:FilteredRows()
    self:SortRows(rows)
    self.rows = rows
    if resetCursor then
        self.cursor = 1
        self.top = 1
    end
    self:ClampCursor()
    self.visualAnchor = nil
end

function State:SetRows(rows, resetCursor)
    self.rawRows = rows or {}
    self:ApplyView(resetCursor)
end

function State:ClampCursor()
    local total = #self.rows
    if total == 0 then
        self.cursor = 1
        self.top = 1
        return
    end
    self.cursor = clamp(self.cursor, 1, total)
    self.top = clamp(self.top, 1, math.max(1, total - self.rowsVisible + 1))
end

function State:Move(delta)
    local total = #self.rows
    if total == 0 then
        self.cursor = 1
        return
    end
    self.cursor = clamp(self.cursor + (delta or 0), 1, total)
end

function State:SetCursor(index)
    if #self.rows == 0 then
        self.cursor = 1
        return
    end
    self.cursor = clamp(index or 1, 1, #self.rows)
end

function State:Home()
    self.cursor = 1
end

function State:End()
    self.cursor = math.max(1, #self.rows)
end

function State:Page(delta, rowsVisible)
    local visible = math.max(1, rowsVisible or self.rowsVisible)
    local amount = math.max(1, visible - 1) * (delta or 1)
    self:Move(amount)
end

function State:EnsureVisible(rowsVisible, scrolloff)
    self.rowsVisible = math.max(1, rowsVisible or self.rowsVisible)
    self.scrolloff = math.max(0, scrolloff or self.scrolloff)

    local total = #self.rows
    if total == 0 then
        self.cursor = 1
        self.top = 1
        return
    end

    self.cursor = clamp(self.cursor, 1, total)
    local visible = self.rowsVisible
    local offset = math.min(self.scrolloff, math.max(0, math.floor((visible - 1) / 2)))
    local maxTop = math.max(1, total - visible + 1)

    if self.cursor < self.top + offset then
        self.top = self.cursor - offset
    elseif self.cursor > self.top + visible - 1 - offset then
        self.top = self.cursor - visible + 1 + offset
    end

    self.top = clamp(self.top, 1, maxTop)
end

function State:GetVisible()
    local result = {}
    local last = math.min(#self.rows, self.top + self.rowsVisible - 1)
    for index = self.top, last do
        result[#result + 1] = self.rows[index]
    end
    return result
end

function State:GetSelected()
    return self.rows[self.cursor]
end

function State:GetRowCount()
    return #self.rows
end

function State:StartVisual()
    self.visualAnchor = self.visualAnchor or self.cursor
    self.mode = "VISUAL"
end

function State:StopVisual()
    self.visualAnchor = nil
    if self.mode == "VISUAL" then
        self.mode = "NORMAL"
    end
end

function State:SelectAllVisible()
    if #self.rows == 0 then
        return
    end
    self.visualAnchor = self.top
    self.cursor = math.min(#self.rows, self.top + self.rowsVisible - 1)
    self.mode = "VISUAL"
end

function State:GetVisualRange()
    if not self.visualAnchor then
        return self.cursor, self.cursor
    end
    return math.min(self.visualAnchor, self.cursor), math.max(self.visualAnchor, self.cursor)
end

function State:GetSelection()
    local from, to = self:GetVisualRange()
    local result = {}
    for index = from, to do
        if self.rows[index] then
            result[#result + 1] = self.rows[index]
        end
    end
    return result
end

function State:PushCount(digit)
    if #self.count >= 9 then
        return
    end
    self.count = self.count .. digit
end

function State:TakeCount()
    local count = tonumber(self.count)
    self.count = ""
    return count or 1
end

function State:ClearCount()
    self.count = ""
end

function State:ClearPending()
    self.pending = ""
end

function State:ClearTransient()
    self.count = ""
    self.pending = ""
end

function State:SetSearch(text)
    self.search = text or ""
    self:ApplyView(true)
end

function State:SetFilter(text)
    self.filter = text or ""
    self:ApplyView(true)
end

function State:SetSort(field, asc)
    self.sort.field = field or "price"
    self.sort.asc = asc ~= false
    self:ApplyView(false)
end
