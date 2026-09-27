local _, KCF = ...

local _G = _G
local GetAuctionItemClasses = _G.GetAuctionItemClasses
local GetAuctionItemSubClasses = _G.GetAuctionItemSubClasses
local GetItemInfo = _G.GetItemInfo
local GetItemSpell = _G.GetItemSpell
local GetSpellInfo = _G.GetSpellInfo
local UnitLevel = _G.UnitLevel
local hooksecurefunc = _G.hooksecurefunc
local type = type
local tonumber = tonumber
local tostring = tostring
local pcall = pcall

local Classification = {}
KCF:RegisterModule("Classification", Classification)

local function values(...)
	return { ... }
end

function Classification:OnInitialize()
	self:BuildTaxonomy()
	KCF:RegisterEvent("ADDON_LOADED", self, "OnAddonLoaded")
end

function Classification:OnEnable()
	self:BuildTaxonomy()
	self:InstallAdiBagsListener()
end

function Classification:BuildTaxonomy()
	local classNames = values(GetAuctionItemClasses())
	local consumables = values(GetAuctionItemSubClasses(4))
	local tradeGoods = values(GetAuctionItemSubClasses(6))

	self.classNames = {
		weapon = classNames[1],
		armor = classNames[2],
		consumable = classNames[4],
		tradeGoods = classNames[6],
		quest = classNames[12],
	}
	self.subClassNames = {
		potion = consumables[2],
		scroll = consumables[5],
		foodAndDrink = consumables[6],
		cloth = tradeGoods[2],
		metalAndStone = tradeGoods[4],
		herb = tradeGoods[6],
	}
	self.foodSpell = GetSpellInfo(433)
	self.waterSpell = GetSpellInfo(430)
end

function Classification.GetItemData(_self, itemID)
	local name, link, quality, itemLevel, requiredLevel, itemType, itemSubType, maxStack, equipLocation, texture, sellPrice = GetItemInfo(itemID)
	if not name then return nil end
	return {
		itemID = itemID,
		name = name,
		link = link,
		quality = quality,
		itemLevel = itemLevel,
		requiredLevel = requiredLevel,
		itemType = itemType,
		itemSubType = itemSubType,
		maxStack = maxStack,
		equipLocation = equipLocation,
		texture = texture,
		sellPrice = sellPrice,
	}
end

function Classification:GetCategory(itemID, data)
	data = data or self:GetItemData(itemID)
	if not data then return nil end

	local classes = self.classNames or {}
	local subClasses = self.subClassNames or {}
	if data.itemType == classes.consumable then
		if data.itemSubType == subClasses.potion then
			return "potion"
		elseif data.itemSubType == subClasses.scroll then
			return "scroll"
		elseif data.itemSubType == subClasses.foodAndDrink then
			local spellName = GetItemSpell and GetItemSpell(itemID)
			if spellName and self.foodSpell and spellName == self.foodSpell then
				return "food"
			elseif spellName and self.waterSpell and spellName == self.waterSpell then
				return "water"
			end
			return "foodAndDrink"
		end
	elseif data.itemType == classes.tradeGoods then
		if data.itemSubType == subClasses.cloth or KCF.CLOTH_ITEM_IDS[itemID] then
			return "cloth"
		end
		return "tradeGoods"
	end
	return nil
end

function Classification:GetHighestUsableCategoryTier(category, candidateItemID, candidateData)
	local playerLevel = tonumber(UnitLevel("player")) or 0
	if playerLevel <= 0 then return nil end

	local highestTier
	local function consider(itemID, data)
		if not data or self:GetCategory(itemID, data) ~= category then return end
		local requiredLevel = tonumber(data.requiredLevel)
		if not requiredLevel or requiredLevel < 0 or requiredLevel > playerLevel then return end
		if not highestTier or requiredLevel > highestTier then
			highestTier = requiredLevel
		end
	end

	consider(candidateItemID, candidateData)
	KCF:ForEachBagSlot(function(_, _, itemID)
		consider(itemID, self:GetItemData(itemID))
	end)
	return highestTier
end

function Classification:ShouldProtectHighestUsableTier(category, itemID, data)
	local playerLevel = tonumber(UnitLevel("player")) or 0
	local requiredLevel = tonumber(data.requiredLevel)
	if playerLevel <= 0 or not requiredLevel or requiredLevel < 0 or requiredLevel > playerLevel then
		return true
	end

	local highestTier = self:GetHighestUsableCategoryTier(category, itemID, data)
	if not highestTier then return true end
	return requiredLevel >= highestTier
end

