local E = unpack(ElvUI)
local S = E:GetModule("Skins")

local _G = _G
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local ipairs = ipairs

local panels = {
	"Root",
	"General",
	"Quality",
	"Consumables",
	"Materials",
	"Corpse",
	"AlwaysKeepList",
	"AlwaysCrapList",
	"Quick",
	"AdiBags",
	"Profession_disenchant",
	"Profession_milling",
	"Profession_prospecting",
	"Inventory",
}

local checkBoxes = {
	"Enabled",
	"AutoLootCrap",
	"AutoSellCrap",
	"AutoDestroy",
	"PauseTradeskills",
	"NoDestroyGroup",
	"NoDestroyRaid",
	"DestroyAnnounce",
	"ProtectQuestItems",
	"Quality0",
	"Quality1",
	"Quality2",
	"Quality3",
	"Quality4",
	"VendorValueEnabled",
	"UseStackValue",
	"LowerLevel_food",
	"LowerLevel_water",
	"LowerLevel_foodAndDrink",
	"LowerLevel_potion",
	"LowerLevel_scroll",
	"LootCloth_2589",
	"LootCloth_2592",
	"LootCloth_4306",
	"LootCloth_4338",
	"LootCloth_14047",
	"LootCloth_21877",
	"LootCloth_33470",
	"Corpse_skinnable",
	"Corpse_mineable",
	"Corpse_gatherable",
	"Corpse_engineerable",
	"CorpseRequireProfession",
	"QuickRightClick",
	"QuickAnnounce",
	"QuickOverlay",
	"AdiBagsJunk",
	"Profession_disenchant_Enabled",
	"Profession_milling_Enabled",
	"Profession_prospecting_Enabled",
	"ProfessionAutoLootResults",
}

local dropDowns = {
	"DestroyQualityCap",
	"VendorQualityCap",
	"Mode_food",
	"Mode_water",
	"Mode_foodAndDrink",
	"Mode_potion",
	"Mode_cloth",
	"Mode_scroll",
	"Mode_tradeGoods",
	"QuickCrapModifier",
	"QuickKeepModifier",
	"Profession_disenchant_Mode",
	"Profession_milling_Mode",
	"Profession_prospecting_Mode",
}

local editBoxes = {
	"VendorThreshold_gold",
	"VendorThreshold_silver",
	"VendorThreshold_copper",
	"AlwaysKeep_Input",
	"AlwaysKeep_Search",
	"AlwaysCrap_Input",
	"AlwaysCrap_Search",
	"Profession_disenchant_Always_Input",
	"Profession_disenchant_Always_Search",
	"Profession_disenchant_Never_Input",
	"Profession_disenchant_Never_Search",
	"Profession_milling_Always_Input",
	"Profession_milling_Always_Search",
	"Profession_milling_Never_Input",
	"Profession_milling_Never_Search",
	"Profession_prospecting_Always_Input",
	"Profession_prospecting_Always_Search",
	"Profession_prospecting_Never_Input",
	"Profession_prospecting_Never_Search",
}

local buttons = {
	"OpenProcessBar",
	"OpenQuickLists",
	"ScanNow",
	"AlwaysKeep_Add",
	"AlwaysKeep_RemoveSelected",
	"AlwaysKeep_Reset",
	"AlwaysCrap_Add",
	"AlwaysCrap_RemoveSelected",
	"AlwaysCrap_Reset",
	"Profession_disenchant_Always_Add",
	"Profession_disenchant_Always_RemoveSelected",
	"Profession_disenchant_Always_Reset",
	"Profession_disenchant_Never_Add",
	"Profession_disenchant_Never_RemoveSelected",
	"Profession_disenchant_Never_Reset",
	"Profession_milling_Always_Add",
	"Profession_milling_Always_RemoveSelected",
	"Profession_milling_Always_Reset",
	"Profession_milling_Never_Add",
	"Profession_milling_Never_RemoveSelected",
	"Profession_milling_Never_Reset",
	"Profession_prospecting_Always_Add",
	"Profession_prospecting_Always_RemoveSelected",
	"Profession_prospecting_Always_Reset",
	"Profession_prospecting_Never_Add",
	"Profession_prospecting_Never_RemoveSelected",
	"Profession_prospecting_Never_Reset",
	"InventoryRefresh",
	"InventoryProcessBar",
}

local listNames = {
	"AlwaysKeep",
	"AlwaysCrap",
	"Profession_disenchant_Always",
	"Profession_disenchant_Never",
	"Profession_milling_Always",
	"Profession_milling_Never",
	"Profession_prospecting_Always",
	"Profession_prospecting_Never",
}

local quickListKeys = { "Keep", "Crap" }
local quickListMaxRows = 24

local function SkinOnce(frame, handler)
	if not frame or frame.__K2040CrapFilterSkin then return end
	handler(frame)
	frame.__K2040CrapFilterSkin = true
end

