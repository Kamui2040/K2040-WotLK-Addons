local root = assert(arg[1], "repository root argument is required")
local addonRoot = root .. "/addons/K2040_CrapFilter"

local function expect(actual, expected, label)
	if actual ~= expected then
		error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
	end
end

local function readFile(path)
	local handle = assert(io.open(path, "rb"))
	local contents = handle:read("*a")
	handle:close()
	return contents
end

local now = 100
local playerLevel = 26
local bags = {
	[0] = {
		{ itemID = 1001, count = 3 },
		{ itemID = 1003, count = 5 },
		{ itemID = 1004, count = 1 },
	},
}
local lootSlots = {}
local lootedSlots = {}
local soldSlots = {}
local cursorHolding = false
local inCombat = false
local cursorInfo
local clearCursorCount = 0
local knownSpells = {
	[13262] = true,
	[31252] = true,
	[51005] = true,
}

local itemData = {
	[1001] = { "Broken Tooth", "item:1001", 0, 1, 0, "Miscellaneous", "Junk", 20, "", "texture", 5 },
	[1002] = { "Protected Relic", "item:1002", 0, 1, 0, "Miscellaneous", "Junk", 20, "", "texture", 1 },
	[1003] = { "Test Herb", "item:1003", 1, 10, 1, "Trade Goods", "Herb", 20, "", "texture", 10 },
	[1004] = { "Test Sword", "item:1004", 2, 20, 15, "Weapon", "Sword", 1, "INVTYPE_WEAPON", "texture", 1000 },
	[1005] = { "Old Potion", "item:1005", 1, 5, 1, "Consumable", "Potion", 20, "", "texture", 25 },
	[1006] = { "Cheap Common", "item:1006", 1, 1, 0, "Miscellaneous", "Junk", 20, "", "texture", 3 },
	[1007] = { "Unsellable Scrap", "item:1007", 0, 1, 0, "Miscellaneous", "Junk", 20, "", "texture", 0 },
	[1008] = { "Locked Scrap", "item:1008", 0, 1, 0, "Miscellaneous", "Junk", 20, "", "texture", 5 },
	[1009] = { "Rare Crap Relic", "item:1009", 3, 40, 30, "Miscellaneous", "Other", 1, "", "texture", 100 },
	[1010] = { "Cheap Uncommon", "item:1010", 2, 10, 0, "Miscellaneous", "Other", 1, "", "texture", 1 },
	[2001] = { "Simple Food", "item:2001", 1, 15, 15, "Consumable", "Food & Drink", 20, "", "texture", 25 },
	[2002] = { "Current Food", "item:2002", 1, 25, 25, "Consumable", "Food & Drink", 20, "", "texture", 50 },
	[2003] = { "Future Food", "item:2003", 1, 30, 30, "Consumable", "Food & Drink", 20, "", "texture", 75 },
	[2101] = { "Simple Water", "item:2101", 1, 15, 15, "Consumable", "Food & Drink", 20, "", "texture", 25 },
	[2102] = { "Current Water", "item:2102", 1, 25, 25, "Consumable", "Food & Drink", 20, "", "texture", 50 },
	[2103] = { "Future Water", "item:2103", 1, 30, 30, "Consumable", "Food & Drink", 20, "", "texture", 75 },
	[2201] = { "Simple Feast", "item:2201", 1, 15, 15, "Consumable", "Food & Drink", 20, "", "texture", 25 },
	[2202] = { "Current Feast", "item:2202", 1, 25, 25, "Consumable", "Food & Drink", 20, "", "texture", 50 },
	[2203] = { "Future Feast", "item:2203", 1, 30, 30, "Consumable", "Food & Drink", 20, "", "texture", 75 },
	[2301] = { "Simple Potion", "item:2301", 1, 15, 15, "Consumable", "Potion", 20, "", "texture", 25 },
	[2302] = { "Current Potion", "item:2302", 1, 25, 25, "Consumable", "Potion", 20, "", "texture", 50 },
	[2303] = { "Future Potion", "item:2303", 1, 30, 30, "Consumable", "Potion", 20, "", "texture", 75 },
	[2304] = { "Exact-level Potion", "item:2304", 1, 26, 26, "Consumable", "Potion", 20, "", "texture", 60 },
	[2305] = { "Uncertain Potion", "item:2305", 1, 1, "unknown", "Consumable", "Potion", 20, "", "texture", 5 },
	[2401] = { "Simple Scroll", "item:2401", 1, 15, 15, "Consumable", "Scroll", 20, "", "texture", 25 },
	[2402] = { "Current Scroll", "item:2402", 1, 25, 25, "Consumable", "Scroll", 20, "", "texture", 50 },
	[2403] = { "Future Scroll", "item:2403", 1, 30, 30, "Consumable", "Scroll", 20, "", "texture", 75 },
	[2589] = { "Linen Cloth", "item:2589", 1, 5, 0, "Trade Goods", "Cloth", 20, "", "texture", 10 },
	[2592] = { "Wool Cloth", "item:2592", 1, 15, 0, "Trade Goods", "Cloth", 20, "", "texture", 20 },
	[2770] = { "Copper Ore", "item:2770", 1, 5, 0, "Trade Goods", "Metal & Stone", 20, "", "texture", 5 },
}

