return function(import)
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local State = import("Core/State")
	local Config = import("Core/Config")
	local Theme = import("Core/Theme")
	local Markup = import("Core/Markup")
	local Widgets = import("Core/Widgets")
	local Editable = import("Core/Editable")
	local Capabilities = import("Core/Capabilities")
	local Icons = import("Icons/Icon")
	local Tooltip = import("Services/Tooltip")
	local Animation = import("Services/Animation")
	local Input = import("Services/Input")

	local Component = { Registry = {} }
	local Base = {}
	Base.__index = Base
	Component.Base = Base

	function Component.Register(name, factory)
		Utility.Check(
			type(name) == "string" and string.match(name, "^%u%w*$") ~= nil,
			"Component",
			name,
			"Name must be PascalCase and alphanumeric."
		)
		Utility.Check(type(factory) == "function", "Component", name, "Factory must be a function.")
		Component.Registry[name] = factory
	end

	function Component.Names()
		local out = {}
		for name in Component.Registry do
			table.insert(out, name)
		end
		table.sort(out)
		return out
	end

	function Component.NewBare(ctx, class, kind, id, config)
		Utility.Check(type(config) == "table", kind, id, "Config must be a table.")
		local self = setmetatable({}, class)
		self.Kind, self.Id, self.Config = kind, id, config
		self.Window, self.Tab, self.Section = ctx.Window, ctx.Tab, ctx.Section
		self.Cleanup = ctx.Cleanup:Extend()
		self.Changed = Signal.new()
		self.TextChanged = Signal.new()
		self.Cleanup:Add(self.Changed)
		self.Cleanup:Add(self.TextChanged)
		self.Enabled, self.Visible, self._destroyed = true, true, false
		self.Cleanup:Add(function()
			self._destroyed = true
			if self._entry then
				self._entry.Remove()
				self._entry = nil
			end
			if self.Id and self.Window.Options[self.Id] == self then
				self.Window.Options[self.Id] = nil
			end
		end)
		ctx.Pending = self
		task.defer(function()
			if self._destroyed or self._entry or not self.Frame then
				return
			end
			local title = config.Title or config.Text
			if type(title) ~= "string" or title == "" or config.Search == false then
				return
			end
			self._entry = ctx.Window:_IndexAdd({
				Kind = kind,
				Title = Markup.Strip(title),
				Description = Markup.Strip(config.Description or config.Content or ""),
				Tab = ctx.Tab,
				Section = ctx.Section,
				Frame = self.Frame,
				Component = self,
			})
		end)
		return self
	end

	local function stub(instance)
		return {
			Instance = instance,
			Source = "",
			SetText = function() end,
			SetColor = function() end,
			SetGradient = function() end,
			SetWeight = function() end,
		}
	end

	function Component.New(ctx, class, kind, id, config, opts)
		opts = opts or {}
		local self = Component.NewBare(ctx, class, kind, id, config)
		local cleanup = self.Cleanup

		if ctx.Host then
			local host = ctx.Host
			self.Frame = host
			self.Hosted = true
			self.Right = Utility.Create("Frame", {
				Name = "Right",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(opts.RightWidth or 40, opts.RightHeight or 22),
				Parent = host,
			})
			self.TitleLabel = nil
			self._title = stub(host)
			self._description = stub(host)
			if config.Tooltip then
				self:SetTooltip(config.Tooltip)
			end
			return self
		end

		local flat = opts.Flat == true

		local frame, stroke = Widgets.Surface(cleanup, {
			Name = kind,
			Parent = ctx.Parent,
			Fill = (not flat) and "SecondaryBackground" or nil,
			Transparency = (not flat) and "ComponentTransparency" or nil,
			Stroke = (not flat) and "Border" or nil,
			StrokeTransparency = (not flat) and "ComponentStrokeTransparency" or nil,
			Radius = opts.Radius or 14,
			Size = UDim2.new(1, 0, 0, opts.MinHeight or 46),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = ctx.Order(),
		})
		cleanup:Add(frame)
		self.Frame, self.Stroke = frame, stroke

		if opts.Flat ~= true and config.Rail ~= false then
			self._rail = Widgets.Surface(cleanup, {
				Name = "Rail",
				Parent = frame,
				Fill = config.RailColor or "Accent",
				Radius = "Full",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 3, 0.5, 0),
				Size = UDim2.fromOffset(2, 0),
				ZIndex = 4,
			})
			cleanup:Add(frame.MouseEnter:Connect(function()
				if self.Enabled and not self:IsLocked() then
					Animation:Play(self._rail, { Size = UDim2.fromOffset(2, 16) }, {
						Duration = 0.26,
						Ease = "Snap",
					})
				end
			end))
			cleanup:Add(frame.MouseLeave:Connect(function()
				Animation:Play(self._rail, { Size = UDim2.fromOffset(2, 0) }, { Duration = 0.18, Ease = "Soft" })
			end))
		end

		local rightWidth = opts.RightWidth or 0
		local left = Utility.Create("Frame", {
			Name = "Left",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, rightWidth > 0 and -(rightWidth + 14) or 0, 0, 0),
			Parent = frame,
		})
		Widgets.Padding(left, 14, 13, 12, 13)
		Widgets.List(left, 11, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		self.Left, self._left = left, left

		local iconSize = tonumber(config.IconSize) or 16
		self._iconSize = iconSize
		self._iconHolder = Utility.Create("Frame", {
			Name = "IconHolder",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(iconSize, iconSize),
			LayoutOrder = 1,
			Visible = false,
			Parent = left,
		})
		self._textCol = Utility.Create("Frame", {
			Name = "TextColumn",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			Parent = left,
		})
		Widgets.List(self._textCol, 3)

		local title = config.Title or config.Text or config.Name or ""
		local description = config.Description or config.Content or config.Desc or ""
		self._editableTitle = config.EditableTitle == true or config.Editable == true
		self._editableDescription = config.EditableDescription == true

		local titleRow = Utility.Create("Frame", {
			Name = "TitleRow",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 1,
			Visible = title ~= "",
			Parent = self._textCol,
		})
		Widgets.List(titleRow, 6, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		self._titleRow = titleRow

		local needsChip = self._editableTitle or self._editableDescription
		self.TitleLabel, self._title = Widgets.Text(cleanup, {
			Class = self._editableTitle and "TextBox" or "TextLabel",
			Name = "Title",
			Parent = titleRow,
			Text = title,
			Color = config.TitleColor,
			Gradient = config.TitleGradient,
			Bold = true,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, needsChip and -24 or 0, 0, 0),
			LayoutOrder = 1,
			Markup = not self._editableTitle,
		})

		self.DescriptionLabel, self._description = Widgets.Text(cleanup, {
			Class = self._editableDescription and "TextBox" or "TextLabel",
			Name = "Description",
			Parent = self._textCol,
			Text = description,
			Color = config.DescriptionColor or config.ContentColor or "MutedText",
			Gradient = config.DescriptionGradient,
			TextSize = 12,
			TextWrapped = true,
			RichText = config.RichText == true or Markup.Has(description),
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0),
			LayoutOrder = 2,
			Visible = description ~= "",
			Markup = not self._editableDescription,
		})

		if config.Badge then
			local badge = Widgets.Surface(cleanup, {
				Name = "Badge",
				Parent = titleRow,
				Fill = config.BadgeColor or "Accent",
				Radius = "Full",
				Size = UDim2.new(0, 0, 0, 15),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = 3,
			})
			Widgets.Padding(badge, 6, 0)
			local _, badgeText = Widgets.Text(cleanup, {
				Parent = badge,
				Text = config.Badge,
				Color = config.BadgeTextColor or "AccentText",
				Heavy = true,
				TextSize = 9,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
			})
			self._badge = badgeText
			self.TitleLabel.Size = UDim2.new(1, needsChip and -70 or -46, 0, 0)
		end

		if needsChip then
			self._chip = Widgets.Chip(cleanup, {
				Name = "Edit",
				Parent = titleRow,
				Radius = "Full",
				Size = UDim2.fromOffset(18, 18),
				LayoutOrder = 2,
				Visible = false,
			})
			Icons.Create(self._chip, "pencil", { Size = 11, Position = UDim2.fromOffset(3.5, 3.5), Cleanup = cleanup })
			cleanup:Add(frame.MouseEnter:Connect(function()
				if self.Enabled then
					self._chip.Visible = true
				end
			end))
			cleanup:Add(frame.MouseLeave:Connect(function()
				self._chip.Visible = false
			end))
		end

		if self._editableTitle then
			self.TitleEditor = Editable.Attach(cleanup, self.TitleLabel, self._title, {
				Label = kind .. " title",
				Color = config.TitleColor,
				Highlight = true,
				Trigger = self._chip,
				Source = function()
					return self._title.Source
				end,
				Validate = config.ValidateTitle,
				OnCommit = function(value)
					self:SetTitle(value)
					Utility.SafeCall(kind .. " OnTitleChanged", config.OnTitleChanged, value)
					self.TextChanged:Fire("Title", value)
				end,
			})
		end
		if self._editableDescription then
			self.DescriptionEditor = Editable.Attach(cleanup, self.DescriptionLabel, self._description, {
				Label = kind .. " description",
				Color = config.DescriptionColor or "MutedText",
				Highlight = true,
				Trigger = (not self._editableTitle) and self._chip or nil,
				Source = function()
					return self._description.Source
				end,
				OnCommit = function(value)
					self:SetDescription(value)
					Utility.SafeCall(kind .. " OnDescriptionChanged", config.OnDescriptionChanged, value)
					self.TextChanged:Fire("Description", value)
				end,
			})
		end

		if rightWidth > 0 then
			self.Right = Utility.Create("Frame", {
				Name = "Right",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(rightWidth, opts.RightHeight or 26),
				ZIndex = 3,
				Parent = frame,
			})
		end

		self:SetIcon(config.Icon)
		if config.IconColor then
			self:SetIconColor(config.IconColor)
		end

		if not opts.NoSearch and (title ~= "" or description ~= "") then
			self._entry = ctx.Window:_IndexAdd({
				Kind = kind,
				Title = Markup.Strip(title),
				Description = Markup.Strip(description),
				Tab = ctx.Tab,
				Section = ctx.Section,
				Frame = frame,
				Component = self,
			})
		end
		if config.Tooltip then
			self:SetTooltip(config.Tooltip)
		end
		if config.Visible == false then
			self:SetVisible(false)
		end
		if config.Enabled == false or config.Disabled == true then
			self:SetEnabled(false)
		end
		if config.Locked then
			self:Lock(type(config.Locked) == "number" and config.Locked or 0, config.LockReason)
		end
		if config.Key then
			self:Bind(config.Key)
		end
		if config.VisibleWhen ~= nil then
			self:DependOn(config.VisibleWhen, "Visible")
		end
		if config.EnabledWhen ~= nil then
			self:DependOn(config.EnabledWhen, "Enabled")
		end

		cleanup:Add(frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 and not self:IsLocked() then
				self:_Menu()
			end
		end))
		return self
	end

	function Component.BindValue(self, id, default, render)
		local state
		if id then
			state = Config:Register(id, default)
		else
			state = State.new(default)
			self.Cleanup:Add(state)
		end
		local valid, value = self:_Normalize(state:Get())
		if not valid then
			value = default
		end
		if value ~= state:Get() or type(value) == "table" then
			state:Set(value, true)
		end
		self.State = state
		self.Cleanup:Add(state.Changed:Connect(function(newValue)
			if self._destroyed then
				return
			end
			render(newValue, true)
			self:_Emit(newValue)
		end))
		Theme.BindFn(function()
			render(state:Get(), false)
		end, self.Cleanup)
	end

	function Base:_Normalize(value)
		return true, value
	end

	function Base:_Emit(value)
		if self._destroyed then
			return
		end
		Utility.SafeCall(self.Kind .. " " .. tostring(self.Id or self.Config.Title or "?"), self.Config.Callback, value)
		self.Changed:Fire(value)
	end

	function Base:GetValue()
		return self.State and self.State:Get()
	end

	function Base:SetValue(value)
		if not self.State then
			Utility.Warn(self.Kind .. " does not hold a value.")
			return self
		end
		local valid, normalized = self:_Normalize(value)
		if not valid then
			Utility.Warn(string.format('Invalid value for %s "%s".', self.Kind, tostring(self.Id)))
			return self
		end
		self.State:Set(normalized)
		return self
	end

	function Base:OnChanged(callback)
		return self.Changed:Connect(callback)
	end

	function Base:SetCallback(callback)
		Utility.Check(callback == nil or type(callback) == "function", self.Kind, self.Id, "Callback must be a function.")
		self.Config.Callback = callback
		return self
	end

	function Base:GetTitle()
		return self._title and self._title.Source or ""
	end

	function Base:GetDescription()
		return self._description and self._description.Source or ""
	end

	function Base:SetTitle(text)
		text = text == nil and "" or tostring(text)
		self._title.SetText(text)
		if self._titleRow then
			self._titleRow.Visible = text ~= ""
		end
		if self._entry then
			self._entry.Title = Markup.Strip(text)
		end
		return self
	end

	function Base:SetDescription(text)
		text = text == nil and "" or tostring(text)
		self._description.SetText(text)
		self.DescriptionLabel.Visible = text ~= ""
		if self._entry then
			self._entry.Description = Markup.Strip(text)
		end
		return self
	end
	Base.SetContent = Base.SetDescription
	Base.SetDesc = Base.SetDescription

	function Base:SetTitleColor(color)
		self._title.SetColor(color)
		return self
	end

	function Base:SetDescriptionColor(color)
		self._description.SetColor(color)
		return self
	end

	function Base:SetTitleGradient(stops)
		self._title.SetGradient(stops)
		return self
	end

	function Base:SetDescriptionGradient(stops)
		self._description.SetGradient(stops)
		return self
	end

	function Base:SetTextColor(color)
		self:SetTitleColor(color)
		self:SetDescriptionColor(color)
		return self
	end

	function Base:SetEditable(kind, enabled)
		if kind == "Title" and self.TitleEditor then
			self.TitleEditor.SetEnabled(enabled ~= false)
		elseif kind == "Description" and self.DescriptionEditor then
			self.DescriptionEditor.SetEnabled(enabled ~= false)
		end
		return self
	end

	function Base:Edit(kind)
		local editor = kind == "Description" and self.DescriptionEditor or self.TitleEditor
		if editor then
			editor.Begin()
		end
		return self
	end

	function Base:SetIcon(spec)
		local holder = self._iconHolder
		if not holder then
			return self
		end
		if spec == nil then
			if self._icon then
				self._icon:Set(nil)
			end
			holder.Visible = false
			self._textCol.Size = UDim2.new(1, 0, 0, 0)
			return self
		end
		if self._icon then
			self._icon:Set(spec)
		else
			self._icon = Icons.Create(holder, spec, Icons.Options(self.Config, {
				Size = self._iconSize or 16,
				Color = self.Config.IconColor or "MutedText",
				Cleanup = self.Cleanup,
			}))
		end
		holder.Visible = true
		self._textCol.Size = UDim2.new(1, -((self._iconSize or 16) + 11), 0, 0)
		return self
	end

	function Base:SetIconColor(color)
		if self._icon then
			self._icon:SetColor(color)
		end
		return self
	end

	function Base:SetIconShape(shape, corner)
		self.Config.IconShape = shape
		if corner ~= nil then
			self.Config.IconCorner = corner
		end
		if self._icon then
			self._icon:SetShape(shape, corner)
		end
		return self
	end

	function Base:SetIconTint(enabled)
		self.Config.IconTint = enabled
		if self._icon then
			self._icon:SetTint(enabled)
		end
		return self
	end

	function Base:SetVisible(visible)
		self.Visible = visible == true
		if self.Frame then
			self.Frame.Visible = self.Visible
		end
		return self
	end

	function Base:SetEnabled(enabled)
		self.Enabled = enabled == true
		if not self.Frame then
			return self
		end
		if self.Enabled then
			if self._blocker then
				self._blocker:Destroy()
				self._blocker = nil
			end
		elseif not self._blocker then
			if self._chip then
				self._chip.Visible = false
			end
			self._blocker = Widgets.Surface(self.Cleanup, {
				Name = "DisabledOverlay",
				Parent = self.Frame,
				Fill = "Background",
				BackgroundTransparency = 0.5,
				Radius = self.Config.Radius or 14,
				Active = true,
				ZIndex = 20,
				Size = UDim2.fromScale(1, 1),
			})
		end
		return self
	end

	local function clock(seconds)
		seconds = math.max(seconds, 0)
		local minutes = math.floor(seconds / 60)
		local rest = math.ceil(seconds % 60)
		if rest == 60 then
			minutes += 1
			rest = 0
		end
		if minutes >= 60 then
			return string.format("%d:%02d:%02d", math.floor(minutes / 60), minutes % 60, rest)
		end
		return string.format("%02d:%02d", minutes, rest)
	end
	Component.Clock = clock

	function Base:_BuildLock()
		if self._lock then
			return self._lock
		end
		local cleanup = self.Cleanup
		local radius = self.Config.Radius or 14

		local cover = Widgets.Surface(cleanup, {
			Class = "CanvasGroup",
			Name = "Lock",
			Parent = self.Frame,
			Fill = "Background",
			BackgroundTransparency = 0.22,
			Radius = radius,
			Active = true,
			ClipsDescendants = true,
			AutomaticSize = Enum.AutomaticSize.None,
			ZIndex = 30,
			Size = UDim2.new(1, 0, 0, 40),
			Visible = false,
			GroupTransparency = 1,
		})

		local function sync()
			local height = 0
			if self._left then
				height = math.max(height, self._left.AbsoluteSize.Y)
			end
			if self.Right then
				height = math.max(height, self.Right.AbsoluteSize.Y + 16)
			end
			if height < 12 then
				height = math.max(self.Frame.Size.Y.Offset, 40)
			end
			cover.Size = UDim2.new(1, 0, 0, height)
		end
		self._lockSync = sync
		if self._left then
			cleanup:Add(self._left:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync))
		end
		sync()
		Utility.Create("UIGradient", {
			Rotation = 35,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.5, 0.3),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
			Parent = cover,
		})

		local shine = Widgets.Surface(cleanup, {
			Name = "Shine",
			Parent = cover,
			Fill = "Text",
			BackgroundTransparency = 0.94,
			Radius = 0,
			Rotation = 18,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 46, 1, 0),
			Position = UDim2.new(0, -40, 0.5, 0),
		})

		local row = Utility.Create("Frame", {
			Name = "Row",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 0, 0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = cover,
		})
		Widgets.List(row, 7, {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		local iconHolder = Utility.Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(15, 15),
			LayoutOrder = 1,
			Parent = row,
		})
		local icon = Icons.Create(iconHolder, "lock", { Size = 15, Color = "MutedText", Cleanup = cleanup })

		local _, label = Widgets.Text(cleanup, {
			Parent = row,
			Text = "00:00",
			Color = "Text",
			Bold = true,
			TextSize = 12,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 2,
			Markup = false,
		})

		local bar = Widgets.Surface(cleanup, {
			Name = "Bar",
			Parent = cover,
			Fill = self.Config.LockColor or "Accent",
			Radius = "Full",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -3),
			Size = UDim2.new(1, 0, 0, 2),
		})

		local hit = Utility.Create("TextButton", {
			Name = "Hit",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = cover,
		})

		local function nudge()
			Widgets.Pulse(iconHolder, 0.72, 0.35)
			Animation:Play(icon.Instance, { Rotation = -14 }, { Duration = 0.06 })
			task.delay(0.06, function()
				if icon.Instance.Parent then
					Animation:Play(icon.Instance, { Rotation = 12 }, { Duration = 0.07 })
					task.delay(0.07, function()
						if icon.Instance.Parent then
							Animation:Play(icon.Instance, { Rotation = 0 }, { Duration = 0.12 })
						end
					end)
				end
			end)
		end

		cleanup:Add(hit.Activated:Connect(nudge))
		cleanup:Add(hit.MouseEnter:Connect(function()
			Animation:Play(cover, { BackgroundTransparency = 0.12 }, { Duration = 0.15 })
			icon:SetColor(self.Config.LockColor or "Accent")
			Animation:Play(shine, { Position = UDim2.new(1, 50, 0.5, 0) }, {
				Duration = 0.55,
				Style = Enum.EasingStyle.Quad,
			})
			task.delay(0.6, function()
				if shine.Parent then
					shine.Position = UDim2.new(0, -50, 0.5, 0)
				end
			end)
		end))
		cleanup:Add(hit.MouseLeave:Connect(function()
			Animation:Play(cover, { BackgroundTransparency = 0.22 }, { Duration = 0.2 })
			icon:SetColor("MutedText")
		end))

		self._lock = {
			Frame = cover,
			Row = row,
			Icon = icon,
			Label = label,
			Bar = bar,
			Hit = hit,
			Nudge = nudge,
		}
		return self._lock
	end

	function Base:Lock(seconds, reason)
		if self._destroyed or not self.Frame then
			return self
		end
		local lock = self:_BuildLock()
		local total = tonumber(seconds) or 0
		self._lockUntil = total > 0 and (os.clock() + total) or math.huge
		self._lockReason = reason

		if self._lockThread then
			pcall(task.cancel, self._lockThread)
			self._lockThread = nil
		end
		if self._lockSync then
			self._lockSync()
		end
		lock.Frame.Visible = true
		lock.Bar.Visible = total > 0
		lock.Label.Instance.Visible = total > 0
		lock.Label.SetText(total > 0 and clock(total) or (reason or ""))
		if reason and total <= 0 then
			lock.Label.Instance.Visible = true
		end
		Animation:Play(lock.Frame, { GroupTransparency = 0 }, { Duration = 0.2 })
		Widgets.Pulse(lock.Row, 0.82, 0.32)

		if total > 0 then
			self._lockThread = task.spawn(function()
				while not self._destroyed do
					local left = self._lockUntil - os.clock()
					if left <= 0 then
						break
					end
					lock.Label.SetText(clock(left))
					lock.Bar.Size = UDim2.new(math.clamp(left / total, 0, 1), 0, 0, 2)
					task.wait(0.05)
				end
				if not self._destroyed then
					self:Unlock()
				end
			end)
			self.Cleanup:Add(self._lockThread)
		end
		return self
	end

	function Base:Unlock()
		if not self._lock then
			return self
		end
		self._lockUntil = nil
		if self._lockThread then
			pcall(task.cancel, self._lockThread)
			self._lockThread = nil
		end
		local cover = self._lock.Frame
		Animation:Play(cover, { GroupTransparency = 1 }, {
			Duration = 0.22,
			OnComplete = function()
				if cover.Parent and not self:IsLocked() then
					cover.Visible = false
				end
			end,
		})
		if self.Stroke then
			Widgets.Glow(self.Stroke, self.Config.LockColor or "Accent", 0.35)
		end
		Utility.SafeCall(self.Kind .. " OnUnlock", self.Config.OnUnlock)
		return self
	end

	function Base:IsLocked()
		if not self._lockUntil then
			return false
		end
		if self._lockUntil == math.huge then
			return true
		end
		return os.clock() < self._lockUntil
	end

	function Base:GetLockRemaining()
		if not self:IsLocked() or self._lockUntil == math.huge then
			return 0
		end
		return math.max(self._lockUntil - os.clock(), 0)
	end

	function Base:SetCooldown(seconds)
		self.Config.Cooldown = tonumber(seconds) or 0
		return self
	end

	function Base:Shake()
		if self._lock and self:IsLocked() then
			self._lock.Nudge()
		end
		return self
	end

	function Base:SetTooltip(text)
		if not self.Frame then
			return self
		end
		if self._tooltip then
			self._tooltip.Text = text
		else
			self._tooltip = Tooltip.Attach(self.Frame, text, self.Cleanup)
		end
		return self
	end

	function Base:DependOn(spec, mode)
		local function evaluate()
			if type(spec) == "function" then
				local ok, result = pcall(spec, self.Window.Options)
				return ok and result == true
			end
			if type(spec) == "string" then
				local value = Config:Get(spec)
				return value ~= nil and value ~= false
			end
			if type(spec) == "table" then
				for id, expected in spec do
					local value = Config:Get(id)
					if type(expected) == "function" then
						local ok, result = pcall(expected, value)
						if not ok or result ~= true then
							return false
						end
					elseif type(expected) == "table" then
						if table.find(expected, value) == nil then
							return false
						end
					elseif value ~= expected then
						return false
					end
				end
				return true
			end
			return true
		end

		local last
		local function apply(instant)
			local on = evaluate()
			if on == last then
				return
			end
			last = on
			if mode == "Enabled" then
				self:SetEnabled(on)
			else
				self:SetVisible(on)
				if on and not instant and self.Frame then
					self.Frame.Position = UDim2.fromOffset(-10, 0)
					Animation:Play(self.Frame, { Position = UDim2.new() }, { Duration = 0.18 })
				end
			end
		end

		self.Cleanup:Add(Config.Changed:Connect(function()
			apply(false)
		end))
		apply(true)
		return self
	end

	function Base:GetDefault()
		return self.Id and Config._defaults[self.Id] or self.Config.Default
	end

	function Base:Reset()
		local default = self:GetDefault()
		if default ~= nil and self.State then
			self.State:Set(Utility.DeepCopy(default))
		end
		return self
	end

	function Base:Bind(key)
		if self._menuBind then
			self._menuBind:Destroy()
			self._menuBind = nil
		end
		if key == nil or key == Enum.KeyCode.Unknown then
			self.BoundKey = nil
			return self
		end
		self.BoundKey = key
		self._menuBind = self.Cleanup:Add(Input.AddBind(key, function()
			self:Trigger()
		end, self.Kind .. " " .. tostring(self.Id or self:GetTitle())))
		return self
	end

	function Base:Trigger()
		if not self.Enabled or self:IsLocked() then
			return self
		end
		if type(self.Fire) == "function" then
			self:Fire()
		elseif self.State and type(self.State:Get()) == "boolean" then
			self.State:Set(not self.State:Get())
		elseif self.Window then
			self.Window:Focus(self)
		end
		return self
	end

	local function describe(value)
		if type(value) == "boolean" then
			return value and "on" or "off"
		end
		if typeof(value) == "Color3" then
			return Utility.ToHex(value)
		end
		if typeof(value) == "EnumItem" then
			return value.Name
		end
		if type(value) == "table" then
			local parts = {}
			for name, on in value do
				if on == true then
					table.insert(parts, tostring(name))
				end
			end
			if #parts > 0 then
				table.sort(parts)
				return table.concat(parts, ", ")
			end
			return "empty"
		end
		if value == nil then
			return "none"
		end
		return tostring(value)
	end
	Component.Describe = describe

	function Base:_Menu()
		if self._destroyed or not self.Window or self.Config.Menu == false then
			return
		end
		local entries = {}
		local function add(title, icon, callback, color)
			table.insert(entries, { Title = title, Icon = icon, Callback = callback, Color = color })
		end

		if self.State then
			add("Copy value", "copy", function()
				Capabilities.SetClipboard(describe(self.State:Get()))
			end)
			if self:GetDefault() ~= nil then
				add("Reset to default", "rotate-ccw", function()
					self:Reset()
				end)
			end
		end
		if type(self.Fire) == "function" or (self.State and type(self.State:Get()) == "boolean") then
			add(self.BoundKey and ("Key: " .. self.BoundKey.Name) or "Set key", "keyboard", function()
				self:_Capture()
			end)
		end
		local bar = self.Window.StatusBar or (self.Window.Owner and self.Window.Owner.StatusBars[1])
		if bar and self.State then
			local pinned = bar._fields and bar._fields[self.Id or Utility.Slug(self:GetTitle())]
			add(pinned and "Unpin from status bar" or "Pin to status bar", "pin", function()
				local id = self.Id or Utility.Slug(self:GetTitle())
				if bar._fields[id] then
					bar:RemoveField(id)
					return
				end
				local clickable = type(self.State:Get()) == "boolean" or type(self.Fire) == "function"
				bar:AddField(id, {
					Label = Markup.Strip(self:GetTitle()),
					Icon = self.Config.Icon,
					Value = function()
						return describe(self.State:Get())
					end,
					Callback = clickable and function()
						self:Trigger()
					end or nil,
				})
			end)
		end
		if self.Config.Menu then
			for _, entry in self.Config.Menu do
				if type(entry) == "table" and entry.Title then
					add(entry.Title, entry.Icon, entry.Callback, entry.Color)
				end
			end
		end
		if #entries == 0 then
			return
		end

		local popup = self.Window:OpenPopup(self.Frame, 184, #entries * 28 + 10)
		local cleanup = popup.Cleanup
		Widgets.Padding(popup.Frame, 5)
		Widgets.List(popup.Frame, 2)
		for index, entry in entries do
			local row = Widgets.Surface(cleanup, {
				Class = "TextButton",
				Parent = popup.Frame,
				Fill = "SecondaryBackground",
				Transparency = 1,
				Radius = 8,
				Size = UDim2.new(1, 0, 0, 26),
				LayoutOrder = index,
			})
			Icons.Create(row, entry.Icon or "dot", {
				Size = 13,
				Color = entry.Color or "MutedText",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 9, 0.5, 0),
				Cleanup = cleanup,
			})
			Widgets.Text(cleanup, {
				Parent = row,
				Text = entry.Title,
				Color = entry.Color or "Text",
				TextSize = 12,
				Position = UDim2.fromOffset(29, 0),
				Size = UDim2.new(1, -36, 1, 0),
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			Widgets.Interactive(cleanup, row, row, { Alpha = { 1, 0.6, 0.45 } })
			cleanup:Add(row.Activated:Connect(function()
				popup.Close()
				Utility.SafeCall("Menu " .. entry.Title, entry.Callback)
			end))
		end
	end

	function Base:_Capture()
		if self._capturingKey then
			return
		end
		self._capturingKey = true
		self:Flash("Accent")
		local cancel = Input.Capture(function(key, cancelled)
			self._capturingKey = false
			if self._destroyed then
				return
			end
			if cancelled then
				return
			end
			self:Bind(key ~= Enum.KeyCode.Unknown and key or nil)
			if self.Window then
				self.Window:Toast(self:GetTitle() .. " -> " .. (key and key.Name or "unbound"))
			end
		end)
		self.Cleanup:Add(cancel)
	end

	function Base:SetBadge(text)
		if self._badge then
			self._badge.SetText(text)
			Widgets.Pulse(self._badge.Instance, 0.8, 0.3)
		end
		return self
	end

	function Base:SetLayoutOrder(order)
		if self.Frame then
			self.Frame.LayoutOrder = order
		end
		return self
	end

	function Base:Flash(token)
		if not self.Stroke then
			return self
		end
		local stroke = self.Stroke
		Animation:Play(stroke, { Color = Theme.Get(token or "Accent"), Transparency = 0 }, { Duration = 0.15 })
		task.delay(0.9, function()
			if stroke.Parent and not self._destroyed then
				Animation:Play(stroke, {
					Color = Theme.Get("Border"),
					Transparency = Theme.Get("ComponentStrokeTransparency"),
				}, { Duration = 0.3 })
			end
		end)
		return self
	end

	function Base:Destroy()
		if self._destroyed then
			return
		end
		if self.Frame then
			Animation:CancelTree(self.Frame)
		end
		self.Cleanup:Clean()
	end

	function Component.Add(owner, name, first, second)
		local factory = Component.Registry[name]
		local id, config
		if type(first) == "string" then
			id, config = first, second
		else
			config = first
		end
		config = config or {}
		if type(config) ~= "table" then
			Utility.Fail(name, id, "Config must be a table.")
		end
		if id ~= nil and owner.Window.Options[id] then
			Utility.Fail(name, id, "Duplicate id: an option with this id already exists in this window.")
		end
		local ctx = {
			Parent = owner.Container,
			Window = owner.Window,
			Tab = owner.TabRef,
			Section = owner.SectionRef,
			Cleanup = owner.Cleanup,
			Order = owner.NextOrder,
		}
		local ok, result = pcall(factory, ctx, id, config)
		if not ok then
			if ctx.Pending then
				pcall(function()
					ctx.Pending:Destroy()
				end)
			end
			local message = tostring(result)
			if string.sub(message, 1, 7) == "[DEADX]" then
				error(message, 0)
			end
			Utility.Fail(name, id, message)
		end
		if id ~= nil then
			owner.Window.Options[id] = result
		end
		return result
	end

	function Component.MakeContainer(class)
		class.__index = function(object, key)
			local method = rawget(class, key)
			if method ~= nil then
				return method
			end
			local name = type(key) == "string" and string.match(key, "^Add(%u%w*)$")
			if name and Component.Registry[name] then
				return function(self, first, second)
					return Component.Add(self, name, first, second)
				end
			end
			return nil
		end
	end

	return Component
end

