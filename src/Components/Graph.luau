return function(import)
	local RunService = game:GetService("RunService")
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local Graph = setmetatable({}, { __index = Component.Base })
	Graph.__index = Graph

	function Graph:Push(value)
		value = tonumber(value)
		if not value then
			return self
		end
		table.insert(self.Points, value)
		while #self.Points > self.Capacity do
			table.remove(self.Points, 1)
		end
		self._dirty = true
		return self
	end

	function Graph:Clear()
		table.clear(self.Points)
		self._dirty = true
		return self
	end

	function Graph:GetPoints()
		return table.clone(self.Points)
	end

	function Graph:Latest()
		return self.Points[#self.Points]
	end

	function Graph:Average()
		if #self.Points == 0 then
			return 0
		end
		local sum = 0
		for _, value in self.Points do
			sum += value
		end
		return sum / #self.Points
	end

	function Graph:Bounds()
		local low, high = math.huge, -math.huge
		for _, value in self.Points do
			low = math.min(low, value)
			high = math.max(high, value)
		end
		if low == math.huge then
			return 0, 1
		end
		if self.Config.Min ~= nil then
			low = self.Config.Min
		end
		if self.Config.Max ~= nil then
			high = self.Config.Max
		end
		if high - low < 1e-3 then
			high = low + 1
		end
		return low, high
	end

	function Graph:_Draw()
		local count = #self.Points
		if count == 0 then
			for _, bar in self.Bars do
				bar.Visible = false
			end
			return
		end
		local low, high = self:Bounds()
		local span = high - low
		local total = #self.Bars
		local first = math.max(count - total + 1, 1)
		local shown = count - first + 1

		for index = 1, total do
			local bar = self.Bars[index]
			local slot = index - (total - shown)
			if slot < 1 then
				bar.Visible = false
			else
				local value = self.Points[first + slot - 1]
				local alpha = math.clamp((value - low) / span, 0, 1)
				bar.Visible = true
				bar.Size = UDim2.new(1 / total, -1, math.max(alpha, 0.02), 0)
			end
		end

		if self._value then
			self._value.SetText(string.format(self.Config.Format or "%.0f", self.Points[count]) .. (self.Config.Suffix or ""))
		end
		if self._range then
			self._range.SetText(string.format("%.0f / %.0f", low, high))
		end
	end

	function Graph:Bind(getter, interval)
		self:Unbind()
		self._thread = task.spawn(function()
			while not self._destroyed do
				local ok, value = pcall(getter)
				if ok and value ~= nil then
					self:Push(value)
				end
				task.wait(interval or self.Config.Interval or 0.5)
			end
		end)
		self.Cleanup:Add(self._thread)
		return self
	end

	function Graph:Unbind()
		if self._thread then
			pcall(task.cancel, self._thread)
			self._thread = nil
		end
		return self
	end

	return function(ctx, id, config)
		local self = Component.NewBare(ctx, Graph, "Graph", id, config)
		local cleanup = self.Cleanup
		local height = config.Height or 96
		self.Points = {}
		self.Capacity = config.Capacity or 90

		local frame, stroke = Widgets.Surface(cleanup, {
			Name = "Graph",
			Parent = ctx.Parent,
			Fill = "SecondaryBackground",
			Transparency = "ComponentTransparency",
			Stroke = "Border",
			StrokeTransparency = "ComponentStrokeTransparency",
			Radius = 14,
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = ctx.Order(),
		})
		cleanup:Add(frame)
		self.Frame, self.Stroke = frame, stroke
		Widgets.Padding(frame, 13, 11)

		local header = Utility.Create("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			Parent = frame,
		})
		if config.Icon then
			local holder = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				Parent = header,
			})
			self._icon = Icons.Create(holder, config.Icon, Icons.Options(config, {
				Size = config.IconSize or 14,
				Color = config.IconColor or config.Color or "Accent",
				Cleanup = cleanup,
			}))
		end
		local _, titleHandle = Widgets.Text(cleanup, {
			Parent = header,
			Text = config.Title or "Graph",
			Color = config.TitleColor or "Text",
			Bold = true,
			TextSize = 12,
			Position = UDim2.fromOffset(config.Icon and 20 or 0, 0),
			Size = UDim2.new(1, -110, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		self._title = titleHandle

		local _, value = Widgets.Text(cleanup, {
			Parent = header,
			Text = "0",
			Color = config.Color or "Accent",
			Heavy = true,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(74, 16),
			Markup = false,
		})
		self._value = value

		local plot = Utility.Create("Frame", {
			Name = "Plot",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 1, -38),
			Parent = frame,
		})

		for line = 1, 3 do
			Widgets.Surface(cleanup, {
				Parent = plot,
				Fill = "Border",
				Radius = 0,
				BackgroundTransparency = 0.6,
				Position = UDim2.fromScale(0, (line - 1) / 2),
				Size = UDim2.new(1, 0, 0, 1),
			})
		end

		local bars = Utility.Create("Frame", {
			Name = "Bars",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = plot,
		})
		self.Bars = {}
		local count = config.Bars or 48
		for index = 1, count do
			local bar = Widgets.Surface(cleanup, {
				Parent = bars,
				Fill = config.Color or "Accent",
				Radius = 2,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new((index - 1) / count, 0, 1, 0),
				Size = UDim2.new(1 / count, -1, 0, 0),
				Visible = false,
			})
			table.insert(self.Bars, bar)
		end
		local stops = Widgets.Stops(config.Gradient)
		if stops then
			for _, bar in self.Bars do
				Utility.Create("UIGradient", { Color = stops, Rotation = 90, Parent = bar })
			end
		end

		local footer = Utility.Create("Frame", {
			Name = "Footer",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 12),
			Parent = frame,
		})
		local _, range = Widgets.Text(cleanup, {
			Parent = footer,
			Text = "0 / 1",
			Color = "MutedText",
			TextSize = 10,
			Size = UDim2.fromScale(1, 1),
			Markup = false,
		})
		self._range = range
		if config.Description then
			Widgets.Text(cleanup, {
				Parent = footer,
				Text = config.Description,
				Color = "MutedText",
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.fromScale(1, 1),
			})
		end

		cleanup:Add(RunService.Heartbeat:Connect(function()
			if self._dirty and not self._destroyed then
				self._dirty = false
				self:_Draw()
			end
		end))

		function self:SetTitle(text)
			self._title.SetText(text)
			return self
		end

		if config.Source then
			self:Bind(config.Source, config.Interval)
		end
		return self
	end
end
