local _, KCF = ...

local _G = _G
local ClearCursor = _G.ClearCursor
local CreateFrame = _G.CreateFrame
local FauxScrollFrame_GetOffset = _G.FauxScrollFrame_GetOffset
local FauxScrollFrame_OnVerticalScroll = _G.FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_Update = _G.FauxScrollFrame_Update
local GetCursorInfo = _G.GetCursorInfo
local GetCursorPosition = _G.GetCursorPosition
local GetItemInfo = _G.GetItemInfo
local StaticPopup_Show = _G.StaticPopup_Show
local UIParent = _G.UIParent
local cos = math.cos
local deg = math.deg
local find = string.find
local floor = math.floor
local ipairs = ipairs
local lower = string.lower
local max = math.max
local min = math.min
local pcall = pcall
local rad = math.rad
local sin = math.sin
local tostring = tostring
local type = type

local QuickLists = {}
KCF:RegisterModule("QuickLists", QuickLists)

local BROKER_NAME = "K2040_CrapFilter"
local ICON = "Interface\\AddOns\\K2040_CrapFilter\\Media\\MinimapIcon"
local RESET_DIALOG = "K2040_CRAP_FILTER_QUICK_RESET_LIST"
local WINDOW_DEFAULT_WIDTH = 460
local WINDOW_DEFAULT_HEIGHT = 330
local WINDOW_MIN_WIDTH = 460
local WINDOW_MIN_HEIGHT = 330
local WINDOW_MAX_WIDTH = 900
local WINDOW_MAX_HEIGHT = 650
local WINDOW_MARGIN = 12
local SECTION_GAP = 12
local SECTION_TOP = 36
local SECTION_BOTTOM = 32
local LIST_TOP = 76
local SECTION_BUTTON_SPACE = 36
local ROW_HEIGHT = 18
local MAX_VISIBLE_ROWS = 24

local function clamp(value, minimum, maximum)
	return max(minimum, min(maximum, value))
end

function QuickLists.CalculateWindowLayout(_self, width, height)
	width = clamp(tonumber(width) or WINDOW_DEFAULT_WIDTH, WINDOW_MIN_WIDTH, WINDOW_MAX_WIDTH)
	height = clamp(tonumber(height) or WINDOW_DEFAULT_HEIGHT, WINDOW_MIN_HEIGHT, WINDOW_MAX_HEIGHT)
	local sectionWidth = floor((width - (WINDOW_MARGIN * 2) - SECTION_GAP) / 2)
	local sectionHeight = height - SECTION_TOP - SECTION_BOTTOM
	local availableListHeight = max(ROW_HEIGHT, sectionHeight - LIST_TOP - SECTION_BUTTON_SPACE)
	local visibleRows = clamp(floor(availableListHeight / ROW_HEIGHT), 1, MAX_VISIBLE_ROWS)
	return width, height, sectionWidth, sectionHeight, visibleRows
end

local function getOptionalLibrary(name)
	local libStub = _G.LibStub
	if not libStub then return nil end
	local ok, library = pcall(function()
		if type(libStub) == "table" and type(libStub.GetLibrary) == "function" then
			return libStub:GetLibrary(name, true)
		elseif type(libStub) == "function" then
			return libStub(name, true)
		end
	end)
	return ok and library or nil
end

local function addBackdrop(frame)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
end

local function setCompactButtonFont(button)
	if button.SetNormalFontObject then button:SetNormalFontObject(_G.GameFontNormalSmall) end
	if button.SetHighlightFontObject then button:SetHighlightFontObject(_G.GameFontHighlightSmall) end
	if button.SetDisabledFontObject then button:SetDisabledFontObject(_G.GameFontDisableSmall) end
end

