local ns = {}
local passed = 0
local failed = 0

local function loadModule(path)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    chunk("ActionHouse", ns)
end

local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        return
    end
    failed = failed + 1
    io.write("FAIL ", name, detail and (" - " .. tostring(detail)) or "", "\n")
end

local function eq(name, actual, expected)
    check(name, actual == expected, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

loadModule("Util/Money.lua")
loadModule("Util/Keys.lua")
loadModule("State.lua")
loadModule("Demo.lua")

local Money = ns.Money
local Keys = ns.Keys
local State = ns.State
local Demo = ns.Demo

eq("money parse 1g 2s 3c", Money.Parse("1g 2s 3c"), 10203)
eq("money parse 1.5g", Money.Parse("1.5g"), 15000)
eq("money parse 2g50s", Money.Parse("2g50s"), 25000)
eq("money parse 15000c", Money.Parse("15000c"), 15000)
eq("money parse bare", Money.Parse("15000"), 15000)
eq("money parse zero", Money.Parse("0"), 0)
eq("money parse invalid", Money.Parse("abc"), nil)
eq("money parse negative", Money.Parse("-1c"), nil)
eq("money format full", Money.Format(10203), "1g 2s 3c")
eq("money format zero", Money.Format(0), "0c")
eq("money format short gold", Money.FormatShort(10000), "1g")
eq("money format short mix", Money.FormatShort(10101), "1g 1s")
eq("money format short copper", Money.FormatShort(101), "1s 1c")

eq("quantity max", Money.ParseQuantity("max", 120), 120)
eq("quantity all", Money.ParseQuantity("all", 120), 120)
eq("quantity valid", Money.ParseQuantity("25", 120), 25)
eq("quantity too big", Money.ParseQuantity("121", 120), nil)
eq("quantity zero", Money.ParseQuantity("0", 120), nil)
eq("quantity invalid", Money.ParseQuantity("1.5", 120), nil)

eq("delta percent", Money.Delta(10000, "+10%"), 11000)
eq("delta copper", Money.Delta(10000, "-1c"), 9999)
eq("delta gold", Money.Delta(10000, "+5g"), 60000)
eq("delta absolute", Money.Delta(10000, "2g"), 20000)
eq("delta negative", Money.Delta(100, "-5g"), nil)

eq("key lower", Keys.Normalize("A", false, false, false), "a")
eq("key upper", Keys.Normalize("A", true, false, false), "A")
eq("key ctrl", Keys.Normalize("D", false, true, false), "C-d")
eq("key colon", Keys.Normalize("SEMICOLON", true, false, false), ":")
eq("key colon char", Keys.Normalize(";", true, false, false), ":")
eq("key slash", Keys.Normalize("SLASH", false, false, false), "/")
eq("key question", Keys.Normalize("/", true, false, false), "?")
eq("key escape", Keys.Normalize("ESCAPE", false, false, false), "Esc")
eq("key shift tab", Keys.Normalize("TAB", true, false, false), "S-Tab")
eq("key digit", Keys.Normalize("1", false, false, false), "1")
eq("key shifted digit", Keys.Normalize("8", true, false, false), "*")
eq("key shifted hash", Keys.Normalize("3", true, false, false), "#")
eq("key space", Keys.Normalize("SPACE", false, false, false), "Space")

local function fixtureRows(count)
    local rows = {}
    for index = 1, count do
        rows[index] = {
            name = string.format("Item %03d", index),
            quality = (index % 5),
            level = index,
            qty = index * 2,
            price = index * 100,
            buyout = index * 200,
            time = "12h",
            timeValue = index,
            kind = index % 2 == 0 and "commodity" or "item",
            status = "active",
            seller = "Seller " .. index,
        }
    end
    return rows
end

local state = State.New()
state:SetRows(fixtureRows(100), true)
eq("state count", state:GetRowCount(), 100)
eq("state cursor start", state.cursor, 1)
state:Move(5)
eq("state move", state.cursor, 6)
state:End()
eq("state end", state.cursor, 100)
state:Home()
eq("state home", state.cursor, 1)
state:SetCursor(50)
state:EnsureVisible(10, 2)
check(
    "state cursor visible",
    state.cursor >= state.top and state.cursor <= state.top + 9,
    state.cursor .. "/" .. state.top
)
state:Page(1, 10)
check("state page", state.cursor > 50, state.cursor)

state:SetCursor(1)
state:StartVisual()
state:SetCursor(7)
local from, to = state:GetVisualRange()
eq("visual from", from, 1)
eq("visual to", to, 7)
eq("visual selection", #state:GetSelection(), 7)

local sorted = State.New()
sorted.sort = { field = "name", asc = false }
sorted:SetRows(fixtureRows(3), true)
eq("sorted first", sorted.rows[1].name, "Item 003")
eq("sorted last", sorted.rows[3].name, "Item 001")

local filtered = State.New()
filtered.search = "item 02"
filtered:SetRows(fixtureRows(100), true)
eq("filtered count", filtered:GetRowCount(), 10)

local quality = State.New()
quality.filter = "quality=3"
quality:SetRows(fixtureRows(20), true)
eq("filter quality", quality:GetRowCount(), 4)

for _, tab in ipairs({ "buy", "sell", "owned", "bids" }) do
    local rows = Demo.GetRows(tab)
    check("demo " .. tab .. " rows", #rows > 0, #rows)
    check("demo " .. tab .. " fields", rows[1].name and rows[1].kind and rows[1].status, "missing fields")
end

local liveState = State.New()
liveState.live = true
liveState.search = "zzz"
liveState:SetRows(fixtureRows(5), true)
eq("live rows bypass filter", liveState:GetRowCount(), 5)
eq("live cursor", liveState.cursor, 1)

local counted = State.New()
counted:PushCount("1")
counted:PushCount("2")
eq("count take", counted:TakeCount(), 12)
eq("count reset", counted:TakeCount(), 1)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then
    os.exit(1)
end
