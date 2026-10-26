return function(import)
	local Utility = import("Core/Utility")
	local Config = import("Core/Config")
	local Capabilities = import("Core/Capabilities")

	local ConfigPanel = {}

	function ConfigPanel.Build(container, config)
		config = config or {}
		Utility.Check(
			type(container) == "table" and container.Container,
			"ConfigPanel",
			"?",
			"Needs a tab, section or card."
		)
		local window = container.Window
		local prefix = config.Prefix or "configs"
		local handle = {}

		local function toast(text, kind)
			if window and window.Toast then
				window:Toast(text, kind)
			end
		end

		local name = container:AddInput(prefix .. "/name", {
			Title = "Name",
			Description = "what the file will be called",
			Placeholder = "default",
			Default = config.Default or "default",
			Icon = "file-pen",
		})

		local list
		local function refresh(silent)
			local saved = Config:List()
			if #saved == 0 then
				saved = { "none" }
			end
			list:SetValues(saved)
			if not silent then
				toast(#Config:List() .. " config(s)", "Info")
			end
		end

		list = container:AddDropdown(prefix .. "/list", {
			Title = "Saved",
			Description = "pick one to load",
			Values = (function()
				local saved = Config:List()
				return #saved > 0 and saved or { "none" }
			end)(),
			Searchable = true,
			Icon = "folder-open",
			Callback = function(value)
				if value and value ~= "none" then
					name:SetValue(value)
				end
			end,
		})

		container:AddButton({
			Title = "Save",
			Description = "writes everything with an id",
			Icon = "save",
			Callback = function()
				local target = name:GetValue()
				if target == "" then
					toast("Pick a name", "Warning")
					return
				end
				local ok, err = Config:Save(target)
				refresh(true)
				toast(ok and ("Saved to " .. target) or tostring(err), ok and "Success" or "Error")
			end,
		})

		container:AddButton({
			Title = "Load",
			Icon = "folder-down",
			Callback = function()
				local target = name:GetValue()
				local ok, err = Config:Load(target)
				toast(ok and ("Loaded " .. target) or tostring(err), ok and "Success" or "Error")
			end,
		})

		container:AddButton({
			Title = "Delete",
			Icon = "trash-2",
			Cooldown = config.DeleteCooldown or 2,
			Callback = function()
				local target = name:GetValue()
				local ok = Config:Delete(target)
				refresh(true)
				toast(ok and ("Deleted " .. target) or "Not found", ok and "Success" or "Error")
			end,
		})

		container:AddButton({
			Title = "Refresh list",
			Icon = "refresh-ccw",
			Callback = function()
				refresh()
			end,
		})

		container:AddToggle(prefix .. "/autosave", {
			Title = "Auto save",
			Description = "writes on every change",
			Default = Config.AutoSave,
			Callback = function(value)
				Config:SetAutoSave(value, name:GetValue())
			end,
		})

		if config.Transfer ~= false then
			container:AddDivider({ Title = "transfer" })

			container:AddButton({
				Title = "Copy config",
				Description = "sends the json to the clipboard",
				Icon = "clipboard-copy",
				Callback = function()
					if Capabilities.SetClipboard(Config:Serialize()) then
						toast("Config copied", "Success")
					else
						toast("No clipboard on this executor", "Warning")
					end
				end,
			})

			local paste = container:AddInput(prefix .. "/paste", {
				Title = "Paste config",
				Description = "paste the json here and confirm",
				Placeholder = "{...}",
				Width = 210,
			})

			container:AddButton({
				Title = "Import",
				Icon = "clipboard-paste",
				Callback = function()
					local text = paste:GetValue()
					if text == "" then
						toast("Paste the json first", "Warning")
						return
					end
					local ok, err = Config:Deserialize(text)
					if ok then
						paste:SetValue("")
					end
					toast(ok and "Imported" or tostring(err), ok and "Success" or "Error")
				end,
			})
		end

		container:AddButton({
			Title = "Reset all",
			Description = "everything back to default",
			Icon = "rotate-ccw",
			Cooldown = config.ResetCooldown or 3,
			Callback = function()
				Config:Reset()
				toast("Everything reset", "Warning")
			end,
		})

		handle.Name = name
		handle.List = list
		handle.Refresh = function()
			refresh(true)
		end
		return handle
	end

	return ConfigPanel
end
