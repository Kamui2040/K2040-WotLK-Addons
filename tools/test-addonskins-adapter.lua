local root = assert(arg[1], "repository root argument is required")
local adapterRoot = root .. "/addons/K2040_LootAndSalvage_AddOnSkins"

local function readFile(path)
	local handle = assert(io.open(path, "rb"))
	local contents = handle:read("*a")
	handle:close()
	return contents
end

local function contains(contents, text, label)
	if not contents:find(text, 1, true) then
		error("missing " .. label, 2)
	end
end

local function excludes(contents, text, label)
	if contents:find(text, 1, true) then
		error("unexpected " .. label, 2)
	end
end

local toc = readFile(adapterRoot .. "/K2040_LootAndSalvage_AddOnSkins.toc")
local adapter = readFile(adapterRoot .. "/Adapter.lua")

contains(toc, "## Interface: 30300", "WotLK interface version")
contains(toc, "## RequiredDeps: ElvUI, ElvUI_AddOnSkins, K2040_CrapFilter", "explicit dependencies")
contains(toc, "Adapter.lua", "adapter load entry")

contains(adapter, "local E = unpack(ElvUI)", "ElvUI engine binding")
contains(adapter, "local function SkinOptions()", "settings skin")
contains(adapter, "local function SkinProcessBar()", "profession window skin")
contains(adapter, "local function SkinQuickLists()", "Quick Lists skin")
contains(adapter, "hooksecurefunc(options, \"BuildPanels\"", "late settings hook")
contains(adapter, "hooksecurefunc(professions, \"CreateProcessBar\"", "late profession hook")
contains(adapter, "hooksecurefunc(quickLists, \"CreateWindow\"", "late Quick Lists hook")
contains(adapter, "ApplySkin()", "direct dependent-addon initialization")
contains(adapter, "PLAYER_LOGIN", "login retry")

excludes(adapter, "E.private.addOnSkins.K2040_CrapFilter", "private AddOnSkins option dependency")
excludes(adapter, "S:AddCallbackForAddon", "late callback registration after required dependencies")

local loginFrame
local skinModule = {}
local engine = {
	media = { blankTex = "blank" },
}

function engine.GetModule(_self, name)
	assert(name == "Skins", "unexpected ElvUI module: " .. tostring(name))
	return skinModule
end

function engine.Delay(_self, _seconds, callback)
	callback()
end

_G.ElvUI = { engine }
_G.UIDropDownMenu_SetText = function() end
_G.hooksecurefunc = function(target, method)
	if type(target) == "string" then
		assert(type(_G[target]) == "function", "missing global hook target: " .. target)
	else
		assert(type(target) == "table", "table hook target is required")
		assert(type(target[method]) == "function", "missing table hook target: " .. tostring(method))
	end
end
_G.CreateFrame = function()
	loginFrame = {
		RegisterEvent = function(self, event) self.event = event end,
		UnregisterEvent = function(self, event)
			assert(self.event == event, "unexpected event removal")
			self.event = nil
		end,
		SetScript = function(self, script, callback) self[script] = callback end,
	}
	return loginFrame
end

assert(loadfile(adapterRoot .. "/Adapter.lua"))()
assert(loginFrame and loginFrame.event == "PLAYER_LOGIN", "login retry was not registered")
assert(type(loginFrame.OnEvent) == "function", "login retry handler was not installed")
loginFrame:OnEvent()
assert(loginFrame.event == nil, "login retry was not removed after use")

print("PASS: standalone AddOnSkins bridge contracts")
