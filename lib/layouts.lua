local Layouts = {}

Layouts.gold = {
  id = "gold",
  importId = "gold_rom",
  baseData = { bank = 0x14, address = 0x5b0b },
  picPointers = { bank = 0x12, address = 0x4000 },
  iconPointers = { bank = 0x23, address = 0x6a70 },
  icons = { bank = 0x23, address = 0x6abe },
  monMenuIcons = { bank = 0x23, address = 0x6975 },
  picBankFix = {
    [0x13] = 0x1f,
    [0x14] = 0x20,
    [0x1f] = 0x2e,
  },
}

Layouts.silver = {
  id = "silver",
  importId = "silver_rom",
  baseData = { bank = 0x14, address = 0x5b0b },
  picPointers = { bank = 0x12, address = 0x4000 },
  iconPointers = { bank = 0x23, address = 0x6a56 },
  icons = { bank = 0x23, address = 0x6aa4 },
  monMenuIcons = { bank = 0x23, address = 0x695b },
  picBankFix = Layouts.gold.picBankFix,
}

Layouts.crystal = {
  id = "crystal",
  importId = "crystal_rom",
  baseData = { bank = 0x14, address = 0x5424 },
  picPointers = { bank = 0x48, address = 0x4000 },
  iconPointers = { bank = 0x23, address = 0x6bbf },
  icons = { bank = 0x23, address = 0x6c0d },
  monMenuIcons = { bank = 0x23, address = 0x6ac4 },
  picBankOffset = 0x36,
}

return Layouts
