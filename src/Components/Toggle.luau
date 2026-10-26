return function(import)
	local Component = import("Core/Component")
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local Animation = import("Services/Animation")

	local Toggle = setmetatable({}, { __index = Component.Base })
	Toggle.__index = Toggle

	function Toggle:_Normalize(value)
		if type(value) == "boolean" then
			return true, value
		end
		return false
	end

	function Toggle:Flip()
		self.State:Set(not self.State:Get())
		return self
	end

	return function(ctx, id, config)
		Utility.Check(
			config.Default == nil or type(config.Default) == "boolean",
			"Toggle",
			id,
			"Default value must be boolean."
		)
		local extra = config.Picker and 62 or 0
		local self = Component.New(ctx, Toggle, "Toggle", id, config, {
			RightWidth = 38 + extra,
			RightHeight = 22,
		})
		local cleanup = self.Cleanup

		local track, trackStroke = Widgets.Surface(cleanup, {
			Name = "Track",
			Parent = self.Right,
			Fill = "TertiaryBackground",
			Stroke = "Border",
			StrokeTransparency = 0.45,
			Radius = "Full",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(38, 20),
		})

		if config.Picker then
			local slot = Utility.Create("Frame", {
				Name = "Picker",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(56, 22),
				ZIndex = 3,
				Parent = self.Right,
			})
			local settings = typeof(config.Picker) == "Color3" and { Default = config.Picker } or config.Picker
			settings = table.clone(settings)
			settings.Title = settings.Title or (config.Title or "") .. " color"
			settings.Search = false
			settings.Menu = false
			local factory = Component.Registry.Colorpicker
			if factory then
				self.Picker = factory({
					Host = slot,
					Parent = slot,
					Window = self.Window,
					Tab = self.Tab,
					Section = self.Section,
					Cleanup = cleanup,
					Order = function()
						return 1
					end,
				}, id and (id .. "/Picker") or nil, settings)
			end
		end
		local knob = Widgets.Surface(cleanup, {
			Name = "Knob",
			Parent = track,
			Fill = "MutedText",
			Radius = "Full",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(14, 14),
		})
		self._track, self._knob = track, knob

		local activeColor = config.Color or config.ActiveColor or "Accent"
		local knobColor = config.KnobColor or "AccentText"

		local function render(value, animate)
			local trackColor = value and Theme.Resolve(activeColor, "Accent") or Theme.Get("TertiaryBackground")
			local dotColor = value and Theme.Resolve(knobColor, "AccentText") or Theme.Get("MutedText")
			local position = value and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
			local alpha = value and 0 or Theme.Get("ElementTransparency")
			if animate then
				Animation:Play(track, { BackgroundColor3 = trackColor, BackgroundTransparency = alpha }, { Duration = 0.15 })
				Animation:Play(knob, { BackgroundColor3 = dotColor, Position = position }, {
					Duration = 0.22,
					Style = Enum.EasingStyle.Back,
				})
				Animation:Play(knob, { Size = UDim2.fromOffset(value and 16 or 14, value and 16 or 14) }, { Duration = 0.1 })
				task.delay(0.1, function()
					if knob.Parent then
						Animation:Play(knob, { Size = UDim2.fromOffset(14, 14) }, { Duration = 0.14 })
					end
				end)
			else
				track.BackgroundColor3 = trackColor
				track.BackgroundTransparency = alpha
				knob.BackgroundColor3 = dotColor
				knob.Position = position
			end
			trackStroke.Transparency = value and 1 or 0.45
		end
		Component.BindValue(self, id, config.Default == true, render)

		local hit = Utility.Create("TextButton", {
			Name = "Hit",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = self.Frame,
		})
		Widgets.Interactive(cleanup, self.Frame, hit, {})
		cleanup:Add(hit.Activated:Connect(function()
			self.State:Set(not self.State:Get())
		end))

		function self:SetColor(color)
			activeColor = color
			render(self.State:Get(), true)
			return self
		end

		return self
	end
end
