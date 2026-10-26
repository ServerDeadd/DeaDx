return function(import)
	local Workspace = game:GetService("Workspace")
	local UserInputService = game:GetService("UserInputService")
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Theme = import("Core/Theme")
	local Markup = import("Core/Markup")
	local Widgets = import("Core/Widgets")
	local Search = import("Core/Search")
	local Config = import("Core/Config")
	local Capabilities = import("Core/Capabilities")
	local Tab = import("Core/Tab")
	local Cleanup = import("Services/Cleanup")
	local Animation = import("Services/Animation")
	local Input = import("Services/Input")
	local Drag = import("Services/Drag")
	local Acrylic = import("Services/Acrylic")
	local Icons = import("Icons/Icon")
	local Dialog = import("Components/Dialog")

	local Window = {}
	Window.__index = Window

	local TOPBAR = Capabilities.Mobile and 50 or 44
	local CORNER = 16
	local CONTROL = Capabilities.Mobile and 30 or 26

	function Window.new(config)
		Utility.Check(type(config) == "table", "Window", "?", "Config must be a table.")
		Utility.Check(config.Title == nil or type(config.Title) == "string", "Window", config.Title, "Title must be a string.")
		local self = setmetatable({}, Window)
		self.Options, self.Tabs = {}, {}
		self.Config = config
		self._search = Search.new()
		self.Cleanup = Cleanup.new()
		self.OnDestroy = Signal.new()
		self.MinimizedChanged = Signal.new()
		self.TabWidth = config.TabWidth or 152
		self.MinSize = config.MinSize or Vector2.new(400, 300)
		self.MaxSize = config.MaxSize or Vector2.new(1100, 860)
		self.Acrylic = config.Acrylic ~= false
		self._searchEnabled = config.Search ~= false and config.SearchEnabled ~= false
		self._minimized, self._destroyed, self._compact = false, false, false
		self._collapsed, self._maximized = false, false
		local cleanup = self.Cleanup

		if config.Theme then
			Theme.Set(config.Theme)
		end
		if config.Font then
			Theme.SetFont(config.Font)
		end
		if config.Scale then
			Theme.SetScale(config.Scale, true)
		end
		if config.LockTheme then
			Theme.Lock(type(config.LockTheme) == "string" and config.LockTheme or nil)
		end
		if config.LockScale then
			Theme.LockScale(type(config.LockScale) == "number" and config.LockScale or nil)
		end
		Input.Init()

		local gui = cleanup:Add(Utility.NewScreenGui("DeaDx_Window", config.DisplayOrder or 100))
		self.Gui = gui
		local size = config.Size or UDim2.fromOffset(580, 440)

		local root, rootStroke = Widgets.Surface(cleanup, {
			Class = "CanvasGroup",
			Name = "Window",
			Parent = gui,
			Stroke = "Border",
			Radius = CORNER,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = config.Position or UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size.X.Offset, size.Y.Offset),
			BackgroundTransparency = 1,
			GroupTransparency = 1,
		})
		self.Root, self.RootStroke = root, rootStroke
		local uiScale = Instance.new("UIScale")
		uiScale.Parent = root
		Theme.BindScale(uiScale, cleanup)

		if self.Acrylic then
			self._paint = Acrylic.Paint(cleanup, {
				Parent = root,
				Radius = CORNER,
				Glass = config.Blur ~= false and config.Glass ~= false,
			})
			self._paint.Frame.ZIndex = 0
		else
			local fill = Widgets.Surface(cleanup, {
				Name = "Fill",
				Parent = root,
				Fill = "Background",
				Radius = CORNER,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,
			})
			self._fill = fill
		end

		self._tint = Utility.Create("Frame", {
			Name = "Tint",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 1,
			Parent = root,
		})
		Utility.Create("UICorner", { CornerRadius = UDim.new(0, CORNER), Parent = self._tint })
		self._tintGradient = Utility.Create("UIGradient", { Parent = self._tint })

		self._image = Utility.Create("ImageLabel", {
			Name = "Backdrop",
			BackgroundTransparency = 1,
			Image = config.BackgroundImage or "",
			ImageTransparency = config.BackgroundImageTransparency or 0.65,
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromScale(1, 1),
			Visible = (config.BackgroundImage or "") ~= "",
			ZIndex = 1,
			Parent = root,
		})
		Utility.Create("UICorner", { CornerRadius = UDim.new(0, CORNER), Parent = self._image })
		if config.Background then
			self:SetBackground(config.Background)
		end

		local topbar = Utility.Create("Frame", {
			Name = "Topbar",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, TOPBAR),
			ZIndex = 4,
			Parent = root,
		})
		self._topbar = topbar
		self._topline = Widgets.Surface(cleanup, {
			Name = "TopbarLine",
			Parent = root,
			Fill = "Border",
			Radius = 0,
			Position = UDim2.fromOffset(0, TOPBAR),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 4,
		})

		local titles = Utility.Create("Frame", {
			Name = "Titles",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = topbar,
		})
		Widgets.List(titles, 8, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		if config.Icon then
			local holder = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(18, 18),
				LayoutOrder = 0,
				Parent = titles,
			})
			self._icon = Icons.Create(holder, config.Icon, Icons.Options(config, {
				Size = config.IconSize or 18,
				Color = config.IconColor or "Accent",
				Cleanup = cleanup,
			}))
		end
		self.TitleLabel, self._title = Widgets.Text(cleanup, {
			Name = "Title",
			Parent = titles,
			Text = config.Title or "DeaDx",
			Color = config.TitleColor or "Text",
			Gradient = config.TitleGradient,
			Bold = true,
			TextSize = 14,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 1,
		})
		local subtitle = config.SubTitle or config.Subtitle or ""
		self.SubtitleLabel, self._subtitle = Widgets.Text(cleanup, {
			Name = "Subtitle",
			Parent = titles,
			Text = subtitle,
			Color = config.SubTitleColor or "MutedText",
			TextSize = 11,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
			Visible = subtitle ~= "",
		})

		local controls = Utility.Create("Frame", {
			Name = "Controls",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0, 0, 0, CONTROL),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = topbar,
		})
		Widgets.List(controls, 6, {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		local controlsWidth = 0
		local function control(iconName, order, callback)
			controlsWidth += CONTROL + 6
			local button = Widgets.Chip(cleanup, {
				Name = "Control",
				Parent = controls,
				Fill = "SecondaryBackground",
				Transparency = "ElementTransparency",
				Radius = "Full",
				Size = UDim2.fromOffset(CONTROL, CONTROL),
				LayoutOrder = order,
			})
			local icon = Icons.Create(button, iconName, {
				Size = 13,
				Position = UDim2.fromOffset((CONTROL - 13) / 2, (CONTROL - 13) / 2),
				Cleanup = cleanup,
			})
			cleanup:Add(button.Activated:Connect(callback))
			return button, icon
		end

		if config.CollapseButton ~= false then
			local _, icon = control("chevrons-up-down", 1, function()
				self:ToggleCollapsed()
			end)
			self._collapseIcon = icon
		end
		if config.MaximizeButton == true then
			control("maximize-2", 2, function()
				self:ToggleMaximized()
			end)
		end
		control("minus", 3, function()
			self:Minimize()
		end)
		if config.CloseButton ~= false then
			control("x", 4, function()
				if config.ConfirmClose then
					self:CreateDialog({
						Title = "Close",
						Content = "Close this window?",
						Buttons = {
							{ Title = "Cancel" },
							{
								Title = "Close",
								Primary = true,
								Callback = function()
									Utility.SafeCall("Window OnClose", config.OnClose)
									self:Destroy()
								end,
							},
						},
					})
					return
				end
				Utility.SafeCall("Window OnClose", config.OnClose)
				self:Destroy()
			end)
		end

		local searchBox, searchStroke = Widgets.Surface(cleanup, {
			Name = "Search",
			Parent = topbar,
			Fill = "TertiaryBackground",
			Stroke = "Border",
			StrokeTransparency = 0.45,
			Transparency = "ElementTransparency",
			Radius = "Full",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(controlsWidth + 14), 0.5, 0),
			Size = UDim2.fromOffset(150, CONTROL),
		})
		self._searchBox, self._searchStroke = searchBox, searchStroke
		Icons.Create(searchBox, "search", {
			Size = 13,
			Position = UDim2.fromOffset(9, (CONTROL - 13) / 2),
			Cleanup = cleanup,
		})
		local searchInput = Widgets.Text(cleanup, {
			Class = "TextBox",
			Name = "SearchInput",
			Parent = searchBox,
			PlaceholderText = "Search...",
			ClearTextOnFocus = false,
			TextSize = 12,
			Position = UDim2.fromOffset(28, 0),
			Size = UDim2.new(1, -36, 1, 0),
		})
		self._searchInput = searchInput

		local sidebar = Utility.Create("Frame", {
			Name = "Sidebar",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, TOPBAR + 1),
			Size = UDim2.new(0, self.TabWidth, 1, -(TOPBAR + 1)),
			ZIndex = 3,
			Parent = root,
		})
		self._sidebar = sidebar
		self._sideline = Widgets.Surface(cleanup, {
			Name = "SidebarLine",
			Parent = sidebar,
			Fill = "Border",
			Radius = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 1, 1, 0),
		})
		local tabList = Widgets.Scroller(cleanup, {
			Name = "Tabs",
			Parent = sidebar,
			Size = UDim2.new(1, -1, 1, 0),
			Thickness = 0,
		})
		Widgets.Padding(tabList, 8, 8)
		Widgets.List(tabList, 4)
		self._tabList = tabList

		if config.Footer then
			local footer = Utility.Create("Frame", {
				Name = "Footer",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, -1, 0, 34),
				Parent = sidebar,
			})
			Widgets.Padding(footer, 12, 0)
			local _, handle = Widgets.Text(cleanup, {
				Parent = footer,
				Text = config.Footer,
				Color = config.FooterColor or "MutedText",
				TextSize = 11,
				Size = UDim2.fromScale(1, 1),
			})
			self._footer = handle
			tabList.Size = UDim2.new(1, -1, 1, -34)
		end

		self._pages = Utility.Create("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(self.TabWidth, TOPBAR + 1),
			Size = UDim2.new(1, -self.TabWidth, 1, -(TOPBAR + 1)),
			ZIndex = 2,
			Parent = root,
		})
		self._content = self._pages

		local function layer(name, order, parent)
			return Utility.Create("Frame", {
				Name = name,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = order,
				Parent = parent or root,
			})
		end
		if config.PopupsOutside == true or config.DropdownsOutsideWindow == true then
			self._popupGui = cleanup:Add(Utility.NewScreenGui("DeaDx_Popups", (config.DisplayOrder or 100) + 5))
			self._popupLayer = layer("Popups", 1, self._popupGui)
			self._outside = true
		else
			self._popupLayer = layer("Popups", 20)
		end
		local searchLayer = layer("SearchLayer", 30)
		self._dialogLayer = layer("Dialogs", 40)

		local results = Widgets.Surface(cleanup, {
			Class = "ScrollingFrame",
			Name = "Results",
			Parent = searchLayer,
			Fill = "SecondaryBackground",
			Stroke = "Border",
			Radius = 12,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, TOPBAR + 6),
			Size = UDim2.fromOffset(300, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Visible = false,
		})
		Utility.Create("UISizeConstraint", { MaxSize = Vector2.new(300, 280), Parent = results })
		Widgets.Padding(results, 5)
		Widgets.List(results, 2)

		local function showResults(text)
			if self._results then
				self._results:Clean()
			end
			local rc = cleanup:Extend()
			self._results = rc
			if text == "" then
				results.Visible = false
				return
			end
			results.Visible = true
			local list = self._search:Query(text)
			if #list == 0 then
				Widgets.Text(rc, {
					Parent = results,
					Text = "No results",
					Color = "MutedText",
					Size = UDim2.new(1, 0, 0, 32),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				return
			end
			for index, entry in list do
				local row = Widgets.Surface(rc, {
					Class = "TextButton",
					Name = "Result",
					Parent = results,
					Fill = "SecondaryBackground",
					Radius = 10,
					Size = UDim2.new(1, 0, 0, 40),
					LayoutOrder = index,
				})
				rc:Add(row)
				local crumb = { entry.Tab and entry.Tab.Title or "?" }
				if entry.SubTab then
					table.insert(crumb, entry.SubTab.Title)
				end
				if entry.Section and entry.Kind ~= "Section" then
					table.insert(crumb, entry.Section.Title)
				end
				if entry.Kind ~= "Tab" and entry.Kind ~= "Section" and entry.Kind ~= "SubTab" then
					table.insert(crumb, entry.Kind)
				end
				Widgets.Text(rc, {
					Parent = row,
					Text = entry.Title,
					Bold = true,
					Position = UDim2.fromOffset(10, 5),
					Size = UDim2.new(1, -20, 0, 15),
					TextTruncate = Enum.TextTruncate.AtEnd,
					Markup = false,
				})
				Widgets.Text(rc, {
					Parent = row,
					Text = table.concat(crumb, "  /  "),
					Color = "MutedText",
					TextSize = 11,
					Position = UDim2.fromOffset(10, 21),
					Size = UDim2.new(1, -20, 0, 14),
					TextTruncate = Enum.TextTruncate.AtEnd,
					Markup = false,
				})
				Widgets.Interactive(rc, row, row, {})
				rc:Add(row.Activated:Connect(function()
					searchInput.Text = ""
					self:_GoTo(entry)
				end))
			end
		end

		cleanup:Add(searchInput:GetPropertyChangedSignal("Text"):Connect(function()
			showResults(searchInput.Text)
		end))
		cleanup:Add(searchInput.Focused:Connect(function()
			if searchInput.Text ~= "" then
				results.Visible = true
			end
		end))
		cleanup:Add(searchInput.FocusLost:Connect(function()
			task.delay(0.2, function()
				if not self._destroyed and not searchInput:IsFocused() then
					results.Visible = false
				end
			end)
		end))

		Drag.Attach(topbar, root, cleanup, {
			Ignore = { controls, searchBox },
			Blocked = function()
				return self._maximized
			end,
		})

		if config.Resize ~= false then
			local grip = Utility.Create("TextButton", {
				Name = "ResizeGrip",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -3, 1, -3),
				Size = UDim2.fromOffset(16, 16),
				ZIndex = 15,
				Parent = root,
			})
			Icons.Create(grip, "grip", { Size = 13, Position = UDim2.fromOffset(1.5, 1.5), Cleanup = cleanup })
			self._grip = grip
			Drag.Resize(grip, root, cleanup, {
				Min = self.MinSize,
				Max = self.MaxSize,
				GetScale = function()
					return Theme.Scale
				end,
				OnResize = function()
					self._maximized = false
					self:_Clamp()
				end,
			})
		end

		if config.RestoreButton ~= false then
			self:_BuildPill(config)
		end

		local cameraConnection
		local function hookCamera()
			if cameraConnection then
				cameraConnection:Disconnect()
				cameraConnection = nil
			end
			local camera = Workspace.CurrentCamera
			if camera then
				cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
					self:_Clamp()
				end)
			end
		end
		hookCamera()
		cleanup:Add(function()
			if cameraConnection then
				cameraConnection:Disconnect()
			end
		end)
		cleanup:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			hookCamera()
			self:_Clamp()
		end))
		cleanup:Add(Theme.ScaleChanged:Connect(function()
			self:_Clamp()
		end))
		cleanup:Add(root:GetPropertyChangedSignal("Size"):Connect(function()
			self:_UpdateLayout()
		end))
		cleanup:Add(self.OnDestroy)
		cleanup:Add(self.MinimizedChanged)

		self:SetMinimizeKey(config.MinimizeKey)
		self._modifier = config.Modifier ~= false and (config.Modifier or Enum.KeyCode.LeftControl) or nil
		if config.UndoKey or config.RedoKey then
			self:SetUndoKeys(config.UndoKey, config.RedoKey)
		end
		if config.Palette ~= false then
			task.defer(function()
				if not self._destroyed then
					self:CreatePalette(config.Palette)
				end
			end)
		end
		self:_Clamp()
		self:_UpdateLayout()
		uiScale.Scale = Theme.Scale * 0.965
		Animation:Play(root, { GroupTransparency = 0 }, { Duration = 0.26, Ease = "Smooth" })
		Animation:Play(uiScale, { Scale = Theme.Scale }, { Duration = 0.38, Ease = "Snap" })
		return self
	end

	function Window:_BuildPill(config)
		local cleanup = self.Cleanup
		local pillGui = cleanup:Add(Utility.NewScreenGui("DeaDx_Restore", (config.DisplayOrder or 100) + 1))
		pillGui.IgnoreGuiInset = true
		local pill = Widgets.Surface(cleanup, {
			Class = "TextButton",
			Name = "Restore",
			Parent = pillGui,
			Fill = "SecondaryBackground",
			Transparency = "ElementTransparency",
			Stroke = "Border",
			Radius = "Full",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = config.RestorePosition or UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(0, 32),
			AutomaticSize = Enum.AutomaticSize.X,
			Visible = false,
		})
		Widgets.Padding(pill, 12, 0)
		Widgets.List(pill, 8, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		local scale = Instance.new("UIScale")
		scale.Scale = 0.92
		scale.Parent = pill

		if config.Icon then
			local holder = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(15, 15),
				LayoutOrder = 1,
				Parent = pill,
			})
			Icons.Create(holder, config.Icon, { Size = 15, Color = "Accent", Cleanup = cleanup })
		end
		Widgets.Text(cleanup, {
			Name = "Brand",
			Parent = pill,
			Text = config.RestoreText or config.Title or "DeaDx",
			Color = config.TitleColor or "Text",
			Bold = true,
			TextSize = 13,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
		})
		local chevronHolder = Utility.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(14, 14),
			LayoutOrder = 3,
			Parent = pill,
		})
		local chevron = Icons.Create(chevronHolder, "chevron-down", { Size = 14, Color = "MutedText", Cleanup = cleanup })

		Widgets.Interactive(cleanup, pill, pill, {})
		cleanup:Add(pill.Activated:Connect(function()
			self:Restore()
		end))
		if config.RestoreDraggable ~= false then
			Drag.Attach(pill, pill, cleanup, { Margin = 16 })
		end
		self._pill = { Frame = pill, Scale = scale, Chevron = chevron.Instance }
	end

	function Window:_Clamp()
		if self._destroyed then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local scale = Theme.Scale
		local maxW = math.min(self.MaxSize.X, viewport.X / scale - 20)
		local maxH = math.min(self.MaxSize.Y, viewport.Y / scale - 20)
		local minW = math.min(self.MinSize.X, maxW)
		local minH = math.min(self.MinSize.Y, maxH)
		if self._collapsed then
			minH, maxH = TOPBAR, math.max(TOPBAR, maxH)
		end
		local size = self.Root.Size
		local width = math.clamp(size.X.Offset, minW, maxW)
		local height = math.clamp(size.Y.Offset, minH, maxH)
		if width ~= size.X.Offset or height ~= size.Y.Offset then
			self.Root.Size = UDim2.fromOffset(width, height)
		end
	end

	function Window:_UpdateLayout()
		if self._destroyed then
			return
		end
		local width = self.Root.Size.X.Offset
		local compact = width < 520
		local sidebar = compact and 50 or self.TabWidth
		self._compact = compact
		self._sidebar.Size = UDim2.new(0, sidebar, 1, -(TOPBAR + 1))
		self._content.Position = UDim2.fromOffset(sidebar, TOPBAR + 1)
		self._content.Size = UDim2.new(1, -sidebar, 1, -(TOPBAR + 1))
		for _, tab in self.Tabs do
			tab:_SetCompact(compact)
		end
		self._searchBox.Visible = self._searchEnabled and width >= 470 and not self._collapsed
	end

	function Window:_IndexAdd(entry)
		return self._search:Add(entry)
	end

	function Window:_GoTo(entry)
		local tab = entry.Tab
		if self._destroyed or not tab or tab.Cleanup:IsCleaned() then
			return
		end
		if self._minimized then
			self:Restore()
		end
		if self._collapsed then
			self:SetCollapsed(false)
		end
		self:SelectTab(tab)
		if entry.SubTab then
			tab:SelectSubTab(entry.SubTab)
		end
		if entry.Kind == "Tab" or entry.Kind == "SubTab" then
			return
		end
		task.delay(0.22, function()
			if self._destroyed then
				return
			end
			local frame = entry.Frame
			if not frame or not frame.Parent then
				return
			end
			local page = entry.SubTab and entry.SubTab.Page or tab.Body
			if not page or not page:IsA("ScrollingFrame") then
				page = frame:FindFirstAncestorWhichIsA("ScrollingFrame")
			end
			if page then
				local offset = (frame.AbsolutePosition.Y - page.AbsolutePosition.Y) / Theme.Scale + page.CanvasPosition.Y - 10
				Animation:Play(page, { CanvasPosition = Vector2.new(0, math.max(0, offset)) }, { Duration = 0.25 })
			end
			if entry.Component and entry.Component.Flash then
				entry.Component:Flash("Accent")
			end
		end)
	end

	function Window:AddTab(config)
		Utility.Check(not self._destroyed, "Tab", config and config.Title, "Window is destroyed.")
		local tab = Tab.new(self, config)
		table.insert(self.Tabs, tab)
		tab:_SetCompact(self._compact)
		if not self._selected then
			self:SelectTab(tab)
		end
		return tab
	end

	function Window:SelectTab(target)
		if self._destroyed then
			return self
		end
		local tab = target
		if type(target) == "number" then
			tab = self.Tabs[target]
		elseif type(target) == "string" then
			tab = nil
			for _, candidate in self.Tabs do
				if candidate.Title == target then
					tab = candidate
					break
				end
			end
		end
		if not tab or tab == self._selected then
			return self
		end
		self:ClosePopup()
		if self._selected then
			self._selected:_SetSelected(false)
		end
		self._selected = tab
		tab:_SetSelected(true)
		return self
	end
	Window.SetTab = Window.SelectTab

	function Window:GetTab(title)
		for _, tab in self.Tabs do
			if tab.Title == title then
				return tab
			end
		end
		return nil
	end

	function Window:SetTitle(text)
		self._title.SetText(text)
		return self
	end

	function Window:SetTitleColor(color)
		self._title.SetColor(color)
		return self
	end

	function Window:SetSubTitle(text)
		text = text or ""
		self._subtitle.SetText(text)
		self.SubtitleLabel.Visible = text ~= ""
		return self
	end
	Window.SetSubtitle = Window.SetSubTitle

	function Window:SetIcon(spec)
		if self._icon then
			self._icon:Set(spec)
		end
		return self
	end

	function Window:SetIconShape(shape, corner)
		self.Config.IconShape = shape
		if corner ~= nil then
			self.Config.IconCorner = corner
		end
		if self._icon then
			self._icon:SetShape(shape, corner)
		end
		return self
	end

	function Window:SetFooter(text)
		if self._footer then
			self._footer.SetText(text)
		end
		return self
	end

	function Window:SetTheme(name)
		return Theme.Set(name)
	end

	function Window:SetSearchEnabled(enabled)
		self._searchEnabled = enabled == true
		if not self._searchEnabled then
			self._searchInput.Text = ""
		end
		self:_UpdateLayout()
		return self
	end

	function Window:ToggleSearch()
		return self:SetSearchEnabled(not self._searchEnabled)
	end

	function Window:SetBackgroundImage(image, transparency)
		self._image.Image = image or ""
		if transparency ~= nil then
			self._image.ImageTransparency = transparency
		end
		self._image.Visible = (image or "") ~= ""
		return self
	end

	function Window:SetBackground(config)
		if type(config) == "string" then
			config = { Image = config }
		end
		if type(config) ~= "table" then
			return self
		end
		if config.Image ~= nil then
			self._image.Image = config.Image
			self._image.Visible = config.Image ~= ""
		end
		if config.Transparency ~= nil then
			Animation:Play(self._image, { ImageTransparency = config.Transparency }, { Duration = 0.2 })
		end
		if config.ScaleType ~= nil then
			self._image.ScaleType = config.ScaleType
		end
		if config.TileSize ~= nil then
			self._image.TileSize = config.TileSize
		end
		if config.ImageColor ~= nil then
			self._image.ImageColor3 = Theme.Resolve(config.ImageColor, "Text")
		end

		local stops = Widgets.Stops(config.Gradient)
		if stops then
			self._tintGradient.Color = stops
			self._tintGradient.Rotation = config.Rotation or 90
			self._tint.BackgroundColor3 = Color3.new(1, 1, 1)
			self._tint.BackgroundTransparency = config.TintTransparency or 0.25
			self._tint.Visible = true
		elseif config.Color ~= nil then
			self._tintGradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
			self._tint.BackgroundColor3 = Theme.Resolve(config.Color, "Background")
			self._tint.BackgroundTransparency = config.TintTransparency or 0.2
			self._tint.Visible = true
		elseif config.Color == false or config.Gradient == false then
			self._tint.Visible = false
		end
		return self
	end

	function Window:SetAcrylic(enabled)
		self.Acrylic = enabled == true
		if self._paint then
			self._paint.SetVisible(self.Acrylic and not self._minimized)
		end
		if self.Acrylic then
			Acrylic.Enable()
		else
			Acrylic.Disable()
		end
		return self
	end

	function Window:SetTransparency(value)
		value = math.clamp(tonumber(value) or 0, 0, 1)
		if self._paint then
			self._paint.SetTransparency(value)
		elseif self._fill then
			Animation:Play(self._fill, { BackgroundTransparency = value }, { Duration = 0.2 })
		end
		return self
	end

	function Window:SetMinimizeKey(key)
		if self._minimizeBind then
			self._minimizeBind:Destroy()
			self._minimizeBind = nil
		end
		if key ~= nil then
			Utility.Check(typeof(key) == "EnumItem", "Window", "MinimizeKey", "MinimizeKey must be an Enum.KeyCode.")
			self._minimizeBind = self.Cleanup:Add(Input.AddBind(key, function()
				self:Toggle()
			end, "Window toggle"))
		end
		return self
	end

	function Window:SetCollapsed(value)
		value = value == true
		if self._collapsed == value or self._destroyed then
			return self
		end
		self._collapsed = value
		local root = self.Root
		local width = root.Size.X.Offset
		local anchor = root.AnchorPoint.Y
		local position = root.Position
		local target = value and TOPBAR or (self._restoreHeight or 440)
		local shift = (root.Size.Y.Offset - target) * anchor

		if value then
			self._restoreHeight = root.Size.Y.Offset
			self._sidebar.Visible = false
			self._content.Visible = false
			self._topline.Visible = false
			if self._grip then
				self._grip.Visible = false
			end
		end

		Animation:Play(root, {
			Size = UDim2.fromOffset(width, target),
			Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset - shift),
		}, {
			Duration = 0.22,
			Style = Enum.EasingStyle.Quint,
			OnComplete = function()
				if not self._destroyed and not value then
					self:_Clamp()
				end
			end,
		})

		if not value then
			self._sidebar.Visible = true
			self._content.Visible = true
			self._topline.Visible = true
			if self._grip then
				self._grip.Visible = true
			end
		end
		if self._collapseIcon then
			Animation:Play(self._collapseIcon.Instance, { Rotation = value and 180 or 0 }, { Duration = 0.2 })
		end
		self:_UpdateLayout()
		return self
	end

	function Window:ToggleCollapsed()
		return self:SetCollapsed(not self._collapsed)
	end

	function Window:IsCollapsed()
		return self._collapsed
	end

	function Window:SetMaximized(value)
		value = value == true
		if self._maximized == value or self._destroyed then
			return self
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return self
		end
		self._maximized = value
		if value then
			self._restoreRect = { Size = self.Root.Size, Position = self.Root.Position }
			local viewport = camera.ViewportSize / Theme.Scale
			Animation:Play(self.Root, {
				Size = UDim2.fromOffset(math.min(viewport.X - 20, self.MaxSize.X), math.min(viewport.Y - 20, self.MaxSize.Y)),
				Position = UDim2.fromScale(0.5, 0.5),
			}, { Duration = 0.22 })
		elseif self._restoreRect then
			Animation:Play(self.Root, {
				Size = self._restoreRect.Size,
				Position = self._restoreRect.Position,
			}, { Duration = 0.22 })
		end
		return self
	end

	function Window:ToggleMaximized()
		return self:SetMaximized(not self._maximized)
	end

	function Window:_Pill(show)
		local pill = self._pill
		if not pill then
			return
		end
		if show then
			pill.Frame.Visible = true
			pill.Chevron.Rotation = 180
			pill.Scale.Scale = 0.92
			Animation:Play(pill.Scale, { Scale = 1 }, { Duration = Animation.Duration.Normal })
			Animation:Play(pill.Chevron, { Rotation = 0 }, { Duration = Animation.Duration.Normal })
		else
			Animation:Play(pill.Chevron, { Rotation = 180 }, { Duration = Animation.Duration.Fast })
			Animation:Play(pill.Scale, { Scale = 0.92 }, {
				Duration = Animation.Duration.Fast,
				OnComplete = function()
					if not self._minimized and not self._destroyed then
						pill.Frame.Visible = false
					end
				end,
			})
		end
	end

	function Window:Minimize()
		if self._minimized or self._destroyed then
			return self
		end
		self._minimized = true
		self:ClosePopup()
		if self._paint then
			self._paint.SetVisible(false)
		end
		Acrylic.Disable()
		self:_Pill(true)
		self.Root.Visible = false
		if self._popupGui then
			self._popupGui.Enabled = false
		end
		self.MinimizedChanged:Fire(true)
		return self
	end

	function Window:Restore()
		if not self._minimized or self._destroyed then
			return self
		end
		self._minimized = false
		self:_Clamp()
		self.Root.Visible = true
		if self._popupGui then
			self._popupGui.Enabled = true
		end
		self:_Pill(false)
		if self._paint then
			self._paint.SetVisible(true)
			if self.Acrylic then
				Acrylic.Enable()
			end
		end
		self.MinimizedChanged:Fire(false)
		return self
	end

	function Window:ToggleMinimize()
		if self._minimized then
			return self:Restore()
		end
		return self:Minimize()
	end
	Window.Toggle = Window.ToggleMinimize

	function Window:IsMinimized()
		return self._minimized
	end

	function Window:Notify(config)
		return import("Services/Notification").Notify(config)
	end

	function Window:Toast(text, kind)
		return import("Services/Notification").Notify({
			Title = text,
			Type = kind or "Info",
			Duration = 2,
			Progress = false,
		})
	end

	function Window:Focus(component)
		if type(component) == "string" then
			component = self.Options[component]
		end
		if not component or not component._entry then
			return self
		end
		self:_GoTo(component._entry)
		return self
	end

	function Window:Index()
		return self._search
	end

	function Window:Tour(steps, config)
		if self._tour and self._tour:IsRunning() then
			self._tour:Finish(true)
		end
		self._tour = import("Services/Tour").new(self, steps, config)
		self.Cleanup:Add(self._tour)
		return self._tour
	end

	function Window:CreatePalette(config)
		if self._palette then
			return self._palette
		end
		config = type(config) == "table" and config or {}
		self._palette = import("Services/Palette").new(self, config)
		self.Cleanup:Add(self._palette)
		return self._palette
	end

	function Window:GetPalette()
		return self._palette
	end

	function Window:SetUndoKeys(undo, redo)
		for _, bind in self._historyBinds or {} do
			bind:Destroy()
		end
		self._historyBinds = {}
		local function hook(key, action, label)
			if key == nil then
				return
			end
			table.insert(
				self._historyBinds,
				self.Cleanup:Add(Input.AddBind(key, function()
					if self._modifier and not UserInputService:IsKeyDown(self._modifier) then
						return
					end
					local ok, id = action()
					if ok then
						self:Toast(label .. ": " .. tostring(id))
					end
				end, label))
			)
		end
		hook(undo, function()
			return Config:Undo()
		end, "Undone")
		hook(redo, function()
			return Config:Redo()
		end, "Redone")
		return self
	end

	function Window:CreateDialog(config)
		Utility.Check(not self._destroyed, "Dialog", config and config.Title, "Window is destroyed.")
		return Dialog.new(self, config)
	end
	Window.Dialog = Window.CreateDialog

	function Window:OpenPopup(anchor, width, height)
		self:ClosePopup()
		local layer = self._popupLayer
		local cleanup = self.Cleanup:Extend()
		local closed = Signal.new()
		cleanup:Add(closed)

		local catcher = Utility.Create("TextButton", {
			Name = "PopupCatcher",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = layer,
		})
		cleanup:Add(catcher)
		local frame = Widgets.Surface(cleanup, {
			Class = "CanvasGroup",
			Name = "Popup",
			Parent = layer,
			Fill = "SecondaryBackground",
			Stroke = "Border",
			Radius = 12,
			Size = UDim2.fromOffset(width, height),
			GroupTransparency = 1,
			ZIndex = 2,
		})
		cleanup:Add(frame)
		local base = self._outside and Theme.Scale or 1
		local scale = Instance.new("UIScale")
		scale.Scale = base * 0.95
		scale.Parent = frame

		local popup
		local x, y = 0, 0

		local function place()
			local uiScale = Theme.Scale
			local bounds, origin
			if self._outside then
				bounds = layer.AbsoluteSize / uiScale
				origin = Vector2.zero
			else
				bounds = Vector2.new(self.Root.Size.X.Offset, self.Root.Size.Y.Offset)
				origin = self.Root.AbsolutePosition
			end
			local anchorPosition = (anchor.AbsolutePosition - origin) / uiScale
			local anchorSize = anchor.AbsoluteSize / uiScale
			x = anchorPosition.X + anchorSize.X - popup.Width
			y = anchorPosition.Y + anchorSize.Y + 4
			if y + popup.Height > bounds.Y - 8 then
				local above = anchorPosition.Y - popup.Height - 4
				if above >= 8 then
					y = above
				end
			end
			x = math.clamp(x, 8, math.max(8, bounds.X - popup.Width - 8))
			y = math.clamp(y, 8, math.max(8, bounds.Y - popup.Height - 8))
			frame.Position = UDim2.fromOffset(x, y)
		end

		popup = { Frame = frame, Cleanup = cleanup, Closed = closed, Width = width, Height = height, Anchor = anchor }
		local isClosed = false

		local viewport = anchor:FindFirstAncestorWhichIsA("ScrollingFrame")
		local function follow()
			if isClosed then
				return
			end
			if viewport then
				local top = viewport.AbsolutePosition.Y
				local bottom = top + viewport.AbsoluteSize.Y
				local anchorTop = anchor.AbsolutePosition.Y
				local anchorBottom = anchorTop + anchor.AbsoluteSize.Y
				local hidden = anchorBottom < top - 2 or anchorTop > bottom + 2
				frame.Visible = not hidden
				if hidden then
					return
				end
			end
			place()
		end

		place()
		cleanup:Add(anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(follow))
		cleanup:Add(anchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(follow))
		cleanup:Add(self.Root:GetPropertyChangedSignal("AbsolutePosition"):Connect(follow))
		cleanup:Add(Theme.ScaleChanged:Connect(follow))
		frame.Position = UDim2.fromOffset(x, y + 7)
		Animation:Play(frame, { GroupTransparency = 0, Position = UDim2.fromOffset(x, y) }, {
			Duration = 0.2,
			Ease = "Smooth",
		})
		Animation:Play(scale, { Scale = base }, { Duration = 0.28, Ease = "Snap" })
		function popup.Close()
			if isClosed then
				return
			end
			isClosed = true
			if self._popup == popup then
				self._popup = nil
			end
			closed:Fire()
			catcher:Destroy()
			Animation:Play(scale, { Scale = base * 0.97 }, { Duration = 0.12, Ease = "Soft" })
			Animation:Play(frame, { GroupTransparency = 1 }, {
				Duration = 0.13,
				Ease = "Soft",
				OnComplete = function()
					cleanup:Clean()
				end,
			})
			task.delay(0.3, function()
				cleanup:Clean()
			end)
		end
		function popup.Resize(newHeight)
			popup.Height = newHeight
			frame.Size = UDim2.fromOffset(popup.Width, newHeight)
			place()
		end

		popup.Place = place
		cleanup:Add(catcher.Activated:Connect(popup.Close))
		self._popup = popup
		return popup
	end

	function Window:ClosePopup()
		if self._popup then
			self._popup.Close()
		end
		return self
	end

	function Window:Save(name)
		return Config:Save(name or self.Config.SaveFile or Utility.Slug(self.Config.Title or "window"))
	end

	function Window:Load(name)
		return Config:Load(name or self.Config.SaveFile or Utility.Slug(self.Config.Title or "window"))
	end

	function Window:SetAutoSave(enabled, name)
		return Config:SetAutoSave(enabled, name or self.Config.SaveFile or Utility.Slug(self.Config.Title or "window"))
	end

	function Window:Destroy()
		if self._destroyed then
			return
		end
		self._destroyed = true
		if self._popup then
			self._popup.Close()
		end
		self.OnDestroy:Fire()
		Acrylic.Disable()
		Animation:CancelTree(self.Gui)
		self.Cleanup:Clean()
		table.clear(self.Options)
		table.clear(self.Tabs)
	end

	return Window
end