local frameMethods = {}
function frameMethods.RegisterEvent(_self) end
function frameMethods.SetScript(self, script, callback) self[script] = callback end
function frameMethods.GetScript(self, script) return self[script] end
function frameMethods.SetOwner(_self) end
function frameMethods.ClearLines(_self) end
function frameMethods.SetUnit(_self) end
function frameMethods.NumLines(_self) return 0 end
function frameMethods.Hide(_self) end

_G.CreateFrame = function()
	return setmetatable({}, { __index = frameMethods })
end
_G.GetTime = function() return now end
_G.GetContainerNumSlots = function(bag) return #(bags[bag] or {}) end
_G.GetContainerItemLink = function(bag, slot)
	local item = bags[bag] and bags[bag][slot]
	return item and ("item:" .. item.itemID) or nil
end
_G.GetContainerItemInfo = function(bag, slot)
	local item = bags[bag] and bags[bag][slot]
	if not item then return nil end
	return "texture", item.count, item.locked and true or false, 1, false, false, "item:" .. item.itemID
end
_G.GetContainerNumFreeSlots = function() return 0 end
_G.GetItemInfo = function(itemID)
	local data = itemData[tonumber(itemID)]
	if not data then return nil end
	return unpack(data)
end
_G.GetItemSpell = function(itemID)
	if itemID >= 2001 and itemID <= 2003 then return "Food" end
	if itemID >= 2101 and itemID <= 2103 then return "Drink" end
	return nil
end
_G.GetSpellInfo = function(spellID)
	local names = {
		[430] = "Drink",
		[433] = "Food",
		[2575] = "Mining",
		[2366] = "Herbalism",
		[4036] = "Engineering",
		[8613] = "Skinning",
		[13262] = "Disenchant",
		[31252] = "Prospecting",
		[51005] = "Milling",
	}
	return names[spellID]
end
_G.IsSpellKnown = function(spellID) return knownSpells[spellID] and true or false end
_G.GetAuctionItemClasses = function()
	return "Weapon", "Armor", "Container", "Consumable", "Glyph", "Trade Goods", "Projectile", "Quiver", "Recipe", "Gem", "Miscellaneous", "Quest"
end
_G.GetAuctionItemSubClasses = function(classIndex)
	if classIndex == 4 then
		return "Consumable", "Potion", "Elixir", "Flask", "Scroll", "Food & Drink", "Item Enhancement", "Bandage", "Other"
	elseif classIndex == 6 then
		return "Elemental", "Cloth", "Leather", "Metal & Stone", "Meat", "Herb", "Enchanting", "Jewelcrafting", "Parts", "Devices", "Explosives", "Materials", "Other"
	end
	return nil
end
_G.UnitLevel = function() return playerLevel end
_G.hooksecurefunc = function(target, method, hook)
	local original = assert(target[method], "hook target missing: " .. tostring(method))
	target[method] = function(self, ...)
		local results = { original(self, ...) }
		hook(self, ...)
		return unpack(results)
	end
end
_G.InCombatLockdown = function() return inCombat end
_G.GetNumPartyMembers = function() return 0 end
_G.GetNumRaidMembers = function() return 0 end
_G.GetNumSkillLines = function() return 0 end
_G.GetSkillLineInfo = function() return nil end
_G.UnitExists = function() return false end
_G.UnitIsDead = function() return false end
_G.GetLootSlotInfo = function(slot)
	local item = lootSlots[slot]
	if not item then return nil end
	return "texture", itemData[item.itemID] and itemData[item.itemID][1], item.count
end
_G.GetLootSlotLink = function(slot)
	local item = lootSlots[slot]
	return item and ("item:" .. item.itemID) or nil
