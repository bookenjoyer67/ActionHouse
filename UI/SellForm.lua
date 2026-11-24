local ADDON_NAME, ns = ...
local SellForm = {}
SellForm.__index = SellForm

ns.UI = ns.UI or {}
ns.UI.SellForm = SellForm

local FIELD_LINE_HEIGHT = 20
local MAX_FIELDS = 6

function SellForm:New(parent)
    local self = setmetatable({}, SellForm)
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetSize(620, 380)
    self.frame:SetPoint("CENTER", parent, "CENTER", 0, 20)
    self.frame:SetFrameLevel(parent:GetFrameLevel() + 50)
    self.frame:EnableMouse(true)
    self.frame:Hide()

    self.bg = self.frame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
    self.bg:SetColorTexture(0.03, 0.03, 0.035, 0.985)

    self.borderTop = self.frame:CreateTexture(nil, "BORDER")
    self.borderTop:SetPoint("TOPLEFT")
    self.borderTop:SetPoint("TOPRIGHT")
    self.borderTop:SetHeight(1)
    self.borderTop:SetColorTexture(0.55, 0.42, 0.12, 1)

    self.title = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    self.title:SetPoint("TOPLEFT", 16, -14)
    self.title:SetText("Post auction")
    self.title:SetTextColor(0.95, 0.82, 0.35)

    self.itemLine = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.itemLine:SetPoint("TOPLEFT", 16, -42)
    self.itemLine:SetPoint("TOPRIGHT", -16, -42)
    self.itemLine:SetJustifyH("LEFT")
    self.itemLine:SetWordWrap(false)

    self.fields = {}
    for index = 1, MAX_FIELDS do
        local line = self.frame:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
        line:SetPoint("TOPLEFT", 22, -70 - ((index - 1) * FIELD_LINE_HEIGHT))
        line:SetPoint("TOPRIGHT", -22, -70 - ((index - 1) * FIELD_LINE_HEIGHT))
        line:SetHeight(FIELD_LINE_HEIGHT)
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        self.fields[index] = line
    end

    self.summary = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.summary:SetPoint("TOPLEFT", 22, -70 - (MAX_FIELDS * FIELD_LINE_HEIGHT) - 4)
    self.summary:SetPoint("TOPRIGHT", -22, -70 - (MAX_FIELDS * FIELD_LINE_HEIGHT) - 4)
    self.summary:SetJustifyH("LEFT")

    self.footer = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.footer:SetPoint("BOTTOMLEFT", 16, 14)
    self.footer:SetText("j/k select   i/e edit   +/- adjust   Enter/p post   Esc back")
    self.footer:SetTextColor(0.55, 0.55, 0.55)

    return self
end

function SellForm:IsShown()
    return self.frame and self.frame:IsShown()
end

function SellForm:GetForm()
    return self.form
end

function SellForm:Show(form)
    if not form then
        return
    end
    self.form = form
    self:Render()
    self.frame:Show()
    if ns.UI then
        ns.UI.state.mode = "SELLFORM"
        ns.UI:UpdateStatus()
        ns.UI:FocusKeys()
    end
end

function SellForm:Hide()
    if not self.frame then
        return
    end
    self.frame:Hide()
    self.form = nil
    if ns.Sell then
        ns.Sell:CloseForm()
    end
    if ns.UI and ns.UI.state.mode == "SELLFORM" then
        ns.UI.state.mode = "NORMAL"
        ns.UI:UpdateStatus()
        ns.UI:FocusKeys()
    end
end

function SellForm:Render()
    local form = self.form
    if not form then
        return
    end

    self.itemLine:SetText(
        string.format(
            "%s   bag %s slot %s   %s available   %s",
            tostring(form.name or "?"),
            tostring(form.bag or "?"),
            tostring(form.slot or "?"),
            tostring(form.available or "?"),
            form.commodity and "commodity" or "item"
        )
    )

    for index = 1, MAX_FIELDS do
        local line = self.fields[index]
        local field = form.fields and form.fields[index]
        if field then
            local prefix = index == form.selected and "> " or "  "
            line:SetText(
                string.format("%s%-12s %s", prefix, ns.Sell:FieldLabel(field), ns.Sell:FieldDisplay(form, field))
            )
            if index == form.selected then
                line:SetTextColor(0.95, 0.82, 0.35)
            else
                line:SetTextColor(0.82, 0.82, 0.82)
            end
            line:Show()
        else
            line:Hide()
        end
    end

    local deposit = ns.Sell:GetDeposit(form)
    local total = ns.Sell:GetTotal(form)
    local priceLabel = ns.Sell.GetPriceLabel and ns.Sell:GetPriceLabel(form) or "none"
    self.summary:SetText(
        string.format(
            "Deposit: %s     Expected: %s     Price: %s",
            deposit and ns.Money.Format(deposit) or "unknown",
            ns.Money.Format(total),
            priceLabel
        )
    )
end

function SellForm:Select(delta)
    local form = self.form
    if not form or not form.fields or #form.fields == 0 then
        return
    end
    form.selected = form.selected + (delta or 0)
    while form.selected < 1 do
        form.selected = form.selected + #form.fields
    end
    while form.selected > #form.fields do
        form.selected = form.selected - #form.fields
    end
    self:Render()
end

function SellForm:EditSelected()
    local form = self.form
    if not form then
        return
    end
    local field = form.fields and form.fields[form.selected]
    if not field then
        return
    end

    local label = field.label
    local initial
    if field.kind == "money" then
        initial = field.value > 0 and ns.Money.Format(field.value) or ""
    elseif field.kind == "duration" then
        initial = ns.Sell:FieldDisplay(form, field)
    else
        initial = tostring(field.value)
    end

    ns.UI.prompt:Open(label:sub(1, 3), initial, "sellfield", function(text)
        local ok, err = ns.Sell:SetFieldFromText(form, field.key, text)
        if not ok then
            ns.UI:SetMessage(err or "Invalid value.", true)
        end
        self:Render()
    end)
end

function SellForm:Adjust(delta)
    local form = self.form
    if not form then
        return
    end
    local field = form.fields and form.fields[form.selected]
    if not field then
        return
    end
    local ok, err = ns.Sell:AdjustField(form, field.key, delta)
    if not ok and err then
        ns.UI:SetMessage(err, true)
    end
    self:Render()
end

function SellForm:Post()
    local form = self.form
    if not form then
        return
    end
    if ns.Sell:IsPriceQueryPending() and not form.priceTouched then
        ns.UI:SetMessage("Looking up the auction price; wait a moment.", true)
        return
    end
    local err = ns.Sell:Validate(form)
    if err then
        ns.UI:SetMessage(err, true)
        return
    end

    ns.Sell:PostForm(form)
    if self.form then
        self:Render()
    end
end

function SellForm:Key(token)
    if token == "Esc" or token == "q" or token == "Backspace" then
        self:Hide()
    elseif token == "j" or token == "Down" or token == "Tab" then
        self:Select(1)
    elseif token == "k" or token == "Up" or token == "S-Tab" then
        self:Select(-1)
    elseif token == "i" or token == "e" then
        self:EditSelected()
    elseif token == "+" or token == "=" then
        self:Adjust(1)
    elseif token == "-" then
        self:Adjust(-1)
    elseif token == "Enter" or token == "p" or token == "P" then
        self:Post()
    elseif token == "?" then
        ns.UI:ShowHelp()
    elseif token == ":" then
        ns.UI:OpenCommand()
    elseif token == "Q" then
        ns.UI:CloseAH()
    end
    return true
end
