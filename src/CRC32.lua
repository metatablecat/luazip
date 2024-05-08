local CRC32_TABLE = table.create(256)
local POLYNOMIAL = 0xEDB88320

-- Generates crc32 table

for byte = 0, 255 do
    local crc = byte
    for _ = 1, 8 do
        local b = bit32.band(crc, 1)
        crc = bit32.rshift(crc, 1)
        if b == 1 then crc = bit32.bxor(crc, POLYNOMIAL) end
    end

    CRC32_TABLE[byte+1] = crc
end


local function crc32(data: buffer): number
    local crc = 0
    local size = buffer.len(data)
    
    if size == 0 then
        return 0
    end
    
    for i = 0, size - 1 do
        local lcrc = bit32.bnot(crc)
        local byte = buffer.readu8(data, i)
        local v1 = bit32.rshift(lcrc, 8)
        local v2 = CRC32_TABLE[bit32.bxor(lcrc % 256, byte) + 1]
        
        crc = bit32.bnot(bit32.bxor(v1, v2))
    end
    
    return crc
end

return crc32