local DeaDx = getgenv().__DeaDx
	or loadstring(game:HttpGet("https://raw.githubusercontent.com/ServerDeadd/DeaDx/main/DeaDx.lua"))()

local Window = DeaDx:CreateWindow({
	Title = "DeaDx",
	SubTitle = "by ServerDead",
	Icon = "zap",
	Size = UDim2.fromOffset(620, 460),
	Theme = "DeaDx",
	Acrylic = true,
	Resize = true,
	Search = true,
	Footer = "v" .. DeaDx:GetVersion(),
	MinimizeKey = Enum.KeyCode.RightControl,
})

local Status = DeaDx:CreateStatusBar({
	Title = "<gradient:#FF2D40:#FFFFFF>DeaDx</gradient>",
	Icon = "activity",
	Position = "TopCenter",
	Fps = true,
	Ping = true,
	Players = true,
	Session = true,
	Separator = "|",
	Draggable = true,
})

local Main = Window:AddTab({ Title = "Main", Icon = "house", Badge = "2" })
local Lab = Window:AddTab({ Title = "Lab", Icon = "flask-conical", IconColor = "#38BDF8" })
local Visual = Window:AddTab({ Title = "Visual", Icon = "palette", IconColor = "#A855F7" })
local Icons = Window:AddTab({ Title = "Icons", Icon = "image" })
local Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })

local Esp = Lab:AddPreview({
	Title = "ESP preview",
	Icon = "scan",
	Label = "ServerDead",
	Color = "#FF2D40",
	Features = { Box = true, Name = true },
})

for _, feature in { "Box", "Corners", "Name", "Distance", "Health", "Tracer", "Skeleton", "Chams" } do
	Esp:AddToggle({
		Title = feature,
		Default = Esp:GetFeature(feature),
		Callback = function(value)
			Esp:SetFeature(feature, value)
		end,
	})
end

Esp:AddColorpicker({
	Title = "Color",
	Default = Color3.fromRGB(255, 45, 64),
	Callback = function(color)
		Esp:SetColor(color)
	end,
})

Esp:AddSlider({
	Title = "Thickness",
	Min = 1,
	Max = 5,
	Default = 1,
	Callback = function(value)
		Esp:SetThickness(value)
	end,
})

local Timing = Lab:AddCard({ Title = "Timers & locks", Icon = "timer", Accent = "#38BDF8", Collapsible = true })

local counter = Timing:AddCountdown("timer", {
	Title = "Countdown",
	Description = "A slider without the knob",
	Seconds = 30,
	AutoStart = false,
	Gradient = { "#FF2D40", "#FACC15" },
	OnFinish = function()
		DeaDx:Notify({ Title = "Time", Content = "Time is up.", Type = "Warning" })
	end,
})

Timing:AddButton({
	Title = "Start / pause",
	Description = "Resumes where it stopped",
	Callback = function()
		counter:Toggle()
	end,
})

Timing:AddButton({
	Title = "Button with cooldown",
	Description = "Locks for 5s with a padlock",
	Cooldown = 5,
	Badge = "NEW",
	Callback = function()
		DeaDx:Notify({ Title = "Done", Content = "Locked for 5s.", Type = "Success" })
	end,
})

local load = Timing:AddProgress("load", {
	Title = "Progress",
	Default = 0.35,
	Color = "#4ADE80",
})

Timing:AddButton({
	Title = "+10%",
	Callback = function()
		load:Increment(0.1)
	end,
})

local Tools = Lab:AddCard({ Title = "Controls", Icon = "sliders-horizontal" })

Tools:AddSegmented("mode", {
	Title = "Mode",
	Values = { "Legit", "Semi", "Rage" },
	Default = "Semi",
	Icons = { Legit = "shield", Semi = "crosshair", Rage = "flame" },
})

Tools:AddStat("kills", {
	Title = "Kills",
	Description = "Updates on its own",
	Default = 0,
	Trend = true,
	Short = true,
})

Tools:AddPlayer("target", {
	Title = "Target",
	Description = "List with avatars",
	Callback = function(name)
		print("target", name)
	end,
})

Tools:AddList("whitelist", {
	Title = "Whitelist",
	Icon = "user-check",
	Default = { "ServerDead" },
	Placeholder = "player name",
})

