-- noiz virus :: fx (tape filter + norns system reverb)
-- each virus has its own filter (type + resonance) and its own room.
-- the filter's cutoff follows the virus's synth cutoff, so a saved sound moves it too.

local FX = {}

-- type: lp / bp / hp · rq: 2 = gentle .. 0.3 = resonant · room: small / room / hall / cathedral
FX.P = {
  sars_cov_2     = { "lp", 1.2, "room" },
  influenza_a    = { "bp", 1.0, "room" },
  hiv_1          = { "lp", 0.8, "hall" },
  ebola          = { "lp", 0.7, "cathedral" },
  tmv            = { "hp", 1.4, "small" },
  marburg        = { "lp", 0.6, "hall" },
  rabies         = { "bp", 0.7, "small" },
  polio          = { "hp", 1.2, "small" },
  adeno          = { "bp", 1.4, "room" },
  mimi           = { "lp", 1.6, "cathedral" },
  sputnik        = { "bp", 0.5, "room" },
  t4             = { "bp", 0.8, "small" },
  lambda         = { "lp", 1.0, "room" },
  t7             = { "hp", 0.9, "small" },
  phix174        = { "bp", 0.6, "small" },
  ms2            = { "hp", 0.7, "small" },
  variola        = { "lp", 1.8, "cathedral" },
  orf            = { "bp", 1.2, "room" },
  rotavirus_a    = { "bp", 0.9, "hall" },
  astrovirus     = { "hp", 1.0, "hall" },
  norovirus      = { "hp", 1.6, "room" },
  hsv1           = { "lp", 0.9, "hall" },
  measles        = { "lp", 1.3, "room" },
  zika           = { "bp", 1.1, "hall" },
  chikungunya    = { "hp", 1.3, "room" },
  lassa          = { "lp", 0.5, "hall" },
  hantaan        = { "lp", 1.1, "cathedral" },
  hepb           = { "bp", 0.8, "small" },
  hepd           = { "hp", 0.5, "small" },
  hpv16          = { "bp", 1.5, "room" },
  pithovirus     = { "lp", 0.4, "cathedral" },
  pvy            = { "bp", 1.3, "room" },
  baculovirus    = { "lp", 1.4, "hall" },
  maize_streak   = { "hp", 1.1, "room" },
  alfalfa_mosaic = { "bp", 1.6, "hall" },
  ssv1           = { "hp", 0.6, "room" },
  iridovirus6    = { "bp", 0.4, "cathedral" },
  torovirus      = { "lp", 1.0, "hall" },
  pandoravirus   = { "lp", 1.2, "cathedral" },
  sirv2          = { "hp", 0.4, "small" },
  m13            = { "hp", 1.8, "small" },
  pstvd          = { "bp", 0.5, "hall" }, -- the VIROID sweeps at random anyway
}

-- norns reverb settings per room (pre-delay ms, low / mid decay s, hf damping Hz) + how much it sends
FX.ROOMS = {
  small     = { pre = 8,  low = 1.0, mid = 0.7, damp = 4500, send = 0.6 },
  room      = { pre = 20, low = 2.2, mid = 1.8, damp = 6000, send = 0.8 },
  hall      = { pre = 40, low = 4.5, mid = 3.6, damp = 7000, send = 0.9 },
  cathedral = { pre = 70, low = 9.0, mid = 7.0, damp = 5000, send = 1.0 },
}
FX.ROOM_NAMES = { "small", "room", "hall", "cathedral" }

-- the norns system reverb lives in a system paramset ("mix" on current norns, "params" on older)
local SYS = { "reverb", "rev_eng_input", "rev_cut_input", "rev_monitor_input", "rev_tape_input",
  "rev_pre_delay", "rev_low_time", "rev_mid_time", "rev_hf_damping" }
local snap = {}

local function sys(id)
  for _, ps in ipairs({ rawget(_G, "mix"), rawget(_G, "params") }) do
    local ok, has = pcall(function() return ps and ps.lookup and ps.lookup[id] ~= nil end)
    if ok and has then return ps end
  end
end

local function sys_set(id, v)
  local ps = sys(id)
  if ps then pcall(function() ps:set(id, v) end) end
end

-- remember the system reverb as it was, then switch it on
function FX.init()
  for _, id in ipairs(SYS) do
    local ps = sys(id)
    if ps then pcall(function() snap[id] = ps:get(id) end) end
  end
  sys_set("reverb", 2)
  pcall(function() audio.rev_on() end)
end

function FX.room(name)
  local r = FX.ROOMS[name] or FX.ROOMS.room
  sys_set("rev_pre_delay", r.pre)
  sys_set("rev_low_time", r.low)
  sys_set("rev_mid_time", r.mid)
  sys_set("rev_hf_damping", r.damp)
end

function FX.off()
  sys_set("reverb", 1)
  pcall(function() audio.rev_off() end)
end

function FX.on()
  sys_set("reverb", 2)
  pcall(function() audio.rev_on() end)
end

