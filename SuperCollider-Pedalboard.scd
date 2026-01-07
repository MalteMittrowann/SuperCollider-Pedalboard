// ============================================================
// Full Effect Chain: Octaver -> Distortion/Flanger -> Looper
// ============================================================

// --- Server / Device (set before boot) -----------------------
ServerOptions.devices;   // list devices
ServerOptions.inDevices;
ServerOptions.outDevices;

(
    // Beispiel: Focusrite (falls zutreffend) — passe den Namen an
    s.options.device = "ASIO : Focusrite USB ASIO";

    // Mono input, Stereo output (duplizieren wir im Synth)
    s.options.numInputBusChannels = 1;
    s.options.numOutputBusChannels = 1;

    s.options.sampleRate = 48000;
)

s.boot;
s.waitForBoot({ "Server läuft!".postln });

// ------------------- Buffers für Looper --------------------
~loopLength = 8; // Länge des Loops in Sekunden
~buf = Buffer.alloc(s, s.sampleRate * ~loopLength, 2); // Stereo-Buffer

// ---------- OCTAVER ----------------------------------------

//////////////////////////////////////////////////////////////
// PitchShift-basiertes Octaver (verwendet float.pow für ratio)
//////////////////////////////////////////////////////////////
SynthDef(\tromboneOctaver, { |inBus = 0, outBus = 0, octave = 1, mix = 0.0|
    var input, shifted, ratio, mixSm;

    // smoothing für mix (sorgt für sanfte Crossfades bei set)
    mixSm = Lag.kr(mix, 0.05); // 50 ms Glättung

    input = SoundIn.ar(inBus); // mono Input

    // ratio: 1 Oktave ↓ = 0.5, 2 Oktaven ↓ = 0.25, ...
    ratio = 1.0 / 2.0.pow(octave); // 2.0 (float) vermeidet parser-probleme

    // PitchShift: windowSize ~0.02–0.05 brauchbar für Brass
    shifted = PitchShift.ar(
        input,
        windowSize: 0.04,
        pitchRatio: ratio,
        timeDispersion: 0.0
    );

    // Mix + duplicate auf stereo
    Out.ar(outBus, (input * (1 - mixSm) + shifted * mixSm).dup);
}).add;


//////////////////////////////////////////////////////////////
// Subharmonic Divider (tracking-basierter Sub-Oktaver)
//////////////////////////////////////////////////////////////
SynthDef(\tromboneSubharm, { |inBus = 0, outBus = 0, octave = 1, mix = 0.0|
    var input, f0, sig, mixSm;

    mixSm = Lag.kr(mix, 0.05); // 50 ms smoothing

    input = SoundIn.ar(inBus);

    // pitch-tracking (Pitch.kr -> [freq, clarity])
    f0 = Pitch.kr(input, ampThreshold: 0.02, median: 7)[0].max(30);

    // subosc mit geteilter Grundfrequenz
    sig = SinOsc.ar(f0 / (2.0.pow(octave))) * (input.abs.lag(0.01));

    Out.ar(outBus, (input * (1 - mixSm) + sig * mixSm).dup);
}).add;

// ------------------- Octaver Setup --------------------------
(
~mode = \sub;     // default: \pitch oder \sub
~octave = 2;      // 1..3
~mix = 1.0;       // Wet-Level für Octaver

// Persistent Octaver Synths
~synthPitch = Synth(\tromboneOctaver, [\octave, ~octave, \mix, 0.0]);
~synthSub   = Synth(\tromboneSubharm, [\octave, ~octave, \mix, 0.0]);
~activeSynth = if(~mode==\pitch){ ~synthPitch }{ ~synthSub };

// Updatefunktion für Octaver
~updateOct = { |oct=nil, mode=nil|
    if(oct.notNil){ ~octave = oct };
    if(mode.notNil){ ~mode = mode };

    ~synthPitch.set(\octave, ~octave);
    ~synthSub.set(\octave, ~octave);

    if(~mode==\pitch){
        ~synthPitch.set(\mix, ~mix);
        ~synthSub.set(\mix, 0.0);
        ~activeSynth = ~synthPitch;
    }{
        ~synthSub.set(\mix, ~mix);
        ~synthPitch.set(\mix, 0.0);
        ~activeSynth = ~synthSub;
    };
};
)