local function SyncDropDownDisplay(frame, value)
	local display = frame and frame.__K2040CrapFilterDropDownDisplay
	local arrow = frame and frame.__K2040CrapFilterDropDownArrow
	if not display or not arrow then return end

	local name = frame:GetName()
	local sourceText = name and _G[name.."Text"]
	if value == nil and sourceText and sourceText.GetText then
		value = sourceText:GetText()
	end
	display:SetText(value or "")

	local button = name and _G[name.."Button"]
	local enabled = not button or not button.IsEnabled or button:IsEnabled()
	if not enabled then
		display:SetTextColor(0.5, 0.5, 0.5)
		arrow:SetTextColor(0.5, 0.5, 0.5)
	elseif frame.__K2040CrapFilterDropDownHover then
		display:SetTextColor(1, 0.82, 0)
		arrow:SetTextColor(1, 1, 1)
	else
		display:SetTextColor(1, 1, 1)
		arrow:SetTextColor(1, 0.82, 0)
	end
end

local function SkinDropDown(frame)
	S:HandleDropDownBox(frame, 350)
	local name = frame:GetName()
	local button = name and _G[name.."Button"]
	local sourceText = name and _G[name.."Text"]
	if sourceText then sourceText:Hide() end

	local displayParent = frame.backdrop or frame
	local display = displayParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	display:SetPoint("LEFT", displayParent, "LEFT", 10, 1)
	display:SetPoint("RIGHT", displayParent, "RIGHT", -30, 1)
	display:SetHeight(16)
	display:SetJustifyH("LEFT")
	display:SetWordWrap(false)
	frame.__K2040CrapFilterDropDownDisplay = display

	local arrow = displayParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	arrow:SetPoint("RIGHT", displayParent, "RIGHT", -10, 1)
	arrow:SetText("v")
	frame.__K2040CrapFilterDropDownArrow = arrow

	if button then
		button:HookScript("OnEnter", function()
			frame.__K2040CrapFilterDropDownHover = true
			SyncDropDownDisplay(frame)
		end)
		button:HookScript("OnLeave", function()
			frame.__K2040CrapFilterDropDownHover = nil
			SyncDropDownDisplay(frame)
		end)
		button:HookScript("OnEnable", function() SyncDropDownDisplay(frame) end)
		button:HookScript("OnDisable", function() SyncDropDownDisplay(frame) end)
	end
	SyncDropDownDisplay(frame)
end

hooksecurefunc("UIDropDownMenu_SetText", function(frame, value)
	SyncDropDownDisplay(frame, value)
end)

local function SyncCheckBoxIndicator(frame)
	local indicator = frame.__K2040CrapFilterCheckedIndicator
	if not indicator then return end

	if frame:GetChecked() then
		local enabled = not frame.IsEnabled or frame:IsEnabled()
		if enabled then
			indicator:SetVertexColor(1, 0.82, 0, 0.9)
		else
			indicator:SetVertexColor(0.6, 0.6, 0.6, 0.8)
		end
		indicator:Show()
	else
		indicator:Hide()
	end
end

local function SkinCheckBox(frame)
	S:HandleCheckBox(frame)

	local indicatorParent = frame.backdrop or frame
	local indicator = indicatorParent:CreateTexture(nil, "OVERLAY")
	indicator:SetTexture(E.media.blankTex)
	if frame.backdrop then
		indicator:SetPoint("TOPLEFT", indicatorParent, "TOPLEFT", 3, -3)
		indicator:SetPoint("BOTTOMRIGHT", indicatorParent, "BOTTOMRIGHT", -3, 3)
	else
		indicator:SetPoint("TOPLEFT", indicatorParent, "TOPLEFT", 7, -7)
		indicator:SetPoint("BOTTOMRIGHT", indicatorParent, "BOTTOMRIGHT", -7, 7)
	end
	frame.__K2040CrapFilterCheckedIndicator = indicator

	hooksecurefunc(frame, "SetChecked", SyncCheckBoxIndicator)
	frame:HookScript("OnShow", SyncCheckBoxIndicator)
	frame:HookScript("OnEnable", SyncCheckBoxIndicator)
	frame:HookScript("OnDisable", SyncCheckBoxIndicator)
	frame:HookScript("OnClick", function(checkbox)
		E:Delay(0, function()
			SyncCheckBoxIndicator(checkbox)
		end)
	end)
	SyncCheckBoxIndicator(frame)
end

local function SyncEditBoxColor(frame)
	local enabled = not frame.IsEnabled or frame:IsEnabled()
	frame:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
end

local function SkinEditBox(frame)
	local name = frame.GetName and frame:GetName()
	if name then
		if _G[name.."Left"] then _G[name.."Left"]:SetAlpha(0) end
		if _G[name.."Middle"] then _G[name.."Middle"]:SetAlpha(0) end
		if _G[name.."Right"] then _G[name.."Right"]:SetAlpha(0) end
		if _G[name.."Mid"] then _G[name.."Mid"]:SetAlpha(0) end
	end

	frame:SetTemplate()
	frame:SetFontObject(_G.GameFontHighlightSmall)
	frame:SetTextInsets(5, 5, 0, 0)
	frame:HookScript("OnEnable", SyncEditBoxColor)
	frame:HookScript("OnDisable", SyncEditBoxColor)
	SyncEditBoxColor(frame)
end

