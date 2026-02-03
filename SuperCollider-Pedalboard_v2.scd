// ============================================================
// ☣️ JUMP UP DNB RIG - TRACK BASED (SUB BASS EDIT) ☣️
//
// 1. TROMPETE (Audio In):
//    - Taste 1: Wobble FX
//    - Taste 2: Sub Bass -1 (Sine)
//    - Taste 3: Sub Bass -2 (Sine)
//    - Taste 4: Sub Bass -3 (Sine)
//    - Taste 5: Doom FX
//    - Pedal A: Macro Control
//
// 2. BASS (AKAI MPK):
//    - Normal: Reese Bass (-2 Halbtöne)
//    - Arp: Tasten 7, 8, 9 (8tel, Triolen, 16tel)
//
// 3. MASTER:
//    - Taste 6: Drop Filter
//    - Taste 10: Tap Tempo
// ============================================================

(
// 1. SERVER SETUP
s.options.device = "2- Steinberg UR22mkII "; // <--- PRÜFEN
s.options.numInputBusChannels = 1;
s.options.numOutputBusChannels = 2;
s.options.sampleRate = 48000;

s.waitForBoot({

    // --- CLEANUP ---
    s.freeAll;
    s.newBusAllocators;
    Window.closeAll;

    MIDIClient.init;
    MIDIIn.connectAll;

    // --- TEMPO ---
    t = TempoClock.default;
    t.tempo = 174 / 60; // 174 BPM Start

    "--- DNB ENGINE STARTED ---".postln;

    // =======================================================
    // --- A. SYNTH DEFS ---
    // =======================================================

    // 0. MIXER
    SynthDef(\mixToMaster, { |inBus, outBus|
        Out.ar(outBus, In.ar(inBus, 2));
    }).add;

    // 1. TROMPETEN FX & OCTAVER

    // Octaver mit "Mode": 0 = PitchShift, 1 = SubSynth (Sinus)
    SynthDef(\chainOctaver, { |inBus=0, outBus=0, octave=1, mix=0.0, mode=1|
        var input, wetSignal, mixSm, ratio, sigPitch, freq, sigSub, amp;
        mixSm = Lag.kr(mix, 0.1);
        input = SoundIn.ar(inBus);

        // Engine 1: Natural PitchShift
        ratio = 1.0 / 2.0.pow(octave);
        sigPitch = PitchShift.ar(input, 0.05, ratio, 0, 0.004);

        // Engine 2: Sub Synth (Sinus)
        # freq = Pitch.kr(input, ampThreshold: 0.02, median: 7);
        amp = input.abs.lag(0.05);
        sigSub = SinOsc.ar(freq / 2.pow(octave)) * amp;
        sigSub = sigSub.tanh; // Leicht gesättigt für Hörbarkeit

        wetSignal = Select.ar(mode, [sigPitch, sigSub]);

        // Output: Original + Wet Signal
        Out.ar(outBus, (input + (wetSignal * mixSm)).dup);
    }).add;

    SynthDef(\fxClean, { |inBus=0, outBus=0, gate=1|
        var input = In.ar(inBus, 2);
        var env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        Out.ar(outBus, input * env);
    }).add;

    SynthDef(\fxWobble, { |inBus=0, outBus=0, gate=1, pedalA=0.5|
        var input, oct, filter, lfo, env, amp;
        var speed = pedalA.linexp(0, 1, 0.5, 12);
        var depth = pedalA.linlin(0, 1, 200, 3000);
        env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5;
        amp = Amplitude.kr(input);
        input = input * (amp > 0.02).lag(0.05);
        oct = PitchShift.ar(input, 0.05, 0.5, 0, 0.01) * 2;
        lfo = SinOsc.kr(speed).range(200, depth);
        filter = RLPF.ar(oct + input, lfo, 0.3).tanh;
        Out.ar(outBus, filter.dup * env);
    }).add;

    SynthDef(\fxCrusher, { |inBus=0, outBus=0, gate=1, pedalA=0|
        var input, crushed, env, amp, dry;
        var sr = pedalA.linexp(0, 1, 44100, 500);
        var bits = pedalA.linlin(0, 1, 16, 3);
        env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5;
        dry = input;
        amp = Amplitude.kr(input);
        input = input * (amp > 0.01).lag(0.05);
        crushed = Latch.ar(input, Impulse.ar(sr));
        crushed = crushed.round(0.5.pow(bits));
        crushed = HPF.ar(crushed, 200);
        Out.ar(outBus, (dry * (1-pedalA) + (crushed * 3 * pedalA)).dup * env);
    }).add;

    SynthDef(\fxSynth, { |inBus=0, outBus=0, gate=1, pedalA=0.5|
        var input, freq, hasFreq, synth, env;
        var cutoff = pedalA.linexp(0, 1, 100, 8000);
        env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5;
        # freq, hasFreq = Pitch.kr(input, ampThreshold: 0.05, median: 7);
        synth = Saw.ar([freq * 0.5, freq * 0.505]);
        synth = RLPF.ar(synth, cutoff, 0.5);
        Out.ar(outBus, synth * env * 0.8);
    }).add;

    SynthDef(\fxLaser, { |inBus=0, outBus=0, gate=1, pedalA=0.5|
        var input, delay, fb, env;
        var pitchRise = pedalA.linlin(0, 1, 1.001, 1.3);
        env = EnvGen.kr(Env.asr(0.01, 1, 0.5), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5;
        fb = LocalIn.ar(2);
        fb = PitchShift.ar(fb, 0.1, pitchRise, 0, 0.01);
        delay = DelayN.ar(input + (fb * 0.7), 0.2, 0.15);
        LocalOut.ar(delay);
        Out.ar(outBus, (input + delay).tanh * env);
    }).add;

    SynthDef(\fxDoom, { |inBus=0, outBus=0, gate=1, pedalA=0.5|
        var input, dist, sub, env;
        var drive = pedalA.linexp(0, 1, 1, 100);
        env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5;
        sub = PitchShift.ar(input, 0.1, 0.5, 0, 0.01);
        dist = (input + sub * 10).fold2(0.2);
        dist = (dist * drive).tanh;
        Out.ar(outBus, dist.dup * env * 0.5);
    }).add;

    // 2. KEYBOARD SYNTHS

    SynthDef(\fatDnBBass, { |freq=50, amp=0.5, gate=1, outBus=0|
        var sig, sub, env, filterEnv;
        sig = VarSaw.ar([freq, freq * 1.005, freq * 0.995], 0, 0.5);
        sig = Splay.ar(sig);
        sub = SinOsc.ar(freq / 2) * 0.8;
        filterEnv = EnvGen.kr(Env.adsr(0.01, 0.2, 0.5, 0.2), gate);
        sig = RLPF.ar(sig + sub, 80 + (filterEnv * amp * 3000), 0.5);
        sig = (sig * 3).tanh;
        env = EnvGen.kr(Env.adsr(0.01, 0.1, 0.2, 0.1), gate, doneAction: 2);
        Out.ar(outBus, sig * env * amp);
    }).add;

    SynthDef(\arpBass, { |freq=50, amp=0.5, outBus=0|
        var sig, sub, env;
        sig = VarSaw.ar([freq, freq*1.01], 0, 0.5);
        sub = SinOsc.ar(freq/2);
        sig = RLPF.ar(sig + sub, freq * 4 * EnvGen.kr(Env.perc(0.001, 0.2)), 0.4);
        sig = (sig * 2).tanh;
        env = EnvGen.kr(Env.perc(0.01, 0.3), doneAction: 2);
        Out.ar(outBus, (sig * env * amp).dup);
    }).add;

    // 3. MASTER FILTER
    SynthDef(\masterFilter, { |inBus=0, outBus=0, active=0|
        var input, filtered, sig;
        var activeLag = Lag.kr(active, 0.2);
        input = In.ar(inBus, 2);
        filtered = HPF.ar(input, 400);
        filtered = FreeVerb.ar(filtered, 0.5, 0.8);
        sig = (input * (1 - activeLag)) + (filtered * activeLag);
        Out.ar(outBus, sig);
    }).add;

    s.sync;

    // =======================================================
    // --- B. INFRASTRUKTUR ---
    // =======================================================

    ~busInterconnect = Bus.audio(s, 2);
    ~busFxOut = Bus.audio(s, 2);
    ~busMaster = Bus.audio(s, 2);

    ~grpOct  = Group.new;
    ~grpFx   = Group.after(~grpOct);
    ~grpBass = Group.after(~grpFx);
    ~grpMaster = Group.after(~grpBass);

    // Start Synths
    // chainOctaver Mode 1 = Sub Synth
    ~octSynth = Synth(\chainOctaver, [\inBus, 0, \outBus, ~busInterconnect, \mix, 0, \mode, 1], target: ~grpOct);
    ~fxSynth = Synth(\fxClean, [\inBus, ~busInterconnect, \outBus, ~busFxOut], target: ~grpFx);
    ~masterSynth = Synth(\masterFilter, [\inBus, ~busMaster, \outBus, 0, \active, 0], target: ~grpMaster);
    Synth(\mixToMaster, [\inBus, ~busFxOut, \outBus, ~busMaster], target: ~grpFx, addAction: \addToTail);


    // =======================================================
    // --- C. LOGIK ---
    // =======================================================

    ~state = ();
    ~state[\pedalA] = 0;
    ~state[\filterOn] = false;
    ~state[\arpOn] = false;
    ~state[\arpRate] = 0.25;
    ~state[\tapTimes] = List.new;
    ~bassNotes = Array.newClear(128);
    ~currentBassNote = nil;

    // --- ARPEGGIATOR TASK ---
    ~arpTask = Task({
        var intervals = [0, 3, 7, 12];
        var step = 0;
        loop {
            if (~state[\arpOn] and: ~currentBassNote.notNil) {
                var note = ~currentBassNote + intervals.wrapAt(step);
                var transNote = note - 2;
                Synth(\arpBass, [\freq, transNote.midicps, \amp, 0.6, \outBus, ~busMaster], target: ~grpBass);
                step = step + 1;
            };
            (~state[\arpRate]).wait;
        };
    });
    ~arpTask.play(t);

    // --- GUI ---
    ~makeGui = {
        defer {
            var w = Window("BPM", Rect(100, 100, 300, 150)).front;
            var txt = StaticText(w, Rect(10, 10, 280, 130)).align_(\center).font_(Font("Impact", 60));
            w.view.background = Color.black;
            txt.stringColor = Color.white;
            SkipJack({
                var beat = t.beats.mod(1);
                var bpm = (t.tempo * 60).round(1).asInteger;
                txt.string = bpm.asString + " BPM";
                if (beat < 0.2) { w.view.background = Color.red; } { w.view.background = Color.black; };
            }, 0.05, { w.isClosed });
        };
    };
    ~makeGui.();


    // --- FX HELPER ---
    ~changeFX = { |synthName|
        if (~fxSynth.notNil) { ~fxSynth.set(\gate, 0); };
        ~fxSynth = Synth(synthName, [\inBus, ~busInterconnect, \outBus, ~busFxOut, \pedalA, ~state[\pedalA]], target: ~grpFx);
        ("⚡ FX: " ++ synthName).postln;
    };

    // --- OCTAVER HELPER ---
    ~setSubOctaver = { |octave|
        // Schaltet FX auf Clean und aktiviert Sub-Octaver auf der gewünschten Oktave
        if (~fxSynth.notNil) { ~fxSynth.set(\gate, 0); };
        ~fxSynth = Synth(\fxClean, [\inBus, ~busInterconnect, \outBus, ~busFxOut], target: ~grpFx);

        ~octSynth.set(\mix, 1.0, \octave, octave, \mode, 1); // Mode 1 = Sub Sine
        ("⬇️ SUB BASS: -" ++ octave ++ " OCT").postln;
    };


    // =======================================================
    // --- D. MIDI MAPPING (PC) ---
    // =======================================================

    MIDIdef.program(\track1Control, { |val|
        switch(val,

            // TASTE 1: WOBBLE (Octaver aus für sauberen Effekt)
            0, {
                ~octSynth.set(\mix, 0);
                ~changeFX.(\fxWobble);
            },

            // TASTE 2: SUB BASS -1 (FX Clean, Octaver An)
            1, { ~setSubOctaver.(1); },

            // TASTE 3: SUB BASS -2
            2, { ~setSubOctaver.(2); },

            // TASTE 4: SUB BASS -3
            3, { ~setSubOctaver.(3); },

            // TASTE 5: DOOM (Octaver aus)
            4, {
                ~octSynth.set(\mix, 0);
                ~changeFX.(\fxDoom);
            },

            // TASTE 6: DROP FILTER
            5, {
                if (~state[\filterOn]) {
                    ~state[\filterOn] = false;
                    ~masterSynth.set(\active, 0);
                    "💣 DROP!".postln;
                } {
                    ~state[\filterOn] = true;
                    ~masterSynth.set(\active, 1);
                    "🌪️ BUILD-UP".postln;
                };
            },

            // TASTE 7: ARP 8tel
            6, {
                if (~state[\arpOn] and: (~state[\arpRate] == 0.5)) {
                    ~state[\arpOn] = false; "🎹 ARP: OFF".postln;
                } {
                    ~state[\arpOn] = true; ~state[\arpRate] = 0.5; "🎹 ARP: ON (8tel)".postln;
                };
            },

            // TASTE 8: ARP 8tel-Triolen
            7, {
                if (~state[\arpOn] and: (~state[\arpRate] == (1/3))) {
                    ~state[\arpOn] = false; "🎹 ARP: OFF".postln;
                } {
                    ~state[\arpOn] = true; ~state[\arpRate] = 1/3; "🎹 ARP: ON (8tel Triolen)".postln;
                };
            },

            // TASTE 9: ARP 16tel
            8, {
                if (~state[\arpOn] and: (~state[\arpRate] == 0.25)) {
                    ~state[\arpOn] = false; "🎹 ARP: OFF".postln;
                } {
                    ~state[\arpOn] = true; ~state[\arpRate] = 0.25; "🎹 ARP: ON (16tel)".postln;
                };
            },

            // TASTE 10: TAP TEMPO
            9, {
                var time = Process.elapsedTime;
                var diff;
                ~state[\tapTimes].add(time);
                if (~state[\tapTimes].size > 4) { ~state[\tapTimes].removeAt(0) };

                if (~state[\tapTimes].size > 1) {
                    diff = ~state[\tapTimes].last - ~state[\tapTimes].first;
                    diff = diff / (~state[\tapTimes].size - 1);
                    t.tempo = 1 / diff;
                    ("🥁 TAP!").postln;
                };
            }
        );
    });

    MIDIdef.cc(\pedalA_control, { |val|
        var norm = val / 127.0;
        ~state[\pedalA] = norm;
        if (~fxSynth.notNil) { ~fxSynth.set(\pedalA, norm) };
    }, 27);


    // =======================================================
    // --- E. KEYBOARD ---
    // =======================================================

    MIDIdef.noteOn(\bassPlay, { |vel, num, chan, src|
        if(num > 20) {
            ~currentBassNote = num;
            if (~state[\arpOn].not) {
                var transNum = num - 2;
                if(~bassNotes[num].notNil) { ~bassNotes[num].set(\gate, 0); };
                ~bassNotes[num] = Synth(\fatDnBBass, [\freq, transNum.midicps, \amp, vel.linlin(0, 127, 0.2, 0.8), \gate, 1, \outBus, ~busMaster], target: ~grpBass);
            };
        };
    });

    MIDIdef.noteOff(\bassStop, { |vel, num|
        if (~currentBassNote == num) { ~currentBassNote = nil; };
        if(~bassNotes[num].notNil) { ~bassNotes[num].set(\gate, 0); ~bassNotes[num] = nil; };
    });

    "--- READY ---".postln;
});
)