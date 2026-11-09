-- noiz virus :: specimens 14-21

local D = include and include("lib/draw3d") or dofile(NV_ROOT .. "lib/draw3d.lua")
local sin, cos, sqrt, floor, pi = D.sin, D.cos, D.sqrt, D.floor, D.pi
local rot, by_z = D.rot, D.by_z

local B = {}

-- 14 T7: big round head, short stubby tail; tail fibres flick out on STOP
function B.t7(cx, cy, a, pulse, flinch)
  local ay, tilt = a * 0.7, 0.3
  local function P(x, y, z)
    local X, Y, Z = rot(x, y, z, ay, tilt)
    return cx + X, cy + Y, Z
  end
  local R = 13 * pulse
  local hy = -4
  -- stubby tail: a short cone under the head
  local sx1, sy1 = P(0, hy + R - 1, 0)
  local sx2, sy2 = P(0, hy + R + 7, 0)
  D.lvl(9); screen.move(sx1 - 4, sy1); screen.line(sx2 - 1.5, sy2); screen.line(sx2 + 1.5, sy2)
  screen.line(sx1 + 4, sy1); screen.close(); screen.fill()
  -- six short fibres folded along the tail; they spread on STOP
  local spread = 1 - flinch
  for k = 0, 5 do
    local t = k * pi / 3 + 0.4
    local fx, fy, fz = P(cos(t) * (2 + 9 * spread), hy + R + 7 + 4 * (1 - spread), sin(t) * (2 + 9 * spread))
    D.seg(sx2, sy2, fx, fy, D.dl(fz / 10, 4, 12))
  end
  D.icosa(cx, cy + hy, R, ay, tilt, { lo = 3, hi = 14, edge = 1 })
end

-- 15 PHI X174: icosahedron with stubby pentagonal prongs on every corner
function B.phix(cx, cy, a, pulse, flinch)
  local R = 13 * pulse
  local ay, ax = a * 0.6, 0.35 + a * 0.2
  local corners = {}
  for i, v in ipairs(D.ICO_V) do
    local x, y, z = rot(v[1], v[2], v[3], ay, ax)
    corners[i] = { x, y, z }
  end
  table.sort(corners, by_z)
  local function prong(c)
    local L = R + 5 * flinch * pulse
    local l = D.dl(c[3], 4, 15)
    local px, py = -c[2] * 2, c[1] * 2
    D.poly({ { cx + c[1] * R + px, cy + c[2] * R + py }, { cx + c[1] * L, cy + c[2] * L },
             { cx + c[1] * R - px, cy + c[2] * R - py } }, l)
    D.lvl(l); screen.circle(cx + c[1] * L, cy + c[2] * L, 1.6); screen.fill()
  end
  for _, c in ipairs(corners) do if c[3] < 0 then prong(c) end end
  D.icosa(cx, cy, R, ay, ax, { lo = 2, hi = 11, edge = 1 })
  for _, c in ipairs(corners) do if c[3] >= 0 then prong(c) end end
end

