local VERSION = "1.0.0"
local DEFAULT_BASE = "https://raw.githubusercontent.com/ServerDeadd/DeaDx/main/src/"

local MODULES = {
	"Core/Signal", "Core/State", "Core/Capabilities", "Core/Utility", "Core/Markup",
	"Core/Theme", "Core/Config", "Core/Widgets", "Core/Editable", "Core/Search",
	"Core/Hash", "Core/Integrity", "Core/Component", "Core/Section", "Core/Card", "Core/Tab", "Core/Window",
	"Themes/Default", "Themes/DeaDx", "Themes/Dark", "Themes/Darker", "Themes/Amoled",
	"Themes/Light", "Themes/Midnight", "Themes/Crimson", "Themes/Ocean", "Themes/Forest",
	"Themes/Amethyst", "Themes/Sunset",
	"Services/Cleanup", "Services/Animation", "Services/Input", "Services/Drag",
	"Services/Acrylic", "Services/Tooltip", "Services/Notification", "Services/StatusBar", "Services/Loading", "Services/KeySystem", "Services/KeyPlus", "Services/Luarmor", "Services/Palette", "Services/ThemeEditor", "Services/Tour", "Services/Console", "Services/ConfigPanel", "Services/KeybindPanel",
	"Icons/Catalog", "Icons/Svg", "Icons/Store", "Icons/Providers", "Icons/Registry", "Icons/Icon",
	"Components/Button", "Components/Toggle", "Components/Slider", "Components/Dropdown",
	"Components/MultiDropdown", "Components/Input", "Components/Keybind", "Components/Colorpicker",
	"Components/Paragraph", "Components/Label", "Components/Divider", "Components/Notification",
	"Components/Dialog", "Components/Segmented", "Components/Progress", "Components/Countdown",
	"Components/Stat", "Components/Image", "Components/Code", "Components/List",
	"Components/Player", "Components/Preview", "Components/Graph",
	"Bootstrap",
}

local globalEnv
do
	local ok, env = pcall(function()
		return getgenv()
	end)
	globalEnv = ok and env or _G
end

local isStudio = typeof(script) == "Instance" and script:IsA("ModuleScript")
local sources, loaded = {}, {}
local import

local function fetch(path)
	local url = (globalEnv.DEADX_BASE or DEFAULT_BASE) .. path .. ".luau"
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok or type(body) ~= "string" or body == "" then
		error(string.format("[DEADX][ERROR] Failed to download module %s\nURL: %s\nReason: %s", path, url, tostring(body)), 0)
	end
	sources[path] = body
end

local function prefetch()
	local pending, failure = #MODULES, nil
	for _, path in MODULES do
		task.spawn(function()
			local ok, err = pcall(fetch, path)
			if not ok then
				failure = failure or err
			end
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 30 do
		task.wait()
	end
	if failure then
		error(failure, 0)
	end
	if pending > 0 then
		error("[DEADX][ERROR] Timed out while downloading modules.", 0)
	end
end

function import(path)
	local cached = loaded[path]
	if cached ~= nil then
		return cached
	end
	local factory
	if isStudio then
		local instance = script
		for _, part in string.split(path, "/") do
			instance = instance:FindFirstChild(part)
			if not instance then
				error("[DEADX][ERROR] Missing module: " .. path, 0)
			end
		end
		factory = require(instance)
	else
		if not sources[path] then
			fetch(path)
		end
		local compiled, err = loadstring(sources[path], "=DeaDx/" .. path)
		if not compiled then
			error(string.format("[DEADX][ERROR] Syntax error in module %s:\n%s", path, tostring(err)), 0)
		end
		factory = compiled()
	end
	local module = factory
	if type(factory) == "function" then
		module = factory(import)
	end
	loaded[path] = module
	return module
end

if not isStudio then
	prefetch()
end

local DeaDx = import("Bootstrap")
DeaDx.Version = VERSION
return DeaDx







