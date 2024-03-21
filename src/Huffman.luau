local Huffman = {}

local HUF_ORDER = {
	16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 
	11, 4, 12, 3, 13, 2, 14, 1, 15
}

local HUF_LIT = {0, 8, 144, 9, 256, 7, 280, 8, 288}
local HUF_DIST = {0, 5, 32}

local function sortHuffman(a, b)
	return a.NumBits == b.NumBits and a.Value < b.Value or a.NumBits < b.NumBits
end

local function msb(bits, numBits)
	local res = 0

	for i = 1, numBits do
		res = bit32.lshift(res, 1) + bit32.band(bits, 1)
		bits = bit32.rshift(bits, 1)
	end

	return res
end

function Huffman.new(init, isFull)
	local hTable = {}

	if isFull then
		for val, numBits in pairs(init) do
			if numBits ~= 0 then
				hTable[#hTable + 1] = 
					{
						Value = val;
						NumBits = numBits;
					}
			end
		end
	else
		for i = 1, #init - 2, 2 do
			local firstVal = init[i]

			local numBits = init[i + 1]
			local nextVal = init[i + 2]

			if numBits ~= 0 then
				for val = firstVal, nextVal - 1 do
					hTable[#hTable + 1] = 
						{
							Value = val;
							NumBits = numBits;
						}
				end
			end
		end
	end

	table.sort(hTable, sortHuffman)

	local code = 1
	local numBits = 0

	for i, slide in ipairs(hTable) do
		if slide.NumBits ~= numBits then
			code = code * (2 ^ (slide.NumBits - numBits))
			numBits = slide.NumBits
		end

		slide.Code = code
		code = code + 1
	end

	local minBits = math.huge
	local look = {}

	for i, slide in ipairs(hTable) do
		minBits = math.min(minBits, slide.NumBits)
		look[slide.Code] = slide.Value
	end

	hTable.minBits = minBits
	hTable.look = look

	function hTable:FirstCode(bits)
		return (2 ^ self.minBits) + msb(bits, self.minBits) 
	end

	function hTable:Read(bitStream)
		local code = 1 -- leading 1 marker
		local numBits = 0

		while true do
			if numBits == 0 then  -- small optimization (optional)
				local index = bitStream:Read(self.minBits)
				numBits = numBits + self.minBits
				code = self:FirstCode(index)
			else
				local bit = bitStream:Read()
				numBits = numBits + 1
				code = code * 2 + bit -- MSB first
			end

			local val = look[code]

			if val then
				return val
			end
		end
	end

	return hTable
end

function Huffman.parse(bitStream)
	local numLits  = bitStream:Read(5) -- # of literal/length codes - 257
	local numDists = bitStream:Read(5) -- # of distance codes - 1
	local numCodes = bitStream:Read(4) -- # of code length codes - 4

	local codeLens = {}

	for i = 1, numCodes + 4 do
		local index = HUF_ORDER[i]
		codeLens[index] = bitStream:Read(3)
	end

	codeLens = Huffman.new(codeLens, true)

	local function decode(numCodes)
		local init = {}
		local numBits
		local val = 0

		while val < numCodes do
			local codeLen = codeLens:Read(bitStream)
			local numRepeats

			if codeLen <= 15 then
				numRepeats = 1
				numBits = codeLen
			elseif codeLen == 16 then
				numRepeats = 3 + bitStream:Read(2)
			elseif codeLen == 17 then
				numRepeats = 3 + bitStream:Read(3)
				numBits = 0
			elseif codeLen == 18 then
				numRepeats = 11 + bitStream:Read(7)
				numBits = 0
			end

			for i = 1, numRepeats do
				init[val] = numBits
				val = val + 1
			end
		end

		return Huffman.new(init, true)
	end

	local numLitCodes = numLits + 257
	local numDistCodes = numDists + 1

	local litTable = decode(numLitCodes)
	local distTable = decode(numDistCodes)

	return litTable, distTable
end

Huffman.FixedLit = Huffman.new(HUF_LIT)
Huffman.FixedDist = Huffman.new(HUF_DIST)
return Huffman