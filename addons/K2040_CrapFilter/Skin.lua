local _, KCF = ...

local _G = _G
local EnumerateFrames = _G.EnumerateFrames
local hooksecurefunc = _G.hooksecurefunc
local ipairs = ipairs
local pcall = pcall
local select = select
local type = type
local find = string.find
local sub = string.sub

local Skin = {}
KCF:RegisterModule("Skin", Skin)

local PREFIX = "K2040CrapFilter_"
local MAX_PARENT_DEPTH = 16

local THEMES = {
	modern = {
		background = { 0.055, 0.055, 0.055, 0.96 },
		panel = { 0.09, 0.09, 0.09, 1 },
		input = { 0.035, 0.035, 0.035, 1 },
		border = { 0, 0, 0, 1 },
		accent = { 0.78, 0.64, 0.36, 1 },
		text = { 0.95, 0.95, 0.95, 1 },
		disabled = { 0.45, 0.45, 0.45, 1 },
	},
}

local BLUE_BUTTON = { 0, 0, 1, 1 }

local function copyColor(color)
	return { color[1], color[2], color[3], color[4] or 1 }
end

local function mediaColor(value, fallback)
	if type(value) == "table"
		and type(value[1]) == "number"
		and type(value[2]) == "number"
		and type(value[3]) == "number" then
		return { value[1], value[2], value[3], value[4] or fallback[4] or 1 }
	end
	return copyColor(fallback)
end

local function getElvUI()
	local container = _G.ElvUI
	if type(container) ~= "table" then return nil, nil end
	local engine = container[1]
	if type(engine) ~= "table" or type(engine.GetModule) ~= "function" then return nil, nil end

	local skinOkay, skins = pcall(engine.GetModule, engine, "Skins")
	local addOnSkinsOkay, addOnSkins = pcall(engine.GetModule, engine, "AddOnSkins")
	if not skinOkay or type(skins) ~= "table"
		or not addOnSkinsOkay or type(addOnSkins) ~= "table" then
		return nil, nil
	end
	return engine, skins
end

local function getTheme(mode, engine)
	local theme = THEMES.modern
	local palette = {
		background = copyColor(theme.background),
		panel = copyColor(theme.panel),
		input = copyColor(theme.input),
		border = copyColor(theme.border),
		accent = copyColor(theme.accent),
		text = copyColor(theme.text),
		disabled = copyColor(theme.disabled),
		font = nil,
	}

	if mode == "elvui" and engine and type(engine.media) == "table" then
		palette.background = mediaColor(engine.media.backdropfadecolor, palette.background)
		palette.panel = mediaColor(engine.media.backdropcolor, palette.panel)
		palette.border = mediaColor(engine.media.bordercolor, palette.border)
		palette.accent = mediaColor(engine.media.rgbvaluecolor, palette.accent)
		if type(engine.media.normFont) == "string" and engine.media.normFont ~= "" then
			palette.font = engine.media.normFont
		end
	end
	return palette
end

local function isOwned(object)
	local current = object
	local depth = 0
	while current and depth < MAX_PARENT_DEPTH do
		local name = current.GetName and current:GetName()
		if type(name) == "string" and sub(name, 1, #PREFIX) == PREFIX then
			return true
		end
		current = current.GetParent and current:GetParent()
		depth = depth + 1
	end
	return false
end

local function belongsToMinimapButton(object)
	local current = object
	local depth = 0
	while current and depth < MAX_PARENT_DEPTH do
		if current.GetName and current:GetName() == "K2040CrapFilter_MinimapButton" then
			return true
		end
		current = current.GetParent and current:GetParent()
		depth = depth + 1
	end
	return false
end

local function setColor(texture, color, alpha)
	if texture and texture.SetTexture then
		texture:SetTexture(color[1], color[2], color[3], alpha or color[4] or 1)
	end
end

local function setSurface(frame, background, border)
	if not frame or not frame.SetBackdrop then return end
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	frame:SetBackdropColor(background[1], background[2], background[3], background[4])
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function setBlueButtonSurface(button)
	button:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 12,
		edgeSize = 12,
		insets = { left = 3, right = 2, top = 3, bottom = 3 },
	})
	button:SetBackdropColor(BLUE_BUTTON[1], BLUE_BUTTON[2], BLUE_BUTTON[3], BLUE_BUTTON[4])
