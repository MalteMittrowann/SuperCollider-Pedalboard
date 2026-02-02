// ============================================================
// ☣️ JUMP UP DNB RIG - CHAINED FX ☣️
// Signalfluss: Mic -> Octaver -> FX -> Out
// Tasten 1-5: FX Slot | Tasten 6-8: Octaver | Taste 9: Mode | Taste 10: Clean
// ============================================================

(
// 1. SETUP
s.options.device = "2- Steinberg UR22mkII "; // <--- HIER DEIN INTERFACE PRÜFEN
s.options.numInputBusChannels = 1;
s.options.numOutputBusChannels = 2;
s.options.sampleRate = 48000;

s.waitForBoot({

    // --- CLEANUP ---
    s.freeAll;
    s.newBusAllocators; // Wichtig für sauberes Routing!
    MIDIClient.init;
    MIDIIn.connectAll;

    "--- DNB CHAIN ENGINE STARTED ---".postln;

    // --- 2. SYNTH DEFS ---

    // A) PERMANENT OCTAVER (Erstes Glied in der Kette)
    // Liest vom Hardware-Input (SoundIn)
    SynthDef(\chainOctaver, { |inBus=0, outBus=0, octave=1, mix=0.0, mode=0|
        var input, env, wetSignal;
        var ratio, sigPitch;
        var freq, sigSub, amp;
        var mixSm = Lag.kr(mix, 0.1);

        input = SoundIn.ar(inBus);

        // Engine 1: Natural
        ratio = 1.0 / 2.0.pow(octave);
        sigPitch = PitchShift.ar(input, 0.05, ratio, 0, 0.004);

        // Engine 2: Sub Synth
        # freq = Pitch.kr(input, ampThreshold: 0.02, median: 7);
        amp = input.abs.lag(0.05);
        sigSub = SinOsc.ar(freq / 2.pow(octave)) * amp;
        sigSub = sigSub.tanh;

        wetSignal = Select.ar(mode, [sigPitch, sigSub]);

        // Output Stereo auf den internen Bus
        Out.ar(outBus, (input + (wetSignal * mixSm)).dup);
    }).add;


    // B) FX SLOT SYNTHS (Zweites Glied in der Kette)
    // WICHTIG: Diese lesen jetzt von 'In.ar' (Bus), nicht mehr 'SoundIn' (Mic)!

    // 0. CLEAN / THROUGH
    SynthDef(\fxClean, { |inBus=0, outBus=0, gate=1|
        var input = In.ar(inBus, 2); // Liest Stereo vom Octaver
        var env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        Out.ar(outBus, input * env);
    }).add;

    // 1. WOBBLE
    SynthDef(\fxWobble, { |inBus=0, outBus=0, gate=1|
        var input, oct, filter, lfo, env, amp;
        env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2); // Stereo Input
        // Input zu Mono summieren für Effekte, falls nötig, oder Stereo bearbeiten.
        // Hier nehmen wir den Mix beider Kanäle für die Analyse:
        input = (input[0] + input[1]) * 0.5;

        amp = Amplitude.kr(input);
        input = input * (amp > 0.02).lag(0.05);
        oct = PitchShift.ar(input, 0.05, 0.5, 0, 0.01) * 2;
        lfo = SinOsc.kr(6).range(200, 2000);
        filter = RLPF.ar(oct + input, lfo, 0.3).tanh;
        Out.ar(outBus, filter.dup * env);
    }).add;

    // 2. CRUSHER
    SynthDef(\fxCrusher, { |inBus=0, outBus=0, gate=1|
        var input, crushed, env, amp;
        var downSampleRate = 4000;
        var bitDepth = 4;
        env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5; // Mono Summe

        amp = Amplitude.kr(input);
        input = input * (amp > 0.01).lag(0.05);
        crushed = Latch.ar(input, Impulse.ar(downSampleRate));
        crushed = crushed.round(0.5.pow(bitDepth));
        crushed = HPF.ar(crushed, 200);
        Out.ar(outBus, crushed.dup * env * 3);
    }).add;

    // 3. SYNTH BASS
    SynthDef(\fxSynth, { |inBus=0, outBus=0, gate=1|
        var input, freq, hasFreq, synth, env;
        env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5;

        # freq, hasFreq = Pitch.kr(input, ampThreshold: 0.05, median: 7);
        synth = Saw.ar([freq * 0.5, freq * 0.505]);
        synth = RLPF.ar(synth, input.abs.lag(0.05).linlin(0, 0.5, 100, 3000), 0.5);
        Out.ar(outBus, synth * env * 0.8);
    }).add;

    // 4. LASER
    SynthDef(\fxLaser, { |inBus=0, outBus=0, gate=1|
        var input, delay, fb, env;
        env = EnvGen.kr(Env.asr(0.01, 1, 0.5), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5;

        fb = LocalIn.ar(2);
        fb = PitchShift.ar(fb, 0.1, 1.1, 0, 0.01);
        delay = DelayN.ar(input + (fb * 0.7), 0.2, 0.15);
        LocalOut.ar(delay);
        Out.ar(outBus, (input + delay).tanh * env);
    }).add;

    // 5. DOOM
    SynthDef(\fxDoom, { |inBus=0, outBus=0, gate=1|
        var input, dist, sub, env;
        env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5;

        sub = PitchShift.ar(input, 0.1, 0.5, 0, 0.01);
        dist = (input + sub * 10).fold2(0.2);
        dist = (dist * 20).tanh;
        Out.ar(outBus, dist.dup * env * 0.5);
    }).add;

    s.sync;

    // --- 3. INFRASTRUKTUR & START ---

    // Internes Kabel (Bus)
    ~busInterconnect = Bus.audio(s, 2);

    // Gruppen für Signalfluss (Octaver -> FX)
    ~grpOct = Group.new;
    ~grpFx = Group.after(~grpOct);

    // START OCTAVER (Läuft immer, aber Mix 0)
    ~octSynth = Synth(\chainOctaver, [\inBus, 0, \outBus, ~busInterconnect, \mix, 0, \mode, 0], target: ~grpOct);

    // START FX (Läuft immer, startet Clean)
    ~fxSynth = Synth(\fxClean, [\inBus, ~busInterconnect, \outBus, 0], target: ~grpFx);

    // Status Vars
    ~state = ();
    ~state[\octave] = 1;
    ~state[\octOn] = false;
    ~state[\octMode] = 0;

    // --- 4. FUNKTIONEN ---

    ~changeFX = { |synthName|
        // Alten FX faden
        if (~fxSynth.notNil) { ~fxSynth.set(\gate, 0); };
        // Neuen FX starten (liest vom internen Bus!)
        ~fxSynth = Synth(synthName, [\inBus, ~busInterconnect, \outBus, 0], target: ~grpFx);
        ("⚡ FX CHANGED: " ++ synthName).postln;
    };

    ~resetAll = {
        // Octaver aus
        ~octSynth.set(\mix, 0);
        ~state[\octOn] = false;

        // FX auf Clean setzen
        if (~fxSynth.notNil) { ~fxSynth.set(\gate, 0); };
        ~fxSynth = Synth(\fxClean, [\inBus, ~busInterconnect, \outBus, 0], target: ~grpFx);

        "🟢 ALL CLEAN".postln;
    };


    // =======================================================
    // --- 5. MIDI MAPPING ---
    // =======================================================

    MIDIdef.program(\jumpUpControl, { |val|

        switch(val,

            // --- FX SLOT (1-5) ---
            0, { ~changeFX.(\fxWobble); },
            1, { ~changeFX.(\fxCrusher); },
            2, { ~changeFX.(\fxSynth); },
            3, { ~changeFX.(\fxLaser); },
            4, { ~changeFX.(\fxDoom); },

            // --- BASS OCTAVER LAYER (6-8) ---
            // Dieser Octaver liegt VOR dem FX
            5, {
                if (~state[\octOn] and: (~state[\octave] == 1)) {
                    // Wenn schon an auf dieser Oktave -> Ausschalten
                    ~octSynth.set(\mix, 0); ~state[\octOn] = false; "⬇️ OCTAVER: BYPASS".postln;
                } {
                    ~state[\octave] = 1; ~state[\octOn] = true;
                    ~octSynth.set(\octave, 1, \mix, 1.0); "⬇️ OCTAVER: -1 (Active)".postln;
                };
            },

            6, {
                if (~state[\octOn] and: (~state[\octave] == 2)) {
                    ~octSynth.set(\mix, 0); ~state[\octOn] = false; "⬇️ OCTAVER: BYPASS".postln;
                } {
                    ~state[\octave] = 2; ~state[\octOn] = true;
                    ~octSynth.set(\octave, 2, \mix, 1.0); "⬇️⬇️ OCTAVER: -2 (Active)".postln;
                };
            },

            7, {
                if (~state[\octOn] and: (~state[\octave] == 3)) {
                    ~octSynth.set(\mix, 0); ~state[\octOn] = false; "⬇️ OCTAVER: BYPASS".postln;
                } {
                    ~state[\octave] = 3; ~state[\octOn] = true;
                    ~octSynth.set(\octave, 3, \mix, 1.0); "⬇️⬇️⬇️ OCTAVER: -3 (Active)".postln;
                };
            },

            // --- MODE SWITCH (9) ---
            8, {
                ~state[\octMode] = 1 - ~state[\octMode];
                ~octSynth.set(\mode, ~state[\octMode]);
                if (~state[\octMode] == 0) { "🎤 MODE: NATURAL".postln } { "🎹 MODE: SYNTH".postln };
            },

            // --- CLEAN / PANIC (10) ---
            9, { ~resetAll.(); }
        );
    });

    "--- READY TO RUMBLE ---".postln;
    "1-5: FX Select | 6-8: Add Bass Octave | 9: Mode | 10: Clean All".postln;
});
)