// ------------------- Distortion + Flanger -------------------
SynthDef(\distFlanger, { |inBus=0, outBus=0, drive=0.5, flangerRate=0.2, flangerDepth=0.003, mix=0.5|
    var input, distorted, flanged, mixSm;

    mixSm = Lag.kr(mix, 0.05);

    input = In.ar(inBus, 2); // Stereo Input

    // einfache Distortion
    distorted = (input * (1 + drive)).tanh;

    // Flanger: DelayC mit LFO
    flanged = DelayC.ar(
        distorted,
        maxdelaytime: 0.01,
        delaytime: flangerDepth * SinOsc.kr(flangerRate).range(0.001, 0.01)
    );

    Out.ar(outBus, (input*(1-mixSm) + flanged*mixSm));
}).add;

// ------------------- Looper Synth ---------------------------
SynthDef(\looper, { |inBus=0, outBus=0, bufnum=0, record=0, play=0|
    var sig, rec, playback;

    sig = In.ar(inBus, 2);

    // Aufnahme in Buffer
    rec = RecordBuf.ar(sig, bufnum, loop:1, doneAction:0, preLevel:record);

    // Playback
    playback = PlayBuf.ar(2, bufnum, loop:1, doneAction:0) * play;

    Out.ar(outBus, playback);
}).add;

// ------------------- Effekt-Kette Start --------------------
(
~startChain = {
    // Octaver -> Distortion -> Looper

    // Bus für Octaver -> Distortion
    ~octBus = Bus.audio(s, 2);

    // Octaver Output auf Bus senden
    ~activeSynth.set(\outBus, ~octBus.index);

    // Distortion Synth, Input vom Octaver-Bus, Output auf Master
    ~distSynth = Synth(\distFlanger, [
        \inBus, ~octBus.index,
        \drive, 0.7,
        \flangerRate, 0.25,
        \flangerDepth, 0.004,
        \mix, 0.7
    ]);

    // Looper Input vom Distortion-Synth
    ~loopBus = Bus.audio(s, 2);
    ~distSynth.map(\outBus, ~loopBus.index);

    ~looperSynth = Synth(\looper, [
        \inBus, ~loopBus.index,
        \bufnum, ~buf.bufnum,
        \record, 1,    // 1 = aufnehmen
        \play, 1       // 1 = sofort abspielen
    ]);
};
)

// Starten der Kette
~startChain.();

//////////////////////////////////////////////////////////////
// STEUERUNG DER EFFEKTKETTE
//////////////////////////////////////////////////////////////

// ----------- Octaver-Steuerung ---------------------------------

~updateOct.(1, \pitch);  // 1 Oktaven, PitchShift
~updateOct.(2, \pitch);  // 2 Oktaven, PitchShift
~updateOct.(3, \pitch);  // 3 Oktaven, PitchShift
~updateOct.(1, \sub);    // 1 Oktaven, Subharmonic
~updateOct.(2, \sub);    // 2 Oktaven, Subharmonic
~updateOct.(3, \sub);    // 3 Oktaven, Subharmonic
~mix = 1.0;
~mix = 0.0;
~updateOct.(nil, ~mode); // Mix anpassen

// ----------- Distortion-Steuerung ---------------------------------

~distSynth.set(\drive, 0.9);
~distSynth.set(\flangerRate, 0.5);
~distSynth.set(\mix, 0.0);
~distSynth.set(\mix, 1.0);

// ----------- Looper-Steuerung ---------------------------------

~looperSynth.set(\record, 1); // Aufnahme
~looperSynth.set(\record, 0); // Stop Aufnahme
~looperSynth.set(\play, 1);   // Playback
~looperSynth.set(\play, 0);   // Stop Playback