local _, KCF = ...

local _G = _G
local CreateFrame = _G.CreateFrame
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetItemInfo = _G.GetItemInfo
local GetLootSlotLink = _G.GetLootSlotLink
local GetLootSlotType = _G.GetLootSlotType
local GetNumLootItems = _G.GetNumLootItems
local GetSpellInfo = _G.GetSpellInfo
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsSpellKnown = _G.IsSpellKnown
local LootSlot = _G.LootSlot
local UIParent = _G.UIParent
local ipairs = ipairs
local tonumber = tonumber

local Professions = {}
KCF:RegisterModule("Professions", Professions)

local PROCESSOR_ORDER = { "disenchant", "milling", "prospecting" }
local PROCESSORS = {
	disenchant = {
		label = "Disenchant",
		spellID = 13262,
	},
	milling = {
		label = "Milling",
		spellID = 51005,
	},
	prospecting = {
		label = "Prospecting",
		spellID = 31252,
	},
}

function Professions:OnInitialize()
	KCF:RegisterEvent("BAG_UPDATE", self, "OnBagUpdate")
	KCF:RegisterEvent("LOOT_OPENED", self, "OnLootOpened")
	KCF:RegisterEvent("LOOT_CLOSED", self, "OnLootClosed")
	KCF:RegisterEvent("UNIT_SPELLCAST_SENT", self, "OnSpellcastSent")
	KCF:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", self, "OnSpellcastSucceeded")
	KCF:RegisterEvent("UNIT_SPELLCAST_FAILED", self, "OnSpellcastStopped")
	KCF:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", self, "OnSpellcastStopped")
	KCF:RegisterEvent("PLAYER_REGEN_ENABLED", self, "OnRegenEnabled")
end

function Professions:OnEnable()
	self:CreateProcessBar()
	self:RequestScan()
	if KCF.db.ui.processBarShown then
		self.frame:Show()
	end
end

function Professions.IsEligible(_self, processor, itemID, count)
	local classification = KCF.modules.Classification
	if processor == "disenchant" then
		return classification:IsDisenchantable(itemID)
	elseif processor == "milling" then
		return (tonumber(count) or 0) >= 5 and classification:IsMillable(itemID)
	elseif processor == "prospecting" then
		return (tonumber(count) or 0) >= 5 and classification:IsProspectable(itemID)
	end
	return false
end

function Professions:ShouldProcess(processor, itemID, count)
	local config = KCF.db.professions[processor]
	if not config or not config.enabled or config.never[itemID] then return false end
	if not self:IsEligible(processor, itemID, count) then return false end
	if config.always[itemID] then return true end
	if config.mode == "whitelist" then return false end

	local classification = KCF.modules.Classification
	if classification:IsGloballyProtected(itemID) then return false end
	if config.mode == "all" then return true end
	if config.mode == "crap" then
		return KCF:Classify(itemID, count) == KCF.RESULT_CRAP
	end
	return false
end

function Professions:IsReserved(itemID)
	local reserved = false
	KCF:ForEachBagSlot(function(_, _, slotItemID, count)
		if not reserved and slotItemID == itemID then
			for _, processor in ipairs(PROCESSOR_ORDER) do
				if self:ShouldProcess(processor, itemID, count) then
					reserved = true
					return
				end
			end
		end
	end)
	return reserved
end

function Professions:FindTarget(processor)
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local _, count, locked = GetContainerItemInfo(bag, slot)
				local itemID = KCF:ParseItemID(link)
				if itemID and not locked and self:ShouldProcess(processor, itemID, count) then
					return {
						bag = bag,
						slot = slot,
						itemID = itemID,
						count = tonumber(count) or 1,
						link = link,
					}
				end
			end
		end
	end
	return nil
end

function Professions:FindNextTarget()
	local enabledCount = 0
	local learnedCount = 0
	for _, processor in ipairs(PROCESSOR_ORDER) do
		local definition = PROCESSORS[processor]
		local config = KCF.db.professions[processor]
		if config and config.enabled then
			enabledCount = enabledCount + 1
			local spellName = GetSpellInfo(definition.spellID)
			if spellName and (not IsSpellKnown or IsSpellKnown(definition.spellID)) then
				learnedCount = learnedCount + 1
				local target = self:FindTarget(processor)
				if target then
					target.processor = processor
					target.label = definition.label
					target.spellID = definition.spellID
					target.spellName = spellName
					return target
				end
			end
		end
	end

	if enabledCount == 0 then
		return nil, "Turn on at least one profession in settings."
	elseif learnedCount == 0 then
		return nil, "This character has not learned an enabled profession."
	end
	return nil, "Nothing in your bags matches the enabled profession rules."
