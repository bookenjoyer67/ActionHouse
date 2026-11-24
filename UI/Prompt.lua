local ADDON_NAME, ns = ...
local Prompt = {}
Prompt.__index = Prompt

ns.UI = ns.UI or {}
ns.UI.Prompt = Prompt

local MAX_HISTORY = 100
local GHOST_COLOR = { 0.55, 0.55, 0.55 }
local GHOST_INSET = 2

local function trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function historyTable(key)
    if not ns.db then
        return {}
    end
    ns.db.history = ns.db.history or {}
    ns.db.history[key] = ns.db.history[key] or {}
    return ns.db.history[key]
end

local function shiftDown()
    local isShift = rawget(_G, "IsShiftKeyDown")
    if type(isShift) ~= "function" then
        return false
    end
    local ok, down = pcall(isShift)
    return ok and down and true or false
end

function Prompt.GetHistory(key)
    return historyTable(key or "cmd")
end

function Prompt.AppendHistory(key, text)
    text = trim(text)
    if text == "" then
        return
    end
    local history = historyTable(key or "cmd")
    if history[#history] ~= text then
        history[#history + 1] = text
        if #history > MAX_HISTORY then
            table.remove(history, 1)
        end
    end
end

function Prompt:New(parent)
    local self = setmetatable({}, Prompt)
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetHeight(26)
    self.frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 46)
    self.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 46)
    self.frame:SetFrameLevel(parent:GetFrameLevel() + 60)
    self.frame:Hide()

    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0.03, 0.03, 0.035, 0.97)

    self.borderTop = self.frame:CreateTexture(nil, "BORDER")
    self.borderTop:SetPoint("TOPLEFT")
    self.borderTop:SetPoint("TOPRIGHT")
    self.borderTop:SetHeight(1)
    self.borderTop:SetColorTexture(0.45, 0.36, 0.16, 1)

    self.prefix = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.prefix:SetPoint("LEFT", 8, 0)
    self.prefix:SetWidth(22)
    self.prefix:SetJustifyH("LEFT")
    self.prefix:SetTextColor(0.95, 0.82, 0.35)

    self.edit = CreateFrame("EditBox", nil, self.frame)
    self.edit:SetPoint("LEFT", self.prefix, "RIGHT", 2, 0)
    self.edit:SetPoint("RIGHT", self.frame, "RIGHT", -8, 0)
    self.edit:SetHeight(20)
    self.edit:SetAutoFocus(false)
    self.edit:SetMaxLetters(255)
    self.edit:SetFontObject(ChatFontNormal)
    self.edit:SetTextInsets(2, 2, 0, 0)
    self.edit:SetScript("OnEnterPressed", function()
        self:Submit()
    end)
    self.edit:SetScript("OnEscapePressed", function()
        self:Close()
    end)
    self.ghost = self.frame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    self.ghost:SetHeight(20)
    self.ghost:SetJustifyH("LEFT")
    self.ghost:SetWordWrap(false)
    self.ghost:SetTextColor(GHOST_COLOR[1], GHOST_COLOR[2], GHOST_COLOR[3])
    self.ghost:Hide()

    self.measure = self.frame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    self.measure:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -1000, 0)
    self.measure:SetAlpha(0)

    self.edit:SetScript("OnTabPressed", function()
        self:Complete(shiftDown() and -1 or 1)
    end)
    self.edit:SetScript("OnCursorChanged", function()
        self:RefreshSuggestion()
    end)
    self.edit:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            self:ResetCompletion()
            self.suggestStack = {}
        end
        self:RefreshSuggestion()
    end)
    self.edit:SetScript("OnKeyDown", function(_, key)
        if key == "UP" then
            self:History(-1)
        elseif key == "DOWN" then
            self:History(1)
        end
    end)
    self.edit:SetScript("OnEditFocusGained", function()
        if ns.UI then
            ns.UI:UpdateStatus()
        end
    end)
    self.edit:SetScript("OnEditFocusLost", function()
        if ns.UI then
            ns.UI:UpdateStatus()
        end
    end)

    self.historyIndex = nil
    self.suggest = false
    self.suggestStack = {}
    return self
end

function Prompt:IsShown()
    return self.frame and self.frame:IsShown()
end

function Prompt:HasFocus()
    return self.edit and self.edit:HasFocus()
end

