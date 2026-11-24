local keyboardFocus = nil
local shiftDown = false
local autoPopulatePrice = true
local postItemNeedsConfirmation = false

local function newObject(kind, name)
    local obj = {
        __kind = kind,
        __name = name,
        __shown = true,
        __width = 1000,
        __height = 700,
        __text = "",
        __scripts = {},
        __events = {},
        __level = 10,
    }

    local methods = {
        GetName = function(self)
            return self.__name
        end,
        GetWidth = function(self)
            return self.__width
        end,
        GetHeight = function(self)
            return self.__height
        end,
        SetWidth = function(self, value)
            self.__width = value
        end,
        SetHeight = function(self, value)
            self.__height = value
        end,
        SetSize = function(self, width, height)
            self.__width = width
            self.__height = height
        end,
        Show = function(self)
            self.__shown = true
        end,
        Hide = function(self)
            self.__shown = false
        end,
        SetShown = function(self, shown)
            self.__shown = shown
        end,
        IsShown = function(self)
            return self.__shown
        end,
        IsVisible = function(self)
            return self.__shown
        end,
        SetScript = function(self, script, handler)
            self.__scripts[script] = handler
        end,
        GetScript = function(self, script)
            return self.__scripts[script]
        end,
        HookScript = function() end,
        RegisterEvent = function(self, event)
            self.__events[event] = true
        end,
        UnregisterEvent = function(self, event)
            self.__events[event] = nil
        end,
        CreateFontString = function()
            return newObject("FontString")
        end,
        CreateTexture = function()
            return newObject("Texture")
        end,
        CreateFrame = function()
            return newObject("Frame")
        end,
        GetFrameLevel = function(self)
            return self.__level
        end,
        SetFrameLevel = function(self, level)
            self.__level = level
        end,
        GetPoint = function()
            return "CENTER", nil, "CENTER", 0, 0
        end,
        GetSize = function(self)
            return self.__width, self.__height
        end,
        GetChildren = function()
            return {}
        end,
        GetParent = function()
            return UIParent
        end,
        GetObjectType = function(self)
            return self.__kind
        end,
        SetText = function(self, text)
            self.__text = tostring(text or "")
            self.__highlighted = false
        end,
        GetText = function(self)
            return self.__text
        end,
        SetCursorPosition = function(self, position)
            self.__cursor = position
        end,
        HighlightText = function(self)
            self.__highlighted = true
        end,
        SetFocus = function(self)
            keyboardFocus = self
        end,
        ClearFocus = function(self)
            if keyboardFocus == self then
                keyboardFocus = nil
            end
        end,
        HasFocus = function(self)
            return keyboardFocus == self
        end,
    }

    setmetatable(obj, {
        __index = function(self, key)
            local method = methods[key]
            if method then
                return method
            end
            return function()
                return self
            end
        end,
    })

    return obj
end

UIParent = newObject("Frame", "UIParent")

function CreateFrame(kind, name)
    return newObject(kind, name)
end

local pendingTimers = {}
local function flushTimers()
    local timers = pendingTimers
    pendingTimers = {}
    for _, callback in ipairs(timers) do
        callback()
    end
end

