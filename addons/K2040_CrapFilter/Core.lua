local addonName, KCF = ...

local _G = _G
local CreateFrame = _G.CreateFrame
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetItemInfo = _G.GetItemInfo
local GetTime = _G.GetTime
local tonumber = tonumber
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local tinsert = table.insert
local sort = table.sort

_G.K2040CrapFilter = KCF

KCF.name = addonName
KCF.displayName = "K2040 Loot & Salvage"
KCF.version = "0.1.0"
KCF.modules = {}
KCF.moduleOrder = {}
KCF.eventHandlers = {}
KCF.scheduled = {}

KCF.RESULT_KEEP = "keep"
KCF.RESULT_CRAP = "crap"
KCF.RESULT_UNKNOWN = "unknown"

KCF.CLOTH_ITEMS = {
	{ itemID = 2589, fallbackName = "Linen Cloth" },
	{ itemID = 2592, fallbackName = "Wool Cloth" },
	{ itemID = 4306, fallbackName = "Silk Cloth" },
	{ itemID = 4338, fallbackName = "Mageweave Cloth" },
	{ itemID = 14047, fallbackName = "Runecloth" },
	{ itemID = 21877, fallbackName = "Netherweave Cloth" },
	{ itemID = 33470, fallbackName = "Frostweave Cloth" },
}
KCF.CLOTH_ITEM_IDS = {}
for _, cloth in ipairs(KCF.CLOTH_ITEMS) do
	KCF.CLOTH_ITEM_IDS[cloth.itemID] = true
end

KCF.PROSPECTABLE_ITEM_IDS = {
	[2770] = true, -- Copper Ore
	[2771] = true, -- Tin Ore
	[2772] = true, -- Iron Ore
	[2775] = true, -- Silver Ore
	[2776] = true, -- Gold Ore
	[3858] = true, -- Mithril Ore
	[7911] = true, -- Truesilver Ore
	[10620] = true, -- Thorium Ore
	[23424] = true, -- Fel Iron Ore
	[23425] = true, -- Adamantite Ore
	[36909] = true, -- Cobalt Ore
	[36910] = true, -- Titanium Ore
	[36912] = true, -- Saronite Ore
}

KCF.defaults = {
	schemaVersion = 1,
	enabled = true,
	classification = {
		protectQuestItems = true,
		qualities = {
			[0] = true,
			[1] = false,
			[2] = false,
			[3] = false,
			[4] = false,
		},
		vendorValue = {
			enabled = false,
			copper = 0,
			useStackValue = false,
			maxQuality = 1,
		},
		categories = {
			food = "neutral",
			water = "neutral",
			foodAndDrink = "neutral",
			potion = "neutral",
			cloth = "neutral",
			scroll = "neutral",
			tradeGoods = "neutral",
		},
		lowerLevelOnly = {
			food = false,
			water = false,
			foodAndDrink = false,
			potion = false,
			scroll = false,
		},
		alwaysKeep = {},
		alwaysCrap = {},
	},
	loot = {
		autoLootCrap = false,
		cloth = {
			[2589] = false,
			[2592] = false,
			[4306] = false,
			[4338] = false,
			[14047] = false,
			[21877] = false,
			[33470] = false,
		},
		corpse = {
			skinnable = false,
			mineable = false,
			gatherable = false,
			engineerable = false,
			requireProfession = true,
		},
	},
	merchant = {
		autoSellCrap = false,
	},
	destroy = {
		enabled = false,
		freeSlotThreshold = 0,
		pauseTradeskills = true,
		doNotDestroyInGroup = true,
		doNotDestroyInRaid = true,
		maxQuality = 1,
		announce = true,
	},
	quick = {
		rightClickEnabled = true,
		crapModifier = "ALT",
		keepModifier = "CTRL-ALT",
		announce = true,
		overlay = true,
	},
	adibags = {
		treatJunkAsCrap = false,
	},
	professions = {
		autoLootResults = false,
		disenchant = {
			enabled = false,
			mode = "crap",
			always = {},
			never = {},
		},
		milling = {
			enabled = false,
			mode = "crap",
			always = {},
			never = {},
		},
		prospecting = {
			enabled = false,
			mode = "crap",
			always = {},
			never = {},
		},
	},
	ui = {
		processBarShown = false,
		quickLists = {
			point = "CENTER",
			relativePoint = "CENTER",
			x = 0,
			y = 0,
			width = 460,
			height = 330,
		},
	},
	minimap = {
		hide = false,
		angle = 220,
	},
}

local function copyDefaults(target, defaults)
	if type(target) ~= "table" then
		target = {}
	end

	for key, value in pairs(defaults) do
		if type(value) == "table" then
			target[key] = copyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end

	return target
end

KCF.CopyDefaults = copyDefaults

function KCF:InitializeDatabase()
	local database = _G.K2040CrapFilterDB
	if type(database) ~= "table" then
		database = {}
	end

	self.db = copyDefaults(database, self.defaults)
	self.db.schemaVersion = 1
	_G.K2040CrapFilterDB = self.db
end

function KCF.Print(_self, message)
	local frame = _G.DEFAULT_CHAT_FRAME
	if frame and frame.AddMessage then
		frame:AddMessage("|cffc5a35c" .. self.displayName .. ":|r " .. tostring(message))
	end
end

function KCF:RegisterModule(name, module)
	if not name or type(module) ~= "table" or self.modules[name] then
		return
	end
	self.modules[name] = module
	module.name = name
	module.addon = self
	tinsert(self.moduleOrder, name)
end