-- 16 MS2: a little swarm of pebbly balls (it's tiny), one up close
local PEB = D.fib(46, 0.9)
local function pebble(cx, cy, r, a, lo, hi)
  D.ball(cx, cy, r, lo, lo + 3)
  local pts = {}
  for i, p in ipairs(PEB) do
    local x, y, z = rot(p[1], p[2], p[3], a, 0.4)
    pts[i] = { x, y, z }
  end
  for _, p in ipairs(pts) do
    if p[3] > 0.1 then
      local l = D.shade(p[1], p[2], p[3], lo + 1, hi)
      D.lvl(l); screen.circle(cx + p[1] * r * 0.9, cy + p[2] * r * 0.9, math.max(0.6, r * 0.15 * (0.4 + 0.6 * p[3]))); screen.fill()
    end
  end
end
local SWARM = { { -18, -14, 3.5, 0.0 }, { 17, -16, 3, 1.3 }, { -17, 15, 3, 2.2 }, { 18, 13, 4, 3.4 }, { 0, -22, 2.5, 4.1 } }
function B.ms2(cx, cy, a, pulse, flinch)
  for _, s in ipairs(SWARM) do
    local dx = cos(a + s[4]) * 2 * flinch
    local dy = sin(a * 1.3 + s[4]) * 2
    pebble(cx + s[1] + dx, cy + s[2] + dy, s[3], a * 2 + s[4], 2, 10)
  end
  pebble(cx, cy, 11 * pulse, a, 2, 15)
end

-- 17 SMALLPOX: a rounded brick with surface tubules and a dumbbell core ---------
local BOX = { 9, 12, 6.5 }
local BOX_F = { -- face: normal axis, sign
  { 1, 1 }, { 1, -1 }, { 2, 1 }, { 2, -1 }, { 3, 1 }, { 3, -1 } }
function B.smallpox(cx, cy, a, pulse, flinch)
  local ay, ax = a * 0.6 + 0.7, 0.55 + 0.2 * sin(a * 0.5)
  local s = pulse
  local function P(x, y, z)
    local X, Y, Z = rot(x * s, y * s, z * s, ay, ax)
    return { cx + X, cy + Y, Z, X, Y, Z }
  end
  local faces = {}
  for _, f in ipairs(BOX_F) do
    local axis, sg = f[1], f[2]
    local u = axis % 3 + 1
    local v = u % 3 + 1
    local function corner(su, sv)
      local c = { 0, 0, 0 }
      c[axis] = BOX[axis] * sg
      c[u] = BOX[u] * su
      c[v] = BOX[v] * sv
      return c
    end
    local cs = { corner(-1, -1), corner(1, -1), corner(1, 1), corner(-1, 1) }
    local n = { 0, 0, 0 }; n[axis] = sg
    local nx, ny, nz = rot(n[1], n[2], n[3], ay, ax)
    if nz > 0 then
      local pts = {}
      for i, c in ipairs(cs) do pts[i] = P(c[1], c[2], c[3]) end
      faces[#faces + 1] = { pts = pts, nz = nz, nx = nx, ny = ny, axis = axis, sg = sg, u = u, v = v }
    end
  end
  table.sort(faces, function(p, q) return p.nz < q.nz end)
  -- rounded silhouette: a soft blob behind the faces

  for _, f in ipairs(faces) do
    local l = D.shade(f.nx, f.ny, f.nz, 3, 12)
    D.poly(f.pts, l)
    -- tubules: little squiggles across the face
    for k = -2, 2 do
      local c = { 0, 0, 0 }
      c[f.axis] = BOX[f.axis] * f.sg
      local px, py
      for m = -4, 4 do
        c[f.u] = BOX[f.u] * 0.8 * m / 4
        c[f.v] = BOX[f.v] * 0.8 * (k / 2.5) + sin(m * 1.7 + k + a * 2) * 0.9
        local p = P(c[1], c[2], c[3])
        if px then D.seg(px, py, p[1], p[2], l - 4) end
        px, py = p[1], p[2]
      end
    end
  end
  -- dumbbell core glimpsed through the biggest face
  local f = faces[#faces]
  if f and f.nz > 0.6 then
    local c1 = { 0, 0, 0 }; local c2 = { 0, 0, 0 }
    c1[f.axis] = BOX[f.axis] * f.sg; c2[f.axis] = BOX[f.axis] * f.sg
    c1[f.u] = -BOX[f.u] * 0.4; c2[f.u] = BOX[f.u] * 0.4
    local p1, p2 = P(c1[1], c1[2], c1[3]), P(c2[1], c2[2], c2[3])
    local cl = D.shade(f.nx, f.ny, f.nz, 3, 12) - 5
    D.lvl(cl)
    screen.move(p1[1], p1[2]); screen.line(p2[1], p2[2]); screen.stroke()
    screen.move(p1[1], p1[2] + 1); screen.line(p2[1], p2[2] + 1); screen.stroke()
    screen.circle(p1[1], p1[2], 2); screen.fill()
    screen.circle(p2[1], p2[2], 2); screen.fill()
  end
end

-- 18 ORF: an oval wound in criss-crossing yarn ----------------------------
function B.orf(cx, cy, a, pulse, flinch)
  local rx, ry, rz = 11 * pulse, 16 * pulse, 10 * pulse
  local tilt = 0.5
  D.lvl(2)
  for k = -16, 16 do -- oval body
    local y = k
    local w = rx * sqrt(math.max(0, 1 - (y / ry) ^ 2))
    local yy = cy + y
    if w > 0 then screen.rect(floor(cx - w), floor(yy), floor(2 * w), 1); screen.fill() end
  end
  -- two families of helical threads
  for fam = -1, 1, 2 do
    for k = 0, 7 do
      local px, py, pv
      for m = 0, 30 do
        local t = m / 30 * pi
        local ph = fam * t * 1.6 + k * pi / 4 + a * fam * 0.6
        local x = sin(t) * cos(ph) * rx
        local y = -cos(t) * ry
        local z = sin(t) * sin(ph) * rz
        local X, Y = x * cos(tilt * sin(a * 0.3)) - y * sin(tilt * sin(a * 0.3)) * 0.0, y
        local vis = z > 0
        if px and vis and pv then
          D.seg(px, py, cx + X, cy + Y, 6 + floor(4 * z / rz + 0.5) + (fam > 0 and 2 or 0))
        end
        px, py, pv = cx + X, cy + Y, vis
      end
    end
  end
end

-- 19 ROTAVIRUS: a wheel with spokes, triple-layer rim and short spikes -----
function B.rota(cx, cy, a, pulse, flinch)
  local tilt = 0.45 + 0.3 * sin(a * 0.4)
  local spin = a * 0.8
  local function P(r, t, z)
    local x, y = cos(t + spin) * r, sin(t + spin) * r
    local X, Y, Z = rot(x, y, z or 0, 0.5 * sin(a * 0.3), tilt)
    return cx + X, cy + Y, Z
  end
  local R = 17 * pulse
  -- spikes around the rim
  for k = 0, 39 do
    local t = k * 2 * pi / 40
    local x1, y1, z1 = P(R, t)
    local x2, y2 = P(R + 3 * flinch, t)
    D.seg(x1, y1, x2, y2, D.dl(z1 / R, 4, 11))
  end
  -- three rim layers + hub, as rings of dots/lines
  local rings = { { R, 13 }, { R - 2.5, 9 }, { R - 5, 6 }, { 5, 11 } }
  for _, rg in ipairs(rings) do
    local px, py
    for k = 0, 48 do
      local t = k * 2 * pi / 48
      local x, y, z = P(rg[1], t)
      if px then D.seg(px, py, x, y, rg[2] + floor(z / R * 2 + 0.5)) end
      px, py = x, y
    end
  end
  -- spokes
  for k = 0, 11 do
    local t = k * 2 * pi / 12
    local x1, y1 = P(5, t)
    local x2, y2, z2 = P(R - 5, t)
    D.seg(x1, y1, x2, y2, 10 + floor(z2 / R * 2 + 0.5))
  end
  D.lvl(13); local hx, hy = P(0, 0); screen.circle(hx, hy, 2.5); screen.fill()
end

-- 20 ASTROVIRUS: a ball with a turning star on its face --------------------
function B.astro(cx, cy, a, pulse, flinch)
  local R = 15 * pulse
  -- knobs around the edge
  for k = 0, 29 do
    local t = k * 2 * pi / 30 + a * 0.2
    D.lvl(7); screen.circle(cx + cos(t) * (R + 1.5 * flinch), cy + sin(t) * (R + 1.5 * flinch), 1.2); screen.fill()
  end
  D.ball(cx, cy, R, 2, 9)
  -- the star: 6 points, wobbling in 3d
  local n = 6
  local pts = {}
  local wob = sin(a) * 0.5
  for k = 0, 2 * n - 1 do
    local t = k * pi / n + a * 0.5
    local r = (k % 2 == 0) and R * 0.78 or R * 0.33
    local x, y = cos(t) * r, sin(t) * r
    local X, Y = rot(x, y, 0, wob, 0.25 * cos(a * 0.7))
    pts[#pts + 1] = { cx + X, cy + Y }
  end
  D.poly(pts, 14, 15)
  D.lvl(4); screen.circle(cx, cy, R * 0.15); screen.fill()
end

-- 21 NOROVIRUS: a ball pocked with dark cups (calici = cup) ----------------
local CUPS = D.fib(32, 0.5)
function B.noro(cx, cy, a, pulse, flinch)
  local R = 15 * pulse
  D.ball(cx, cy, R, 3, 13)
  local pts = {}
  for i, c in ipairs(CUPS) do
    local x, y, z = rot(c[1], c[2], c[3], a * 0.8, 0.3)
    pts[i] = { x, y, z }
  end
  table.sort(pts, by_z)
  for _, p in ipairs(pts) do
    if p[3] > 0.05 then
      local r = R * 0.2 * (0.45 + 0.55 * p[3])
      local x, y = cx + p[1] * R * 0.85, cy + p[2] * R * 0.85
      D.lvl(D.shade(p[1], p[2], p[3], 6, 15)); screen.circle(x, y, r + 0.8); screen.fill()
      D.lvl(1); screen.circle(x + 0.3, y + 0.3, r * (0.6 + 0.4 * flinch)); screen.fill()
    end
  end
end

B.list = {
  { id = "t7", name = "PHAGE T7", kind = "DSDNA", draw = B.t7 },
  { id = "phix174", name = "PHI X174", kind = "SSDNA", draw = B.phix },
  { id = "ms2", name = "PHAGE MS2", kind = "+SSRNA", draw = B.ms2 },
  { id = "variola", name = "SMALLPOX", kind = "DSDNA", draw = B.smallpox },
  { id = "orf", name = "ORF", kind = "DSDNA", draw = B.orf },
  { id = "rotavirus_a", name = "ROTAVIRUS", kind = "DSRNA", draw = B.rota },
  { id = "astrovirus", name = "ASTROVIRUS", kind = "+SSRNA", draw = B.astro },
  { id = "norovirus", name = "NOROVIRUS", kind = "+SSRNA", draw = B.noro },
}

return B