Tools:AddCode({
	Title = "Loadstring",
	Default = 'loadstring(game:HttpGet("https://.../DeaDx.lua"))()',
})

local Combat = Main:AddSection({ Title = "Combat", Icon = "sword", Collapsible = true })

Combat:AddToggle("aimbot", {
	Title = "Aimbot",
	Description = "Locks onto the closest target",
	Default = false,
	Picker = Color3.fromRGB(255, 45, 64),
	Callback = function(value)
		print("aimbot", value)
	end,
})

Combat:AddSlider("fov", {
	Title = "FOV",
	Description = "Only shows with aimbot on",
	Min = 10,
	Max = 400,
	Default = 120,
	Increment = 5,
	Suffix = "px",
	VisibleWhen = "aimbot",
})

Combat:AddGraph({
	Title = "FPS",
	Icon = "activity",
	Description = "right click any row",
	Source = function()
		return workspace:GetRealPhysicsFPS()
	end,
	Interval = 0.25,
	Capacity = 80,
	Gradient = { "#FF2D40", "#FACC15" },
})

Combat:AddKeybind("panic", {
	Title = "Panic key",
	Description = "Right-click the key to pick a mode",
	Default = Enum.KeyCode.P,
	Mode = "Toggle",
	Callback = function(state)
		print("panic", state)
	end,
})

local Editing = Main:AddSection({ Title = "Editable", Icon = "pencil" })

local profiles = Editing:AddDropdown("profile", {
	Title = "Profile",
	Description = "Rename, remove or add options right here",
	Values = { "Default", "Legit", "Rage" },
	Default = "Default",
	Editable = true,
	Creatable = true,
	Removable = true,
	Icons = { Default = "user", Legit = "shield", Rage = "flame" },
	Colors = { Rage = "#FF2D40", Legit = "#4ADE80" },
	Callback = function(value)
		print("profile", value)
	end,
	OnRename = function(old, new)
		print("renamed", old, "->", new)
	end,
})

Editing:AddDropdown("targets", {
	Title = "Target parts",
	Values = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" },
	Default = { "Head" },
	Multi = true,
	Searchable = true,
})

Editing:AddInput("name", {
	Title = "Display name",
	Description = "Double-click the title to rename this row",
	Placeholder = "type here",
	Default = "",
	EditableTitle = true,
	OnTitleChanged = function(value)
		print("title is now", value)
	end,
})

Editing:AddParagraph({
	Title = "Markup",
	Content = "Use <red>colors</red>, <gradient:#FF2D40:#FACC15>gradients</gradient>, <b>bold</b>, <i>italic</i> and <size:16>sizes</size>.",
})

local Looks = Visual:AddSection({ Title = "Appearance", Icon = "paintbrush" })

Looks:AddDropdown("theme", {
	Title = "Theme",
	Values = DeaDx:GetThemes(),
	Default = DeaDx:GetTheme(),
	Callback = function(value)
		DeaDx:SetTheme(value)
	end,
})

Looks:AddColorpicker("accent", {
	Title = "Accent",
	Default = Color3.fromRGB(255, 45, 64),
	Transparency = 0,
	Callback = function(color)
		DeaDx:SetAccent(color)
	end,
})

Looks:AddSlider("scale", {
	Title = "UI scale",
	Min = 0.7,
	Max = 1.4,
	Default = 1,
	Increment = 0.05,
	Rounding = 2,
	Callback = function(value)
		DeaDx:SetScale(value)
	end,
})

Looks:AddToggle("acrylic", {
	Title = "Acrylic",
	Default = true,
	Callback = function(value)
		Window:SetAcrylic(value)
	end,
})

local Editor = Visual:AddSection({ Title = "Theme editor", Icon = "palette", Collapsible = true, Collapsed = true })
DeaDx:AddThemeEditor(Editor, { Name = "DeaDx Custom" })

local Bar = Visual:AddSection({ Title = "Status bar", Icon = "layout-panel-top" })

Bar:AddDropdown("barpos", {
	Title = "Position",
	Values = DeaDx:StatusBarAnchors(),
	Default = "topcenter",
	Searchable = true,
	Callback = function(value)
		Status:SetPosition(value)
	end,
})

Bar:AddInput("barname", {
	Title = "Name",
	Placeholder = "DeaDx",
	Live = true,
	Callback = function(value)
		Status:SetTitle(value ~= "" and value or "DeaDx")
	end,
})

