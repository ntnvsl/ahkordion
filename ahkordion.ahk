A := {
  latch: false,    port: 1, tuning:  40, step: 2,
   hold: false, channel: 0,   vel1: 110,  cc1: 0,
   bend:  true,  octave: 0,   vel2:  90,  cc3: 0,
}

layout := (
  '10 1E 2C 11 1F 2D 12 20 2E 13 21 2F '
  '14 22 30 15 23 31 16 24 32 17 25 33 '
  '18 26 34 19 27 35 1A 28 136 1B 2B 148 '
  '1C'
)

      Pause:: ExitApp
        Esc:: bend(-2,, 4, true), mute(), DllCall('Sleep', u, 175), pitch(0)
         F3:: mute(), A.channel -= A.channel > 0, tip()
         F4:: mute(), A.channel += A.channel < 15, tip()
        #F3:: A.port -= A.port > 0, Reload()
        #F4:: A.port += A.port < 63, Reload()
         F6:: A.vel1 += set('vel1', -1), tip()
         F7:: A.vel1 += set('vel1'), tip()
        !F6:: A.vel2 += set('vel2', -1), tip()
        !F7:: A.vel2 += set('vel2'), tip()
        F11:: A.tuning -= A.tuning > 24, tip()
        F12:: A.tuning += A.tuning < 55, tip()
 ScrollLock:: (keys.Count) or A.step := A.step = 2 ? 12 : 2, tip()
       SC29:: cc3(false), tip()
          2:: mute
          3::
          4:: mute false
          5::
          6::
          7::
          8:: msg 20 + A_ThisHotkey, 127, 0xB0
          -:: cc1(set('cc1', -1)), tip()
          =:: cc1(set('cc1')), tip()
         BS:: return
          1:: (A.bend) ? bend(2)        : false
       1 Up:: (A.bend) ? bend(-2, true) : false
        Tab:: (A.bend) ? bend(1)        : (octave(1), tip())
     Tab Up:: (A.bend) ? bend(-1, true) : false
   CapsLock:: (A.bend) ? bend(-1)       : (octave(-1), tip())
CapsLock Up:: (A.bend) ? bend(1, true)  : false
     LShift:: (A.bend) ? bend(-2)       : false
  LShift Up:: (A.bend) ? bend(2, true)  : false
   Space Up:: (Z.pm) or mute()
      #LAlt:: A.hold := !A.hold, tip()
       RAlt:: A.latch := !A.latch, tip()
    AppsKey:: A.bend := !A.bend, tip()
       Left:: octave(-1), tip()
      Right:: octave(1), tip()
       Down:: octave(), tip()

#SingleInstance
KeyHistory !ListLines(!A_MaxHotkeysPerInterval := 1e3)

held := [], keys := Map(), midi := Map()
Z := {any: 0, pm: 0}

for p in A.OwnProps()
  try A.%p% := RegRead(rk := 'HKCU\Software\ahkordion', p)

for c in StrSplit(layout, ' ')
  Hotkey('SC' c, key.Bind(A_Index, false)),
  Hotkey('SC' c ' Up', key.Bind(A_Index, true)),
  held.Push(false)

wm := 'winmm\midiOut', u := 'UInt'
winmm := DllCall('LoadLibrary', 'Str', 'winmm')
DllCall wm 'Open', u '*', &(dev:=0), u, A.port, u, 0, u, 0, u, 0

(cc1(v:=0) =>
  msg(1, A.cc1 := (A.cc1 += v) < 0 ? 0 : A.cc1 > 127 ? 127 : A.cc1, 0xB0))()

(cc3(init:=true) =>
  msg(3, init ? A.cc3 : (A.cc3 := 127 * !A.cc3), 0xB0))()

(tip() => TrayTip(
  abc(A.tuning) ' (' A.octave+2 '-' A.octave+5 '), v' A.vel1 '/' A.vel2
  ', dev ' A.port ':' A.channel+1 '`n' (A.hold ? 'hold' : 'latch') ' '
  (A.latch ? '✅' : '❌') ' bend: ' A.step ' ' (A.bend ? '✅' : '❌') '`n'
  'cc1: ' A.cc1 ', cc3 ' (A.cc3 ? '✅' : '❌')
))()

key(k, up, *) {
  off(c) => c and !Z.any and mute()
  k2m(k, t, o) => --k + t + (o * 12)
  if !up {
    if held[k]
      return
    held[k] := true
    off A.latch
    Z.any++
    keys[k] := [A.tuning, A.octave]
    m := k2m(k, keys[k]*)
    midi.Has(m) and play(-m)
    play midi[m] := m
  } else {
    held[k] := false
    if !Z.any or !keys.Has(k)
      return
    Z.any--
    if A.latch {
      off A.hold
      return
    }
    play -m := k2m(k, keys.Delete(k)*)
    midi.Has(m) and midi.Delete(m)
  } chord
}

