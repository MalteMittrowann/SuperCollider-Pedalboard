// ============================================================
// ☣️ JUMP UP DNB RIG - FULL CONCERT EDITION ☣️
//
// BANK 00 (PC 0-9):   TRACK 1 (Wobble, Distortion, Arp)
// BANK 01 (PC 10-19): TRACK 2 (Delay, Harmonizer, Reverb)
// BANK 02 (PC 20-29): TRACK 3 (Song Structure / Story)
// BANK 09 (PC 90-99): SHOWCASE (Looper Demo)
//
// ============================================================

(
// 1. SERVER SETUP
s.quit;

s.options.device = "2- Steinberg UR22mkII ";
s.options.numInputBusChannels = 1;
s.options.numOutputBusChannels = 2;
s.options.sampleRate = 48000;
s.options.memSize = 2.pow(18); // 256MB RAM

s.waitForBoot({

    // --- CLEANUP ---
    s.freeAll;
    s.newBusAllocators;
    Window.closeAll;

    MIDIClient.init;
    MIDIIn.connectAll;

    t = TempoClock.default;
    t.tempo = 174 / 60;

    "--- DNB CONCERT ENGINE STARTED ---".postln;

    // =======================================================
    // --- A. SYNTH DEFS ---
    // =======================================================

    SynthDef(\mixToMaster, { |inBus, outBus|
        Out.ar(outBus, In.ar(inBus, 2));
    }).add;

    // --- STANDARD FX (BANK 00/01) ---
    SynthDef(\chainOctaver, { |inBus=0, outBus=0, octave=1, mix=0.0, mode=1|
        var input, wetSignal, mixSm, ratio, sigPitch, freq, sigSub, amp;
        mixSm = Lag.kr(mix, 0.1);
        input = SoundIn.ar(inBus);
        ratio = 1.0 / 2.0.pow(octave);
        sigPitch = PitchShift.ar(input, 0.05, ratio, 0, 0.004);
        # freq = Pitch.kr(input, ampThreshold: 0.02, median: 7);
        amp = input.abs.lag(0.05);
        sigSub = SinOsc.ar(freq / 2.pow(octave)) * amp;
        sigSub = sigSub.tanh;
        wetSignal = Select.ar(mode, [sigPitch, sigSub]);
        Out.ar(outBus, (input + (wetSignal * mixSm)).dup);
    }).add;

    SynthDef(\fxClean, { |inBus=0, outBus=0, gate=1|
        var input = In.ar(inBus, 2);
        var env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        Out.ar(outBus, input * env);
    }).add;

    SynthDef(\fxWobble, { |inBus=0, outBus=0, gate=1, pedalA=0.5|
        var input, oct, filter, lfo, env, amp, speed, depth;
        speed = pedalA.linexp(0, 1, 0.5, 12);
        depth = pedalA.linlin(0, 1, 200, 3000);
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
        var input, crushed, env, amp, dry, sr, bits;
        sr = pedalA.linexp(0, 1, 44100, 500);
        bits = pedalA.linlin(0, 1, 16, 3);
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
        var input, freq, hasFreq, synth, env, cutoff;
        cutoff = pedalA.linexp(0, 1, 100, 8000);
        env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5;
        # freq, hasFreq = Pitch.kr(input, ampThreshold: 0.05, median: 7);
        synth = Saw.ar([freq * 0.5, freq * 0.505]);
        synth = RLPF.ar(synth, cutoff, 0.5);
        Out.ar(outBus, synth * env * 0.8);
    }).add;

    SynthDef(\fxLaser, { |inBus=0, outBus=0, gate=1, pedalA=0.5|
        var input, delay, fb, env, pitchRise;
        pitchRise = pedalA.linlin(0, 1, 1.001, 1.3);
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
        var input, dist, sub, env, drive;
        drive = pedalA.linexp(0, 1, 1, 100);
        env = EnvGen.kr(Env.asr(0.01, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        input = (input[0] + input[1]) * 0.5;
        sub = PitchShift.ar(input, 0.1, 0.5, 0, 0.01);
        dist = (input + sub * 10).fold2(0.2);
        dist = (dist * drive).tanh;
        Out.ar(outBus, dist.dup * env * 0.5);
    }).add;

    SynthDef(\fxDelay, { |inBus=0, outBus=0, gate=1, pedalA=0.5, delayTime=0.5|
        var input, delays, env;
        env = EnvGen.kr(Env.asr(0.01, 1, 2.0), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        delays =
            DelayN.ar(input, 4.0, delayTime * 1) * 0.7 +
            DelayN.ar(input, 4.0, delayTime * 2) * 0.4 +
            DelayN.ar(input, 4.0, delayTime * 3) * 0.2 +
            DelayN.ar(input, 4.0, delayTime * 4) * 0.05;
        Out.ar(outBus, (input + (delays * pedalA * 1.5)) * env);
    }).add;

    SynthDef(\fxHarmonizer, { |inBus=0, outBus=0, gate=1, pedalA=0.5, semitones=7|
        var input, shifted, env, ratio, mix;
        mix = pedalA.linlin(0, 1, 0.2, 1.0);
        env = EnvGen.kr(Env.asr(0.05, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);
        ratio = 2.pow(semitones / 12.0);
        shifted = PitchShift.ar(input, 0.05, ratio, 0, 0.004);
        Out.ar(outBus, (input * (1-mix) + (shifted * mix)) * env);
    }).add;

    // --- COMBO FX FÜR BANK 02 ---

    // Crusher + Harmonizer (Quinte)
    SynthDef(\fxCrushHarm, { |inBus=0, outBus=0, gate=1, pedalA=0|
        var input, dry, crushed, harm, mix, sr, bits, env;
        env = EnvGen.kr(Env.asr(0.05, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);

        sr = pedalA.linexp(0, 1, 44100, 500);
        bits = pedalA.linlin(0, 1, 16, 3);
        dry = input;
        crushed = Latch.ar(input, Impulse.ar(sr));
        crushed = crushed.round(0.5.pow(bits));
        crushed = HPF.ar(crushed, 200);
        mix = (dry * (1-pedalA) + (crushed * 3 * pedalA));

        harm = PitchShift.ar(mix, 0.05, 1.498, 0, 0.004);

        Out.ar(outBus, (mix + harm) * 0.7 * env);
    }).add;

    // Doom + Harmonizer
    SynthDef(\fxDoomHarm, { |inBus=0, outBus=0, gate=1, pedalA=0.5|
        var input, dist, sub, harm, drive, env;
        env = EnvGen.kr(Env.asr(0.05, 1, 0.1), gate, doneAction: 2);
        input = In.ar(inBus, 2);

        drive = pedalA.linexp(0, 1, 1, 100);
        dist = (input * 2).fold2(0.2);
        dist = (dist * drive).tanh;

        harm = PitchShift.ar(dist, 0.05, 1.498, 0, 0.004);

        Out.ar(outBus, (dist + harm) * 0.6 * env);
    }).add;


    // --- MASTER SEKTION ---

    SynthDef(\masterReverb, { |inBus=0, outBus=0, active=0|
        var input, wet, sig, activeLag;
        activeLag = Lag.kr(active, 0.5);
        input = In.ar(inBus, 2);
        wet = GVerb.ar(input.sum, 200, 5.0, 0.5, 0.5, 15, -3.dbamp, -5.dbamp, -5.dbamp, 200, 1);
        wet = wet * 0.4;
        sig = input + (wet * activeLag);
        Out.ar(outBus, sig);
    }).add;

    SynthDef(\masterFilter, { |inBus=0, outBus=0, active=0, pedalA=0|
        var input, filtered, sig, activeLag, cutoff;
        activeLag = Lag.kr(active, 0.2);
        input = In.ar(inBus, 2);
        cutoff = pedalA.linexp(0, 1, 20, 3000);
        filtered = HPF.ar(input, cutoff);
        filtered = FreeVerb.ar(filtered, 0.5, 0.8);
        sig = (input * (1 - activeLag)) + (filtered * activeLag);
        Out.ar(outBus, sig);
    }).add;


    // --- INSTRUMENTE ---
    SynthDef(\loopRecorder, { |inBus=0, bufnum=0|
        var input = In.ar(inBus, 2);
        RecordBuf.ar(input, bufnum, 0, 1.0, 0.0, 1, 0, 1);
    }).add;

    SynthDef(\loopPlayer, { |outBus=0, bufnum=0, endFrame=48000, fadeTime=0.05, gate=1|
        var playHead, sig, env;
        env = EnvGen.kr(Env.asr(fadeTime, 1, fadeTime), gate, doneAction: 2);
        playHead = Phasor.ar(0, BufRateScale.kr(bufnum), 0, endFrame, 0);
        sig = BufRd.ar(2, bufnum, playHead);
        Out.ar(outBus, sig * env);
    }).add;

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

    s.sync;

    // =======================================================
    // --- B. INFRASTRUKTUR ---
    // =======================================================

    ~busInterconnect = Bus.audio(s, 2);
    ~busFxOut = Bus.audio(s, 2);
    ~busReverbOut = Bus.audio(s, 2);
    ~busMaster = Bus.audio(s, 2);

    ~grpOct  = Group.new;
    ~grpFx   = Group.after(~grpOct);
    ~grpRev  = Group.after(~grpFx);
    ~grpLoop = Group.after(~grpRev);
    ~grpBass = Group.after(~grpLoop);
    ~grpMaster = Group.after(~grpBass);

    ~buf = Buffer.alloc(s, s.sampleRate * 60, 2);
    ~buf.zero;

    ~octSynth = Synth(\chainOctaver, [\inBus, 0, \outBus, ~busInterconnect, \mix, 0, \mode, 1], target: ~grpOct);
    ~fxSynth = Synth(\fxClean, [\inBus, ~busInterconnect, \outBus, ~busFxOut], target: ~grpFx);
    ~reverbSynth = Synth(\masterReverb, [\inBus, ~busFxOut, \outBus, ~busReverbOut, \active, 0], target: ~grpRev);
    Synth(\mixToMaster, [\inBus, ~busReverbOut, \outBus, ~busMaster], target: ~grpRev, addAction: \addToTail);
    ~masterSynth = Synth(\masterFilter, [\inBus, ~busMaster, \outBus, 0, \active, 0, \pedalA, 0], target: ~grpMaster);


    // =======================================================
    // --- C. LOGIK ---
    // =======================================================

    ~state = ();
    ~state[\pedalA] = 0;
    ~state[\filterOn] = false;
    ~state[\reverbOn] = false;
    ~state[\arpOn] = false;
    ~state[\arpRate] = 0.25;
    ~state[\arpPattern] = [0, 3, 7, 12];
    ~state[\tapTimes] = List.new;

    ~state[\loopStatus] = \empty;
    ~state[\recStartTime] = 0;
    ~state[\loopFrames] = 0;

    ~bassNotes = Array.newClear(128);
    ~currentBassNote = nil;

    // --- ARPEGGIATOR TASK ---
    ~arpTask = Task({
        var step = 0;
        loop {
            if (~state[\arpOn] and: ~currentBassNote.notNil) {
                var pattern = ~state[\arpPattern];
                var note = ~currentBassNote + pattern.wrapAt(step);
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


    // --- HELPERS ---

    ~changeFX = { |synthName, args = #[]|
        if (~fxSynth.notNil) { ~fxSynth.set(\gate, 0); };
        ~fxSynth = Synth(synthName, [\inBus, ~busInterconnect, \outBus, ~busFxOut, \pedalA, ~state[\pedalA]] ++ args, target: ~grpFx);
        ("⚡ FX: " ++ synthName).postln;
    };

    ~setSubOctaver = { |octave|
        if (~fxSynth.notNil) { ~fxSynth.set(\gate, 0); };
        ~fxSynth = Synth(\fxClean, [\inBus, ~busInterconnect, \outBus, ~busFxOut], target: ~grpFx);
        ~octSynth.set(\mix, 1.0, \octave, octave, \mode, 1);
        ("⬇️ SUB BASS: -" ++ octave ++ " OCT").postln;
    };

    ~updateTempo = {
        var time = Process.elapsedTime;
        var diff;
        ~state[\tapTimes].add(time);
        if (~state[\tapTimes].size > 4) { ~state[\tapTimes].removeAt(0) };
        if (~state[\tapTimes].size > 1) {
            diff = ~state[\tapTimes].last - ~state[\tapTimes].first;
            diff = diff / (~state[\tapTimes].size - 1);
            t.tempo = 1 / diff;
            ("🥁 TAP! " ++ (t.tempo * 60).round(1) ++ " BPM").postln;
            if (~fxSynth.defName == \fxDelay) { ~fxSynth.set(\delayTime, t.beatDur); };
        };
    };

    ~resetAll = {
        ~octSynth.set(\mix, 0);
        ~state[\octOn] = false;
        ~state[\filterOn] = false;
        ~state[\reverbOn] = false;
        ~masterSynth.set(\active, 0);
        ~reverbSynth.set(\active, 0);
        ~state[\arpOn] = false;

        if (~fxSynth.notNil) { ~fxSynth.set(\gate, 0); };
        ~fxSynth = Synth(\fxClean, [\inBus, ~busInterconnect, \outBus, ~busFxOut], target: ~grpFx);
        "🟢 CLEAN".postln;
    };


    // =======================================================
    // --- D. MIDI MAPPING ---
    // =======================================================

    MIDIdef.program(\fcbControl, { |val|

        ("PC Empfangen: " ++ val).postln;

        switch(val,

            // --- BANK 00 (TRACK 1) ---
            0, { ~octSynth.set(\mix, 0); ~changeFX.(\fxWobble); },
            1, { ~octSynth.set(\mix, 0); ~changeFX.(\fxCrusher); },
            2, { ~octSynth.set(\mix, 0); ~changeFX.(\fxSynth); },
            3, { ~octSynth.set(\mix, 0); ~changeFX.(\fxLaser); },
            4, { ~octSynth.set(\mix, 0); ~changeFX.(\fxDoom); },
            5, { if (~state[\filterOn]) { ~state[\filterOn]=false; ~masterSynth.set(\active, 0); "💣 DROP!".postln; } { ~state[\filterOn]=true; ~masterSynth.set(\active, 1); "🌪️ BUILD-UP".postln; }; },
            6, { ~state[\arpOn] = ~state[\arpOn].not; if (~state[\arpOn]) { "🎹 ARP: ON".postln } { "🎹 ARP: OFF".postln }; },

            // --- BANK 01 (TRACK 2) ---
            10, { ~octSynth.set(\mix, 0); ~changeFX.(\fxDelay, [\delayTime, t.beatDur]); },
            11, { if (~state[\filterOn]) { ~state[\filterOn]=false; ~masterSynth.set(\active, 0); "💣 DROP!".postln; } { ~state[\filterOn]=true; ~masterSynth.set(\active, 1); "🌪️ HIGH PASS".postln; }; },
            12, { ~setSubOctaver.(1); },
            13, { ~setSubOctaver.(2); },
            14, { ~setSubOctaver.(3); },
            15, { ~state[\reverbOn] = ~state[\reverbOn].not; if (~state[\reverbOn]) { ~reverbSynth.set(\active, 1); "⛪ REVERB: ON".postln; } { ~reverbSynth.set(\active, 0); "⛪ REVERB: OFF".postln; }; },
            16, { ~octSynth.set(\mix, 0); ~changeFX.(\fxHarmonizer, [\semitones, 7]); "🎺 HARMONY: +5th".postln; },
            17, { ~octSynth.set(\mix, 0); ~changeFX.(\fxHarmonizer, [\semitones, 5]); "🎺 HARMONY: +4th".postln; },
            18, { ~octSynth.set(\mix, 0); ~changeFX.(\fxHarmonizer, [\semitones, 4]); "🎺 HARMONY: +3rd".postln; },
            19, { ~updateTempo.(); },

            // ===============================================
            // --- BANK 02 (TRACK 3 - SONG STRUCTURE) ---
            // ===============================================

            // 20 (1): REVERB + CRUSHER
            20, {
                ~resetAll.();
                ~reverbSynth.set(\active, 1); ~state[\reverbOn] = true;
                ~changeFX.(\fxCrusher);
                "▶️ SONG 3: PART 1 (Crush + Rev)".postln;
            },

            // 21 (2): ADD HARMONIZER + ARP 8tel OKTAVEN
            21, {
                // FX wechseln zu Crusher+Harm
                ~changeFX.(\fxCrushHarm);
                // Arp an (8tel, Oktaven)
                ~state[\arpOn] = true; ~state[\arpRate] = 0.5; ~state[\arpPattern] = [0, 12];
                "▶️ SONG 3: PART 2 (Add Harm + Arp 8tel)".postln;
            },

            // 22 (3): BUILD UP (HighPass Filter Control)
            22, {
                // FX bleibt, Arp bleibt.
                // Reverb bleibt.
                // HighPass AN (Gesteuert durch Pedal!)
                ~state[\filterOn] = true;
                ~masterSynth.set(\active, 1);
                "▶️ SONG 3: PART 3 (BUILD UP - Pedal Filter)".postln;
            },

            // 23 (4): DROP (Wobble, Filter Off, Rev Off, Arp 8tel Power)
            23, {
                ~state[\filterOn] = false; ~masterSynth.set(\active, 0); // Filter aus
                ~reverbSynth.set(\active, 0); ~state[\reverbOn] = false; // Reverb aus
                ~changeFX.(\fxWobble); // Wobble statt Doom
                // Arp 8tel Root-5-8
                ~state[\arpOn] = true; ~state[\arpRate] = 0.5; ~state[\arpPattern] = [0, 7, 12];
                "▶️ SONG 3: PART 4 (DROP - Wobble + Arp 8tel Power)".postln;
            },

            // 24 (5): OUTRO (Crusher, Reverb On, Arp Off)
            24, {
                ~reverbSynth.set(\active, 1); ~state[\reverbOn] = true;
                ~state[\arpOn] = false; // Bass Arp Stop
                ~changeFX.(\fxCrusher); // Crusher statt Wobble
                "▶️ SONG 3: PART 5 (OUTRO - Crusher + Rev)".postln;
            },


            // --- BANK 09 (SHOWCASE) ---
            90, { if (~recorderSynth.notNil) { ~recorderSynth.free; }; ~state[\loopStatus] = \recording; ~state[\recStartTime] = Process.elapsedTime; ~recorderSynth = Synth(\loopRecorder, [\inBus, ~busReverbOut, \bufnum, ~buf], target: ~grpLoop); "🔴 REC".postln; },
            91, {
                if (~state[\loopStatus] == \recording) {
                    var dur, fr; ~recorderSynth.free; ~recorderSynth = nil; dur = Process.elapsedTime - ~state[\recStartTime]; fr = (dur * s.sampleRate).asInteger; if(fr<500){fr=500}; ~state[\loopFrames]=fr; ~playerSynth = Synth(\loopPlayer, [\outBus, ~busMaster, \bufnum, ~buf, \endFrame, fr], target: ~grpLoop); ~state[\loopStatus] = \playing; "▶️ PLAY".postln;
                } {
                    if (~state[\loopStatus] == \playing) { if (~playerSynth.notNil) { ~playerSynth.set(\gate, 0); ~playerSynth = nil; }; ~state[\loopStatus] = \stopped; "⏸️ STOP".postln; }
                    { if (~state[\loopFrames] > 0) { ~playerSynth = Synth(\loopPlayer, [\outBus, ~busMaster, \bufnum, ~buf, \endFrame, ~state[\loopFrames]], target: ~grpLoop); ~state[\loopStatus] = \playing; "▶️ RESTART".postln; }; };
                };
            },
            92, { ~octSynth.set(\mix, 0); ~changeFX.(\fxLaser); },
            93, { if (~state[\filterOn]) { ~state[\filterOn]=false; ~masterSynth.set(\active, 0); "💣 DROP".postln; } { ~state[\filterOn]=true; ~masterSynth.set(\active, 1); "🌪️ HPF".postln; }; },
            94, { ~octSynth.set(\mix, 0); ~changeFX.(\fxDoom); },
            95, { if (~state[\arpOn] and: { (~state[\arpRate] - 0.25).abs < 0.001 } and: { ~state[\arpPattern] == [0, 3, 7, 12] }) { ~state[\arpOn] = false; "🎹 ARP: OFF".postln; } { ~state[\arpOn] = true; ~state[\arpRate] = 0.25; ~state[\arpPattern] = [0, 3, 7, 12]; "🎹 ARP: ON (16tel)".postln; }; },
            96, { if (~state[\arpOn] and: { (~state[\arpRate] - (1/3)).abs < 0.001 } and: { ~state[\arpPattern] == [0, 3, 7] }) { ~state[\arpOn] = false; "🎹 ARP: OFF".postln; } { ~state[\arpOn] = true; ~state[\arpRate] = 1/3; ~state[\arpPattern] = [0, 3, 7]; "🎹 ARP: ON (Triolen)".postln; }; },
            97, { if (~state[\arpOn] and: { (~state[\arpRate] - 0.5).abs < 0.001 } and: { ~state[\arpPattern] == [0, 12] }) { ~state[\arpOn] = false; "🎹 ARP: OFF".postln; } { ~state[\arpOn] = true; ~state[\arpRate] = 0.5; ~state[\arpPattern] = [0, 12]; "🎹 ARP: ON (8tel Okt)".postln; }; },
            98, { if (~state[\arpOn] and: { (~state[\arpRate] - 0.5).abs < 0.001 } and: { ~state[\arpPattern] == [0, 3, 7, 10] }) { ~state[\arpOn] = false; "🎹 ARP: OFF".postln; } { ~state[\arpOn] = true; ~state[\arpRate] = 0.5; ~state[\arpPattern] = [0, 3, 7, 10]; "🎹 ARP: ON (8tel Min7)".postln; }; },
            99, { ~updateTempo.(); }
        );
    });

    // PEDAL A (CC 27)
    MIDIdef.cc(\pedalA_control, { |val|
        var norm = val / 127.0;
        ~state[\pedalA] = norm;
        if (~fxSynth.notNil) { ~fxSynth.set(\pedalA, norm) };
        ~octSynth.set(\mix, norm);
        // Update Master Filter Cutoff (für Bank 02 Taste 3)
        ~masterSynth.set(\pedalA, norm);
    }, 27);

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