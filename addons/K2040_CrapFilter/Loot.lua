local _, KCF = ...

local _G = _G
local CreateFrame = _G.CreateFrame
local CursorHasItem = _G.CursorHasItem
local DeleteCursorItem = _G.DeleteCursorItem
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetLootSlotInfo = _G.GetLootSlotInfo
local GetLootSlotLink = _G.GetLootSlotLink
local GetLootSlotType = _G.GetLootSlotType
local GetNumLootItems = _G.GetNumLootItems
local GetNumPartyMembers = _G.GetNumPartyMembers
local GetNumRaidMembers = _G.GetNumRaidMembers
local GetNumSkillLines = _G.GetNumSkillLines
local GetSkillLineInfo = _G.GetSkillLineInfo
local GetSpellInfo = _G.GetSpellInfo
local InCombatLockdown = _G.InCombatLockdown
local LootSlot = _G.LootSlot
local PickupContainerItem = _G.PickupContainerItem
local SplitContainerItem = _G.SplitContainerItem
local UnitExists = _G.UnitExists
local UnitIsDead = _G.UnitIsDead
local UIParent = _G.UIParent
local ClearCursor = _G.ClearCursor
local tonumber = tonumber
local pairs = pairs

local Loot = {}
KCF:RegisterModule("Loot", Loot)

local PROFESSION_SPELL_IDS = {
	skinnable = 8613,
	mineable = 2575,
	gatherable = 2366,
	engineerable = 4036,
}

function Loot:OnInitialize()
	self.tradeSkillOpen = false
	self.scanTooltip = CreateFrame("GameTooltip", "K2040CrapFilter_CorpseScanner", UIParent, "GameTooltipTemplate")
	self.scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	KCF:RegisterEvent("LOOT_OPENED", self, "OnLootOpened")
	KCF:RegisterEvent("LOOT_CLOSED", self, "OnLootClosed")
	KCF:RegisterEvent("BAG_UPDATE", self, "OnBagUpdate")
	KCF:RegisterEvent("TRADE_SKILL_SHOW", self, "OnTradeSkillShow")
	KCF:RegisterEvent("TRADE_SKILL_CLOSE", self, "OnTradeSkillClose")
	KCF:RegisterEvent("CRAFT_SHOW", self, "OnTradeSkillShow")
	KCF:RegisterEvent("CRAFT_CLOSE", self, "OnTradeSkillClose")
end

function Loot.GetSafeDestroyAmount(_self, baseline, current, expected)
	baseline = tonumber(baseline) or 0
	current = tonumber(current) or 0
	expected = tonumber(expected) or 0
	local increase = current - baseline
	if increase <= 0 or expected <= 0 then return 0 end
	if increase < expected then return increase end
	return expected
end

function Loot.PlayerHasProfession(_self, kind)
	local professionName = GetSpellInfo(PROFESSION_SPELL_IDS[kind])
	if not professionName then return false end
	for index = 1, GetNumSkillLines() do
		local skillName, isHeader = GetSkillLineInfo(index)
		if not isHeader and skillName == professionName then
			return true
		end
	end
	return false
end

function Loot:GetCorpseCapabilities()
	local found = {}
	if not UnitExists("target") or not UnitIsDead("target") then return found end

	self.scanTooltip:ClearLines()
	self.scanTooltip:SetUnit("target")
	local skinText = _G.UNIT_SKINNABLE
	local professionNames = {
		mineable = GetSpellInfo(PROFESSION_SPELL_IDS.mineable),
		gatherable = GetSpellInfo(PROFESSION_SPELL_IDS.gatherable),
		engineerable = GetSpellInfo(PROFESSION_SPELL_IDS.engineerable),
	}
	for line = 1, self.scanTooltip:NumLines() do
		local fontString = _G["K2040CrapFilter_CorpseScannerTextLeft" .. line]
		local text = fontString and fontString:GetText()
		if text then
			if skinText and text:find(skinText, 1, true) then found.skinnable = true end
			for kind, professionName in pairs(professionNames) do
				if professionName and text:find(professionName, 1, true) then found[kind] = true end
			end
		end
	end
	self.scanTooltip:Hide()
	return found
end

function Loot:ShouldForceLootCorpse()
	local config = KCF.db.loot.corpse
	local found = self:GetCorpseCapabilities()
	for kind, enabled in pairs(config) do
		if kind ~= "requireProfession" and enabled and found[kind] then
			if not config.requireProfession or self:PlayerHasProfession(kind) then
				return true, kind
			end
		end
	end
	return false
end

function Loot.HasSelectedCloth(_self)
	for _, enabled in pairs(KCF.db.loot.cloth) do
		if enabled then return true end
	end
	return false
end

function Loot.ShouldLootItem(_self, itemID, quantity, forceAll)
	if forceAll or KCF.db.loot.cloth[itemID] then return true end
	if not KCF.db.loot.autoLootCrap then return false end
	return KCF:Classify(itemID, quantity) == KCF.RESULT_CRAP
