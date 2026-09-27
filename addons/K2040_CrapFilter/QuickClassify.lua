local _, KCF = ...

local _G = _G
local CreateFrame = _G.CreateFrame
local GetContainerItemLink = _G.GetContainerItemLink
local GetMouseFocus = _G.GetMouseFocus
local InCombatLockdown = _G.InCombatLockdown
local IsAltKeyDown = _G.IsAltKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local IsShiftKeyDown = _G.IsShiftKeyDown
local hooksecurefunc = _G.hooksecurefunc
local pcall = pcall
local type = type
local tostring = tostring

local Quick = {}
KCF:RegisterModule("QuickClassify", Quick)

local function isDown(value)
	return value == 1 or value == true
end

function Quick:OnInitialize()
	KCF:RegisterEvent("BAG_UPDATE", self, "OnBagUpdate")
	KCF:RegisterEvent("PLAYER_REGEN_ENABLED", self, "OnRegenEnabled")
	KCF:RegisterEvent("ADDON_LOADED", self, "OnAddonLoaded")
end

function Quick:OnEnable()
	self:InstallAdiBagsHook()
	self:InstallBagButtonWrappers()
end

function Quick.ModifierMatches(_self, specification)
	local required = { ALT = false, CTRL = false, SHIFT = false }
	for token in tostring(specification or ""):gmatch("[^%-]+") do
		if required[token] ~= nil then required[token] = true end
	end
	return required.ALT == isDown(IsAltKeyDown())
		and required.CTRL == isDown(IsControlKeyDown())
		and required.SHIFT == isDown(IsShiftKeyDown())
end

function Quick:GetRightClickRule()
	if not KCF.db.quick.rightClickEnabled then return nil end
	local keep = KCF.db.quick.keepModifier
	local crap = KCF.db.quick.crapModifier
	if keep and self:ModifierMatches(keep) then return KCF.RESULT_KEEP end
	if crap and self:ModifierMatches(crap) then return KCF.RESULT_CRAP end
	return nil
end

function Quick.GetButtonBagSlot(_self, button)
	if not button then return nil end
	local bag = tonumber(button.bagID or button.bag)
	local slot = tonumber(button.slotID or button.slot)
	if bag and slot then return bag, slot end

	local name = button.GetName and button:GetName()
	if name and name:match("^ContainerFrame%d+Item%d+$") then
		local parent = button:GetParent()
		bag = parent and parent.GetID and parent:GetID()
		slot = button.GetID and button:GetID()
		if bag and slot then return bag, slot end
	end
	return nil
end

function Quick:GetButtonItemID(button)
	if not button then return nil end
	if button.GetRealButton then
		local realButton = button:GetRealButton()
		if realButton and realButton ~= button then
			button = realButton
		end
	end
	if button.GetItemId then
		local itemID = KCF:ParseItemID(button:GetItemId())
		if itemID then return itemID end
	end
	if button.GetItemLink then
		local itemID = KCF:ParseItemID(button:GetItemLink())
		if itemID then return itemID end
	end
	local bag, slot = self:GetButtonBagSlot(button)
	if not bag then return nil end
	return KCF:ParseItemID(GetContainerItemLink(bag, slot))
end

function Quick.ShowOverlay(_self, button, rule)
	if not KCF.db.quick.overlay or not button then return end
	local overlay = button.__KCFOverlay
	if not overlay then
		overlay = CreateFrame("Frame", nil, button)
		overlay:SetAllPoints(button)
		overlay:SetFrameLevel(button:GetFrameLevel() + 8)
		overlay.texture = overlay:CreateTexture(nil, "OVERLAY")
		overlay.texture:SetAllPoints(overlay)
		overlay.__elapsed = 0
		overlay:SetScript("OnUpdate", function(overlayFrame, elapsed)
			overlayFrame.__elapsed = overlayFrame.__elapsed + elapsed
			if overlayFrame.__elapsed >= 0.8 then overlayFrame:Hide() end
		end)
		button.__KCFOverlay = overlay
	end
	if rule == KCF.RESULT_KEEP then
		overlay.texture:SetTexture(0.1, 0.8, 0.2, 0.45)
	else
		overlay.texture:SetTexture(0.9, 0.15, 0.1, 0.45)
	end
	overlay.__elapsed = 0
	overlay:Show()
