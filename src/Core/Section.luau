return function(import)
	local Utility = import("Core/Utility")
	local Theme = import("Core/Theme")
	local Markup = import("Core/Markup")
	local Widgets = import("Core/Widgets")
	local Component = import("Core/Component")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local Section = {}
	Component.MakeContainer(Section)

	function Section.new(owner, config)
		if type(config) == "string" then
			config = { Title = config }
		end
		config = config or {}
		Utility.Check(type(config.Title) == "string", "Section", config.Title, "Title must be a string.")
		local self = setmetatable({}, Section)
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

		local frame = Utility.Create("Frame", {
			Name = "Section",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = owner.NextOrder(),
			Parent = owner.Container,
		})
		cleanup:Add(frame)
		Widgets.List(frame, 12)
		self.Frame = frame

		local collapsible = config.Collapsible == true
		local header = Utility.Create(collapsible and "TextButton" or "Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = 0,
			Parent = frame,
		})
		self.Header = header

		local row = Utility.Create("Frame", {
			Name = "Row",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -5),
			Parent = header,
		})
		Widgets.List(row, 7, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		if collapsible then
			local chevronHolder = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(12, 12),
				LayoutOrder = 0,
				Parent = row,
			})
			self._chevron = Icons.Create(chevronHolder, "chevron-down", {
				Size = 12,
				Color = "MutedText",
				Cleanup = cleanup,
			})
		end

		if config.Icon then
			local holder = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(13, 13),
				LayoutOrder = 1,
				Parent = row,
			})
			self._icon = Icons.Create(holder, config.Icon, Icons.Options(config, {
				Size = 13,
				Color = config.IconColor or config.Color or "MutedText",
				Cleanup = cleanup,
			}))
		end

		self.Label, self._text = Widgets.Text(cleanup, {
			Name = "Title",
			Parent = row,
			Text = config.Title,
			Color = config.Color or config.TitleColor or "MutedText",
			Gradient = config.Gradient,
			Bold = true,
			TextSize = 12,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
		})

		self._line = Widgets.Surface(cleanup, {
			Name = "Line",
			Parent = header,
			Fill = config.LineColor or "Border",
			Radius = 0,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 1, -1),
			Visible = config.Line ~= false,
		})

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
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = clip,
		})
		Widgets.List(self.Container, config.Gap or 9)

		local function fit()
			if self._collapsed or self._animating then
				return
			end
			clip.Size = UDim2.new(1, 0, 0, self.Container.AbsoluteSize.Y)
		end
		cleanup:Add(self.Container:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
		task.defer(fit)
		self._fit = fit

		if collapsible then
			cleanup:Add(header.Activated:Connect(function()
				self:Toggle()
			end))
			if config.Collapsed == true then
				self:Collapse(true)
			end
		end

		self._entry = window:_IndexAdd({
			Kind = "Section",
			Title = Markup.Strip(config.Title),
			Tab = tab,
			Section = self,
			Frame = header,
		})
		cleanup:Add(function()
			if self._entry then
				self._entry.Remove()
			end
		end)
		return self
	end

	function Section:AddCard(config)
		return import("Core/Card").new(self, config)
	end

	function Section:SetTitle(text)
		self.Title = text
		self._text.SetText(text)
		if self._entry then
			self._entry.Title = Markup.Strip(text)
		end
		return self
	end

	function Section:SetColor(color)
		self._text.SetColor(color)
		return self
	end

	function Section:SetIcon(spec)
		if self._icon then
			self._icon:Set(spec)
		end
		return self
	end

	function Section:SetIconColor(color)
		if self._icon then
			self._icon:SetColor(color)
		end
		return self
	end

	function Section:Collapse(instant)
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

	function Section:Expand(instant)
		if not self._collapsed then
			return self
		end
		self._collapsed = false
		self._animating = true
		local target = self.Container.AbsoluteSize.Y
		Animation:Play(self._clip, { Size = UDim2.new(1, 0, 0, target) }, {
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

	function Section:Toggle()
		if self._collapsed then
			return self:Expand()
		end
		return self:Collapse()
	end

	function Section:IsCollapsed()
		return self._collapsed
	end

	function Section:SetVisible(visible)
		self.Frame.Visible = visible == true
		return self
	end

	function Section:Destroy()
		self.Cleanup:Clean()
	end

	return Section
end
