-- Gen1BetterSprites 0.1.0

local modules = {}
local function localRequire(name)
  if modules[name] ~= nil then return modules[name] end
  local relative = "lib/" .. name .. ".lua"
  local source = assert(mod:read(relative), "missing " .. relative)
  local chunk = assert(load(source, "@" .. mod.path .. "/" .. relative))
  local value = chunk(mod, localRequire)
  modules[name] = value
  return value
end

local Layouts = localRequire("layouts")
local Reader = localRequire("rom_reader")
local Sprites = localRequire("sprites")
local Cache = localRequire("cache")
local VirtualImages = localRequire("virtual_images")

VirtualImages.install()

mod.options:define({
  { key = "source", label = "SPRITE SOURCE", type = "choice", default = "auto",
    choices = {
      { "AUTO", "auto" }, { "GOLD", "gold" },
      { "SILVER", "silver" }, { "CRYSTAL", "crystal" },
    } },
})

local requested = mod.options:get("source") or "auto"
local source
if requested ~= "auto" and Layouts[requested]
   and mod.imports:info(Layouts[requested].importId) then
  source = Layouts[requested]
else
  for _, id in ipairs({ "crystal", "silver", "gold" }) do
    if mod.imports:info(Layouts[id].importId) then
      source = Layouts[id]
      break
    end
  end
end

if requested ~= "auto" and (not source or source.id ~= requested) then
  mod.log:warn("requested %s ROM is unavailable; using %s",
    requested, source and source.id or "normal Gen 1 sprites")
end

if source then
local info = mod.imports:info(source.importId)
  local speciesRows = {}
  for id, def in mod.content.pokemon:each() do
    local dex = tonumber(def.dex)
    if dex and dex >= 1 and dex <= 151 then
      speciesRows[#speciesRows + 1] = { id = id, dex = dex }
    end
  end
  table.sort(speciesRows, function(a, b) return a.dex < b.dex end)

  local reader = Reader.new(mod.imports, source.importId)
  local frontPaths, backPaths, frontsReady, backsReady, iconsReady = {}, {}, 0, 0, 0
  for _, row in ipairs(speciesRows) do
    local cacheKey = ("sprites/v1/%s/front/%03d.bin"):format(source.id, row.dex)
    local asset = Cache.readSprite(cacheKey, info.md5)
    if not asset then
      local ok, extracted = pcall(Sprites.front, reader, source, row.dex)
      if ok then
        asset = extracted
        Cache.writeSprite(cacheKey, info.md5, asset)
      else
        mod.log:error("%s front extraction failed for %s: %s",
          source.id, row.id, tostring(extracted))
      end
    end

    if asset then
      local path = "__gen1_better_sprites/" .. source.id
        .. "/front/" .. row.id:lower()
      VirtualImages.register(path, asset)
      frontPaths[row.id] = path
      frontsReady = frontsReady + 1
    end

    local backKey = ("sprites/v1/%s/back/%03d.bin"):format(source.id, row.dex)
    local back = Cache.readSprite(backKey, info.md5)
    if not back then
      local ok, extracted = pcall(Sprites.back, reader, source, row.dex)
      if ok then
        back = extracted
        Cache.writeSprite(backKey, info.md5, back)
      else
        mod.log:error("%s back extraction failed for %s: %s",
          source.id, row.id, tostring(extracted))
      end
    end
    if back then
      local path = "__gen1_better_sprites/" .. source.id
        .. "/back/" .. row.id:lower()
      VirtualImages.register(path, back)
      backPaths[row.id] = path
      backsReady = backsReady + 1
    end

    local iconKey = ("sprites/v1/%s/icon/%03d.bin"):format(source.id, row.dex)
    local icon = Cache.readSprite(iconKey, info.md5)
    if not icon then
      local ok, extracted = pcall(Sprites.icon, reader, source, row.dex)
      if ok then
        icon = extracted
        Cache.writeSprite(iconKey, info.md5, icon)
      else
        mod.log:error("%s icon extraction failed for %s: %s",
          source.id, row.id, tostring(extracted))
      end
    end
    if icon then
      icon.transparentZero = true
      local path = "__gen1_better_sprites/" .. source.id
        .. "/icon/" .. row.id:lower()
      VirtualImages.register(path, icon)
      mod.content.icons:override(row.id, { image = path, frames = 2 })
      iconsReady = iconsReady + 1
    end
  end

  mod.hooks:wrap("pokemon.sprite", function(next, vanillaPath, context)
    if context and context.side == "front" then
      local path = frontPaths[context.species]
      if path then return path end
    elseif context and context.side == "back" then
      local path = backPaths[context.species]
      if path then return path end
    end
    return next(vanillaPath, context)
  end)
  mod.log:info("%d %s front, %d back, and %d party icons are ready",
    frontsReady, source.id, backsReady, iconsReady)
else
  mod.log:info("no supported Gen 2 ROM is imported; using normal Gen 1 sprites")
end

return mod