end
_G.GetLootSlotType = function() return 1 end
_G.GetNumLootItems = function() return #lootSlots end
_G.LootSlot = function(slot) lootedSlots[#lootedSlots + 1] = slot end
_G.CursorHasItem = function() return cursorHolding end
_G.DeleteCursorItem = function() end
_G.PickupContainerItem = function() end
_G.SplitContainerItem = function() end
_G.ClearCursor = function()
	clearCursorCount = clearCursorCount + 1
	cursorInfo = nil
end
_G.GetCursorInfo = function()
	if not cursorInfo then return nil end
	return unpack(cursorInfo)
end
_G.UseContainerItem = function(bag, slot)
	soldSlots[#soldSlots + 1] = { bag = bag, slot = slot }
end
_G.UIParent = {}
local modifierState = { alt = false, ctrl = false, shift = false }
_G.IsAltKeyDown = function() return modifierState.alt end
_G.IsControlKeyDown = function() return modifierState.ctrl end
_G.IsShiftKeyDown = function() return modifierState.shift end
_G.GetMouseFocus = function() return nil end
_G.EnumerateFrames = function() return nil end

local namespace = {}
assert(loadfile(addonRoot .. "/Core.lua"))("K2040_CrapFilter", namespace)
assert(loadfile(addonRoot .. "/Classification.lua"))("K2040_CrapFilter", namespace)
assert(loadfile(addonRoot .. "/Professions.lua"))("K2040_CrapFilter", namespace)
assert(loadfile(addonRoot .. "/Loot.lua"))("K2040_CrapFilter", namespace)
assert(loadfile(addonRoot .. "/Merchant.lua"))("K2040_CrapFilter", namespace)
assert(loadfile(addonRoot .. "/QuickClassify.lua"))("K2040_CrapFilter", namespace)
assert(loadfile(addonRoot .. "/QuickLists.lua"))("K2040_CrapFilter", namespace)

_G.K2040CrapFilterDB = {
	unknownSentinel = "preserve",
	classification = {
		alwaysKeep = { [1002] = true },
	},
}
namespace:InitializeDatabase()
namespace.modules.Classification:BuildTaxonomy()

expect(namespace.db.unknownSentinel, "preserve", "unknown SavedVariables field")
expect(namespace.db.schemaVersion, 1, "schema version")
expect(namespace.db.destroy.enabled, false, "safe auto-destroy default")
expect(namespace.db.merchant.autoSellCrap, false, "safe auto-sell default")
expect(namespace.db.classification.lowerLevelOnly.scroll, false, "safe Scroll tier default")
expect(namespace.db.professions.prospecting.enabled, false, "safe Prospecting default")
expect(namespace.db.professions.autoLootResults, false, "safe profession result auto-loot default")
expect(namespace.db.minimap.hide, false, "visible minimap launcher default")
expect(namespace.db.ui.quickLists.width, 460, "compact quick-list width default")
expect(namespace.db.ui.quickLists.height, 330, "compact quick-list height default")
expect(#namespace.CLOTH_ITEMS, 7, "complete cloth loot choice set")
for _, cloth in ipairs(namespace.CLOTH_ITEMS) do
	expect(namespace.db.loot.cloth[cloth.itemID], false, "safe cloth auto-loot default " .. cloth.itemID)
end
expect(namespace:ParseItemID("|cff9d9d9d|Hitem:1001:0:0:0:0:0:0:0|h[Broken Tooth]|h|r"), 1001, "item link parsing")

expect(namespace:Classify(1002), namespace.RESULT_KEEP, "Always Keep precedence")
namespace.db.classification.alwaysCrap[1002] = true
expect(namespace:Classify(1002), namespace.RESULT_KEEP, "Always Keep wins over Always Crap")
expect(namespace:Classify(1001), namespace.RESULT_CRAP, "poor quality rule")
expect(namespace:Classify(9999), namespace.RESULT_UNKNOWN, "uncached item safety")

namespace.db.classification.qualities[0] = false
namespace.db.classification.vendorValue.enabled = true
namespace.db.classification.vendorValue.copper = 5
expect(namespace:Classify(1006), namespace.RESULT_CRAP, "vendor value rule")
expect(namespace:Classify(1010), namespace.RESULT_KEEP, "vendor quality limit protects Uncommon")
namespace.db.classification.qualities[2] = true
expect(namespace:Classify(1010), namespace.RESULT_CRAP, "direct quality rule ignores vendor quality limit")
namespace.db.classification.qualities[2] = false

namespace.db.classification.categories.potion = "always_crap"
namespace.db.classification.lowerLevelOnly.potion = true
local originalBagZero = bags[0]
local consumableTiers = {
	{ category = "food", lower = 2001, current = 2002, future = 2003 },
	{ category = "water", lower = 2101, current = 2102, future = 2103 },
	{ category = "foodAndDrink", lower = 2201, current = 2202, future = 2203 },
	{ category = "potion", lower = 2301, current = 2302, future = 2303 },
	{ category = "scroll", lower = 2401, current = 2402, future = 2403 },
}
for _, fixture in ipairs(consumableTiers) do
	namespace.db.classification.categories[fixture.category] = "always_crap"
	namespace.db.classification.lowerLevelOnly[fixture.category] = true
	bags[0] = {
		{ itemID = fixture.lower, count = 1 },
		{ itemID = fixture.current, count = 1 },
		{ itemID = fixture.future, count = 1 },
	}
	expect(namespace:Classify(fixture.lower), namespace.RESULT_CRAP, fixture.category .. " lower usable tier")
	expect(namespace:Classify(fixture.current), namespace.RESULT_KEEP, fixture.category .. " highest usable tier")
	expect(namespace:Classify(fixture.future), namespace.RESULT_KEEP, fixture.category .. " unusable future tier")
end

bags[0] = { { itemID = 2301, count = 1 } }
expect(namespace:Classify(2302), namespace.RESULT_KEEP, "incoming highest usable tier")
expect(namespace:Classify(2304), namespace.RESULT_KEEP, "exact-level tier")
expect(namespace:Classify(2305), namespace.RESULT_KEEP, "unprovable tier safety")

bags[0] = { { itemID = 2301, count = 1 }, { itemID = 2302, count = 1 } }
namespace.db.classification.qualities[1] = true
expect(namespace:Classify(2302), namespace.RESULT_KEEP, "highest usable tier blocks later quality rule")
namespace.db.classification.qualities[1] = false

namespace.db.classification.lowerLevelOnly.potion = false
expect(namespace:Classify(2302), namespace.RESULT_CRAP, "disabled tier protection preserves blanket category rule")
namespace.db.classification.lowerLevelOnly.potion = true
namespace.db.classification.categories.potion = "always_keep"
expect(namespace:Classify(2301), namespace.RESULT_KEEP, "category Always Keep ignores tier filter")
namespace.db.classification.categories.potion = "always_crap"

namespace.db.classification.alwaysCrap[2302] = true
expect(namespace:Classify(2302), namespace.RESULT_CRAP, "explicit Always Crap overrides tier protection")
namespace.db.classification.alwaysCrap[2302] = nil
bags[0] = originalBagZero

local adiBagsItemPrototype = {}
function adiBagsItemPrototype:OnAcquire(_container, bag, slot)
	self.bag = bag
	self.slot = slot
end
local registeredAdiBags = {
	IsJunk = function(_, itemID) return itemID == 1006 end,
	GetClass = function(_, className)
		expect(className, "ItemButton", "AdiBags item-button class lookup")
		return { prototype = adiBagsItemPrototype }
	end,
}
_G.AdiBags = nil
_G.LibStub = function(libraryName)
	expect(libraryName, "AceAddon-3.0", "AdiBags AceAddon library lookup")
	return {
		GetAddon = function(_, addonName)
			expect(addonName, "AdiBags", "AdiBags registry lookup")
			return registeredAdiBags
		end,
	}
end
namespace.db.adibags.treatJunkAsCrap = true
namespace.db.classification.vendorValue.enabled = false
expect(namespace:Classify(1006), namespace.RESULT_CRAP, "AdiBags AceAddon IsJunk integration")
expect(namespace:Classify(1002), namespace.RESULT_KEEP, "Always Keep wins over AdiBags")
_G.LibStub = nil
_G.AdiBags = registeredAdiBags
expect(namespace:Classify(1006), namespace.RESULT_CRAP, "AdiBags global fallback integration")

local professions = namespace.modules.Professions
local processButtonState = {}
local processButton = {
	text = {
		SetText = function(_, value) processButtonState.text = value end,
	},
}
function processButton:Disable() processButtonState.enabled = false end
function processButton:Enable() processButtonState.enabled = true end
function processButton:SetAttribute(name, value) processButtonState[name] = value end

namespace.db.professions.disenchant.enabled = false
namespace.db.professions.milling.enabled = false
namespace.db.professions.prospecting.enabled = false
local nextTarget, noTargetReason = professions:FindNextTarget()
expect(nextTarget, nil, "disabled profession queues have no target")
expect(noTargetReason, "Turn on at least one profession in settings.", "disabled profession action explanation")
professions:SetActionTarget(processButton, nil, noTargetReason)
expect(processButtonState.text, "No profession target ready", "disabled profession action state")
expect(processButtonState.enabled, false, "disabled profession action button")

namespace.db.professions.disenchant.enabled = true
knownSpells[13262] = false
nextTarget, noTargetReason = professions:FindNextTarget()
expect(nextTarget, nil, "unlearned profession has no target")
expect(noTargetReason, "This character has not learned an enabled profession.", "unlearned profession action explanation")

knownSpells[13262] = true
namespace.db.professions.disenchant.mode = "all"
namespace.db.classification.alwaysKeep[1004] = nil
nextTarget = professions:FindNextTarget()
expect(nextTarget.processor, "disenchant", "deterministic next profession target")
expect(nextTarget.itemID, 1004, "next profession target item")
professions:SetActionTarget(processButton, {
	bag = 0,
	slot = 3,
	itemID = 1004,
	link = "item:1004",
	processor = "disenchant",
	label = "Disenchant",
	spellName = "Disenchant",
})
expect(processButtonState.text, "Disenchant: Test Sword", "ready profession action state")
expect(processButtonState.enabled, true, "ready profession action button")
expect(processButtonState.macrotext, "/cast Disenchant\n/use 0 3", "ready profession action macro")

professions:OnActionPreClick(processButton)
expect(professions.pendingAction.itemID, 1004, "hardware click records prepared target")
professions:OnSpellcastSent("UNIT_SPELLCAST_SENT", "player", "Disenchant")
expect(professions.castInProgress.itemID, 1004, "matching sent event starts tracked profession cast")
expect(professions.pendingAction, nil, "sent event consumes pending action")
professions:OnSpellcastSucceeded("UNIT_SPELLCAST_SUCCEEDED", "player", "Disenchant")
expect(professions.castInProgress, nil, "successful profession cast clears active cast")
expect(professions.awaitingResult.itemID, 1004, "successful prepared cast awaits its result")
professions.awaitingResult = nil

local bagUpdateRequested = false
local originalRequestScan = professions.RequestScan
professions.RequestScan = function(receiver)
	expect(receiver, professions, "profession bag-update receiver")
	bagUpdateRequested = true
end
professions:OnBagUpdate()
expect(bagUpdateRequested, true, "profession bag-update scan request")
professions.RequestScan = originalRequestScan

namespace.db.professions.disenchant.enabled = true
namespace.db.professions.disenchant.mode = "all"
namespace.db.classification.alwaysKeep[1004] = true
expect(professions:ShouldProcess("disenchant", 1004, 1), false, "global keep blocks broad processing")
namespace.db.professions.disenchant.always[1004] = true
expect(professions:ShouldProcess("disenchant", 1004, 1), true, "profession Always override")
namespace.db.professions.disenchant.never[1004] = true
expect(professions:ShouldProcess("disenchant", 1004, 1), false, "profession Never precedence")

namespace.db.professions.milling.enabled = true
namespace.db.professions.milling.mode = "all"
expect(professions:ShouldProcess("milling", 1003, 4), false, "milling stack minimum")
expect(professions:ShouldProcess("milling", 1003, 5), true, "milling eligible stack")

namespace.db.professions.prospecting.enabled = true
namespace.db.professions.prospecting.mode = "all"
expect(professions:ShouldProcess("prospecting", 2770, 4), false, "prospecting stack minimum")
expect(professions:ShouldProcess("prospecting", 2770, 5), true, "prospecting eligible ore stack")
expect(professions:ShouldProcess("prospecting", 1003, 5), false, "prospecting rejects non-ore trade goods")

local loot = namespace.modules.Loot
expect(loot:GetSafeDestroyAmount(10, 13, 5), 3, "bounded net increase")
expect(loot:GetSafeDestroyAmount(10, 15, 5), 5, "bounded expected loot")
expect(loot:GetSafeDestroyAmount(10, 9, 5), 0, "no pre-existing deletion")

lootSlots = {
	{ itemID = 2589, count = 2 },
	{ itemID = 2592, count = 3 },
	{ itemID = 1001, count = 1 },
}
lootedSlots = {}
loot.session = nil
namespace.db.professions.autoLootResults = true
professions.awaitingResult = { processor = "disenchant", itemID = 1004, started = now - 2, autoLootUntil = now - 0.5 }
professions:OnLootOpened()
expect(#lootedSlots, 0, "expired profession result window remains manual")
professions.awaitingResult = { processor = "disenchant", itemID = 1004, started = now, autoLootUntil = now + 1.5 }
professions:OnLootOpened()
expect(#lootedSlots, 3, "prepared profession result auto-loot count")
loot:OnLootOpened()
expect(#lootedSlots, 3, "normal loot classifier ignores tracked profession results")
expect(loot.session, nil, "profession results are not attributed to auto-destroy")
professions:OnLootClosed()
expect(professions.awaitingResult, nil, "profession result close clears tracked result")
namespace.db.professions.autoLootResults = false

lootedSlots = {}
loot.session = nil
namespace.db.loot.cloth[2589] = true
namespace.db.loot.autoLootCrap = false
loot:OnLootOpened()
expect(#lootedSlots, 1, "selected cloth-only loot count")
expect(lootedSlots[1], 1, "selected Linen Cloth loot slot")
expect(loot.session.expected[2589], 2, "selected cloth attributed quantity")

lootedSlots = {}
loot.session = nil
namespace.db.classification.qualities[0] = true
namespace.db.loot.autoLootCrap = true
loot:OnLootOpened()
expect(#lootedSlots, 2, "selected cloth plus classified crap loot count")
expect(lootedSlots[1], 1, "selected cloth remains looted with auto-loot crap")
expect(lootedSlots[2], 3, "classified crap loot slot")

lootedSlots = {}
loot.session = nil
namespace.db.loot.cloth[2589] = false
namespace.db.loot.autoLootCrap = false
loot:OnLootOpened()
expect(#lootedSlots, 0, "disabled cloth and crap auto-loot")
lootSlots = {}
namespace.db.classification.qualities[0] = false

local counts = namespace:SnapshotBagCounts()
expect(counts[1001], 3, "bag snapshot quantity")
expect(counts[1003], 5, "bag snapshot second item")

local merchant = namespace.modules.Merchant
bags[0] = {
	{ itemID = 1001, count = 3 },
	{ itemID = 1002, count = 1 },
	{ itemID = 1003, count = 5 },
	{ itemID = 1007, count = 2 },
	{ itemID = 1008, count = 4, locked = true },
	{ itemID = 1009, count = 1 },
}
namespace.db.classification.qualities[0] = true
namespace.db.classification.alwaysCrap[1003] = true
namespace.db.classification.alwaysCrap[1009] = true
soldSlots = {}
expect(merchant:SellAllCrap(), 0, "disabled auto-sell")
expect(#soldSlots, 0, "disabled auto-sell uses no bag item")

namespace.db.merchant.autoSellCrap = true
expect(merchant:ShouldSell(1002, 1, false), false, "Always Keep blocks auto-sell")
expect(merchant:ShouldSell(1003, 5, false), false, "profession reservation blocks auto-sell")
expect(merchant:ShouldSell(1007, 2, false), false, "unsellable item blocks auto-sell")
expect(merchant:ShouldSell(1008, 4, true), false, "locked item blocks auto-sell")
local soldCount, soldValue = merchant:SellAllCrap()
expect(soldCount, 4, "auto-sell item count")
expect(soldValue, 115, "auto-sell vendor value")
expect(#soldSlots, 2, "only safe sell candidates used")
expect(soldSlots[1].bag, 0, "auto-sell candidate bag")
expect(soldSlots[1].slot, 1, "auto-sell candidate slot")
expect(soldSlots[2].slot, 6, "explicit high-quality crap is sellable")

soldSlots = {}
cursorHolding = true
expect(merchant:SellAllCrap(), 0, "held cursor blocks auto-sell")
expect(#soldSlots, 0, "held cursor prevents bag use")
cursorHolding = false
inCombat = true
expect(merchant:SellAllCrap(), 0, "combat blocks auto-sell")
expect(#soldSlots, 0, "combat prevents bag use")
inCombat = false

namespace.db.merchant.autoSellCrap = false
namespace.db.classification.alwaysCrap[1003] = nil
namespace.db.classification.alwaysCrap[1009] = nil
namespace.db.classification.qualities[0] = false
bags[0] = originalBagZero

local quick = namespace.modules.QuickClassify
namespace.db.quick.rightClickEnabled = true
namespace.db.quick.announce = false
namespace.db.quick.overlay = false
namespace.db.quick.crapModifier = "ALT"
namespace.db.quick.keepModifier = "CTRL-ALT"

local originalClickCount = 0
local bagButton = {
	itemID = 1003,
	scripts = {},
}
function bagButton.GetName(_self) return nil end
function bagButton:GetItemId() return self.itemID end
function bagButton:GetScript(script) return self.scripts[script] end
function bagButton:SetScript(script, callback) self.scripts[script] = callback end
bagButton:SetScript("OnClick", function() originalClickCount = originalClickCount + 1 end)

expect(quick:InstallAdiBagsHook(), true, "AdiBags acquisition hook installed")
expect(bagButton.__KCFWrappedHandler, nil, "unassigned pooled button is not wrapped")
adiBagsItemPrototype.OnAcquire(bagButton, nil, 0, 1)
local wrappedClick = bagButton:GetScript("OnClick")
expect(wrappedClick == bagButton.__KCFWrappedHandler, true, "AdiBags button wrapped on acquisition")

modifierState.alt = true
wrappedClick(bagButton, "RightButton")
expect(namespace.db.classification.alwaysCrap[1003], true, "Alt-right-click adds Always Crap")
expect(originalClickCount, 0, "consumed quick-classification click")

modifierState.ctrl = true
bagButton.itemID = 1005
wrappedClick(bagButton, "RightButton")
expect(namespace.db.classification.alwaysKeep[1005], true, "Ctrl-Alt-right-click adds Always Keep")
expect(namespace.db.classification.alwaysCrap[1005], nil, "Always Keep removes Always Crap")

modifierState.alt = false
modifierState.ctrl = false
wrappedClick(bagButton, "LeftButton")
expect(originalClickCount, 1, "ordinary bag click delegated")

local reacquiredClickCount = 0
local reacquiredOriginal = function() reacquiredClickCount = reacquiredClickCount + 1 end
bagButton:SetScript("OnClick", reacquiredOriginal)
adiBagsItemPrototype.OnAcquire(bagButton, nil, 0, 1)
expect(bagButton:GetScript("OnClick") == reacquiredOriginal, false, "pooled bag button rewrapped")
bagButton:GetScript("OnClick")(bagButton, "LeftButton")
expect(reacquiredClickCount, 1, "reacquired bag click delegated once")

local quickLists = namespace.modules.QuickLists
local layoutWidth, layoutHeight, sectionWidth, sectionHeight, visibleRows = quickLists:CalculateWindowLayout(100, 100)
expect(layoutWidth, 460, "quick-list minimum width")
expect(layoutHeight, 330, "quick-list minimum height")
expect(sectionWidth, 212, "quick-list compact pane width")
expect(sectionHeight, 262, "quick-list compact pane height")
expect(visibleRows, 8, "quick-list compact visible rows")
layoutWidth, layoutHeight, sectionWidth, sectionHeight, visibleRows = quickLists:CalculateWindowLayout(1000, 800)
expect(layoutWidth, 900, "quick-list maximum width")
expect(layoutHeight, 650, "quick-list maximum height")
expect(sectionWidth, 432, "quick-list expanded pane width")
expect(sectionHeight, 582, "quick-list expanded pane height")
expect(visibleRows, 24, "quick-list expanded visible rows")
cursorInfo = { "item", 1006, "item:1006" }
expect(quickLists:AddCursorRule(namespace.RESULT_CRAP), true, "dragged item adds Always Crap")
expect(namespace.db.classification.alwaysCrap[1006], true, "quick Crap list uses canonical rule")
expect(clearCursorCount, 1, "successful quick-list drop safely clears cursor")
cursorInfo = { "item", 1006, "item:1006" }
expect(quickLists:AddCursorRule(namespace.RESULT_KEEP), true, "dragged item adds Always Keep")
expect(namespace.db.classification.alwaysKeep[1006], true, "quick Keep list uses canonical rule")
expect(namespace.db.classification.alwaysCrap[1006], nil, "quick Keep replaces quick Crap")

local quickRefreshCount = 0
local originalQuickRefresh = quickLists.Refresh
quickLists.Refresh = function(receiver)
	expect(receiver, quickLists, "quick-list refresh receiver")
	quickRefreshCount = quickRefreshCount + 1
end
namespace:SetItemRule(1006, namespace.RESULT_CRAP)
expect(quickRefreshCount, 1, "canonical rule changes refresh compact lists")
quickLists.Refresh = originalQuickRefresh

local brokerName
local iconName
local brokerObject
local fakeBroker = {
	NewDataObject = function(_, name, data)
		brokerName = name
		brokerObject = data
		return data
	end,
}
local fakeIcon = {
	Register = function(_, name, data, settings)
		iconName = name
		expect(data, brokerObject, "LibDBIcon broker object")
		expect(settings, namespace.db.minimap, "LibDBIcon SavedVariables table")
	end,
}
_G.LibStub = {
	GetLibrary = function(_, name)
		if name == "LibDataBroker-1.1" then return fakeBroker end
		if name == "LibDBIcon-1.0" then return fakeIcon end
	end,
}
expect(quickLists:TryRegisterBroker(), true, "optional broker registration")
expect(brokerName, "K2040_CrapFilter", "LibDataBroker object name")
expect(iconName, "K2040_CrapFilter", "LibDBIcon registration name")
expect(quickLists.dbIconRegistered, true, "LibDBIcon registration state")
_G.LibStub = nil

local optionsSource = readFile(addonRoot .. "/Options.lua")
expect(namespace.displayName, "K2040 Loot & Salvage", "approved visible addon name")
expect(optionsSource:find("UIPanelScrollFrameTemplate", 1, true) ~= nil, true, "responsive options scroll canvas")
expect(optionsSource:find("content:SetWidth(max(320", 1, true) ~= nil, true, "minimum options content width")
expect(optionsSource:find('label:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, y)', 1, true) ~= nil, true, "responsive text right anchor")
expect(optionsSource:find("label:SetWordWrap(true)", 1, true) ~= nil, true, "responsive text wrapping")
expect(optionsSource:find("label:SetHeight(52)", 1, true) ~= nil, true, "multi-line text height")
local _, contentHeightCount = optionsSource:gsub("setPanelContentHeight%(panel,", "")
expect(contentHeightCount, 13, "content height declared across every settings panel builder")
expect(optionsSource:find(", 300, -", 1, true), nil, "no legacy x=300 right column")
expect(optionsSource:find(", 304, -", 1, true), nil, "no legacy x=304 right column")
expect(optionsSource:find(", 320, -", 1, true), nil, "no legacy x=320 right column")
expect(optionsSource:find("_RemoveSelected", 1, true) ~= nil, true, "dedicated list removal button")
expect(optionsSource:find("_Reset", 1, true) ~= nil, true, "dedicated list reset button")
expect(optionsSource:find("_Search", 1, true) ~= nil, true, "search field for every item list")
expect(optionsSource:find("BuildAlwaysKeepPanel", 1, true) ~= nil, true, "dedicated Always Keep page")
expect(optionsSource:find("BuildAlwaysCrapPanel", 1, true) ~= nil, true, "dedicated Always Crap page")
expect(optionsSource:find("BuildItemListsPanel", 1, true), nil, "no combined global item-list page")
expect(optionsSource:find('RegisterForClicks("LeftButtonUp")', 1, true) ~= nil, true, "left-click list selection")
expect(optionsSource:find("StaticPopup_Show(RESET_LIST_DIALOG", 1, true) ~= nil, true, "confirmed list reset")
expect(optionsSource:find("UIPanelCloseButton", 1, true), nil, "no per-row list removal buttons")
expect(optionsSource:find("Only classify lower usable tiers as crap", 1, true) ~= nil, true, "safe consumable tier wording")
expect(optionsSource:find("only affect items below your level", 1, true), nil, "ambiguous raw-level wording removed")
expect(optionsSource:find('self:AddCategoryMode(panel, "scroll", "Scrolls", 8, -178, true)', 1, true) ~= nil, true, "Scroll lower-tier option")
expect(optionsSource:find("Checked qualities are always marked Crap. Vendor value does not affect them.", 1, true) ~= nil, true, "quality rule explanation")
expect(optionsSource:find("Its value, stack, and quality settings apply only here.", 1, true) ~= nil, true, "vendor-value rule explanation")
expect(optionsSource:find("Classify low vendor-value items as crap", 1, true), nil, "ambiguous vendor-value wording removed")
expect(optionsSource:find("Automatically sell crap at merchants", 1, true) ~= nil, true, "merchant auto-sell option")
expect(optionsSource:find('createCheckBox(panel, "LootCloth_" .. itemID', 1, true) ~= nil, true, "cloth loot controls generated from canonical set")
expect(optionsSource:find('self:BuildProfessionPanel("prospecting", "Prospecting")', 1, true) ~= nil, true, "Prospecting settings page")
expect(optionsSource:find('local function createWideButton', 1, true) ~= nil, true, "responsive full-width settings action helper")
expect(optionsSource:find('button:SetPoint("RIGHT", parent, "RIGHT", -16, 0)', 1, true) ~= nil, true, "settings actions stop before the content edge")
expect(optionsSource:find('end, 280, -168, 150)', 1, true), nil, "no clipped fixed-position Rescan bags button")
expect(optionsSource:find('"ProfessionAutoLootResults"', 1, true) ~= nil, true, "profession result auto-loot option")
expect(optionsSource:find('loot the immediate item-only result window', 1, true) ~= nil, true, "profession result auto-loot safety wording")
expect(optionsSource:find('Safety boundary:', 1, true), nil, "technical safety heading removed from settings")
expect(optionsSource:find('Items already in your bags are never treated as newly looted.', 1, true) ~= nil, true, "plain inventory safety wording")

local quickListsSource = readFile(addonRoot .. "/QuickLists.lua")
expect(quickListsSource:find('NewDataObject', 1, true) ~= nil, true, "optional LibDataBroker launcher")
expect(quickListsSource:find('LibDBIcon-1.0', 1, true) ~= nil, true, "optional LibDBIcon registration")
expect(quickListsSource:find('K2040CrapFilter_MinimapButton', 1, true) ~= nil, true, "standalone collector-compatible minimap button")
expect(quickListsSource:find('Media\\\\MinimapIcon', 1, true) ~= nil, true, "project-owned launcher icon")
expect(quickListsSource:find('INV_Misc_Coin_01', 1, true), nil, "stock coin launcher removed")
expect(quickListsSource:find('MiniMap-TrackingBorder', 1, true) ~= nil, true, "standard circular launcher border")
expect(quickListsSource:find('UI-Minimap-Background', 1, true) ~= nil, true, "contrasting circular launcher background")
expect(quickListsSource:find('UI-Minimap-ZoomButton-Highlight', 1, true) ~= nil, true, "standard circular launcher highlight")
expect(quickListsSource:find('frame:SetResizable(true)', 1, true) ~= nil, true, "resizable quick-list window")
expect(quickListsSource:find('frame:StartSizing("BOTTOMRIGHT")', 1, true) ~= nil, true, "bottom-right resize handle")
expect(quickListsSource:find('OnSizeChanged', 1, true) ~= nil, true, "dynamic quick-list layout")
expect(quickListsSource:find('MAX_VISIBLE_ROWS = 24', 1, true) ~= nil, true, "responsive quick-list row capacity")
expect(quickListsSource:find('Drag an item anywhere in this pane', 1, true) ~= nil, true, "pane-wide drag-and-drop guidance")
expect(quickListsSource:find('section:SetScript("OnReceiveDrag", receiveItem)', 1, true) ~= nil, true, "pane-wide drag-and-drop target")
expect(quickListsSource:find('"_Drop"', 1, true), nil, "no button-shaped drag target")
expect(quickListsSource:find('GameFontNormalLarge', 1, true), nil, "compact standalone quick-list headings")
expect(quickListsSource:find('setCompactButtonFont(remove)', 1, true) ~= nil, true, "compact quick-list action buttons")
expect(quickListsSource:find('_Search', 1, true) ~= nil, true, "quick-list search fields")
expect(quickListsSource:find('_RemoveSelected', 1, true) ~= nil, true, "quick-list selected removal")
expect(quickListsSource:find('_Reset', 1, true) ~= nil, true, "quick-list reset controls")
expect(quickListsSource:find('KCF:SetItemRule(itemID, rule)', 1, true) ~= nil, true, "quick lists share canonical item rules")

local professionsSource = readFile(addonRoot .. "/Professions.lua")
expect(professionsSource:find('Profession Processing', 1, true) ~= nil, true, "plain profession processing title")
expect(professionsSource:find('K2040CrapFilter_ProcessAction', 1, true) ~= nil, true, "single secure profession action")
expect(professionsSource:find('The addon picks the next matching item.', 1, true) ~= nil, true, "automatic next-target explanation")
expect(professionsSource:find('UNIT_SPELLCAST_SENT', 1, true) ~= nil, true, "prepared action cast tracking")

local lootSource = readFile(addonRoot .. "/Loot.lua")
expect(lootSource:find('professions:IsProfessionResultPending()', 1, true) ~= nil, true, "profession results bypass normal loot and destruction attribution")

print("PASS K2040 Loot & Salvage deterministic Lua tests")
