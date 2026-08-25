local mod, requireLocal = ...
local Lz3 = requireLocal("lz3")
local Sprites = {}

local function bytesToString(bytes, count)
  local chunks, chunk = {}, {}
  for i = 1, count do
    chunk[#chunk + 1] = string.char(bytes[i] or 0)
    if #chunk == 4096 then
      chunks[#chunks + 1] = table.concat(chunk)
      chunk = {}
    end
  end
  chunks[#chunks + 1] = table.concat(chunk)
  return table.concat(chunks)
end

local function columnsToRows(data, tiles)
  local out = {}
  for y = 0, tiles - 1 do
    for x = 0, tiles - 1 do
      local source = (x * tiles + y) * 16
      local target = (y * tiles + x) * 16
      for i = 1, 16 do out[target + i] = data[source + i] end
    end
  end
  return out
end

local function farPointer(reader, table_, species, side)
  local address = table_.address + (species - 1) * 6 + (side == "back" and 3 or 0)
  return reader:byte(table_.bank, address),
    reader:word(table_.bank, address + 1)
end

local function decodePic(reader, layout, species, side, picSize)
  local bank, address = farPointer(reader, layout.picPointers, species, side)
  if layout.picBankOffset then
    bank = bank + layout.picBankOffset
  elseif layout.picBankFix then
    bank = layout.picBankFix[bank] or bank
  end
  local compressed = reader:read(bank, address, 0x8000 - address + 0x4000)
  local stream = Lz3.decompress(compressed)
  local byteCount = picSize * picSize * 16
  local rowMajor = columnsToRows(stream, picSize)
  return {
    width = picSize * 8,
    height = picSize * 8,
    pixels = bytesToString(rowMajor, byteCount),
  }
end

function Sprites.front(reader, layout, species)
  local rowAddress = layout.baseData.address + (species - 1) * 32
  local picSize = reader:byte(layout.baseData.bank, rowAddress + 17) % 16
  assert(picSize >= 5 and picSize <= 7, "invalid front sprite size")
  return decodePic(reader, layout, species, "front", picSize)
end

function Sprites.back(reader, layout, species)
  return decodePic(reader, layout, species, "back", 6)
end

local function gbcColor(lo, hi)
  local value = lo + hi * 0x100
  local function expand(channel)
    return math.floor(channel * 255 / 31 + 0.5)
  end
  return {
    expand(value % 0x20),
    expand(math.floor(value / 0x20) % 0x20),
    expand(math.floor(value / 0x400) % 0x20),
  }
end

function Sprites.palette(reader, layout, species)
  local table_ = assert(layout.pokemonPalettes, "missing Pokemon palette table")
  -- Row zero is the unused species entry. Each species row stores the two
  -- normal middle colors followed by the two shiny middle colors.
  local bytes = reader:read(table_.bank, table_.address + species * 8, 4)
  return {
    { 255, 255, 255 },
    gbcColor(bytes:byte(1), bytes:byte(2)),
    gbcColor(bytes:byte(3), bytes:byte(4)),
    { 0, 0, 0 },
  }
end

function Sprites.icon(reader, layout, species)
  local iconIndex = reader:byte(
    layout.monMenuIcons.bank, layout.monMenuIcons.address + species - 1)
  local address = reader:word(
    layout.iconPointers.bank, layout.iconPointers.address + iconIndex * 2)
  return {
    width = 16,
    height = 32,
    pixels = reader:read(layout.icons.bank, address, 8 * 16),
    transparentZero = true,
  }
end

return Sprites