C_Timer = {
    After = function(_, callback)
        pendingTimers[#pendingTimers + 1] = callback
    end,
    NewTimer = function(_, callback)
        pendingTimers[#pendingTimers + 1] = callback
        return { Cancel = function() end }
    end,
}

function GetCurrentKeyBoardFocus()
    return keyboardFocus
end

function GetBuildInfo()
    return "1.60.1", "71037", "Nov 23 2026", 16001
end

function GetMoney()
    return 1234567
end

function time()
    return os.time()
end

function GetTime()
    return os.time()
end

function GetRealmName()
    return "TestRealm"
end

function UnitName()
    return "Tester"
end

function UnitGUID()
    return "Player-1"
end

function IsShiftKeyDown()
    return shiftDown
end

function IsControlKeyDown()
    return false
end

function IsAltKeyDown()
    return false
end

WOW_PROJECT_ID = 42
WOW_PROJECT_CAMELOT = 42
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {
    AddMessage = function() end,
}
ActionHouseDB = {}
ActionHouseCharDB = {}

Enum = {
    AuctionHouseSortOrder = {
        Price = 0,
        Name = 1,
        Buyout = 4,
        TimeRemaining = 5,
    },
    ItemCommodityStatus = {
        Commodity = 2,
        Item = 1,
        Unknown = 0,
    },
}

local browseResults = {
    {
        itemKey = { itemID = 2770, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 },
        minPrice = 1200,
        totalQuantity = 60,
        containsOwnerItem = false,
    },
    {
        itemKey = { itemID = 2771, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 },
        minPrice = 2000,
        totalQuantity = 10,
        containsOwnerItem = false,
    },
}

local commodityResults = {
    {
        auctionID = 101,
        quantity = 20,
        unitPrice = 1150,
        timeLeftSeconds = 3600,
        owners = { "Seller A" },
        containsOwnerItem = false,
    },
    {
        auctionID = 102,
        quantity = 40,
        unitPrice = 1200,
        timeLeftSeconds = 7200,
        owners = { "Seller B" },
        containsOwnerItem = false,
    },
}

local itemResults = {
    {
        auctionID = 201,
        itemKey = { itemID = 2771, itemLevel = 32, itemSuffix = 0, battlePetSpeciesID = 0 },
        itemLink = "item:2771",
        quantity = 1,
        bidAmount = 100000,
        buyoutAmount = 300000,
        timeLeft = 2,
        owners = { "Seller C" },
        containsOwnerItem = false,
    },
}

local ownedResults = {
    {
        auctionID = 301,
        itemKey = { itemID = 2770, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 },
        itemLink = "item:2770",
        quantity = 20,
        bidAmount = 1000,
        buyoutAmount = 2000,
        timeLeftSeconds = 3600,
        status = 0,
        bidder = nil,
    },
    {
        auctionID = 302,
        itemKey = { itemID = 2771, itemLevel = 32, itemSuffix = 0, battlePetSpeciesID = 0 },
        itemLink = "item:2771",
        quantity = 1,
        bidAmount = 100000,
        buyoutAmount = 300000,
        timeLeftSeconds = 0,
        status = 1,
        bidder = "Tester",
    },
}

local bidResults = {
    {
        auctionID = 401,
        itemKey = { itemID = 2771, itemLevel = 32, itemSuffix = 0, battlePetSpeciesID = 0 },
        itemLink = "item:2771",
        timeLeft = 1,
        minBid = 110000,
        bidAmount = 100000,
        buyoutAmount = 300000,
        bidder = "Player-1",
    },
    {
        auctionID = 402,
        itemKey = { itemID = 2770, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 },
        itemLink = "item:2770",
        timeLeft = 2,
        minBid = 1300,
        bidAmount = 1200,
        buyoutAmount = 2500,
        bidder = "OtherPlayer",
    },
}

local calls = {}

local function pendingPostFrame(commodity)
    return {
        CachePendingPost = function(_, location, duration, quantity, bid, buyout)
            calls.cachePendingPost = {
                commodity = commodity,
                location = location,
                duration = duration,
                quantity = quantity,
                bid = bid,
                buyout = buyout,
            }
        end,
    }
end

_G.AuctionHouseFrame = {
    CommoditiesSellFrame = pendingPostFrame(true),
    ItemSellFrame = pendingPostFrame(false),
}

C_AuctionHouse = {
    IsThrottledMessageSystemReady = function()
        return true
    end,
    SendBrowseQuery = function(query)
        calls.browse = query
    end,
    GetBrowseResults = function()
        return browseResults
    end,
    HasFullBrowseResults = function()
        return true
    end,
    RequestMoreBrowseResults = function()
        calls.moreBrowse = true
    end,
    GetItemKeyInfo = function(itemKey)
        return {
            itemID = itemKey.itemID,
            itemName = itemKey.itemID == 2770 and "Copper Ore" or "Test Item",
            isCommodity = itemKey.itemID == 2770,
        }
    end,
    SendSearchQuery = function(itemKey, sort, split)
        calls.search = { itemKey = itemKey, sort = sort, split = split }
    end,
    ShouldAutoPopulatePrice = function()
        return autoPopulatePrice
    end,
    MakeItemKey = function(itemID, itemLevel, itemSuffix, battlePetSpeciesID)
        return {
            itemID = itemID,
            itemLevel = itemLevel or 0,
            itemSuffix = itemSuffix or 0,
            battlePetSpeciesID = battlePetSpeciesID or 0,
        }
    end,
    GetItemKeyFromItem = function(location)
        return {
            itemID = location.itemID,
            itemLevel = location.itemID == 2771 and 32 or 0,
            itemSuffix = 0,
            battlePetSpeciesID = 0,
        }
    end,
    GetNumCommoditySearchResults = function()
        return #commodityResults
    end,
    GetCommoditySearchResultInfo = function(_, index)
        return commodityResults[index]
    end,
    GetCommoditySearchResultsQuantity = function()
        return 60
    end,
    HasFullCommoditySearchResults = function()
        return true
    end,
    RequestMoreCommoditySearchResults = function()
        calls.moreCommodity = true
    end,
    StartCommoditiesPurchase = function(itemID, quantity)
        calls.startPurchase = { itemID = itemID, quantity = quantity }
    end,
    ConfirmCommoditiesPurchase = function(itemID, quantity)
        calls.confirmPurchase = { itemID = itemID, quantity = quantity }
    end,
    CancelCommoditiesPurchase = function()
        calls.cancelPurchase = true
    end,
    PlaceBid = function(auctionID, amount)
        calls.placeBid = { auctionID = auctionID, amount = amount }
    end,
    GetNumOwnedAuctions = function()
        return 0
    end,
    GetNumBids = function()
        return 0
    end,
    HasFullItemSearchResults = function()
        return true
    end,
    GetNumItemSearchResults = function()
        return #itemResults
    end,
    GetItemSearchResultInfo = function(_, index)
        return itemResults[index]
    end,
    GetItemCommodityStatus = function(location)
        return location and location.itemID == 2770 and 2 or 1
    end,
    IsSellItemValid = function()
        return true
    end,
    GetAvailablePostCount = function()
        return 20
    end,
    CalculateItemDeposit = function()
        return 1000
    end,
    CalculateCommodityDeposit = function()
        return 500
    end,
    SupportsCopperValues = function()
        return true
    end,
    PostItem = function(location, duration, quantity, bid, buyout)
        calls.postItem = {
            location = location,
            duration = duration,
            quantity = quantity,
            bid = bid,
            buyout = buyout,
        }
        return postItemNeedsConfirmation
    end,
    ConfirmPostItem = function(location, duration, quantity, bid, buyout)
        calls.confirmPostItem = {
            location = location,
            duration = duration,
            quantity = quantity,
            bid = bid,
            buyout = buyout,
        }
    end,
    PostCommodity = function(location, duration, quantity, unitPrice)
        calls.postCommodity = {
            location = location,
            duration = duration,
            quantity = quantity,
            unitPrice = unitPrice,
        }
        return false
    end,
    QueryOwnedAuctions = function(sorts)
        calls.queryOwned = sorts
    end,
    GetNumOwnedAuctions = function()
        return #ownedResults
    end,
    GetOwnedAuctionInfo = function(index)
        return ownedResults[index]
    end,
    CanCancelAuction = function()
        return true
    end,
    GetCancelCost = function()
        return 500
    end,
    CancelAuction = function(auctionID)
        calls.cancelAuction = auctionID
    end,
    QueryBids = function(sorts)
        calls.queryBids = sorts
    end,
    GetBids = function()
        return bidResults
    end,
    GetNumBids = function()
        return #bidResults
    end,
    GetBidInfo = function(index)
        return bidResults[index]
    end,
    GetAuctionInfoByID = function(auctionID)
        return { quantity = auctionID == 401 and 1 or 20 }
    end,
}

C_Item = {
    GetItemInfo = function(itemID)
        if itemID == 2770 or itemID == 2771 then
            return (itemID == 2770 and "Copper Ore" or "Test Item"),
                nil,
                1,
                1,
                1,
                "Trade Goods",
                "Metal & Stone",
                20,
                "",
                nil,
                1
        end
        return nil
    end,
    GetItemInfoInstant = function(itemID)
        return itemID, "Trade Goods", "Metal & Stone", "", nil, 7, 7
    end,
    LockItem = function()
        return true
    end,
    UnlockItem = function()
        return true
    end,
    DoesItemExist = function()
        return true
    end,
    GetCurrentItemLevel = function(location)
        return location and location.itemID == 2771 and 32 or 0
    end,
    GetItemQuality = function(location)
        return location and location.itemID == 2771 and 3 or 1
    end,
}

ItemLocation = {
    CreateFromBagAndSlot = function(_, bag, slot)
        return {
            bag = bag,
            slot = slot,
            itemID = slot == 1 and 2770 or 2771,
            IsValid = function()
                return true
            end,
            GetBagAndSlot = function(self)
                return self.bag, self.slot
            end,
        }
    end,
}

C_Container = {
    GetContainerNumSlots = function(bag)
        if bag == 0 then
            return 2
        end
        return 0
    end,
    GetContainerItemInfo = function(bag, slot)
        if bag ~= 0 then
            return nil
        end
        if slot == 1 then
            return {
                itemID = 2770,
                stackCount = 20,
                quality = 1,
                hyperlink = "|cffffffff|Hitem:2770::::::::::|h[Copper Ore]|h|r",
                iconFileID = 1,
            }
        elseif slot == 2 then
            return {
                itemID = 2771,
                stackCount = 1,
                quality = 3,
                hyperlink = "|cff0070dd|Hitem:2771::::::::::|h[Test Item]|h|r",
                iconFileID = 2,
            }
        end
        return nil
    end,
}

local ns = {}
local files = {
    "Compat.lua",
    "Util/Money.lua",
    "Util/Keys.lua",
    "State.lua",
    "Demo.lua",
    "Auction.lua",
    "Sell.lua",
    "Manage.lua",
    "UI/List.lua",
    "UI/Prompt.lua",
    "UI/Help.lua",
    "UI/Confirm.lua",
    "UI/SellForm.lua",
    "UI/Frame.lua",
    "Keymap.lua",
    "Commands.lua",
    "Core.lua",
}

for _, path in ipairs(files) do
    local chunk, err = loadfile(path)
    assert(chunk, path .. ": " .. tostring(err))
    chunk("ActionHouse", ns)
end

ns.db = {
    autoShow = false,
    confirm = "always",
    scrolloff = 3,
    history = { cmd = {}, search = {} },
    ui = {},
}
ns.charDB = {}

local count = 0
local function check(name, condition, detail)
    if condition then
        count = count + 1
        return
    end
    error("FAIL " .. name .. (detail and (" - " .. tostring(detail)) or ""), 2)
end

ns.UI:Init()
check("frame created", ns.UI.frame ~= nil)
check("state created", ns.UI.state ~= nil)
ns.UI:ShowDemo("buy")
flushTimers()
check("demo shown", ns.UI:IsShown())
check("demo rows", ns.UI.state:GetRowCount() > 10, ns.UI.state:GetRowCount())
check("focus captured", keyboardFocus == ns.UI.catcher, tostring(keyboardFocus))
check("rows rendered", #ns.UI.list.rowFrames > 0, #ns.UI.list.rowFrames)

local catcher = ns.UI.catcher
local keyDown = catcher.__scripts.OnKeyDown
local enterPressed = catcher.__scripts.OnEnterPressed
local escapePressed = catcher.__scripts.OnEscapePressed
local tabPressed = catcher.__scripts.OnTabPressed

local startCursor = ns.UI.state.cursor
keyDown(catcher, "J")
check("catcher j moves", ns.UI.state.cursor == startCursor + 1, ns.UI.state.cursor)
shiftDown = true
keyDown(catcher, "G")
shiftDown = false
check("catcher G goes to end", ns.UI.state.cursor == ns.UI.state:GetRowCount())

local oldTab = ns.UI.state.tab
tabPressed(catcher)
check("catcher tab switches", ns.UI.state.tab ~= oldTab, ns.UI.state.tab)
ns.UI:SetTab("buy")

ns.UI.state:SetCursor(1)
ns.UI:Refresh()
enterPressed(catcher)
check("catcher enter opens confirm", ns.UI.confirm:IsShown())
check("confirm mode", ns.UI.state.mode == "CONFIRM", ns.UI.state.mode)
escapePressed(catcher)
check("catcher escape cancels", not ns.UI.confirm:IsShown())
check("confirm mode reset", ns.UI.state.mode == "NORMAL", ns.UI.state.mode)

shiftDown = true
keyDown(catcher, "B")
shiftDown = false
check("B confirm opened", ns.UI.confirm:IsShown())
keyDown(catcher, "Y")
check("B confirm closed", not ns.UI.confirm:IsShown())

ns.UI:OpenCommand()
check("prompt open", ns.UI:IsPromptOpen())
check("prompt starts empty", ns.UI.prompt.edit:GetText() == "", ns.UI.prompt.edit:GetText())
check("prompt focus deferred", not ns.UI.prompt.edit:HasFocus())
flushTimers()
check("prompt focused after defer", ns.UI.prompt.edit:HasFocus())
ns.UI.prompt.edit:SetText("demo sell")
ns.UI.prompt:Submit()
check("switched to sell", ns.UI.state.tab == "sell", ns.UI.state.tab)
check("prompt closed", not ns.UI:IsPromptOpen())
check("sell rows", ns.UI.state:GetRowCount() > 3, ns.UI.state:GetRowCount())

ns.UI:StartKeytest()
check("keytest on", ns.UI.state.keytest)
ns.Keymap:OnKey("j", "J")
check("keytest stays", ns.UI.state.keytest)
ns.Keymap:OnKey("Esc", "ESCAPE")
check("keytest off", not ns.UI.state.keytest)

ns.UI:OpenSearch()
ns.UI.prompt.edit:SetText("copper")
ns.UI.prompt:Submit()
check("search applied", ns.UI.state.search == "copper")
check("search filters", ns.UI.state:GetRowCount() > 0 and ns.UI.state:GetRowCount() < 10, ns.UI.state:GetRowCount())

ns.UI:OpenSearch()
check("search prompt reopens cleanly", ns.UI.prompt.edit:GetText() == "copper", ns.UI.prompt.edit:GetText())
ns.UI.prompt:Close()

ns.UI:Hide()
check("hidden", not ns.UI:IsShown())

ns.UI:Hide()
ns.db.autoShow = true
ns.UI:OnAuctionHouseShow()
check("auto-open live", ns.UI:IsShown() and not ns.UI.state.demo)
check("live tab", ns.UI.state.tab == "buy", ns.UI.state.tab)

ns.UI:SetSearch("copper")
check("browse query sent", calls.browse ~= nil)
ns.Auction:OnEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check("browse rows", ns.UI.state:GetRowCount() == 2, ns.UI.state:GetRowCount())
check("browse row view", ns.UI.state.rows[1].view == "browse", ns.UI.state.rows[1].view)
check("browse row name", ns.UI.state.rows[1].name == "Copper Ore", ns.UI.state.rows[1].name)

ns.UI.state:SetCursor(1)
ns.UI:Refresh()
ns.UI:PrimaryAction()
check("detail search sent", calls.search ~= nil)
ns.Auction:OnEvent("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
check("commodity rows", ns.UI.state:GetRowCount() == 2, ns.UI.state:GetRowCount())
check("commodity view", ns.UI.state.rows[1].view == "commodity", ns.UI.state.rows[1].view)
check("commodity qty", ns.UI.state.rows[1].qty == 20, ns.UI.state.rows[1].qty)

ns.UI.state:SetCursor(1)
ns.UI:Refresh()
ns.UI:PrimaryAction()
flushTimers()
check("qty prompt opened", ns.UI:IsPromptOpen())
check("qty prompt starts at 1", ns.UI.prompt.edit:GetText() == "1", ns.UI.prompt.edit:GetText())
check("qty prompt selects the 1", ns.UI.prompt.edit.__highlighted == true)
ns.UI.prompt.edit:SetText("")
ns.UI.prompt:Submit()
check("empty qty falls back to 1", calls.startPurchase ~= nil and calls.startPurchase.quantity == 1)
ns.Auction:CancelCommodityPurchase(true)

ns.UI:BuySelected(5)
check("purchase started", calls.startPurchase ~= nil and calls.startPurchase.quantity == 5)
ns.Auction:OnEvent("COMMODITY_PRICE_UPDATED", 1150, 5750)
check("quote confirm", ns.UI.confirm:IsShown())
ns.UI.confirm:Resolve(true)
check("purchase confirmed", calls.confirmPurchase ~= nil and calls.confirmPurchase.quantity == 5)

ns.UI:Back()
check("back to browse", ns.Auction.mode == "browse" and #ns.UI.state.rows == 2, ns.Auction.mode)
ns.UI.state:SetCursor(2)
ns.UI:Refresh()
ns.UI:PrimaryAction()
ns.Auction:OnEvent(
    "ITEM_SEARCH_RESULTS_UPDATED",
    { itemID = 2771, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
)
check("item rows", #ns.UI.state.rows == 1 and ns.UI.state.rows[1].view == "item", #ns.UI.state.rows)
ns.UI.state:SetCursor(1)
ns.UI:Refresh()
ns.Commands:Run("bid")
check("bid confirm", ns.UI.confirm:IsShown())
ns.UI.confirm:Resolve(true)
check("bid sent", calls.placeBid ~= nil and calls.placeBid.amount == 100000)

ns.UI:SetTab("sell")
check("sell tab", ns.UI.state.tab == "sell", ns.UI.state.tab)
check("sell rows", ns.UI.state:GetRowCount() == 2, ns.UI.state:GetRowCount())
check("sell row view", ns.UI.state.rows[1].view == "sell", ns.UI.state.rows[1].view)
ns.UI.state:SetCursor(1)
ns.UI:Refresh()
ns.UI:PrimaryAction("post")
check("sell form shown", ns.UI.sellForm:IsShown())
check("sell form mode", ns.UI.state.mode == "SELLFORM", ns.UI.state.mode)
local sellForm = ns.Sell:GetForm()
check("sell form item", sellForm ~= nil and sellForm.itemID == 2770)
check("auto price starts at vendor", sellForm and sellForm.priceSource == "vendor")
check(
    "vendor default is silver rounded",
    ns.Sell:GetField(sellForm, "unitPrice").value == 100,
    ns.Sell:GetField(sellForm, "unitPrice").value
)
check(
    "auto commodity query sent",
    calls.search and calls.search.itemKey and calls.search.itemKey.itemID == 2770,
    calls.search and calls.search.itemKey and calls.search.itemKey.itemID
)
check("sell price lookup blocks buy queries", not ns.Auction:CanQuery(true))
ns.Sell:OnEvent("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
check(
    "auto commodity undercuts lowest",
    ns.Sell:GetField(sellForm, "unitPrice").value == 1149,
    ns.Sell:GetField(sellForm, "unitPrice").value
)
ns.Sell:SetField(sellForm, "unitPrice", 1200)
ns.Sell:ApplyMarketPrice(sellForm, 500, nil, nil, false)
check(
    "manual price is not overwritten",
    ns.Sell:GetField(sellForm, "unitPrice").value == 1200,
    ns.Sell:GetField(sellForm, "unitPrice").value
)
ns.UI.sellForm:Key("i")
check("i opens field editor", ns.UI:IsPromptOpen())
ns.UI.prompt:Close()
ns.UI.sellForm:Key("e")
check("e opens field editor", ns.UI:IsPromptOpen())
ns.UI.prompt:Close()
ns.UI.sellForm:Key("Enter")
check("enter posts without confirmation", not ns.UI.confirm:IsShown() and calls.postCommodity ~= nil)
check("commodity post sent", calls.postCommodity ~= nil)
check(
    "commodity post duration",
    calls.postCommodity and calls.postCommodity.duration == 2,
    calls.postCommodity and calls.postCommodity.duration
)
check(
    "commodity post price",
    calls.postCommodity and calls.postCommodity.unitPrice == 1200,
    calls.postCommodity and calls.postCommodity.unitPrice
)
ns.Sell:OnEvent("AUCTION_HOUSE_AUCTION_CREATED")
check("sell form closed after post", not ns.UI.sellForm:IsShown())

ns.UI.state:SetCursor(1)
ns.UI:Refresh()
ns.UI:PrimaryAction("post")
local ownSellForm = ns.Sell:GetForm()
commodityResults[1].containsOwnerItem = true
ns.Sell:OnEvent("COMMODITY_SEARCH_RESULTS_UPDATED", 2770)
check(
    "own listing is not undercut",
    ownSellForm and ns.Sell:GetField(ownSellForm, "unitPrice").value == 1150,
    ownSellForm and ns.Sell:GetField(ownSellForm, "unitPrice").value
)
commodityResults[1].containsOwnerItem = false
ns.UI.sellForm:Hide()

ns.UI.state:SetCursor(2)
ns.UI:Refresh()
ns.UI:PrimaryAction("post")
local itemSellForm = ns.Sell:GetForm()
check("item sell form", itemSellForm ~= nil and itemSellForm.commodity == false)
ns.Sell:OnEvent("ITEM_SEARCH_RESULTS_UPDATED", itemResults[1].itemKey)
check("auto item bid", ns.Sell:GetField(itemSellForm, "bid").value == 100000)
check(
    "auto item buyout undercuts",
    ns.Sell:GetField(itemSellForm, "buyout").value == 299999,
    ns.Sell:GetField(itemSellForm, "buyout").value
)
ns.Sell:SetField(itemSellForm, "buyout", 300000)
postItemNeedsConfirmation = true
ns.UI.sellForm:Key("Enter")
postItemNeedsConfirmation = false
check("item post sent", calls.postItem ~= nil)
check("item post not confirmed by addon", calls.confirmPostItem == nil)
check("item post handed to confirmation frame", calls.cachePendingPost ~= nil)
check("item post no confirmation overlay", not ns.UI.confirm:IsShown())
check(
    "item post cache duration matches",
    calls.cachePendingPost and calls.postItem and calls.cachePendingPost.duration == calls.postItem.duration,
    calls.cachePendingPost and calls.cachePendingPost.duration
)
check(
    "item post cache quantity matches",
    calls.cachePendingPost and calls.postItem and calls.cachePendingPost.quantity == calls.postItem.quantity,
    calls.cachePendingPost and calls.cachePendingPost.quantity
)
check(
    "item post cache bid matches",
    calls.cachePendingPost and calls.postItem and calls.cachePendingPost.bid == calls.postItem.bid,
    calls.cachePendingPost and calls.cachePendingPost.bid
)
check(
    "item post cache buyout matches",
    calls.cachePendingPost and calls.postItem and calls.cachePendingPost.buyout == calls.postItem.buyout,
    calls.cachePendingPost and calls.cachePendingPost.buyout
)
check("item post duration", calls.postItem and calls.postItem.duration == 2, calls.postItem and calls.postItem.duration)
check("item post buyout", calls.postItem and calls.postItem.buyout == 300000, calls.postItem and calls.postItem.buyout)
check("item sell form waiting on client", ns.UI.sellForm:IsShown())
check(
    "item post confirm notify",
    type(ns.UI.messageText) == "string" and ns.UI.messageText:find("Confirm", 1, true) ~= nil,
    ns.UI.messageText
)
ns.Sell:OnEvent("AUCTION_HOUSE_AUCTION_CREATED")
check("item sell form closed", not ns.UI.sellForm:IsShown())

autoPopulatePrice = false
ns.UI.state:SetCursor(1)
ns.UI:Refresh()
ns.UI:PrimaryAction("post")
local offSellForm = ns.Sell:GetForm()
check("auto price off leaves price empty", offSellForm and ns.Sell:GetField(offSellForm, "unitPrice").value == 0)
check("auto price off has no query", offSellForm and offSellForm.priceQueryToken == nil)
ns.UI.sellForm:Hide()
autoPopulatePrice = true

ns.UI:SetTab("owned")
check("owned query sent", calls.queryOwned ~= nil)
ns.Manage:OnEvent("OWNED_AUCTIONS_UPDATED")
check("owned rows", ns.UI.state:GetRowCount() == 2, ns.UI.state:GetRowCount())
local activeOwned
for index, row in ipairs(ns.UI.state.rows) do
    if row.status == "active" then
        activeOwned = index
    end
end
check("owned active row", activeOwned ~= nil)
ns.UI.state:SetCursor(activeOwned or 1)
ns.UI:Refresh()
ns.UI:PrimaryAction("cancel")
check("owned cancel confirm", ns.UI.confirm:IsShown())
ns.UI.confirm:Resolve(true)
check("owned cancel sent", calls.cancelAuction == 301, calls.cancelAuction)
ns.Manage:OnEvent("AUCTION_CANCELED", 301)

ns.UI:SetTab("bids")
check("bids query sent", calls.queryBids ~= nil)
ns.Manage:OnEvent("BIDS_UPDATED")
check("bid rows", ns.UI.state:GetRowCount() == 2, ns.UI.state:GetRowCount())
local outbidIndex
for index, row in ipairs(ns.UI.state.rows) do
    if row.status == "outbid" then
        outbidIndex = index
    end
end
check("outbid row", outbidIndex ~= nil)
ns.UI.state:SetCursor(outbidIndex or 1)
ns.UI:Refresh()
ns.UI:PrimaryAction("bid")
check("bid raise confirm", ns.UI.confirm:IsShown())
ns.UI.confirm:Resolve(true)
check("bid raised", calls.placeBid ~= nil and calls.placeBid.amount == 1300, calls.placeBid and calls.placeBid.amount)

ns.UI:OnAuctionHouseClosed()
check("closed hides live", not ns.UI:IsShown())

ns.UI:ShowDemo("buy")
check("demo works after live", ns.UI:IsShown() and ns.UI.state.demo)
ns.Commands:Run("b")
check(":b hides ActionHouse", not ns.UI:IsShown())

local probeLines = ns.Compat:Probe(false)
check("probe lines", type(probeLines) == "table" and #probeLines > 10, type(probeLines))
check("probe saved", ns.db.probe ~= nil and ns.db.probe.lines ~= nil)

io.write("smoke_ui: ", count, " checks passed\n")
