-- noiz virus :: specimens 6-13
-- draw(cx, cy, a, pulse, flinch): a = rotation, pulse = swell on a note, flinch = STOP recoil (<1)

local D = include and include("lib/draw3d") or dofile(NV_ROOT .. "lib/draw3d.lua")
local sin, cos, sqrt, floor, pi = D.sin, D.cos, D.sqrt, D.floor, D.pi
local rot, by_z = D.rot, D.by_z

local B = {}

-- 6 MARBURG: a filament closed into a tumbling ring ----------------------
local MB = {}
do
  local n = 60
  for k = 0, n - 1 do
    local t = 2 * pi * k / n
    local r = 16 + 1.2 * sin(3 * t)          -- slightly lumpy ring
    MB[#MB + 1] = { cos(t) * r, sin(t) * r * 0.92, 2.5 * sin(2 * t), k }
  end
end
function B.marburg(cx, cy, a, pulse, flinch)
  local pts = {}
  for i, p in ipairs(MB) do
    local x, y, z = rot(p[1], p[2], p[3], a * 0.7, 0.9 + 0.35 * sin(a * 0.5))
    pts[i] = { cx + x * pulse, cy + y * pulse, z, p[4] }
  end
  table.sort(pts, by_z)
  for _, p in ipairs(pts) do
    local l = D.dl(p[3] / 14, 3, 12)
    D.lvl(l); screen.circle(p[1], p[2], 2.7 * pulse); screen.fill()
    D.lvl(l + 3); screen.circle(p[1] - 0.7, p[2] - 0.7, 0.9); screen.fill()
    if p[4] % 5 == 0 then
      D.lvl(l + 2); screen.circle(p[1] + 2.4 * flinch, p[2] - 1, 0.8); screen.fill()
    end
  end
end

-- 7 RABIES: a bullet, coiled core bands, fuzzy glycoprotein coat ---------
function B.rabies(cx, cy, a, pulse, flinch)
  local L, r = 19 * pulse, 7.5 * pulse
  local tilt = 0.7 + 0.2 * sin(a * 0.6)
  local ax_, ay_, az_ = rot(-sin(tilt), cos(tilt), 0, 0.5 * sin(a * 0.8), 0.25)
  local sl = {}
  local s = -L
  while s <= L do
    local rr = r
    if s < -L + r then -- rounded nose
      local u = (s + L) / r
      rr = r * sqrt(D.clamp(1 - (1 - u) ^ 2, 0, 1))
    end
    sl[#sl + 1] = { cx + ax_ * s, cy + ay_ * s, az_ * s, s, rr }
    s = s + 1
  end
  -- perpendicular on screen, for the spike fringe
  local px, py = -ay_, ax_
  local pn = sqrt(px * px + py * py); px, py = px / pn, py / pn
  table.sort(sl, by_z)
  for _, p in ipairs(sl) do
    local band = sin(p[4] * 1.3 - a * 5)
    local l = (band > 0.3 and 4 or 10) + floor(p[3] / L * 2 + 0.5)
    D.lvl(l); screen.circle(p[1], p[2], p[5]); screen.fill()
    if floor(p[4]) % 2 == 0 then -- fringe of spikes on both silhouettes
      local f = p[5] + 2.2 * flinch
      D.lvl(8)
      screen.pixel(floor(p[1] + px * f), floor(p[2] + py * f)); screen.fill()
      screen.pixel(floor(p[1] - px * f), floor(p[2] - py * f)); screen.fill()
    end
  end
  -- flat back end, if it faces us
  local e = L
  if az_ > 0.15 then
    D.lvl(6); screen.circle(cx + ax_ * e, cy + ay_ * e, r); screen.fill()
    D.lvl(2); screen.circle(cx + ax_ * e, cy + ay_ * e, r * 0.45); screen.fill()
  end
end

-- 8 POLIO: a small, crisp, tumbling icosahedron ------------------------
function B.polio(cx, cy, a, pulse, flinch)
  local P = D.icosa(cx, cy, 15 * pulse, a, 0.4 + a * 0.37, { lo = 2, hi = 14, edge = 1 })
  -- little mesas on the 5-fold corners (front ones)
  for _, v in ipairs(P) do
    if v[3] > 0.2 then
      D.lvl(D.dl(v[3], 6, 15)); screen.circle(v[1], v[2], 1.2 * flinch + 0.3); screen.fill()
    end
  end
end

-- 9 ADENOVIRUS: faceted shell with capsomere grid + 12 knobbed fibres ---
function B.adeno(cx, cy, a, pulse, flinch)
  local R = 12.5 * pulse
  local ay, ax = a * 0.8, 0.5
  local fib = {}
  for i, v in ipairs(D.ICO_V) do
    local x, y, z = rot(v[1], v[2], v[3], ay, ax)
    fib[i] = { x, y, z }
  end
  table.sort(fib, by_z)
  local function fibre(f)
    local len = R + 10 * flinch * pulse
    local l = D.dl(f[3], 3, 13)
    D.seg(cx + f[1] * R, cy + f[2] * R, cx + f[1] * len, cy + f[2] * len, l)
    D.lvl(l + 1); screen.circle(cx + f[1] * len, cy + f[2] * len, 1.8); screen.fill()
  end
  for _, f in ipairs(fib) do if f[3] < 0 then fibre(f) end end
  D.icosa(cx, cy, R, ay, ax, { lo = 3, hi = 13, edge = 1, grid = 2 })
  for _, f in ipairs(fib) do if f[3] >= 0 then fibre(f) end end
end

-- 10 MIMIVIRUS: a giant in a fuzzy halo, with its star-gate ----------------
local MIMI_HAIR = D.fib(220, 0.3)
function B.mimi(cx, cy, a, pulse, flinch)
  local R = 15 * pulse
  local ay, ax = a * 0.35, 0.3
  local hair = {}
  for i, h in ipairs(MIMI_HAIR) do
    local x, y, z = rot(h[1], h[2], h[3], ay, ax)
    hair[i] = { x, y, z }
  end
  local H = R + 5 * flinch
  for _, h in ipairs(hair) do
    if h[3] < 0.15 then
      D.seg(cx + h[1] * R * 0.95, cy + h[2] * R * 0.95, cx + h[1] * H, cy + h[2] * H, D.dl(h[3], 2, 7))
    end
  end
  local P = D.icosa(cx, cy, R, ay, ax, { lo = 2, hi = 9, edge = 3 })
  -- star-gate: a five-armed starfish on one corner
  local v = P[1]
  if v[3] > 0 then
    local nb = {}
    for _, f in ipairs(D.ICO_F) do
      for k = 1, 3 do
        if f[k] == 1 then
          for m = 1, 3 do if f[m] ~= 1 then nb[f[m]] = true end end
        end
      end
    end
    local l = D.dl(v[3], 9, 15)
    for idx in pairs(nb) do
      local w = P[idx]
      local ex, ey = v[1] + (w[1] - v[1]) * 0.85, v[2] + (w[2] - v[2]) * 0.85
      local px, py = -(ey - v[2]) * 0.18, (ex - v[1]) * 0.18
      D.poly({ { v[1] + px, v[2] + py }, { ex, ey }, { v[1] - px, v[2] - py } }, l)
    end
  end
  -- front fuzz over the shell
  for _, h in ipairs(hair) do
    if h[3] >= 0.15 then
      local x, y = cx + h[1] * (R + 1), cy + h[2] * (R + 1)
      D.lvl(D.dl(h[3], 4, 9)); screen.pixel(floor(x), floor(y)); screen.fill()
    end
  end
end

-- 11 SPUTNIK: tiny virophages clinging to a giant's curved wall ------------
local WALL_HAIR = {}
for k = 0, 40 do WALL_HAIR[#WALL_HAIR + 1] = -1.0 + k * 0.05 end
function B.sputnik(cx, cy, a, pulse, flinch)
  -- the giant's wall: a huge circle off to the left
  local wx, wy, wr = cx - 62, cy, 58
  D.lvl(2); screen.circle(wx, wy, wr); screen.fill()
  D.lvl(5); screen.circle(wx, wy, wr); screen.stroke()
  for _, t in ipairs(WALL_HAIR) do
    local x1, y1 = wx + cos(t) * wr, wy + sin(t) * wr
    local x2, y2 = wx + cos(t) * (wr + 3), wy + sin(t) * (wr + 3)
    D.seg(x1, y1, x2, y2, 4)
  end
  -- three virophages, bobbing, the big one front and centre
  local sp = {
    { 8, 0, 7.5, 1.0 }, { 2, -15, 4, 1.7 }, { 4, 15, 4.5, 2.6 },
  }
  for i = #sp, 1, -1 do
    local s = sp[i]
    local bob = sin(a * 2 + s[4]) * 1.5
    local x = wx + wr + 3 + s[3] + s[1] * 0.2 + bob * flinch
    local y = cy + s[2]
    D.icosa(x, y, s[3] * pulse, a * (1 + 0.3 * i) + s[4], 0.5 + s[4], { lo = 3, hi = 14, edge = 1 })
  end
end

-- 12 T4: the lunar lander. on STOP the tail sheath contracts ---------------
function B.t4(cx, cy, a, pulse, flinch)
  local ay, tilt = a * 0.6, 0.18
  local function P(x, y, z)
    local X, Y, Z = rot(x, y, z, ay, tilt)
    return cx + X, cy + Y, Z
  end
  local top = -22
  local tail = 15 * (0.55 + 0.45 * flinch)
  local base = top + 18 + 3 + tail
  -- legs behind
  local legs = {}
  for k = 0, 5 do
    local t = k * pi / 3 + 0.3
    local kx, kz = cos(t), sin(t)
    local x1, y1, z1 = P(kx * 4, base, kz * 4)
    local x2, y2, z2 = P(kx * 15, base - 6 + (1 - flinch) * 4, kz * 15)
    local x3, y3, z3 = P(kx * 19, base + 9, kz * 19)
    legs[#legs + 1] = { x1, y1, z1, x2, y2, z2, x3, y3, z3 }
  end
  local function leg(g)
    D.seg(g[1], g[2], g[4], g[5], D.dl(g[6] / 15, 4, 13))
    D.seg(g[4], g[5], g[7], g[8], D.dl(g[9] / 19, 4, 13))
  end
  for _, g in ipairs(legs) do if g[6] < 0 then leg(g) end end
  -- tail sheath: rings
  local y = top + 18 + 3
  while y <= base do
    local x1 = P(-2.6, y, 0)
    local x2 = P(2.6, y, 0)
    local _, yy = P(0, y, 0)
    D.seg(x1, yy, x2, yy, (floor(y) % 2 == 0) and 11 or 6)
    y = y + 1
  end
  -- baseplate
  local bx, by = P(0, base, 0)
  D.lvl(10); screen.rect(bx - 5, by - 1, 10, 2); screen.fill()
  -- collar
  local kx, ky = P(0, top + 19, 0)
  D.lvl(8); screen.rect(kx - 4, ky - 1, 8, 2); screen.fill()
  -- head: a stretched icosahedron
  D.icosa(cx, cy + top + 9, 7.5 * pulse, ay, tilt, { lo = 3, hi = 14, edge = 1, sy = 1.35 })
  for _, g in ipairs(legs) do if g[6] >= 0 then leg(g) end end
end

-- 13 LAMBDA: round head, long flexible waving tail -------------------------
function B.lambda(cx, cy, a, pulse, flinch)
  local hx, hy = cx - 8, cy - 12
  -- tail first (behind the head)
  local n = 26
  local px, py = hx, hy
  for k = 1, n do
    local t = k / n
    local wave = sin(t * 5 - a * 3) * 7 * t * flinch
    local x = hx + t * 22 + wave * 0.5
    local y = hy + 6 + t * 30 + wave
    D.seg(px, py, x, y, 9)
    if k % 2 == 0 then D.lvl(13); screen.circle(x, y, 1.3); screen.fill() end
    px, py = x, y
  end
  -- tip fibre
  D.seg(px, py, px + 3, py + 4, 6)
  D.icosa(hx, hy, 10 * pulse, a, 0.45, { lo = 3, hi = 14, edge = 1 })
end

B.list = {
  { id = "marburg", name = "MARBURG", kind = "-SSRNA", draw = B.marburg },
  { id = "rabies", name = "RABIES", kind = "-SSRNA", draw = B.rabies },
  { id = "polio", name = "POLIO", kind = "+SSRNA", draw = B.polio },
  { id = "adeno", name = "ADENOVIRUS", kind = "DSDNA", draw = B.adeno },
  { id = "mimi", name = "MIMIVIRUS", kind = "DSDNA", draw = B.mimi },
  { id = "sputnik", name = "SPUTNIK", kind = "DSDNA", draw = B.sputnik },
  { id = "t4", name = "PHAGE T4", kind = "DSDNA", draw = B.t4 },
  { id = "lambda", name = "LAMBDA", kind = "DSDNA", draw = B.lambda },
}

return B
