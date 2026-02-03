// ============================================================
// MIDI SNIFFER
// Lauscht auf ALLE Geräte, ALLE Kanäle und ALLE Nachrichtentypen.
// ============================================================

(
// 1. MIDI System starten & alles verbinden
MIDIClient.init;
MIDIIn.connectAll;

"--- MIDI SNIFFER GESTARTET ---".postln;
"Bewege jetzt Fader, Pedale oder drücke Tasten...".postln;
"".postln;


// ============================================================
// DEFINITIONEN (Was soll abgehört werden?)
// ============================================================

// 1. Control Change (CC)
// Das sind meistens Pedale, Drehregler, Fader.
MIDIdef.cc(\sniffCC, { |val, num, chan, src|
    ("🎛️ [CC]  Nummer: " ++ num.asString.padLeft(3) ++
     " | Wert: " ++ val.asString.padLeft(3) ++
     " | Kanal: " ++ chan ++
     " | Quelle: " ++ src).postln;
});

// 2. Program Change (PC)
// Das sind meistens Taster zum Umschalten von Presets (wie beim FCB1010).
MIDIdef.program(\sniffPC, { |val, chan, src|
    ("🔘 [PC]  Preset: " ++ val.asString.padLeft(3) ++
     " | Kanal: " ++ chan ++
     " | Quelle: " ++ src).postln;
});

// 3. Note On (Tastenanschlag)
// Manche Controller senden Noten statt CC/PC.
MIDIdef.noteOn(\sniffNoteOn, { |vel, num, chan, src|
    ("🎹 [NoteON]  Note: " ++ num ++
     " | Velocity: " ++ vel ++
     " | Kanal: " ++ chan).postln;
});

// 4. Note Off (Loslassen)
MIDIdef.noteOff(\sniffNoteOff, { |vel, num, chan, src|
    ("🎹 [NoteOFF] Note: " ++ num ++
     " | Kanal: " ++ chan).postln;
});

// 5. Pitch Bend (Rad)
MIDIdef.bend(\sniffBend, { |val, chan, src|
    ("〰️ [Bend]  Wert: " ++ val ++
     " | Kanal: " ++ chan).postln;
});

// 6. SysEx (System Exclusive)
// Das sind Rohdaten, die manche Chips (z.B. UnO Kemper) senden.
MIDIdef.sysex(\sniffSysEx, { |data, src|
    ("💾 [SysEx] Datenlänge: " ++ data.size ++
     " | Quelle: " ++ src).postln;
    // data.postln; // Entkommentieren, um die Hex-Daten zu sehen
});

)

// ============================================================
// STOP

MIDIdef.freeAll;