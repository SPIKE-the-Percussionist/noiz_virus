-- noiz virus :: specimens 22-29

local D = include and include("lib/draw3d") or dofile(NV_ROOT .. "lib/draw3d.lua")
local sin, cos, sqrt, floor, pi = D.sin, D.cos, D.sqrt, D.floor, D.pi
local rot, by_z = D.rot, D.by_z

local B = {}

-- tangent frame for a unit vector
local function frame(p)
  local ux, uy, uz = 0, 1, 0
  if math.abs(p[2]) > 0.9 then ux, uy, uz = 1, 0, 0 end
  local e1 = { uy * p[3] - uz * p[2], uz * p[1] - ux * p[3], ux * p[2] - uy * p[1] }
  local n = sqrt(e1[1] ^ 2 + e1[2] ^ 2 + e1[3] ^ 2)
  e1 = { e1[1] / n, e1[2] / n, e1[3] / n }
  local e2 = { p[2] * e1[3] - p[3] * e1[2], p[3] * e1[1] - p[1] * e1[3], p[1] * e1[2] - p[2] * e1[1] }
  return e1, e2
end

-- deterministic little random
local function rng(seed)
  local s = seed
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

-- 22 HERPES: an icosahedral yolk in a fried-egg envelope ------------------
function B.herpes(cx, cy, a, pulse, flinch)
  local R = 19 * pulse * (0.9 + 0.1 * flinch)
  local pts = {}
  for k = 0, 39 do
    local t = k * 2 * pi / 40
    local r = R * (1 + 0.07 * sin(3 * t + a) + 0.05 * sin(5 * t - a * 2))
    pts[#pts + 1] = { cx + cos(t) * r, cy + sin(t) * r * 0.9 }
  end
  -- glycoprotein spikes poking out of the white
  for k = 1, #pts, 2 do
    local p = pts[k]
    local dx, dy = p[1] - cx, p[2] - cy
    local n = sqrt(dx * dx + dy * dy)
    D.seg(p[1], p[2], p[1] + dx / n * 2.5, p[2] + dy / n * 2.5, 7)
  end
  D.poly(pts, 3, 8)
  -- tegument, then the capsid sitting a little off centre like a yolk
  local yx, yy = cx + 2.5 * sin(a), cy + 1.5 * cos(a * 0.7)
  D.lvl(5); screen.circle(yx, yy, R * 0.7); screen.fill()
  D.icosa(yx, yy, R * 0.56, a * 0.7, 0.4, { lo = 5, hi = 15, edge = 2, grid = 3 })
end

-- 23 MEASLES: a lumpy, shapeless blob with a fringe and a tangled coil inside
function B.measles(cx, cy, a, pulse, flinch)
  local R = 16 * pulse
  local function rr(t)
    return 1 + 0.14 * sin(2 * t + a) + 0.09 * sin(3 * t - a * 1.5 + 1) + 0.05 * sin(5 * t + a * 2.3)
  end
  -- fringe of short spikes
  for k = 0, 63 do
    local t = k * 2 * pi / 64
    local r = R * rr(t)
    local h = 2.8 * flinch
    D.seg(cx + cos(t) * r, cy + sin(t) * r, cx + cos(t) * (r + h), cy + sin(t) * (r + h), (k % 2 == 0) and 9 or 6)
  end
  -- body: shrinking blobs toward the light
  for layer = 0, 4 do
    local f = layer / 5
    local s = R * (1 - 0.75 * f)
    local ox, oy = -R * 0.3 * f, -R * 0.35 * f
    local pts = {}
    for k = 0, 31 do
      local t = k * 2 * pi / 32
      local r = s * rr(t)
      pts[#pts + 1] = { cx + ox + cos(t) * r, cy + oy + sin(t) * r }
    end
    D.poly(pts, 2 + layer * 1.6)
  end
  -- coiled herringbone nucleocapsid, tangled through the middle
  local px, py
  for m = 0, 44 do
    local t = m / 44 * 2 * pi
    local x = cx + R * 0.55 * sin(t * 2 + a * 0.5) * cos(t * 0.5)
    local y = cy + R * 0.45 * sin(t * 1.5 + 0.8) + R * 0.1 * sin(a + t * 3)
    if px then
      D.seg(px, py, x, y, 13)
      if m % 2 == 0 then
        local dx, dy = x - px, y - py
        local n = sqrt(dx * dx + dy * dy) + 0.001
        D.seg(x - dy / n * 1.5, y + dx / n * 1.5, x + dy / n * 1.5, y - dx / n * 1.5, 10)
      end
    end
    px, py = x, y
  end
end

-- 24 ZIKA: a smooth golf ball, grooved in herringbone rafts ---------------
local RAFT = D.fib(30, 0.2)
local RAFT_F = {}
for i, p in ipairs(RAFT) do
  local e1, e2 = frame(p)
  local th = (i % 2 == 0) and pi / 3 or -pi / 3
  local dv = { cos(th) * e1[1] + sin(th) * e2[1], cos(th) * e1[2] + sin(th) * e2[2], cos(th) * e1[3] + sin(th) * e2[3] }
  local pv = { -sin(th) * e1[1] + cos(th) * e2[1], -sin(th) * e1[2] + cos(th) * e2[2], -sin(th) * e1[3] + cos(th) * e2[3] }
  RAFT_F[i] = { p, dv, pv }
end
function B.zika(cx, cy, a, pulse, flinch)
  local R = 15 * pulse * (0.94 + 0.06 * flinch)
  local ay, ax = a * 0.6, 0.3
  D.ball(cx, cy, R, 3, 14)
  for _, f in ipairs(RAFT_F) do
    local p, dv, pv = f[1], f[2], f[3]
    local _, _, pz = rot(p[1], p[2], p[3], ay, ax)
    if pz > 0.15 then
      local px, py = rot(p[1], p[2], p[3], ay, ax)
      local l = D.shade(px, py, pz, 3, 14) - 8
      for o = -1, 1 do
        local q1, q2 = {}, {}
        for k = 1, 3 do
          q1[k] = p[k] + pv[k] * o * 0.11 - dv[k] * 0.2
          q2[k] = p[k] + pv[k] * o * 0.11 + dv[k] * 0.2
        end
        local x1, y1 = rot(q1[1], q1[2], q1[3], ay, ax)
        local x2, y2 = rot(q2[1], q2[2], q2[3], ay, ax)
        D.seg(cx + x1 * R, cy + y1 * R, cx + x2 * R, cy + y2 * R, l)
      end
    end
  end
end

-- 25 CHIKUNGUNYA: a ball studded with triangular spike trimers -----------
local TRI = D.fib(42, 1.1)
local TRI_F = {}
for i, p in ipairs(TRI) do
  local e1, e2 = frame(p)
  TRI_F[i] = { p, e1, e2 }
end
function B.chik(cx, cy, a, pulse, flinch)
  local R = 12.5 * pulse
  local ay, ax = a * 0.5, 0.35 + 0.15 * sin(a)
  D.ball(cx, cy, R, 2, 8)
  local list = {}
  for _, f in ipairs(TRI_F) do
    local p, e1, e2 = f[1], f[2], f[3]
    local _, _, z = rot(p[1], p[2], p[3], ay, ax)
    if z > -0.25 then
      local h = 1 + 0.32 * flinch
      local tri = {}
      for k = 0, 2 do
        local t = k * 2 * pi / 3 + 0.3
        local q = {}
        for j = 1, 3 do q[j] = p[j] * h + (cos(t) * e1[j] + sin(t) * e2[j]) * 0.17 end
        local x, y = rot(q[1], q[2], q[3], ay, ax)
        tri[#tri + 1] = { cx + x * R, cy + y * R }
      end
      list[#list + 1] = { tri, z }
    end
  end
  table.sort(list, function(p, q) return p[2] < q[2] end)
  for _, t in ipairs(list) do
    D.poly(t[1], D.dl(t[2], 4, 13), D.dl(t[2], 6, 15))
  end
end

-- 26 LASSA: a round shell full of grainy "sand" (ribosomes) ----------------
local SAND = {}
do
  local r = rng(26)
  while #SAND < 70 do
    local x, y = r() * 2 - 1, r() * 2 - 1
    if x * x + y * y < 0.8 then SAND[#SAND + 1] = { x, y, floor(r() * 4) } end
  end
end
function B.lassa(cx, cy, a, pulse, flinch)
  local R = 17 * pulse
  -- club spikes
  for k = 0, 27 do
    local t = k * 2 * pi / 28 + a * 0.1
    local x1, y1 = cx + cos(t) * R, cy + sin(t) * R
    local x2, y2 = cx + cos(t) * (R + 2.5), cy + sin(t) * (R + 2.5)
    D.seg(x1, y1, x2, y2, 6)
    D.lvl(9); screen.circle(x2, y2, 0.9); screen.fill()
  end
  D.lvl(2); screen.circle(cx, cy, R); screen.fill()
  D.lvl(11); screen.circle(cx, cy, R); screen.stroke()
  D.lvl(6); screen.circle(cx, cy, R - 1.2); screen.stroke()
  -- the two looped segments (L and S)
  for s = 0, 1 do
    local rx, ry = R * (0.5 - 0.15 * s), R * (0.32 + 0.1 * s)
    local ph = a * (s == 0 and 0.7 or -0.9) + s
    local px, py
    for m = 0, 24 do
      local t = m * 2 * pi / 24
      local x = cos(t) * rx
      local y = sin(t) * ry
      local X = cx + x * cos(ph) - y * sin(ph)
      local Y = cy + x * sin(ph) + y * cos(ph)
      if px then D.seg(px, py, X, Y, 7 + s * 2) end
      px, py = X, Y
    end
  end
  -- sand, jostling (pulls together on STOP)
  local sc = (0.8 + 0.2 * flinch) * R
  for i, g in ipairs(SAND) do
    local x = cx + (g[1] + 0.05 * sin(a * 3 + i * 1.7)) * sc
    local y = cy + (g[2] + 0.05 * cos(a * 2.6 + i * 2.3)) * sc
    D.lvl(8 + g[3] * 2); screen.rect(floor(x), floor(y), 1, 1); screen.fill()
  end
end

-- 27 HANTAAN: a ball wrapped in a square grid ------------------------------
local GRID, KNOBS = {}, {}
do
  local N, M = 2, 8
  local function cube(axis, sg, u, v)
    local c = { 0, 0, 0 }
    local ua = axis % 3 + 1
    local va = ua % 3 + 1
    c[axis] = sg; c[ua] = u; c[va] = v
    local n = sqrt(c[1] ^ 2 + c[2] ^ 2 + c[3] ^ 2)
    return { c[1] / n, c[2] / n, c[3] / n }
  end
  for axis = 1, 3 do
    for _, sg in ipairs({ -1, 1 }) do
      for i = -N, N do
        local l1, l2 = {}, {}
        for m = 0, M do
          local s = -1 + 2 * m / M
          l1[#l1 + 1] = cube(axis, sg, i / N, s)
          l2[#l2 + 1] = cube(axis, sg, s, i / N)
        end
        GRID[#GRID + 1] = l1; GRID[#GRID + 1] = l2
        for j = -N + 1, N - 1 do
          if i > -N and i < N then KNOBS[#KNOBS + 1] = cube(axis, sg, i / N, j / N) end
        end
      end
    end
  end
end
function B.hantaan(cx, cy, a, pulse, flinch)
  local R = 15 * pulse
  local ay, ax = a * 0.5 + 0.4, 0.5 + 0.2 * sin(a * 0.5)
  D.ball(cx, cy, R, 2, 8)
  for _, line in ipairs(GRID) do
    local px, py, pz
    for _, p in ipairs(line) do
      local x, y, z = rot(p[1], p[2], p[3], ay, ax)
      if px and z > 0 and pz > 0 then
        D.seg(cx + px * R, cy + py * R, cx + x * R, cy + y * R, D.shade(x, y, z, 6, 14))
      end
      px, py, pz = x, y, z
    end
  end
  local kr = R * (1 + 0.1 * (1 - flinch))
  for _, p in ipairs(KNOBS) do
    local x, y, z = rot(p[1], p[2], p[3], ay, ax)
    if z > 0.1 then
      D.lvl(D.shade(x, y, z, 8, 15)); screen.rect(floor(cx + x * kr), floor(cy + y * kr), 1, 1); screen.fill()
    end
  end
end

-- 28 HEPATITIS B: a double-shelled sphere in a swarm of decoy rods and dots --
local DECOY = {}
do
  local r = rng(28)
  for i = 1, 24 do
    DECOY[i] = {
      d = 0.85 + r() * 0.45, inc = (i / 24) * pi + (r() - 0.5) * 0.4, ph = r() * 2 * pi,
      sp = 0.6 + r() * 0.9, rod = (i % 3 ~= 0), len = 4 + r() * 5, tw = r() * pi,
    }
  end
end
function B.hepb(cx, cy, a, pulse, flinch)
  local R = 10 * pulse
  local D0 = 20 * (0.75 + 0.25 * flinch)
  local items = {}
  for _, o in ipairs(DECOY) do
    local t = o.ph + a * o.sp
    local x, y, z = cos(t) * o.d * D0, 0, sin(t) * o.d * D0
    x, y, z = D.rotz(x, y, z, o.inc)
    y = y * 0.8
    items[#items + 1] = { o, x, y, z }
  end
  local function draw(it)
    local o, x, y, z = it[1], it[2], it[3], it[4]
    local l = D.dl(z / 22, 3, 13)
    if o.rod then
      local t = o.tw + a * 0.5
      local dx, dy = cos(t) * o.len / 2, sin(t) * o.len / 2
      D.seg(cx + x - dx, cy + y - dy, cx + x + dx, cy + y + dy, l)
      D.seg(cx + x - dx + 0.8, cy + y - dy + 0.8, cx + x + dx + 0.8, cy + y + dy + 0.8, l - 2)
    else
      D.lvl(l); screen.circle(cx + x, cy + y, 1.6); screen.fill()
    end
  end
  for _, it in ipairs(items) do if it[4] < 0 then draw(it) end end
  -- the real particle: envelope, then the core showing through
  D.lvl(3); screen.circle(cx, cy, R); screen.fill()
  D.icosa(cx, cy, R * 0.66, a * 0.9, 0.3, { lo = 4, hi = 13, edge = 2 })
  D.lvl(12); screen.circle(cx, cy, R); screen.stroke()
  for k = 0, 17 do
    local t = k * 2 * pi / 18 + a * 0.2
    D.lvl(9); screen.circle(cx + cos(t) * (R + 1.2), cy + sin(t) * (R + 1.2), 0.8); screen.fill()
  end
  for _, it in ipairs(items) do if it[4] >= 0 then draw(it) end end
end

-- 29 HEPATITIS DELTA: a tiny pulsing particle around a ring of RNA ---------
-- on STOP the ring zips itself up into a rod (as the real RNA does)
function B.hepd(cx, cy, a, pulse, flinch)
  local s = 1 + (pulse - 1) * 3 + 0.05 * sin(a * 4)
  local R = 8 * s
  -- echo rings: the pulse spreading out
  for k = 0, 2 do
    local ph = ((a / (2 * pi)) * 3 + k / 3) % 1
    D.lvl(floor(4 * (1 - ph) + 0.5)); screen.circle(cx, cy, R + 3 + ph * 14); screen.stroke()
  end
  -- borrowed hep B coat
  D.lvl(4); screen.circle(cx, cy, R); screen.fill()
  for k = 0, 11 do
    local t = k * 2 * pi / 12 - a * 0.3
    D.lvl(10); screen.circle(cx + cos(t) * (R + 1), cy + sin(t) * (R + 1), 0.8); screen.fill()
  end
  -- the circular RNA: a bead ring tumbling in 3d
  local rr = R * 0.62
  local beads = {}
  for k = 0, 15 do
    local t = k * 2 * pi / 16
    local x, y, z = cos(t) * rr, sin(t) * rr * flinch, 0
    x, y, z = rot(x, y, z, a * 0.8, 0.9 + 0.3 * sin(a))
    beads[#beads + 1] = { x, y, z }
  end
  for k = 1, #beads do
    local p, q = beads[k], beads[k % #beads + 1]
    D.seg(cx + p[1], cy + p[2], cx + q[1], cy + q[2], D.dl(p[3] / rr, 7, 13))
  end
  table.sort(beads, by_z)
  for _, b in ipairs(beads) do
    D.lvl(D.dl(b[3] / rr, 8, 15)); screen.circle(cx + b[1], cy + b[2], 0.9); screen.fill()
  end
end

B.list = {
  { id = "hsv1", name = "HERPES 1", kind = "DSDNA", draw = B.herpes },
  { id = "measles", name = "MEASLES", kind = "-SSRNA", draw = B.measles },
  { id = "zika", name = "ZIKA", kind = "+SSRNA", draw = B.zika },
  { id = "chikungunya", name = "CHIKUNGUNYA", kind = "+SSRNA", draw = B.chik },
  { id = "lassa", name = "LASSA", kind = "-SSRNA", draw = B.lassa },
  { id = "hantaan", name = "HANTAAN", kind = "-SSRNA", draw = B.hantaan },
  { id = "hepb", name = "HEPATITIS B", kind = "DSDNA-RT", draw = B.hepb },
  { id = "hepd", name = "HEP DELTA", kind = "-SSRNA", draw = B.hepd },
}

return B
