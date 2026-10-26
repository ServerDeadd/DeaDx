return function(import)
	local Utility = import("Core/Utility")
	local Widgets = import("Core/Widgets")
	local Theme = import("Core/Theme")
	local Cleanup = import("Services/Cleanup")
	local Toast = import("Components/Notification")

	local Notification = { Max = 6, Side = "BottomRight", Width = 282 }

	local root, gui, holder
	local active = {}
	local counter = 0

	local SIDES = {
		bottomright = { Vector2.new(1, 1), UDim2.new(1, -8, 1, -8), Enum.VerticalAlignment.Bottom, Enum.HorizontalAlignment.Right },
		bottomleft = { Vector2.new(0, 1), UDim2.new(0, 8, 1, -8), Enum.VerticalAlignment.Bottom, Enum.HorizontalAlignment.Left },
		topright = { Vector2.new(1, 0), UDim2.new(1, -8, 0, 8), Enum.VerticalAlignment.Top, Enum.HorizontalAlignment.Right },
		topleft = { Vector2.new(0, 0), UDim2.new(0, 8, 0, 8), Enum.VerticalAlignment.Top, Enum.HorizontalAlignment.Left },
		topcenter = { Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8), Enum.VerticalAlignment.Top, Enum.HorizontalAlignment.Center },
		bottomcenter = { Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8), Enum.VerticalAlignment.Bottom, Enum.HorizontalAlignment.Center },
	}

	local function ensure()
		if gui and gui.Parent then
			return
		end
		root = Cleanup.new()
		gui = root:Add(Utility.NewScreenGui("DeaDx_Notifications", 1500))
		holder = Utility.Create("Frame", {
			Name = "Holder",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(Notification.Width, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = gui,
		})
		Widgets.List(holder, 7)
		local scale = Instance.new("UIScale")
		scale.Parent = holder
		Theme.BindScale(scale, root)
		Notification.SetSide(Notification.Side)
	end

	function Notification.SetSide(side)
		Notification.Side = side
		if not holder then
			return
		end
		local preset = SIDES[string.lower(string.gsub(tostring(side), "[%s%-]", ""))] or SIDES.bottomright
		holder.AnchorPoint = preset[1]
		holder.Position = preset[2]
		local layout = holder:FindFirstChildOfClass("UIListLayout")
		if layout then
			layout.VerticalAlignment = preset[3]
			layout.HorizontalAlignment = preset[4]
		end
	end

	function Notification.Notify(config)
		Utility.Check(type(config) == "table", "Notification", "?", "Config must be a table.")
		ensure()
		counter += 1
		local toast = Toast.new(holder, config, counter, function(closed)
			local index = table.find(active, closed)
			if index then
				table.remove(active, index)
			end
		end)
		table.insert(active, toast)
		while #active > Notification.Max do
			active[1]:Close()
		end
		return toast
	end

	function Notification.Ask(config)
		Utility.Check(type(config) == "table", "Notification", "?", "Config must be a table.")
		local copy = table.clone(config)
		copy.Options = config.Options or { config.Confirm or "Yes", config.Cancel or "No" }
		copy.Type = config.Type or "Warning"
		copy.Duration = config.Duration or 0
		copy.Closable = config.Closable ~= false
		return Notification.Notify(copy)
	end

	function Notification.Prompt(config)
		Utility.Check(type(config) == "table", "Notification", "?", "Config must be a table.")
		local copy = table.clone(config)
		copy.Input = config.Input or config.Placeholder or true
		copy.Type = config.Type or "Info"
		copy.Duration = config.Duration or 0
		copy.Closable = config.Closable ~= false
		return Notification.Notify(copy)
	end

	function Notification.Count()
		return #active
	end

	function Notification.SetMax(value)
		Notification.Max = math.max(tonumber(value) or 6, 1)
		while #active > Notification.Max do
			active[1]:Close()
		end
		return Notification.Max
	end

	function Notification.SetWidth(value)
		Notification.Width = math.clamp(tonumber(value) or 282, 180, 520)
		if holder then
			holder.Size = UDim2.fromOffset(Notification.Width, 0)
		end
		return Notification.Width
	end

	function Notification.List()
		return table.clone(active)
	end

	function Notification.CloseAll()
		for _, toast in table.clone(active) do
			toast:Close()
		end
	end

	function Notification.Reset()
		for _, toast in table.clone(active) do
			toast:Destroy()
		end
		table.clear(active)
		if root then
			root:Clean()
		end
		root, gui, holder = nil, nil, nil
	end

	return Notification
end