function Prompt:Open(prefix, initialText, historyKey, onSubmit, completion, selectAll, suggest)
    self.openSeq = (self.openSeq or 0) + 1
    local openSeq = self.openSeq

    self.prefix:SetText(prefix or ":")
    self.historyKey = historyKey or "cmd"
    self.onSubmit = onSubmit
    self.completion = completion
    self.selectAll = selectAll
    self.suggest = suggest and true or false
    self.suggestStack = {}
    self.historyIndex = nil
    self:ResetCompletion()
    self:ClearSuggestion()
    self.frame:Show()
    self.edit:SetText(initialText or "")
    self.edit:SetCursorPosition(#self.edit:GetText())
    self:RefreshSuggestion()
    if ns.UI then
        ns.UI:UpdateStatus()
    end

    -- Focus after the opening keystroke has finished. Focusing inside the
    -- same OnKeyDown makes the key's OnChar land in this EditBox and inserts
    -- the ":" or "/" that opened the prompt.
    C_Timer.After(0.05, function()
        if self.openSeq ~= openSeq or not self.frame:IsShown() then
            return
        end
        self.edit:SetFocus()
        if self.selectAll then
            self.edit:HighlightText()
        else
            self.edit:SetCursorPosition(#self.edit:GetText())
        end
    end)
end

function Prompt:Close(restoreFocus)
    if self.frame:IsShown() then
        self.frame:Hide()
        self.edit:ClearFocus()
    end
    self.onSubmit = nil
    self.completion = nil
    self.selectAll = nil
    self.suggest = false
    self.suggestStack = {}
    self.historyIndex = nil
    self:ClearSuggestion()
    if restoreFocus ~= false and ns.UI then
        ns.UI:FocusKeys()
    end
end

function Prompt:ResetCompletion()
    self.completionCandidates = nil
    self.completionIndex = 1
    self.completionBase = nil
end

function Prompt:ClearSuggestion()
    self.suggestionCandidate = nil
    if self.ghost then
        self.ghost:Hide()
    end
end

function Prompt:SuggestionFor(text)
    if not self.completion then
        return nil
    end
    text = tostring(text or "")
    local candidates = self.completion(text) or {}
    local candidate = candidates[1]
    if type(candidate) ~= "string" or #candidate <= #text then
        return nil
    end
    if candidate:sub(1, #text):lower() ~= text:lower() then
        return nil
    end
    return candidate
end

function Prompt:RefreshSuggestion()
    if not self.ghost or not self.suggest or not self.frame:IsShown() then
        self:ClearSuggestion()
        return
    end

    local text = self.edit:GetText()
    local cursor = self.edit:GetCursorPosition()
    if cursor ~= #text then
        self:ClearSuggestion()
        return
    end

    local candidate = self:SuggestionFor(text)
    if not candidate then
        self:ClearSuggestion()
        return
    end

    local suffix = candidate:sub(#text + 1)
    if suffix == "" then
        self:ClearSuggestion()
        return
    end

    self.measure:SetText(text)
    local used = self.measure:GetStringWidth() or 0
    self.measure:SetText(suffix)
    local suffixWidth = self.measure:GetStringWidth() or 0
    local available = (self.edit:GetWidth() or 0) - (GHOST_INSET * 2)
    if used + suffixWidth > available then
        self:ClearSuggestion()
        return
    end

    self.suggestionCandidate = candidate
    self.ghost:SetText(suffix)
    self.ghost:ClearAllPoints()
    self.ghost:SetPoint("LEFT", self.edit, "LEFT", GHOST_INSET + used, 0)
    self.ghost:Show()
end

function Prompt:AcceptSuggestion()
    local candidate = self.suggestionCandidate
    if not candidate then
        return false
    end
    local text = self.edit:GetText()
    if candidate == text then
        return false
    end
    self.suggestStack[#self.suggestStack + 1] = text
    self.edit:SetText(candidate)
    self.edit:SetCursorPosition(#candidate)
    self:ResetCompletion()
    self:RefreshSuggestion()
    return true
end

function Prompt:UndoSuggestion()
    local stack = self.suggestStack
    if not stack or #stack == 0 then
        return false
    end
    local previous = stack[#stack]
    stack[#stack] = nil
    self.edit:SetText(previous)
    self.edit:SetCursorPosition(#previous)
    self:ResetCompletion()
    self:RefreshSuggestion()
    return true
end

function Prompt:AddHistory(text)
    Prompt.AppendHistory(self.historyKey or "cmd", text)
end

function Prompt:Submit()
    local text = self.edit:GetText()
    self:AddHistory(text)
    local callback = self.onSubmit
    self:Close(false)
    if callback then
        callback(text)
    end
    if ns.UI then
        ns.UI:FocusKeys()
    end
end

function Prompt:History(direction)
    local history = Prompt.GetHistory(self.historyKey or "cmd")
    if #history == 0 then
        return
    end

    local index = self.historyIndex or (#history + 1)
    index = index + direction
    if index < 1 then
        index = 1
    elseif index > #history + 1 then
        index = #history + 1
    end
    self.historyIndex = index
    self:ResetCompletion()
    self.suggestStack = {}
    self.edit:SetText(index == #history + 1 and "" or (history[index] or ""))
    self.edit:SetCursorPosition(#self.edit:GetText())
    self:RefreshSuggestion()
end

function Prompt:Complete(direction)
    if not self.completion then
        return
    end

    direction = direction or 1
    if self.suggest then
        if direction < 0 then
            self:UndoSuggestion()
        else
            self:AcceptSuggestion()
        end
        return
    end
    local text = self.edit:GetText()

    if not self.completionCandidates then
        local candidates = self.completion(text) or {}
        if #candidates == 0 then
            return
        end
        self.completionCandidates = candidates
        self.completionBase = text
        if direction < 0 then
            self.completionIndex = #candidates
        else
            self.completionIndex = 1
        end
    else
        self.completionIndex = self.completionIndex + direction
        if self.completionIndex > #self.completionCandidates then
            self.completionIndex = 1
        elseif self.completionIndex < 1 then
            self.completionIndex = #self.completionCandidates
        end
    end

    local candidate = self.completionCandidates[self.completionIndex]
    if candidate then
        self.edit:SetText(candidate)
        self.edit:SetCursorPosition(#candidate)
    end
end
