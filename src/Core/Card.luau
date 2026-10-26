return function(import)
	local Utility = import("Core/Utility")
	local Markup = import("Core/Markup")
	local Widgets = import("Core/Widgets")
	local Component = import("Core/Component")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local Card = {}
	Component.MakeContainer(Card)

	function Card.new(owner, config)
		if type(config) == "string" then
			config = { Title = config }
		end
		config = config or {}
		local self = setmetatable({}, Card)
		local tab = owner.TabRef or owner
		local window = owner.Window
		self.Window, self.Title, self.TabRef, self.SectionRef = window, config.Title, tab, self
		self.Config = config
		self.Cleanup = owner.Cleanup:Extend()
		self._order = 0
		self._collapsed = false
		self.NextOrder = function()
			self._order += 1
			return self._order
		end
		local cleanup = self.Cleanup

		local inset = config.Accent and 10 or 0
		local wrapper = Utility.Create("Frame", {
			Name = "Card",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = owner.NextOrder(),
			Parent = owner.Container,
		})
		cleanup:Add(wrapper)
		self.Wrapper = wrapper

		local frame, stroke = Widgets.Surface(cleanup, {
			Name = "Surface",
			Parent = wrapper,
			Fill = config.Fill or "SecondaryBackground",
			Transparency = config.Transparency or "ComponentTransparency",
			Stroke = config.Border or "Border",
			StrokeTransparency = "ComponentStrokeTransparency",
			Radius = config.Radius or 16,
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(inset, 0),
			Size = UDim2.new(1, -inset, 0, 0),
		})
		Widgets.Padding(frame, 12, 12)
		Widgets.List(frame, 10)
		self.Frame, self.Stroke = frame, stroke

		if config.Accent then
			Widgets.Surface(cleanup, {
				Name = "Accent",
				Parent = wrapper,
				Fill = config.Accent,
				Radius = "Full",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.new(0, 3, 1, -16),
			})
		end

		if config.Title then
			local collapsible = config.Collapsible == true
			local header = Utility.Create(collapsible and "TextButton" or "Frame", {
				Name = "Header",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 20),
				LayoutOrder = 0,
				Parent = frame,
			})
			Widgets.List(header, 7, {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			})
			self.Header = header

			if config.Icon then
				local holder = Utility.Create("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(15, 15),
					LayoutOrder = 1,
					Parent = header,
				})
				self._icon = Icons.Create(holder, config.Icon, Icons.Options(config, {
					Size = 15,
					Color = config.IconColor or config.Accent or "Accent",
					Cleanup = cleanup,
				}))
			end
			local _, handle = Widgets.Text(cleanup, {
				Parent = header,
				Text = config.Title,
				Color = config.TitleColor or "Text",
				Gradient = config.TitleGradient,
				Bold = true,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				LayoutOrder = 2,
			})
			self._text = handle

			if config.Badge then
				local badge = Widgets.Surface(cleanup, {
					Name = "Badge",
					Parent = header,
					Fill = config.BadgeColor or "Accent",
					Radius = "Full",
					Size = UDim2.new(0, 0, 0, 16),
					AutomaticSize = Enum.AutomaticSize.X,
					LayoutOrder = 3,
				})
				Widgets.Padding(badge, 7, 0)
				local _, badgeText = Widgets.Text(cleanup, {
					Parent = badge,
					Text = config.Badge,
					Color = config.BadgeTextColor or "AccentText",
					Bold = true,
					TextSize = 10,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 1, 0),
				})
				self._badge = badgeText
			end

			if collapsible then
				local chevronHolder = Utility.Create("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(13, 13),
					Parent = header,
				})
				self._chevron = Icons.Create(chevronHolder, "chevron-down", {
					Size = 13,
					Color = "MutedText",
					Cleanup = cleanup,
				})
				cleanup:Add(header.Activated:Connect(function()
					self:Toggle()
				end))
			end
		end

		local clip = Utility.Create("Frame", {
			Name = "Clip",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 1,
			Parent = frame,
		})
		self._clip = clip

		self.Container = Utility.Create("Frame", {
			Name = "Body",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = clip,
		})
		Widgets.List(self.Container, config.Gap or 8)

		local function fit()
			if self._collapsed or self._animating then
				return
			end
			clip.Size = UDim2.new(1, 0, 0, self.Container.AbsoluteSize.Y)
		end
		cleanup:Add(self.Container:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
		task.defer(fit)
		self._fit = fit

		if config.Title then
			self._entry = window:_IndexAdd({
				Kind = "Card",
				Title = Markup.Strip(config.Title),
				Tab = tab,
				Section = self,
				Frame = frame,
			})
			cleanup:Add(function()
				if self._entry then
					self._entry.Remove()
				end
			end)
		end
		if config.Collapsed == true then
			self:Collapse(true)
		end
		return self
	end

	function Card:AddCard(config)
		return Card.new(self, config)
	end

	function Card:AddSection(config)
		return import("Core/Section").new(self, config)
	end

	function Card:SetTitle(text)
		self.Title = text
		if self._text then
			self._text.SetText(text)
		end
		if self._entry then
			self._entry.Title = Markup.Strip(text)
		end
		return self
	end

	function Card:SetBadge(text)
		if self._badge then
			self._badge.SetText(text)
			Widgets.Pulse(self._badge.Instance, 0.8, 0.3)
		end
		return self
	end

	function Card:SetIcon(spec)
		if self._icon then
			self._icon:Set(spec)
		end
		return self
	end

	function Card:Collapse(instant)
		if self._collapsed then
			return self
		end
		self._collapsed = true
		self._animating = true
		Animation:Play(self._clip, { Size = UDim2.new(1, 0, 0, 0) }, {
			Duration = instant and 0 or 0.26,
			Ease = "Smooth",
			OnComplete = function()
				self._animating = false
			end,
		})
		if self._chevron then
			Animation:Play(self._chevron.Instance, { Rotation = -90 }, {
				Duration = instant and 0 or 0.26,
				Ease = "Smooth",
			})
		end
		return self
	end

	function Card:Expand(instant)
		if not self._collapsed then
			return self
		end
		self._collapsed = false
		self._animating = true
		Animation:Play(self._clip, { Size = UDim2.new(1, 0, 0, self.Container.AbsoluteSize.Y) }, {
			Duration = instant and 0 or 0.28,
			Ease = "Smooth",
			OnComplete = function()
				self._animating = false
				self._fit()
			end,
		})
		if self._chevron then
			Animation:Play(self._chevron.Instance, { Rotation = 0 }, {
				Duration = instant and 0 or 0.28,
				Ease = "Smooth",
			})
		end
		return self
	end

	function Card:Toggle()
		if self._collapsed then
			return self:Expand()
		end
		return self:Collapse()
	end

	function Card:SetVisible(visible)
		self.Wrapper.Visible = visible == true
		return self
	end

	function Card:Destroy()
		self.Cleanup:Clean()
	end

	return Card
end
