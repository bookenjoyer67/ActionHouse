local ADDON_NAME, ns = ...
local Keys = {}

ns.Keys = Keys

local SPECIAL = {
    ESCAPE = "Esc",
    ESC = "Esc",
    ENTER = "Enter",
    RETURN = "Enter",
    TAB = "Tab",
    SPACE = "Space",
    BACKSPACE = "Backspace",
    DELETE = "Delete",
    INSERT = "Insert",
    PAGEUP = "PageUp",
    PAGEDOWN = "PageDown",
    HOME = "Home",
    END = "End",
    UP = "Up",
    DOWN = "Down",
    LEFT = "Left",
    RIGHT = "Right",
}

local NAMED_PUNCTUATION = {
    SEMICOLON = ";",
    SLASH = "/",
    PERIOD = ".",
    COMMA = ",",
    MINUS = "-",
    EQUALS = "=",
    LBRACKET = "[",
    RBRACKET = "]",
    BACKSLASH = "\\",
    APOSTROPHE = "'",
    GRAVE = "`",
    TILDE = "`",
}

local SHIFTED_DIGITS = {
    ["1"] = "!",
    ["2"] = "@",
    ["3"] = "#",
    ["4"] = "$",
    ["5"] = "%",
    ["6"] = "^",
    ["7"] = "&",
    ["8"] = "*",
    ["9"] = "(",
    ["0"] = ")",
}

local SHIFTED_PUNCTUATION = {
    [";"] = ":",
    ["/"] = "?",
    ["."] = ">",
    [","] = "<",
    ["-"] = "_",
    ["="] = "+",
    ["["] = "{",
    ["]"] = "}",
    ["\\"] = "|",
    ["'"] = '"',
    ["`"] = "~",
}

local function addModifiers(base, shift, ctrl, alt, shiftIsCase)
    if ctrl then
        base = "C-" .. base
    end
    if alt then
        base = "A-" .. base
    end
    if shift and not shiftIsCase then
        base = "S-" .. base
    end
    return base
end

---Normalize a WoW key name plus modifier state into a stable token.
---@param key string
---@param shift boolean|nil
---@param ctrl boolean|nil
---@param alt boolean|nil
---@return string
function Keys.Normalize(key, shift, ctrl, alt)
    shift, ctrl, alt = not not shift, not not ctrl, not not alt
    if type(key) ~= "string" or key == "" then
        return ""
    end

    local upper = key:upper()

    if SPECIAL[upper] then
        return addModifiers(SPECIAL[upper], shift, ctrl, alt, false)
    end

    if NAMED_PUNCTUATION[upper] then
        local char = NAMED_PUNCTUATION[upper]
        if shift and SHIFTED_PUNCTUATION[char] then
            char = SHIFTED_PUNCTUATION[char]
            shift = false
        end
        return addModifiers(char, shift, ctrl, alt, true)
    end

    if #key == 1 then
        if key:match("%a") then
            local letter = shift and key:upper() or key:lower()
            return addModifiers(letter, false, ctrl, alt, true)
        end

        if key:match("%d") then
            local digit = key
            if shift and SHIFTED_DIGITS[digit] then
                digit = SHIFTED_DIGITS[digit]
                shift = false
            end
            return addModifiers(digit, false, ctrl, alt, true)
        end

        local char = key
        if shift and SHIFTED_PUNCTUATION[char] then
            char = SHIFTED_PUNCTUATION[char]
            shift = false
        end
        return addModifiers(char, shift, ctrl, alt, true)
    end

    return addModifiers(upper, shift, ctrl, alt, false)
end

---Build a token from a WoW OnKeyDown event using the current modifier state.
---@param key string
---@return string
function Keys.FromEvent(key)
    local shift = _G.IsShiftKeyDown and _G.IsShiftKeyDown() or false
    local ctrl = _G.IsControlKeyDown and _G.IsControlKeyDown() or false
    local alt = _G.IsAltKeyDown and _G.IsAltKeyDown() or false
    return Keys.Normalize(key, shift, ctrl, alt)
end

---Whether a token is a plain printable character useful for text-adjacent bindings.
---@param token string
---@return boolean
function Keys.IsPrintable(token)
    return type(token) == "string" and #token == 1
end
