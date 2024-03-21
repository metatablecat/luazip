-- An improved Buffer reading library

export type BufferReader = {
	Buffer: buffer,
	Offset: number,
	
	tostring: (BufferReader) -> string,
	len: (BufferReader) -> number,
	
	readi8: (BufferReader) -> number,
	readu8: (BufferReader) -> number,
	readi16: (BufferReader) -> number,
	readu16: (BufferReader) -> number,
	readi32: (BufferReader) -> number,
	readu32: (BufferReader) -> number,
	readf32: (BufferReader) -> number,
	readf64: (BufferReader) -> number,
	
	writei8: (BufferReader, value: number) -> number,
	writeu8: (BufferReader, value: number) -> number,
	writei16: (BufferReader, value: number) -> number,
	writeu16: (BufferReader, value: number) -> number,
	writei32: (BufferReader, value: number) -> number,
	writeu32: (BufferReader, value: number) -> number,
	writef32: (BufferReader, value: number) -> number,
	writef64: (BufferReader, value: number) -> number,
	
	readstring: (BufferReader, size: number) -> string,
	writestring: (BufferReader, value: string, size: number?) -> (),
	
	fill: (BufferReader, value: number, count: number?) -> (),
	
	seek: (BufferReader, dst: number) -> (),
	resize: (BufferReader, newSize: number) -> () -- this is expensive
}

return function(buf: string|buffer): BufferReader
	if typeof(buf) == "string" then
		buf = buffer.fromstring(buf)
	end
	
	local bufReader = {}
	bufReader.Buffer = buf
	bufReader.Offset = 0
	
	-- all functions are proxies to the buffer lib basically, and moves the offset
	-- except seek
	
	function bufReader.seek(self: BufferReader, dst: number)
		-- seek should move the offset add/sub dst
		self.Offset += dst
	end

	function bufReader.tostring(self: BufferReader): string
		return buffer.tostring(self.Buffer)
	end
	
	function bufReader.len(self: BufferReader): number
		return buffer.len(self.Buffer)
	end
	
	function bufReader.readi8(self: BufferReader): number
		local dat = buffer.readi8(self.Buffer, self.Offset)
		self:seek(1)
		return dat
	end
	
	function bufReader.readu8(self: BufferReader): number
		local dat = buffer.readu8(self.Buffer, self.Offset)
		self:seek(1)
		return dat
	end
	
	function bufReader.readi16(self: BufferReader): number
		local dat = buffer.readi16(self.Buffer, self.Offset)
		self:seek(2)
		return dat
	end
	
	function bufReader.readu16(self: BufferReader): number
		local dat = buffer.readu16(self.Buffer, self.Offset)
		self:seek(2)
		return dat
	end
	
	function bufReader.readi32(self: BufferReader): number
		local dat = buffer.readi32(self.Buffer, self.Offset)
		self:seek(4)
		return dat
	end
	
	function bufReader.readu32(self: BufferReader): number
		local dat = buffer.readu32(self.Buffer, self.Offset)
		self:seek(4)
		return dat
	end
	
	function bufReader.readf32(self: BufferReader): number
		local dat = buffer.readf32(self.Buffer, self.Offset)
		self:seek(4)
		return dat
	end
	
	function bufReader.readf64(self: BufferReader): number
		local dat = buffer.readf64(self.Buffer, self.Offset)
		self:seek(8)
		return dat
	end
	
	function bufReader.readstring(self: BufferReader, size: number): string
		local dat = buffer.readstring(self.Buffer, self.Offset, size)
		self:seek(size)
		return dat
	end
	
	function bufReader.writestring(self: BufferReader, value: string, size: number?)
		size = size or #value
		buffer.writestring(self.Buffer, self.Offset, value, size)
		self:seek(size)
	end
	
	function bufReader.writei8(self: BufferReader, value: number): number
		local dat = buffer.writei8(self.Buffer, self.Offset, value)
		self:seek(1)
		return dat
	end
	
	function bufReader.writeu8(self: BufferReader, value: number): number
		local dat = buffer.writeu8(self.Buffer, self.Offset, value)
		self:seek(1)
		return dat
	end
	
	function bufReader.writei16(self: BufferReader, value: number): number
		local dat = buffer.writei16(self.Buffer, self.Offset, value)
		self:seek(2)
		return dat
	end
	
	function bufReader.writeu16(self: BufferReader, value: number): number
		local dat = buffer.writeu16(self.Buffer, self.Offset, value)
		self:seek(2)
		return dat
	end
	
	function bufReader.writei32(self: BufferReader, value: number): number
		local dat = buffer.writei32(self.Buffer, self.Offset, value)
		self:seek(4)
		return dat
	end
	
	function bufReader.writeu32(self: BufferReader, value: number): number
		local dat = buffer.writeu32(self.Buffer, self.Offset, value)
		self:seek(4)
		return dat
	end
	
	function bufReader.writef32(self: BufferReader, value: number): number
		local dat = buffer.writef32(self.Buffer, self.Offset, value)
		self:seek(4)
		return dat
	end
	
	function bufReader.writef64(self: BufferReader, value: number): number
		local dat = buffer.writef64(self.Buffer, self.Offset, value)
		self:seek(8)
		return dat
	end
	
	function bufReader.resize(self: BufferReader, newSize: number)
		-- to do this, we need to make a new buffer and copy the data into it
		local resized = buffer.create(newSize)
		buffer.copy(resized, 0, self.Buffer, 0, newSize)
		self.Buffer = resized
	end
	
	function bufReader.fill(self: BufferReader, value: number, size: number?)
		buffer.fill(self.Buffer, self.Offset, value, size)
	end
	
	return bufReader
end