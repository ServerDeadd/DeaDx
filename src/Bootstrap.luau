return function(import)
	local VERSION = "1.0.0"
	local CREDIT = "ServerDead"

	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local State = import("Core/State")
	local Config = import("Core/Config")
	local Capabilities = import("Core/Capabilities")
	local Markup = import("Core/Markup")
	local Theme = import("Core/Theme")
	local Component = import("Core/Component")
	local Window = import("Core/Window")
	local Icons = import("Icons/Icon")
	local IconStore = import("Icons/Store")
	local IconRegistry = import("Icons/Registry")
	local IconProviders = import("Icons/Providers")
	local Input = import("Services/Input")
	local Acrylic = import("Services/Acrylic")
	local Tooltip = import("Services/Tooltip")
	local Notification = import("Services/Notification")
	local StatusBar = import("Services/StatusBar")
	local Hash = import("Core/Hash")

	local globalEnv
	do
		local ok, env = pcall(function()
			return getgenv()
		end)
		globalEnv = ok and env or _G
	end

	if type(globalEnv.__DeaDx) == "table" and type(globalEnv.__DeaDx.Unload) == "function" then
		pcall(function()
			globalEnv.__DeaDx:Unload()
		end)
	end

	for _, name in { "DeaDx", "Dark", "Darker", "Amoled", "Light", "Midnight", "Crimson", "Ocean", "Forest", "Amethyst", "Sunset" } do
		Theme.Register(name, import("Themes/" .. name))
	end
	Theme.Set("DeaDx")

	for _, name in {
		"Button", "Toggle", "Slider", "Dropdown", "MultiDropdown", "Input",
		"Keybind", "Colorpicker", "Paragraph", "Label", "Divider",
		"Segmented", "Progress", "Countdown", "Stat", "Image", "Code",
		"List", "Player", "Preview", "Graph",
	} do
		local path = "Components/" .. name
		local factory
		Component.Register(name, function(ctx, id, config)
			factory = factory or import(path)
			return factory(ctx, id, config)
		end)
	end

	local DeaDx = {
		Version = VERSION,
		Credit = CREDIT,
		Icons = Icons,
		IconStore = IconStore,
		Config = Config,
		Theme = Theme,
		Markup = Markup,
		State = State,
		Signal = Signal,
		Capabilities = Capabilities,
		Component = Component,
		Options = Config._states,
		Windows = {},
		StatusBars = {},
		Screens = {},
	}

	function DeaDx:CreateWindow(config)
		local window = Window.new(config or {})
		window.Owner = self
		table.insert(self.Windows, window)
		window.OnDestroy:Connect(function()
			local index = table.find(self.Windows, window)
			if index then
				table.remove(self.Windows, index)
			end
		end)
		return window
	end

	function DeaDx:CreateStatusBar(config)
		local bar = StatusBar.new(config or {})
		table.insert(self.StatusBars, bar)
		return bar
	end

	function DeaDx:StatusBarAnchors()
		return StatusBar.Anchors()
	end

	function DeaDx:CreateLoadingScreen(config)
		local screen = import("Services/Loading").new(config or {})
		table.insert(self.Screens, screen)
		return screen
	end

	function DeaDx:CreateKeySystem(config)
		local key = import("Services/KeySystem").new(config or {})
		self.Key = key
		return key
	end

	function DeaDx:Integrity()
		return import("Core/Integrity").Report()
	end

	function DeaDx:GuardIntegrity(interval, callback)
		return import("Core/Integrity").Guard(interval, callback)
	end

	function DeaDx:Luarmor(config, key)
		return import("Services/Luarmor").Check(config, key)
	end

	function DeaDx:LuarmorLoad(config, key)
		return import("Services/Luarmor").Load(config, key)
	end

	function DeaDx:LuarmorPurge(config)
		return import("Services/Luarmor").PurgeCache(config)
	end

	function DeaDx:LuarmorInfo(status)
		return import("Services/Luarmor").Info(status)
	end

	function DeaDx:KeyPlus(config, key)
		return import("Services/KeyPlus").Request(config, key)
	end

	function DeaDx:KeyPlusRun(config, key)
		return import("Services/KeyPlus").Run(config, key)
	end

	function DeaDx:KeyPlusPack(secret, key, hwid, nonce, stamp, payload)
		return import("Services/KeyPlus").Pack(secret, key, hwid, nonce, stamp, payload)
	end

	function DeaDx:KeyPlusOpen(secret, key, hwid, nonce, response, window)
		return import("Services/KeyPlus").Open(secret, key, hwid, nonce, response, window)
	end

	function DeaDx:Hash(text, salt)
		if salt ~= nil then
			return Hash.Salted(text, salt)
		end
		return Hash.Sha256(text)
	end

	function DeaDx:GetHwid()
		return Capabilities.Hwid()
	end

	function DeaDx:Notify(config)
		return Notification.Notify(config)
	end

	function DeaDx:Ask(config)
		return Notification.Ask(config)
	end

	function DeaDx:Prompt(config)
		return Notification.Prompt(config)
	end

	function DeaDx:SetNotificationSide(side)
		Notification.SetSide(side)
		return self
	end

	function DeaDx:SetNotificationMax(value)
		return Notification.SetMax(value)
	end

	function DeaDx:SetNotificationWidth(value)
		return Notification.SetWidth(value)
	end

	function DeaDx:CloseNotifications()
		Notification.CloseAll()
		return self
	end

	function DeaDx:SetTheme(name)
		return Theme.Set(name)
	end

	function DeaDx:GetTheme()
		return Theme.GetName()
	end

	function DeaDx:GetThemes()
		return Theme.Names()
	end

	function DeaDx:RegisterTheme(name, definition)
		Theme.Register(name, definition)
		return self
	end

	function DeaDx:AddThemeEditor(container, config)
		return import("Services/ThemeEditor").Build(container, config)
	end

	function DeaDx:AddConsole(container, config)
		return import("Services/Console").Build(container, config)
	end

	function DeaDx:AddConfigManager(container, config)
		return import("Services/ConfigPanel").Build(container, config)
	end

	function DeaDx:AddKeybinds(container, config)
		return import("Services/KeybindPanel").Build(container, config)
	end

	function DeaDx:Log(text, level, tag)
		return import("Services/Console").Log(text, level, tag)
	end

	function DeaDx:ClearLog()
		import("Services/Console").Clear()
		return self
	end

	function DeaDx:GetLog()
		return import("Services/Console").Dump()
	end

	function DeaDx:MirrorLog(enabled)
		import("Services/Console").Mirror = enabled == true
		return self
	end

	function DeaDx:ExportTheme(name)
		return import("Services/ThemeEditor").Export(name)
	end

	function DeaDx:SetAccent(color)
		Theme.Override("Accent", Theme.Resolve(color, "Accent"))
		return self
	end

	function DeaDx:LockTheme(name)
		return Theme.Lock(name)
	end

	function DeaDx:UnlockTheme()
		return Theme.Unlock()
	end

	function DeaDx:IsThemeLocked()
		return Theme.IsLocked()
	end

	function DeaDx:LockScale(value)
		return Theme.LockScale(value)
	end

	function DeaDx:UnlockScale()
		return Theme.UnlockScale()
	end

	function DeaDx:IsScaleLocked()
		return Theme.IsScaleLocked()
	end

	function DeaDx:SetFont(font)
		Theme.SetFont(font)
		return self
	end

	function DeaDx:SetScale(scale)
		Theme.SetScale(scale)
		return self
	end

	function DeaDx:SetIconProvider(name)
		return IconRegistry.SetProvider(name)
	end

	function DeaDx:GetIconProvider()
		return IconRegistry.GetProvider()
	end

	function DeaDx:GetIconProviders()
		return IconRegistry.Providers()
	end

	function DeaDx:RegisterIconProvider(name, resolve)
		IconRegistry.Register(name, resolve)
		return self
	end

	function DeaDx:SetIconTemplate(provider, template)
		IconProviders.SetTemplate(provider, template)
		return self
	end

	function DeaDx:RegisterIcon(alias, spec)
		IconRegistry.Alias(alias, spec)
		return self
	end

	function DeaDx:SetIconVerify(enabled)
		IconStore.Verify = enabled == true
		return self
	end

	function DeaDx:GetIconStats()
		return IconStore.Stats()
	end

	function DeaDx:ClearIconCache()
		IconStore.Clear()
		return self
	end

	function DeaDx:ForgetIcon(name)
		return IconStore.Forget(name)
	end

	function DeaDx:ImportIcon(name, body)
		return IconStore.Import(name, body)
	end

	function DeaDx:ListIcons()
		return Icons:List()
	end

	function DeaDx:RegisterComponent(name, factory)
		Component.Register(name, factory)
		return self
	end

	function DeaDx:RegisterColor(name, hex)
		Markup.RegisterColor(name, hex)
		return self
	end

	function DeaDx:SetAcrylicAssets(shadow, noise)
		if type(shadow) == "string" then
			Acrylic.ShadowAsset = shadow
		end
		if type(noise) == "string" then
			Acrylic.NoiseAsset = noise
		end
		return self
	end

	function DeaDx:Save(name)
		return Config:Save(name)
	end

	function DeaDx:Load(name)
		return Config:Load(name)
	end

	function DeaDx:DeleteConfig(name)
		return Config:Delete(name)
	end

	function DeaDx:ListConfigs()
		return Config:List()
	end

	function DeaDx:SetAutoSave(enabled, name)
		return Config:SetAutoSave(enabled, name)
	end

	function DeaDx:ResetConfig()
		Config:Reset()
		return self
	end

	function DeaDx:Undo()
		return Config:Undo()
	end

	function DeaDx:Redo()
		return Config:Redo()
	end

	function DeaDx:CanUndo()
		return Config:CanUndo()
	end

	function DeaDx:CanRedo()
		return Config:CanRedo()
	end

	function DeaDx:SetDebug(enabled)
		Utility.Debug = enabled == true
		return self
	end

	function DeaDx:GetVersion()
		return VERSION
	end

	function DeaDx:GetStats()
		local guis = 0
		local parent = Utility.GetGuiParent()
		if parent then
			for _, child in parent:GetChildren() do
				if child:GetAttribute("DeaDx") then
					guis += 1
				end
			end
		end
		return {
			Version = VERSION,
			Windows = #self.Windows,
			StatusBars = #self.StatusBars,
			Binds = Input.BindCount(),
			Guis = guis,
			Notifications = Notification.Count(),
			Theme = Theme.GetName(),
			Icons = IconStore.Stats(),
			Options = #Config:Keys(),
		}
	end

	function DeaDx:Unload()
		for _, window in table.clone(self.Windows) do
			window:Destroy()
		end
		for _, bar in table.clone(self.StatusBars) do
			bar:Destroy()
		end
		for _, screen in table.clone(self.Screens) do
			screen:Destroy()
		end
		if self.Key then
			self.Key:Destroy()
			self.Key = nil
		end
		table.clear(self.Windows)
		table.clear(self.StatusBars)
		table.clear(self.Screens)
		Notification.Reset()
		Tooltip.Reset()
		Input.Reset()
		Acrylic.Reset()
		if globalEnv.__DeaDx == self then
			globalEnv.__DeaDx = nil
		end
	end

	globalEnv.__DeaDx = DeaDx
	return DeaDx
end