end

function Professions:SetStatus(text)
	if self.status then self.status:SetText(text or "") end
end

function Professions:SetActionTarget(button, target, reason)
	button.target = nil
	button:SetAttribute("macrotext", nil)
	button:SetAttribute("type", nil)
	if not target then
		button:Disable()
		button.text:SetText("No profession target ready")
		button.statusReason = reason or "No profession action is currently available."
		self:SetStatus(button.statusReason)
		return
	end

	button.target = target
	button.statusReason = nil
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", "/cast " .. target.spellName .. "\n/use " .. target.bag .. " " .. target.slot)
	button.text:SetText(target.label .. ": " .. (GetItemInfo(target.itemID) or ("Item " .. target.itemID)))
	button:Enable()
	self:SetStatus("Ready. Click once to process this item. The addon will then find the next one.")
end

function Professions:Scan()
	if not self.frame or (InCombatLockdown and InCombatLockdown()) then
		self.scanAfterCombat = true
		return
	end
	if self.castInProgress or self.awaitingResult then
		self.scanPending = true
		return
	end
	self.scanAfterCombat = nil
	self.scanPending = nil
	local target, reason = self:FindNextTarget()
	self:SetActionTarget(self.actionButton, target, reason)
end

function Professions.RequestScan(_self)
	KCF:Schedule("profession-scan", 0.15, function()
		Professions:Scan()
	end)
end

function Professions:OnActionPreClick(button)
	if not button.target then return end
	self.pendingAction = button.target
	self:SetStatus("Starting " .. button.target.label .. " on " .. (GetItemInfo(button.target.itemID) or ("Item " .. button.target.itemID)) .. "...")
	KCF:Schedule("profession-click-timeout", 1, function()
		if Professions.pendingAction and not Professions.castInProgress then
			Professions.pendingAction = nil
			Professions:RequestScan()
		end
	end)
end

function Professions:OnActionPostClick(button)
	if self.pendingAction or self.castInProgress then button:Disable() end
end

function Professions.CreateProcessButton(_self, parent)
	local button = CreateFrame("Button", "K2040CrapFilter_ProcessAction", parent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
	button:SetPoint("TOP", parent, "TOP", 0, -78)
	button:SetWidth(280)
	button:SetHeight(24)
	button:SetNormalFontObject("GameFontNormalSmall")
	button:SetHighlightFontObject("GameFontHighlightSmall")
	button:SetDisabledFontObject("GameFontDisableSmall")
	button.text = button:GetFontString()
	button:SetText("No profession target ready")
	button:SetScript("PreClick", function(buttonFrame)
		Professions:OnActionPreClick(buttonFrame)
	end)
	button:SetScript("PostClick", function(buttonFrame)
		Professions:OnActionPostClick(buttonFrame)
	end)
	button:SetScript("OnEnter", function(buttonFrame)
		_G.GameTooltip:SetOwner(buttonFrame, "ANCHOR_TOP")
		if buttonFrame.target then
			_G.GameTooltip:SetHyperlink(buttonFrame.target.link)
			_G.GameTooltip:AddLine("Click once to cast. The next matching item is selected afterward.", 1, 1, 1, true)
		else
			_G.GameTooltip:AddLine("Profession processing")
			_G.GameTooltip:AddLine(buttonFrame.statusReason or "No profession item is ready.", 1, 1, 1, true)
		end
		_G.GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		_G.GameTooltip:Hide()
	end)
	return button
end

function Professions:CreateProcessBar()
	if self.frame then return end
	local frame = CreateFrame("Frame", "K2040CrapFilter_ProcessBar", UIParent)
	frame:SetWidth(430)
	frame:SetHeight(148)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(barFrame)
		if not (InCombatLockdown and InCombatLockdown()) then barFrame:StartMoving() end
	end)
	frame:SetScript("OnDragStop", function(barFrame) barFrame:StopMovingOrSizing() end)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 14, -11)
	title:SetText(KCF.displayName .. " — Profession Processing")
	local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", 14, -34)
	help:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
	help:SetHeight(34)
	help:SetJustifyH("LEFT")
	help:SetJustifyV("TOP")
	help:SetWordWrap(true)
	help:SetText("The addon picks the next matching item. Click once for each cast.")
	local close = CreateFrame("Button", "K2040CrapFilter_ProcessBar_Close", frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 1, 1)
	close:SetScript("OnClick", function()
		frame:Hide()
		KCF.db.ui.processBarShown = false
	end)

	self.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	self.status:SetPoint("TOPLEFT", 16, -116)
	self.status:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
	self.status:SetHeight(18)
	self.status:SetJustifyH("LEFT")
	self.status:SetWordWrap(false)
	self.actionButton = self:CreateProcessButton(frame)
	self.frame = frame
	frame:Hide()
