-- noiz virus :: tiny 3d helpers for the 128x64 screen

local D = {}
local sin, cos, sqrt, floor, pi = math.sin, math.cos, math.sqrt, math.floor, math.pi
D.sin, D.cos, D.sqrt, D.floor, D.pi = sin, cos, sqrt, floor, pi

local L = { -0.45, -0.55, 0.70 }
do
  local n = sqrt(L[1] ^ 2 + L[2] ^ 2 + L[3] ^ 2)
  L = { L[1] / n, L[2] / n, L[3] / n }
end
D.LIGHT = L

function D.clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

-- rotate around y (ay), then around x (ax)
function D.rot(x, y, z, ay, ax)
  local c, s = cos(ay), sin(ay)
  x, z = x * c + z * s, -x * s + z * c
  c, s = cos(ax), sin(ax)
  y, z = y * c - z * s, y * s + z * c
  return x, y, z
end

-- rotate around z (in the screen plane)
function D.rotz(x, y, z, a)
  local c, s = cos(a), sin(a)
  return x * c - y * s, x * s + y * c, z
end

function D.fib(n, seed)
  local pts, ga = {}, pi * (3 - sqrt(5))
  for i = 0, n - 1 do
    local y = 1 - 2 * (i + 0.5) / n
    local r = sqrt(1 - y * y)
    local th = ga * i + (seed or 0)
    pts[#pts + 1] = { cos(th) * r, y, sin(th) * r }
  end
  return pts
end

-- depth -1 (back) .. 1 (front) -> grey level
function D.dl(z, lo, hi)
  local t = D.clamp((z + 1) / 2, 0, 1)
  return floor(lo + (hi - lo) * t + 0.5)
end

function D.lvl(l) screen.level(floor(D.clamp(l, 0, 15) + 0.5)) end

-- fake-lit ball
function D.ball(cx, cy, r, lo, hi)
  local n = 6
  for i = 0, n - 1 do
    local f = i / n
    D.lvl(lo + (hi - lo) * f)
    screen.circle(cx - r * 0.32 * f, cy - r * 0.38 * f, r * (1 - 0.8 * f))
    screen.fill()
  end
end

function D.by_z(p, q) return p[3] < q[3] end

function D.seg(x1, y1, x2, y2, l)
  D.lvl(l); screen.move(x1, y1); screen.line(x2, y2); screen.stroke()
end

function D.poly(pts, l, outline)
  D.lvl(l)
  screen.move(pts[1][1], pts[1][2])
  for i = 2, #pts do screen.line(pts[i][1], pts[i][2]) end
  screen.close()
  screen.fill()
  if outline then
    D.lvl(outline)
    screen.move(pts[1][1], pts[1][2])
    for i = 2, #pts do screen.line(pts[i][1], pts[i][2]) end
    screen.close()
    screen.stroke()
  end
end

-- lambert shade for a normal
function D.shade(nx, ny, nz, lo, hi)
  local lam = D.clamp(nx * L[1] + ny * L[2] + nz * L[3], 0, 1)
  return lo + (hi - lo) * lam
end

-- icosahedron --------------------------------------------------------
local phi = (1 + sqrt(5)) / 2
local IV = {}
for _, s1 in ipairs({ -1, 1 }) do
  for _, s2 in ipairs({ -1, 1 }) do
    IV[#IV + 1] = { 0, s1, s2 * phi }
    IV[#IV + 1] = { s1, s2 * phi, 0 }
    IV[#IV + 1] = { s2 * phi, 0, s1 }
  end
end
for i, v in ipairs(IV) do
  local n = sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
  IV[i] = { v[1] / n, v[2] / n, v[3] / n }
end
local IF = {}
do
  local function d2(a, b) return (a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2 end
  local e = 1e9
  for i = 2, #IV do e = math.min(e, d2(IV[1], IV[i])) end
  for i = 1, #IV do
    for j = i + 1, #IV do
      for k = j + 1, #IV do
        if math.abs(d2(IV[i], IV[j]) - e) < 1e-6 and math.abs(d2(IV[j], IV[k]) - e) < 1e-6
          and math.abs(d2(IV[i], IV[k]) - e) < 1e-6 then
          IF[#IF + 1] = { i, j, k }
        end
      end
    end
  end
end
D.ICO_V, D.ICO_F = IV, IF

-- draw a shaded icosahedron; returns projected vertices {x, y, z, X, Y, Z}
-- o: lo, hi (face levels), edge (edge level), grid (sub-triangle level),
--    sx, sy, sz (stretch), shimmer (phase for iridescence)
function D.icosa(cx, cy, R, ay, ax, o)
  o = o or {}
  local sx, sy, sz = o.sx or 1, o.sy or 1, o.sz or 1
  local P = {}
  for i, v in ipairs(IV) do
    local X, Y, Z = D.rot(v[1] * sx, v[2] * sy, v[3] * sz, ay, ax)
    if o.az then X, Y, Z = D.rotz(X, Y, Z, o.az) end
    P[i] = { cx + X * R, cy + Y * R, Z, X, Y, Z }
  end
  local faces = {}
  for _, f in ipairs(IF) do
    local a, b, c = P[f[1]], P[f[2]], P[f[3]]
    local ux, uy, uz = b[4] - a[4], b[5] - a[5], b[6] - a[6]
    local vx, vy, vz = c[4] - a[4], c[5] - a[5], c[6] - a[6]
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    local mx, my, mz = (a[4] + b[4] + c[4]) / 3, (a[5] + b[5] + c[5]) / 3, (a[6] + b[6] + c[6]) / 3
    if nx * mx + ny * my + nz * mz < 0 then nx, ny, nz = -nx, -ny, -nz end
    local n = sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / n, ny / n, nz / n
    if nz > 0 then
      faces[#faces + 1] = { a, b, c, mz, nx, ny, nz }
    end
  end
  table.sort(faces, function(p, q) return p[4] < q[4] end)
  for fi, f in ipairs(faces) do
    local l = D.shade(f[5], f[6], f[7], o.lo or 2, o.hi or 12)
    if o.shimmer then
      l = l + 4 * sin(o.shimmer + fi * 1.7 + f[5] * 3)
    end
    D.poly({ f[1], f[2], f[3] }, l, o.edge)
    if o.grid then -- capsomere hint: connect edge midpoints
      local m = {}
      for k = 1, 3 do
        local p, q = f[k], f[k % 3 + 1]
        m[k] = { (p[1] + q[1]) / 2, (p[2] + q[2]) / 2 }
      end
      D.lvl(o.grid)
      screen.move(m[1][1], m[1][2]); screen.line(m[2][1], m[2][2])
      screen.line(m[3][1], m[3][2]); screen.close(); screen.stroke()
    end
  end
  return P
end

return D