end

function Loot:OnLootOpened()
	if not KCF.db.enabled then return end
	local professions = KCF.modules.Professions
	if professions and professions.IsProfessionResultPending and professions:IsProfessionResultPending() then
		return
	end
	local forceAll = self:ShouldForceLootCorpse()
	if not forceAll and not KCF.db.loot.autoLootCrap and not self:HasSelectedCloth() then return end

	local session = {
		baseline = KCF:SnapshotBagCounts(),
		expected = {},
		started = _G.GetTime(),
	}
	local itemSlotType = _G.LOOT_SLOT_ITEM or 1
	for slot = 1, GetNumLootItems() do
		if not GetLootSlotType or GetLootSlotType(slot) == itemSlotType then
			local link = GetLootSlotLink(slot)
			local itemID = KCF:ParseItemID(link)
			if itemID then
				local _, _, quantity = GetLootSlotInfo(slot)
				quantity = tonumber(quantity) or 1
				if self:ShouldLootItem(itemID, quantity, forceAll) then
					session.expected[itemID] = (session.expected[itemID] or 0) + quantity
					LootSlot(slot)
				end
			end
		end
	end

	if next(session.expected) then
		self.session = session
		KCF:Schedule("loot-session-expire", 12, function()
			if Loot.session == session then Loot.session = nil end
		end)
	end
end

function Loot:CanDestroyNow()
	local config = KCF.db.destroy
	if not config.enabled or not KCF.db.enabled then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	if config.pauseTradeskills and self.tradeSkillOpen then return false end
	if config.doNotDestroyInRaid and GetNumRaidMembers() > 0 then return false end
	if config.doNotDestroyInGroup and GetNumPartyMembers() > 0 then return false end
	return KCF:GetFreeBagSlots() <= (tonumber(config.freeSlotThreshold) or 0)
end

function Loot:FindDestroyCandidate()
	if not self.session or not self:CanDestroyNow() then return nil end
	local professions = KCF.modules.Professions
	for itemID, expected in pairs(self.session.expected) do
		local baseline = self.session.baseline[itemID] or 0
		local current = KCF:CountBagItem(itemID)
		local amount = self:GetSafeDestroyAmount(baseline, current, expected)
		if amount > 0 then
			local _, _, quality = _G.GetItemInfo(itemID)
			local result = KCF:Classify(itemID, amount)
			if result == KCF.RESULT_CRAP
				and tonumber(quality)
				and quality <= KCF.db.destroy.maxQuality
				and not professions:IsReserved(itemID) then
				for bag = 0, 4 do
					for slot = 1, GetContainerNumSlots(bag) do
						local link = GetContainerItemLink(bag, slot)
						if KCF:ParseItemID(link) == itemID then
							local _, count, locked = GetContainerItemInfo(bag, slot)
							if not locked then
								return bag, slot, itemID, math.min(amount, tonumber(count) or 1)
							end
						end
					end
				end
			end
		end
	end
	return nil
end

function Loot:DestroyNext()
	local bag, slot, itemID, amount = self:FindDestroyCandidate()
	if not bag then return end
	local _, count = GetContainerItemInfo(bag, slot)
	count = tonumber(count) or 1

	if CursorHasItem and CursorHasItem() then
		KCF:Print("Automatic cleanup paused because the cursor is holding an item.")
		return
	end

	if amount < count then
		SplitContainerItem(bag, slot, amount)
	else
		PickupContainerItem(bag, slot)
	end
	if not CursorHasItem or not CursorHasItem() then
		KCF:Print("Automatic cleanup could not pick up the newly looted items, so nothing was destroyed.")
		return
	end

	DeleteCursorItem()
	if CursorHasItem and CursorHasItem() then
		if ClearCursor then ClearCursor() end
		KCF:Print("Automatic cleanup stopped because the client requested confirmation.")
		return
	end

	self.session.expected[itemID] = math.max(0, self.session.expected[itemID] - amount)
	if KCF.db.destroy.announce then
		KCF:Print("Destroyed " .. amount .. " newly looted " .. KCF:GetItemName(itemID) .. ".")
	end
	KCF:Schedule("destroy-next", 0.25, function()
		Loot:DestroyNext()
	end)
end

function Loot.RequestDestroy(_self)
	KCF:Schedule("destroy-next", 0.35, function()
		Loot:DestroyNext()
	end)
end

function Loot:OnLootClosed()
	if self.session then self:RequestDestroy() end
end

function Loot:OnBagUpdate()
	if self.session then self:RequestDestroy() end
end

function Loot:OnTradeSkillShow()
	self.tradeSkillOpen = true
end

function Loot:OnTradeSkillClose()
	self.tradeSkillOpen = false
	if self.session then self:RequestDestroy() end
end
