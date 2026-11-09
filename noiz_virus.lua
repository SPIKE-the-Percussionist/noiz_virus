-- noiz virus
-- v1.0
-- SPIKE the Percussionist
-- manipulate.net
--
-- reads the real genomes of
-- 42 viruses and plays them.
-- (#42 isn't even a virus.)
--
-- E1: virus
-- E2: window (letters per read)
-- E3: mutation
-- K1+E3: live <> virus mix
--
-- each virus has its own
-- scale + sound; G/C-rich
-- codons ring longer
-- K2: play / stop
-- K3: back to the start
-- K1+K3: reassort
-- (segmented ones)
-- K1+K2: save this virus's
-- sound as you've set it
--
-- the gene map shows which
-- real gene is being read
--
-- sound source: synth, sample
-- or both. the sample side
-- chops up the live input
-- (or a file) with softcut
--
-- each virus has its own
-- tape filter, reverb room,
-- delay and panning,
-- played by the genome
--
-- grid 128 in portrait +
-- arc 4: see the README
--
-- follows MIDI clock +
-- start/stop when CLOCK
-- source is set to midi

engine.name = "PolyPerc"

local musicutil = require "musicutil"
local G = include("lib/genetics")
local VIR = include("lib/viruses")
local SAMP = include("lib/sampler")
local GLITCH = include("lib/glitch")
local FX = include("lib/fx")
local SPL = include("lib/splash") -- the NoiZ Temple startup screen

local DATA = _path.code .. "noiz_virus/data/"
local SAVE_DIR = _path.data .. "noiz_virus/"
local SAVE_FILE = SAVE_DIR .. "sounds.txt"

-- state ---------------------------------------------------------------
local genomes = {}   -- per virus: { seq, segs = {starts}, lens, mut = {}, mutcount }
local cur            -- current genome table
local pos = 1        -- next letter to read (1-based, flat across segments)
local playing = false
local GR = {}         -- the grid (filled in at the bottom)
local ARC = { sparks = {}, glitch = 0, cut = 1000 } -- the arc (filled in at the bottom)
local GEST = {}       -- gesture pads being held / latched: throw wall stut rev mut dry
local translating = false     -- ribosome mode: inside a gene?
local last = { start = 1, len = 3, letters = "", label = "", notes = {}, stop = false, aug = false }
local scale_notes = {}
local midi_out
local angle, pulse, flinch = 0, 1, 1
local mut_flash = 0
local found_flash = 0
local screen_dirty = true
local hold = 0       -- clock steps left before the next read (letter rhythm)
local last_units = 1
local k1_held = false
local section_flash = 0
local saved_flash = 0
local mix_flash = 0 -- shows the live <> virus bar on line 2
local saved_msg = ""
local apply_room -- (defined with the fx, below)
local pan_now, pan2, pan_slew = 0, 0, 0.02 -- this read's place in the stereo field
local wander = 0
local rev_glide = 0         -- how far the reverb sends have swelled (gaps, STOPs)
local mutated_now = false   -- did a letter mutate in this read?
local gene_flash = 0
local gene_tone, gene_gap = 1, false   -- set per step, used by play()
local gap_level = 1                    -- 1 inside genes; glides down in quiet gaps
-- each gene moves the music by a few scale degrees
local GENE_SHIFT = { 0, 3, 5, 1, 4, -2, 2, 6 }
local sec_beats = 0    -- flu: beats spent in the current section
local SEC_BARS = { 0, 4, 8, 16 }

-- flu: each of the 8 segments is a section; chord-like moves in scale degrees
local PROGRESSION = { 0, 3, 4, 0, 5, 3, 4, 0 }
local COMP = { A = "U", U = "A", G = "C", C = "G" }

local DIVS = { 1, 1/2, 1/4, 1/8, 1/3, 1/6, 1/12 }
local DIV_NAMES = { "1/4", "1/8", "1/16", "1/32", "1/8T", "1/16T", "1/32T" }

-- genomes ---------------------------------------------------------------
-- lay the gene map out along the genome as it is now (segments can be reassorted)
local function build_track(g)
  local t, starts = {}, {}
  for k = 1, #g.segs do
    for _, it in ipairs(g.gsrc[g.segid[k]] or {}) do
      local off = g.segs[k] - 1
      t[#t + 1] = { a = it[1] + off, b = it[2] + off, n = it[3], first = it[4], name = it[5], strand = it[6] }
    end
  end
  table.sort(t, function(p, q) return p.a < q.a end)
  for k, it in ipairs(t) do starts[k] = it.a end
  g.track, g.tstarts = t, starts
end

local function load_genome(i)
  if genomes[i] then return genomes[i] end
  local v = VIR.list[i]
  local f = io.open(DATA .. v.id .. ".rna", "r")
  local g = { seq = "", segs = {}, lens = {}, mut = {}, mutcount = 0 }
  if not f then
    print("noiz virus: missing " .. DATA .. v.id .. ".rna")
    g.seq = "AUG"
    g.segs, g.lens = { 1 }, { 3 }
  else
    local parts = {}
    local at = 1
    for line in f:lines() do
      line = line:gsub("%s", ""):upper():gsub("T", "U")
      if #line > 0 then
        parts[#parts + 1] = line
        g.segs[#g.segs + 1] = at
        g.lens[#g.lens + 1] = #line
        at = at + #line
      end
    end
    f:close()
    g.seq = table.concat(parts)
  end
  g.segid, g.cursor = {}, {}
  for k = 1, #g.segs do g.segid[k] = k end
  -- gene map: data/<id>.genes, one line per stretch: seg from to gene starts name
  g.gsrc = {}
  local gf = io.open(DATA .. v.id .. ".genes", "r")
  if gf then
    for line in gf:lines() do
      local sg, a, b, n, st, sd, name = line:match("^(%d+) (%d+) (%d+) (%d+) (%d) ([%+%-]) (%S+)")
      if sg then
        sg = tonumber(sg)
        g.gsrc[sg] = g.gsrc[sg] or {}
        table.insert(g.gsrc[sg], { tonumber(a), tonumber(b), tonumber(n), st == "1", name, sd })
      end
    end
    gf:close()
  end
  genomes[i] = g
  build_track(g)
  return g
end

local function wrap(i)
  local n = #cur.seq
  return ((i - 1) % n) + 1
end

local function base_at(i)
  i = wrap(i)
  return cur.mut[i] or cur.seq:sub(i, i)
end

-- which gene covers letter i (nil between genes): a quick binary search
local function gene_at(i)
  local st = cur.tstarts
  if not st or #st == 0 then return nil end
  local lo, hi = 1, #st
  if i < st[1] then return nil end
  while lo < hi do
    local mid = (lo + hi + 1) // 2
    if st[mid] <= i then lo = mid else hi = mid - 1 end
  end
  local it = cur.track[lo]
  if i <= it.b then return it end
  return nil
end

-- where a gene begins: + strand genes at their low end, - strand genes at their high end
local function gene_entry(it) return it.strand == "-" and it.b or it.a end

-- the next real gene start after letter i, moving through the genome (wraps round)
local function next_gene_start(i)
  local t = cur.track
  if not t or #t == 0 then return nil end
  local best, wrapbest
  for _, it in ipairs(t) do
    if it.first then
      local e = gene_entry(it)
      if e > i and (not best or e < gene_entry(best)) then best = it end
      if not wrapbest or e < gene_entry(wrapbest) then wrapbest = it end
    end
  end
  best = best or wrapbest
  if best then return gene_entry(best), best end
end

local function has_genes() return cur.track and #cur.track > 0 end

-- for a letter between genes: which gap is it (index of the gene before it) and how long is the gap
local function gap_here(i)
  local st, t = cur.tstarts, cur.track
  local lo, hi = 0, #st
  while lo < hi do -- last gene starting at or before i
    local mid = (lo + hi + 1) // 2
    if st[mid] <= i then lo = mid else hi = mid - 1 end
  end
  local prev_end = lo > 0 and t[lo].b or 0
  local next_start = t[lo + 1] and t[lo + 1].a or (#cur.seq + 1)
  return lo, next_start - prev_end - 1
end

local function segment_of(i)
  local s = 1
  for k, st in ipairs(cur.segs) do if i >= st then s = k end end
  return s
end

-- each virus's form (when params > forms is on)
local function form()
  if params:string("forms") ~= "on" then return nil end
  return VIR.list[params:get("virus")].form
end

-- Ebola reads its template strand: backwards, and complemented (A<>U, G<>C)
-- in ribosome mode on a real gene, the reader follows that gene's strand instead:
-- a - strand gene is read from its high end, backwards, complemented
local gstrand = nil
local ghi = nil   -- high end of the - strand gene being read (search on from there)
local function dir()
  local d
  if translating and gstrand then d = gstrand == "-" and -1 or 1
  else d = form() == "reverse" and -1 or 1 end
  if GEST.rev then d = -d end -- REV gesture: read the other way
  return d
end
local function sense(b)
  if translating and gstrand then return gstrand == "-" and COMP[b] or b end
  if form() == "reverse" then return COMP[b] end
  return b
end

local function is_reassorted()
  for k, id in ipairs(cur.segid) do if id ~= k then return true end end
  return false
end

-- flu reassortment: shuffle the 8 segments, carrying mutations + our place along
local function reassort()
  if #cur.segs < 2 then return end
  local here = segment_of(wrap(pos))
  cur.cursor[cur.segid[here]] = wrap(pos) - cur.segs[here]
  local pieces = {}
  for k = 1, #cur.segs do
    local st, ln = cur.segs[k], cur.lens[k]
    local muts = {}
    for i = st, st + ln - 1 do
      if cur.mut[i] then muts[i - st] = cur.mut[i] end
    end
    pieces[k] = { seq = cur.seq:sub(st, st + ln - 1), len = ln, id = cur.segid[k], muts = muts }
  end
  for k = #pieces, 2, -1 do
    local j = math.random(k)
    pieces[k], pieces[j] = pieces[j], pieces[k]
  end
  -- always land on a different segment than the one playing now
  local now_id = cur.segid[here]
  if pieces[1].id == now_id then
    local j = math.random(2, #pieces)
    pieces[1], pieces[j] = pieces[j], pieces[1]
  end
  local parts, at = {}, 1
  cur.mut, cur.segs, cur.lens, cur.segid = {}, {}, {}, {}
  for k, pc in ipairs(pieces) do
    parts[k] = pc.seq
    cur.segs[k], cur.lens[k], cur.segid[k] = at, pc.len, pc.id
    for o, b in pairs(pc.muts) do cur.mut[at + o] = b end
    at = at + pc.len
  end
  cur.seq = table.concat(parts)
  build_track(cur)
  -- jump straight into the new first section, where that segment left off
  pos = cur.segs[1] + (cur.cursor[cur.segid[1]] or 0)
  last.start, last.section = pos, nil
  translating, hold, sec_beats = false, 0, 0
  section_flash = 10
  screen_dirty = true
end

-- flu: move on to the next segment, resuming where that segment left off
local function next_section()
  local k = segment_of(wrap(pos))
  cur.cursor[cur.segid[k]] = wrap(pos) - cur.segs[k]
  local n = k % #cur.segs + 1
  pos = cur.segs[n] + (cur.cursor[cur.segid[n]] or 0)
  translating, hold = false, 0
end

-- reading a letter may mutate it first (the change stays in the genome)
local function read_letter(i)
  i = wrap(i)
  local rate = params:get("mutation")
  if rate > 0 and math.random() * 100 < rate then
    local old = base_at(i)
    local nb
    repeat nb = G.BASES[math.random(4)] until nb ~= old
    mutated_now = true
    ARC.sparks[#ARC.sparks + 1] = { i = i, t = 8 } -- a spark on the arc
    if cur.mut[i] == nil then cur.mutcount = cur.mutcount + 1 end
    if nb == cur.seq:sub(i, i) then
      cur.mut[i] = nil
      cur.mutcount = cur.mutcount - 1
    else
      cur.mut[i] = nb
    end
    mut_flash = 6
  end
  return base_at(i)
end

local function restore_genome()
  cur.mut, cur.mutcount = {}, 0
  cur.strain = nil
  screen_dirty = true
end

local function reset_pos()
  pos = dir() == -1 and #cur.seq or 1
  hold, sec_beats = 0, 0
  if cur.cursor then cur.cursor = {} end
  translating = false
end

local function set_virus(i)
  cur = load_genome(i)
  if params.lookup and params.lookup["fx_reverb"] then apply_room() end
  reset_pos()
  last.letters, last.label, last.notes = "", "", {}
  last.codon2, last.notes2, last.section = "", {}, nil
  screen_dirty = true
end

-- strains -----------------------------------------------------------------
-- a strain = your mutations (+ segment order), 8 slots per virus, in dust/data/noiz_virus/strains/
-- file: line 1 "order 1 2 3 ...", then one line per changed letter: segment offset letter
local STRAIN_DIR = SAVE_DIR .. "strains/"
local function strain_file(n) return STRAIN_DIR .. VIR.list[params:get("virus")].id .. "_" .. n .. ".txt" end
local function strain_exists(n)
  local f = io.open(strain_file(n), "r")
  if f then f:close() return true end
  return false
end

local function strain_msg(t) saved_flash, saved_msg = 36, t; screen_dirty = true end

local function save_strain()
  local n = params:get("strain_slot")
  if cur.mutcount == 0 and not is_reassorted() then
    os.remove(strain_file(n))
    if cur.strain == n then cur.strain = nil end
    strain_msg("CLEARED #" .. n)
    return
  end
  if util.make_dir then util.make_dir(STRAIN_DIR) end
  local f = io.open(strain_file(n), "w")
  if not f then print("noiz virus: can't write " .. strain_file(n)) return end
  f:write("order " .. table.concat(cur.segid, " ") .. "\n")
  for i, b in pairs(cur.mut) do
    local k = segment_of(i)
    f:write(cur.segid[k] .. " " .. (i - cur.segs[k]) .. " " .. b .. "\n")
  end
  f:close()
  cur.strain = n
  strain_msg("SAVED #" .. n)
end

local function load_strain()
  local n = params:get("strain_slot")
  local f = io.open(strain_file(n), "r")
  if not f then strain_msg("#" .. n .. " IS EMPTY") return end
  local i = params:get("virus")
  genomes[i] = nil -- start from the original genome
  cur = load_genome(i)
  local order, muts = nil, {}
  for line in f:lines() do
    if line:sub(1, 5) == "order" then
      order = {}
      for x in line:gmatch("%d+") do order[#order + 1] = tonumber(x) end
    else
      local sg, off, b = line:match("^(%d+) (%d+) ([ACGU])")
      if sg then muts[#muts + 1] = { tonumber(sg), tonumber(off), b } end
    end
  end
  f:close()
  -- put the segments in the saved order
  if order and #order == #cur.segs then
    local pieces = {}
    for k = 1, #cur.segs do pieces[k] = cur.seq:sub(cur.segs[k], cur.segs[k] + cur.lens[k] - 1) end
    local lens = {}
    for k = 1, #cur.lens do lens[k] = cur.lens[k] end
    local parts, at = {}, 1
    cur.segs, cur.lens, cur.segid = {}, {}, {}
    for k, id in ipairs(order) do
      parts[k] = pieces[id]
      cur.segs[k], cur.lens[k], cur.segid[k] = at, lens[id], id
      at = at + lens[id]
    end
    cur.seq = table.concat(parts)
    build_track(cur)
  end
  -- and the changed letters
  local slot = {}
  for k, id in ipairs(cur.segid) do slot[id] = k end
  for _, m in ipairs(muts) do
    local k = slot[m[1]]
    if k and m[2] < cur.lens[k] then
      local at = cur.segs[k] + m[2]
      if cur.seq:sub(at, at) ~= m[3] then
        if not cur.mut[at] then cur.mutcount = cur.mutcount + 1 end
        cur.mut[at] = m[3]
      end
    end
  end
  cur.strain = n
  reset_pos()
  last.section = nil
  strain_msg("LOADED #" .. n)
end

-- notes ---------------------------------------------------------------
local function build_scale()
  local name = musicutil.SCALES[params:get("scale")].name
  scale_notes = musicutil.generate_scale(params:get("root"), name, 6)
end

local function squash(n) return (n or ""):lower():gsub("[^%a]", "") end
local function scale_index(name)
  if not name then return nil end
  for i, sc in ipairs(musicutil.SCALES) do
    if sc.name == name then return i end
  end
  for i, sc in ipairs(musicutil.SCALES) do -- forgiving second try
    if squash(sc.name) == squash(name) then return i end
  end
  return nil
end

local function scale_short()
  local name = musicutil.SCALES[params:get("scale")].name
  for _, v in ipairs(VIR.list) do
    if v.sound.scale == name then return v.sound.short end
  end
  return name:gsub(" ", ""):upper():sub(1, 5)
end

-- each virus brings its own scale, register, speed + tone
local function apply_personality(i)
  if params:string("personality") ~= "per virus" then return end
  local s = VIR.list[i].sound
  local si = scale_index(s.scale)
  if si then params:set("scale", si) end
  params:set("root", s.root)
  params:set("division", s.division)
  params:set("release", s.release)
  params:set("cutoff", s.cutoff)
  params:set("pw", s.pw)
end

-- your own sounds ----------------------------------------------------
-- each virus keeps a factory copy of its sound; your saved version replaces it
-- file: one line per virus: id|scale|root|division|release|cutoff|pw
for _, v in ipairs(VIR.list) do
  v.factory = {}
  for k, x in pairs(v.sound) do v.factory[k] = x end
end

local function write_sounds()
  if util.make_dir then util.make_dir(SAVE_DIR) end
  local f = io.open(SAVE_FILE, "w")
  if not f then print("noiz virus: can't write " .. SAVE_FILE) return end
  for _, v in ipairs(VIR.list) do
    if v.custom then
      local s = v.sound
      f:write(string.format("%s|%s|%d|%d|%.3f|%.1f|%d\n", v.id, s.scale or "-", s.root, s.division,
        s.release, s.cutoff, s.pw))
    end
  end
  f:close()
end

local function read_sounds()
  local f = io.open(SAVE_FILE, "r")
  if not f then return end
  local by = {}
  for _, v in ipairs(VIR.list) do by[v.id] = v end
  for line in f:lines() do
    local id, sc, root, div, rel, cut, pw = line:match("^([^|]+)|([^|]*)|(%d+)|(%d+)|([%d%.]+)|([%d%.]+)|(%d+)")
    local v = id and by[id]
    if v then
      v.sound = { scale = (sc ~= "-") and sc or v.factory.scale, root = tonumber(root), division = tonumber(div),
        release = tonumber(rel), cutoff = tonumber(cut), pw = tonumber(pw) }
      v.custom = true
    end
  end
  f:close()
end

-- store the current settings as this virus's sound
local function save_sound()
  local v = VIR.list[params:get("virus")]
  v.sound = {
    scale = v.factory.scale and musicutil.SCALES[params:get("scale")].name or nil,
    root = params:get("root"), division = params:get("division"),
    release = params:get("release"), cutoff = params:get("cutoff"), pw = params:get("pw"),
  }
  v.custom = true
  write_sounds()
  saved_flash, saved_msg = 36, "SOUND SAVED"
  screen_dirty = true
end

local function factory_sound()
  local i = params:get("virus")
  local v = VIR.list[i]
  -- anything to undo? (a saved sound, or tweaks not saved yet)
  local f = v.factory
  local same = not v.custom and params:get("root") == f.root and params:get("division") == f.division
    and math.abs(params:get("release") - f.release) < 0.005 and math.abs(params:get("cutoff") - f.cutoff) < 0.5
    and params:get("pw") == f.pw
    and (not f.scale or musicutil.SCALES[params:get("scale")].name == f.scale)
  v.sound, v.custom = {}, nil
  for k, x in pairs(v.factory) do v.sound[k] = x end
  write_sounds()
  local keep = params:string("personality")
  params:set("personality", 1)
  apply_personality(i)
  params:set("personality", keep == "manual" and 2 or 1)
  saved_flash, saved_msg = 36, same and "NO CHANGES" or "FACTORY"
  screen_dirty = true
end

local function resync_engine()
  engine.release(params:get("release"))
  engine.pw(params:get("pw") / 100)
end

local function degree_note(d)
  local n = scale_notes[util.clamp(d, 1, #scale_notes)]
  return n
end

local function note_off_later(note, ch, units)
  clock.run(function()
    clock.sleep(clock.get_beat_sec() * DIVS[params:get("division")] * units * params:get("gate") / 100)
    if midi_out then midi_out:note_off(note, 0, ch) end
  end)
end

local function synth_on() return params:string("sound_source") ~= "sample" end
local function sample_on() return params:string("sound_source") ~= "synth" end

local function play(notes, gc, accent, units, chaos)
  if #notes == 0 then return end
  local out = params:string("output")
  local amp = params:get("amp") * (accent and 1.35 or 1)
  if out ~= "midi" and synth_on() then
    local spice = params:get("gc_spice") / 100
    local cut = params:get("cutoff") * 2 ^ ((gc - 0.5) * 2 * spice)
    cut = cut * gene_tone
    cut = cut * (0.5 + 0.5 * gap_level)
    amp = amp * gap_level
    if chaos then
      cut = 80 * 2 ^ (math.random() * 7)
      engine.release(0.03 * 2 ^ (math.random() * 7))
      engine.pw(math.random())
      amp = params:get("amp") * (0.4 + math.random())
    end
    engine.pan(util.clamp(params:get("pan") + pan_now, -1, 1))
    engine.cutoff(util.clamp(cut, 50, 12000))
    if not sample_on() then ARC.cut = cut end
    engine.amp(util.clamp(amp / math.sqrt(#notes), 0, 1))
    for _, n in ipairs(notes) do engine.hz(musicutil.note_num_to_freq(n)) end
  end
  if out ~= "audio" and midi_out then
    local ch = params:get("midi_ch")
    local vel = accent and 127 or 96
    vel = math.max(1, math.floor(vel * (0.4 + 0.6 * gap_level)))
    for _, n in ipairs(notes) do
      n = util.clamp(math.floor(n + 0.5), 0, 127)
      if chaos then vel = math.random(30, 127) end
      midi_out:note_on(n, vel, ch)
      note_off_later(n, ch, units)
    end
  end
end

-- HIV's second voice: same strand, shifted one letter (a second reading frame)
local function play2(notes, units)
  if #notes == 0 then return end
  local out = params:string("output")
  if out ~= "midi" and synth_on() then
    engine.pan(util.clamp(params:get("pan") + pan2, -1, 1))
    engine.amp(util.clamp(params:get("amp") * params:get("voice2_level") / 100, 0, 1))
    for _, n in ipairs(notes) do engine.hz(musicutil.note_num_to_freq(n)) end
  end
  if out ~= "audio" and midi_out then
    local ch = params:get("midi_ch2")
    for _, n in ipairs(notes) do
      midi_out:note_on(n, 80, ch)
      note_off_later(n, ch, units)
    end
  end
end

-- the reader ---------------------------------------------------------
local function gc_of(s)
  local _, c = s:gsub("[GC]", "")
  return #s > 0 and c / #s or 0.5
end

-- the tape: each read cuts to a slice of the live loop / sample -----------------
local function live_seconds()
  return ({ 1, 2, 4, 8 })[params:get("live_bars")] * 4 * clock.get_beat_sec()
end

-- the tape filter: the virus's own type, the cutoff following its synth cutoff,
-- moved by the genome (G/C opens it, genes colour it, mutations squelch, gaps close it)
local FILTER_KINDS = { "virus", "lowpass", "highpass", "bandpass", "off" }
local function tape_filter(gc, chaos)
  local v = VIR.list[params:get("virus")]
  local p = FX.P[v.id] or { "lp", 1, "room" }
  local pick = params:string("filter_type")
  local kind = pick == "virus" and p[1] or ({ lowpass = "lp", highpass = "hp", bandpass = "bp", off = "off" })[pick]
  if kind == "off" then FX.filter(2, "off"); FX.filter(3, "off"); return end
  local cut = params:get("cutoff")
  local fc = kind == "lp" and cut * 3 or (kind == "bp" and cut * 1.5 or cut * 0.3)
  local oct = params:get("filter_tone") / 100 * 3
  local g = params:get("filter_genome") / 100
  oct = oct + (gc - 0.5) * 2 * g                                     -- G/C-rich reads open it
  if last.gene then oct = oct + (((last.gene.n * 3) % 5) - 2) * 0.35 * g end -- each gene its own colour
  oct = oct - (1 - gap_level) * 2 * g                                -- quiet gaps close it
  local rq = p[2] * (1 - 0.85 * params:get("filter_res") / 100)
  if mutated_now and g > 0 then oct = oct + g; rq = rq * 0.35 end   -- fresh mutation: squelch
  if chaos then                                                     -- the VIROID: random sweeps
    kind = ({ "lp", "bp", "hp" })[math.random(3)]
    fc, oct, rq = 200 + math.random() * 6000, 0, 0.3 + math.random() * 1.2
  end
  fc = util.clamp(fc * 2 ^ oct, 40, 16000)
  ARC.cut = fc
  rq = util.clamp(rq, 0.08, 4)
  FX.filter(2, kind, fc, rq)
  FX.filter(3, kind, fc, rq)
end

-- reverb sends: the virus's room, swelling into gene gaps and STOPs / rests
local throw = false
local function reverb_step()
  if params:string("fx_reverb") == "off" then FX.sends(0, 0, 0); return end
  local v = VIR.list[params:get("virus")]
  local p = FX.P[v.id] or { "lp", 1, "room" }
  local room = params:string("fx_reverb") == "virus room" and p[3] or params:string("fx_reverb")
  local amt = params:get("fx_reverb_amount") / 100 * FX.ROOMS[room].send
  local g = params:get("fx_reverb_genome") / 100
  local target = (1 - gap_level) * 1.5 * g + (throw and 1.5 * g or 0)
  rev_glide = rev_glide + util.clamp(target - rev_glide, -0.15, 0.3)
  local swell = 1 + rev_glide
  FX.sends(util.clamp(amt * params:get("fx_rev_synth") / 100 * swell, 0, 1),
    util.clamp(amt * params:get("fx_rev_tape") / 100 * swell, 0, 1),
    util.clamp(amt * params:get("fx_rev_live") / 100, 0, 1))
end

-- the delay: most reads stay dry; now and then the dice throw a few slices in
-- (1-3 reads at a time), and they echo in the virus's own time + feedback
local throw_left = 0
local DELAY_TIMES = { "virus", "1/16", "1/8T", "1/8", "3/16", "1/4", "3/8" }
local function delay_step(chaos)
  local on = sample_on() and params:get("delay_level") > 0
  if not on then SAMP.delay_door(false); SAMP.delay_level(0); throw_left = 0; return end
  local v = VIR.list[params:get("virus")]
  local p = FX.D[v.id] or { 0.5, 0.5 }
  local open = false
  if throw_left > 0 then
    throw_left, open = throw_left - 1, true
  else
    local chance = params:get("delay_throws") / 100 * (mutated_now and 2 or 1)
    if chaos then chance = 0.6 end
    if math.random() < chance then
      throw_left, open = math.random(0, 2), true
      -- ping-pong: the echoes land on the other side from where the slice is
      if params:string("delay_pingpong") == "on" then
        local dp = -pan_now
        if math.abs(dp) < 0.3 then dp = (math.random() < 0.5 and -0.7 or 0.7) * params:get("pan_width") / 100 end
        SAMP.delay_pan(util.clamp(dp, -1, 1))
      else
        SAMP.delay_pan(0)
      end
      if chaos then -- the VIROID: a new delay time on every throw
        SAMP.delay_time(FX.DELAY_BEATS[math.random(#FX.DELAY_BEATS)] * clock.get_beat_sec())
      end
    end
  end
  if GEST.throw then open = true end -- THROW gesture: everything goes in
  if not chaos then
    local ti = params:get("delay_time")
    local beats = ti == 1 and p[1] or FX.DELAY_BEATS[ti - 1]
    SAMP.delay_time(beats * clock.get_beat_sec())
  end
  -- feedback: -1 = the virus's own, else 0..100 %. 100% = nothing ever fades: a wall of noiz
  local fb = params:get("delay_fb")
  fb = fb < 0 and p[2] or fb / 100
  if GEST.wall then fb = 1 end -- WALL gesture: nothing fades
  SAMP.delay_fb(fb)
  SAMP.delay_level(params:get("delay_level") / 100)
  -- up near 100% the throws go in softer, so the wall builds instead of jumping
  SAMP.delay_door(open, fb > 0.9 and 1 - (fb - 0.9) * 6 or 1)
end

-- panning: each virus has its own character (lib/fx.lua). sets pan_now (synth + tape),
-- pan2 (HIV's second voice) and how fast the tape glides there
local PAN_CHARS = { "virus", "still", "rarely", "wander", "bounce", "letters", "split", "off" }
local function pan_step(str, start, chaos)
  local w = params:get("pan_width") / 100
  local v = VIR.list[params:get("virus")]
  local c = params:string("panning")
  if c == "virus" then c = FX.PAN[v.id] or "still" end
  local p, p2, slew = 0, nil, 0.02
  if c == "chaos" then -- the VIROID (unless you pick another character for it)
    p, slew = (math.random() * 2 - 1) * w, math.random() * 0.3
  elseif c == "rarely" then
    if math.random() < 0.07 then p = (math.random() < 0.5 and -1 or 1) * (0.6 + math.random() * 0.4) * w end
    slew = 0.005
  elseif c == "wander" then
    wander = wander + 0.05 + math.random() * 0.04
    p, slew = math.sin(wander) * w, 0.3
  elseif c == "bounce" then
    p, slew = (math.random() * 2 - 1) * w, 0.01
  elseif c == "letters" then
    local _, pur = str:gsub("[AG]", "")
    local _, pyr = str:gsub("[CUT]", "")
    if #str > 0 then p = (pyr - pur) / #str * w end
    slew = 0.03
  elseif c == "split" then
    slew = 0.15
    if form() == "frames" then
      p, p2 = -0.6 * w, 0.6 * w                       -- HIV: one voice each side
    elseif #cur.segs > 1 then
      local k, n = segment_of(wrap(start)), #cur.segs -- each segment its own place
      p = ((k - 1) / (n - 1) * 2 - 1) * w
    elseif last.gene then
      p = (last.gene.n % 2 == 0 and -0.6 or 0.6) * w  -- no segments: genes alternate sides
    end
  end
  pan_now, pan2, pan_slew = p, p2 or p, slew
end

apply_room = function()
  local s = params:string("fx_reverb")
  if s == "off" then FX.off(); return end
  FX.on()
  local p = FX.P[VIR.list[params:get("virus")].id] or { "lp", 1, "room" }
  FX.room(s == "virus room" and p[3] or s)
end

local function sample_cut(notes, notes2, deg, chaos, start, gc)
  if not sample_on() or SAMP.len <= 0 then return end
  local N = params:get("slices")
  local slice = ((deg or 1) - 1) % N
  if last.gene and params:string("gene_changes") ~= "no change" and form() ~= "sections" then
    slice = (slice + last.gene.n * 5) % N -- each gene leans on its own slices
  end
  -- the whole tape, or this section of it for the segmented viruses
  local ra, rb = 0, 1
  if form() == "sections" then
    local k = segment_of(wrap(start))
    ra, rb = (k - 1) / #cur.segs, k / #cur.segs
  end
  local L = SAMP.len
  local span = (rb - ra) * L
  local a = ra * L + span * slice / N
  local b = a + span / N
  local root = params:get("root")
  local rate = 1
  if params:string("sample_pitch") == "follows notes" and notes[1] then
    rate = 2 ^ (((notes[1] - root) % 12) / 12) -- in the virus's scale, within an octave
  end
  if dir() == -1 then rate = -rate end
  local lvl = params:get("sample_level") * (last.aug and 1.25 or 1) * gap_level
  if #notes == 0 then -- STOP codons and rests cut to silence...
    -- ...or, with the reverb on, leave a ghost of the slice to throw into the tail
    local throw_on = params:string("fx_reverb") ~= "off" and params:get("fx_reverb_genome") > 0
    lvl = throw_on and lvl * 0.12 * params:get("fx_reverb_genome") / 100 or 0
  end
  -- mangle: glitches, more likely where a letter just mutated
  local m = params:get("mangle") / 100
  if chaos then m = 1 end
  if m > 0 and math.random() < m * (mutated_now and 1 or 0.5) then
    -- which glitch: even odds, or this virus's own loaded dice (lib/glitch.lua)
    local r = GLITCH(VIR.list[params:get("virus")].id, params:string("glitch_pick") == "virus flavor")
    ARC.glitch = 6
    if r == "s" then b = a + (b - a) / 8                       -- stutter
    elseif r == "r" then rate = -rate                          -- reverse
    elseif r == "o" then rate = rate * (math.random() < 0.5 and 0.5 or 2) -- octave jump
    else                                                       -- somewhere else entirely
      local s2 = math.random(0, N - 1)
      a = ra * L + span * s2 / N; b = a + span / N
    end
  end
  if chaos then -- the VIROID: nothing makes sense
    rate = (0.25 + math.random() * 3.5) * (math.random() < 0.4 and -1 or 1)
    if #notes > 0 then lvl = params:get("sample_level") * (0.4 + math.random() * 0.8) end
  end
  tape_filter(gc or 0.5, chaos)
  SAMP.pan(2, pan_now, pan_slew)
  SAMP.pan(3, pan2, pan_slew)
  SAMP.cut(2, a, b, rate, util.clamp(lvl, 0, 1.5))
  -- HIV's second voice: its own playhead, across the tape, an octave down
  if notes2 and #notes2 > 0 then
    local s2 = (slice + N // 2) % N
    local a2 = ra * L + span * s2 / N
    SAMP.cut(3, a2, a2 + span / N, rate * 0.5, util.clamp(lvl * params:get("voice2_level") / 100, 0, 1.5))
  else
    SAMP.mute(3)
  end
end

-- find the next AUG from pos without mutating anything
local function scan_for_start()
  local n, d = #cur.seq, dir()
  for k = 0, n - 1 do
    local i = wrap(pos + k * d)
    if sense(base_at(i)) == "A" and sense(base_at(i + d)) == "U"
      and sense(base_at(i + 2 * d)) == "G" then
      return i
    end
  end
  return nil
end

local function step()
  local win = params:get("window")
  local ribo = params:string("read_mode") == "ribosome"
  local notes, label, stop, aug = {}, "", false, false
  local first_deg
  mutated_now = false

  local real = params:string("ribo_genes") == "real genes" and has_genes() and form() ~= "chaos"
  if ribo then
    win = math.max(3, win - win % 3)
    if translating and real then -- left the gene? hunt for the next one
      local gn = gene_at(wrap(pos))
      if not gn or gn.n ~= translating then translating = false end
    end
    if not translating then
      local from = (gstrand == "-" and ghi) or (wrap(pos) - 1)
      gstrand, ghi = nil, nil
      if real then
        local s, it = next_gene_start(from)
        if s then
          pos = s; translating = it.n; gstrand = it.strand; found_flash = 8
          ghi = it.strand == "-" and it.b or nil
        end
      else
        local s = scan_for_start()
        if s then pos = s; translating = true; found_flash = 8 end
      end
    end
  end

  local d = dir()
  local start = pos
  local letters = {}
  for k = 0, win - 1 do letters[k + 1] = sense(read_letter(pos + k * d)) end
  local str = table.concat(letters)
  pos = wrap(pos + win * d)
  if GEST.stut then pos = start end -- STUT gesture: read the same spot again
  if GR.loop_lo and (pos < GR.loop_lo or pos > GR.loop_hi) then
    pos = d == 1 and GR.loop_lo or GR.loop_hi -- grid loop: stay inside it
  end

  -- flu: which section (segment slot) are we in?
  local shift = 0
  if form() == "sections" then
    local sec = segment_of(wrap(start))
    if sec ~= last.section then section_flash = 10 end
    last.section = sec
    shift = PROGRESSION[(sec - 1) % #PROGRESSION + 1]
  end
  -- gene map: which gene is this?
  local gene = gene_at(wrap(start))
  if (gene and gene.n) ~= (last.gene and last.gene.n) and has_genes() then gene_flash = 8 end
  last.gene = gene
  local changes = params:string("gene_changes")
  gene_tone, gene_gap = 1, false
  if gene and form() ~= "sections" then
    if changes == "transposes" then
      shift = shift + GENE_SHIFT[(gene.n - 1) % #GENE_SHIFT + 1]
    elseif changes == "changes tone" then
      gene_tone = 2 ^ (((gene.n * 5) % 7 - 3) / 3)
    end
  end
  local gaps = params:string("gene_gaps")
  if not gene and has_genes() and gaps ~= "play" then gene_gap = true end
  -- quiet gaps: each gap has its own depth (short gaps barely dip), and the level glides
  local target = 1
  if gene_gap and gaps == "quiet" then
    local k, len = gap_here(wrap(start))
    local depth = 0.35 + 0.5 * ((k * 37) % 11) / 10          -- 0.35 .. 0.85, differs per gap
    local short = math.max(0, 1 - len / 120)                 -- under ~120 letters: shallower
    target = depth + (1 - depth) * short
  end
  gap_level = gap_level + util.clamp(target - gap_level, -0.12, 0.12)
  local function dn(deg)
    if not first_deg then first_deg = deg end
    return degree_note(deg + shift)
  end

  if win == 1 then
    notes[1] = dn(G.BASE_DEGREE[str])
    label = str
  elseif win == 2 then
    notes[1] = dn(G.pair_degree(letters[1], letters[2]))
    label = str
  else
    for c = 0, math.floor(win / 3) - 1 do
      local codon = str:sub(c * 3 + 1, c * 3 + 3)
      local aa = G.translate(codon)
      if c == 0 then label = G.AA_NAME[aa] end
      if aa == "*" then
        stop = true
        if ribo then translating = false end
        break
      end
      if codon == "AUG" then aug = true end
      notes[#notes + 1] = dn(G.AA_DEGREE[aa])
    end
  end

  -- HIV: the same letters read one step over, an octave down
  local notes2, codon2 = {}, ""
  if form() == "frames" and win >= 3 then
    for k = 1, 3 do codon2 = codon2 .. sense(base_at(start + k * d)) end
    local aa2 = G.translate(codon2)
    if aa2 ~= "*" then notes2[1] = dn(G.AA_DEGREE[aa2]) - 12 end
  end

  last.start, last.len, last.letters, last.label = start, win, str, label
  last.notes, last.stop, last.aug = notes, stop, aug
  last.codon2, last.notes2 = codon2, notes2

  local wrapped = (d == 1 and pos < start) or (d == -1 and pos > start)
  if params:string("at_end") == "stop" and wrapped then
    playing = false
  end

  -- letter rhythm: G/C bond with three hydrogen bonds, A/U with two.
  -- strong (G/C-rich) reads ring longer, weak (A/U-rich) reads are short
  local units = 1
  if params:string("rhythm") == "bonds" then
    local head = str:sub(1, math.min(3, #str))
    local _, gcn = head:gsub("[GC]", "")
    if #head == 3 then
      units = ({ 1, 1, 2, 3 })[gcn + 1]
    elseif gcn == #head then
      units = 2
    end
  end
  if gene_gap and params:string("gene_gaps") == "silent" then
    notes, notes2 = {}, {}
    last.notes, last.notes2 = notes, notes2
  end

  -- the VIROID makes no sense: random pitches (not even in tune), random rhythm
  local chaos = form() == "chaos"
  if chaos then
    notes = {}
    for k = 1, math.random(1, 3) do notes[k] = 33 + math.random() * 60 end
    if math.random() < 0.15 then notes = {} end
    label, stop, aug = "NOIZ", math.random() < 0.08, math.random() < 0.1
    units = math.random(1, 4)
    last.notes, last.stop, last.aug, last.label = notes, stop, aug, label
  end
  last.chaos = chaos
  last_units = units

  pan_step(str, start, chaos)
  play(notes, gc_of(str), aug, units, chaos)
  play2(notes2, units)
  throw = #notes == 0
  sample_cut(notes, notes2, first_deg, chaos, start, gc_of(str))
  reverb_step()
  delay_step(chaos)
  if #notes > 0 then pulse = 1.1 end
  if stop then flinch = 0.35 end
  screen_dirty = true
  return units
end

local function all_notes_off()
  if midi_out then
    for n = 0, 127 do
      midi_out:note_off(n, 0, params:get("midi_ch"))
      midi_out:note_off(n, 0, params:get("midi_ch2"))
    end
  end
end

local function start_playing()
  playing = true
  screen_dirty = true
end

local function stop_playing()
  playing = false
  SAMP.stop()
  all_notes_off()
  screen_dirty = true
end

-- MIDI clock transport (works when PARAMS > CLOCK > source = midi or link)
function clock.transport.start()
  if params:string("on_start") == "restart" then reset_pos() end
  start_playing()
end

function clock.transport.stop()
  stop_playing()
end

-- point the tape at the live input or the chosen file
local function set_tape()
  if params:string("sample_input") == "sample file" then
    if not SAMP.file(params:get("sample_file")) then
      SAMP.len = 0
      print("noiz virus: no sample file chosen (or it can't be read)")
    end
  else
    SAMP.live(live_seconds())
  end
  screen_dirty = true
end

-- params ---------------------------------------------------------------
local function add_params()
  params:add_separator("noiz_virus", "noiz virus")
  params:add_option("virus", "virus", VIR.names, 1)
  params:set_action("virus", function(i) set_virus(i); apply_personality(i); resync_engine() end)
  params:add_option("personality", "virus sets sound", { "per virus", "manual" }, 1)
  params:add_trigger("save_sound", "save sound for this virus")
  params:set_action("save_sound", save_sound)
  params:add_trigger("factory_sound", "factory sound for this virus")
  params:set_action("factory_sound", factory_sound)
  params:add_option("rhythm", "rhythm", { "bonds", "even" }, 1)
  params:add_option("forms", "forms", { "on", "off" }, 1)
  params:set_action("forms", function() reset_pos(); resync_engine(); screen_dirty = true end)
  params:add_option("flu_sections", "section length",
    { "whole segment", "4 bars", "8 bars", "16 bars" }, 3)
  params:add_trigger("reassort", "reassort (segments)")
  params:set_action("reassort", reassort)
  params:add_number("voice2_level", "HIV voice 2 level", 0, 100, 70)
  params:add_number("window", "window (letters)", 1, 12, 3)
  params:add_option("read_mode", "read mode", { "raw", "ribosome" }, 1)
  params:add_control("mutation", "mutation %",
    controlspec.new(0, 50, "lin", 1, 0, "%"))
  params:add_option("division", "step", DIV_NAMES, 3)
  params:add_option("at_end", "at end of genome", { "loop", "stop" }, 1)
  params:add_option("on_start", "midi start", { "restart", "keep place" }, 1)
  params:add_trigger("restore", "restore genome")
  params:set_action("restore", restore_genome)

  params:add_separator("strain_sep", "strains")
  params:add_number("strain_slot", "strain slot", 1, 8, 1,
    function(p) return p:get() .. (strain_exists(p:get()) and " (saved)" or " (empty)") end)
  params:add_trigger("save_strain", "save strain")
  params:set_action("save_strain", save_strain)
  params:add_trigger("load_strain", "load strain")
  params:set_action("load_strain", load_strain)
  params:add_trigger("jump", "jump to random spot")
  GR.jump = function()
    pos = math.random(#cur.seq); translating = false; screen_dirty = true
  end
  params:set_action("jump", GR.jump)

  params:add_separator("gene_sep", "gene map")
  params:add_option("gene_names", "gene names", { "on", "off" }, 1)
  params:add_option("gene_changes", "each gene", { "transposes", "changes tone", "no change" }, 1)
  params:add_option("gene_gaps", "between genes", { "quiet", "silent", "play" }, 1)
  params:add_option("ribo_genes", "ribosome reads", { "real genes", "any AUG" }, 1)

  params:add_separator("notes_sep", "notes")
  local scale_names = {}
  for i, s in ipairs(musicutil.SCALES) do scale_names[i] = s.name end
  local def = 1
  for i, n in ipairs(scale_names) do if n == "Minor Pentatonic" then def = i end end
  params:add_option("scale", "scale", scale_names, def)
  params:set_action("scale", build_scale)
  params:add_number("root", "root note", 24, 72, 48,
    function(p) return musicutil.note_num_to_name(p:get(), true) end)
  params:set_action("root", build_scale)

  params:add_separator("synth_sep", "synth")
  params:add_option("output", "output", { "audio", "midi", "audio + midi" }, 3)
  params:add_control("amp", "amp", controlspec.new(0, 1, "lin", 0, 0.5, ""))
  params:add_control("cutoff", "cutoff", controlspec.new(50, 5000, "exp", 0, 900, "hz"))
  params:add_control("gc_spice", "GC brightness", controlspec.new(0, 100, "lin", 1, 50, "%"))
  params:add_control("release", "release", controlspec.new(0.05, 4, "exp", 0, 0.8, "s"))
  params:set_action("release", function(x) engine.release(x) end)
  params:add_control("pw", "pulse width", controlspec.new(1, 99, "lin", 1, 50, "%"))
  params:set_action("pw", function(x) engine.pw(x / 100) end)
  params:add_control("gain", "gain", controlspec.new(0, 4, "lin", 0, 1, ""))
  params:set_action("gain", function(x) engine.gain(x) end)
  params:add_control("pan", "pan", controlspec.new(-1, 1, "lin", 0, 0, ""))
  params:set_action("pan", function(x) engine.pan(x) end)

  params:add_separator("sample_sep", "sample (softcut)")
  params:add_option("sound_source", "sound source", { "synth", "sample", "synth + sample" }, 1)
  params:set_action("sound_source", function() if not sample_on() then SAMP.stop() end; screen_dirty = true end)
  params:add_option("sample_input", "sample input", { "live input", "sample file" }, 1)
  params:set_action("sample_input", function() set_tape() end)
  params:add_file("sample_file", "sample file", _path.audio)
  params:set_action("sample_file", function(path)
    if params:string("sample_input") == "sample file" then set_tape() end
  end)
  params:add_option("live_bars", "live loop length", { "1 bar", "2 bars", "4 bars", "8 bars" }, 2)
  params:set_action("live_bars", function() if SAMP.source == "live" then SAMP.live(live_seconds()) end end)
  params:add_option("live_freeze", "live loop", { "recording", "frozen" }, 1)
  params:set_action("live_freeze", function(x) SAMP.freeze(x == 2); screen_dirty = true end)
  params:add_number("slices", "slices", 2, 64, 16)
  params:add_option("sample_pitch", "sample pitch", { "follows notes", "fixed" }, 1)
  params:add_control("sample_level", "sample level", controlspec.new(0, 1.5, "lin", 0, 0.8, ""))
  params:add_control("mangle", "mangle", controlspec.new(0, 100, "lin", 1, 0, "%"))
  params:add_option("glitch_pick", "glitch pick", { "virus flavor", "even odds" }, 1)

  -- MIX: the dry live input (what comes in, straight through) against everything
  -- noiz virus makes (synth + tape). the live loop keeps recording even with the
  -- dry input turned all the way down.
  params:add_separator("mix_sep", "mix")
  params:add_control("mix_live", "live input", controlspec.new(0, 100, "lin", 1, 100, "%"))
  params:set_action("mix_live", function() apply_mix() end)
  params:add_control("mix_virus", "noiz virus", controlspec.new(0, 100, "lin", 1, 100, "%"))
  params:set_action("mix_virus", function() apply_mix() end)
  params:add_control("mix_xfade", "live <> virus", controlspec.new(-100, 100, "lin", 1, 0, ""))
  params:set_action("mix_xfade", function() apply_mix() end)

  -- FX: each virus has its own tape filter and its own room; the genome plays them
  params:add_separator("fx_sep", "fx")
  params:add_option("filter_type", "tape filter", FILTER_KINDS, 1)
  params:add_control("filter_tone", "filter tone", controlspec.new(-100, 100, "lin", 1, 0, ""))
  params:add_control("filter_res", "filter resonance", controlspec.new(0, 100, "lin", 1, 0, "%"))
  params:add_control("filter_genome", "genome moves filter", controlspec.new(0, 100, "lin", 1, 50, "%"))
  params:add_option("fx_reverb", "reverb", { "virus room", "small", "room", "hall", "cathedral", "off" }, 1)
  params:set_action("fx_reverb", function() apply_room() end)
  params:add_control("fx_reverb_amount", "reverb amount", controlspec.new(0, 100, "lin", 1, 35, "%"))
  params:add_control("fx_reverb_genome", "genome moves reverb", controlspec.new(0, 100, "lin", 1, 50, "%"))
  params:add_control("fx_rev_synth", "reverb: synth", controlspec.new(0, 100, "lin", 1, 100, "%"))
  params:add_control("fx_rev_tape", "reverb: tape", controlspec.new(0, 100, "lin", 1, 100, "%"))
  params:add_control("fx_rev_live", "reverb: live input", controlspec.new(0, 100, "lin", 1, 0, "%"))
  params:add_control("delay_throws", "delay throws", controlspec.new(0, 100, "lin", 1, 20, "%"))
  params:add_option("delay_time", "delay time", DELAY_TIMES, 1)
  params:add_number("delay_fb", "delay feedback", -1, 100, -1,
    function(p) local x = p:get(); return x < 0 and "virus" or (x .. "%") end)
  params:add_control("delay_level", "delay level", controlspec.new(0, 100, "lin", 1, 70, "%"))
  params:add_option("delay_pingpong", "delay ping-pong", { "on", "off" }, 1)
  params:add_separator("grid_sep", "grid")
  params:add_option("grid_orient", "grid orientation", { "portrait", "portrait flipped" }, 1)
  params:set_action("grid_orient", function() if GR.all then GR.all(0) end end)
  params:set_action("delay_pingpong", function(x) if x == 2 then SAMP.delay_pan(0) end end)
  params:add_option("panning", "panning", PAN_CHARS, 1)
  params:add_control("pan_width", "pan width", controlspec.new(0, 100, "lin", 1, 70, "%"))

  params:add_separator("midi_sep", "midi out")
  params:add_number("midi_dev", "midi device", 1, 16, 1)
  params:set_action("midi_dev", function(d) midi_out = midi.connect(d) end)
  params:add_number("midi_ch", "midi channel", 1, 16, 1)
  params:add_number("midi_ch2", "voice 2 channel", 1, 16, 2)
  params:add_number("gate", "gate %", 5, 100, 50)

  params:add_separator("visual_sep", "visual")
  params:add_control("spin", "spin speed", controlspec.new(0, 3, "lin", 0.05, 1, ""))
end

-- screen -------------------------------------------------------------
-- DNA viruses are read as RNA, but shown with T as they really are
local function shown(t)
  if VIR.list[params:get("virus")].dna then return (t:gsub("U", "T")) end
  return t
end

local function big_num(n)
  if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
  if n >= 100000 then return string.format("%dK", math.floor(n / 1000 + 0.5)) end
  return tostring(n)
end
local function draw_strand()
  local center = 11
  if params:string("gene_names") == "on" and has_genes() then
    -- the gene map along the strand: bright under genes, dark between, a tick where one begins
    for c = 0, 25 do
      local i = wrap(last.start + (c - center) * dir())
      local gn = gene_at(i)
      local prev = gene_at(wrap(i - dir()))
      screen.level(gn and 7 or 1)
      screen.move(c * 5 - 1, 54); screen.line(c * 5 + 4, 54); screen.stroke()
      if gn and (not prev or prev.n ~= gn.n) then
        screen.level(13); screen.move(c * 5 - 1, 52); screen.line(c * 5 - 1, 55); screen.stroke()
      end
    end
  else
    screen.level(2)
    screen.move(0, 54); screen.line(128, 54); screen.stroke()
  end
  for c = 0, 25 do
    local i = last.start + (c - center) * dir()
    local ch = sense(base_at(i))
    local x = c * 5
    local inwin = c >= center and c < center + last.len
    if inwin then
      if c == center then
        screen.level(playing and 15 or 6)
        screen.rect(x - 1, 56, last.len * 5 + 1, 8); screen.fill()
      end
      screen.level(0)
    else
      screen.level(c > center and 6 or 3)
    end
    screen.move(x, 62); screen.text(shown(ch))
    if cur.mut[wrap(i)] then
      if inwin then -- dark notch cut into the lit window
        screen.level(0); screen.rect(x, 63, 3, 1); screen.fill()
      else
        screen.level(12); screen.pixel(x + 1, 63); screen.fill()
      end
    end
  end
  if last.codon2 and last.codon2 ~= "" then -- HIV second frame, one letter over
    screen.level(playing and 12 or 5)
    screen.move((center + 1) * 5 - 1, 55); screen.line((center + 4) * 5 - 1, 55); screen.stroke()
  end
end

local function draw_panel()
  local v = VIR.list[params:get("virus")]
  local x = 64
  screen.level(15); screen.move(x, 7); screen.text(v.name)
  if v.custom then screen.level(6); screen.text("*") end

  screen.level(5); screen.move(x, 14)
  if mix_flash > 0 then
    -- L [----|--o----] V : where the crossfade sits (left = live, right = virus)
    local m = params:get("mix_xfade")
    screen.level(m <= 0 and 15 or 6); screen.move(x, 14); screen.text("L")
    screen.level(m >= 0 and 15 or 6); screen.move(x + 58, 14); screen.text("V")
    -- track + centre tick as pixel blocks (lines on whole pixels smear half a pixel left)
    screen.level(3); screen.rect(x + 7, 11, 49, 1); screen.fill()
    screen.level(6); screen.rect(x + 31, 9, 1, 5); screen.fill()
    local px = math.floor(x + 31 + m * 0.23 + 0.5)
    screen.level(15); screen.rect(px - 1, 8, 3, 6); screen.fill()
  elseif saved_flash > 0 then
    screen.level(15); screen.text(saved_msg)
  else
    local names = params:string("gene_names") == "on" and has_genes()
    local gname = names and last.gene and last.gene.name
    if #cur.segs > 1 then
      if section_flash > 0 then screen.level(15) end
      local sg = cur.segid[segment_of(wrap(last.start))] .. "/" .. #cur.segs
      screen.text(gname and sg or ("SEG " .. sg))
    elseif not gname then
      screen.level(names and 3 or 5)
      screen.text(v.kind)
    end
    if gname then
      screen.level(gene_flash > 0 and 15 or 11)
      if #cur.segs > 1 then screen.text(" ") end
      screen.text(gname)
    end
  end
  -- form tag, right side of line 2
  local f = form()
  local tag = (f == "reverse" and "<<<")
    or (f == "frames" and "DUO")
    or (f == "sections" and is_reassorted() and "MIX")
    or (f == "chaos" and "???") or nil
  if tag and saved_flash <= 0 and mix_flash <= 0 then
    screen.level(f == "sections" and section_flash > 0 and 15 or 7)
    screen.move(127, 14); screen.text_right(tag)
  end
  if sample_on() then -- the tape: REC (live), FRZ (frozen) or SMP (file)
    local t = SAMP.source == "file" and "SMP" or (SAMP.frozen and "FRZ" or "REC")
    if SAMP.len <= 0 then t = "---" end
    screen.level(t == "REC" and 10 or 6); screen.move(0, 50); screen.text(t)
  end
  if cur.strain then -- playing one of your saved strains
    screen.level(9); screen.move(0, 20); screen.text("#" .. cur.strain)
  end
  if params:string("read_mode") == "ribosome" then
    screen.level(found_flash > 0 and 15 or (translating and 8 or 3))
    screen.move(0, 13); screen.text("RIBO")
  end

  -- the codon / letters being read
  screen.font_size(16)
  screen.level(15)
  screen.move(x, 30)
  local big = last.letters:sub(1, 3)
  screen.text(big ~= "" and shown(big) or "---")
  screen.font_size(8)
  if last.codon2 and last.codon2 ~= "" then -- HIV second frame
    screen.level(#last.notes2 > 0 and 7 or 3)
    screen.move(127, 30); screen.text_right(shown(last.codon2))
  end

  -- amino acid + notes
  screen.move(x, 38)
  if last.stop and #last.notes == 0 then
    screen.level(4); screen.text("STOP")
  else
    if last.len >= 3 then
      screen.level(last.aug and 15 or 11)
      screen.text(last.label .. " ")
    end
    screen.level(8)
    local s = ""
    for k, n in ipairs(last.notes) do
      if k > 3 then s = s .. "+"; break end
      if last.chaos then
        s = s .. "?? "
      else
        s = s .. musicutil.note_num_to_name(n, true) .. " "
      end
    end
    screen.text(s)
  end

  -- position
  screen.level(6); screen.move(x, 45)
  local n = #cur.seq
  screen.text(string.format(n > 99999 and "%07d" or "%05d", wrap(last.start)))
  screen.level(3); screen.text("/" .. big_num(n))

  -- window / mutation
  screen.level(4); screen.move(x, 52)
  screen.text("WIN " .. params:get("window"))
  screen.move(x + 32, 52)
  if mut_flash > 0 then screen.level(15) end
  screen.text("MUT " .. math.floor(params:get("mutation") + 0.5))
end

function redraw()
  if SPL.active then SPL.redraw() return end
  screen.clear()
  screen.aa(0)
  screen.font_face(1)
  screen.font_size(8)
  local v = VIR.list[params:get("virus")]
  v.draw(30, 26, angle, pulse, flinch)
  draw_panel()
  draw_strand()
  if not playing then
    screen.level(3); screen.move(0, 6); screen.text("II")
  end
  screen.update()
end

-- controls -------------------------------------------------------------
function enc(n, d)
  if SPL.active then SPL.skip() return end
  if n == 1 then
    params:delta("virus", d)
  elseif n == 2 then
    params:delta("window", d)
  elseif n == 3 and k1_held then
    params:delta("mix_xfade", d * 2)
    mix_flash = 24
  elseif n == 3 then
    params:delta("mutation", d)
  end
  screen_dirty = true
end

function key(n, z)
  if SPL.active then -- startup screen: any press derezzes it
    if z == 1 then SPL.skip() end
    if n == 1 then k1_held = false end
    return
  end
  if n == 1 then k1_held = (z == 1) return end
  if z == 0 then return end
  if n == 3 and k1_held then
    reassort()
  elseif n == 2 and k1_held then
    save_sound()
  elseif n == 2 then
    if playing then stop_playing() else start_playing() end
  elseif n == 3 then
    reset_pos()
    last.start = 1
    screen_dirty = true
  end
end

-- init ----------------------------------------------------------------
-- live input level -> monitor; noiz virus level -> engine (synth) + softcut (tape)
-- crossfade: centre = both full, left fades the virus out, right fades the input out
function apply_mix()
  local x = params:get("mix_xfade") / 100
  local live = params:get("mix_live") / 100 * (x > 0 and (1 - x) or 1)
  local virus = params:get("mix_virus") / 100 * (x < 0 and (1 + x) or 1)
  audio.level_monitor(live)
  audio.level_eng(virus)
  audio.level_cut(virus)
end

function init()
  math.randomseed(os.time())
  for _, v in ipairs(VIR.list) do
    if v.sound.scale and not scale_index(v.sound.scale) then
      print("noiz virus: no scale called '" .. v.sound.scale .. "' for " .. v.name)
    end
  end
  read_sounds()
  SAMP.init()
  FX.init()
  add_params()
  params:bang()
  build_scale()
  if not cur then set_virus(params:get("virus")) end

  -- the reader, locked to the norns clock (internal, midi, link or crow)
  clock.run(function()
    while true do
      local div = DIVS[params:get("division")]
      clock.sync(div)
      -- the live loop follows the tempo (MIDI clock can change it)
      if SAMP.source == "live" and params:string("sample_input") == "live input"
        and math.abs(live_seconds() - SAMP.len) > 0.02 then
        SAMP.live(live_seconds())
      end
      if playing then
        local bars = SEC_BARS[params:get("flu_sections")]
        if form() == "sections" and bars > 0 then
          sec_beats = sec_beats + div
          if sec_beats >= bars * 4 - 1e-6 then
            sec_beats = 0
            next_section()
          end
        end
        if hold > 0 then
          hold = hold - 1
        else
          hold = step() - 1
        end
      end
    end
  end)

  -- animation
  local frame = metro.init()
  frame.time = 1 / 15
  frame.event = function()
    angle = angle + 0.06 * params:get("spin")
    pulse = 1 + (pulse - 1) * 0.7
    flinch = 1 + (flinch - 1) * 0.8
    if mut_flash > 0 then mut_flash = mut_flash - 1 end
    if found_flash > 0 then found_flash = found_flash - 1 end
    if section_flash > 0 then section_flash = section_flash - 1 end
    if gene_flash > 0 then gene_flash = gene_flash - 1 end
    if saved_flash > 0 then saved_flash = saved_flash - 1 end
    if mix_flash > 0 then mix_flash = mix_flash - 1; screen_dirty = true end
    GR.redraw()
    ARC.redraw()
  end
  frame:start()

  -- the screen draws at 10 fps on its own metro (the spin speed is set by the
  -- 15 fps animation above, so it looks the same). While the norns screen is
  -- asleep nothing is drawn at all: the screensaver swaps screen.update for a
  -- do-nothing function, and drawing into it anyway can overflow the norns
  -- screen queue ("screen event Q full") and choke the CPU.
  local scr = metro.init()
  scr.time = 1 / 10
  scr.event = function()
    if SPL.active then return end
    if screen.update_default and screen.update ~= screen.update_default then return end
    redraw()
  end
  scr:start()
  GR.init()
  ARC.init()
  SPL.start(function() redraw() end)
end

function cleanup()
  SAMP.cleanup()
  -- hand the system mix (monitor / engine / softcut) back the way it was
  pcall(function() mix:bang() end)
  FX.sends(0, 0, 0)
  FX.cleanup()
  all_notes_off()
end


-- GRID ---------------------------------------------------------------------------
-- a 128 grid stood up in portrait: 8 across, 16 down (top = far from you).
--  r1-6  c1-7  viruses 1-42 (they breathe; the playing one is bright)
--        c8    SHIFT · RESET · SYNTH/LIVE · FREEZE · REASSORT · SAVE
--  r7          strains 1-8         r8-9   genome strand (16 spots)
--  r10-13      window · mutation · mangle · delay throws (8-step faders)
--  r14         live <> virus crossfade (4+5 together = centre)
--  r15 c2-7    gestures: THROW WALL STUT REV MUT! DRY (hold; SHIFT+pad latches)
--  r16         c1 RESTORE (hold 1 s) · c8 PLAY
local g = grid.connect()
GR.held, GR.latched = {}, {}
GR.shift_held, GR.shift_armed, GR.shift_t, GR.shift_used = false, false, 0, false
GR.flash, GR.restore_t, GR.t = {}, nil, 0
GR.strain_cache, GR.strain_cache_t = {}, -99
GR.glow = {}
for i = 1, 42 do GR.glow[i] = { ph = math.random() * 6.28, sp = 0.04 + math.random() * 0.1, fl = 0 } end

local FADERS = {
  [10] = { id = "window", vals = { 1, 2, 3, 4, 5, 6, 9, 12 }, zero = 3 },
  [11] = { id = "mutation", vals = { 0, 3, 6, 10, 16, 24, 36, 50 }, zero = 0 },
  [12] = { id = "mangle", vals = { 0, 5, 10, 20, 35, 50, 75, 100 }, zero = 0 },
  [13] = { id = "delay_throws", vals = { 0, 5, 10, 20, 30, 50, 75, 100 }, zero = 0 },
}
local XF = { -100, -70, -40, -15, 15, 40, 70, 100 }
local GNAMES = { "throw", "wall", "stut", "rev", "mut", "dry" } -- columns 2-7 of row 15

-- logical (c 1-8, r 1-16) <-> the grid's own (x 1-16, y 1-8)
local function to_xy(c, r)
  if params:get("grid_orient") == 1 then return r, 9 - c end
  return 17 - r, c
end
local function to_cr(x, y)
  if params:get("grid_orient") == 1 then return 9 - y, x end
  return y, 17 - x
end
local function led(c, r, l) local x, y = to_xy(c, r); g:led(x, y, math.floor(util.clamp(l, 0, 15))) end
function GR.all(l) if g.device then g:all(l); g:refresh() end end

local function shift_on() return GR.shift_held or GR.shift_armed end
local function used_shift() GR.shift_used = true; GR.shift_armed = false end

local function strain_has(n)
  if GR.t - GR.strain_cache_t > 30 then -- re-check the files every 2 s
    GR.strain_cache_t = GR.t
    for k = 1, 8 do GR.strain_cache[k] = strain_exists(k) end
  end
  return GR.strain_cache[n]
end

-- gestures: hold to play; MUT! and DRY borrow a param and give it back
local function gesture(name, on)
  if GEST[name] == on then return end
  GEST[name] = on
  if name == "mut" then
    if on then GR.mut_was = params:get("mutation"); params:set("mutation", 50)
    elseif GR.mut_was then params:set("mutation", GR.mut_was); GR.mut_was = nil end
  elseif name == "dry" then
    if on then GR.dry_was = params:get("mix_xfade"); params:set("mix_xfade", -100)
    elseif GR.dry_was then params:set("mix_xfade", GR.dry_was); GR.dry_was = nil end
    mix_flash = 24
  end
end

local function strand_key(i)
  local n = #cur.seq
  local a = math.floor((i - 1) * n / 16) + 1
  local b = math.floor(i * n / 16)
  if shift_on() then
    used_shift()
    if GR.loop_lo then GR.loop_lo, GR.loop_hi, GR.loop_first = nil, nil, nil -- SHIFT again: loop off
    else GR.loop_first = i end                                              -- loop starts here...
    return
  end
  if GR.loop_first then                                                     -- ...and ends here
    local i1, i2 = math.min(GR.loop_first, i), math.max(GR.loop_first, i)
    GR.loop_lo = math.floor((i1 - 1) * n / 16) + 1
    GR.loop_hi = math.floor(i2 * n / 16)
    GR.loop_first = nil
    pos = dir() == 1 and GR.loop_lo or GR.loop_hi
    translating = false
    return
  end
  if GR.loop_lo and (a > GR.loop_hi or b < GR.loop_lo) then GR.loop_lo, GR.loop_hi = nil, nil end
  pos = dir() == 1 and a or b
  translating = false
  hold = 0
  screen_dirty = true
end

function GR.key(x, y, z)
  if z == 1 then SPL.skip() end
  local c, r = to_cr(x, y)
  -- SHIFT: hold it, or tap it to arm the next press
  if c == 8 and r == 1 then
    if z == 1 then GR.shift_held, GR.shift_t, GR.shift_used = true, GR.t, false
    else
      GR.shift_held = false
      if not GR.shift_used and GR.t - GR.shift_t < 6 then GR.shift_armed = not GR.shift_armed end
    end
    return
  end
  -- gestures (hold; SHIFT + pad latches it, press again to let go)
  if r == 15 and c >= 2 and c <= 7 then
    local name = GNAMES[c - 1]
    if z == 1 then
      if shift_on() then used_shift(); GR.latched[name] = not GR.latched[name]
      elseif GR.latched[name] then GR.latched[name] = false end
      GR.held[name] = true
    else
      GR.held[name] = false
    end
    gesture(name, GR.held[name] or GR.latched[name] or false)
    return
  end
  -- crossfade row: remember what's held so 4+5 together = centre
  if r == 14 then
    GR.xf_held = GR.xf_held or {}
    GR.xf_held[c] = z == 1 or nil
    if z == 1 then
      if shift_on() then used_shift(); params:set("mix_xfade", 0)
      elseif (c == 4 and GR.xf_held[5]) or (c == 5 and GR.xf_held[4]) then params:set("mix_xfade", 0)
      else params:set("mix_xfade", XF[c]) end
      mix_flash = 24
    end
    return
  end
  -- RESTORE: hold for a second (so it can't happen by accident)
  if r == 16 and c == 1 then
    GR.restore_t = z == 1 and GR.t or nil
    return
  end
  if z == 0 then return end
  GR.flash[r * 10 + c] = 4

  if r <= 6 and c <= 7 then                                   -- viruses
    local n = (r - 1) * 7 + c
    if n <= #VIR.list then params:set("virus", n); GR.loop_lo, GR.loop_hi = nil, nil; GR.strain_cache_t = -99 end
  elseif c == 8 and r == 2 then                               -- RESET (SHIFT: ribosome on/off)
    if shift_on() then used_shift(); params:set("read_mode", params:get("read_mode") == 1 and 2 or 1)
    else reset_pos(); last.start = 1; screen_dirty = true end
  elseif c == 8 and r == 3 then                               -- SYNTH/LIVE (SHIFT: both)
    if shift_on() then used_shift(); params:set("sound_source", 3)
    else params:set("sound_source", params:get("sound_source") == 1 and 2 or 1) end
  elseif c == 8 and r == 4 then                               -- FREEZE the live loop
    params:set("live_freeze", params:get("live_freeze") == 1 and 2 or 1)
  elseif c == 8 and r == 5 then                               -- REASSORT (SHIFT: jump to a random spot)
    if shift_on() then used_shift(); GR.jump()
    else reassort() end
  elseif c == 8 and r == 6 then                               -- SAVE sound (SHIFT: factory sound)
    if shift_on() then used_shift(); factory_sound()
    else save_sound() end
  elseif r == 7 then                                          -- strains: load (SHIFT: save)
    params:set("strain_slot", c)
    if shift_on() then used_shift(); save_strain() else load_strain() end
    GR.strain_cache_t = -99
  elseif r == 8 or r == 9 then                                -- genome strand
    strand_key((r - 8) * 8 + c)
  elseif FADERS[r] then                                       -- faders (SHIFT: back to zero)
    local f = FADERS[r]
    if shift_on() then used_shift(); params:set(f.id, f.zero) else params:set(f.id, f.vals[c]) end
  elseif r == 16 and c == 8 then                              -- PLAY
    if playing then stop_playing() else start_playing() end
  end
  screen_dirty = true
end
g.key = function(x, y, z) GR.key(x, y, z) end

local function fader_pos(f)
  local v, best = params:get(f.id), 1
  for k, x in ipairs(f.vals) do if v >= x - 1e-6 then best = k end end
  return best
end

function GR.redraw()
  GR.t = GR.t + 1
  if not g.device then return end
  g:all(0)
  local sel = params:get("virus")
  -- the viruses breathe, each at its own pace, now and then a flicker
  for i = 1, #VIR.list do
    local o = GR.glow[i]
    o.ph = o.ph + o.sp
    if o.fl > 0 then o.fl = o.fl - 1 elseif math.random() < 0.004 then o.fl = 3 end
    local l = 1 + 4.5 * ((math.sin(o.ph) + 1) / 2) ^ 1.5 + (VIR.list[i].custom and 1 or 0) + (o.fl > 0 and 4 or 0)
    if i == sel then l = playing and (12 + (pulse - 1) * 30) or 11 end
    led((i - 1) % 7 + 1, (i - 1) // 7 + 1, l)
  end
  -- column 8
  local sh = shift_on()
  led(8, 1, GR.shift_held and 15 or (GR.shift_armed and (GR.t % 8 < 4 and 15 or 8) or 4))
  led(8, 2, params:get("read_mode") == 2 and 9 or 4)
  local src = params:get("sound_source")
  led(8, 3, src == 1 and 4 or (src == 2 and 15 or 9))
  led(8, 4, params:get("live_freeze") == 2 and 15 or 4)
  led(8, 5, #cur.segs > 1 and (is_reassorted() and 9 or 4) or 1)
  led(8, 6, VIR.list[sel].custom and 8 or 4)
  -- strains
  for k = 1, 8 do
    led(k, 7, cur.strain == k and 15 or (strain_has(k) and 6 or 1))
  end
  -- genome strand: where the reader is, the loop, and a dim line
  local n = #cur.seq
  local here = math.floor((wrap(pos) - 1) * 16 / n) + 1
  for i = 1, 16 do
    local a = math.floor((i - 1) * n / 16) + 1
    local b = math.floor(i * n / 16)
    local l = 2
    if GR.loop_lo and b >= GR.loop_lo and a <= GR.loop_hi then l = 6 end
    if GR.loop_first == i then l = GR.t % 6 < 3 and 12 or 6 end
    if i == here then l = 15 end
    led((i - 1) % 8 + 1, 8 + (i - 1) // 8, l)
  end
  -- faders
  for r, f in pairs(FADERS) do
    local p = fader_pos(f)
    for c = 1, 8 do led(c, r, c < p and 5 or (c == p and 13 or 1)) end
  end
  -- crossfade
  local xf = params:get("mix_xfade")
  local xc
  if math.abs(xf) < 8 then xc = 0 else
    xc = 1; for k = 1, 8 do if math.abs(XF[k] - xf) < math.abs(XF[xc] - xf) then xc = k end end
  end
  for c = 1, 8 do
    local l = (c == 4 or c == 5) and 4 or 1
    if xc == 0 and (c == 4 or c == 5) then l = 13 elseif c == xc then l = 15 end
    led(c, 14, l)
  end
  -- gestures
  for k, name in ipairs(GNAMES) do
    led(k + 1, 15, GEST[name] and 15 or (GR.latched[name] and 10 or 3))
  end
  -- RESTORE: fills up while you hold it
  if GR.restore_t then
    local held = GR.t - GR.restore_t
    led(1, 16, 4 + held * 0.75)
    if held >= 15 then restore_genome(); GR.restore_t = nil; GR.flash[161] = 6; strain_msg("RESTORED") end
  else
    led(1, 16, 3)
  end
  led(8, 16, playing and (10 + (pulse - 1) * 40) or 4)
  -- key-press flashes
  for k, t in pairs(GR.flash) do
    if t > 0 then led(k % 10, k // 10, 15); GR.flash[k] = t - 1 else GR.flash[k] = nil end
  end
  g:refresh()
end

function GR.init()
  grid.add = function() g = grid.connect() ; g.key = function(x, y, z) GR.key(x, y, z) end end
end

-- ARC -----------------------------------------------------------------------------
-- 4 rings (top to bottom). the setting shows dim, what the genome is doing shows bright.
-- main page:          1 genome scrub · 2 mutation · 3 filter tone · 4 live <> virus
-- SHIFT (held/armed): 1 delay feedback · 2 mangle · 3 reverb amount · 4 pan width
local a = arc.connect()
ARC.acc, ARC.t, ARC.mutmap, ARC.mutmap_t = { 0, 0, 0, 0 }, 0, {}, -99

local function page2() return GR.shift_held or GR.shift_armed end

-- turn: params move smoothly; one full turn ~ the whole range
local ARC_PARAMS = {
  { nil, { "mutation", 50 }, { "filter_tone", 200 }, { "mix_xfade", 200 } },
  { { "delay_fb", 101 }, { "mangle", 100 }, { "fx_reverb_amount", 100 }, { "pan_width", 100 } },
}
function ARC.delta(n, d)
  SPL.skip()
  if GR.shift_held then GR.shift_used = true end -- holding SHIFT to turn the arc doesn't arm it
  if not page2() and n == 1 then                 -- scrub through the genome
    ARC.acc[1] = ARC.acc[1] + d * #cur.seq / 1024
    local whole = ARC.acc[1] >= 0 and math.floor(ARC.acc[1]) or math.ceil(ARC.acc[1])
    if whole ~= 0 then
      ARC.acc[1] = ARC.acc[1] - whole
      pos = wrap(pos + whole); translating = false; hold = 0; screen_dirty = true
    end
    return
  end
  local spec = ARC_PARAMS[page2() and 2 or 1][n]
  if not spec then return end
  local id, range = spec[1], spec[2]
  local ok, p = pcall(function() return params:lookup_param(id) end)
  local step = (ok and p and p.controlspec and p.controlspec.step and p.controlspec.step > 0 and p.controlspec.step) or 1
  ARC.acc[n] = ARC.acc[n] + d * range / 900
  local whole = ARC.acc[n] >= 0 and math.floor(ARC.acc[n] / step) or math.ceil(ARC.acc[n] / step)
  if whole ~= 0 then
    ARC.acc[n] = ARC.acc[n] - whole * step
    params:set(id, params:get(id) + whole * step)
    if id == "mix_xfade" then mix_flash = 24 end
  end
end
a.delta = function(n, d) ARC.delta(n, d) end
function ARC.init()
  arc.add = function() a = arc.connect(); a.delta = function(n, d) ARC.delta(n, d) end end
end

local function aled(r, i, l) a:led(r, (i - 1) % 64 + 1, math.floor(util.clamp(l, 0, 15))) end
-- fill clockwise from the top for 0..1
local function fill(r, f, lo, hi)
  local n = math.floor(f * 64 + 0.5)
  for i = 1, 64 do aled(r, i, i <= n and lo or 0) end
  if n > 0 then aled(r, n, hi) else aled(r, 1, 5) end -- at zero: a marker at the top
end
-- -1..1 around the top: left = counter-clockwise, right = clockwise
local function bipolar(r, f, lo, hi)
  local n = math.floor(math.abs(f) * 28 + 0.5)
  for k = 0, n do aled(r, f >= 0 and 1 + k or 1 - k, k == n and hi or lo) end
end

function ARC.redraw()
  ARC.t = ARC.t + 1
  if ARC.glitch > 0 then ARC.glitch = ARC.glitch - 1 end
  for k = #ARC.sparks, 1, -1 do
    local sp = ARC.sparks[k]; sp.t = sp.t - 1
    if sp.t <= 0 then table.remove(ARC.sparks, k) end
  end
  while #ARC.sparks > 40 do table.remove(ARC.sparks, 1) end
  if not a.device then return end
  a:all(0)
  local n = #cur.seq
  if not page2() then
    -- 1: the genome as a circle. dim line, segments marked, mutations glitter, the reader a bright comet
    if ARC.t - ARC.mutmap_t > 15 then
      ARC.mutmap_t = ARC.t; ARC.mutmap = {}
      for i in pairs(cur.mut) do local k = math.floor((i - 1) * 64 / n) + 1; ARC.mutmap[k] = (ARC.mutmap[k] or 0) + 1 end
    end
    for i = 1, 64 do
      local l = 1
      if GR.loop_lo then
        local lo, hi = math.floor((GR.loop_lo - 1) * 64 / n) + 1, math.floor((GR.loop_hi - 1) * 64 / n) + 1
        if i >= lo and i <= hi then l = 3 end
      end
      if ARC.mutmap[i] then l = l + math.min(4, ARC.mutmap[i]) + ((ARC.t + i * 7) % 11 == 0 and 4 or 0) end
      aled(1, i, l)
    end
    for k = 2, #cur.segs do aled(1, math.floor((cur.segs[k] - 1) * 64 / n) + 1, 7) end
    for _, sp in ipairs(ARC.sparks) do aled(1, math.floor((sp.i - 1) * 64 / n) + 1, 6 + sp.t) end
    local here = math.floor((wrap(pos) - 1) * 64 / n) + 1
    local d = dir()
    aled(1, here - 2 * d, 3); aled(1, here - d, 7); aled(1, here, 15)
    -- 2: mutation fills the ring; fresh mutations spark inside the fill
    local m = params:get("mutation") / 50
    fill(2, m, 3, 10)
    local filled = math.floor(m * 64 + 0.5)
    for _, sp in ipairs(ARC.sparks) do
      if filled > 0 then aled(2, (sp.i * 13) % filled + 1, 6 + sp.t) end
    end
    -- 3: filter tone (dim, from the top) + the cutoff the genome is playing right now (bright, dancing)
    bipolar(3, params:get("filter_tone") / 100, 2, 6)
    local lf = (math.log(util.clamp(ARC.cut, 40, 16000)) - math.log(40)) / (math.log(16000) - math.log(40))
    local c = math.floor(lf * 56 + 0.5) + 37 -- low cutoff at bottom-left, high at bottom-right, around the top
    aled(3, c - 1, 6); aled(3, c, 15); aled(3, c + 1, 6)
    -- 4: crossfade from the top: left = live, right = virus; DRY breathes it
    local xf = params:get("mix_xfade") / 100
    bipolar(4, xf, 3, 13)
    aled(4, 1, 9)
    if GEST.dry then for i = 33, 64 do aled(4, i, 2 + 2 * math.sin(ARC.t * 0.3)) end end
  else
    -- 1: delay feedback; the top glows hot in wall-of-noiz land (90%+), WALL makes it roar
    local fb = params:get("delay_fb")
    local v = VIR.list[params:get("virus")]
    local f = fb < 0 and ((FX.D[v.id] or { 0.5, 0.5 })[2]) or fb / 100
    fill(1, f, fb < 0 and 2 or 4, fb < 0 and (ARC.t % 10 < 5 and 9 or 4) or 12)
    if f >= 0.9 or GEST.wall then
      for i = 58, 64 do aled(1, i, 8 + 7 * math.abs(math.sin(ARC.t * 0.25 + i))) end
    end
    -- 2: mangle; each glitch flashes the whole fill
    local mg = params:get("mangle") / 100
    fill(2, mg, 3 + ARC.glitch, 12)
    -- 3: reverb amount; the swells (gene gaps, STOPs) bloom past it
    local ra = params:get("fx_reverb_amount") / 100
    fill(3, ra, 4, 11)
    local bloom = math.floor(math.min(1, ra * (1 + rev_glide)) * 64 + 0.5)
    for i = math.floor(ra * 64 + 0.5) + 1, bloom do aled(3, i, 3 + 2 * math.sin(ARC.t * 0.4 + i * 0.5)) end
    -- 4: pan width (dim span around the top) + where the sound sits right now (bright)
    local w = params:get("pan_width") / 100
    bipolar(4, w, 2, 3); bipolar(4, -w, 2, 3)
    local pz = math.floor(util.clamp(pan_now, -1, 1) * 28 + 0.5)
    aled(4, 1 + pz, 15); aled(4, pz, 6); aled(4, 2 + pz, 6)
  end
  a:refresh()
end