function Classification.GetAdiBagsAddon(_self)
	local adiBags = _G.AdiBags
	if adiBags and type(adiBags.IsJunk) == "function" then return adiBags end

	local libStub = _G.LibStub
	if not libStub then return nil end
	local ok, aceAddon = pcall(function()
		return libStub("AceAddon-3.0", true)
	end)
	if not ok or not aceAddon or type(aceAddon.GetAddon) ~= "function" then return nil end

	local found, registeredAddon = pcall(aceAddon.GetAddon, aceAddon, "AdiBags", true)
	if found and registeredAddon and type(registeredAddon.IsJunk) == "function" then
		return registeredAddon
	end
	return nil
end

function Classification.GetAdiBagsResult(self, itemID)
	if not KCF.db.adibags.treatJunkAsCrap then return false end
	local adiBags = self:GetAdiBagsAddon()
	if not adiBags then return false end
	local ok, result = pcall(adiBags.IsJunk, adiBags, itemID)
	return ok and result and true or false
end

function Classification:Classify(itemID, quantity)
	itemID = KCF:ParseItemID(itemID)
	if not itemID then return KCF.RESULT_UNKNOWN, "invalid-item" end

	local settings = KCF.db.classification
	if settings.alwaysKeep[itemID] then
		return KCF.RESULT_KEEP, "always-keep"
	elseif settings.alwaysCrap[itemID] then
		return KCF.RESULT_CRAP, "always-crap"
	end

	local data = self:GetItemData(itemID)
	if not data then
		return KCF.RESULT_UNKNOWN, "item-not-cached"
	end

	if settings.protectQuestItems and self.classNames and data.itemType == self.classNames.quest then
		return KCF.RESULT_KEEP, "quest-item"
	end

	if self:GetAdiBagsResult(itemID) then
		return KCF.RESULT_CRAP, "adibags-junk"
	end

	local category = self:GetCategory(itemID, data)
	local mode = category and settings.categories[category]
	if mode == "always_keep" then
		return KCF.RESULT_KEEP, "category-" .. category
	elseif mode == "always_crap" then
		local lowerTiersOnly = settings.lowerLevelOnly[category]
		if lowerTiersOnly and self:ShouldProtectHighestUsableTier(category, itemID, data) then
			return KCF.RESULT_KEEP, "category-" .. category .. "-highest-usable-tier"
		end
		return KCF.RESULT_CRAP, "category-" .. category
	end

	if data.quality ~= nil and settings.qualities[data.quality] then
		return KCF.RESULT_CRAP, "quality-" .. tostring(data.quality)
	end

	local value = settings.vendorValue
	local quality = tonumber(data.quality)
	local sellPrice = tonumber(data.sellPrice)
	if value.enabled and quality and sellPrice and quality <= value.maxQuality then
		local comparedValue = sellPrice
		if value.useStackValue then
			comparedValue = sellPrice * (tonumber(quantity) or 1)
		end
		if comparedValue <= (tonumber(value.copper) or 0) then
			return KCF.RESULT_CRAP, "vendor-value"
		end
	end

	return KCF.RESULT_KEEP, "default-keep"
end

function Classification.IsGloballyProtected(_self, itemID)
	return KCF.db.classification.alwaysKeep[KCF:ParseItemID(itemID)] and true or false
end

function Classification:IsDisenchantable(itemID)
	local data = self:GetItemData(itemID)
	if not data or not self.classNames then return false end
	local quality = tonumber(data.quality)
	return quality and quality >= 2 and quality <= 4
		and (data.itemType == self.classNames.weapon or data.itemType == self.classNames.armor)
end

function Classification:IsMillable(itemID)
	local data = self:GetItemData(itemID)
	return data and self.classNames and self.subClassNames
		and data.itemType == self.classNames.tradeGoods
		and data.itemSubType == self.subClassNames.herb
end

function Classification:IsProspectable(itemID)
	itemID = KCF:ParseItemID(itemID)
	local data = itemID and self:GetItemData(itemID)
	return data and self.classNames and self.subClassNames
		and KCF.PROSPECTABLE_ITEM_IDS[itemID]
		and data.itemType == self.classNames.tradeGoods
		and data.itemSubType == self.subClassNames.metalAndStone
		and true or false
end

function Classification:InstallAdiBagsListener()
	local adiBags = self:GetAdiBagsAddon()
	if self.adiBagsHooked or not adiBags or type(adiBags.SendMessage) ~= "function" or type(hooksecurefunc) ~= "function" then
		return
	end

	hooksecurefunc(adiBags, "SendMessage", function(_, message)
		if message == "AdiBags_FiltersChanged" or message == "AdiBags_OverrideFilter" then
			KCF:NotifyRulesChanged()
		end
	end)
	self.adiBagsHooked = true
end

function Classification:OnAddonLoaded(_, loadedAddon)
	if loadedAddon == "AdiBags" then
		self:InstallAdiBagsListener()
		KCF:NotifyRulesChanged()
	end
end

function KCF.Classify(_self, itemID, quantity)
	return Classification:Classify(itemID, quantity)
end

function KCF.GetItemCategory(_self, itemID)
	return Classification:GetCategory(itemID)
end
