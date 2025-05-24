layout := { ; kbdlayout.info/kbdusx/scancodes
  B: '10 1E 2C 11 1F 2D 12 20 2E 13 21 2F 14 22 30 15 23 31 16 24 32 17 25 33 18 26 34 19 27 35 1A 28 136 1B 2B 148 1C',
  C: '10 56 1E 11 2C 1F 12 2D 20 13 2E 21 14 2F 22 15 30 23 16 31 24 17 32 25 18 33 26 19 34 27 1A 35 28 1B 136 2B 1C 148',
}

      Pause:: A.isActive := !A.isActive, icon(), tip()
     !Pause:: ExitApp
#HotIf A.isActive
        Esc:: bend(-2,, 4, 1), strum(0), DllCall('Sleep', u, 175), pitch(0)
        ^F1:: A.layout := A.layout = 'B' ? 'C' : 'B', Reload()
         F3:: strum(0), A.midiChannel -= A.midiChannel > 0, tip()
         F4:: strum(0), A.midiChannel += A.midiChannel < 15, tip()
        ^F3:: A.midiPort -= A.midiPort > 0, Reload()
        ^F4:: A.midiPort += A.midiPort < 63, Reload()
         F6:: A.velocityA += op('velocityA', -1), tip()
         F7:: A.velocityA += op('velocityA', +1), tip()
        !F6:: A.velocityB += op('velocityB', -1), tip()
        !F7:: A.velocityB += op('velocityB', +1), tip()
        F11:: A.firstNote -= A.firstNote > 0, tip()
        F12:: A.firstNote += A.firstNote + pressedKeys.Length-1 < 127, tip()
 ScrollLock:: (susKeys.Count) or A.bendRange := A.bendRange = 2 ? 12 : 2, tip()
       SC29:: cc3(0), tip()
          2:: strum 0
          3::
          4:: strum
          5::
          6::
          7::
          8:: midi 20 + A_ThisHotkey, 127, 0xB0
          9::
          0:: strum
          -:: cc1(op('cc1Value', -1)), tip()
          =:: cc1(op('cc1Value', +1)), tip()
         BS:: return
          1:: (A.isBend) ? bend(2)     : 0
       1 Up:: (A.isBend) ? bend(-2, 1) : 0
        Tab:: (A.isBend) ? bend(1)     : (octave(+1), tip())
     Tab Up:: (A.isBend) ? bend(-1, 1) : 0
   CapsLock:: (A.isBend) ? bend(-1)    : (octave(-1), tip())
CapsLock Up:: (A.isBend) ? bend(1, 1)  : 0
     LShift:: (A.isBend) ? bend(-2)    : 0
  LShift Up:: (A.isBend) ? bend(2, 1)  : 0
   Space Up:: (Z.palmMute) or strum(0)
      !RAlt:: A.isLatch := !A.isLatch, tip()
       RAlt:: A.isHold := !A.isHold, tip()
    AppsKey:: A.isBend := !A.isBend, tip()
       Left:: octave(-1), tip()
      Right:: octave(+1), tip()
       Down:: tip
#HotIf

#SingleInstance
KeyHistory !ListLines(0)
A_MaxHotkeysPerInterval := 1000

A := { isActive: 1,   bendRange:  2, velocityA: 110,
         isHold: 0,    midiPort:  0, velocityB:  90,
        isLatch: 0, midiChannel:  0,  cc1Value:   0,
         isBend: 1,   firstNote: 39,  cc3Value:   0, layout: 'B', }

Z := {anyKey: 0, palmMute: 0}

pressedKeys := []
susKeys := Map()
susMidi := Map()

regKey := 'HKCU\Software\' StrSplit(A_ScriptName, '.')[1]
for p in A.OwnProps()
  try A.%p% := RegRead(regKey, p)

wm := 'winmm\midiOut', u := 'UInt'
winmm := DllCall('LoadLibrary', 'Str', 'winmm')
DllCall wm 'Open', u '*', &midiOut:=0, u, A.midiPort, u,0,u,0,u,0

HotIf (*) => A.isActive
for sc in StrSplit(layout.%A.layout%, ' ')
  Hotkey('SC' sc, key.Bind(A_Index, 1)),
  Hotkey('SC' sc ' Up', key.Bind(A_Index, 0)),
  pressedKeys.Push(0)

(cc1(value:=0) =>
  midi(1, A.cc1Value += value, 0xB0))()

(cc3(init:=1) =>
  midi(3, init ? A.cc3Value : (A.cc3Value := 127 * !A.cc3Value), 0xB0))()

(icon() =>
  TraySetIcon('imageres.dll', 101 + A.isActive))()

(tip() => ToolTip(!A.isActive ? '' :
  abc(A.firstNote) ' ● '
  ' v' A.velocityA '/' A.velocityB ' ● port ' A.midiPort ':' A.midiChannel+1
  '`n' (A.isLatch ? 'latch' : 'hold') ' ' (A.isHold ? '✅' : '❌')
  ' bend ' A.bendRange ' ' (A.isBend ? '✅' : '❌')
  '`n' 'cc1 ' A.cc1Value ' ● cc3 ' (A.cc3Value ? '✅' : '❌')
  '`n' 'layout ' A.layout
))()