function KCF:RegisterEvent(event, owner, method)
	if type(event) ~= "string" or type(owner) ~= "table" then
		return
	end
	local handlers = self.eventHandlers[event]
	if not handlers then
		handlers = {}
		self.eventHandlers[event] = handlers
		self.eventFrame:RegisterEvent(event)
	end
	tinsert(handlers, { owner = owner, method = method })
end

function KCF:DispatchEvent(event, ...)
	local handlers = self.eventHandlers[event]
	if not handlers then return end

	for _, entry in ipairs(handlers) do
		local callback = entry.method
		if type(callback) == "string" then
			callback = entry.owner[callback]
		end
		if type(callback) == "function" then
			local ok, message = pcall(callback, entry.owner, event, ...)
			if not ok then
				self:Print("Stopped an event handler after an error: " .. tostring(message))
			end
		end
	end
end

function KCF:Schedule(key, delay, callback)
	if type(key) ~= "string" or type(callback) ~= "function" then return end
	self.scheduled[key] = {
		due = GetTime() + (tonumber(delay) or 0),
		callback = callback,
	}
	self.eventFrame:SetScript("OnUpdate", function(_, elapsed)
		self:RunScheduled(elapsed)
	end)
end

function KCF:CancelSchedule(key)
	self.scheduled[key] = nil
end

function KCF:RunScheduled()
	local now = GetTime()
	local ready = {}
	for key, entry in pairs(self.scheduled) do
		if entry.due <= now then
			ready[#ready + 1] = key
		end
	end

	for _, key in ipairs(ready) do
		local entry = self.scheduled[key]
		self.scheduled[key] = nil
		if entry then
			local ok, message = pcall(entry.callback)
			if not ok then
				self:Print("Stopped a scheduled action after an error: " .. tostring(message))
			end
		end
	end

	if not next(self.scheduled) then
		self.eventFrame:SetScript("OnUpdate", nil)
	end
end

function KCF.ParseItemID(_self, value)
	if type(value) == "number" then
		value = tonumber(value)
	elseif type(value) == "string" then
		value = tonumber(value:match("item:(%d+)") or value:match("^%s*(%d+)%s*$"))
	end

	if value and value > 0 and value == math.floor(value) then
		return value
	end
	return nil
end

function KCF.GetItemName(_self, itemID)
	local name = GetItemInfo(itemID)
	return name or ("Item " .. tostring(itemID))
end

function KCF:SetItemRule(itemID, rule)
	itemID = self:ParseItemID(itemID)
	if not itemID or not self.db then return false end

	local keep = self.db.classification.alwaysKeep
	local crap = self.db.classification.alwaysCrap
	if rule == self.RESULT_KEEP then
		keep[itemID] = true
		crap[itemID] = nil
	elseif rule == self.RESULT_CRAP then
		crap[itemID] = true
		keep[itemID] = nil
	else
		keep[itemID] = nil
		crap[itemID] = nil
	end

	self:NotifyRulesChanged(itemID)
	return true
end

function KCF:NotifyRulesChanged(itemID)
	local professions = self.modules.Professions
	if professions and professions.RequestScan then
		professions:RequestScan()
	end
	if self.RefreshOptions then
		self:RefreshOptions()
	end
	local quickLists = self.modules.QuickLists
	if quickLists and quickLists.Refresh then
		quickLists:Refresh()
	end
	if self.OnItemRuleChanged then
		self:OnItemRuleChanged(itemID)
	end
end

function KCF:GetSortedItemIDs(list)
	local ids = {}
	for itemID, enabled in pairs(list or {}) do
		itemID = self:ParseItemID(itemID)
		if itemID and enabled then
			ids[#ids + 1] = itemID
		end
	end
	sort(ids)
	return ids
end

function KCF:ForEachBagSlot(callback)
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local _, count, locked = GetContainerItemInfo(bag, slot)
				local itemID = self:ParseItemID(link)
				if itemID then
					callback(bag, slot, itemID, tonumber(count) or 1, locked, link)
				end
			end
		end
	end
end

function KCF:SnapshotBagCounts()
	local counts = {}
	self:ForEachBagSlot(function(_, _, itemID, count)
		counts[itemID] = (counts[itemID] or 0) + count
	end)
	return counts
end

function KCF:CountBagItem(itemID)
	local total = 0
	self:ForEachBagSlot(function(_, _, slotItemID, count)
		if slotItemID == itemID then
			total = total + count
		end
	end)
	return total
end

function KCF.GetFreeBagSlots(_self)
	local total = 0
	for bag = 0, 4 do
		local free = _G.GetContainerNumFreeSlots(bag)
		total = total + (tonumber(free) or 0)
	end
	return total
end

function KCF:InitializeModules()
	for _, name in ipairs(self.moduleOrder) do
		local module = self.modules[name]
		if module.OnInitialize then
			module:OnInitialize()
		end
	end
end

function KCF:EnableModules()
	for _, name in ipairs(self.moduleOrder) do
		local module = self.modules[name]
		if module.OnEnable then
			module:OnEnable()
		end
	end
end

KCF.eventFrame = CreateFrame("Frame", "K2040CrapFilter_EventFrame")
KCF.eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" and (...) == addonName then
		KCF:InitializeDatabase()
		KCF:InitializeModules()
	elseif event == "PLAYER_LOGIN" then
		KCF:EnableModules()
	end
	KCF:DispatchEvent(event, ...)
end)
KCF.eventFrame:RegisterEvent("ADDON_LOADED")
KCF.eventFrame:RegisterEvent("PLAYER_LOGIN")