play(n) {
  pm := GetKeyState('Space','P')
  vel := GetKeyState('BS','P') ? 127 : pm ? A.vel2 : A.vel1
  msg Abs(n), (n > 0) * vel
  Z.pm := pm and vel = A.vel2
}

mute(hush:=true) {
  Critical -1
  for m in midi
    play(-m), hush or play(m)
  (hush) and (Z.any := 0, keys.Clear(), midi.Clear())
  chord
}

bend(semi, ret:=false, ms:=2, slide:=false) {
  Critical -1
  range := 8192 / (slide ? 2 : A.step)
  lim := Round(range * semi * !ret + 8192, 1)
  while semi > 0 ? pitch() < lim : pitch() > lim
    pitch(range / 20 * semi), DllCall('Sleep', u, ms)
  (A.step != 2 and ret and pitch()) and pitch(0)
}

pitch(v?) {
  static p := 8192
  if IsSet(v)
    p := !v ? 8192 : p + v,
    p := p < 0 ? 0 : p > 16384 ? 16384 : Round(p, 1),
    val := Round(p) - (p = 16384),
    msg(val & 0x7F, (val >> 7) & 0x7F, 0xE0)
  return p
}

msg(n, vel, cmd:=0x90) =>
  DllCall(wm 'ShortMsg', u, dev, u, cmd + A.channel | n << 8 | vel << 16)

set(p, dec:=0) => dec < 0
  ? -((A.%p% = 127 ? 7 : 10) * !!A.%p%)
  : (A.%p% = 120 ? 7 : 10) * (A.%p% < 127)

octave(o:=0) =>
  A.octave += !o ? -A.octave : o > 0 ? A.octave < 3 : -(A.octave > -2)

abc(n, oct:=true) {
  static abc := ['C','C♯','D','E♭','E','F','F♯','G','A♭','A','B♭','B']
  return abc[Mod(n, 12) + 1] (oct ? n // 12 - 1 : '')
}

chord() {
  static tones := ['n1','b2','n2','b3','n3','n4','b5','n5','b6','n6','b7','n7']
  _ := text := ''
  notes := []
  for m in (oct := Map(), midi) {
    for n in midi
      (n > m and !Mod(n - m, 12)) and oct[n] := true
    oct.Has(m) or notes.Push(m)
  }
  if (len := notes.Length) = 1
    text := abc(notes[1], false)
  else
    loop len {
      n1:=b2:=n2:=b3:=n3:=n4:=b5:=n5:=b6:=n6:=b7:=n7 := false
      for n in notes
        %tones[Mod(Abs(n - notes[1]), 12) + 1]% := true
      mi3  := b3 and !n3,
      no3  := !b3 and !n3 and n5,
      aug  := !b3 and n3 and !n5 and b6,
      dim  := mi3 and b5 and !n5 and !n7,
      dim7 := dim and n6,
      hdim := dim and !n6 and b7,
      sus2 := no3 and n2 and !n4,
      sus4 := no3 and !n2 and n4,
      is5  := no3 and len = 2,
      is6  := !dim and n6,
      is7  := !dim and (b7 or n7),
      is9  := !sus2 and n2,
      is11 := !sus4 and n4,
      text .= (
        abc(notes[1], false)
        (is5? 5 : aug? '+' : hdim? 'ø' : dim7? '⁰7' : dim? '⁰' : mi3? 'm' : _)
        (!is7 and is6 ? 6 : _)
        (n7 ? 'maj' : _)
        (is7 ? is6 ? 13 : is11 ? 11 : is9 ? 9 : 7 : _)
        (sus2 ? 'sus2' : sus4 ? 'sus4' : _)
        (' ' StrReplace(
          (b2 ? '(♭9)' : _)
          (!is7 and is9 ? '(9)' : _)
          (b3 and n3 ? '(♯9)' : _)
          (!is7 and is11 ? '(11)' : _)
          (!dim and b5 ? '(' (n5 ? '♯11' : '♭5') ')' : _)
          (!aug and b6 ? '(' (n5 ? '♭13' : '♯5') ')' : _)
          (b7 and (n7 or dim7) ? '(♭7)' : _)
        , ')(', ', ')) '`n'
      )
      if A_Index = len
        break
      while notes[1] < notes[len]
        notes[1] += 12
      notes.Push notes.RemoveAt(1)
    }
  ToolTip text
}

exit(*) {
  for p in A.OwnProps()
    RegWrite A.%p%, 'REG_SZ', rk, p
  DllCall wm 'Reset', u, dev
  DllCall wm 'Close', u, dev
  DllCall 'FreeLibrary', u, winmm
  ExitApp
} OnExit exit