end

local function stripButtonTextures(button)
	if button.SetNormalTexture then button:SetNormalTexture(nil) end
	if button.SetPushedTexture then button:SetPushedTexture(nil) end
	if button.SetDisabledTexture then button:SetDisabledTexture(nil) end
	if button.SetHighlightTexture then button:SetHighlightTexture(nil) end
end

local function ensureCloseText(button)
	if button.__K2040SkinCloseText then return end
	local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER", 0, 0)
	text:SetText("X")
	button.__K2040SkinCloseText = text
end

local function isBlueActionButton(button, name)
	if sub(name, -6) == "_Close" then return true end
	local texture = button.GetNormalTexture and button:GetNormalTexture()
	local texturePath = texture and texture.GetTexture and texture:GetTexture()
	return type(texturePath) == "string" and find(texturePath, "UI-Panel-Button", 1, true) ~= nil
end

local function styleBlueButton(button, name)
	stripButtonTextures(button)
	setBlueButtonSurface(button)
	if button.SetNormalFontObject then button:SetNormalFontObject(_G.GameFontHighlightSmall) end
	if button.SetHighlightFontObject then button:SetHighlightFontObject(_G.GameFontNormalSmall) end
	if button.SetDisabledFontObject then button:SetDisabledFontObject(_G.GameFontDisableSmall) end
	if sub(name, -6) == "_Close" then ensureCloseText(button) end
end

local function hideNamedTextures(frame)
	local name = frame and frame.GetName and frame:GetName()
	if not name then return end
	for _, suffix in ipairs({ "Left", "Middle", "Right", "Mid" }) do
		local texture = _G[name .. suffix]
		if texture and texture.SetAlpha then texture:SetAlpha(0) end
	end
end

local function styleRegions(frame, palette)
	if not frame or not frame.GetNumRegions then return end
	for index = 1, frame:GetNumRegions() do
		local region = select(index, frame:GetRegions())
		if region and region.IsObjectType and region:IsObjectType("FontString") then
			if palette.font and region.GetFont and region.SetFont then
				local _, size, flags = region:GetFont()
				if type(size) == "number" and size > 0 then region:SetFont(palette.font, size, flags) end
			end
		end
	end
end

local function useElvSurface(frame, template)
	if not frame or not frame.StripTextures or not frame.SetTemplate then return false end
	frame:StripTextures()
	frame:SetTemplate(template or "Transparent")
	return true
end

local function stylePanel(frame, palette, engine)
	if engine and useElvSurface(frame, "Transparent") then
		styleRegions(frame, palette)
		return
	end
	setSurface(frame, palette.background, palette.border)
	styleRegions(frame, palette)
end

local function styleButton(button, palette, skins)
	if skins and type(skins.HandleButton) == "function" then
		skins:HandleButton(button)
		styleRegions(button, palette)
		return
	end

	stripButtonTextures(button)
	setSurface(button, palette.panel, palette.border)

	if button.CreateTexture and button.SetHighlightTexture then
		local highlight = button.__K2040SkinHighlight
		if not highlight then
			highlight = button:CreateTexture(nil, "HIGHLIGHT")
			highlight:SetPoint("TOPLEFT", 1, -1)
			highlight:SetPoint("BOTTOMRIGHT", -1, 1)
			button:SetHighlightTexture(highlight)
			button.__K2040SkinHighlight = highlight
		end
		setColor(highlight, palette.accent, 0.25)
	end
	styleRegions(button, palette)
end

local function styleCloseButton(button, parent, palette, skins)
	if skins and type(skins.HandleCloseButton) == "function" then
		skins:HandleCloseButton(button, parent)
		return
	end
	styleButton(button, palette, nil)
	ensureCloseText(button)
end

local function syncCheckBox(frame, palette)
	local indicator = frame.__K2040SkinChecked
	if not indicator then return end
	if frame:GetChecked() then
		local enabled = not frame.IsEnabled or frame:IsEnabled()
		local color = enabled and palette.accent or palette.disabled
		setColor(indicator, color)
		indicator:Show()
	else
		indicator:Hide()
	end
end