end

function Professions:ToggleProcessBar(show)
	if not self.frame then return end
	if show == nil then show = not self.frame:IsShown() end
	if show then
		self.frame:Show()
		self.frame:Raise()
		KCF.db.ui.processBarShown = true
		self:RequestScan()
	else
		self.frame:Hide()
		KCF.db.ui.processBarShown = false
	end
end

function Professions:IsProfessionResultPending()
	return self.awaitingResult ~= nil
end

function Professions:OnBagUpdate()
	self:RequestScan()
end

function Professions:OnSpellcastSent(_, unit, spellName)
	if unit ~= "player" then return end
	local pending = self.pendingAction
	if not pending or pending.spellName ~= spellName then return end
	self.castInProgress = pending
	self.pendingAction = nil
	KCF:CancelSchedule("profession-click-timeout")
	self:SetStatus("Processing " .. pending.label .. "...")
end

function Professions:OnSpellcastSucceeded(_, unit, spellName)
	if unit ~= "player" then return end
	local active = self.castInProgress
	if not active or active.spellName ~= spellName then return end
	self.castInProgress = nil
	self.awaitingResult = {
		processor = active.processor,
		itemID = active.itemID,
		started = GetTime(),
		autoLootUntil = GetTime() + 1.5,
	}
	self:SetStatus("Cast complete. Waiting for the result.")
	KCF:Schedule("profession-result-timeout", 5, function()
		if Professions.awaitingResult then
			Professions.awaitingResult = nil
			Professions:RequestScan()
		end
	end)
	KCF:Schedule("profession-success-rescan", 0.5, function()
		Professions:Scan()
	end)
end

function Professions:OnSpellcastStopped(_, unit, spellName)
	if unit ~= "player" then return end
	local active = self.castInProgress or self.pendingAction
	if not active or active.spellName ~= spellName then return end
	self.castInProgress = nil
	self.pendingAction = nil
	self:SetStatus("The cast did not finish. Checking the item again.")
	self:RequestScan()
end

function Professions:OnLootOpened()
	if not self.awaitingResult or not KCF.db.professions.autoLootResults then return end
	if not self.awaitingResult.autoLootUntil or GetTime() > self.awaitingResult.autoLootUntil then
		self:SetStatus("Auto-loot waited too long. Loot this window manually.")
		return
	end
	local itemSlotType = _G.LOOT_SLOT_ITEM or 1
	local numLootItems = GetNumLootItems and GetNumLootItems() or 0
	if numLootItems < 1 then return end

	for slot = 1, numLootItems do
		if (GetLootSlotType and GetLootSlotType(slot) ~= itemSlotType)
			or not (GetLootSlotLink and GetLootSlotLink(slot)) then
			self:SetStatus("This loot window includes something unexpected. Loot it manually.")
			return
		end
	end

	for slot = 1, numLootItems do LootSlot(slot) end
	self:SetStatus("Result looted. Finding the next item...")
end

function Professions:OnLootClosed()
	if not self.awaitingResult then return end
	self.awaitingResult = nil
	KCF:CancelSchedule("profession-result-timeout")
	self:RequestScan()
end

function Professions:OnRegenEnabled()
	if self.scanAfterCombat then self:RequestScan() end
end