local function SkinOptions()
	for _, name in ipairs(panels) do
		SkinOnce(_G["K2040CrapFilter_Options_"..name], function(frame)
			frame:StripTextures()
			frame:SetTemplate("Transparent")
		end)
		SkinOnce(_G["K2040CrapFilter_Options_"..name.."_ScrollFrameScrollBar"], function(frame)
			S:HandleScrollBar(frame)
		end)
	end

	for _, name in ipairs(checkBoxes) do
		SkinOnce(_G["K2040CrapFilter_"..name], function(frame)
			SkinCheckBox(frame)
		end)
	end

	for _, name in ipairs(dropDowns) do
		SkinOnce(_G["K2040CrapFilter_"..name], SkinDropDown)
	end

	for _, name in ipairs(editBoxes) do
		SkinOnce(_G["K2040CrapFilter_"..name], SkinEditBox)
	end

	for _, name in ipairs(buttons) do
		SkinOnce(_G["K2040CrapFilter_"..name], function(frame)
			S:HandleButton(frame)
		end)
	end

	SkinOnce(_G.K2040CrapFilter_FreeSlotThreshold, function(frame)
		S:HandleSliderFrame(frame)
	end)

	for _, listName in ipairs(listNames) do
		SkinOnce(_G["K2040CrapFilter_"..listName.."_ScrollScrollBar"], function(frame)
			S:HandleScrollBar(frame)
		end)

		for index = 1, 8 do
			SkinOnce(_G["K2040CrapFilter_"..listName.."_Row"..index], function(frame)
				S:HandleButton(frame)
			end)
		end
	end
end

local function SkinProcessBar()
	SkinOnce(_G.K2040CrapFilter_ProcessBar, function(frame)
		frame:StripTextures()
		frame:SetTemplate("Transparent")
	end)
	SkinOnce(_G.K2040CrapFilter_ProcessBar_Close, function(frame)
		S:HandleCloseButton(frame, _G.K2040CrapFilter_ProcessBar)
	end)
	SkinOnce(_G.K2040CrapFilter_ProcessAction, function(frame)
		S:HandleButton(frame)
	end)
end

local function SkinQuickLists()
	local window = _G.K2040CrapFilter_QuickLists
	SkinOnce(window, function(frame)
		frame:StripTextures()
		frame:SetTemplate("Transparent")
	end)
	SkinOnce(_G.K2040CrapFilter_QuickLists_Close, function(frame)
		S:HandleCloseButton(frame, window)
	end)

	for _, key in ipairs(quickListKeys) do
		SkinOnce(_G["K2040CrapFilter_QuickLists_"..key], function(frame)
			frame:StripTextures()
			frame:SetTemplate("Transparent")
		end)
		SkinOnce(_G["K2040CrapFilter_QuickLists_"..key.."_Search"], SkinEditBox)
		SkinOnce(_G["K2040CrapFilter_QuickLists_"..key.."_ScrollScrollBar"], function(frame)
			S:HandleScrollBar(frame)
		end)
		SkinOnce(_G["K2040CrapFilter_QuickLists_"..key.."_RemoveSelected"], function(frame)
			S:HandleButton(frame)
		end)
		SkinOnce(_G["K2040CrapFilter_QuickLists_"..key.."_Reset"], function(frame)
			S:HandleButton(frame)
		end)
		for index = 1, quickListMaxRows do
			SkinOnce(_G["K2040CrapFilter_QuickLists_"..key.."_Row"..index], function(frame)
				S:HandleButton(frame)
			end)
		end
	end
end

local function SkinAll()
	SkinOptions()
	SkinProcessBar()
	SkinQuickLists()
end

local function InstallLateFrameHooks()
	local addon = _G.K2040CrapFilter
	local modules = addon and addon.modules
	local options = modules and modules.Options
	local professions = modules and modules.Professions
	local quickLists = modules and modules.QuickLists

	if options and options.BuildPanels and not options.__K2040CrapFilterSkinHook then
		hooksecurefunc(options, "BuildPanels", function()
			E:Delay(0, SkinOptions)
		end)
		options.__K2040CrapFilterSkinHook = true
	end
	if professions and professions.CreateProcessBar and not professions.__K2040CrapFilterSkinHook then
		hooksecurefunc(professions, "CreateProcessBar", function()
			E:Delay(0, SkinProcessBar)
		end)
		professions.__K2040CrapFilterSkinHook = true
	end
	if quickLists and quickLists.CreateWindow and not quickLists.__K2040CrapFilterSkinHook then
		hooksecurefunc(quickLists, "CreateWindow", function()
			E:Delay(0, SkinQuickLists)
		end)
		quickLists.__K2040CrapFilterSkinHook = true
	end
end

local function ApplySkin()
	InstallLateFrameHooks()
	SkinAll()
	E:Delay(0.25, SkinAll)
end

ApplySkin()

local loginRetry = CreateFrame("Frame")
loginRetry:RegisterEvent("PLAYER_LOGIN")
loginRetry:SetScript("OnEvent", function(frame)
	frame:UnregisterEvent("PLAYER_LOGIN")
	ApplySkin()
end)
