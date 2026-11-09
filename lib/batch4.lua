-- noiz virus :: specimens 30-37

local D = include and include("lib/draw3d") or dofile(NV_ROOT .. "lib/draw3d.lua")
local sin, cos, sqrt, floor, pi = D.sin, D.cos, D.sqrt, D.floor, D.pi
local rot, by_z = D.rot, D.by_z

local B = {}

local function frame(p)
  local ux, uy, uz = 0, 1, 0
  if math.abs(p[2]) > 0.9 then ux, uy, uz = 1, 0, 0 end
  local e1 = { uy * p[3] - uz * p[2], uz * p[1] - ux * p[3], ux * p[2] - uy * p[1] }
  local n = sqrt(e1[1] ^ 2 + e1[2] ^ 2 + e1[3] ^ 2)
  e1 = { e1[1] / n, e1[2] / n, e1[3] / n }
  local e2 = { p[2] * e1[3] - p[3] * e1[2], p[3] * e1[1] - p[1] * e1[3], p[1] * e1[2] - p[2] * e1[1] }
  return e1, e2
end

local function rng(seed)
  local s = seed
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

-- a capsule (rounded rod) from (x1,y1) to (x2,y2)
local function pill(x1, y1, x2, y2, r, l, outline)
  local dx, dy = x2 - x1, y2 - y1
  local n = sqrt(dx * dx + dy * dy) + 0.001
  local px, py = -dy / n * r, dx / n * r
  D.poly({ { x1 + px, y1 + py }, { x2 + px, y2 + py }, { x2 - px, y2 - py }, { x1 - px, y1 - py } }, l)
  D.lvl(l); screen.circle(x1, y1, r); screen.fill(); screen.circle(x2, y2, r); screen.fill()
  if outline then
    D.lvl(outline)
    screen.move(x1 + px, y1 + py); screen.line(x2 + px, y2 + py); screen.stroke()
  end
end

-- 30 HPV-16: a ball studded with 72 five-pointed stars ---------------------
local STARS = {}
for i, p in ipairs(D.fib(72, 0.7)) do
  local e1, e2 = frame(p)
  local pts = {}
  for k = 0, 9 do
    local t = k * pi / 5 + i
    local r = (k % 2 == 0) and 0.19 or 0.08
    pts[#pts + 1] = { p[1] + (cos(t) * e1[1] + sin(t) * e2[1]) * r,
                      p[2] + (cos(t) * e1[2] + sin(t) * e2[2]) * r,
                      p[3] + (cos(t) * e1[3] + sin(t) * e2[3]) * r }
  end
  STARS[i] = { p, pts }
end
function B.hpv(cx, cy, a, pulse, flinch)
  local R = 18 * pulse * (0.93 + 0.07 * flinch)
  local ay, ax = a * 0.6, 0.4
  D.ball(cx, cy, R, 0, 3)
  for _, s in ipairs(STARS) do
    local p = s[1]
    local x, y, z = rot(p[1], p[2], p[3], ay, ax)
    if z > 0.1 then
      local poly = {}
      for k, q in ipairs(s[2]) do
        local qx, qy = rot(q[1], q[2], q[3], ay, ax)
        poly[k] = { cx + qx * R, cy + qy * R }
      end
      D.poly(poly, D.shade(x, y, z, 4, 15))
      D.lvl(1); screen.rect(floor(cx + x * R), floor(cy + y * R), 1, 1); screen.fill()
    end
  end
end

