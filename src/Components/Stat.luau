return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local Stat = setmetatable({}, { __index = Component.Base })
	Stat.__index = Stat

	local function format(value, config)
		if type(value) == "number" then
			local rounded = Utility.Round(value, config.Decimals or 0)
			if config.Short and math.abs(rounded) >= 1000 then
				local units = { "k", "M", "B" }
				local scaled, step = rounded, 0
				while math.abs(scaled) >= 1000 and step < #units do
					scaled /= 1000
					step += 1
				end
				return string.format("%.1f%s", scaled, units[step])
			end
			return string.format("%." .. tostring(config.Decimals or 0) .. "f", rounded)
		end
		return tostring(value)
	end

	function Stat:_Normalize(value)
		if value == nil then
			return true, 0
		end
		return true, value
	end

	function Stat:Bind(getter, interval)
		self:Unbind()
		self._poll = task.spawn(function()
			while not self._destroyed do
				local ok, value = pcall(getter)
				if ok and value ~= nil then
					self:SetValue(value)
				end
				task.wait(interval or 1)
			end
		end)
		self.Cleanup:Add(self._poll)
		return self
	end

	function Stat:Unbind()
		if self._poll then
			pcall(task.cancel, self._poll)
			self._poll = nil
		end
		return self
	end

	return function(ctx, id, config)
		local self = Component.New(ctx, Stat, "Stat", id, config, {
			RightWidth = config.Width or 120,
			RightHeight = 30,
			MinHeight = 52,
		})
		local cleanup = self.Cleanup

		local trendHolder
		if config.Trend then
			trendHolder = Utility.Create("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(14, 14),
				Parent = self.Right,
			})
			self._trend = Icons.Create(trendHolder, "trending-up", {
				Size = 14,
				Color = "Success",
				Cleanup = cleanup,
			})
		end

		local _, value = Widgets.Text(cleanup, {
			Name = "Value",
			Parent = self.Right,
			Text = "0",
			Color = config.ValueColor or "Text",
			Gradient = config.ValueGradient,
			Heavy = true,
			TextSize = config.TextSize or 19,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, trendHolder and -19 or 0, 0.5, 0),
			Size = UDim2.new(1, trendHolder and -19 or 0, 1, 0),
		})
		self._value = value

		local suffix = config.Suffix or ""
		local previous = 0

		local function render(current, animate)
			local text = format(current, config) .. suffix
			value.SetText(text)
			if animate then
				Widgets.Pulse(value.Instance, 0.86, 0.3)
			end
			if self._trend and type(current) == "number" then
				local up = current >= previous
				self._trend:Set(up and "trending-up" or "trending-down")
				self._trend:SetColor(up and "Success" or "Error")
			end
			if type(current) == "number" then
				previous = current
			end
		end
		Component.BindValue(self, id, config.Default or 0, render)

		if config.Bind then
			self:Bind(config.Bind, config.Interval)
		end
		return self
	end
end
