local Reader = {}
Reader.__index = Reader

local function offset(bank, address)
  if bank == 0 then return address end
  assert(address >= 0x4000 and address < 0x8000,
    ("invalid banked address %02x:%04x"):format(bank, address))
  return bank * 0x4000 + address - 0x4000
end

function Reader.new(imports, importId)
  return setmetatable({ imports = imports, importId = importId }, Reader)
end

function Reader:read(bank, address, length)
  local data, err = self.imports:read(
    self.importId, offset(bank, address), length)
  assert(data, err)
  return data
end

function Reader:byte(bank, address)
  return self:read(bank, address, 1):byte(1)
end

function Reader:word(bank, address)
  local a, b = self:read(bank, address, 2):byte(1, 2)
  return a + b * 0x100
end

return Reader
