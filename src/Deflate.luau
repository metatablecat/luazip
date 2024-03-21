local BufferReader = require(script.Parent.BufferReader)
local Huffman = require(script.Parent.Huffman)

local BTYPE_NO_COMPRESSION = 0
local BTYPE_FIXED_HUFFMAN = 1
local BTYPE_DYNAMIC_HUFFMAN = 2

local lens = {
	[0] = 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
	35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
}

local lext = {
	[0] = 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
	3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
}

local dists = {
	[0] = 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
	257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
	8193, 12289, 16385, 24577
}

local dext = {
	[0] = 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
	7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
	12, 12, 13, 13
}

local function write(state, byte)
	local pos = state.Pos
	table.insert(state.Output, string.char(byte))
	state.Window[pos] = byte
	state.Pos = pos % 32768 + 1  -- 32K
end

-- weak metatable marking objects as bitstream type
local isBitStream = setmetatable({}, { __mode = 'k' })

local function createBitStream(reader)
	local stream = {}
	stream.buffer = 0
	stream.bitsLeft = 0
	isBitStream[stream] = true

	function stream:GetBitsLeft()
		return self.bitsLeft
	end

	function stream:Read(count)
		count = count or 1

		while self.bitsLeft < count do
			local byte = reader:readu8()

			if not byte then 
				return 
			end

			self.buffer += bit32.lshift(byte, self.bitsLeft)
			self.bitsLeft +=  8
		end

		local bits

		if count == 0 then
			bits = 0
		elseif count == 32 then
			bits = buffer
			self.buffer = 0
		else
			bits = bit32.band(self.buffer, bit32.rshift(2^32 - 1, 32 - count))
			self.buffer = bit32.rshift(self.buffer, count)
		end

		self.bitsLeft -= count
		return bits
	end

	return stream
end

local function getBitStream(obj)
	if isBitStream[obj] then
		return obj
	end

	return createBitStream(obj)
end

local function parseCompressedItem(bitStream, state, litTable, distTable)
	local val = litTable:Read(bitStream)

	if val < 256 then -- literal
		write(state, val)
	elseif val == 256 then -- end of block
		return true
	else
		local lenBase = lens[val - 257]
		local numExtraBits = lext[val - 257]

		local extraBits = bitStream:Read(numExtraBits)
		local len = lenBase + extraBits

		local distVal = distTable:Read(bitStream)
		local distBase = dists[distVal]

		local distNumExtraBits = dext[distVal]
		local distExtraBits = bitStream:Read(distNumExtraBits)

		local dist = distBase + distExtraBits

		for i = 1, len do
			local pos = (state.Pos - 1 - dist) % 32768 + 1
			local byte = assert(state.Window[pos], "invalid distance")
			write(state, byte)
		end
	end

	return false
end

local function parseBlock(bitStream, state)
	local bFinal = bitStream:Read(1)
	local bType = bitStream:Read(2)

	if bType == BTYPE_NO_COMPRESSION then
		local left = bitStream:GetBitsLeft()
		bitStream:Read(left)

		local len = bitStream:Read(16)

		for i = 1, len do
			local byte = bitStream:Read(8)
			write(state, byte)
		end
	elseif bType == BTYPE_FIXED_HUFFMAN or bType == BTYPE_DYNAMIC_HUFFMAN then
		local litTable, distTable

		if bType == BTYPE_DYNAMIC_HUFFMAN then
			litTable, distTable = Huffman.parse(bitStream)
		else
			litTable = Huffman.FixedLit
			distTable = Huffman.FixedDist
		end

		repeat until parseCompressedItem(bitStream, state, litTable, distTable)
	else
		error("unrecognized compression type")
	end

	return bFinal ~= 0
end

return function(buffer: string|buffer, uncompressedSize: number?): string
	local state = {
		Output = if uncompressedSize then table.create(uncompressedSize) else {},
		Window = {},
		Pos = 1
	}

	local bitStream = getBitStream(BufferReader(buffer))
	repeat until parseBlock(bitStream, state)
	
	return table.concat(state.Output)
end