return function(import)
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")

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

	local Integrity = {
		Tampered = Signal.new(),
		Strict = false,
	}

	local isHooked = lookup("isfunctionhooked", "is_function_hooked")
	local isC = lookup("iscclosure", "is_c_closure")
	local isL = lookup("islclosure", "is_l_closure")
	local isSynapse = lookup("issynapsefunction", "isexecutorclosure", "is_executor_closure", "checkclosure")
	local rawMeta = lookup("getrawmetatable", "get_raw_metatable")
	local checkCaller = lookup("checkcaller")
	local hookRestore = lookup("restorefunction")
	local getInfo = debug and debug.info

	Integrity.Available = {
		IsFunctionHooked = isHooked ~= nil,
		IsCClosure = isC ~= nil,
		IsLClosure = isL ~= nil,
		IsExecutorClosure = isSynapse ~= nil,
		RawMetatable = rawMeta ~= nil,
		CheckCaller = checkCaller ~= nil,
		Restore = hookRestore ~= nil,
	}

	local function hooked(fn)
		if type(fn) ~= "function" or not isHooked then
			return false
		end
		local ok, result = pcall(isHooked, fn)
		return ok and result == true
	end
	Integrity.IsHooked = hooked

	local function native(fn)
		if type(fn) ~= "function" or not isC then
			return true
		end
		local ok, result = pcall(isC, fn)
		if not ok then
			return true
		end
		return result == true
	end
	Integrity.IsNative = native

	local function lua(fn)
		if type(fn) ~= "function" or not isL then
			return true
		end
		local ok, result = pcall(isL, fn)
		if not ok then
			return true
		end
		return result == true
	end
	Integrity.IsLua = lua

	function Integrity.Signature(fn)
		if type(fn) ~= "function" or not getInfo then
			return nil
		end
		local ok, source = pcall(getInfo, fn, "s")
		if not ok then
			return nil
		end
		local okLine, line = pcall(getInfo, fn, "l")
		return tostring(source) .. ":" .. tostring(okLine and line or "?")
	end

	local function engineTargets()
		local targets = {}
		local function add(name, fn)
			if type(fn) == "function" then
				table.insert(targets, { Name = name, Fn = fn, Native = true })
			end
		end
		pcall(function()
			add("game.HttpGet", game.HttpGet)
			add("game.GetService", game.GetService)
			add("Instance.new", Instance.new)
		end)
		pcall(function()
			local http = game:GetService("HttpService")
			add("HttpService.JSONDecode", http.JSONDecode)
			add("HttpService.JSONEncode", http.JSONEncode)
		end)
		pcall(function()
			local market = game:GetService("MarketplaceService")
			add("Marketplace.UserOwnsGamePassAsync", market.UserOwnsGamePassAsync)
			add("Marketplace.PlayerOwnsAsset", market.PlayerOwnsAsset)
		end)
		pcall(function()
			local player = game:GetService("Players").LocalPlayer
			if player then
				add("Player.IsInGroup", player.IsInGroup)
				add("Player.GetRankInGroup", player.GetRankInGroup)
			end
		end)
		add("string.format", string.format)
		add("string.byte", string.byte)
		add("string.sub", string.sub)
		add("table.concat", table.concat)
		add("bit32.bxor", bit32 and bit32.bxor)
		add("os.time", os.time)
		return targets
	end

	function Integrity.Scan(extra)
		local failures = {}
		for _, target in engineTargets() do
			if hooked(target.Fn) then
				table.insert(failures, target.Name .. " (hook)")
			elseif target.Native and not native(target.Fn) then
				table.insert(failures, target.Name .. " (nao nativa)")
			end
		end

		for _, entry in extra or {} do
			local fn = type(entry) == "table" and entry.Fn or entry
			local name = type(entry) == "table" and entry.Name or "custom"
			if hooked(fn) then
				table.insert(failures, name .. " (hook)")
			elseif type(entry) == "table" and entry.Lua and not lua(fn) then
				table.insert(failures, name .. " (nao lua)")
			end
		end

		if rawMeta then
			local ok, meta = pcall(rawMeta, game)
			if ok and type(meta) == "table" then
				for _, name in { "__namecall", "__index", "__newindex" } do
					local value = rawget(meta, name)
					if type(value) == "function" then
						if hooked(value) then
							table.insert(failures, "game." .. name .. " (hook)")
						elseif not native(value) then
							table.insert(failures, "game." .. name .. " (nao nativa)")
						end
					end
				end
			end
		end

		if checkCaller then
			local ok, result = pcall(checkCaller)
			if ok and result == false then
				table.insert(failures, "checkcaller")
			end
		end

		return #failures == 0, failures
	end

	function Integrity.Report()
		local ok, failures = Integrity.Scan()
		return {
			Clean = ok,
			Failures = failures,
			Detection = Integrity.Available,
		}
	end

	function Integrity.Guard(interval, onTamper, extra)
		local running = true
		local thread = task.spawn(function()
			while running do
				task.wait(interval or 5)
				if not running then
					break
				end
				local ok, failures = Integrity.Scan(extra)
				if not ok then
					Integrity.Tampered:Fire(failures)
					Utility.SafeCall("Integrity guard", onTamper, failures)
					if Integrity.Strict then
						running = false
					end
				end
			end
		end)
		return {
			Stop = function()
				running = false
				pcall(task.cancel, thread)
			end,
			Thread = thread,
		}
	end

	return Integrity
end
