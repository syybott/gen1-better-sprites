local mod = ...

local OptionRows = require("src.ui.OptionRows")

local Screen = { isModOptions = true }
Screen.__index = Screen

local function stepChoice(choices, current, direction)
  local index = 1
  for i, choice in ipairs(choices) do
    if choice[2] == current then index = i break end
  end
  index = (index - 1 + direction) % #choices + 1
  return choices[index][2]
end

function Screen.new(game, config)
  local self = setmetatable({
    game = game,
    isModOptions = true,
    isOpaque = true,
    screenId = "BetterSpritesOptions",
    index = 1,
    scroll = 0,
  }, Screen)

  local rows = {
    {
      label = "SPRITE SOURCE",
      value = function() return config.label("source") end,
      step = function(_, direction)
        config.set("source", stepChoice(config.sourceChoices,
          config.get("source"), direction))
        return true
      end,
    },
  }

  if #config.sourceChoices == 1 then
    rows[#rows + 1] = { label = "MOD MANAGER SCREEN >", info = true }
    rows[#rows + 1] = { label = "GEN1BETTER ASSETS >", info = true }
    rows[#rows + 1] = { label = "IMPORTED FILES >", info = true }
    rows[#rows + 1] = { label = "IMPORT YOUR ROMS", info = true }
  end

  local function toggleRow(label, key)
    return {
      label = label,
      value = function() return config.get(key) and "ON" or "OFF" end,
      step = function()
        config.set(key, not config.get(key))
        return true
      end,
    }
  end
  rows[#rows + 1] = toggleRow("MENU TRUE COLOR", "menu_true_color")
  rows[#rows + 1] = toggleRow("BATTLE TRUE COLOR", "battle_true_color")
  rows[#rows + 1] = toggleRow("GLOBAL PALETTES", "global_palettes")
  self.rows = rows
  self.selectable = {}
  for i, row in ipairs(rows) do
    if not row.info then self.selectable[#self.selectable + 1] = i end
  end
  return self
end

function Screen:update()
  local input = self.game.input
  local position = 1
  for i, rowIndex in ipairs(self.selectable) do
    if rowIndex == self.index then position = i break end
  end
  if input:wasPressed("up") then
    position = (position - 2) % #self.selectable + 1
    self.index = self.selectable[position]
  elseif input:wasPressed("down") then
    position = position % #self.selectable + 1
    self.index = self.selectable[position]
  elseif input:wasPressed("left") or input:wasPressed("right")
      or input:wasPressed("a") then
    local direction = input:wasPressed("left") and -1 or 1
    local row = self.rows[self.index]
    if row and row.step then row.step(self.game, direction) end
  elseif input:wasPressed("b") or input:wasPressed("start") then
    self.game.stack:pop()
  end
  self.scroll = OptionRows.clampScroll(self.index, self.scroll,
    #self.rows, nil)
end

function Screen:draw()
  OptionRows.draw(self.game, self.rows, self.index, self.scroll,
    "B:DONE  RESTART REQUIRED")
end

return Screen
