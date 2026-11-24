local ADDON_NAME, ns = ...
local Keymap = {}

ns.Keymap = Keymap

local function message(text)
    ns.UI:SetMessage(text)
end

local function refresh()
    ns.UI:Refresh()
end

local function move_rows(state, delta)
    state:Move(delta)
end

local function handle_pending(token)
    local ui = ns.UI
    local state = ui.state
    local sequence = state.pending .. token
    state:ClearPending()
    local count = state:TakeCount()

    if sequence == "gg" then
        state:SetCursor(count > 1 and count or 1)
    elseif sequence == "gt" then
        local tabs = ui.GetTabs and ui:GetTabs() or ns.State.TABS
        if count > 1 and count <= #tabs then
            ui:SetTab(tabs[count])
        else
            ui:NextTab(1)
        end
        return true
    elseif sequence == "gT" then
        ui:NextTab(-1)
        return true
    elseif sequence == "g?" then
        ui:ShowHelp()
        return true
    elseif sequence == "gv" then
        state:StartVisual()
    else
        message("Unknown command sequence: " .. sequence)
    end

    refresh()
    return true
end

function Keymap:OnKey(token, raw)
    local ui = ns.UI
    local state = ui and ui.state
    if not state or not ui:IsShown() then
        return false
    end

    if state.keytest then
        return ui:KeytestKey(token, raw)
    end

    if state.paused then
        return false
    end

    if ui:IsPromptOpen() then
        return true
    end

    if state.mode == "CONFIRM" then
        return ui.confirm:Key(token)
    end

    if state.mode == "HELP" then
        return ui.help:Key(token)
    end

    if state.mode == "SELLFORM" then
        return ui.sellForm:Key(token)
    end

    if token == "" then
        return true
    end

    if token == "Esc" then
        state:ClearTransient()
        state:StopVisual()
        ui:SetMessage("")
        ui:UpdateStatus()
        refresh()
        return true
    end

    if state.pending ~= "" then
        return handle_pending(token)
    end

    if token:match("^%d$") then
        if token == "0" and state.count == "" then
            state:Home()
            refresh()
            return true
        end
        state:PushCount(token)
        ui:UpdateStatus()
        return true
    end

    if token == "g" then
        state.pending = "g"
        ui:UpdateStatus()
        return true
    end

    local count = state:TakeCount()
    local visible = ui:GetRowsVisible()

    if token == "j" or token == "Down" then
        move_rows(state, count)
        refresh()
        return true
    elseif token == "k" or token == "Up" then
        move_rows(state, -count)
        refresh()
        return true
    elseif token == "C-d" then
        state:Page(count > 1 and count or 1, math.max(1, math.floor(visible / 2)))
        refresh()
        return true
    elseif token == "C-u" then
        state:Page(-(count > 1 and count or 1), math.max(1, math.floor(visible / 2)))
        refresh()
        return true
    elseif token == "C-f" or token == "PageDown" or token == "Space" then
        state:Page(count, visible)
        refresh()
        return true
    elseif token == "C-b" or token == "PageUp" then
        state:Page(-count, visible)
        refresh()
        return true
    elseif token == "Home" then
        state:Home()
        refresh()
        return true
    elseif token == "End" then
        state:End()
        refresh()
        return true
    elseif token == "H" then
        state:SetCursor(state.top)
        refresh()
        return true
    elseif token == "M" then
        state:SetCursor(state.top + math.floor(visible / 2))
        refresh()
        return true
    elseif token == "L" then
        state:SetCursor(math.min(state:GetRowCount(), state.top + visible - 1))
        refresh()
        return true
    elseif token == "G" then
        if count > 1 then
            state:SetCursor(count)
        else
            state:End()
        end
        refresh()
        return true
    elseif token == "Tab" then
        ui:NextTab(1)
        return true
    elseif token == "S-Tab" then
        ui:NextTab(-1)
        return true
    elseif token == "h" then
        ui:NextTab(-1)
        return true
    elseif token == "l" then
        ui:NextTab(1)
        return true
    elseif token == ":" then
        ui:OpenCommand()
        return true
    elseif token == "/" then
        ui:OpenSearch()
        return true
    elseif token == "?" then
        ui:ShowHelp()
        return true
    elseif token == "*" or token == "#" then
        ui:SearchSelected()
        return true
    elseif token == "v" then
        if state.mode == "VISUAL" then
            state:StopVisual()
        else
            state:StartVisual()
        end
        refresh()
        return true
    elseif token == "V" then
        state:SelectAllVisible()
        refresh()
        return true
    elseif token == "n" or token == "N" then
        message("No separate match set. / filters the list; Esc clears pending keys.")
        ui:UpdateStatus()
        return true
    elseif token == "m" then
        ui:RequestMore()
        return true
    elseif token == "r" then
        ui:RefreshAll()
        return true
    elseif token == "R" then
        ui:RefreshAll()
        return true
    elseif token == "Backspace" or token == "-" then
        ui:Back()
        return true
    elseif token == "Enter" or token == "o" then
        if state.mode == "VISUAL" then
            message("Leave visual mode before buying or opening a row.")
            return true
        end
        ui:PrimaryAction()
        return true
    elseif token == "b" then
        if state.mode == "VISUAL" then
            message("Buying is single-target only. Esc leaves visual mode.")
            return true
        end
        if state.demo then
            ui:DemoAction("bid", count)
        else
            ui:PrimaryAction("bid", count)
        end
        return true
    elseif token == "B" then
        if state.mode == "VISUAL" then
            message("Buying is single-target only. Esc leaves visual mode.")
            return true
        end
        if state.demo then
            local row = state:GetSelected()
            if state.tab == "buy" and row and row.kind == "commodity" then
                ui:DemoAction("buy", count)
            else
                ui:DemoAction("buyout", count)
            end
        else
            ui:PrimaryAction("buyout", count)
        end
        return true
    elseif token == "p" then
        if state.demo then
            if state.mode == "VISUAL" then
                ui:DemoVisualAction("post")
            else
                ui:DemoAction("post", count)
            end
        else
            ui:PrimaryAction("post", count)
        end
        return true
    elseif token == "x" or token == "Delete" then
        if state.demo then
            if state.mode == "VISUAL" then
                ui:DemoVisualAction("cancel")
            else
                ui:DemoAction("cancel", count)
            end
        else
            ui:PrimaryAction("cancel", count)
        end
        return true
    elseif token == "." then
        ui:RepeatLast()
        return true
    elseif token == "q" then
        if state.mode == "VISUAL" then
            state:StopVisual()
            refresh()
        else
            ui:RequestClose()
        end
        return true
    elseif token == "Q" then
        ui:CloseAH()
        return true
    end

    if token:match("^%a$") or token:match("^%d$") or #token == 1 then
        message("Unknown key: " .. token .. "  (press ? for help)")
        ui:UpdateStatus()
    end
    return true
end
