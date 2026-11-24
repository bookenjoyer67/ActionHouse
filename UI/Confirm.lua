local ADDON_NAME, ns = ...
local Confirm = {}
Confirm.__index = Confirm

ns.UI = ns.UI or {}
ns.UI.Confirm = Confirm

function Confirm:New(parent)
    local self = setmetatable({}, Confirm)
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetSize(460, 130)
    self.frame:SetPoint("CENTER", parent, "CENTER", 0, 40)
    self.frame:SetFrameLevel(parent:GetFrameLevel() + 80)
    self.frame:EnableMouse(true)
    self.frame:Hide()

    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0.03, 0.03, 0.035, 0.98)

    self.borderTop = self.frame:CreateTexture(nil, "BORDER")
    self.borderTop:SetPoint("TOPLEFT")
    self.borderTop:SetPoint("TOPRIGHT")
    self.borderTop:SetHeight(1)
    self.borderTop:SetColorTexture(0.55, 0.42, 0.12, 1)

    self.title = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 16, -14)
    self.title:SetText("Confirm")

    self.text = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.text:SetPoint("TOPLEFT", 16, -44)
    self.text:SetPoint("TOPRIGHT", -16, -44)
    self.text:SetHeight(48)
    self.text:SetJustifyH("LEFT")
    self.text:SetJustifyV("TOP")
    self.text:SetWordWrap(true)

    self.hint = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", 16, 14)
    self.hint:SetText("|cff7cfc00y|r confirm    |cffff6060n / Esc|r cancel")
    return self
end

function Confirm:IsShown()
    return self.frame and self.frame:IsShown()
end

function Confirm:Open(text, onYes, onNo, returnMode)
    self.onYes = onYes
    self.onNo = onNo
    self.returnMode = returnMode or "NORMAL"
    self.text:SetText(text or "")
    self.frame:Show()
    if ns.UI then
        ns.UI.state.mode = "CONFIRM"
        ns.UI:UpdateStatus()
        ns.UI:FocusKeys()
    end
end

function Confirm:Close()
    if self.frame:IsShown() then
        self.frame:Hide()
    end
    self.onYes = nil
    self.onNo = nil
    local returnMode = self.returnMode or "NORMAL"
    self.returnMode = nil
    if ns.UI and ns.UI.state.mode == "CONFIRM" then
        ns.UI.state.mode = returnMode
        ns.UI:UpdateStatus()
        ns.UI:FocusKeys()
    end
end

function Confirm:Resolve(accepted)
    local callback = accepted and self.onYes or self.onNo
    local returnMode = self.returnMode or "NORMAL"
    self.frame:Hide()
    self.onYes = nil
    self.onNo = nil
    self.returnMode = nil
    if ns.UI and ns.UI.state.mode == "CONFIRM" then
        ns.UI.state.mode = returnMode
        ns.UI:UpdateStatus()
    end
    if callback then
        callback()
    end
    if ns.UI then
        ns.UI:FocusKeys()
    end
end

function Confirm:Key(token)
    if token == "y" or token == "Y" then
        self:Resolve(true)
    elseif token == "n" or token == "N" or token == "Esc" then
        self:Resolve(false)
    end
    return true
end
