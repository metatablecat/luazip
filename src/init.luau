-- ZIP opener
-- Opens zip files and returns a tree of files/directories
-- NOTE: These are compressed until :open is called
local BufferReader = require(script.BufferReader)
local Deflate = require(script.Deflate)
local crc = require(script.CRC32)

type ZIPCommon = ZIPFile & ZIPDirectory

local DISABLE_CRC = false -- You should leave this on, unless debugging bad data
local COMPRESSION_METHODS = {
	[0] = "Uncompressed",
	[8] = "Deflate",
}

export type ZIPFile = {
	Type: "File",
	Parent: ZIPDirectory?,
	UncompressedSize: number,
	CompressedData: buffer,
	CompressionMethod: "Uncompressed"|"Deflate"|"Unknown",
	CRC32: number,
	Open: (ZIPFile) -> string -- uncompressed data
}

export type ZIPDirectory = {
	Type: "Directory",
	Parent: ZIPDirectory?,
	Name: string,
	Objects: {[string]: ZIPCommon}
}

local function EOCD(eocdBuffer: BufferReader.BufferReader)
	-- this will assume the data has been copied over
	
	eocdBuffer:seek(4) -- signature
	local eocd = {
		DiskNum = eocdBuffer:readu16(),
		StartDisk = eocdBuffer:readu16(),
		NumEntries = eocdBuffer:readu16(),
		TotalEntries = eocdBuffer:readu16(),
		DirectorySize = eocdBuffer:readu32(),
		DirectoryOffset = eocdBuffer:readu32()
	}
	
	local commentLen = eocdBuffer:readu16()
	eocd.Comment = if commentLen > 0 then eocdBuffer:readstring(commentLen) else ""
	return eocd
end

local function DirectoryRecord(buffer: BufferReader.BufferReader)
	local record = {
		Version = buffer:readu16(),
		MinVersion = buffer:readu16(),
		BitFlag = buffer:readu16(),
		CompressionMethod = buffer:readu16(),
		ModifiedTime = buffer:readu16(),
		ModifiedDate = buffer:readu16(),
		CRC32 = buffer:readu32(),
		CompressedSize = buffer:readu32(),
		UncompressedSize = buffer:readu32(),
		FileNameLength = buffer:readu16(),
		ExtraFieldLength = buffer:readu16(),
		FileCommentLength = buffer:readu16(),
		DiskStart = buffer:readu16(),
		InternalFileAttributes = buffer:readu16(),
		ExternalFileAttributes = buffer:readu32(),
		OffsetOfLocalHeader = buffer:readu32()
	}
	
	record.FileName = if record.FileNameLength > 0 then buffer:readstring(record.FileNameLength) else ""
	record.ExtraField = if record.ExtraFieldLength > 0 then buffer:readstring(record.ExtraFieldLength) else ""
	record.FileComment = if record.FileCommentLength > 0 then buffer:readstring(record.FileCommentLength) else ""
	return record
end

local function DirectoryRecords(record: string)
	-- returns multiple directory records for each file in the record
	local fileStreams = string.split(record, "PK\01\02")
	table.remove(fileStreams, 1) -- remove the dead record
	
	local files = table.create(#fileStreams)
	
	for i, fileStream in fileStreams do
		files[i] = DirectoryRecord(BufferReader(fileStream))
	end
	
	return files
end

local function ZIPFile(reader: BufferReader.BufferReader): ZIPFile
	reader:readu32() -- signature
	local header = {
		MinVersion = reader:readu16(),
		BitFlag = reader:readu16(),
		CompressionMethod = reader:readu16(),
		ModifiedTime = reader:readu16(),
		ModifiedDate = reader:readu16(),
		CRC32 = reader:readu32(),
		CompressedSize = reader:readu32(),
		UncompressedSize = reader:readu32(),
		FileNameLength = reader:readu16(),
		ExtraFieldLength = reader:readu16()
	}
	
	header.FileName = if header.FileNameLength > 0 then reader:readstring(header.FileNameLength) else ""
	header.ExtraField = if header.ExtraFieldLength > 0 then reader:readstring(header.ExtraFieldLength) else ""
	
	local data = reader:readstring(if header.CompressionMethod == 0 then header.UncompressedSize else header.CompressedSize)
	local zipFile = {
		Type = "File",
		UncompressedSize = header.UncompressedSize,
		CompressedData = data,
		CompressionMethod = COMPRESSION_METHODS[header.CompressionMethod] or "Unknown",
		CRC32 = header.CRC32,
		
		Open = function(self)
			local data
			if self.CompressionMethod == "Uncompressed" then
				data = self.CompressedData
			elseif self.CompressionMethod == "Deflate" then
				data = Deflate(self.CompressedData)
			else
				error("Unknown compression method")
			end
			
			local crcCheck = crc(buffer.fromstring(data))
			if crcCheck ~= self.CRC32 then
				(if DISABLE_CRC then warn else error)(`Failed CRC check. {crcCheck}, {self.CRC32}`)
			end

			return data
		end,
	}
	return zipFile
end

local function BuildFiles(stream, fileHeaders): {[string]: ZIPFile}
	-- builds files from directory headers
	local zipfiles = {}
	local fileReader = BufferReader(stream)
	for _, v in fileHeaders do
		fileReader.Offset = v.OffsetOfLocalHeader
		zipfiles[v.FileName] = ZIPFile(fileReader)
	end
	
	return zipfiles
end

local function ZIPDirectory(name, parent): ZIPDirectory
	local d = {
		Type = "Directory",
		Name = name,
		Parent = parent,
		Objects = {}
	}
	
	if parent then parent.Objects[name] = d end
	return d
end

local function GetDirectoryTree(root: ZIPDirectory, fileName: string): ZIPDirectory
	-- gets or creates missing directories from the given file name
	local directories = string.split(fileName, "/")
	local localFileName = table.remove(directories, #directories)
	local top = root
	
	for _, directory in directories do
		top = top.Objects[directory] or ZIPDirectory(directory, top)
	end
	
	return top, localFileName
end

local function BuildDirectories(files: {[string]: ZIPFile}, root: ZIPDirectory)
	-- builds directory tree from file name
	for fileName, file in files do
		local directory, localFileName = GetDirectoryTree(root, fileName)
		if localFileName == "" then continue end -- ignore empty files
		
		file.Parent = directory
		directory.Objects[localFileName] = file
	end
end

-- a pattern to find the End of central directory (at the end)
local EOCD_FindPat ="[%s%S]+(PK\05\06.-)$"
return function(zip: string, name: string?): ZIPDirectory
	local eocdBuffer = string.match(zip, EOCD_FindPat)
	local EOCD = EOCD(BufferReader(eocdBuffer))
	
	
	local fileHeaders = DirectoryRecords(string.sub(zip, EOCD.DirectoryOffset + 1, EOCD.DirectoryOffset + EOCD.DirectorySize))
	local objects = BuildFiles(zip, fileHeaders)
	
	local root = ZIPDirectory(name or "")
	BuildDirectories(objects, root)
	return root
end