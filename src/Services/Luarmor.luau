return function(import)
	local Utility = import("Core/Utility")
	local Signal = import("Core/Signal")
	local Capabilities = import("Core/Capabilities")

	local Luarmor = {
		Library = "https://sdkapi-public.luarmor.net/library.lua",
		Loaded = Signal.new(),
	}

	local CODES = {
		KEY_VALID = { Message = "Key accepted.", Ok = true },
		KEY_EXPIRED = { Message = "This key has expired.", Fatal = true },
		KEY_BANNED = { Message = "This key is blacklisted.", Fatal = true },
		KEY_HWID_LOCKED = { Message = "Key is locked to another HWID. Reset it on the bot.", Fatal = true },
		KEY_INCORRECT = { Message = "Key not found. Check it and try again." },
		KEY_INVALID = { Message = "Key format is invalid." },
		SCRIPT_ID_INCORRECT = { Message = "Script id not found.", Fatal = true, Owner = true },
		SCRIPT_ID_INVALID = { Message = "Script id format is invalid.", Fatal = true, Owner = true },
		INVALID_EXECUTOR = { Message = "Executor not supported.", Fatal = true },
		SECURITY_ERROR = { Message = "Request could not be validated.", Fatal = true },
		TIME_ERROR = { Message = "Your system clock is off. Fix the time and retry.", Fatal = true },
		UNKNOWN_ERROR = { Message = "Luarmor is down. Try again in a bit.", Fatal = true },
	}

	function Luarmor.Codes()
		local out = {}
		for code in CODES do
			table.insert(out, code)
		end
		table.sort(out)
		return out
	end

	function Luarmor.Describe(code)
		local entry = CODES[code]
		return entry and entry.Message or ("Unexpected code: " .. tostring(code))
	end

	function Luarmor.IsFatal(code)
		local entry = CODES[code]
		return entry ~= nil and entry.Fatal == true
	end

	function Luarmor.IsOwnerFault(code)
		local entry = CODES[code]
		return entry ~= nil and entry.Owner == true
	end

	local cached

	function Luarmor.Api(config)
		config = config or {}
		if cached and not config.Reload then
			cached.script_id = config.ScriptId or config.script_id or cached.script_id
			return cached
		end
		if not Capabilities.Http then
			return nil, "no http capability"
		end
		local url = config.Library or Luarmor.Library
		local ok, body = Capabilities.HttpGet(url)
		if not ok or type(body) ~= "string" or body == "" then
			return nil, "could not download the luarmor library"
		end
		local compiled, err = loadstring(body, "=DeaDx/Luarmor")
		if not compiled then
			return nil, "luarmor library failed to compile: " .. tostring(err)
		end
		local built, api = pcall(compiled)
		if not built or type(api) ~= "table" then
			return nil, "luarmor library returned no api"
		end
		cached = api
		api.script_id = config.ScriptId or config.script_id
		Luarmor.Loaded:Fire(api)
		return api
	end

	function Luarmor.Check(config, key)
		config = config or {}
		Utility.Check(
			type(config.ScriptId) == "string" and config.ScriptId ~= "",
			"Luarmor",
			"ScriptId",
			"ScriptId is required."
		)
		key = tostring(key or "")
		if key == "" then
			return { code = "KEY_INVALID", message = Luarmor.Describe("KEY_INVALID") }
		end

		local api, reason = Luarmor.Api(config)
		if not api then
			return { code = "UNKNOWN_ERROR", message = reason or Luarmor.Describe("UNKNOWN_ERROR"), Local = true }
		end
		api.script_id = config.ScriptId

		local ran, status = pcall(api.check_key, key)
		if not ran or type(status) ~= "table" or status.code == nil then
			return {
				code = "UNKNOWN_ERROR",
				message = ran and Luarmor.Describe("UNKNOWN_ERROR") or tostring(status),
				Local = true,
			}
		end
		if status.message == nil or status.message == "" then
			status.message = Luarmor.Describe(status.code)
		end
		return status
	end

	function Luarmor.SetKey(key)
		local env = getgenv and getgenv() or _G
		env.script_key = tostring(key or "")
		return env.script_key
	end

	function Luarmor.Load(config, key)
		config = config or {}
		if key then
			Luarmor.SetKey(key)
		end
		local api, reason = Luarmor.Api(config)
		if not api then
			return false, reason
		end
		api.script_id = config.ScriptId or api.script_id
		if type(api.load_script) ~= "function" then
			return false, "luarmor library has no load_script"
		end
		local ok, err = pcall(api.load_script)
		if not ok then
			return false, tostring(err)
		end
		return true
	end

	function Luarmor.PurgeCache(config)
		local api = Luarmor.Api(config or {})
		if not api or type(api.purge_cache) ~= "function" then
			return false
		end
		return (pcall(api.purge_cache))
	end

	function Luarmor.Info(status)
		if type(status) ~= "table" or status.code ~= "KEY_VALID" or type(status.data) ~= "table" then
			return nil
		end
		local data = status.data
		local expire = tonumber(data.auth_expire) or 0
		local left = expire > 0 and (expire - os.time()) or -1
		return {
			Expire = expire,
			Lifetime = expire <= 0,
			SecondsLeft = left,
			Note = data.note,
			Executions = tonumber(data.total_executions) or 0,
			FromAd = data.note == "Ad Reward",
		}
	end

	function Luarmor.Remaining(info)
		if not info or info.Lifetime then
			return "lifetime"
		end
		local left = info.SecondsLeft
		if left <= 0 then
			return "expired"
		end
		local days = math.floor(left / 86400)
		if days >= 1 then
			return days .. (days == 1 and " day left" or " days left")
		end
		local hours = math.floor(left / 3600)
		if hours >= 1 then
			return hours .. (hours == 1 and " hour left" or " hours left")
		end
		return math.max(math.floor(left / 60), 1) .. " min left"
	end

	return Luarmor
end