Bar:AddToggle("barvisible", {
	Title = "Visible",
	Default = true,
	Callback = function(value)
		Status:SetVisible(value)
	end,
})

local Remote = Icons:AddSection({ Title = "Cached icons", Icon = "download" })

Remote:AddParagraph({
	Title = "Disk cache",
	Content = "External icons are downloaded once, saved in <b>DeaDx/icons</b> by name and reused from disk.",
})

Remote:AddButton({
	Title = "Load a lucide SVG by url",
	Description = "lucide.dev / rocket",
	Callback = function()
		local tab = Window:GetTab("Icons")
		if tab then
			tab:SetIcon("https://unpkg.com/lucide-static@0.544.0/icons/rocket.svg")
		end
		DeaDx:Notify({ Title = "Icon", Content = "Tab icon replaced from a url.", Type = "Success" })
	end,
})

Remote:AddButton({
	Title = "Icon cache stats",
	Callback = function()
		local stats = DeaDx:GetIconStats()
		DeaDx:Notify({
			Title = "Icon cache",
			Content = string.format("%d cached - %.1f KB - %s", stats.Count, stats.Bytes / 1024, stats.Folder),
			Type = "Info",
		})
	end,
})

Remote:AddButton({
	Title = "Clear icon cache",
	Callback = function()
		DeaDx:ClearIconCache()
		DeaDx:Notify({ Title = "Icon cache", Content = "Cleared.", Type = "Warning" })
	end,
})

local Alerts = Settings:AddSubTab({ Title = "Alerts", Icon = "bell" })
local Configs = Settings:AddSubTab({ Title = "Configs", Icon = "save" })

for _, kind in { "Info", "Success", "Warning", "Error" } do
	Alerts:AddButton({
		Title = kind .. " notification",
		Callback = function()
			DeaDx:Notify({ Title = kind, Content = "This is a " .. kind .. " toast.", Type = kind })
		end,
	})
end

Alerts:AddButton({
	Title = "Dialog",
	Callback = function()
		Window:CreateDialog({
			Title = "Confirm",
			Content = "Everything working?",
			Icon = "circle-help",
			Buttons = {
				{ Title = "No" },
				{ Title = "Yes", Primary = true },
			},
		})
	end,
})

DeaDx:AddConfigManager(Configs)

Configs:AddDivider({ Title = "keybinds" })
DeaDx:AddKeybinds(Configs)

Configs:AddDivider({ Title = "logs" })
DeaDx:AddConsole(Configs, { Height = 150 })

Configs:AddDivider({ Title = "danger" })

Configs:AddButton({
	Title = "Unload",
	Description = "Removes every DeaDx gui",
	Callback = function()
		DeaDx:Unload()
	end,
})

Window:SelectTab(1)
profiles:AddValue("Silent", { Icon = "eye-off", Color = "#38BDF8" })

local Palette = Window:GetPalette()
if Palette then
	Palette:AddAction({
		Title = "Undo last change",
		Icon = "undo-2",
		Detail = "config",
		Callback = function()
			DeaDx:Undo()
		end,
	})
	Palette:AddAction({
		Title = "Save config",
		Icon = "save",
		Detail = "config",
		Callback = function()
			DeaDx:Save("default")
		end,
	})
end

Window.StatusBar = Status

Alerts:AddButton({
	Title = "Open the tour",
	Description = "walks through the UI",
	Icon = "compass",
	Callback = function()
		Window:Tour({
			{ Target = "aimbot", Title = "Aimbot", Text = "Turns on aim assist. Right-click to pin it or bind a key." },
			{ Target = "profile", Title = "Profiles", Text = "You can rename, add and remove options right here." },
			{ Tab = "Lab", Target = "timer", Title = "Countdown", Text = "A knobless slider for countdowns." },
			{ Tab = "Visual", Target = "theme", Title = "Theme", Text = "Switch themes or build your own in the editor." },
		})
	end,
})

DeaDx:Log("hub loaded", "Success", "boot")
DeaDx:Log("icons served from cache", "Info", "icons")

DeaDx:Notify({
	Title = "DeaDx loaded",
	Content = "Ready to go. <gradient:#FF2D40:#FACC15>by ServerDead</gradient>",
	Type = "Success",
	Duration = 6,
})
