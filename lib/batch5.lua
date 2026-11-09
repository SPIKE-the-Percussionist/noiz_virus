-- noiz virus :: specimens 38-42

local D = include and include("lib/draw3d") or dofile(NV_ROOT .. "lib/draw3d.lua")
local sin, cos, sqrt, floor, pi = D.sin, D.cos, D.sqrt, D.floor, D.pi
local rot, by_z = D.rot, D.by_z

local B = {}

local function rng(seed)
  local s = seed
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

-- draw a polyline through pts {x, y, ...} at level l (or l(i) if a function)
local function path(pts, l)
  for i = 2, #pts do
    local p, q = pts[i - 1], pts[i]
    D.seg(p[1], p[2], q[1], q[2], type(l) == "function" and l(i) or l)
  end
end

-- 38 TOROVIRUS: a spiky, bent kidney that closes into a donut on STOP -------
function B.toro(cx, cy, a, pulse, flinch)
  local Rm, r = 13 * pulse, 4 * pulse
  local gap = 0.9 * flinch
  local ay, ax = 0.6 * sin(a * 0.7), 0.5 + 0.2 * sin(a * 0.5)
  local spin = a * 0.6
  local beads = {}
  local N = 40
  for k = 0, N do
    local t = gap + (2 * pi - 2 * gap) * k / N + spin
    local x, y, z = rot(cos(t) * Rm, sin(t) * Rm, 0, ay, ax)
    local ox, oy, oz = rot(cos(t), sin(t), 0, ay, ax)
    beads[#beads + 1] = { x, y, z, ox, oy, oz, k }
  end
  table.sort(beads, by_z)
  for _, b in ipairs(beads) do
    local x, y, z = cx + b[1], cy + b[2], b[3]
    -- spikes on the outer rim
    D.lvl(D.dl(z / Rm, 3, 11)); screen.circle(x, y, r); screen.fill()
    D.lvl(D.dl(z / Rm, 5, 15)); screen.circle(x - r * 0.3, y - r * 0.35, r * 0.4); screen.fill()
  end
  -- spikes, on top: outer rim plus the ones standing up toward us
  for _, b in ipairs(beads) do
    if b[7] % 2 == 0 and b[3] > -Rm * 0.3 then
      local x, y = cx + b[1], cy + b[2]
      local sx, sy = x + b[4] * (r + 4.5), y + b[5] * (r + 4.5)
      D.seg(x + b[4] * (r - 0.5), y + b[5] * (r - 0.5), sx, sy, D.dl(b[3] / Rm, 7, 13))
      D.lvl(D.dl(b[3] / Rm, 9, 15)); screen.circle(sx, sy, 1); screen.fill()
    end
  end
end

-- 39 PANDORAVIRUS: a big ovoid with thick layered walls and an open pore ----
local SPECK = {}
do
  local r = rng(39)
  while #SPECK < 90 do
    local x, y = r() * 2 - 1, r() * 2 - 1
    if x * x + y * y < 0.75 then SPECK[#SPECK + 1] = { x, y, r() } end
  end
end
function B.pandora(cx, cy, a, pulse, flinch)
  local rx, ry = 13 * pulse, 20 * pulse
  local th = 0.3 * sin(a * 0.5)
  local c, s = cos(th), sin(th)
  local oy = cy + 3
  local function P(x, y) return cx + x * c - y * s, oy + x * s + y * c end
  local pore = 0.32 + 0.25 * (1 - flinch) -- half-angle of the opening at the top
  local function wall(k, l)
    local pts = {}
    for m = 0, 40 do
      local t = -pi / 2 + pore + (2 * pi - 2 * pore) * m / 40
      local w = 1 - k * 0.13
      pts[#pts + 1] = { P(cos(t) * rx * w, sin(t) * ry * w) }
    end
    return pts
  end
  -- body
  local body = wall(0)
  D.poly(body, 2)
  -- the genome: a speckled interior that churns slowly
  for i, g in ipairs(SPECK) do
    local x = g[1] * rx * 0.62 + sin(a + i) * 0.8
    local y = g[2] * ry * 0.62 + cos(a * 1.3 + i * 0.7) * 0.8
    local px, py = P(x, y)
    D.lvl(4 + floor(g[3] * 5)); screen.rect(floor(px), floor(py), 1, 1); screen.fill()
  end
  -- three wall layers
  path(wall(0), 13)
  path(wall(1), 9)
  path(wall(2), 5)
  -- the pore's lips
  for _, sg in ipairs({ -1, 1 }) do
    local t = -pi / 2 + sg * pore
    local x1, y1 = P(cos(t) * rx, sin(t) * ry)
    local x2, y2 = P(cos(t) * rx * 0.74, sin(t) * ry * 0.74)
    D.seg(x1, y1, x2, y2, 14)
  end
end

-- 40 SIRV2: a stiff rod with fibre tufts at both ends ----------------------
function B.sirv2(cx, cy, a, pulse, flinch)
  local L = 18 * pulse
  local th = 0.5 + 0.35 * sin(a * 0.5)
  local tilt = 0.75 + 0.25 * cos(a * 0.8) -- foreshortening as it turns
  local ux, uy = cos(th) * tilt, sin(th)
  local nx, ny = -sin(th), cos(th)
  local wd = 3.2
  local function P(u, v) return cx + ux * u * L + nx * v, cy + uy * u * L + ny * v end
  -- tufts
  for _, e in ipairs({ -1, 1 }) do
    local ex, ey = P(e, 0)
    for k = -1, 1 do
      local px, py = ex, ey
      for m = 1, 4 do
        local u = e * (1 + m * 0.08)
        local v = k * m * (1.2 + 1.3 * (1 - flinch)) + sin(a * 3 + m + k * 2) * 0.8
        local x, y = P(u, v)
        D.seg(px, py, x, y, 13 - m * 2)
        px, py = x, y
      end
    end
  end
  -- the rod
  D.poly({ { P(-1, -wd) }, { P(1, -wd) }, { P(1, wd) }, { P(-1, wd) } }, 8)
  local x1, y1 = P(-1, -wd + 0.6); local x2, y2 = P(1, -wd + 0.6)
  D.seg(x1, y1, x2, y2, 13)
  -- helical banding, travelling along the rod
  for k = 0, 21 do
    local u = -1 + ((k + a * 1.5) % 22) / 11
    local bx1, by1 = P(u, -wd); local bx2, by2 = P(u + 0.06, wd)
    D.seg(bx1, by1, bx2, by2, 3)
  end
end

-- 41 PHAGE M13: a very long, thin, whipping fibre ---------------------------
function B.m13(cx, cy, a, pulse, flinch)
  local pts = {}
  local N = 90
  for k = 0, N do
    local t = k / N
    -- a long loop that doubles back across the space
    local x = cx + 24 * sin(t * pi * 1.6 + 0.3) * cos(t * 0.9)
    local y = cy - 20 + 42 * t
    -- a whip wave travelling along it
    local amp = (1.5 + 3.5 * t) * (0.4 + 0.6 * flinch)
    x = x + amp * sin(t * 14 - a * 3)
    y = y + amp * 0.5 * cos(t * 11 - a * 2.5) * pulse
    pts[#pts + 1] = { x, y }
  end
  path(pts, function(i) return 6 + floor(7 * (1 - i / #pts) + 0.5) end)
  -- the business end: the pIII knob
  local p = pts[1]
  D.lvl(15); screen.circle(p[1], p[2], 1.8 * pulse); screen.fill()
  local q = pts[#pts]
  D.lvl(6); screen.circle(q[1], q[2], 1); screen.fill()
end

-- the dotted outline of the shell it doesn't have; on STOP it flickers brighter,
-- as if it were trying to form
local function ghost(cx, cy, R, a, flinch)
  local boost = floor(5 * (1 - flinch) + 0.5)
  local P = {}
  for i, v in ipairs(D.ICO_V) do
    local x, y, z = rot(v[1], v[2], v[3], a * 0.4, 0.4)
    P[i] = { cx + x * R, cy + y * R, z }
  end
  local seen = {}
  for _, f in ipairs(D.ICO_F) do
    for k = 1, 3 do
      local i, j = f[k], f[k % 3 + 1]
      local key = math.min(i, j) * 100 + math.max(i, j)
      if not seen[key] then
        seen[key] = true
        local p, q = P[i], P[j]
        local n = floor(sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2) / 3)
        D.lvl(D.dl((p[3] + q[3]) / 2, 1, 4) + boost)
        for m = 0, n do
          local t = m / math.max(n, 1)
          screen.rect(floor(p[1] + (q[1] - p[1]) * t), floor(p[2] + (q[2] - p[2]) * t), 1, 1)
          screen.fill()
        end
      end
    end
  end
end

-- the sigil: hard zigzag, double strand, a loop at every turn; twitches on the beat
-- w: half-width, h: zigzag height, n: number of points
local function sigil(cx, cy, a, pulse, flinch, w, h, n)
  local pts = {}
  local beat = floor(a / (2 * pi) * 6)
  for i = 1, n do
    local x = -w + 2 * w * (i - 1) / (n - 1)
    local amp = h * ((i % 2 == 0) and 1 or -1) * (0.6 + 0.4 * sin(beat * 1.7 + i * 2.1))
    pts[i] = { cx + x * pulse, cy + amp * pulse }
  end
  for o = -1, 1, 2 do
    local side = {}
    for i, p in ipairs(pts) do side[i] = { p[1], p[2] + o * 1.3 } end
    path(side, o < 0 and 15 or 9)
  end
  for i = 2, #pts - 1 do
    local p = pts[i]
    local r = 2.2 * flinch + 0.4
    local dir = (p[2] < cy) and -1 or 1
    D.lvl(14); screen.circle(p[1], p[2] + dir * (r + 1.3), r); screen.stroke()
  end
  for _, i in ipairs({ 1, #pts }) do
    D.lvl(15); screen.circle(pts[i][1] + (i == 1 and -2.2 or 2.2), pts[i][2], 1.9); screen.stroke()
  end
end

-- 42 PSTVd VIROID: bare RNA, a sigil held inside the ghost of a shell it doesn't have
function B.viroid(cx, cy, a, pulse, flinch)
  ghost(cx, cy, 23, a, flinch)
  sigil(cx, cy, a, pulse, flinch, 14, 6.5, 6)
end

B.list = {
  { id = "torovirus", name = "TOROVIRUS", kind = "+SSRNA", draw = B.toro },
  { id = "pandoravirus", name = "PANDORAVIRUS", kind = "DSDNA", draw = B.pandora },
  { id = "sirv2", name = "SIRV2", kind = "DSDNA", draw = B.sirv2 },
  { id = "m13", name = "PHAGE M13", kind = "SSDNA", draw = B.m13 },
  { id = "pstvd", name = "VIROID", kind = "CIRC RNA", draw = B.viroid },
}

return B