-- 31 PITHOVIRUS: a huge striped amphora, corked at one end ------------------
function B.pitho(cx, cy, a, pulse, flinch)
  local L, W = 19 * pulse, 11 * pulse
  local th = 0.35 + 0.2 * sin(a * 0.5)
  local c, s = cos(th), sin(th)
  local function P(u, v) -- u along the body (-1 top .. 1 bottom), v across (px)
    local x, y = v, u * L
    return cx + x * c - y * s, cy + 2 + x * s + y * c
  end
  local function w(u) return W * sqrt(math.max(0, 1 - u * u)) * (u < -0.8 and 0.85 or 1) end
  local U0 = -0.92
  local left, right = {}, {}
  for k = 0, 20 do
    local u = U0 + (1 - U0) * k / 20
    local hw = math.max(w(u), (u < -0.85) and 3.5 or 0)
    left[#left + 1] = { P(u, -hw) }
    right[#right + 1] = { P(u, hw) }
  end
  local body = {}
  for _, p in ipairs(left) do body[#body + 1] = p end
  for i = #right, 1, -1 do body[#body + 1] = right[i] end
  D.poly(body, 3, 12)
  -- longitudinal stripes turning with the body
  for k = 0, 11 do
    local ph = k * 2 * pi / 12 + a
    if cos(ph) > 0 then
      local px, py
      for m = 0, 14 do
        local u = U0 + 0.05 + (0.95 - U0) * m / 14
        local x, y = P(u, w(u) * 0.9 * sin(ph))
        if px then D.seg(px, py, x, y, 4 + floor(cos(ph) * 7 + 0.5)) end
        px, py = x, y
      end
    end
  end
  -- the cork: a gridded plug that pops out on STOP
  local pop = 2.5 * (1 - flinch)
  local u1, u2 = U0 - (3 + pop) / L, U0 - pop / L
  local cork = { { P(u1, -3.5) }, { P(u1, 3.5) }, { P(u2, 3.5) }, { P(u2, -3.5) } }
  D.poly(cork, 10, 14)
  for v = -2, 2, 2 do
    local x1, y1 = P(u1, v); local x2, y2 = P(u2, v)
    D.seg(x1, y1, x2, y2, 5)
  end
end

-- 32 POTATO VIRUS Y: a long floppy thread, waving -------------------------
function B.pvy(cx, cy, a, pulse, flinch)
  local span = 50 * (0.55 + 0.45 * flinch)
  local pts = {}
  for k = 0, 56 do
    local t = k / 56
    local curl = 1 + 1.2 * (1 - flinch)
    local x = cx - span / 2 + span * t + 5 * sin(t * 5 * curl + a * 1.5)
    local y = cy + 13 * sin(t * 2.4 * pi * curl + a) * sin(t * pi) + 5 * sin(t * 7 - a * 2) * pulse
    local z = sin(t * 4 + a)
    pts[#pts + 1] = { x, y, z }
  end
  for k = 2, #pts do
    local p, q = pts[k - 1], pts[k]
    D.seg(p[1], p[2] + 1, q[1], q[2] + 1, D.dl(q[3], 2, 6))
    D.seg(p[1], p[2], q[1], q[2], D.dl(q[3], 7, 13))
    if k % 2 == 0 then
      local dx, dy = q[1] - p[1], q[2] - p[2]
      local n = sqrt(dx * dx + dy * dy) + 0.001
      D.seg(q[1] - dy / n * 1.3, q[2] + dx / n * 1.3, q[1] + dy / n * 1.3, q[2] - dx / n * 1.3, D.dl(q[3], 9, 15))
    end
  end
end

-- 33 BACULOVIRUS: a faceted crystal with rod virions trapped inside --------
local RV, RE, RF = {}, {}, {}
do
  for _, x in ipairs({ -1, 1 }) do for _, y in ipairs({ -1, 1 }) do for _, z in ipairs({ -1, 1 }) do
    RV[#RV + 1] = { x, y, z }
  end end end
  local AX = {}
  for ax = 1, 3 do
    for _, sg in ipairs({ -1, 1 }) do
      local v = { 0, 0, 0 }; v[ax] = 2 * sg
      RV[#RV + 1] = v; AX[ax * 10 + sg] = #RV
    end
  end
  for i = 1, 8 do
    for ax = 1, 3 do RE[#RE + 1] = { i, AX[ax * 10 + RV[i][ax]] } end
  end
  local function cv(x, y, z)
    for i = 1, 8 do if RV[i][1] == x and RV[i][2] == y and RV[i][3] == z then return i end end
  end
  for i = 1, 3 do
    for j = i + 1, 3 do
      local k = 6 - i - j
      for _, si in ipairs({ -1, 1 }) do
        for _, sj in ipairs({ -1, 1 }) do
          local c1, c2 = { 0, 0, 0 }, { 0, 0, 0 }
          c1[i], c1[j], c1[k] = si, sj, 1
          c2[i], c2[j], c2[k] = si, sj, -1
          RF[#RF + 1] = { AX[i * 10 + si], cv(c1[1], c1[2], c1[3]), AX[j * 10 + sj], cv(c2[1], c2[2], c2[3]) }
        end
      end
    end
  end
end
local RODS = {}
do
  local r = rng(33)
  for i = 1, 8 do
    local c = { (r() - 0.5) * 1.3, (r() - 0.5) * 1.3, (r() - 0.5) * 1.3 }
    local d = { r() - 0.5, r() - 0.5, r() - 0.5 }
    local n = sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2)
    RODS[i] = { c, { d[1] / n * 0.45, d[2] / n * 0.45, d[3] / n * 0.45 } }
  end
end
function B.baculo(cx, cy, a, pulse, flinch)
  local S = 9 * pulse
  local ay, ax = a * 0.5 + 0.3, 0.45
  local P = {}
  for i, v in ipairs(RV) do
    local x, y, z = rot(v[1], v[2], v[3], ay, ax)
    P[i] = { cx + x * S, cy + y * S, z / 2, x, y, z }
  end
  -- back edges, faint
  for _, e in ipairs(RE) do
    local p, q = P[e[1]], P[e[2]]
    if p[3] + q[3] < 0 then D.seg(p[1], p[2], q[1], q[2], 3) end
  end
  -- front faces, glassy
  local melt = flinch
  for _, f in ipairs(RF) do
    local p1, p2, p3, p4 = P[f[1]], P[f[2]], P[f[3]], P[f[4]]
    local mx, my, mz = (p1[4] + p3[4]) / 2, (p1[5] + p3[5]) / 2, (p1[6] + p3[6]) / 2
    if mz > 0 then
      local n = sqrt(mx * mx + my * my + mz * mz)
      D.poly({ p1, p2, p3, p4 }, D.shade(mx / n, my / n, mz / n, 1, 5) * melt)
    end
  end
  -- trapped rods (spill out a little on STOP: the crystal dissolves)
  local spill = 1 + 0.7 * (1 - flinch)
  local rl = {}
  for _, r in ipairs(RODS) do
    local c, d = r[1], r[2]
    local x1, y1, z1 = rot(c[1] * spill - d[1], c[2] * spill - d[2], c[3] * spill - d[3], ay, ax)
    local x2, y2, z2 = rot(c[1] * spill + d[1], c[2] * spill + d[2], c[3] * spill + d[3], ay, ax)
    rl[#rl + 1] = { x1, y1, x2, y2, (z1 + z2) / 2 }
  end
  table.sort(rl, function(p, q) return p[5] < q[5] end)
  for _, r in ipairs(rl) do
    pill(cx + r[1] * S, cy + r[2] * S, cx + r[3] * S, cy + r[4] * S, 1.1, D.dl(r[5] / 1.5, 6, 12))
  end
  -- front edges, bright
  for _, e in ipairs(RE) do
    local p, q = P[e[1]], P[e[2]]
    if p[3] + q[3] >= 0 then D.seg(p[1], p[2], q[1], q[2], floor(10 + 4 * melt)) end
  end
end

-- 34 MAIZE STREAK: twin icosahedra, fused --------------------------------
function B.maize(cx, cy, a, pulse, flinch)
  local R = 12.5 * pulse
  local ay, ax = a * 0.6, 0.35
  local dx, dy, dz = rot(1, 0, 0, ay * 0.7 + 0.5, ax)
  local d = 10 * (1 + 0.3 * (1 - flinch))
  local twins = { { cx + dx * d, cy + dy * d, dz }, { cx - dx * d, cy - dy * d, -dz } }
  table.sort(twins, by_z)
  for _, t in ipairs(twins) do
    D.icosa(t[1], t[2], R, ay, ax, { lo = 2, hi = 14, edge = 0, grid = 5 })
  end
end

-- 35 ALFALFA MOSAIC: a set of capsules of different lengths ----------------
local CAPS = { { 21, -15, 0.0 }, { 16, 0, 1.7 }, { 12, 14, 3.1 }, { 8, 6, 4.4 } }
function B.alfalfa(cx, cy, a, pulse, flinch)
  local apart = 1 + 0.35 * (1 - flinch)
  for i, c in ipairs(CAPS) do
    local spin = a * (0.5 + i * 0.15) + c[3]
    local len = c[1] * pulse * (0.35 + 0.65 * math.abs(cos(spin)))
    local th = 0.25 * sin(a + c[3])
    local ox = (i == 4) and 15 or ((i % 2 == 0) and -3 or 3)
    local x0, y0 = cx + ox * apart, cy + c[2] * apart
    local hx, hy = cos(th) * len / 2, sin(th) * len / 2
    pill(x0 - hx, y0 - hy, x0 + hx, y0 + hy, 3.6, 8)
    D.seg(x0 - hx, y0 - hy - 2, x0 + hx, y0 + hy - 2, 14)
    -- lattice bands
    local nb = floor(len / 3)
    for b = 1, nb - 1 do
      local f = b / nb - 0.5 + 0.08 * sin(spin * 2)
      local bx, by = x0 + hx * 2 * f, y0 + hy * 2 * f
      D.seg(bx - sin(th) * 3, by + cos(th) * 3 - 0.5, bx + sin(th) * 3, by - cos(th) * 3, 2)
    end
  end
end

-- 36 SSV1: a lemon-shaped spindle with a tuft of tail fibres ---------------
function B.ssv1(cx, cy, a, pulse, flinch)
  local L, W = 17 * pulse, 10 * pulse
  local th = 0.55 + 0.3 * sin(a * 0.6)
  local c, s = cos(th), sin(th)
  local function P(u, v)
    local x, y = u * L, v
    return cx - 3 + x * c - y * s, cy + x * s + y * c
  end
  local function w(u) return W * (1 - u * u) ^ 0.85 end
  -- tail fibres from the pointed end (u = 1); they splay on STOP
  local tx, ty = P(1, 0)
  for k = -2, 2 do
    local px, py = tx, ty
    for m = 1, 5 do
      local u = 1 + m * 0.07
      local v = k * m * (0.5 + 0.9 * (1 - flinch)) + sin(a * 2 + m + k) * 1.2
      local x, y = P(u, v)
      D.seg(px, py, x, y, 12 - m)
      px, py = x, y
    end
  end
  -- body, shaded in layers toward the light
  for layer = 0, 4 do
    local f = layer / 5
    local pts = {}
    for k = 0, 24 do
      local u = -1 + 2 * k / 24
      pts[#pts + 1] = { P(u * (1 - 0.3 * f), -w(u) * (1 - 0.7 * f) - 2.5 * f) }
    end
    for k = 23, 1, -1 do
      local u = -1 + 2 * k / 24
      pts[#pts + 1] = { P(u * (1 - 0.3 * f), w(u) * (1 - 0.7 * f) - 2.5 * f) }
    end
    D.poly(pts, 2 + layer * 2.2)
  end
  -- a ridge turning round the long axis
  local ph = a * 1.5
  if cos(ph) > -0.2 then
    local px, py
    for k = 0, 16 do
      local u = -0.9 + 1.8 * k / 16
      local x, y = P(u, w(u) * sin(ph))
      if px then D.seg(px, py, x, y, 5 + floor(5 * math.max(0, cos(ph)) + 0.5)) end
      px, py = x, y
    end
  end
end

-- 37 IRIDOVIRUS 6: an icosahedron that shimmers ---------------------------
local GLINT = {}
do
  local r = rng(37)
  for i = 1, 14 do GLINT[i] = { (r() - 0.5) * 44, (r() - 0.5) * 44, r() * 2 * pi } end
end
function B.irido(cx, cy, a, pulse, flinch)
  local R = 17 * pulse
  D.icosa(cx, cy, R, a * 0.5, 0.35, { lo = 1, hi = 13, edge = 1, grid = 7, shimmer = a * 4 * (0.5 + flinch) })
  for i, g in ipairs(GLINT) do
    local v = sin(a * 5 + g[3])
    if v > 0.75 then
      local l = floor(9 + 24 * (v - 0.75))
      local x, y = floor(cx + g[1]), floor(cy + g[2])
      D.lvl(l); screen.rect(x, y, 1, 1); screen.fill()
      D.lvl(l - 6)
      screen.rect(x - 1, y, 1, 1); screen.fill(); screen.rect(x + 1, y, 1, 1); screen.fill()
      screen.rect(x, y - 1, 1, 1); screen.fill(); screen.rect(x, y + 1, 1, 1); screen.fill()
    end
  end
end

B.list = {
  { id = "hpv16", name = "HPV-16", kind = "DSDNA", draw = B.hpv },
  { id = "pithovirus", name = "PITHOVIRUS", kind = "DSDNA", draw = B.pitho },
  { id = "pvy", name = "POTATO VIR Y", kind = "+SSRNA", draw = B.pvy },
  { id = "baculovirus", name = "BACULOVIRUS", kind = "DSDNA", draw = B.baculo },
  { id = "maize_streak", name = "MAIZE STREAK", kind = "SSDNA", draw = B.maize },
  { id = "alfalfa_mosaic", name = "ALFALFA MOS", kind = "+SSRNA", draw = B.alfalfa },
  { id = "ssv1", name = "SSV1", kind = "DSDNA", draw = B.ssv1 },
  { id = "iridovirus6", name = "IRIDOVIRUS 6", kind = "DSDNA", draw = B.irido },
}

return B
