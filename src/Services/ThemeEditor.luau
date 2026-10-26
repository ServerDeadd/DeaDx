return function(import)
	local HttpService = game:GetService("HttpService")
	local Utility = import("Core/Utility")
	local Theme = import("Core/Theme")
	local Capabilities = import("Core/Capabilities")

	local ThemeEditor = {}

	local GROUPS = {
		{
			Title = "Background",
			Icon = "layers",
			Tokens = { "Background", "SecondaryBackground", "TertiaryBackground", "Border" },
		},
		{
			Title = "Accent",
			Icon = "palette",
			Tokens = { "Accent", "AccentText", "Hover", "Pressed" },
		},
		{
			Title = "Text",
			Icon = "type",
			Tokens = { "Text", "MutedText" },
		},
		{
			Title = "States",
			Icon = "bell",
			Tokens = { "Success", "Warning", "Error", "Info" },
		},
	}

	local SLIDERS = {
		{ Token = "AcrylicTransparency", Title = "Acrylic", Max = 1 },
		{ Token = "ElementTransparency", Title = "Elements", Max = 1 },
		{ Token = "ComponentTransparency", Title = "Components", Max = 1 },
		{ Token = "ComponentStrokeTransparency", Title = "Strokes", Max = 1 },
	}

	local function snapshot()
		local out = {}
		for _, group in GROUPS do
			for _, token in group.Tokens do
				local value = Theme.Get(token)
				if typeof(value) == "Color3" then
					out[token] = value
				end
			end
		end
		for _, entry in SLIDERS do
			local value = Theme.Get(entry.Token)
			if type(value) == "number" then
				out[entry.Token] = value
			end
		end
		return out
	end

	function ThemeEditor.Export(name)
		local lines = { "return {" }
		local data = snapshot()
		local keys = {}
		for token in data do
			table.insert(keys, token)
		end
		table.sort(keys)
		for _, token in keys do
			local value = data[token]
			if typeof(value) == "Color3" then
				table.insert(lines, string.format(
					"\t%s = Color3.fromRGB(%d, %d, %d),",
					token,
					math.floor(value.R * 255 + 0.5),
					math.floor(value.G * 255 + 0.5),
					math.floor(value.B * 255 + 0.5)
				))
			else
				table.insert(lines, string.format("\t%s = %.2f,", token, value))
			end
		end
		table.insert(lines, "}")
		return table.concat(lines, "\n"), name
	end

	function ThemeEditor.Build(container, config)
		config = config or {}
		Utility.Check(type(container) == "table" and container.Container, "ThemeEditor", "?", "Needs a tab, section or card.")
		local name = config.Name or "Custom"
		local created = {}

		local picker = container:AddDropdown(config.Id or "theme/base", {
			Title = "Base theme",
			Description = "switches the theme and reloads the values",
			Values = Theme.Names(),
			Default = Theme.GetName(),
			Searchable = true,
			Callback = function(value)
				if Theme.IsLocked() then
					return
				end
				Theme.Set(value)
				for token, control in created do
					local current = Theme.Get(token)
					if typeof(current) == "Color3" then
						control:SetValue(current)
					elseif type(current) == "number" then
						control:SetValue(current)
					end
				end
			end,
		})

		for _, group in GROUPS do
			local host = container.AddCard and container:AddCard({
				Title = group.Title,
				Icon = group.Icon,
				Collapsible = true,
				Collapsed = true,
			}) or container
			for _, token in group.Tokens do
				local value = Theme.Get(token)
				if typeof(value) == "Color3" then
					created[token] = host:AddColorpicker("theme/" .. token, {
						Title = token,
						Default = value,
						Swatches = true,
						Harmony = true,
						Callback = function(color)
							Theme.Override(token, color)
						end,
					})
				end
			end
		end

		local fades = container.AddCard and container:AddCard({
			Title = "Transparency",
			Icon = "droplet",
			Collapsible = true,
			Collapsed = true,
		}) or container
		for _, entry in SLIDERS do
			local value = Theme.Get(entry.Token)
			if type(value) == "number" then
				created[entry.Token] = fades:AddSlider("theme/" .. entry.Token, {
					Title = entry.Title,
					Min = 0,
					Max = entry.Max or 1,
					Default = value,
					Increment = 0.02,
					Rounding = 2,
					Callback = function(amount)
						Theme.Override(entry.Token, amount)
					end,
				})
			end
		end

		container:AddButton({
			Title = "Copy theme",
			Description = "sends the ready table to the clipboard",
			Icon = "clipboard-copy",
			Callback = function()
				local source = ThemeEditor.Export(name)
				if Capabilities.SetClipboard(source) then
					container.Window:Toast("Theme copied", "Success")
				else
					container.Window:Toast("No clipboard on this executor", "Warning")
				end
			end,
		})

		container:AddButton({
			Title = "Save as theme",
			Description = "registers " .. name .. " and applies it",
			Icon = "save",
			Callback = function()
				Theme.Register(name, snapshot())
				Theme.Set(name)
				picker:SetValues(Theme.Names())
				picker:SetValue(name)
				container.Window:Toast("Theme " .. name .. " saved", "Success")
			end,
		})

		return {
			Controls = created,
			Export = ThemeEditor.Export,
			Snapshot = snapshot,
		}
	end

	return ThemeEditor
end
