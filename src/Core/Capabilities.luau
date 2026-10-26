return function(import)
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")

	local env = {}
	pcall(function()
		env = getfenv(1)
	end)

	local function lookup(...)
		for _, name in { ... } do
			local value = rawget(env, name) or env[name]
			if type(value) == "function" then
				return value
			end
		end
		return nil
	end

	local Capabilities = {}

	Capabilities.Studio = RunService:IsStudio()
	Capabilities.GetHui = lookup("gethui")
	Capabilities.ProtectGui = lookup("protectgui") or (type(env.syn) == "table" and env.syn.protect_gui or nil)
	Capabilities.GetCustomAsset = lookup("getcustomasset", "getsynasset")
	Capabilities.Identity = lookup("getidentity", "getthreadidentity")

	local requestFn = lookup("request", "http_request")
	if not requestFn and type(env.syn) == "table" then
		requestFn = env.syn.request
	end
	Capabilities.Request = requestFn

	local okGet, httpGet = pcall(function()
		return game.HttpGet
	end)
	local hasHttpGet = okGet and httpGet ~= nil
	Capabilities.Http = hasHttpGet or requestFn ~= nil

	local fs = {
		Write = lookup("writefile"),
		Append = lookup("appendfile"),
		Read = lookup("readfile"),
		IsFile = lookup("isfile"),
		Delete = lookup("delfile"),
		MakeFolder = lookup("makefolder"),
		IsFolder = lookup("isfolder"),
		DeleteFolder = lookup("delfolder"),
		List = lookup("listfiles"),
	}
	Capabilities.FS = fs
	Capabilities.FileSystem = fs.Write ~= nil and fs.Read ~= nil and fs.IsFile ~= nil and fs.MakeFolder ~= nil and fs.IsFolder ~= nil

	local clipboard = lookup("setclipboard", "toclipboard")
	Capabilities.Clipboard = clipboard ~= nil
	Capabilities.Drawing = env.Drawing ~= nil
	Capabilities.Touch = UserInputService.TouchEnabled
	Capabilities.Keyboard = UserInputService.KeyboardEnabled
	Capabilities.Mobile = not Capabilities.Studio
		and table.find({ Enum.Platform.IOS, Enum.Platform.Android }, UserInputService:GetPlatform()) ~= nil

	function Capabilities.SetClipboard(text)
		if not clipboard then
			return false
		end
		return (pcall(clipboard, text))
	end

	function Capabilities.HttpGet(url)
		if requestFn then
			local ok, response = pcall(requestFn, { Url = url, Method = "GET" })
			if ok and type(response) == "table" then
				local code = response.StatusCode or response.Status
				if response.Success or code == 200 then
					return true, response.Body
				end
				return false, "status " .. tostring(code)
			end
		end
		if hasHttpGet then
			local ok, body = pcall(function()
				return game:HttpGet(url)
			end)
			if ok then
				return true, body
			end
			return false, tostring(body)
		end
		return false, "no http capability"
	end

	local cachedHwid
	function Capabilities.Hwid()
		if cachedHwid then
			return cachedHwid
		end
		local fn = lookup("gethwid", "get_hwid")
		if fn then
			local ok, value = pcall(fn)
			if ok and type(value) == "string" and value ~= "" then
				cachedHwid = value
				return cachedHwid
			end
		end
		local ok, value = pcall(function()
			return game:GetService("RbxAnalyticsService"):GetClientId()
		end)
		if ok and type(value) == "string" and value ~= "" then
			cachedHwid = value
			return cachedHwid
		end
		local player = game:GetService("Players").LocalPlayer
		cachedHwid = "uid-" .. tostring(player and player.UserId or 0)
		return cachedHwid
	end

	function Capabilities.EnsureFolder(path)
		if not Capabilities.FileSystem then
			return false
		end
		local built = ""
		for part in string.gmatch(path, "[^/\\]+") do
			built = built == "" and part or (built .. "/" .. part)
			if not fs.IsFolder(built) then
				local ok = pcall(fs.MakeFolder, built)
				if not ok then
					return false
				end
			end
		end
		return true
	end

	return Capabilities
end
