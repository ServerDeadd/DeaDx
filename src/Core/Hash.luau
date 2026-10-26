return function(import)
	local Hash = {}

	local K = {
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
		0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
		0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
		0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
		0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
		0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
		0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
	}

	local band, bor, bxor, bnot = bit32.band, bit32.bor, bit32.bxor, bit32.bnot
	local rrotate, rshift, lshift = bit32.rrotate, bit32.rshift, bit32.lshift

	local function pack(value)
		return string.char(
			band(rshift(value, 24), 0xff),
			band(rshift(value, 16), 0xff),
			band(rshift(value, 8), 0xff),
			band(value, 0xff)
		)
	end

	local function unpack32(text, index)
		local a, b, c, d = string.byte(text, index, index + 3)
		return lshift(a, 24) + lshift(b, 16) + lshift(c, 8) + d
	end

	local function preprocess(message)
		local length = #message
		local bits = length * 8
		message ..= "\128"
		local padding = (56 - (length + 1) % 64) % 64
		message ..= string.rep("\0", padding)
		message ..= pack(math.floor(bits / 4294967296))
		message ..= pack(bits % 4294967296)
		return message
	end

	function Hash.Sha256(message)
		if type(message) ~= "string" then
			return nil
		end
		local h = {
			0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
			0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
		}
		local data = preprocess(message)
		local w = table.create(64, 0)

		for chunk = 1, #data, 64 do
			for index = 0, 15 do
				w[index + 1] = unpack32(data, chunk + index * 4)
			end
			for index = 17, 64 do
				local a, b = w[index - 15], w[index - 2]
				local s0 = bxor(rrotate(a, 7), rrotate(a, 18), rshift(a, 3))
				local s1 = bxor(rrotate(b, 17), rrotate(b, 19), rshift(b, 10))
				w[index] = (w[index - 16] + s0 + w[index - 7] + s1) % 4294967296
			end

			local a, b, c, d, e, f, g, hh = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]
			for index = 1, 64 do
				local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
				local ch = bxor(band(e, f), band(bnot(e), g))
				local temp1 = (hh + s1 + ch + K[index] + w[index]) % 4294967296
				local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
				local maj = bxor(band(a, b), band(a, c), band(b, c))
				local temp2 = (s0 + maj) % 4294967296
				hh, g, f, e = g, f, e, (d + temp1) % 4294967296
				d, c, b, a = c, b, a, (temp1 + temp2) % 4294967296
			end

			h[1] = (h[1] + a) % 4294967296
			h[2] = (h[2] + b) % 4294967296
			h[3] = (h[3] + c) % 4294967296
			h[4] = (h[4] + d) % 4294967296
			h[5] = (h[5] + e) % 4294967296
			h[6] = (h[6] + f) % 4294967296
			h[7] = (h[7] + g) % 4294967296
			h[8] = (h[8] + hh) % 4294967296
		end

		local out = {}
		for index = 1, 8 do
			out[index] = string.format("%08x", h[index])
		end
		return table.concat(out)
	end

	function Hash.Salted(message, salt)
		return Hash.Sha256(tostring(salt or "") .. "::" .. tostring(message))
	end

	local function hexToBytes(text)
		if type(text) ~= "string" or #text % 2 ~= 0 then
			return nil
		end
		local out = table.create(#text / 2)
		local position = 1
		for index = 1, #text, 2 do
			local byte = tonumber(string.sub(text, index, index + 1), 16)
			if not byte then
				return nil
			end
			out[position] = string.char(byte)
			position += 1
		end
		return table.concat(out)
	end
	Hash.FromHex = hexToBytes

	function Hash.ToHex(text)
		local out = table.create(#text)
		for index = 1, #text do
			out[index] = string.format("%02x", string.byte(text, index))
		end
		return table.concat(out)
	end

	local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

	function Hash.Base64Encode(text)
		if type(text) ~= "string" then
			return nil
		end
		local out = {}
		for index = 1, #text, 3 do
			local a, b, c = string.byte(text, index, index + 2)
			local value = lshift(a, 16) + lshift(b or 0, 8) + (c or 0)
			local chunk = {}
			for slot = 0, 3 do
				chunk[slot + 1] = string.sub(B64, band(rshift(value, 18 - slot * 6), 63) + 1, band(rshift(value, 18 - slot * 6), 63) + 1)
			end
			if not b then
				chunk[3], chunk[4] = "=", "="
			elseif not c then
				chunk[4] = "="
			end
			table.insert(out, table.concat(chunk))
		end
		return table.concat(out)
	end

	function Hash.Base64Decode(text)
		if type(text) ~= "string" then
			return nil
		end
		text = string.gsub(text, "[^%w%+/=]", "")
		local out = {}
		for index = 1, #text, 4 do
			local value, bits = 0, 0
			for slot = 0, 3 do
				local char = string.sub(text, index + slot, index + slot)
				if char ~= "" and char ~= "=" then
					local position = string.find(B64, char, 1, true)
					if not position then
						return nil
					end
					value = lshift(value, 6) + (position - 1)
					bits += 6
				else
					value = lshift(value, 6)
				end
			end
			local chars = math.floor(bits / 8)
			for slot = 1, chars do
				table.insert(out, string.char(band(rshift(value, 24 - slot * 8), 0xff)))
			end
		end
		return table.concat(out)
	end

	function Hash.Hmac(key, message)
		key, message = tostring(key), tostring(message)
		local block = 64
		if #key > block then
			key = hexToBytes(Hash.Sha256(key)) or key
		end
		key ..= string.rep("\0", block - #key)
		local inner, outer = table.create(block), table.create(block)
		for index = 1, block do
			local byte = string.byte(key, index)
			inner[index] = string.char(bxor(byte, 0x36))
			outer[index] = string.char(bxor(byte, 0x5c))
		end
		local first = hexToBytes(Hash.Sha256(table.concat(inner) .. message))
		return Hash.Sha256(table.concat(outer) .. (first or ""))
	end

	function Hash.Keystream(key, length)
		local out, index = {}, 0
		local produced = 0
		while produced < length do
			local block = hexToBytes(Hash.Sha256(tostring(key) .. ":" .. index))
			if not block then
				return nil
			end
			table.insert(out, block)
			produced += #block
			index += 1
		end
		return string.sub(table.concat(out), 1, length)
	end

	function Hash.Stream(data, key)
		if type(data) ~= "string" or data == "" then
			return data
		end
		local stream = Hash.Keystream(key, #data)
		if not stream then
			return nil
		end
		local out = table.create(#data)
		for index = 1, #data do
			out[index] = string.char(bxor(string.byte(data, index), string.byte(stream, index)))
		end
		return table.concat(out)
	end

	function Hash.Nonce(size)
		local out = table.create(size or 16)
		for index = 1, size or 16 do
			out[index] = string.format("%02x", math.random(0, 255))
		end
		return table.concat(out)
	end

	function Hash.Equal(a, b)
		if type(a) ~= "string" or type(b) ~= "string" or #a ~= #b then
			return false
		end
		local diff = 0
		for index = 1, #a do
			diff = bor(diff, bxor(string.byte(a, index), string.byte(b, index)))
		end
		return diff == 0
	end

	function Hash.Encode(text, key)
		if type(text) ~= "string" or type(key) ~= "string" or key == "" then
			return text
		end
		local out = table.create(#text)
		for index = 1, #text do
			local byte = string.byte(text, index)
			local mask = string.byte(key, (index - 1) % #key + 1)
			out[index] = string.format("%02x", bxor(byte, mask))
		end
		return table.concat(out)
	end

	function Hash.Decode(text, key)
		if type(text) ~= "string" or type(key) ~= "string" or key == "" or #text % 2 ~= 0 then
			return nil
		end
		local out = table.create(#text / 2)
		local position = 1
		for index = 1, #text, 2 do
			local byte = tonumber(string.sub(text, index, index + 1), 16)
			if not byte then
				return nil
			end
			local mask = string.byte(key, (position - 1) % #key + 1)
			out[position] = string.char(bxor(byte, mask))
			position += 1
		end
		return table.concat(out)
	end

	return Hash
end
