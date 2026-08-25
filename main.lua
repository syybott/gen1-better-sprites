local mod = ...

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
local OptionsScreen = localRequire("options_screen")

VirtualImages.install()

local sourceChoices = { { "GEN1", "gen1" } }
for _, id in ipairs({ "gold", "silver", "crystal" }) do
  if mod.imports:info(Layouts[id].importId) then
    sourceChoices[#sourceChoices + 1] = { id:upper(), id }
  end
end
mod.options:define({
  { key = "source", label = "SPRITE SOURCE", type = "choice",
    default = "gen1", choices = sourceChoices },
  { key = "menu_true_color", label = "MENU TRUE COLOR", type = "toggle",
    default = false },
  { key = "battle_true_color", label = "BATTLE TRUE COLOR", type = "toggle",
    default = false },
  { key = "global_palettes", label = "GLOBAL PALETTES", type = "toggle",
    default = false },
})
local runtimeOptions = {
  source = mod.options:get("source") or "gen1",
  menu_true_color = mod.options:get("menu_true_color") == true,
  battle_true_color = mod.options:get("battle_true_color") == true,
  global_palettes = mod.options:get("global_palettes") == true,
}
if runtimeOptions.source == "auto" then runtimeOptions.source = "gen1" end
local MOD_ID = "gen1-better-sprites"
local function setOption(game, key, value)
  runtimeOptions[key] = value
  local options = game.options or game.save and game.save.options
  if not options then return end
  options.modOptions = options.modOptions or {}
  local bucket = options.modOptions[MOD_ID] or {}
  options.modOptions[MOD_ID] = bucket
  bucket[key] = value
  if game.mods then
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions[MOD_ID] = bucket
  end
  if game.writeOptions then game:writeOptions() end
end
mod.content.screens:register("BetterSpritesOptions", {
  isModOptions = true,
  new = function(game)
    return OptionsScreen.new(game, {
      sourceChoices = sourceChoices,
      get = function(key) return runtimeOptions[key] end,
      set = function(key, value) setOption(game, key, value) end,
      label = function(key)
        local value = runtimeOptions[key]
        for _, choice in ipairs(sourceChoices) do
          if choice[2] == value then return choice[1] end
        end
        return "GEN1"
      end,
    })
  end,
})
mod.hooks:wrap("ui.options.rows", function(next, game, rows)
  local out = next(game, rows)
  if type(out) ~= "table" then return out end
  out[#out + 1] = {
    id = "gen1_better_sprites_options", label = "BETTERSPRITES",
    value = function() return "OPEN" end,
    activate = function(g) mod.ui.push(g, "BetterSpritesOptions") end,
  }
  return out
end)

local requested = runtimeOptions.source
local source
if requested ~= "gen1" and Layouts[requested]
   and mod.imports:info(Layouts[requested].importId) then
  source = Layouts[requested]
end

if requested ~= "gen1" and not source then
  mod.log:warn("requested %s ROM is unavailable; using normal Gen 1 sprites",
    requested)
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
  local frontPaths, backPaths, colorFrontPaths, colorBackPaths = {}, {}, {}, {}
  local frontsReady, backsReady, iconsReady = 0, 0, 0
  for _, row in ipairs(speciesRows) do
    local palette = Sprites.palette(reader, source, row.dex)
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
      local colorPath = path .. "/true_color"
      local colored = {}
      for key, value in pairs(asset) do colored[key] = value end
      colored.palette = palette
      VirtualImages.register(colorPath, colored)
      colorFrontPaths[row.id] = colorPath
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
      local colorPath = path .. "/true_color"
      local colored = {}
      for key, value in pairs(back) do colored[key] = value end
      colored.palette = palette
      VirtualImages.register(colorPath, colored)
      colorBackPaths[row.id] = colorPath
      mod.content.battle_sprite_scales:register(
        "gen1_better_sprites_back_" .. source.id .. "_" .. row.id:lower(),
        { path = path, scale = 4 / 3 })
      mod.content.battle_sprite_scales:register(
        "gen1_better_sprites_back_color_" .. source.id .. "_" .. row.id:lower(),
        { path = colorPath, scale = 4 / 3 })
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
    if runtimeOptions.global_palettes then
      local paletteId = "GEN1BETTER_" .. source.id:upper() .. "_" .. row.id
      mod.content.palettes:register(paletteId, palette)
      mod.content.pokemon:patch(row.id, { palette = paletteId })
    end
  end

  mod.hooks:wrap("pokemon.sprite", function(next, vanillaPath, context)
    if context and context.side == "front" then
      local trueColor = context.kind == "battle"
        and runtimeOptions.battle_true_color
        or context.kind ~= "battle" and runtimeOptions.menu_true_color
      local path = trueColor and colorFrontPaths[context.species]
        or frontPaths[context.species]
      if path and trueColor then context.trueColor = true end
      if path then return path end
    elseif context and context.side == "back" then
      local trueColor = context.kind == "battle"
        and runtimeOptions.battle_true_color
        or context.kind ~= "battle" and runtimeOptions.menu_true_color
      local path = trueColor and colorBackPaths[context.species]
        or backPaths[context.species]
      if path and trueColor then context.trueColor = true end
      if path then return path end
    end
    return next(vanillaPath, context)
  end)
  mod.log:info("%d %s front, %d back, and %d party icons are ready",
    frontsReady, source.id, backsReady, iconsReady)
else
  mod.log:info("Gen 1 sprite source selected")
end

return mod
