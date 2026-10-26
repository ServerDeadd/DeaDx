return function(import)
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Theme = import("Core/Theme")
	local Widgets = import("Core/Widgets")
	local Markup = import("Core/Markup")
	local Capabilities = import("Core/Capabilities")
	local Icons = import("Icons/Icon")
	local Animation = import("Services/Animation")

	local Console = {
		Limit = 300,
		Entries = {},
		Added = Signal.new(),
		Cleared = Signal.new(),
		Mirror = false,
	}

	local LEVELS = {
		Info = { Color = "Info", Icon = "info" },
		Success = { Color = "Success", Icon = "circle-check" },
		Warning = { Color = "Warning", Icon = "triangle-alert" },
		Error = { Color = "Error", Icon = "alert-circle" },
		Debug = { Color = "MutedText", Icon = "bug" },
	}

	function Console.Log(text, level, tag)
		level = LEVELS[level] and level or "Info"
		local entry = {
			Text = tostring(text),
			Level = level,
			Tag = tag,
			Clock = os.date("%H:%M:%S"),
			Time = os.clock(),
		}
		table.insert(Console.Entries, entry)
		while #Console.Entries > Console.Limit do
			table.remove(Console.Entries, 1)
		end
		if Console.Mirror then
			local prefix = "[DEADX]" .. (tag and ("[" .. tag .. "]") or "")
			if level == "Error" then
				warn(prefix .. " " .. entry.Text)
			else
				print(prefix, entry.Text)
			end
		end
		Console.Added:Fire(entry)
		return entry
	end

	function Console.Clear()
		table.clear(Console.Entries)
		Console.Cleared:Fire()
	end

	function Console.Dump()
		local lines = {}
		for _, entry in Console.Entries do
			table.insert(lines, string.format(
				"[%s][%s]%s %s",
				entry.Clock,
				string.upper(entry.Level),
				entry.Tag and ("[" .. entry.Tag .. "]") or "",
				Markup.Strip(entry.Text)
			))
		end
		return table.concat(lines, "\n")
	end

	function Console.Levels()
		local out = {}
		for name in LEVELS do
			table.insert(out, name)
		end
		table.sort(out)
		return out
	end

	function Console.Build(container, config)
		config = config or {}
		Utility.Check(
			type(container) == "table" and container.Container,
			"Console",
			"?",
			"Needs a tab, section or card."
		)
		local cleanup = container.Cleanup:Extend()
		local height = config.Height or 190
		local filter, level = "", "All"
		local handle = {}

		local frame, stroke = Widgets.Surface(cleanup, {
			Name = "Console",
			Parent = container.Container,
			Fill = config.Background or "Background",
			Transparency = config.Transparency or 0.2,
			Stroke = "Border",
			StrokeTransparency = 0.5,
			Radius = 14,
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = container.NextOrder(),
		})
		cleanup:Add(frame)
		Widgets.Padding(frame, 10, 10)

		local bar = Utility.Create("Frame", {
			Name = "Bar",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
			Parent = frame,
		})
		local _, search = Widgets.Field(cleanup, {
			Name = "Filter",
			Parent = bar,
			Radius = 9,
			Placeholder = "filter...",
			Size = UDim2.new(1, -128, 1, 0),
			Inset = 9,
			Trail = 9,
		})
		cleanup:Add(search:GetPropertyChangedSignal("Text"):Connect(function()
			filter = string.lower(search.Text)
			if handle.Refresh then
				handle:Refresh()
			end
		end))

		local function chip(iconName, offset, callback)
			local button = Widgets.Chip(cleanup, {
				Parent = bar,
				Radius = 9,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -offset, 0.5, 0),
				Size = UDim2.fromOffset(26, 26),
			})
			local icon = Icons.Create(button, iconName, {
				Size = 13,
				Position = UDim2.fromOffset(6.5, 6.5),
				Cleanup = cleanup,
			})
			cleanup:Add(button.Activated:Connect(callback))
			return button, icon
		end

		local list = Widgets.Scroller(cleanup, {
			Name = "Lines",
			Parent = frame,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 1, -32),
			Thickness = 3,
		})
		Widgets.List(list, 2)

		local rows = cleanup:Extend()

		function handle:Refresh()
			rows:Clean()
			rows = cleanup:Extend()
			local shown = 0
			for index, entry in Console.Entries do
				local matches = filter == "" or string.find(string.lower(Markup.Strip(entry.Text)), filter, 1, true)
				if matches and (level == "All" or entry.Level == level) then
					shown += 1
					local row = Utility.Create("Frame", {
						Name = "Line",
						BackgroundTransparency = 1,
						AutomaticSize = Enum.AutomaticSize.Y,
						Size = UDim2.new(1, 0, 0, 0),
						LayoutOrder = index,
						Parent = list,
					})
					rows:Add(row)
					Widgets.Surface(rows, {
						Parent = row,
						Fill = LEVELS[entry.Level].Color,
						Radius = "Full",
						Position = UDim2.fromOffset(0, 5),
						Size = UDim2.fromOffset(2, 10),
					})
					Widgets.Text(rows, {
						Parent = row,
						Text = entry.Clock,
						Color = "MutedText",
						TextSize = 10,
						Position = UDim2.fromOffset(8, 1),
						Size = UDim2.fromOffset(48, 14),
						Markup = false,
					})
					Widgets.Text(rows, {
						Parent = row,
						Text = (entry.Tag and ("<fade:0.4>[" .. entry.Tag .. "]</fade> ") or "") .. entry.Text,
						Color = entry.Level == "Error" and "Error" or (entry.Level == "Warning" and "Warning" or "Text"),
						TextSize = 11,
						TextWrapped = true,
						AutomaticSize = Enum.AutomaticSize.Y,
						Position = UDim2.fromOffset(58, 0),
						Size = UDim2.new(1, -62, 0, 0),
					})
				end
			end
			if shown == 0 then
				rows:Add((Widgets.Text(rows, {
					Parent = list,
					Text = #Console.Entries == 0 and "no logs yet" or "nothing matches",
					Color = "MutedText",
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 28),
				})))
			end
			if config.AutoScroll ~= false then
				task.defer(function()
					if list.Parent then
						list.CanvasPosition = Vector2.new(0, list.AbsoluteCanvasSize.Y)
					end
				end)
			end
		end

		local copyButton, copyIcon = chip("copy", 60, function()
			if Capabilities.SetClipboard(Console.Dump()) then
				copyIcon:Set("check")
				task.delay(1.2, function()
					if copyIcon then
						copyIcon:Set("copy")
					end
				end)
			end
		end)

		chip("eraser", 30, function()
			Console.Clear()
		end)

		local levelButton, levelIcon = chip("filter", 0, function()
			local levels = { "All" }
			for _, name in Console.Levels() do
				table.insert(levels, name)
			end
			local index = (table.find(levels, level) or 1) % #levels + 1
			level = levels[index]
			levelIcon:SetColor(level == "All" and "MutedText" or LEVELS[level].Color)
			handle:Refresh()
		end)

		cleanup:Add(Console.Added:Connect(function()
			handle:Refresh()
		end))
		cleanup:Add(Console.Cleared:Connect(function()
			handle:Refresh()
		end))
		handle:Refresh()

		handle.Frame = frame
		handle.List = list
		function handle:Destroy()
			cleanup:Clean()
		end
		return handle
	end

	return Console
end