end

function Quick:ApplyRuleToButton(button, rule)
	local itemID = self:GetButtonItemID(button)
	if not itemID then return false end
	if not KCF:SetItemRule(itemID, rule) then return false end
	self:ShowOverlay(button, rule)
	if KCF.db.quick.announce then
		local label = rule == KCF.RESULT_KEEP and "Always Keep" or "Always Crap"
		KCF:Print(KCF:GetItemName(itemID) .. " -> " .. label)
	end
	return true
end

function Quick.GetAdiBagsItemPrototype(_self)
	local classification = KCF.modules.Classification
	local adiBags = classification and classification:GetAdiBagsAddon()
	if not adiBags or type(adiBags.GetClass) ~= "function" then return nil end
	local ok, itemClass = pcall(adiBags.GetClass, adiBags, "ItemButton")
	if not ok or not itemClass then return nil end
	return itemClass.prototype
end

function Quick:InstallAdiBagsHook()
	if self.adiBagsAcquireHooked then return true end
	if type(hooksecurefunc) ~= "function" then return false end
	local prototype = self:GetAdiBagsItemPrototype()
	if not prototype or type(prototype.OnAcquire) ~= "function" then return false end
	hooksecurefunc(prototype, "OnAcquire", function(button)
		Quick:WrapButton(button)
	end)
	self.adiBagsAcquireHooked = true
	return true
end

function Quick:WrapButton(button)
	if not button or not button.GetScript or not button.SetScript then return end
	if InCombatLockdown and InCombatLockdown() then
		self.installAfterCombat = true
		return
	end
	local bag, slot = self:GetButtonBagSlot(button)
	if not bag or not slot then return end
	local original = button:GetScript("OnClick")
	if button.__KCFWrappedHandler and original == button.__KCFWrappedHandler then return end
	if type(original) ~= "function" then return end
	local wrapped
	wrapped = function(itemButton, mouseButton, ...)
		if mouseButton == "RightButton" and not (InCombatLockdown and InCombatLockdown()) then
			local rule = Quick:GetRightClickRule()
			if rule and Quick:ApplyRuleToButton(itemButton, rule) then return end
		end
		return original(itemButton, mouseButton, ...)
	end
	button.__KCFOriginalOnClick = original
	button.__KCFWrappedHandler = wrapped
	button:SetScript("OnClick", wrapped)
end

function Quick:InstallBagButtonWrappers()
	if InCombatLockdown and InCombatLockdown() then
		self.installAfterCombat = true
		return
	end
	self.installAfterCombat = nil
	self:InstallAdiBagsHook()
	local frame = _G.EnumerateFrames()
	while frame do
		local bag, slot = self:GetButtonBagSlot(frame)
		if bag and slot then
			self:WrapButton(frame)
		end
		frame = _G.EnumerateFrames(frame)
	end
end

function Quick:ClassifyMouseover(rule)
	local button = GetMouseFocus and GetMouseFocus()
	if not self:ApplyRuleToButton(button, rule) then
		KCF:Print("Move the pointer over a bag item before using that keybind.")
	end
end

function Quick.OnBagUpdate(_self)
	KCF:Schedule("quick-button-scan", 0.2, function()
		Quick:InstallBagButtonWrappers()
	end)
end

function Quick:OnRegenEnabled()
	if self.installAfterCombat then self:InstallBagButtonWrappers() end
end

function Quick:OnAddonLoaded(_, loadedAddon)
	if loadedAddon == "AdiBags" then self:InstallAdiBagsHook() end
	if loadedAddon == "ElvUI" or loadedAddon == "AdiBags" then self:OnBagUpdate() end
end

_G.K2040CrapFilter_MarkMouseoverCrap = function()
	Quick:ClassifyMouseover(KCF.RESULT_CRAP)
end

_G.K2040CrapFilter_MarkMouseoverKeep = function()
	Quick:ClassifyMouseover(KCF.RESULT_KEEP)
end