-- sends, 0..1 each
function FX.sends(eng, cut, mon)
  audio.level_eng_rev(eng)
  audio.level_cut_rev(cut)
  audio.level_monitor_rev(mon)
end

-- put the system reverb back the way it was
function FX.cleanup()
  for _, id in ipairs(SYS) do
    local ps = sys(id)
    if ps and snap[id] ~= nil then
      pcall(function()
        ps:set(id, snap[id])
        local p = ps:lookup_param(id)
        if p and p.bang then p:bang() end
      end)
    end
  end
end

-- softcut's filter after the playhead: kind = "lp" / "bp" / "hp" / "off"
local function sc(name, ...)
  local f = softcut["post_filter_" .. name] or softcut["filter_" .. name]
  if f then f(...) end
end

function FX.filter(v, kind, fc, rq)
  if kind == "off" then
    sc("dry", v, 1); sc("lp", v, 0); sc("bp", v, 0); sc("hp", v, 0); sc("br", v, 0)
    return
  end
  sc("dry", v, 0); sc("br", v, 0)
  sc("lp", v, kind == "lp" and 1 or 0)
  sc("bp", v, kind == "bp" and 1 or 0)
  sc("hp", v, kind == "hp" and 1 or 0)
  sc("fc", v, fc)
  sc("rq", v, rq)
end

-- delay per virus: time in beats (1/16 = 0.25, 1/8T = 1/3, 1/8 = 0.5, 3/16 = 0.75, 1/4 = 1, 3/8 = 1.5)
-- and feedback (0..0.9). the VIROID picks a new time on every throw.
FX.D = {
  sars_cov_2     = { 0.75, 0.45 }, influenza_a    = { 0.5,  0.55 }, hiv_1          = { 1,    0.4  },
  ebola          = { 1.5,  0.7  }, tmv            = { 0.25, 0.3  }, marburg        = { 1,    0.65 },
  rabies         = { 0.25, 0.5  }, polio          = { 1/3,  0.35 }, adeno          = { 0.5,  0.4  },
  mimi           = { 1.5,  0.6  }, sputnik        = { 1/3,  0.55 }, t4             = { 0.25, 0.6  },
  lambda         = { 0.75, 0.5  }, t7             = { 1/3,  0.45 }, phix174        = { 0.25, 0.4  },
  ms2            = { 0.5,  0.3  }, variola        = { 1,    0.75 }, orf            = { 0.75, 0.35 },
  rotavirus_a    = { 0.5,  0.65 }, astrovirus     = { 1/3,  0.6  }, norovirus      = { 0.25, 0.55 },
  hsv1           = { 1.5,  0.5  }, measles        = { 0.75, 0.55 }, zika           = { 0.5,  0.5  },
  chikungunya    = { 1/3,  0.4  }, lassa          = { 1,    0.6  }, hantaan        = { 1.5,  0.45 },
  hepb           = { 0.5,  0.35 }, hepd           = { 0.25, 0.25 }, hpv16          = { 0.75, 0.3  },
  pithovirus     = { 1.5,  0.85 }, pvy            = { 1/3,  0.5  }, baculovirus    = { 1,    0.45 },
  maize_streak   = { 0.75, 0.6  }, alfalfa_mosaic = { 0.5,  0.45 }, ssv1           = { 0.25, 0.7  },
  iridovirus6    = { 0.75, 0.8  }, torovirus      = { 1,    0.55 }, pandoravirus   = { 1.5,  0.65 },
  sirv2          = { 1/3,  0.75 }, m13            = { 0.5,  0.6  }, pstvd          = { 0.5,  0.5  },
}
FX.DELAY_BEATS = { 0.25, 1/3, 0.5, 0.75, 1, 1.5 }

-- panning character per virus:
--   still = stays centred · rarely = centred, now and then one read jumps out
--   wander = drifts slowly across · bounce = jumps on every read
--   letters = purines (A G) lean left, pyrimidines (C U) lean right
--   split = the shape decides: HIV's two voices L/R, each segment its own place
FX.PAN = {
  tmv = "still", polio = "still", hepb = "still", adeno = "still", hpv16 = "still",
  maize_streak = "still", chikungunya = "still",
  sars_cov_2 = "rarely", measles = "rarely", zika = "rarely", sputnik = "rarely", lambda = "rarely",
  orf = "rarely", baculovirus = "rarely", torovirus = "rarely",
  ebola = "wander", marburg = "wander", mimi = "wander", variola = "wander", pithovirus = "wander",
  pandoravirus = "wander", hsv1 = "wander", iridovirus6 = "wander",
  rabies = "bounce", norovirus = "bounce", t4 = "bounce", t7 = "bounce", phix174 = "bounce",
  m13 = "bounce", sirv2 = "bounce", ssv1 = "bounce",
  astrovirus = "letters", hepd = "letters", ms2 = "letters", pvy = "letters",
  influenza_a = "split", hiv_1 = "split", rotavirus_a = "split", lassa = "split", hantaan = "split",
  alfalfa_mosaic = "split",
  pstvd = "chaos",
}

return FX
