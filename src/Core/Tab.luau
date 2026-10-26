return function(import)
	local Utility = import("Core/Utility")
	local Theme = import("Core/Theme")
	local Markup = import("Core/Markup")
	local Widgets = import("Core/Widgets")
	local Component = import("Core/Component")
	local Section = import("Core/Section")
	local Animation = import("Services/Animation")
	local Icons = import("Icons/Icon")

	local SUBBAR = 34

	local SubTab = {}
	Component.MakeContainer(SubTab)

	local Tab = {}
	Component.MakeContainer(Tab)

	function SubTab.new(tab, config)
		if type(config) == "string" then
			config = { Title = config }
		end
		config = config or {}
		Utility.Check(type(config.Title) == "string", "SubTab", config.Title, "Title must be a string.")
		local self = setmetatable({}, SubTab)
		local window = tab.Window
		self.Window, self.Title, self.TabRef, self.SectionRef = window, config.Title, tab, nil
		self.Parent = tab
		self.Config = config
		self.Selected = false
		self.Cleanup = tab.Cleanup:Extend()
		self._order = 0
		self.NextOrder = function()
			self._order += 1
			return self._order
		end
		local cleanup = self.Cleanup

		local button = Widgets.Surface(cleanup, {
			Class = "TextButton",
			Name = "SubTab",
			Parent = tab._subBar,
			Fill = "SecondaryBackground",
			Transparency = 1,
			Radius = "Full",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = #tab.SubTabs + 1,
		})
		cleanup:Add(button)
		self.Button = button
		Widgets.Padding(button, 12, 0)
		Widgets.List(button, 6, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		if config.Icon then
			local holder = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(14, 14),
				LayoutOrder = 1,
				Parent = button,
			})
			self._icon = Icons.Create(holder, config.Icon, Icons.Options(config, {
				Size = 14,
				Color = config.IconColor or "MutedText",
				Cleanup = cleanup,
			}))
		end

		self.Label, self._text = Widgets.Text(cleanup, {
			Parent = button,
			Text = config.Title,
			Color = config.TitleColor or "MutedText",
			TextSize = 12,
			Bold = true,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
		})

		local page = Widgets.Scroller(cleanup, {
			Name = "SubPage",
			Parent = tab._subHolder,
			Visible = false,
		})
		cleanup:Add(page)
		Widgets.Padding(page, 2, 2, 8, 10)
		Widgets.List(page, config.Gap or 9)
		self.Page, self.Container = page, page

		cleanup:Add(button.MouseEnter:Connect(function()
			self._hover = true
			self:_Visual()
		end))
		cleanup:Add(button.MouseLeave:Connect(function()
			self._hover = false
			self:_Visual()
		end))
		cleanup:Add(button.Activated:Connect(function()
			tab:SelectSubTab(self)
		end))
		Theme.BindFn(function()
			self:_Visual(true)
		end, cleanup)

		self._entry = window:_IndexAdd({
			Kind = "SubTab",
			Title = Markup.Strip(config.Title),
			Tab = tab,
			SubTab = self,
			Frame = page,
		})
		cleanup:Add(function()
			if self._entry then
				self._entry.Remove()
			end
		end)
		return self
	end

	function SubTab:_Visual(instant)
		local selected, hover = self.Selected, self._hover
		local goal = {
			BackgroundColor3 = Theme.Get(selected and "Accent" or "Hover"),
			BackgroundTransparency = selected and 0 or (hover and 0.6 or 1),
		}
		local textColor = Theme.Resolve(
			selected and (self.Config.SelectedColor or "AccentText") or (self.Config.TitleColor or "MutedText"),
			"MutedText"
		)
		if instant then
			for property, value in goal do
				self.Button[property] = value
			end
			self.Label.TextColor3 = textColor
		else
			Animation:Play(self.Button, goal, { Duration = Animation.Duration.Fast })
			Animation:Play(self.Label, { TextColor3 = textColor }, { Duration = Animation.Duration.Fast })
		end
		if self._icon then
			self._icon:SetColor(selected and (self.Config.SelectedColor or "AccentText") or (self.Config.IconColor or "MutedText"))
		end
	end

	function SubTab:_SetSelected(selected)
		self.Selected = selected
		self.Page.Visible = selected
		if selected then
			self.Page.Position = UDim2.fromOffset(0, 5)
			Animation:Play(self.Page, { Position = UDim2.new() }, { Duration = 0.24, Ease = "Smooth" })
			task.defer(function()
				if self.Selected then
					self.Parent:_Stagger()
				end
			end)
		end
		self:_Visual()
	end

	function SubTab:Select()
		self.Parent:SelectSubTab(self)
		return self
	end

	function SubTab:SetTitle(text)
		self.Title = text
		self._text.SetText(text)
		if self._entry then
			self._entry.Title = Markup.Strip(text)
		end
		return self
	end

	function SubTab:SetIcon(spec)
		if self._icon then
			self._icon:Set(spec)
		end
		return self
	end

	function SubTab:AddSection(config)
		return Section.new(self, config)
	end

	function SubTab:AddCard(config)
		return import("Core/Card").new(self, config)
	end

	function SubTab:Destroy()
		local parent = self.Parent
		local index = table.find(parent.SubTabs, self)
		if index then
			table.remove(parent.SubTabs, index)
		end
		local wasSelected = parent._subSelected == self
		if wasSelected then
			parent._subSelected = nil
		end
		self.Cleanup:Clean()
		if wasSelected and parent.SubTabs[1] then
			parent:SelectSubTab(parent.SubTabs[1])
		end
	end

	function Tab.new(window, config)
		if type(config) == "string" then
			config = { Title = config }
		end
		Utility.Check(
			type(config) == "table" and type(config.Title) == "string",
			"Tab",
			config and config.Title,
			"Title must be a string."
		)
		local self = setmetatable({}, Tab)
		self.Window, self.Title, self.Config = window, config.Title, config
		self.TabRef, self.SectionRef = self, nil
		self.SubTabs = {}
		self.Selected, self._hover, self._compact = false, false, false
		self._order = 0
		self.NextOrder = function()
			self._order += 1
			return self._order
		end
		self.Cleanup = window.Cleanup:Extend()
		local cleanup = self.Cleanup

		local button = Widgets.Surface(cleanup, {
			Class = "TextButton",
			Name = "Tab",
			Parent = window._tabList,
			Fill = "SecondaryBackground",
			BackgroundTransparency = 1,
			Radius = 9,
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = #window.Tabs + 1,
		})
		cleanup:Add(button)
		self.Button = button

		self._indicator = Widgets.Surface(cleanup, {
			Name = "Indicator",
			Parent = button,
			Fill = config.IndicatorColor or "Accent",
			Radius = "Full",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 2, 0.5, 0),
			Size = UDim2.fromOffset(3, 0),
		})
		self._icon = Icons.Create(button, config.Icon, Icons.Options(config, {
			Size = config.IconSize or 16,
			Color = config.IconColor or "MutedText",
			Cleanup = cleanup,
		}))
		self.Label, self._text = Widgets.Text(cleanup, {
			Name = "Title",
			Parent = button,
			Text = config.Title,
			Color = config.TitleColor or "MutedText",
			Gradient = config.TitleGradient,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -40, 1, 0),
			Position = UDim2.fromOffset(36, 0),
		})

		self._badge = Widgets.Surface(cleanup, {
			Name = "Badge",
			Parent = button,
			Fill = config.BadgeColor or "Accent",
			Radius = "Full",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -9, 0.5, 0),
			Size = UDim2.fromOffset(0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			Visible = false,
			ZIndex = 3,
		})
		Widgets.Padding(self._badge, 6, 0)
		local _, badgeText = Widgets.Text(cleanup, {
			Parent = self._badge,
			Text = "",
			Color = config.BadgeTextColor or "AccentText",
			Heavy = true,
			TextSize = 10,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Markup = false,
		})
		self._badgeText = badgeText
		if config.Badge then
			task.defer(function()
				self:SetBadge(config.Badge)
			end)
		end

		local page = Utility.Create("Frame", {
			Name = "Page",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			Parent = window._pages,
		})
		cleanup:Add(page)
		self.Page = page

		self._subBar = Utility.Create("ScrollingFrame", {
			Name = "SubBar",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 0, SUBBAR - 8),
			Position = UDim2.fromOffset(12, 4),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
			Visible = false,
			Parent = page,
		})
		Widgets.List(self._subBar, 6, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		self._subHolder = Utility.Create("Frame", {
			Name = "SubPages",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(12, SUBBAR),
			Size = UDim2.new(1, -12, 1, -SUBBAR),
			Visible = false,
			Parent = page,
		})

		local body = Widgets.Scroller(cleanup, {
			Name = "Body",
			Parent = page,
		})
		Widgets.Padding(body, 12, 12, 14, 14)
		Widgets.List(body, config.Gap or 9)
		self.Body, self.Container = body, body

		cleanup:Add(button.MouseEnter:Connect(function()
			self._hover = true
			self:_Visual()
		end))
		cleanup:Add(button.MouseLeave:Connect(function()
			self._hover = false
			self:_Visual()
		end))
		cleanup:Add(button.Activated:Connect(function()
			window:SelectTab(self)
		end))
		Theme.BindFn(function()
			self:_Visual(true)
		end, cleanup)

		self._entry = window:_IndexAdd({
			Kind = "Tab",
			Title = Markup.Strip(config.Title),
			Tab = self,
		})
		cleanup:Add(function()
			if self._entry then
				self._entry.Remove()
			end
		end)
		self:_Layout()
		return self
	end

	function Tab:_Layout()
		local hasIcon = self._icon.Instance.Visible
		if self._compact then
			self._icon.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
			self._icon.Instance.Position = UDim2.fromScale(0.5, 0.5)
			self.Label.Visible = false
		else
			self._icon.Instance.AnchorPoint = Vector2.zero
			self._icon.Instance.Position = UDim2.new(0, 13, 0.5, -(self._icon.Instance.Size.Y.Offset / 2))
			self.Label.Visible = true
			local x = hasIcon and 36 or 13
			local trail = (self._badge and self._badge.Visible) and (self._badge.AbsoluteSize.X + 14) or 8
			self.Label.Position = UDim2.fromOffset(x, 0)
			self.Label.Size = UDim2.new(1, -(x + trail), 1, 0)
		end
		if self._badge then
			self._badge.Visible = self._badgeOn == true and not self._compact
		end
	end

	function Tab:_SetCompact(compact)
		if self._compact ~= compact then
			self._compact = compact
			self:_Layout()
		end
	end

	function Tab:_Visual(instant)
		local selected, hover = self.Selected, self._hover
		local goal = {
			BackgroundColor3 = Theme.Get(selected and "SecondaryBackground" or "Hover"),
			BackgroundTransparency = selected and 0.1 or (hover and 0.55 or 1),
		}
		local textColor = Theme.Resolve(
			selected and (self.Config.SelectedColor or "Text") or (self.Config.TitleColor or "MutedText"),
			"MutedText"
		)
		local indicator = { Size = UDim2.fromOffset(3, selected and 15 or 0) }
		if instant then
			for property, value in goal do
				self.Button[property] = value
			end
			self.Label.TextColor3 = textColor
			self._indicator.Size = indicator.Size
		else
			Animation:Play(self.Button, goal, { Duration = Animation.Duration.Fast })
			Animation:Play(self.Label, { TextColor3 = textColor }, { Duration = Animation.Duration.Fast })
			Animation:Play(self._indicator, indicator, { Duration = Animation.Duration.Fast })
		end
		self._icon:SetColor(selected and (self.Config.SelectedColor or "Text") or (self.Config.IconColor or "MutedText"))
	end

	function Tab:_Stagger()
		local host = self._subSelected and self._subSelected.Container or self.Body
		if not host or not host.Visible then
			return
		end
		local items = {}
		for _, child in host:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				table.insert(items, child)
			end
		end
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		Animation:Sequence(items, function(item, _, delay)
			local target = item.Position
			item.Position = UDim2.new(target.X.Scale, target.X.Offset - 14, target.Y.Scale, target.Y.Offset)
			Animation:Play(item, { Position = target }, {
				Duration = 0.3,
				Delay = delay,
				Ease = "Smooth",
			})
		end, { Limit = 14 })
	end

	function Tab:_SetSelected(selected)
		self.Selected = selected
		self.Page.Visible = selected
		if selected then
			self.Page.Position = UDim2.fromOffset(0, 6)
			Animation:Play(self.Page, { Position = UDim2.new() }, { Duration = 0.26, Ease = "Smooth" })
			task.defer(function()
				if self.Selected then
					self:_Stagger()
				end
			end)
		end
		self:_Visual()
	end

	function Tab:Select()
		self.Window:SelectTab(self)
		return self
	end

	function Tab:Deselect()
		if self.Window._selected == self then
			self.Window._selected = nil
		end
		self:_SetSelected(false)
		return self
	end

	function Tab:SetTitle(text)
		self.Title = text
		self._text.SetText(text)
		if self._entry then
			self._entry.Title = Markup.Strip(text)
		end
		return self
	end

	function Tab:SetTitleColor(color)
		self.Config.TitleColor = color
		self._text.SetColor(color)
		self:_Visual(true)
		return self
	end

	function Tab:SetIcon(spec)
		self._icon:Set(spec)
		self:_Layout()
		return self
	end

	function Tab:SetIconColor(color)
		self.Config.IconColor = color
		self._icon:SetColor(color)
		return self
	end

	function Tab:SetIconShape(shape, corner)
		self.Config.IconShape = shape
		if corner ~= nil then
			self.Config.IconCorner = corner
		end
		self._icon:SetShape(shape, corner)
		return self
	end

	function Tab:SetBadge(text)
		if text == nil or text == false or text == "" then
			self._badgeOn = false
			self._badge.Visible = false
			self:_Layout()
			return self
		end
		local first = not self._badgeOn
		self._badgeOn = true
		self._badgeText.SetText(tostring(text))
		self._badge.Visible = not self._compact
		Widgets.Pulse(self._badge, first and 0.5 or 0.82, 0.32)
		task.defer(function()
			if not self.Cleanup:IsCleaned() then
				self:_Layout()
			end
		end)
		return self
	end

	function Tab:GetBadge()
		return self._badgeOn and self._badgeText.Source or nil
	end

	function Tab:SetVisible(visible)
		self.Button.Visible = visible == true
		return self
	end

	function Tab:AddSection(config)
		return Section.new(self, config)
	end

	function Tab:AddCard(config)
		return import("Core/Card").new(self, config)
	end

	function Tab:AddSubTab(config)
		local sub = SubTab.new(self, config)
		table.insert(self.SubTabs, sub)
		if #self.SubTabs == 1 then
			self._subBar.Visible = true
			self._subHolder.Visible = true
			self.Body.Visible = false
		end
		if not self._subSelected then
			self:SelectSubTab(sub)
		end
		return sub
	end

	function Tab:SelectSubTab(target)
		local sub = target
		if type(target) == "number" then
			sub = self.SubTabs[target]
		elseif type(target) == "string" then
			sub = nil
			for _, candidate in self.SubTabs do
				if candidate.Title == target then
					sub = candidate
					break
				end
			end
		end
		if not sub or sub == self._subSelected then
			return self
		end
		if self._subSelected then
			self._subSelected:_SetSelected(false)
		end
		self._subSelected = sub
		sub:_SetSelected(true)
		return self
	end

	function Tab:GetSubTab(title)
		for _, sub in self.SubTabs do
			if sub.Title == title then
				return sub
			end
		end
		return nil
	end

	function Tab:Destroy()
		local window = self.Window
		local index = table.find(window.Tabs, self)
		if index then
			table.remove(window.Tabs, index)
		end
		local wasSelected = window._selected == self
		if wasSelected then
			window._selected = nil
		end
		Animation:CancelTree(self.Page)
		self.Cleanup:Clean()
		if wasSelected and window.Tabs[1] then
			window:SelectTab(window.Tabs[1])
		end
	end

	Tab.SubTab = SubTab
	return Tab
end
