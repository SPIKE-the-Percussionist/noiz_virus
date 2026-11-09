-- noiz virus :: the specimens
-- each virus: name, data file, strand type, and a draw(cx, cy, a, pulse, flinch)
-- a = rotation angle, pulse = swell on each note, flinch = spikes pulling in on STOP

local V = {}

local sin, cos, sqrt, floor, pi = math.sin, math.cos, math.sqrt, math.floor, math.pi

local function rot(x, y, z, ay, ax)
  local c, s = cos(ay), sin(ay)
  x, z = x * c + z * s, -x * s + z * c
  c, s = cos(ax), sin(ax)
  y, z = y * c - z * s, y * s + z * c
  return x, y, z
end

local function fib(n, seed)
  local pts, ga = {}, pi * (3 - sqrt(5))
  for i = 0, n - 1 do
    local y = 1 - 2 * (i + 0.5) / n
    local r = sqrt(1 - y * y)
    local th = ga * i + (seed or 0)
    pts[#pts + 1] = { cos(th) * r, y, sin(th) * r }
  end
  return pts
end

-- depth (-1 back .. 1 front) -> grey level
local function dl(z, lo, hi)
  local t = (z + 1) / 2
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  return floor(lo + (hi - lo) * t + 0.5)
end

-- fake-lit ball: stacked circles drifting toward the light (top left)
local function ball(cx, cy, r, lo, hi)
  local n = 6
  for i = 0, n - 1 do
    local f = i / n
    screen.level(floor(lo + (hi - lo) * f + 0.5))
    screen.circle(cx - r * 0.32 * f, cy - r * 0.38 * f, r * (1 - 0.8 * f))
    screen.fill()
  end
end

local function by_z(p, q) return p[3] < q[3] end

-- a sphere with spikes (corona, flu)
local function spiky(cfg)
  local dirs = fib(cfg.n, cfg.seed)
  local tilt = cfg.tilt or 0.3
  return function(cx, cy, a, pulse, flinch)
    local r = cfg.r * pulse
    local len = cfg.len * pulse * flinch
    local sp = {}
    for i, d in ipairs(dirs) do
      local x, y, z = rot(d[1], d[2], d[3], a, tilt)
      sp[i] = { x, y, z }
    end
    table.sort(sp, by_z)
    local function spike(p)
      local tx, ty = cx + p[1] * (r + len), cy + p[2] * (r + len)
      screen.level(dl(p[3], cfg.lo, cfg.hi))
      screen.move(cx + p[1] * (r - 1), cy + p[2] * (r - 1))
      screen.line(tx, ty)
      screen.stroke()
      if cfg.tip > 0 then
        screen.circle(tx, ty, cfg.tip * flinch)
        screen.fill()
      end
    end
    for _, p in ipairs(sp) do if p[3] < 0 then spike(p) end end
    ball(cx, cy, r, cfg.blo, cfg.bhi)
    for _, p in ipairs(sp) do if p[3] >= 0 then spike(p) end end
  end
end

-- HIV: see-through shell, tumbling cone capsid, sparse knobs
local hiv_knobs = fib(14, 1.3)
local function draw_hiv(cx, cy, a, pulse, flinch)
  local r = 15 * pulse
  local kn = {}
  for i, d in ipairs(hiv_knobs) do
    local x, y, z = rot(d[1], d[2], d[3], a, 0.2)
    kn[i] = { x, y, z }
  end
  table.sort(kn, by_z)
  local function knob(p)
    local L = r + 3 * flinch
    screen.level(dl(p[3], 3, 15))
    screen.move(cx + p[1] * r, cy + p[2] * r)
    screen.line(cx + p[1] * L, cy + p[2] * L)
    screen.stroke()
    screen.circle(cx + p[1] * L, cy + p[2] * L, 2 * flinch)
    screen.fill()
  end
  for _, p in ipairs(kn) do if p[3] < 0 then knob(p) end end
  -- shell
  screen.level(1); screen.circle(cx, cy, r); screen.fill()
  screen.level(3); screen.circle(cx, cy, r - 1.5); screen.stroke()
  screen.level(8); screen.circle(cx, cy, r); screen.stroke()
  -- cone capsid
  local N = 10
  local narrow, wide = {}, {}
  for i = 1, N do
    local ph = 2 * pi * i / N
    local x, y, z = rot(cos(ph) * 1.6, -9, sin(ph) * 1.6, a * 0.8, 0.5)
    narrow[i] = { cx + x * pulse, cy + y * pulse, z }
    x, y, z = rot(cos(ph) * 6, 9, sin(ph) * 6, a * 0.8, 0.5)
    wide[i] = { cx + x * pulse, cy + y * pulse, z }
  end
  for i = 1, N do
    local n, w = narrow[i], wide[i]
    screen.level(dl((n[3] + w[3]) / 12, 4, 12))
    screen.move(n[1], n[2]); screen.line(w[1], w[2]); screen.stroke()
  end
  for _, ring in ipairs({ narrow, wide }) do
    for i = 1, N do
      local p, q = ring[i], ring[i % N + 1]
      screen.level(dl((p[3] + q[3]) / 12, 5, 13))
      screen.move(p[1], p[2]); screen.line(q[1], q[2]); screen.stroke()
    end
  end
  for _, p in ipairs(kn) do if p[3] >= 0 then knob(p) end end
end

-- Ebola: a curling filament (shepherd's crook)
local EB = {}
do
  local n = 70
  for k = 0, n - 1 do
    local t = k / (n - 1)
    if t < 0.5 then
      local u = t / 0.5
      EB[#EB + 1] = { -6 + 4 * sin(u * 4.5), 20 - 30 * u, 4 * sin(u * 5) }
    else
      local u = (t - 0.5) / 0.5
      local ang = pi + u * 1.75 * pi
      EB[#EB + 1] = { 6 + 10 * cos(ang), -10 + 9.5 * sin(ang), 4 * sin(u * 4) }
    end
  end
end
local function draw_ebola(cx, cy, a, pulse, flinch)
  local pts = {}
  for i, p in ipairs(EB) do
    local x, y, z = rot(p[1], p[2], p[3], a, 0.25)
    pts[i] = { cx + x * pulse, cy + y * pulse, z, i }
  end
  table.sort(pts, by_z)
  local tr = 2.3 * pulse
  for _, p in ipairs(pts) do
    local l = dl(p[3] / 14, 3, 12)
    screen.level(l)
    screen.circle(p[1], p[2], tr); screen.fill()
    screen.level(math.min(15, l + 3))
    screen.circle(p[1] - 0.7, p[2] - 0.7, 0.9); screen.fill()
    if p[4] % 6 == 0 then -- little glycoprotein bumps
      screen.level(math.min(15, l + 2))
      screen.circle(p[1] + tr * flinch, p[2] - tr * 0.3, 0.8); screen.fill()
    end
  end
end

-- Tobacco mosaic virus: a hollow helical rod, bands marching along it
local function draw_tmv(cx, cy, a, pulse, flinch)
  local L, r, t = 22 * pulse, 5.2 * pulse, 0.55
  local ax, ay, az = rot(-sin(t), cos(t), 0, 0.6 * sin(a), 0.3)
  local sl = {}
  local s = -L
  while s <= L do
    sl[#sl + 1] = { cx + ax * s, cy + ay * s, az * s, s }
    s = s + 1.2
  end
  table.sort(sl, by_z)
  for _, p in ipairs(sl) do
    local band = sin(p[4] * 1.1 - a * 6)
    local l = band > 0.2 and 3 or 9
    l = l + floor(p[3] / L * 2 + 0.5)
    screen.level(math.max(1, math.min(15, l)))
    screen.circle(p[1], p[2], r); screen.fill()
  end
  if math.abs(az) > 0.2 then -- hollow end cap, if it's facing us
    local e = az > 0 and L or -L
    screen.level(7); screen.circle(cx + ax * e, cy + ay * e, r); screen.fill()
    screen.level(0); screen.circle(cx + ax * e, cy + ay * e, 1.6); screen.fill()
  end
end

V.list = {
  { id = "sars_cov_2", name = "SARS-COV-2", kind = "+SSRNA",
    sound = { scale = "Phrygian", short = "PHRYG", root = 45, division = 2, release = 0.6, cutoff = 1200, pw = 50 },
    draw = spiky { n = 34, r = 13, len = 7, tip = 1.6, lo = 3, hi = 15, blo = 1, bhi = 7, tilt = 0.35 } },
  { id = "influenza_a", name = "INFLUENZA A", kind = "-SSRNA", form = "sections",
    sound = { scale = "Dorian", short = "DOR", root = 50, division = 3, release = 0.35, cutoff = 1800, pw = 30 },
    draw = spiky { n = 110, r = 14, len = 4.5, tip = 0, lo = 2, hi = 13, blo = 1, bhi = 7, tilt = -0.3, seed = 0.7 } },
  { id = "hiv_1", name = "HIV-1", kind = "+SSRNA", draw = draw_hiv, form = "frames",
    sound = { scale = "Hungarian Minor", short = "HUNG", root = 38, division = 5, release = 1.2, cutoff = 600, pw = 70 } },
  { id = "ebola", name = "EBOLA", kind = "-SSRNA", draw = draw_ebola, form = "reverse",
    sound = { scale = "Locrian", short = "LOCR", root = 36, division = 1, release = 3.0, cutoff = 400, pw = 85 } },
  { id = "tmv", name = "TMV", kind = "+SSRNA", draw = draw_tmv,
    sound = { scale = "Major Pentatonic", short = "PENT", root = 60, division = 3, release = 0.15, cutoff = 3000, pw = 20 } },
}

-- the other 37 (drawings in batch1-5), each with its own scale + sound ------------
-- root = MIDI note, division = step (1 1/4, 2 1/8, 3 1/16, 4 1/32, 5 1/8T, 6 1/16T, 7 1/32T)
local P = {
  marburg        = { "Neapolitan Minor",      37, 2, 2.2,  500, 80, form = "reverse" },
  rabies         = { "Double Harmonic",       43, 6, 0.3, 2200, 35 },
  polio          = { "Major",                 60, 3, 0.25, 2500, 50 },
  adeno          = { "Six Tone Symmetrical",  48, 2, 0.7, 1500, 60 },
  mimi           = { "Overtone",              31, 1, 3.5,  700, 50 },
  sputnik        = { "Lydian",                72, 4, 0.1, 4000, 15 },
  t4             = { "Diminished Half Whole", 40, 3, 0.2, 1800, 25 },
  lambda         = { "Mixolydian",            52, 5, 0.6, 1400, 45 },
  t7             = { "Major Bebop",           55, 3, 0.15, 3000, 40 },
  phix174        = { "Whole Tone",            64, 6, 0.4, 2800, 55 },
  ms2            = { "Minor Pentatonic",      69, 4, 0.08, 4500, 30 },
  variola        = { "Persian",               34, 2, 2.5,  450, 75 },
  orf            = { "Eight Tone Spanish",    46, 5, 0.5, 1600, 65 },
  rotavirus_a    = { "Prometheus",            50, 3, 0.3, 2000, 50, form = "sections" },
  astrovirus     = { "Enigmatic",             62, 2, 1.2, 2600, 20 },
  norovirus      = { "Blues Scale",           41, 2, 0.45, 900, 60 },
  hsv1           = { "Natural Minor",         45, 1, 1.8,  800, 55 },
  measles        = { "Harmonic Minor",        47, 6, 0.5, 1300, 40 },
  zika           = { "Balinese",              57, 3, 0.9, 3200, 50 },
  chikungunya    = { "Mixolydian Bebop",      53, 5, 0.35, 2400, 30 },
  lassa          = { "Oriental",              39, 2, 1.5,  700, 70, form = "sections" },
  hantaan        = { "Gagaku Rittsu Sen Pou", 50, 1, 2.8, 1100, 50, form = "sections" },
  hepb           = { "Melodic Minor",         48, 4, 0.12, 3500, 35 },
  hepd           = { "Chromatic",             72, 6, 0.06, 4800, 10 },
  hpv16          = { "Harmonic Major",        55, 3, 0.5, 2000, 45 },
  pithovirus     = { "Altered Scale",         28, 1, 4.0,  300, 90 },
  pvy            = { "In Sen Pou",            58, 5, 1.0, 1700, 25 },
  baculovirus    = { "Dorian Bebop",          51, 3, 0.3, 2600, 60 },
  maize_streak   = { "Neapolitan Major",      65, 2, 0.4, 3000, 50 },
  alfalfa_mosaic = { "Okinawa",               60, 2, 0.7, 2200, 35, form = "sections" },
  ssv1           = { "Hungarian Major",       44, 6, 0.25, 4000, 15 },
  iridovirus6    = { "Leading Whole Tone",    67, 7, 1.5, 4500, 50 },
  torovirus      = { "Major Locrian",         42, 2, 1.1,  900, 70 },
  pandoravirus   = { "Lydian Minor",          29, 1, 3.8,  500, 85 },
  sirv2          = { "East Indian Purvi",     49, 3, 0.2, 3800, 20 },
  m13            = { "Diminished Whole Half", 63, 4, 0.1, 3300, 30 },
  -- the VIROID has no scale at all: every note, rhythm and tone is random
  pstvd          = { nil,                     48, 3, 0.4, 2000, 50, form = "chaos" },
}

for _, mod in ipairs({ "batch1", "batch2", "batch3", "batch4", "batch5" }) do
  local B = include("lib/" .. mod)
  for _, v in ipairs(B.list) do
    local p = assert(P[v.id], "no personality for " .. v.id)
    v.sound = { scale = p[1], root = p[2], division = p[3], release = p[4], cutoff = p[5], pw = p[6] }
    v.form = p.form
    v.dna = v.kind:find("DNA") ~= nil
    V.list[#V.list + 1] = v
  end
end

V.names = {}
for i, v in ipairs(V.list) do V.names[i] = v.name end

return V
