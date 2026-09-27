local _, KCF = ...

local _G = _G
local CreateFrame = _G.CreateFrame
local ClearCursor = _G.ClearCursor
local FauxScrollFrame_GetOffset = _G.FauxScrollFrame_GetOffset
local FauxScrollFrame_OnVerticalScroll = _G.FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_Update = _G.FauxScrollFrame_Update
local GetCursorInfo = _G.GetCursorInfo
local GetItemInfo = _G.GetItemInfo
local InterfaceOptions_AddCategory = _G.InterfaceOptions_AddCategory
local InterfaceOptionsFrame_OpenToCategory = _G.InterfaceOptionsFrame_OpenToCategory
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_SetSelectedValue = _G.UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local StaticPopup_Show = _G.StaticPopup_Show
local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs
local pairs = pairs
local next = next
local lower = string.lower
local find = string.find
local floor = math.floor
local max = math.max
local min = math.min

local Options = {}
KCF:RegisterModule("Options", Options)

local MODE_VALUES = {
	{ value = "neutral", label = "Do not classify" },
	{ value = "always_keep", label = "Always Keep" },
	{ value = "always_crap", label = "Always Crap" },
}

local PROCESS_MODE_VALUES = {
	{ value = "whitelist", label = "Only Always Process items" },
	{ value = "crap", label = "Eligible Crap items" },
	{ value = "all", label = "All eligible items" },
}

local MODIFIER_VALUES = {
	{ value = "ALT", label = "Alt" },
	{ value = "CTRL", label = "Ctrl" },
	{ value = "SHIFT", label = "Shift" },
	{ value = "CTRL-ALT", label = "Ctrl + Alt" },
	{ value = "SHIFT-ALT", label = "Shift + Alt" },
	{ value = "CTRL-SHIFT", label = "Ctrl + Shift" },
	{ value = "CTRL-SHIFT-ALT", label = "Ctrl + Shift + Alt" },
}

local RESET_LIST_DIALOG = "K2040_CRAP_FILTER_RESET_LIST"
_G.StaticPopupDialogs[RESET_LIST_DIALOG] = {
	text = "Reset the %s list? Every item in this list will be removed.",
	button1 = _G.YES,
	button2 = _G.NO,
	OnAccept = function(_, data)
		if data and data.reset then data.reset() end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

local function setLabel(checkBox, text)
	local label = _G[checkBox:GetName() .. "Text"]
	if label then
		label:SetText(text)
		label:SetWidth(320)
		label:SetJustifyH("LEFT")
	end
end

local function addHeading(panel, text, y)
	local parent = panel.content or panel
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	label:SetPoint("TOPLEFT", 16, y)
	label:SetText(text)
	return label
end

local function addText(panel, text, x, y, width, template)
	local parent = panel.content or panel
	local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlightSmall")
	label:SetPoint("TOPLEFT", x, y)
	if not width or width >= 500 then
		label:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, y)
		label:SetHeight(52)
	else
		label:SetWidth(width)
		label:SetHeight(20)
	end
	label:SetWordWrap(true)
	label:SetJustifyH("LEFT")
	label:SetJustifyV("TOP")
	label:SetText(text)
	return label
end

local function setPanelContentHeight(panel, height)
	panel.contentHeight = height
	panel.content:SetHeight(height)
end

local function createPanel(internalName, title, parent)
	local panel = CreateFrame("Frame", "K2040CrapFilter_Options_" .. internalName, _G.InterfaceOptionsFramePanelContainer)
	panel.name = title
	panel.parent = parent
	panel.controls = {}

	local scroll = CreateFrame("ScrollFrame", panel:GetName() .. "_ScrollFrame", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -2)
	scroll:SetPoint("BOTTOMRIGHT", -26, 2)
	scroll:EnableMouseWheel(true)

	local content = CreateFrame("Frame", panel:GetName() .. "_Content", scroll)
	content:SetWidth(360)
	content:SetHeight(420)
	scroll:SetScrollChild(content)
	panel.scrollFrame = scroll
	panel.content = content
	panel.contentHeight = 420

	local function syncContentWidth(width)
		content:SetWidth(max(320, (width or scroll:GetWidth() or 362) - 2))
	end
	scroll:SetScript("OnSizeChanged", function(_, width) syncContentWidth(width) end)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local nextValue = self:GetVerticalScroll() - (delta * 32)
		self:SetVerticalScroll(min(max(nextValue, 0), self:GetVerticalScrollRange()))
	end)
	panel:SetScript("OnShow", function()
		syncContentWidth()
		content:SetHeight(panel.contentHeight)
	end)
	InterfaceOptions_AddCategory(panel)
	return panel
end

