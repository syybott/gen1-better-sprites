local mod = ...
local VirtualImages = { assets = {}, installed = false }

local function isVirtual(path)
  return type(path) == "string"
    and path:sub(1, 22) == "__gen1_better_sprites/"
end

function VirtualImages.register(path, asset)
  VirtualImages.assets[path] = asset
end

function VirtualImages.install()
  if VirtualImages.installed then return end
  VirtualImages.installed = true

  local originalImageData = love.image.newImageData
  local originalImage = love.graphics.newImage

  local function decode(path)
    local asset = VirtualImages.assets[path]
    assert(asset, "unknown Gen1BetterSprites image: " .. tostring(path))
    local image = originalImageData(asset.width, asset.height)
    local tilesWide = asset.width / 8
    for tile = 0, #asset.pixels / 16 - 1 do
      local tileX = tile % tilesWide * 8
      local tileY = math.floor(tile / tilesWide) * 8
      for y = 0, 7 do
        local low = asset.pixels:byte(tile * 16 + y * 2 + 1)
        local high = asset.pixels:byte(tile * 16 + y * 2 + 2)
        for x = 0, 7 do
          local divisor = 2 ^ (7 - x)
          local shade = math.floor(high / divisor) % 2 * 2
            + math.floor(low / divisor) % 2
          local value = 1 - shade / 3
          local color = asset.palette and asset.palette[shade + 1]
          local red = color and color[1] / 255 or value
          local green = color and color[2] / 255 or value
          local blue = color and color[3] / 255 or value
          local alpha = asset.transparentZero and shade == 0 and 0 or 1
          image:setPixel(tileX + x, tileY + y, red, green, blue, alpha)
        end
      end
    end

    if asset.transparentZero then return image end

    local seen, queue, head = {}, {}, 1
    local function add(x, y)
      local key = y * asset.width + x
      if seen[key] then return end
      local r, g, b, a = image:getPixel(x, y)
      if r == 1 and g == 1 and b == 1 and a == 1 then
        seen[key] = true
        queue[#queue + 1] = { x, y }
      end
    end
    for x = 0, asset.width - 1 do add(x, 0); add(x, asset.height - 1) end
    for y = 0, asset.height - 1 do add(0, y); add(asset.width - 1, y) end
    while head <= #queue do
      local point = queue[head]
      head = head + 1
      local x, y = point[1], point[2]
      image:setPixel(x, y, 1, 1, 1, 0)
      if x > 0 then add(x - 1, y) end
      if x + 1 < asset.width then add(x + 1, y) end
      if y > 0 then add(x, y - 1) end
      if y + 1 < asset.height then add(x, y + 1) end
    end
    return image
  end

  love.image.newImageData = function(source, ...)
    if isVirtual(source) then return decode(source) end
    return originalImageData(source, ...)
  end

  love.graphics.newImage = function(source, ...)
    if isVirtual(source) then return originalImage(decode(source), ...) end
    return originalImage(source, ...)
  end

  mod.log:info("installed in-memory sprite image bridge")
end

return VirtualImages
