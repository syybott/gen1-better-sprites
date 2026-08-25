local mod = ...
local Cache = {}
local MAGIC = "G1BS1"

function Cache.readSprite(key, fingerprint)
  local bytes = mod.cache:read(key)
  if type(bytes) ~= "string" then return nil end
  local prefix = MAGIC .. fingerprint .. "\0"
  if bytes:sub(1, #prefix) ~= prefix then return nil end
  local width, height = bytes:byte(#prefix + 1, #prefix + 2)
  local pixels = bytes:sub(#prefix + 3)
  if #pixels ~= width * height / 4 then return nil end
  return { width = width, height = height, pixels = pixels }
end

function Cache.writeSprite(key, fingerprint, asset)
  local bytes = MAGIC .. fingerprint .. "\0"
    .. string.char(asset.width, asset.height) .. asset.pixels
  return mod.cache:write(key, bytes)
end

return Cache