key(k, isDown, *) {
  if isDown {
    if pressedKeys[k]
      return
    pressedKeys[k] := 1
    (A.isHold and A.isLatch and !Z.anyKey) and strum(0)
    Z.anyKey++
    susKeys[k] := A.firstNote
    note := susKeys[k--] + k
    susMidi.Has(note) and play(-note)
    play note
    susMidi[note] := note
  } else {
    pressedKeys[k] := 0
    if !Z.anyKey or !susKeys.Has(k)
      return
    Z.anyKey--
    if A.isHold {
      (!A.isLatch and !Z.anyKey) and strum(0)
      return
    }
    note := susKeys.Delete(k--) + k
    play -note
    susMidi.Has(note) and susMidi.Delete(note)
  } chords
}

play(note) {
  palmMute := GetKeyState('Space','P')
  velocity := GetKeyState('BS','P') ? 127 : palmMute ? A.velocityB : A.velocityA
  midi Abs(note), (note > 0) * velocity
  Z.palmMute := palmMute and velocity = A.velocityB
}

strum(letRing:=1) {
  Critical -1
  for note in susMidi
    play(-note), letRing and play(note)
  (letRing) or (Z.anyKey := 0, susKeys.Clear(), susMidi.Clear())
  chords
}

bend(direction, reset:=0, stepDelay:=2, slideDown:=0) {
  Critical -1
  range := 8192 / (slideDown ? 2 : A.bendRange)
  limit := Round(8192 + range * direction * !reset, 1)
  while direction > 0 ? pitch() < limit : pitch() > limit
    pitch(range / 20 * direction),
    DllCall('Sleep', u, stepDelay)
  (A.bendRange != 2 and reset and pitch()) and pitch(0)
}

pitch(value?) {
  static stored := 8192
  if IsSet(value)
    stored := !value ? 8192 : stored + value,
    stored := stored < 0 ? 0 : stored > 16384 ? 16384 : Round(stored, 1),
    new := Round(stored) - (stored = 16384),
    midi(new & 0x7F, (new >> 7) & 0x7F, 0xE0)
  return stored
}

midi(note, velocity, command:=0x90) =>
  DllCall(wm 'ShortMsg', u, midiOut, u, command + A.midiChannel | note << 8 | velocity << 16)

op(var, inc:=1) => inc = 1
  ? (A.%var% = 120 ? 7 : 10) * (A.%var% < 127)
  : (A.%var% = 127 ? 7 : 10) * -!!A.%var%

octave(up:=1) =>
  A.firstNote += 12 * (up = 1 ? A.firstNote + pressedKeys.Length-1 + 12 <= 127 : -(A.firstNote - 12 >= 0))

abc(note, withOctave:=1) {
  static notes := StrSplit('C C♯ D E♭ E F F♯ G A♭ A B♭ B', ' ')
  return notes[Mod(note, 12) + 1] (withOctave ? note // 12 - 1 : '')
}

chords() {
  static pitches := StrSplit('n1 b2 n2 b3 n3 n4 b5 n5 b6 n6 b7 n7', ' ')
  _ := text := ''
  chord := []
  for x in (octaves := Map(), susMidi) {
    for y in susMidi
      (y > x and !Mod(y - x, 12)) and octaves[y] := 1
    octaves.Has(x) or chord.Push(x)
  }
  if chord.Length = 1
    text := abc(chord[1], 0)
  else
    loop chord.Length {
      n1:=b2:=n2:=b3:=n3:=n4:=b5:=n5:=b6:=n6:=b7:=n7 := 0
      for note in chord
        %pitches[Mod(Abs(note - chord[1]), 12) + 1]% := 1
      mi3  := b3 and !n3,
      no3  := !b3 and !n3 and n5,
      aug  := !b3 and n3 and !n5 and b6,
      dim  := mi3 and b5 and !n5 and !n7,
      dim7 := dim and n6,
      hdim := dim and !n6 and b7,
      sus2 := no3 and n2 and !n4,
      sus4 := no3 and !n2 and n4,
      is5  := no3 and chord.Length = 2,
      is6  := !dim and n6,
      is7  := !dim and (b7 or n7),
      is9  := !sus2 and n2,
      is11 := !sus4 and n4,
      text .= (
        abc(chord[1], 0)
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
      if A_Index = chord.Length
        break
      while chord[1] < chord[chord.Length]
        chord[1] += 12
      chord.Push chord.RemoveAt(1)
    }
  ToolTip text
}

exit(*) {
  for p in A.OwnProps()
    RegWrite A.%p%, 'REG_SZ', regKey, p
  DllCall wm 'Reset', u, midiOut
  DllCall wm 'Close', u, midiOut
  DllCall 'FreeLibrary', u, winmm
  ExitApp
} OnExit exit