function QuickLists:OnInitialize()
	if _G.StaticPopupDialogs and not _G.StaticPopupDialogs[RESET_DIALOG] then
		_G.StaticPopupDialogs[RESET_DIALOG] = {
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
	end
	KCF:RegisterEvent("ADDON_LOADED", self, "OnAddonLoaded")
end

function QuickLists:OnEnable()
	self:CreateWindow()
	self:TryRegisterBroker()
	if not self.dbIconRegistered then self:CreateMinimapButton() end
end

function QuickLists.GetList(_self, rule)
	if rule == KCF.RESULT_KEEP then return KCF.db.classification.alwaysKeep end
	return KCF.db.classification.alwaysCrap
end

function QuickLists.AddCursorRule(_self, rule)
	if type(GetCursorInfo) ~= "function" then return false end
	local cursorType, itemID, itemLink = GetCursorInfo()
	if cursorType ~= "item" then return false end
	itemID = KCF:ParseItemID(itemLink or itemID)
	if not itemID or not KCF:SetItemRule(itemID, rule) then return false end
	if ClearCursor then ClearCursor() end
	return true
end

function QuickLists:CreateListSection(parent, key, title, rule, titleColor)
	local section = CreateFrame("Frame", "K2040CrapFilter_QuickLists_" .. key, parent)
	section:SetWidth(212)
	section:SetHeight(232)
	addBackdrop(section)

	local heading = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	heading:SetPoint("TOPLEFT", 10, -8)
	heading:SetText(title)
	heading:SetTextColor(titleColor[1], titleColor[2], titleColor[3])

	local dropHint = section:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	dropHint:SetPoint("TOPLEFT", 10, -27)
	dropHint:SetText("Drag an item anywhere in this pane")

	local function receiveItem()
		local cursorType = type(GetCursorInfo) == "function" and GetCursorInfo()
		if cursorType ~= "item" then return end
		if not self:AddCursorRule(rule) then
			KCF:Print("Drag a bag item onto the " .. title .. " area.")
		end
	end
	local function receiveItemOnMouseUp(_, mouseButton)
		if mouseButton == "LeftButton" then receiveItem() end
	end
	section:EnableMouse(true)
	section:SetScript("OnReceiveDrag", receiveItem)
	section:SetScript("OnMouseUp", receiveItemOnMouseUp)

	local searchLabel = section:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	searchLabel:SetPoint("TOPLEFT", 10, -51)
	searchLabel:SetText("Search")
	local search = CreateFrame("EditBox", "K2040CrapFilter_QuickLists_" .. key .. "_Search", section, "InputBoxTemplate")
	search:SetPoint("TOPLEFT", 60, -45)
	search:SetWidth(142)
	search:SetHeight(20)
	search:SetAutoFocus(false)

	local scroll = CreateFrame("ScrollFrame", "K2040CrapFilter_QuickLists_" .. key .. "_Scroll", section, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -LIST_TOP)
	scroll:SetWidth(166)
	scroll:SetHeight(100)
	scroll:SetScript("OnReceiveDrag", receiveItem)
	scroll:SetScript("OnMouseUp", receiveItemOnMouseUp)

	local selectedItemID
	local rows = {}
	local visibleRows = 5
	local refresh
	for index = 1, MAX_VISIBLE_ROWS do
		local row = CreateFrame("Button", "K2040CrapFilter_QuickLists_" .. key .. "_Row" .. index, section)
		row:SetPoint("TOPLEFT", 10, -LIST_TOP - ((index - 1) * ROW_HEIGHT))
		row:SetWidth(166)
		row:SetHeight(ROW_HEIGHT - 1)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", 3, 0)
		row.text:SetPoint("RIGHT", -3, 0)
		row.text:SetJustifyH("LEFT")
		row:RegisterForClicks("LeftButtonUp")
		row:SetScript("OnReceiveDrag", receiveItem)
		row:SetScript("OnClick", function(rowFrame)
			if not rowFrame.itemID then return end
			selectedItemID = rowFrame.itemID
			refresh()
		end)
		row:SetScript("OnEnter", function(rowFrame)
			if not rowFrame.itemID then return end
			_G.GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
			_G.GameTooltip:SetHyperlink("item:" .. rowFrame.itemID)
			_G.GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
		rows[index] = row
	end

	local emptyText = section:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	emptyText:SetPoint("CENTER", section, "TOP", 0, -158)
	emptyText:SetText("No items in this list.")

	local remove = CreateFrame("Button", "K2040CrapFilter_QuickLists_" .. key .. "_RemoveSelected", section, "UIPanelButtonTemplate")
	remove:SetPoint("BOTTOMLEFT", 10, 8)
	remove:SetWidth(112)
	remove:SetHeight(20)
	remove:SetText("Remove selected")
	setCompactButtonFont(remove)
	remove:SetScript("OnClick", function()
		if not selectedItemID then return end
		local itemID = selectedItemID
		selectedItemID = nil
		KCF:SetItemRule(itemID, nil)
	end)

	local reset = CreateFrame("Button", "K2040CrapFilter_QuickLists_" .. key .. "_Reset", section, "UIPanelButtonTemplate")
	reset:SetPoint("BOTTOMRIGHT", -10, 8)
	reset:SetWidth(64)
	reset:SetHeight(20)
	reset:SetText("Reset list")
	setCompactButtonFont(reset)
	reset:SetScript("OnClick", function()
		local list = self:GetList(rule)
		if not next(list) then return end
		if not StaticPopup_Show then return end
		StaticPopup_Show(RESET_DIALOG, title, nil, {
			reset = function()
				for itemID in pairs(list) do list[itemID] = nil end
				selectedItemID = nil
				KCF:NotifyRulesChanged()
			end,
		})
	end)

	refresh = function()
		local list = self:GetList(rule)
		local allIDs = KCF:GetSortedItemIDs(list)
		local ids = {}
		local query = lower(search:GetText() or ""):match("^%s*(.-)%s*$")
		for _, itemID in ipairs(allIDs) do
			local itemName = GetItemInfo(itemID) or ("Item " .. itemID)
			if query == "" or find(lower(itemName), query, 1, true) or find(tostring(itemID), query, 1, true) then
				ids[#ids + 1] = itemID
			end
		end
		if selectedItemID and not list[selectedItemID] then selectedItemID = nil end
		FauxScrollFrame_Update(scroll, #ids, visibleRows, ROW_HEIGHT)
		local offset = FauxScrollFrame_GetOffset(scroll)
		for index, row in ipairs(rows) do
			local itemID = index <= visibleRows and ids[offset + index]
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
		if selectedItemID then remove:Enable() else remove:Disable() end
		if #allIDs > 0 then reset:Enable() else reset:Disable() end
	end
	search:SetScript("OnTextChanged", function()
		selectedItemID = nil
		refresh()
	end)
	search:SetScript("OnEscapePressed", function(editBox)
		editBox:SetText("")
		editBox:ClearFocus()
	end)
	scroll:SetScript("OnVerticalScroll", function(scrollFrame, offset)
		FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, ROW_HEIGHT, refresh)
	end)

	local function layout(width, height, rowCount)
		section:SetWidth(width)
		section:SetHeight(height)
		search:SetWidth(max(90, width - 70))

		local availableListHeight = max(ROW_HEIGHT, height - LIST_TOP - SECTION_BUTTON_SPACE)
		visibleRows = clamp(rowCount or floor(availableListHeight / ROW_HEIGHT), 1, #rows)
		local renderedListHeight = visibleRows * ROW_HEIGHT
		local listWidth = max(100, width - 46)
		scroll:SetWidth(listWidth)
		scroll:SetHeight(renderedListHeight)
		for _, row in ipairs(rows) do row:SetWidth(listWidth) end

		emptyText:ClearAllPoints()
		emptyText:SetPoint("TOP", section, "TOP", 0, -(LIST_TOP + floor(renderedListHeight / 2) - 6))
		reset:SetWidth(64)
		remove:SetWidth(max(94, width - 20 - 64 - 8))
		refresh()
	end

	return {
		frame = section,
		search = search,
		scroll = scroll,
		rows = rows,
		remove = remove,
		reset = reset,
		refresh = refresh,
		layout = layout,
	}
end

function QuickLists:LayoutWindow(width, height)
	if not self.frame or not self.listWidgets then return end
	local _, _, sectionWidth, sectionHeight, visibleRows = self:CalculateWindowLayout(
		width or self.frame:GetWidth(),
		height or self.frame:GetHeight()
	)
	local keep = self.listWidgets[1]
	local crap = self.listWidgets[2]

	keep.frame:ClearAllPoints()
	keep.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", WINDOW_MARGIN, -SECTION_TOP)
	crap.frame:ClearAllPoints()
	crap.frame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -WINDOW_MARGIN, -SECTION_TOP)
	keep.layout(sectionWidth, sectionHeight, visibleRows)
	crap.layout(sectionWidth, sectionHeight, visibleRows)
end

function QuickLists:CreateWindow()
	if self.frame then return end
	local frame = CreateFrame("Frame", "K2040CrapFilter_QuickLists", UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetMinResize(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT)
	frame:SetMaxResize(WINDOW_MAX_WIDTH, WINDOW_MAX_HEIGHT)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	addBackdrop(frame)

	local position = KCF.db.ui.quickLists
	frame:SetWidth(clamp(tonumber(position.width) or WINDOW_DEFAULT_WIDTH, WINDOW_MIN_WIDTH, WINDOW_MAX_WIDTH))
	frame:SetHeight(clamp(tonumber(position.height) or WINDOW_DEFAULT_HEIGHT, WINDOW_MIN_HEIGHT, WINDOW_MAX_HEIGHT))
	frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
	local function saveGeometry(window)
		local point, _, relativePoint, x, y = window:GetPoint(1)
		position.point = point or "CENTER"
		position.relativePoint = relativePoint or "CENTER"
		position.x = x or 0
		position.y = y or 0
		position.width = floor(window:GetWidth() + 0.5)
		position.height = floor(window:GetHeight() + 0.5)
	end
	frame:SetScript("OnDragStart", function(window) window:StartMoving() end)
	frame:SetScript("OnDragStop", function(window)
		window:StopMovingOrSizing()
		saveGeometry(window)
	end)
	frame:SetScript("OnShow", function(window)
		window:Raise()
		self:Refresh()
	end)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText(KCF.displayName .. " — Quick Lists")
	local close = CreateFrame("Button", "K2040CrapFilter_QuickLists_Close", frame, "UIPanelCloseButton")
	close:SetWidth(24)
	close:SetHeight(24)
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() frame:Hide() end)

	self.listWidgets = {
		self:CreateListSection(frame, "Keep", "Always Keep", KCF.RESULT_KEEP, { 0.25, 1, 0.35 }),
		self:CreateListSection(frame, "Crap", "Always Crap", KCF.RESULT_CRAP, { 1, 0.3, 0.2 }),
	}
	local help = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetPoint("BOTTOMLEFT", 16, 13)
	help:SetPoint("BOTTOMRIGHT", -32, 13)
	help:SetJustifyH("CENTER")
	help:SetHeight(24)
	help:SetWordWrap(true)
	help:SetText("Drag items into either side. Click an item to select it.")

	local resize = CreateFrame("Frame", "K2040CrapFilter_QuickLists_Resize", frame)
	resize:SetWidth(24)
	resize:SetHeight(24)
	resize:SetPoint("BOTTOMRIGHT", -2, 2)
	resize:SetFrameLevel(frame:GetFrameLevel() + 10)
	resize:EnableMouse(true)
	resize.text = resize:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	resize.text:SetPoint("BOTTOMRIGHT", -2, 2)
	resize.text:SetText("///")
	resize:SetScript("OnMouseDown", function(_, mouseButton)
		if mouseButton == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
	end)
	resize:SetScript("OnMouseUp", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			frame:StopMovingOrSizing()
			saveGeometry(frame)
		end
	end)
	resize:SetScript("OnEnter", function() resize.text:SetTextColor(1, 1, 1) end)
	resize:SetScript("OnLeave", function() resize.text:SetTextColor(1, 0.82, 0) end)

	if _G.UISpecialFrames then _G.UISpecialFrames[#_G.UISpecialFrames + 1] = frame:GetName() end
	self.frame = frame
	self.resize = resize
	frame:SetScript("OnSizeChanged", function(_, width, height)
		position.width = floor(width + 0.5)
		position.height = floor(height + 0.5)
		self:LayoutWindow(width, height)
	end)
	self:LayoutWindow(frame:GetWidth(), frame:GetHeight())
	frame:Hide()
end

function QuickLists:Refresh()
	for _, widget in ipairs(self.listWidgets or {}) do widget.refresh() end
end

function QuickLists:ToggleWindow(show)
	if not self.frame then self:CreateWindow() end
	if show == nil then show = not self.frame:IsShown() end
	if show then
		self.frame:Show()
		self:Refresh()
	else
		self.frame:Hide()
	end
end

function QuickLists:UpdateMinimapButtonPosition()
	local button = self.minimapButton
	local minimap = _G.Minimap
	if not button or not minimap or button:GetParent() ~= minimap then return end
	local angle = tonumber(KCF.db.minimap.angle) or 220
	button:ClearAllPoints()
	button:SetPoint("CENTER", minimap, "CENTER", cos(rad(angle)) * 80, sin(rad(angle)) * 80)
end

function QuickLists:UpdateMinimapAngle()
	local minimap = _G.Minimap
	if not minimap or type(GetCursorPosition) ~= "function" then return end
	local cursorX, cursorY = GetCursorPosition()
	local scale = minimap:GetEffectiveScale()
	local centerX, centerY = minimap:GetCenter()
	if not cursorX or not cursorY or not scale or not centerX or not centerY then return end
	local atan2 = math.atan2
	if not atan2 then return end
	KCF.db.minimap.angle = deg(atan2((cursorY / scale) - centerY, (cursorX / scale) - centerX))
	self:UpdateMinimapButtonPosition()
end

function QuickLists:CreateMinimapButton()
	if self.minimapButton or self.dbIconRegistered or not _G.Minimap then return end
	local button = CreateFrame("Button", "K2040CrapFilter_MinimapButton", _G.Minimap)
	button:SetWidth(33)
	button:SetHeight(33)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(_G.Minimap:GetFrameLevel() + 8)
	button:SetToplevel(true)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")

	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetWidth(22)
	background:SetHeight(22)
	background:SetPoint("TOPLEFT", 5, -4)
	background:SetVertexColor(0.18, 0.18, 0.18)
	button.background = background

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetWidth(24)
	icon:SetHeight(24)
	icon:SetPoint("TOPLEFT", 4, -3)
	icon:SetTexCoord(0.03, 0.97, 0.03, 0.97)
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetWidth(52)
	border:SetHeight(52)
	border:SetPoint("TOPLEFT", 0, 0)
	button.border = border

	button:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			local options = KCF.modules.Options
			if options then options:Open() end
		else
			self:ToggleWindow()
		end
	end)
	button:SetScript("OnEnter", function(frame)
		_G.GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
		_G.GameTooltip:AddLine(KCF.displayName)
		_G.GameTooltip:AddLine("Left-click: open quick Keep/Crap lists", 1, 1, 1)
		_G.GameTooltip:AddLine("Right-click: open full settings", 1, 1, 1)
		_G.GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		_G.GameTooltip:Hide()
	end)
	button:SetScript("OnDragStart", function(frame)
		if frame:GetParent() ~= _G.Minimap then return end
		frame:SetScript("OnUpdate", function() self:UpdateMinimapAngle() end)
	end)
	button:SetScript("OnDragStop", function(frame) frame:SetScript("OnUpdate", nil) end)

	self.minimapButton = button
	self:UpdateMinimapButtonPosition()
end

function QuickLists:TryRegisterBroker()
	if not self.broker then
		local brokerLibrary = getOptionalLibrary("LibDataBroker-1.1")
		if brokerLibrary and type(brokerLibrary.NewDataObject) == "function" then
			local data = {
				type = "launcher",
				label = KCF.displayName,
				text = KCF.displayName,
				icon = ICON,
				OnClick = function(_, mouseButton)
					if mouseButton == "RightButton" then
						local options = KCF.modules.Options
						if options then options:Open() end
					else
						QuickLists:ToggleWindow()
					end
				end,
				OnTooltipShow = function(tooltip)
					tooltip:AddLine(KCF.displayName)
					tooltip:AddLine("Left-click: open quick Keep/Crap lists", 1, 1, 1)
					tooltip:AddLine("Right-click: open full settings", 1, 1, 1)
				end,
			}
			local ok, broker = pcall(brokerLibrary.NewDataObject, brokerLibrary, BROKER_NAME, data)
			if ok then self.broker = broker end
		end
	end

	if self.broker and not self.dbIconRegistered then
		local iconLibrary = getOptionalLibrary("LibDBIcon-1.0")
		if iconLibrary and type(iconLibrary.Register) == "function" then
			local ok = pcall(iconLibrary.Register, iconLibrary, BROKER_NAME, self.broker, KCF.db.minimap)
			if ok then
				self.dbIconRegistered = true
				if self.minimapButton then self.minimapButton:Hide() end
			end
		end
	end
	return self.broker ~= nil
end

function QuickLists:OnAddonLoaded()
	self:TryRegisterBroker()
	if not self.dbIconRegistered then self:CreateMinimapButton() end
end

function KCF.ToggleQuickLists(_self, show)
	QuickLists:ToggleWindow(show)
end