local function styleCheckBox(frame, palette, skins)
	if skins and type(skins.HandleCheckBox) == "function" then
		skins:HandleCheckBox(frame)
	else
		if frame.SetNormalTexture then frame:SetNormalTexture(nil) end
		if frame.SetPushedTexture then frame:SetPushedTexture(nil) end
		if frame.SetDisabledTexture then frame:SetDisabledTexture(nil) end
		if frame.SetHighlightTexture then frame:SetHighlightTexture(nil) end
		setSurface(frame, palette.input, palette.border)
	end

	local parent = frame.backdrop or frame
	local indicator = frame.__K2040SkinChecked
	if not indicator then
		indicator = parent:CreateTexture(nil, "OVERLAY")
		indicator:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
		indicator:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)
		frame.__K2040SkinChecked = indicator
		if hooksecurefunc then hooksecurefunc(frame, "SetChecked", function() syncCheckBox(frame, palette) end) end
		frame:HookScript("OnShow", function() syncCheckBox(frame, palette) end)
		frame:HookScript("OnEnable", function() syncCheckBox(frame, palette) end)
		frame:HookScript("OnDisable", function() syncCheckBox(frame, palette) end)
		frame:HookScript("OnClick", function() syncCheckBox(frame, palette) end)
	end
	syncCheckBox(frame, palette)
	styleRegions(frame, palette)
end

local function styleEditBox(frame, palette, skins)
	hideNamedTextures(frame)
	if skins and type(skins.HandleEditBox) == "function" and frame.CreateBackdrop then
		skins:HandleEditBox(frame)
	else
		setSurface(frame, palette.input, palette.border)
	end
	if frame.SetFontObject then frame:SetFontObject(_G.GameFontHighlightSmall) end
	if frame.SetTextInsets then frame:SetTextInsets(5, 5, 0, 0) end
end

local function ensureDropDownPresentation(frame)
	local name = frame:GetName()
	local source = name and _G[name .. "Text"]
	local button = name and _G[name .. "Button"]
	local surface = frame.backdrop or frame

	if not frame.__K2040SkinDropDownText then
		local display = surface:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		display:SetPoint("LEFT", surface, "LEFT", 9, 0)
		display:SetPoint("RIGHT", surface, "RIGHT", -28, 0)
		display:SetJustifyH("LEFT")
		display:SetWordWrap(false)
		frame.__K2040SkinDropDownText = display
	end

	if button then
		stripButtonTextures(button)
		if not frame.__K2040SkinDropDownArrow then
			local arrow = surface:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			arrow:SetPoint("RIGHT", surface, "RIGHT", -9, 0)
			arrow:SetText("v")
			frame.__K2040SkinDropDownArrow = arrow
		end
	end

	if source then source:Hide() end
end

local function syncDropDown(frame, explicitText)
	local display = frame.__K2040SkinDropDownText
	if not display then return end
	local name = frame:GetName()
	local source = name and _G[name .. "Text"]
	local value = explicitText
	if value == nil and source and source.GetText then value = source:GetText() end
	display:SetText(value or "")
	if source then source:Hide() end
end

local function styleDropDown(frame, palette, skins)
	if skins and type(skins.HandleDropDownBox) == "function" then
		skins:HandleDropDownBox(frame, 350)
	else
		hideNamedTextures(frame)
		setSurface(frame, palette.input, palette.border)
	end
	ensureDropDownPresentation(frame)
	syncDropDown(frame)
end

local function styleSlider(frame, palette, skins)
	if skins and type(skins.HandleSliderFrame) == "function" then
		skins:HandleSliderFrame(frame)
		return
	end
	setSurface(frame, palette.input, palette.border)
	local thumb = frame.GetThumbTexture and frame:GetThumbTexture()
	setColor(thumb, palette.accent)
end

local function styleScrollBar(frame, palette, skins)
	if skins and type(skins.HandleScrollBar) == "function" then
		skins:HandleScrollBar(frame)
		return
	end
	styleSlider(frame, palette, nil)
end

local function isDropDown(_frame, name)
	return name ~= "" and _G[name .. "Button"] ~= nil and _G[name .. "Text"] ~= nil
end

