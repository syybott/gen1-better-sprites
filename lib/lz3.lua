local Lz3 = {}

local function flipBits(value)
  local flipped = 0
  for bitIndex = 0, 7 do
    flipped = flipped
      + math.floor(value / 2 ^ bitIndex) % 2 * 2 ^ (7 - bitIndex)
  end
  return flipped
end

function Lz3.decompress(data)
  local pos, out = 1, {}
  local function nextByte()
    local value = data:byte(pos)
    assert(value, "lz3 stream ended unexpectedly")
    pos = pos + 1
    return value
  end

  while true do
    local first = nextByte()
    if first == 0xff then break end
    local command, length
    if math.floor(first / 0x20) == 7 then
      command = math.floor(first / 4) % 8
      length = first % 4 * 0x100 + nextByte() + 1
    else
      command = math.floor(first / 0x20)
      length = first % 0x20 + 1
    end

    if command == 0 then
      for _ = 1, length do out[#out + 1] = nextByte() end
    elseif command == 1 then
      local value = nextByte()
      for _ = 1, length do out[#out + 1] = value end
    elseif command == 2 then
      local a, b = nextByte(), nextByte()
      for i = 1, length do out[#out + 1] = i % 2 == 1 and a or b end
    elseif command == 3 then
      for _ = 1, length do out[#out + 1] = 0 end
    else
      local encoded = nextByte()
      local from
      if encoded >= 0x80 then
        from = #out - encoded % 0x80
      else
        from = encoded * 0x100 + nextByte() + 1
      end
      if command == 5 then
        for i = 0, length - 1 do out[#out + 1] = flipBits(out[from + i]) end
      elseif command == 6 then
        for i = 0, length - 1 do out[#out + 1] = out[from - i] end
      else
        for i = 0, length - 1 do out[#out + 1] = out[from + i] end
      end
    end
  end
  return out
end

return Lz3