local function addRefresh(panel, callback)
	panel.refreshers = panel.refreshers or {}
	panel.refreshers[#panel.refreshers + 1] = callback
	panel.refresh = function(self)
		for _, refresh in ipairs(self.refreshers) do refresh() end
	end
end

local function createCheckBox(panel, internalName, label, description, getter, setter, x, y)
	local checkBox = CreateFrame("CheckButton", "K2040CrapFilter_" .. internalName, panel.content or panel, "InterfaceOptionsCheckButtonTemplate")
	checkBox:SetPoint("TOPLEFT", x, y)
	setLabel(checkBox, label)
	checkBox.tooltipText = description
	checkBox:SetScript("OnClick", function(self)
		setter(self:GetChecked() and true or false)
		KCF:NotifyRulesChanged()
	end)
	addRefresh(panel, function()
		checkBox:SetChecked(getter() and 1 or nil)
	end)
	return checkBox
end

local function createButton(panel, internalName, label, callback, x, y, width)
	local button = CreateFrame("Button", "K2040CrapFilter_" .. internalName, panel.content or panel, "UIPanelButtonTemplate")
	button:SetPoint("TOPLEFT", x, y)
	button:SetWidth(width or 180)
	button:SetHeight(24)
	button:SetText(label)
	button:SetScript("OnClick", callback)
	return button
end

local function createWideButton(panel, internalName, label, callback, y)
	local parent = panel.content or panel
	local button = createButton(panel, internalName, label, callback, 16, y, 200)
	button:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
	return button
end

local function findValueLabel(values, value)
	for _, entry in ipairs(values) do
		if entry.value == value then return entry.label end
	end
	return tostring(value or "")
end

local function createDropDown(panel, internalName, label, values, getter, setter, x, y, width)
	width = width or 350
	addText(panel, label, x + 16, y, width - 16, "GameFontNormal")
	local dropDown = CreateFrame("Frame", "K2040CrapFilter_" .. internalName, panel.content or panel, "UIDropDownMenuTemplate")
	dropDown:SetPoint("TOPLEFT", x, y - 16)
	UIDropDownMenu_SetWidth(dropDown, width - 40)
	UIDropDownMenu_Initialize(dropDown, function()
		for _, entry in ipairs(values) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = entry.label
			info.value = entry.value
			info.checked = getter() == entry.value
			info.func = function()
				setter(entry.value)
				UIDropDownMenu_SetSelectedValue(dropDown, entry.value)
				UIDropDownMenu_SetText(dropDown, entry.label)
				KCF:NotifyRulesChanged()
			end
			_G.UIDropDownMenu_AddButton(info)
		end
	end)
	addRefresh(panel, function()
		local value = getter()
		UIDropDownMenu_SetSelectedValue(dropDown, value)
		UIDropDownMenu_SetText(dropDown, findValueLabel(values, value))
	end)
	return dropDown
end

local function createSlider(panel, internalName, label, minimum, maximum, step, getter, setter, x, y, width)
	local slider = CreateFrame("Slider", "K2040CrapFilter_" .. internalName, panel.content or panel, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", x, y)
	slider:SetWidth(width or 240)
	slider:SetMinMaxValues(minimum, maximum)
	slider:SetValueStep(step)
	_G[slider:GetName() .. "Text"]:SetText(label)
	_G[slider:GetName() .. "Low"]:SetText(tostring(minimum))
	_G[slider:GetName() .. "High"]:SetText(tostring(maximum))
	slider:SetScript("OnValueChanged", function(self, value)
		value = floor(value + 0.5)
		setter(value)
		_G[self:GetName() .. "Text"]:SetText(label .. ": " .. value)
	end)
	addRefresh(panel, function()
		local value = tonumber(getter()) or minimum
		slider:SetValue(value)
		_G[slider:GetName() .. "Text"]:SetText(label .. ": " .. value)
	end)
	return slider
end

local function createMoneyInput(panel, internalName, label, getter, setter, x, y)
	addText(panel, label, x, y, 340, "GameFontNormal")
	local fields = {}
	local units = {
		{ key = "gold", divisor = 10000, label = "g" },
		{ key = "silver", divisor = 100, label = "s" },
		{ key = "copper", divisor = 1, label = "c" },
	}

	local function save()
		local gold = tonumber(fields.gold:GetText()) or 0
		local silver = tonumber(fields.silver:GetText()) or 0
		local copper = tonumber(fields.copper:GetText()) or 0
		setter(math.max(0, floor(gold) * 10000 + floor(silver) * 100 + floor(copper)))
		KCF:NotifyRulesChanged()
	end

	for index, unit in ipairs(units) do
		local edit = CreateFrame("EditBox", "K2040CrapFilter_" .. internalName .. "_" .. unit.key, panel.content or panel, "InputBoxTemplate")
		edit:SetPoint("TOPLEFT", x + (index - 1) * 82, y - 20)
		edit:SetWidth(48)
		edit:SetHeight(22)
		edit:SetAutoFocus(false)
		edit:SetNumeric(true)
		edit:SetMaxLetters(index == 1 and 6 or 2)
		edit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); save() end)
		edit:SetScript("OnEditFocusLost", save)
		addText(panel, unit.label, x + (index - 1) * 82 + 52, y - 24, 24, "GameFontHighlightSmall")
		fields[unit.key] = edit
	end

	addRefresh(panel, function()
		local total = math.max(0, tonumber(getter()) or 0)
		fields.gold:SetText(floor(total / 10000))
		fields.silver:SetText(floor((total % 10000) / 100))
		fields.copper:SetText(total % 100)
	end)
	return fields