local function isPanel(name)
	if find(name, "^K2040CrapFilter_Options_")
		and not find(name, "_Content", 1, true)
		and not find(name, "_ScrollFrame", 1, true) then
		return true
	end
	return name == "K2040CrapFilter_ProcessBar"
		or name == "K2040CrapFilter_QuickLists"
		or name == "K2040CrapFilter_QuickLists_Keep"
		or name == "K2040CrapFilter_QuickLists_Crap"
end

function Skin.ApplyObject(_self, object, mode, palette, engine, skins)
	if not object or not isOwned(object) or belongsToMinimapButton(object) then return end
	local name = object.GetName and object:GetName() or ""
	if name == "K2040CrapFilter_EventFrame" then return end
	if object.__K2040SkinMode == mode then return end

	local objectType = object.GetObjectType and object:GetObjectType() or ""
	local parent = object.GetParent and object:GetParent()
	local parentName = parent and parent.GetName and parent:GetName()
	if objectType == "Button" and parentName and _G[parentName .. "Button"] == object then
		return
	end
	if objectType == "CheckButton" then
		styleCheckBox(object, palette, skins)
	elseif objectType == "EditBox" then
		styleEditBox(object, palette, skins)
	elseif objectType == "Slider" and find(name, "ScrollBar", 1, true) then
		styleScrollBar(object, palette, skins)
	elseif objectType == "Slider" then
		styleSlider(object, palette, skins)
	elseif objectType == "Button" and sub(name, -6) == "_Close" then
		styleCloseButton(object, object:GetParent(), palette, skins)
	elseif objectType == "Button" then
		styleButton(object, palette, skins)
	elseif objectType == "Frame" and isDropDown(object, name) then
		styleDropDown(object, palette, skins)
	elseif objectType == "Frame" and isPanel(name) then
		stylePanel(object, palette, engine)
	else
		styleRegions(object, palette)
	end
	object.__K2040SkinMode = mode
end

function Skin:ApplyAll()
	local mode = KCF:ResolveSkinMode(KCF.db and KCF.db.ui and KCF.db.ui.skinMode)
	if mode == "vanilla" then return end
	if mode == "blue" then
		local blueObject = EnumerateFrames and EnumerateFrames()
		while blueObject do
			if isOwned(blueObject) and not belongsToMinimapButton(blueObject) then
				local name = blueObject.GetName and blueObject:GetName() or ""
				local objectType = blueObject.GetObjectType and blueObject:GetObjectType() or ""
				if objectType == "Button" and isBlueActionButton(blueObject, name) then
					styleBlueButton(blueObject, name)
				end
			end
			blueObject = EnumerateFrames(blueObject)
		end
		return
	end

	local engine, skins
	if mode == "elvui" then
		engine, skins = getElvUI()
		if not engine or not skins then return end
	end
	local palette = getTheme(mode, engine)

	local object = EnumerateFrames and EnumerateFrames()
	while object do
		self:ApplyObject(object, mode, palette, engine, skins)
		object = EnumerateFrames(object)
	end

end

function Skin:InstallLateHooks()
	if self.hooksInstalled or type(hooksecurefunc) ~= "function" then return end
	self.hooksInstalled = true

	local professions = KCF.modules.Professions
	if professions and professions.CreateProcessBar then
		hooksecurefunc(professions, "CreateProcessBar", function() Skin:ApplyAll() end)
	end
	local quickLists = KCF.modules.QuickLists
	if quickLists and quickLists.CreateWindow then
		hooksecurefunc(quickLists, "CreateWindow", function() Skin:ApplyAll() end)
	end
	local options = KCF.modules.Options
	if options and options.BuildPanels then
		hooksecurefunc(options, "BuildPanels", function() Skin:ApplyAll() end)
	end
end

function Skin:OnInitialize()
	if type(hooksecurefunc) == "function" and type(_G.UIDropDownMenu_SetText) == "function" then
		hooksecurefunc("UIDropDownMenu_SetText", function(frame, value)
			local mode = KCF:ResolveSkinMode(KCF.db and KCF.db.ui and KCF.db.ui.skinMode)
			if mode == "vanilla" or mode == "blue" then return end
			syncDropDown(frame, value)
		end)
	end
	self:InstallLateHooks()
	KCF:RegisterEvent("PLAYER_ENTERING_WORLD", self, "OnWorldReady")
end

function Skin:OnEnable()
	self:ApplyAll()
end

function Skin:OnWorldReady()
	self:ApplyAll()
end
