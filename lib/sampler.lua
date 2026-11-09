-- noiz virus :: the tape side (softcut)
-- voice 1 records the live input into a rolling loop; voices 2 + 3 are the playheads;
-- voice 4 is the delay
-- the genome decides where they jump, how fast, which way, and how loud

local S = {}
local BUF = 1
local MAXLEN = 340 -- seconds of tape we use (softcut has ~350 per buffer)

S.len = 0          -- seconds of usable audio
S.source = "live"
S.frozen = false

local function voice_setup(v)
  softcut.enable(v, 1)
  softcut.buffer(v, BUF)
  softcut.level(v, 0)
  softcut.pan(v, 0)
  softcut.loop(v, 1)
  softcut.loop_start(v, 0)
  softcut.loop_end(v, 1)
  softcut.position(v, 0)
  softcut.rate(v, 1)
  softcut.play(v, 1)
  softcut.fade_time(v, 0.008)
  softcut.level_slew_time(v, 0.01)
  softcut.rate_slew_time(v, 0)
end

function S.init()
  if softcut.reset then softcut.reset() end
  audio.level_cut(1)
  audio.level_adc_cut(1)
  audio.level_eng_cut(0) -- don't record the synth, only the input
  softcut.buffer_clear()
  for v = 1, 3 do voice_setup(v) end
  -- voice 1: the recorder (silent, it only writes)
  softcut.level_input_cut(1, 1, 1)
  softcut.level_input_cut(2, 1, 1)
  softcut.rec_level(1, 1)
  softcut.pre_level(1, 0)
  softcut.rec(1, 0)
  S.delay_init()
end

-- record the input into a loop of this many seconds, over and over
function S.live(seconds)
  S.source = "live"
  S.len = math.min(seconds, MAXLEN)
  softcut.loop_start(1, 0)
  softcut.loop_end(1, S.len)
  softcut.play(1, 1)
  softcut.rec(1, S.frozen and 0 or 1)
end

function S.freeze(on)
  S.frozen = on
  if S.source == "live" then softcut.rec(1, on and 0 or 1) end
end

-- load a sound file (first channel) onto the tape
function S.file(path)
  if not path or path == "" or path:sub(-1) == "/" then return false end
  local ch, samples, rate = audio.file_info(path)
  if not samples or samples <= 0 or not rate or rate <= 0 then return false end
  softcut.rec(1, 0)
  local dur = math.min(samples / rate, MAXLEN)
  softcut.buffer_clear_channel(BUF)
  softcut.buffer_read_mono(path, 0, 0, dur, 1, BUF)
  S.source = "file"
  S.len = dur
  return true
end

-- play the stretch a..b (seconds) on voice v, looping it until the next cut
function S.cut(v, a, b, rate, level)
  if S.len <= 0 then return end
  if b < a + 0.005 then b = a + 0.005 end
  softcut.loop_start(v, a)
  softcut.loop_end(v, b)
  softcut.rate(v, rate)
  softcut.position(v, rate < 0 and b or a) -- backwards starts at the end
  softcut.level(v, level)
end

-- voice 4: the delay. it records the playheads (voices 2 + 3) into buffer 2 and plays
-- back from the same spot, so what you hear is one loop-length late. rec level is the
-- "door": open = this read gets thrown in, closed = the echoes just keep fading.
local DBUF, DV = 2, 4
S.dtime = 0
function S.delay_init()
  softcut.buffer_clear_channel(DBUF)
  softcut.enable(DV, 1)
  softcut.buffer(DV, DBUF)
  softcut.level(DV, 0)
  softcut.pan(DV, 0)
  softcut.rate(DV, 1)
  softcut.loop(DV, 1)
  softcut.loop_start(DV, 0)
  softcut.loop_end(DV, 0.5)
  softcut.position(DV, 0)
  softcut.fade_time(DV, 0.01)
  softcut.level_slew_time(DV, 0.05)
  softcut.recpre_slew_time(DV, 0.012) -- the door opens and closes without clicks
  softcut.level_input_cut(1, DV, 0)
  softcut.level_input_cut(2, DV, 0)
  softcut.level_cut_cut(2, DV, 1)
  softcut.level_cut_cut(3, DV, 1)
  softcut.rec_level(DV, 0)
  softcut.pre_level(DV, 0.5)
  softcut.play(DV, 1)
  softcut.rec(DV, 1)
  if softcut.post_filter_dry then -- echoes a little darker than the tape
    softcut.post_filter_dry(DV, 0); softcut.post_filter_lp(DV, 1)
    softcut.post_filter_fc(DV, 6000); softcut.post_filter_rq(DV, 1.5)
  end
end

function S.delay_time(sec)
  sec = math.max(0.02, math.min(sec, 8))
  if math.abs(sec - S.dtime) > 0.002 then
    S.dtime = sec
    softcut.loop_end(DV, sec)
  end
end
function S.delay_door(open, amt) softcut.rec_level(DV, open and (amt or 1) or 0) end
function S.delay_fb(fb) softcut.pre_level(DV, fb) end
function S.delay_level(l) softcut.level(DV, l) end
function S.delay_pan(x) softcut.pan_slew_time(DV, 0.05); softcut.pan(DV, x) end
-- pan a playhead; slew = how long it takes to get there
function S.pan(v, x, slew) softcut.pan_slew_time(v, slew or 0.02); softcut.pan(v, x) end

function S.mute(v) softcut.level(v, 0) end
function S.stop() softcut.level(2, 0); softcut.level(3, 0) end

function S.cleanup()
  softcut.rec(1, 0)
  softcut.rec(4, 0)
  for v = 1, 4 do softcut.level(v, 0); softcut.play(v, 0) end
end

return S
