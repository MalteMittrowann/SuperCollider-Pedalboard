// ============================================================
// LIVE RIG: SMART LOOPER (FIXED) + DUAL OCTAVER + DISTORTION
// Tasten 1-10 (PC 0-9)
// ============================================================

(
// 1. SETUP
// BITTE HIER DEIN INTERFACE PRÜFEN:
s.options.device = "2- Steinberg UR22mkII ";
s.options.numInputBusChannels = 1;
s.options.numOutputBusChannels = 2;
s.options.sampleRate = 48000;

s.waitForBoot({

    // --- GEISTERJÄGER START ---
    s.freeAll;           // Tötet alle laufenden Synths
    s.newBusAllocators;  // Setzt alle Bus-Zuweisungen zurück (Verhindert Audio-Salat)
    MIDIClient.init;
    MIDIIn.connectAll;
    // --- GEISTERJÄGER ENDE ---

    "--- SYSTEM START (CLEAN) ---".postln;

    // --- 2. SYNTH DEFS ---

    // A) DUAL OCTAVER
    SynthDef(\dualOctaver, { |inBus=0, outBus=0, octave=1, mix=0.0, mode=0|
        var input, mixSm, wetSignal;
        var ratio, sigPitch;
        var freq, sigSub, amp;

        mixSm = Lag.kr(mix, 0.1);
        input = SoundIn.ar(inBus);

        // Engine 1: Natural
        ratio = 1.0 / 2.0.pow(octave);
        sigPitch = PitchShift.ar(input, 0.05, ratio, 0, 0.004);

        // Engine 2: Subharmonic
        freq = Pitch.kr(input, ampThreshold: 0.02, median: 7)[0];
        amp = input.abs.lag(0.05);
        sigSub = SinOsc.ar(freq / 2.pow(octave)) * amp;
        sigSub = sigSub.tanh;

        wetSignal = Select.ar(mode, [sigPitch, sigSub]);
        Out.ar(outBus, (input * (1 - mixSm) + wetSignal * mixSm).dup);
    }).add;


    // B) DISTORTION
    SynthDef(\dualDistortion, { |inBus=0, outBus=0, mode=0, drive=10, mix=0.0|
        var input, wet, tube, fold, sig, mixSm;
        mixSm = Lag.kr(mix, 0.1);
        input = In.ar(inBus, 2);

        tube = (input * drive).tanh;
        fold = (input * drive).fold2(0.4) * 0.8;

        wet = Select.ar(mode, [tube, fold]);
        sig = (input * (1 - mixSm)) + (wet * mixSm);
        Out.ar(outBus, sig);
    }).add;


    // C) LOOPER RECORDER
    SynthDef(\loopRecorder, { |inBus=0, bufnum=0|
        var input = In.ar(inBus, 2);
        RecordBuf.ar(input, bufnum, 0, 1.0, 0.0, 1, 0, 1);
    }).add;

    // D) LOOPER PLAYER (FIXED: Mit Gate!)
    SynthDef(\loopPlayer, { |outBus=0, bufnum=0, endFrame=48000, fadeTime=0.05, gate=1|
        var playHead, sig, env;

        // HIER WAR DER FEHLER: Wir nutzen jetzt 'gate' statt einer festen 1
        // doneAction: 2 bedeutet: Wenn Gate auf 0 geht und Fade fertig ist -> Lösche Synth!
        env = EnvGen.kr(Env.asr(fadeTime, 1, fadeTime), gate, doneAction: 2);

        playHead = Phasor.ar(0, BufRateScale.kr(bufnum), 0, endFrame, 0);
        sig = BufRd.ar(2, bufnum, playHead);

        Out.ar(outBus, sig * env);
    }).add;

    // E) MIXER
    SynthDef(\liveThrough, { |inBus=0, outBus=0|
        var input = In.ar(inBus, 2);
        Out.ar(outBus, input);
    }).add;

    s.sync;

    // --- 3. INFRASTRUKTUR ---

    ~maxLoopTime = 60;
    ~buf = Buffer.alloc(s, s.sampleRate * ~maxLoopTime, 2);
    ~buf.zero;

    ~busOctToDist = Bus.audio(s, 2);
    ~busDistToLoop = Bus.audio(s, 2);

    ~grpOct = Group.new;
    ~grpDist = Group.after(~grpOct);
    ~grpLoop = Group.after(~grpDist);

    // --- 4. START ENGINE ---

    ~state = ();
    ~state[\octave] = 1;
    ~state[\octOn] = false;
    ~state[\octMode] = 0;

    ~state[\distOn] = false;
    ~state[\distMode] = 0;

    ~state[\loopStatus] = \empty;
    ~state[\recStartTime] = 0;
    ~state[\loopFrames] = 0;

    ~octSynth = Synth(\dualOctaver, [\outBus, ~busOctToDist, \mix, 0, \mode, 0], target: ~grpOct);
    ~distSynth = Synth(\dualDistortion, [\inBus, ~busOctToDist, \outBus, ~busDistToLoop, \mix, 0], target: ~grpDist);
    ~thruSynth = Synth(\liveThrough, [\inBus, ~busDistToLoop, \outBus, 0], target: ~grpLoop);

    "--- RIG BEREIT ---".postln;
    "Tasten 1-3: Oct | 4: REC | 5: PLAY/STOP | 6-7: Dist | 10: Mode".postln;


    // =======================================================
    // --- 5. MIDI LOGIK ---
    // =======================================================

    MIDIdef.program(\fcb_control, { |val|

        switch(val,

            // --- OCTAVER (Taste 1-3) ---
            0, {
                if (~state[\octOn] and: (~state[\octave] == 1)) {
                    ~octSynth.set(\mix, 0.0); ~state[\octOn] = false; "OCTAVER: AUS".postln;
                } {
                    ~state[\octave] = 1; ~state[\octOn] = true;
                    ~octSynth.set(\octave, 1, \mix, 1.0); "OCTAVER: AN (-1)".postln;
                };
            },
            1, {
                if (~state[\octOn] and: (~state[\octave] == 2)) {
                    ~octSynth.set(\mix, 0.0); ~state[\octOn] = false; "OCTAVER: AUS".postln;
                } {
                    ~state[\octave] = 2; ~state[\octOn] = true;
                    ~octSynth.set(\octave, 2, \mix, 1.0); "OCTAVER: AN (-2)".postln;
                };
            },
            2, {
                if (~state[\octOn] and: (~state[\octave] == 3)) {
                    ~octSynth.set(\mix, 0.0); ~state[\octOn] = false; "OCTAVER: AUS".postln;
                } {
                    ~state[\octave] = 3; ~state[\octOn] = true;
                    ~octSynth.set(\octave, 3, \mix, 1.0); "OCTAVER: AN (-3)".postln;
                };
            },

            // --- LOOPER LOGIK ---

            // TASTE 4: REC START
            3, {
                // Sicherheits-Kill: Falls Player noch läuft, weg damit!
                if (~playerSynth.notNil) { ~playerSynth.set(\gate, 0); ~playerSynth = nil; };
                if (~recorderSynth.notNil) { ~recorderSynth.free; };

                ~state[\loopStatus] = \recording;
                "LOOPER:  🔴 AUFNAHME LÄUFT...".postln;

                ~state[\recStartTime] = Process.elapsedTime;
                ~recorderSynth = Synth(\loopRecorder, [\inBus, ~busDistToLoop, \bufnum, ~buf], target: ~grpLoop);
            },

            // TASTE 5: PLAY / STOP / OVERDUB ENDE
            4, {
                if (~state[\loopStatus] == \recording) {
                    // STOP REC -> START PLAY
                    var duration, frames;

                    ~recorderSynth.free; ~recorderSynth = nil;

                    duration = Process.elapsedTime - ~state[\recStartTime];
                    frames = (duration * s.sampleRate).asInteger;
                    if (frames < 500) { frames = 500 };
                    ~state[\loopFrames] = frames;

                    "LOOPER:  ⏹️ REC STOP. Länge: % sek".format(duration.round(0.01)).postln;
                    "LOOPER:  ▶️ WIEDERGABE".postln;

                    // Hier übergeben wir gate=1 (Default), damit er läuft
                    ~playerSynth = Synth(\loopPlayer, [\outBus, 0, \bufnum, ~buf, \endFrame, frames], target: ~grpLoop);

                    ~state[\loopStatus] = \playing;

                } {
                    if (~state[\loopStatus] == \playing) {
                        // START PLAY -> STOP (PAUSE)

                        // Hier wird das gate auf 0 gesetzt -> Synth fadet aus und löscht sich (doneAction: 2)
                        if (~playerSynth.notNil) {
                             ~playerSynth.set(\gate, 0);
                             ~playerSynth = nil;
                        };

                        ~state[\loopStatus] = \stopped;
                        "LOOPER:  ⏸️ PAUSE".postln;

                    } {
                         // STOP -> RESTART
                         if (~state[\loopFrames] > 0) {
                             ~playerSynth = Synth(\loopPlayer, [\outBus, 0, \bufnum, ~buf, \endFrame, ~state[\loopFrames]], target: ~grpLoop);

                             ~state[\loopStatus] = \playing;
                             "LOOPER:  ▶️ WIEDERGABE (Restart)".postln;
                         } {
                             "LOOPER: (Leer) Bitte erst aufnehmen!".postln;
                         };
                    };
                };
            },

            // --- DISTORTION ---
            5, {
                 if (~state[\distOn] and: (~state[\distMode] == 0)) {
                    ~distSynth.set(\mix, 0.0); ~state[\distOn] = false; "DIST: AUS".postln;
                } {
                    ~state[\distMode] = 0; ~state[\distOn] = true;
                    ~distSynth.set(\mode, 0, \drive, 8, \mix, 1.0); "DIST: TUBE".postln;
                };
            },
            6, {
                 if (~state[\distOn] and: (~state[\distMode] == 1)) {
                    ~distSynth.set(\mix, 0.0); ~state[\distOn] = false; "DIST: AUS".postln;
                } {
                    ~state[\distMode] = 1; ~state[\distOn] = true;
                    ~distSynth.set(\mode, 1, \drive, 20, \mix, 1.0); "DIST: FOLD".postln;
                };
            },

            // --- MODE SWITCH ---
            9, {
                if (~state[\octMode] == 0) {
                    ~state[\octMode] = 1; ~octSynth.set(\mode, 1);
                    "MODE: 🌊 SUBHARMONIC (Synth)".postln;
                } {
                    ~state[\octMode] = 0; ~octSynth.set(\mode, 0);
                    "MODE: 🎤 PITCH SHIFT (Natural)".postln;
                };
            }
        );
    });
});
)