end

local function createItemList(panel, internalName, label, getter, addItem, removeItem, x, y, width, visibleRows)
	width = width or 260
	visibleRows = visibleRows or 8
	local selectedItemID
	local refresh
	local search
	addText(panel, label, x, y, width, "GameFontNormal")
	local input = CreateFrame("EditBox", "K2040CrapFilter_" .. internalName .. "_Input", panel.content or panel, "InputBoxTemplate")
	input:SetPoint("TOPLEFT", x, y - 24)
	input:SetWidth(width - 62)
	input:SetHeight(22)
	input:SetAutoFocus(false)
	input:SetScript("OnReceiveDrag", function(self)
		local cursorType, itemID, itemLink = GetCursorInfo()
		if cursorType == "item" then
			self:SetText(itemLink or itemID or "")
			if ClearCursor then ClearCursor() end
		end
	end)
	local add = createButton(panel, internalName .. "_Add", "Add", function()
		local itemID = KCF:ParseItemID(input:GetText())
		if itemID and addItem(itemID) then
			input:SetText("")
			search:SetText("")
			KCF:NotifyRulesChanged(itemID)
		else
			KCF:Print("Enter an item ID or item link.")
		end
	end, x + width - 56, y - 24, 56)
	add:SetHeight(22)
	input:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		add:Click()
	end)

	addText(panel, "Search", x, y - 60, 48, "GameFontNormalSmall")
	search = CreateFrame("EditBox", "K2040CrapFilter_" .. internalName .. "_Search", panel.content or panel, "InputBoxTemplate")
	search:SetPoint("TOPLEFT", x + 52, y - 58)
	search:SetWidth(width - 52)
	search:SetHeight(22)
	search:SetAutoFocus(false)
	search:SetScript("OnTextChanged", function()
		selectedItemID = nil
		refresh()
	end)
	search:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)

	local scroll = CreateFrame("ScrollFrame", "K2040CrapFilter_" .. internalName .. "_Scroll", panel.content or panel, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", x, y - 88)
	scroll:SetWidth(width - 26)
	scroll:SetHeight((visibleRows * 20) + 2)
	local rows = {}
	for index = 1, visibleRows do
		local row = CreateFrame("Button", "K2040CrapFilter_" .. internalName .. "_Row" .. index, panel.content or panel)
		row:SetPoint("TOPLEFT", x, y - 88 - ((index - 1) * 20))
		row:SetWidth(width - 26)
		row:SetHeight(19)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", 3, 0)
		row.text:SetPoint("RIGHT", -3, 0)
		row.text:SetJustifyH("LEFT")
		row:RegisterForClicks("LeftButtonUp")
		row:SetScript("OnClick", function(self)
			if not self.itemID then return end
			selectedItemID = self.itemID
			refresh()
		end)
		row:SetScript("OnEnter", function(self)
			if not self.itemID then return end
			_G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			_G.GameTooltip:SetHyperlink("item:" .. self.itemID)
			_G.GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
		rows[index] = row
	end

	local emptyText = addText(panel, "No items in this list.", x + 8, y - 88 - (visibleRows * 10), width - 42, "GameFontDisableSmall")
	local actionY = y - 100 - (visibleRows * 20)
	local removeSelected = createButton(panel, internalName .. "_RemoveSelected", "Remove selected", function()
		if not selectedItemID then return end
		local itemID = selectedItemID
		if removeItem(itemID) then
			selectedItemID = nil
			KCF:NotifyRulesChanged(itemID)
		end
		refresh()
	end, x, actionY, 154)
	local resetList = createButton(panel, internalName .. "_Reset", "Reset list", function()
		local list = getter()
		if not next(list) then return end
		StaticPopup_Show(RESET_LIST_DIALOG, label, nil, {
			reset = function()
				for itemID in pairs(list) do list[itemID] = nil end
				selectedItemID = nil
				KCF:NotifyRulesChanged()
				refresh()
			end,
		})
	end, x + 162, actionY, 122)

	refresh = function()
		local list = getter()
		local allIDs = KCF:GetSortedItemIDs(list)
		local ids = {}
		local query = lower(search:GetText() or ""):match("^%s*(.-)%s*$")
		for _, itemID in ipairs(allIDs) do
			local itemName = GetItemInfo(itemID) or ("Item " .. itemID)
			local matches = query == ""
				or find(lower(itemName), query, 1, true)
				or find(tostring(itemID), query, 1, true)
			if matches then ids[#ids + 1] = itemID end
		end
		if selectedItemID and not list[selectedItemID] then selectedItemID = nil end
		FauxScrollFrame_Update(scroll, #ids, #rows, 20)
		local offset = FauxScrollFrame_GetOffset(scroll)
		for index, row in ipairs(rows) do
			local itemID = ids[offset + index]
			row.itemID = itemID
			if itemID then
				local itemName = GetItemInfo(itemID) or ("Item " .. itemID)
				row.text:SetText(itemName .. " (" .. itemID .. ")")
				if itemID == selectedItemID then row:LockHighlight() else row:UnlockHighlight() end
				row:Show()
			else
				row:UnlockHighlight()
				row:Hide()
			end
		end
		if #ids == 0 then
			emptyText:SetText(#allIDs == 0 and "No items in this list." or "No items match the search.")
			emptyText:Show()
		else
			emptyText:Hide()
		end
		if selectedItemID then removeSelected:Enable() else removeSelected:Disable() end
		if #allIDs > 0 then resetList:Enable() else resetList:Disable() end
	end
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, 20, refresh)
	end)
	addRefresh(panel, refresh)
	return {
		input = input,
		search = search,
		add = add,
		scroll = scroll,
		rows = rows,
		removeSelected = removeSelected,
		reset = resetList,
	}
end

function Options:OnInitialize()
	self.panels = {}
	self:BuildPanels()
	_G.BINDING_HEADER_K2040_CRAP_FILTER = KCF.displayName
	_G.BINDING_NAME_KCF_MARK_MOUSEOVER_CRAP = "Mark mouseover item as Always Crap"
	_G.BINDING_NAME_KCF_MARK_MOUSEOVER_KEEP = "Mark mouseover item as Always Keep"
	_G.SLASH_K2040CRAPFILTER1 = "/kcf"
	_G.SlashCmdList.K2040CRAPFILTER = function(message)
		Options:HandleSlashCommand(message)
	end
end

function Options:OnEnable()
	self:RefreshAll()
end

function Options:BuildRootPanel()
	local panel = createPanel("Root", KCF.displayName)
	addHeading(panel, KCF.displayName, -16)
	addText(panel, "Sort loot, sell junk, and process profession items. Always Keep protects items from automatic cleanup.", 16, -52, 540)
	createCheckBox(panel, "Enabled", "Enable " .. KCF.displayName, "Turns the addon on or off.", function()
		return KCF.db.enabled
	end, function(value)
		KCF.db.enabled = value
	end, 16, -124)
	createWideButton(panel, "OpenProcessBar", "Open profession processing", function()
		KCF.modules.Professions:ToggleProcessBar(true)
	end, -168)
	createWideButton(panel, "ScanNow", "Rescan bags", function()
		KCF.modules.Professions:RequestScan()
		KCF:RefreshOptions()
	end, -202)
	createWideButton(panel, "OpenQuickLists", "Open quick Keep/Crap lists", function()
		KCF.modules.QuickLists:ToggleWindow(true)
	end, -236)
	addText(panel, "The profession window picks the next item for you. Each cast still needs one click. Use /kcf lists for the quick lists.", 16, -278, 540)
	setPanelContentHeight(panel, 350)
	self.rootPanel = panel
	self.panels[#self.panels + 1] = panel
end

function Options:BuildGeneralPanel()
	local panel = createPanel("General", "Loot, Sell & Auto-Destroy", self.rootPanel.name)
	addHeading(panel, "Loot, sell, and auto-destroy", -16)
	addText(panel, "Choose what the addon loots, sells, or destroys. Each action has its own setting.", 16, -48, 540)
	createCheckBox(panel, "AutoLootCrap", "Automatically loot items classified as crap", "Loots items marked Crap. Bind-on-pickup warnings still need your confirmation.", function()
		return KCF.db.loot.autoLootCrap
	end, function(value)
		KCF.db.loot.autoLootCrap = value
	end, 16, -104)
	createCheckBox(panel, "AutoSellCrap", "Automatically sell crap at merchants", "Sells marked Crap when you open a merchant. Always Keep and profession items are skipped.", function()
		return KCF.db.merchant.autoSellCrap
	end, function(value)
		KCF.db.merchant.autoSellCrap = value
	end, 16, -134)
	createCheckBox(panel, "AutoDestroy", "Automatically destroy newly looted crap", "Only destroys Crap added during the current loot window. Items already in your bags are safe.", function()
		return KCF.db.destroy.enabled
	end, function(value)
		KCF.db.destroy.enabled = value
	end, 16, -164)
	createSlider(panel, "FreeSlotThreshold", "Destroy only when free bag slots are at or below", 0, 16, 1, function()
		return KCF.db.destroy.freeSlotThreshold
	end, function(value)
		KCF.db.destroy.freeSlotThreshold = value
	end, 26, -218, 320)
	createDropDown(panel, "DestroyQualityCap", "Highest quality eligible for automatic destruction", {
		{ value = 0, label = "Poor only" },
		{ value = 1, label = "Common or lower" },
	}, function()
		return KCF.db.destroy.maxQuality
	end, function(value)
		KCF.db.destroy.maxQuality = value
	end, 8, -262, 350)
	createCheckBox(panel, "PauseTradeskills", "Pause auto-destroy while a tradeskill window is open", "Stops cleanup while you craft or use a profession window.", function()
		return KCF.db.destroy.pauseTradeskills
	end, function(value)
		KCF.db.destroy.pauseTradeskills = value
	end, 16, -336)
	createCheckBox(panel, "NoDestroyGroup", "Do not auto-destroy while in a party", nil, function()
		return KCF.db.destroy.doNotDestroyInGroup
	end, function(value)
		KCF.db.destroy.doNotDestroyInGroup = value
	end, 16, -366)
	createCheckBox(panel, "NoDestroyRaid", "Do not auto-destroy while in a raid", nil, function()
		return KCF.db.destroy.doNotDestroyInRaid
	end, function(value)
		KCF.db.destroy.doNotDestroyInRaid = value
	end, 16, -396)
	createCheckBox(panel, "DestroyAnnounce", "Show auto-destroy confirmations in chat", nil, function()
		return KCF.db.destroy.announce
	end, function(value)
		KCF.db.destroy.announce = value
	end, 16, -426)
	setPanelContentHeight(panel, 476)
	self.panels[#self.panels + 1] = panel
end

function Options:BuildQualityPanel()
	local panel = createPanel("Quality", "Quality & Value", self.rootPanel.name)
	addHeading(panel, "Quality and vendor value", -16)
	addText(panel, "These settings only decide which items are marked Crap. Looting, selling, and destroying are set elsewhere.", 16, -48, 540)
	createCheckBox(panel, "ProtectQuestItems", "Always protect quest-category items", "Quest items are never marked Crap automatically.", function()
		return KCF.db.classification.protectQuestItems
	end, function(value)
		KCF.db.classification.protectQuestItems = value
	end, 16, -108)
	addHeading(panel, "Quality rules", -154)
	addText(panel, "Checked qualities are always marked Crap. Vendor value does not affect them.", 16, -184, 540)
	local qualities = {
		{ 0, "Poor-quality" },
		{ 1, "Common-quality" },
		{ 2, "Uncommon-quality" },
		{ 3, "Rare-quality" },
		{ 4, "Epic-quality" },
	}
	for index, entry in ipairs(qualities) do
		local quality, label = entry[1], entry[2]
		createCheckBox(panel, "Quality" .. quality, "Mark all " .. label .. " items as Crap", "Marks every item of this quality as Crap.", function()
			return KCF.db.classification.qualities[quality]
		end, function(value)
			KCF.db.classification.qualities[quality] = value
		end, 16, -242 - ((index - 1) * 30))
	end
	addHeading(panel, "Vendor-value rule", -404)
	addText(panel, "Use this rule to mark cheap items as Crap. Its value, stack, and quality settings apply only here.", 16, -434, 540)
	createCheckBox(panel, "VendorValueEnabled", "Use vendor value to classify cheap items as Crap", "Marks items at or below the chosen value as Crap, up to the selected quality.", function()
		return KCF.db.classification.vendorValue.enabled
	end, function(value)
		KCF.db.classification.vendorValue.enabled = value
	end, 16, -492)
	createMoneyInput(panel, "VendorThreshold", "Maximum value for the vendor-value rule", function()
		return KCF.db.classification.vendorValue.copper
	end, function(value)
		KCF.db.classification.vendorValue.copper = value
	end, 26, -530)
	createCheckBox(panel, "UseStackValue", "Use the entire stack's value instead of one item's value", "Off compares one item. On compares the whole stack.", function()
		return KCF.db.classification.vendorValue.useStackValue
	end, function(value)
		KCF.db.classification.vendorValue.useStackValue = value
	end, 16, -594)
	createDropDown(panel, "VendorQualityCap", "Vendor-value rule applies only to these qualities", {
		{ value = 0, label = "Poor only" },
		{ value = 1, label = "Common or lower" },
		{ value = 2, label = "Uncommon or lower" },
	}, function()
		return KCF.db.classification.vendorValue.maxQuality
	end, function(value)
		KCF.db.classification.vendorValue.maxQuality = value
	end, 8, -638, 350)
	addText(panel, "Example: with a 5 silver limit for Common items, a Common item worth 4 silver is Crap. Uncommon items are not affected.", 16, -708, 540)
	setPanelContentHeight(panel, 770)
	self.panels[#self.panels + 1] = panel
end

function Options.AddCategoryMode(_self, panel, category, label, x, y, withLevelLimit)
	createDropDown(panel, "Mode_" .. category, label, MODE_VALUES, function()
		return KCF.db.classification.categories[category]
	end, function(value)
		KCF.db.classification.categories[category] = value
	end, x, y, 250)
	if withLevelLimit then
		createCheckBox(panel, "LowerLevel_" .. category, "Only classify lower usable tiers as crap", "Keeps the best tier you can use and marks only lower tiers as Crap.", function()
			return KCF.db.classification.lowerLevelOnly[category]
		end, function(value)
			KCF.db.classification.lowerLevelOnly[category] = value
		end, x + 8, y - 64)
	end
end

function Options:BuildConsumablesPanel()
	local panel = createPanel("Consumables", "Food, Water & Potions", self.rootPanel.name)
	addHeading(panel, "Food, water, and potions", -16)
	addText(panel, "Food and water use their item spell when possible. Unusual items use the Food & Drink setting.", 16, -48, 540)
	self:AddCategoryMode(panel, "food", "Food", 8, -106, true)
	self:AddCategoryMode(panel, "water", "Water", 8, -220, true)
	self:AddCategoryMode(panel, "foodAndDrink", "Combined or unrecognized Food & Drink", 8, -334, true)
	self:AddCategoryMode(panel, "potion", "Potions", 8, -448, true)
	setPanelContentHeight(panel, 578)
	self.panels[#self.panels + 1] = panel
end

function Options:BuildMaterialsPanel()
	local panel = createPanel("Materials", "Cloth, Scrolls & Tradeskills", self.rootPanel.name)
	addHeading(panel, "Cloth, scrolls, and tradeskill materials", -16)
	addText(panel, "Set rules for cloth, scrolls, and other trade goods.", 16, -48, 540)
	self:AddCategoryMode(panel, "cloth", "Cloth", 8, -100, false)
	self:AddCategoryMode(panel, "scroll", "Scrolls", 8, -178, true)
	self:AddCategoryMode(panel, "tradeGoods", "Other trade goods", 8, -292, false)
	addHeading(panel, "Always-loot cloth types", -378)
	addText(panel, "These settings only decide which cloth to loot. Other rules still apply afterward.", 16, -410, 540)
	for index, cloth in ipairs(KCF.CLOTH_ITEMS) do
		local itemID = cloth.itemID
		local function getLabel()
			local itemName = GetItemInfo(itemID) or cloth.fallbackName
			return "Loot [" .. itemName .. "]"
		end
		local checkBox = createCheckBox(panel, "LootCloth_" .. itemID, getLabel(), "Always loot this cloth.", function()
			return KCF.db.loot.cloth[itemID]
		end, function(value)
			KCF.db.loot.cloth[itemID] = value
		end, 16, -474 - ((index - 1) * 30))
		addRefresh(panel, function() setLabel(checkBox, getLabel()) end)
	end
	setPanelContentHeight(panel, 716)
	self.panels[#self.panels + 1] = panel
end

function Options:BuildCorpsePanel()
	local panel = createPanel("Corpse", "Corpse Overrides", self.rootPanel.name)
	addHeading(panel, "Corpse overrides", -16)
	addText(panel, "For selected corpse types, loot everything first so the corpse can be gathered. Normal rules run afterward.", 16, -48, 540)
	local labels = {
		skinnable = "Loot everything from skinnable corpses",
		mineable = "Loot everything from mineable corpses",
		gatherable = "Loot everything from gatherable corpses",
		engineerable = "Loot everything from engineerable corpses",
	}
	local order = { "skinnable", "mineable", "gatherable", "engineerable" }
	for index, key in ipairs(order) do
		createCheckBox(panel, "Corpse_" .. key, labels[key], nil, function()
			return KCF.db.loot.corpse[key]
		end, function(value)
			KCF.db.loot.corpse[key] = value
		end, 16, -112 - ((index - 1) * 32))
	end
	createCheckBox(panel, "CorpseRequireProfession", "Require the matching profession before forcing loot", "If the addon cannot confirm the corpse type or your profession, it uses normal loot rules.", function()
		return KCF.db.loot.corpse.requireProfession
	end, function(value)
		KCF.db.loot.corpse.requireProfession = value
	end, 16, -260)
	setPanelContentHeight(panel, 320)
	self.panels[#self.panels + 1] = panel
end

function Options:BuildAlwaysKeepPanel()
	local panel = createPanel("AlwaysKeepList", "Always Keep", self.rootPanel.name)
	addHeading(panel, "Always Keep", -16)
	addText(panel, "Items here are never marked Crap or destroyed. The rule applies to every copy of that item.", 16, -48, 540)
	createItemList(panel, "AlwaysKeep", "Always Keep", function()
		return KCF.db.classification.alwaysKeep
	end, function(itemID)
		KCF.db.classification.alwaysKeep[itemID] = true
		KCF.db.classification.alwaysCrap[itemID] = nil
		return true
	end, function(itemID)
		KCF.db.classification.alwaysKeep[itemID] = nil
		return true
	end, 16, -112, 350, 8)
	setPanelContentHeight(panel, 430)
	self.panels[#self.panels + 1] = panel
end

function Options:BuildAlwaysCrapPanel()
	local panel = createPanel("AlwaysCrapList", "Always Crap", self.rootPanel.name)
	addHeading(panel, "Always Crap", -16)
	addText(panel, "Items here are always marked Crap. Adding the same item to Always Keep replaces this rule.", 16, -48, 540)
	createItemList(panel, "AlwaysCrap", "Always Crap", function()
		return KCF.db.classification.alwaysCrap
	end, function(itemID)
		KCF.db.classification.alwaysCrap[itemID] = true
		KCF.db.classification.alwaysKeep[itemID] = nil
		return true
	end, function(itemID)
		KCF.db.classification.alwaysCrap[itemID] = nil
		return true
	end, 16, -112, 350, 8)
	setPanelContentHeight(panel, 430)
	self.panels[#self.panels + 1] = panel
end

function Options:BuildQuickPanel()
	local panel = createPanel("Quick", "Quick Classification", self.rootPanel.name)
	addHeading(panel, "Quick classification", -16)
	addText(panel, "Hold the exact modifier and right-click a supported bag item. This shortcut is disabled in combat.", 16, -48, 540)
	createCheckBox(panel, "QuickRightClick", "Enable modifier + right-click", nil, function()
		return KCF.db.quick.rightClickEnabled
	end, function(value)
		KCF.db.quick.rightClickEnabled = value
	end, 16, -110)
	createDropDown(panel, "QuickCrapModifier", "Always Crap modifier", MODIFIER_VALUES, function()
		return KCF.db.quick.crapModifier
	end, function(value)
		KCF.db.quick.crapModifier = value
	end, 8, -152, 350)
	createDropDown(panel, "QuickKeepModifier", "Always Keep modifier", MODIFIER_VALUES, function()
		return KCF.db.quick.keepModifier
	end, function(value)
		KCF.db.quick.keepModifier = value
	end, 8, -228, 350)
	createCheckBox(panel, "QuickAnnounce", "Show quick-classification confirmations in chat", nil, function()
		return KCF.db.quick.announce
	end, function(value)
		KCF.db.quick.announce = value
	end, 16, -306)
	createCheckBox(panel, "QuickOverlay", "Show a short green/red overlay on the item", nil, function()
		return KCF.db.quick.overlay
	end, function(value)
		KCF.db.quick.overlay = value
	end, 16, -336)
	addText(panel, "You can also set mouse-over shortcuts in WoW's Key Bindings under " .. KCF.displayName .. ".", 16, -382, 540)
	setPanelContentHeight(panel, 468)
	self.panels[#self.panels + 1] = panel
end

function Options:BuildAdiBagsPanel()
	local panel = createPanel("AdiBags", "AdiBags Integration", self.rootPanel.name)
	addHeading(panel, "Optional AdiBags integration", -16)
	addText(panel, "Uses AdiBags' Junk result when available. Always Keep still wins.", 16, -48, 540)
	createCheckBox(panel, "AdiBagsJunk", "Treat items classified as Junk by AdiBags as crap", nil, function()
		return KCF.db.adibags.treatJunkAsCrap
	end, function(value)
		KCF.db.adibags.treatJunkAsCrap = value
	end, 16, -106)
	local status = addText(panel, "", 20, -154, 520)
	addRefresh(panel, function()
		local classification = KCF.modules.Classification
		local adiBags = classification and classification:GetAdiBagsAddon()
		if adiBags then
			status:SetText("AdiBags Junk detection is ready.")
			status:SetTextColor(0.2, 1, 0.2)
		else
			status:SetText("AdiBags Junk detection is unavailable. Normal rules still work.")
			status:SetTextColor(1, 0.82, 0)
		end
	end)
	setPanelContentHeight(panel, 240)
	self.panels[#self.panels + 1] = panel
end

function Options:BuildProfessionPanel(processor, title)
	local panel = createPanel("Profession_" .. processor, title, self.rootPanel.name)
	addHeading(panel, title, -16)
	addText(panel, "The addon picks the next matching item. Click once per cast; it scans your bags again afterward.", 16, -48, 540)
	createCheckBox(panel, "Profession_" .. processor .. "_Enabled", "Enable " .. title, nil, function()
		return KCF.db.professions[processor].enabled
	end, function(value)
		KCF.db.professions[processor].enabled = value
	end, 16, -112)
	createDropDown(panel, "Profession_" .. processor .. "_Mode", "Processing mode", PROCESS_MODE_VALUES, function()
		return KCF.db.professions[processor].mode
	end, function(value)
		KCF.db.professions[processor].mode = value
	end, 8, -150, 350)
	local function addTo(listName, itemID)
		local config = KCF.db.professions[processor]
		config[listName][itemID] = true
		config[listName == "always" and "never" or "always"][itemID] = nil
		return true
	end
	local function removeFrom(listName, itemID)
		KCF.db.professions[processor][listName][itemID] = nil
		return true
	end
	createItemList(panel, "Profession_" .. processor .. "_Always", "Always Process", function()
		return KCF.db.professions[processor].always
	end, function(itemID)
		return addTo("always", itemID)
	end, function(itemID)
		return removeFrom("always", itemID)
	end, 16, -228, 350, 8)
	createItemList(panel, "Profession_" .. processor .. "_Never", "Never Process", function()
		return KCF.db.professions[processor].never
	end, function(itemID)
		return addTo("never", itemID)
	end, function(itemID)
		return removeFrom("never", itemID)
	end, 16, -544, 350, 8)
	setPanelContentHeight(panel, 870)
	self.panels[#self.panels + 1] = panel
end

function Options:BuildInventoryPanel()
	local panel = createPanel("Inventory", "Inventory & Processing", self.rootPanel.name)
	addHeading(panel, "Inventory and processing", -16)
	addText(panel, "Profession items are protected from auto-destroy. Always Keep blocks them unless you add an Always Process rule.", 16, -48, 540)
	local status = addText(panel, "", 16, -112, 540, "GameFontNormal")
	local function refreshStatus()
		local itemKinds, itemCount = 0, 0
		local seen = {}
		KCF:ForEachBagSlot(function(_, _, itemID, count)
			if KCF:Classify(itemID, count) == KCF.RESULT_CRAP then
				if not seen[itemID] then itemKinds = itemKinds + 1; seen[itemID] = true end
				itemCount = itemCount + count
			end
		end)
		status:SetText("Bags: " .. itemCount .. " item(s) across " .. itemKinds .. " Crap item type(s).")
	end
	addRefresh(panel, refreshStatus)
	createButton(panel, "InventoryRefresh", "Refresh bag summary", function()
		refreshStatus()
		KCF.modules.Professions:RequestScan()
	end, 16, -160, 210)
	createButton(panel, "InventoryProcessBar", "Process profession items", function()
		KCF.modules.Professions:ToggleProcessBar(true)
	end, 16, -194, 250)
	createCheckBox(panel, "ProfessionAutoLootResults", "Auto-loot profession results", "After a cast started here, loot the immediate item-only result window. Other loot windows stay manual.", function()
		return KCF.db.professions.autoLootResults
	end, function(value)
		KCF.db.professions.autoLootResults = value
	end, 16, -236)
	addText(panel, "Items already in your bags are never treated as newly looted. When the addon is unsure, it keeps them.", 16, -286, 540)
	setPanelContentHeight(panel, 390)
	self.panels[#self.panels + 1] = panel
end

function Options:BuildPanels()
	self:BuildRootPanel()
	self:BuildGeneralPanel()
	self:BuildQualityPanel()
	self:BuildConsumablesPanel()
	self:BuildMaterialsPanel()
	self:BuildCorpsePanel()
	self:BuildAlwaysKeepPanel()
	self:BuildAlwaysCrapPanel()
	self:BuildQuickPanel()
	self:BuildAdiBagsPanel()
	self:BuildProfessionPanel("disenchant", "Disenchant")
	self:BuildProfessionPanel("milling", "Milling")
	self:BuildProfessionPanel("prospecting", "Prospecting")
	self:BuildInventoryPanel()
	KCF.uiPanels = self.panels
end

function Options:RefreshAll()
	for _, panel in ipairs(self.panels) do
		if panel.refresh then panel:refresh() end
	end
end

function Options:Open()
	InterfaceOptionsFrame_OpenToCategory(self.rootPanel)
	InterfaceOptionsFrame_OpenToCategory(self.rootPanel)
end

function Options:HandleSlashCommand(message)
	message = (message or ""):lower():match("^%s*(.-)%s*$")
	if message == "process" then
		KCF.modules.Professions:ToggleProcessBar()
	elseif message == "lists" then
		KCF.modules.QuickLists:ToggleWindow()
	elseif message == "scan" then
		KCF.modules.Professions:RequestScan()
		self:RefreshAll()
	elseif message == "help" then
		KCF:Print("/kcf opens settings; /kcf lists toggles quick Keep/Crap lists; /kcf process toggles profession processing; /kcf scan refreshes bags.")
	else
		self:Open()
	end
end

function KCF.RefreshOptions(_self)
	if Options.panels then Options:RefreshAll() end
end
