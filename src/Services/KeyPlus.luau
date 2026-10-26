return function(import)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local Utility = import("Core/Utility")
	local Hash = import("Core/Hash")
	local Capabilities = import("Core/Capabilities")

	local KeyPlus = { Version = 1, Marker = "--DEADX" }

	local function options(value)
		if type(value) == "string" then
			return { Secret = value }
		end
		return value or {}
	end

	local function signature(config, key, hwid, nonce, stamp)
		if not config.Secret then
			return nil
		end
		return Hash.Hmac(config.Secret, table.concat({
			"v1",
			tostring(key),
			tostring(hwid),
			tostring(nonce),
			tostring(stamp),
		}, "|"))
	end
	KeyPlus.Sign = signature

	local function streamKey(config, key, hwid, nonce, stamp)
		local base = config.Secret or tostring(key)
		local tag = config.Secret and "stream" or "ukey"
		local parts = { tag, tostring(nonce), tostring(stamp) }
		if config.BindHwid then
			table.insert(parts, tostring(hwid))
		end
		return Hash.Hmac(base, table.concat(parts, "|"))
	end
	KeyPlus.StreamKey = streamKey

	function KeyPlus.Pack(config, key, hwid, nonce, stamp, payload)
		config = options(config)
		stamp = stamp or os.time()
		nonce = nonce or Hash.Nonce(16)
		local cipher = Hash.Stream(payload, streamKey(config, key, hwid, nonce, stamp))
		local response = {
			v = KeyPlus.Version,
			ts = stamp,
			nonce = nonce,
			data = Hash.ToHex(cipher),
		}
		local sig = signature(config, key, hwid, nonce, stamp)
		if sig then
			response.sig = sig
		end
		return response
	end

	function KeyPlus.Open(config, key, hwid, nonce, response, window)
		config = options(config)
		if type(response) ~= "table" then
			return nil, "invalid response"
		end
		if response.error then
			return nil, tostring(response.error)
		end
		local stamp = tonumber(response.ts or response.timestamp)
		if not stamp then
			return nil, "missing timestamp"
		end
		if math.abs(os.time() - stamp) > (window or config.Window or 300) then
			return nil, "response expired"
		end
		local echo = tostring(response.nonce or response.n or "")
		if echo ~= "" and echo ~= nonce then
			return nil, "nonce mismatch"
		end
		if config.Secret then
			local expected = signature(config, key, hwid, nonce, stamp)
			if not Hash.Equal(string.lower(tostring(response.sig or response.signature or "")), expected) then
				return nil, "invalid signature"
			end
		end

		local raw = response.data or response.payload
		if type(raw) ~= "string" or raw == "" then
			return nil, "missing payload"
		end
		local cipher = Hash.FromHex(raw) or Hash.Base64Decode(raw)
		if not cipher then
			return nil, "corrupted payload"
		end
		local plain = Hash.Stream(cipher, streamKey(config, key, hwid, nonce, stamp))
		if type(plain) ~= "string" or plain == "" then
			return nil, "failed to open"
		end

		local marker = config.Marker or KeyPlus.Marker
		if marker ~= "" and string.sub(plain, 1, #marker) == marker then
			return plain, stamp
		end
		if loadstring and loadstring(plain) then
			return plain, stamp
		end
		return nil, "wrong key"
	end

	function KeyPlus.Request(config, key)
		config = options(config)
		Utility.Check(
			type(config.Endpoint) == "string" and config.Endpoint ~= "",
			"KeyPlus",
			"Endpoint",
			"Endpoint must be a url."
		)

		local player = Players.LocalPlayer
		local hwid = config.Hwid or Capabilities.Hwid()
		local nonce = Hash.Nonce(16)
		local replacements = {
			key = HttpService:UrlEncode(tostring(key or "")),
			hwid = HttpService:UrlEncode(hwid),
			nonce = nonce,
			user = HttpService:UrlEncode(player and player.Name or ""),
			userid = tostring(player and player.UserId or 0),
			place = tostring(game.PlaceId),
			id = HttpService:UrlEncode(tostring(config.KeyId or "")),
			v = tostring(KeyPlus.Version),
		}

		local url = config.Endpoint
		if not string.find(url, "{") then
			local glue = string.find(url, "?", 1, true) and "&" or "?"
			url ..= glue .. "key={key}&hwid={hwid}&nonce={nonce}&v={v}"
		end
		url = string.gsub(url, "{(%w+)}", function(name)
			return replacements[string.lower(name)] or ""
		end)

		local ok, body = Capabilities.HttpGet(url)
		if not ok or type(body) ~= "string" then
			return nil, "no response from the server"
		end

		local parsed, response = pcall(HttpService.JSONDecode, HttpService, body)
		if not parsed or type(response) ~= "table" then
			return nil, "response is not json"
		end

		return KeyPlus.Open(config, key, hwid, nonce, response, config.Window)
	end

	function KeyPlus.Run(config, key)
		local payload, reason = KeyPlus.Request(config, key)
		if not payload then
			return nil, reason
		end
		local compiled, err = loadstring(payload, "=DeaDx/KeyPlus")
		if not compiled then
			return nil, "compile failed: " .. tostring(err)
		end
		local ok, result = pcall(compiled)
		if not ok then
			return nil, "run failed: " .. tostring(result)
		end
		return result or true
	end

	function KeyPlus.Verify(config, key)
		local payload, reason = KeyPlus.Request(config, key)
		return payload ~= nil, reason
	end

	return KeyPlus
end
