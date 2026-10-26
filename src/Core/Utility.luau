return function(import)
	local Players = game:GetService("Players")
	local CoreGui = game:GetService("CoreGui")
	local Capabilities = import("Core/Capabilities")

	local Utility = { Debug = false, Root = "DeaDx" }

	local EARLY = { "RichText", "FontFace", "TextSize", "TextWrapped", "TextTruncate", "TextScaled" }
	local LATE = { AutomaticSize = true, Parent = true }

	function Utility.Create(class, props, children)
		local instance = Instance.new(class)
		if instance:IsA("GuiObject") then
			instance.BorderSizePixel = 0
		end
		if instance:IsA("GuiButton") then
			instance.AutoButtonColor = false
		end
		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
			instance.Text = ""
		end
		props = props or {}
		local applied = {}
		for _, key in EARLY do
			if props[key] ~= nil then
				instance[key] = props[key]
				applied[key] = true
			end
		end
		for key, value in props do
			if not applied[key] and not LATE[key] then
				instance[key] = value
			end
		end
		for _, child in children or {} do
			child.Parent = instance
		end
		if props.AutomaticSize ~= nil then
			instance.AutomaticSize = props.AutomaticSize
		end
		instance.Parent = props.Parent
		return instance
	end

	function Utility.Log(...)
		if Utility.Debug then
			print("[DEADX]", ...)
		end
	end

	function Utility.Warn(message)
		warn("[DEADX][WARN] " .. tostring(message))
	end

	function Utility.Format(kind, name, reason)
		return string.format('[DEADX][ERROR]\nFailed to create %s "%s":\n%s', kind, tostring(name or "?"), tostring(reason))
	end

	function Utility.Fail(kind, name, reason)
		error(Utility.Format(kind, name, reason), 0)
	end

	function Utility.Check(condition, kind, name, reason)
		if not condition then
			Utility.Fail(kind, name, reason)
		end
	end

	function Utility.SafeCall(label, callback, ...)
		if type(callback) ~= "function" then
			return false
		end
		local ok = xpcall(callback, function(err)
			warn(string.format("[DEADX][ERROR] Callback error in %s:\n%s", label, Utility.Debug and debug.traceback(tostring(err), 2) or tostring(err)))
		end, ...)
		return ok
	end

	function Utility.Round(value, decimals)
		local m = 10 ^ (decimals or 0)
		return math.floor(value * m + 0.5) / m
	end

	function Utility.Map(value, inMin, inMax, outMin, outMax)
		if inMax == inMin then
			return outMin
		end
		return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin
	end

	function Utility.DeepCopy(value)
		if type(value) ~= "table" then
			return value
		end
		local out = {}
		for k, v in value do
			out[k] = Utility.DeepCopy(v)
		end
		return out
	end

	function Utility.ToHex(color)
		return string.format(
			"#%02X%02X%02X",
			math.floor(color.R * 255 + 0.5),
			math.floor(color.G * 255 + 0.5),
			math.floor(color.B * 255 + 0.5)
		)
	end

	function Utility.FromHex(text)
		text = string.gsub(tostring(text), "^#", "")
		if #text == 3 then
			text = string.gsub(text, ".", "%0%0")
		end
		if #text ~= 6 or string.find(text, "%X") then
			return nil
		end
		return Color3.fromRGB(
			tonumber(string.sub(text, 1, 2), 16),
			tonumber(string.sub(text, 3, 4), 16),
			tonumber(string.sub(text, 5, 6), 16)
		)
	end

	function Utility.Hash(text)
		if type(text) ~= "string" then
			return "00000000000000000000"
		end
		local a, b = 5381, 52711
		local length = #text
		for index = 1, length do
			local byte = string.byte(text, index)
			a = (a * 33 + byte) % 4294967296
			b = (b * 31 + byte * index) % 4294967296
		end
		return string.format("%08x%08x%04x", a, b, length % 65536)
	end

	function Utility.Slug(text)
		text = string.lower(tostring(text))
		text = string.gsub(text, "[^%w%-_%.]+", "-")
		text = string.gsub(text, "%-+", "-")
		text = string.gsub(text, "^%-", "")
		text = string.gsub(text, "%-$", "")
		if text == "" then
			text = "icon"
		end
		return string.sub(text, 1, 72)
	end

	function Utility.Kebab(text)
		text = string.gsub(tostring(text), "(%l%d)(%u)", "%1-%2")
		text = string.gsub(text, "(%u)(%u%l)", "%1-%2")
		text = string.gsub(text, "[%s_]+", "-")
		return string.lower(text)
	end

	function Utility.Clamp(value, min, max)
		return math.max(min, math.min(max, value))
	end

	function Utility.GetGuiParent()
		if Capabilities.GetHui then
			local ok, hui = pcall(Capabilities.GetHui)
			if ok and hui then
				return hui
			end
		end
		local ok = pcall(function()
			local probe = Instance.new("Folder")
			probe.Parent = CoreGui
			probe:Destroy()
		end)
		if ok then
			return CoreGui
		end
		local player = Players.LocalPlayer
		return player and player:FindFirstChildOfClass("PlayerGui")
	end

	function Utility.NewScreenGui(name, order)
		local parent = Utility.GetGuiParent()
		if not parent then
			error("[DEADX][ERROR] No GUI parent available (PlayerGui not found).", 0)
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = name
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = false
		gui.DisplayOrder = order or 100
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui:SetAttribute("DeaDx", true)
		if Capabilities.ProtectGui then
			pcall(Capabilities.ProtectGui, gui)
		end
		gui.Parent = parent
		return gui
	end

	return Utility
end
