local ADDON_NAME, ns = ...
local Prompt = {}
Prompt.__index = Prompt

ns.UI = ns.UI or {}
ns.UI.Prompt = Prompt

local MAX_HISTORY = 100

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
    self.edit:SetScript("OnTabPressed", function()
        self:Complete()
    end)
    self.edit:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            self:ResetCompletion()
        end
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
    return self
end

function Prompt:IsShown()
    return self.frame and self.frame:IsShown()
end

function Prompt:HasFocus()
    return self.edit and self.edit:HasFocus()
end

function Prompt:Open(prefix, initialText, historyKey, onSubmit, completion, selectAll)
    self.openSeq = (self.openSeq or 0) + 1
    local openSeq = self.openSeq

    self.prefix:SetText(prefix or ":")
    self.historyKey = historyKey or "cmd"
    self.onSubmit = onSubmit
    self.completion = completion
    self.selectAll = selectAll
    self.historyIndex = nil
    self:ResetCompletion()
    self.frame:Show()
    self.edit:SetText(initialText or "")
    self.edit:SetCursorPosition(#self.edit:GetText())
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
    self.historyIndex = nil
    if restoreFocus ~= false and ns.UI then
        ns.UI:FocusKeys()
    end
end

function Prompt:ResetCompletion()
    self.completionCandidates = nil
    self.completionIndex = 1
    self.completionBase = nil
end

function Prompt:AddHistory(text)
    text = trim(text)
    if text == "" then
        return
    end
    local history = historyTable(self.historyKey or "cmd")
    if history[#history] ~= text then
        history[#history + 1] = text
        if #history > MAX_HISTORY then
            table.remove(history, 1)
        end
    end
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
    local history = historyTable(self.historyKey or "cmd")
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
    self.edit:SetText(index == #history + 1 and "" or (history[index] or ""))
    self.edit:SetCursorPosition(#self.edit:GetText())
end

function Prompt:Complete()
    if not self.completion then
        return
    end

    local text = self.edit:GetText()

    if not self.completionCandidates then
        local candidates = self.completion(text) or {}
        if #candidates == 0 then
            return
        end
        self.completionCandidates = candidates
        self.completionIndex = 1
        self.completionBase = text
    else
        self.completionIndex = self.completionIndex + 1
        if self.completionIndex > #self.completionCandidates then
            self.completionIndex = 1
        end
    end

    local candidate = self.completionCandidates[self.completionIndex]
    if candidate then
        self.edit:SetText(candidate)
        self.edit:SetCursorPosition(#candidate)
    end
end
