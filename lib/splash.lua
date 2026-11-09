-- noiz virus :: startup screen
-- the NoiZ Temple logo, then it derezzes (TRON style) from the creature's eyes outward:
-- each piece flashes, breaks into a falling shard and fades, leaving the virus behind.

local S = { active = false }

local FPS = 20
local SHOW = 2.0 * FPS      -- frames the logo stays up
local BW, BH = 4, 4         -- piece size (32 x 16 pieces)
local COLS, ROWS = 32, 16
local FALL = 6              -- frames a shard falls / fades

-- average brightness of each 4x4 piece of the logo (row by row, hex 0-f)
local BLOCKS = "044444444444420000000000000000000fffff9fbcfff80000000000000000000ffffe2f2ffff80050000000000000000ffffd155ffff80655250000000000000ffff5017ffff80554750000000000000ffff0027ffff80661270000407474000fffb0006ffff80566060120202280000fff50103ffff80515763574a00900000fff9b000efff8062057476381a436000ffffb000cfff80332010110213421000ffff8000afff80363110000001500000ffff60009fff80060675587754585000fffe40007fff80061444245642462000fff900001fff80000000000510000000fffe5003afff800000000000000000004444433444442000000000000000000"

local png, m, frame, derez_at, done_cb
local pieces = {}

local function lvl(i) return tonumber(BLOCKS:sub(i, i), 16) or 0 end

local function setup()
  pieces = {}
  local ex, ey = 26 / BW, 20 / BH -- between the eyes
  for r = 0, ROWS - 1 do
    for c = 0, COLS - 1 do
      local i = r * COLS + c + 1
      local d = math.sqrt((c + 0.5 - ex) ^ 2 + ((r + 0.5 - ey) * 1.6) ^ 2)
      pieces[i] = {
        x = c * BW, y = r * BH, l = lvl(i),
        t = math.floor(d * 0.55 + math.random() * 4), -- when it goes
        dx = (math.random() - 0.5) * 1.5,
      }
    end
  end
end

local function draw()
  screen.clear()
  if png then screen.display_png(png, 0, 0) end
  if derez_at then
    local k = frame - derez_at
    -- first two frames: a scanline glitch
    if k < 2 then
      screen.level(0)
      for _ = 1, 6 do screen.rect(0, math.random(0, 63), 128, 1); screen.fill() end
    end
    -- gone pieces: black, merged into runs along each row, one fill for all of them
    screen.level(0)
    for r = 0, ROWS - 1 do
      local run
      for c = 0, COLS do
        local p = c < COLS and pieces[r * COLS + c + 1]
        local gone = p and k > p.t
        if gone and not run then run = c
        elseif not gone and run then
          screen.rect(run * BW, r * BH, (c - run) * BW, BH); run = nil
        end
      end
    end
    screen.fill()
    -- flashing pieces and falling shards (only where there was something to see),
    -- grouped by brightness so each level is one fill
    local busy, by = false, {}
    for _, p in ipairs(pieces) do
      local a = k - p.t
      if a <= FALL then busy = true end
      if p.l >= 2 and a >= 0 and a <= FALL then
        local l, x, y, w
        if a == 0 then
          l, x, y, w = 15, p.x, p.y, BW
        else
          l = math.max(1, math.floor(p.l * (1 - a / FALL) + 0.5))
          x, y, w = math.floor(p.x + 1 + p.dx * a), math.floor(p.y + 1 + a * a * 0.6), 2
        end
        by[l] = by[l] or {}
        local t = by[l]; t[#t + 1] = x; t[#t + 1] = y; t[#t + 1] = w
      end
    end
    for l = 1, 15 do
      local t = by[l]
      if t then
        screen.level(l)
        for i = 1, #t, 3 do screen.rect(t[i], t[i + 1], t[i + 2], t[i + 2]) end
        screen.fill()
      end
    end
    if not busy then S.finish() return end
  end
  screen.update()
end

-- start the splash; on_done runs when it has gone. false = no logo file, skipped.
function S.start(on_done)
  local path = norns.state.path .. "lib/temple.png"
  if not util.file_exists(path) then return false end
  png, done_cb, frame, derez_at = path, on_done, 0, nil
  setup()
  S.active = true
  m = metro.init()
  m.time = 1 / FPS
  m.event = function()
    frame = frame + 1
    if not derez_at and frame >= SHOW then derez_at = frame end
    if S.active then draw() end
  end
  m:start()
  draw()
  return true
end

-- a key / encoder / grid press: derez now
function S.skip()
  if S.active and not derez_at then derez_at = frame end
end

-- norns calls redraw() after the menu: put the splash back up
function S.redraw() if S.active then draw() end end

function S.finish()
  if not S.active then return end
  S.active = false
  if m then m:stop(); metro.free(m.id); m = nil end
  if done_cb then done_cb() end
end

return S
