-- noiz virus :: glitch flavors (loaded dice)
-- when mangle fires, each virus picks its glitch with its own odds:
--   s = stutter, r = reverse, o = octave jump, j = jump elsewhere (out of 10)
-- the timing and the pick stay random; only the odds lean.

local F = {
  sars_cov_2     = { s = 2, r = 2, o = 2, j = 4 }, -- slips frames on the ribosome
  influenza_a    = { s = 2, r = 1, o = 2, j = 5 }, -- reassorts its 8 segments
  hiv_1          = { s = 2, r = 5, o = 1, j = 2 }, -- reverse transcriptase
  ebola          = { s = 1, r = 5, o = 2, j = 2 }, -- already backwards: reverse flips it forwards
  tmv            = { s = 6, r = 1, o = 2, j = 1 }, -- 2130 identical coat proteins
  marburg        = { s = 2, r = 4, o = 3, j = 1 }, -- Ebola's cousin, with a twist
  rabies         = { s = 5, r = 2, o = 1, j = 2 }, -- the bullet: rapid fire
  polio          = { s = 3, r = 1, o = 4, j = 2 }, -- tiny and quick
  adeno          = { s = 1, r = 4, o = 3, j = 2 }, -- genes on both strands
  mimi           = { s = 5, r = 1, o = 1, j = 3 }, -- the giant: thick and repetitive
  sputnik        = { s = 3, r = 1, o = 1, j = 5 }, -- hijacks the giant's factory
  t4             = { s = 3, r = 1, o = 5, j = 1 }, -- spring-loaded tail
  lambda         = { s = 2, r = 3, o = 1, j = 4 }, -- slips in and out of the host DNA
  t7             = { s = 2, r = 1, o = 4, j = 3 }, -- the fast one
  phix174        = { s = 5, r = 2, o = 2, j = 1 }, -- overlapping genes, same letters twice
  ms2            = { s = 2, r = 2, o = 5, j = 1 }, -- little RNA phage
  variola        = { s = 4, r = 1, o = 3, j = 2 }, -- huge and heavy
  orf            = { s = 4, r = 3, o = 1, j = 2 }, -- the woven pox
  rotavirus_a    = { s = 2, r = 1, o = 1, j = 6 }, -- 11 segments
  astrovirus     = { s = 1, r = 2, o = 4, j = 3 }, -- the star
  norovirus      = { s = 6, r = 2, o = 1, j = 1 }, -- spreads like wildfire
  hsv1           = { s = 1, r = 3, o = 2, j = 4 }, -- hides, then wakes up somewhere else
  measles        = { s = 3, r = 4, o = 1, j = 2 },
  zika           = { s = 2, r = 1, o = 3, j = 4 },
  chikungunya    = { s = 4, r = 2, o = 2, j = 2 },
  lassa          = { s = 1, r = 6, o = 1, j = 2 }, -- ambisense: reads both ways
  hantaan        = { s = 3, r = 2, o = 1, j = 4 }, -- 3 segments
  hepb           = { s = 3, r = 5, o = 1, j = 1 }, -- reverse transcribes, overlapping genes
  hepd           = { s = 4, r = 2, o = 1, j = 3 }, -- a satellite riding on hep B
  hpv16          = { s = 2, r = 3, o = 4, j = 1 },
  pithovirus     = { s = 2, r = 1, o = 5, j = 2 }, -- frozen for 30,000 years
  pvy            = { s = 4, r = 1, o = 2, j = 3 }, -- hops plant to plant on aphids
  baculovirus    = { s = 4, r = 3, o = 2, j = 1 },
  maize_streak   = { s = 2, r = 4, o = 1, j = 3 }, -- ambisense DNA
  alfalfa_mosaic = { s = 1, r = 2, o = 2, j = 5 }, -- 3 RNAs in 3 shells
  ssv1           = { s = 2, r = 2, o = 4, j = 2 }, -- hot springs
  iridovirus6    = { s = 1, r = 3, o = 5, j = 1 }, -- iridescent shimmer
  torovirus      = { s = 2, r = 4, o = 2, j = 2 },
  pandoravirus   = { s = 2, r = 2, o = 1, j = 5 }, -- most of its genes are unknown
  sirv2          = { s = 5, r = 1, o = 3, j = 1 }, -- boiling acid
  m13            = { s = 5, r = 1, o = 2, j = 2 }, -- extruded, never stops
  pstvd          = { s = 1, r = 1, o = 1, j = 1 }, -- the VIROID ignores all of this anyway
}

local EVEN = { s = 1, r = 1, o = 1, j = 1 }
local ORDER = { "s", "r", "o", "j" }

-- returns "s", "r", "o" or "j"
return function(id, flavored)
  local w = (flavored and F[id]) or EVEN
  local total = w.s + w.r + w.o + w.j
  local x = math.random() * total
  for _, k in ipairs(ORDER) do
    x = x - w[k]
    if x < 0 then return k end
  end
  return "j"
end
