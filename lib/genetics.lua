-- noiz virus :: genetics
-- the standard genetic code + how letters become music

local G = {}

G.BASES = { "A", "C", "G", "U" }
G.BASE_INDEX = { A = 1, C = 2, G = 3, U = 4 }

-- standard codon table, built in UCAG-free "ACGU" order
local AA = "KNKNTTTTRSRSIIMIQHQHPPPPRRRRLLLLEDEDAAAAGGGGVVVV*Y*YSSSS*CWCLFLF"
G.CODON = {}
do
  local i = 1
  for _, b1 in ipairs(G.BASES) do
    for _, b2 in ipairs(G.BASES) do
      for _, b3 in ipairs(G.BASES) do
        G.CODON[b1 .. b2 .. b3] = AA:sub(i, i)
        i = i + 1
      end
    end
  end
end

G.AA_NAME = {
  A = "ALA", R = "ARG", N = "ASN", D = "ASP", C = "CYS", Q = "GLN", E = "GLU",
  G = "GLY", H = "HIS", I = "ILE", L = "LEU", K = "LYS", M = "MET", F = "PHE",
  P = "PRO", S = "SER", T = "THR", W = "TRP", Y = "TYR", V = "VAL", ["*"] = "STOP",
}

-- amino acids ordered roughly from small/water-loving-ish to big/charged,
-- so chemically similar ones land on neighbouring scale degrees
G.AA_ORDER = "GAVLIMFWPSTCYNQDEKRH"
G.AA_DEGREE = {}
for i = 1, #G.AA_ORDER do G.AA_DEGREE[G.AA_ORDER:sub(i, i)] = i end

-- single letters (WIN 1) spread across the scale like a chord
G.BASE_DEGREE = { A = 1, C = 3, G = 5, U = 8 }

-- dinucleotides (WIN 2): 16 combos -> degrees 1..16
function G.pair_degree(a, b)
  return (G.BASE_INDEX[a] - 1) * 4 + G.BASE_INDEX[b]
end

function G.translate(codon) return G.CODON[codon] end

return G
