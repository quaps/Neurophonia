// physical modeling of a vibrating string, using a delay line (CombL) excited by an intial pulse (Impulse)
// To make it a bit richer, I've combined two slightly detuned delay lines
// "accelerate" is used for a pitch glide, and "sustain" changes the envelope timescale
(
	SynthDef(\MANDOLIN, {|out, sustain=1, pan, accelerate, freq, detune=0.2 |
		var env = EnvGen.ar(Env.linen(0.002, 0.996, 0.002, 1,-3), timeScale:sustain, doneAction:2);
		var sound = Decay.ar(Impulse.ar(0,0,0.1), 0.1*(freq.cpsmidi)/69) * WhiteNoise.ar;
		var pitch = freq * Line.kr(1, 1+accelerate, sustain);
		sound = CombL.ar(sound, 0.05, pitch.reciprocal*(1-(detune/100)), sustain)
		+ CombL.ar(sound, 0.05, pitch.reciprocal*(1+(detune/100)), sustain);
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
	}).add
);


// an example of additive synthesis, building up a gong-like noise from a sum of sine-wave harmonics
// notice how the envelope timescale and amplitude can be scaled as a function of the harmonic frequency
// "voice" provides something like a tone knob, and "decay" adjusts how the harmonics decay
// as in the other SynthDefs, "sustain" affects the overall envelope timescale and "accelerate" for pitch glide
// for a demo, try this in Tidal
// d1 $ n (slow 2 $ fmap (*7) $ run 8) # s "supergong" # decay "[1 0.2]/4" # voice "[0.5 0]/8"
(
	SynthDef(\GONG,{|out, sustain=1, pan, accelerate, freq, voice=0, decay=1 |
		// lowest modes for clamped circular plate
		var freqlist =[1.000,  2.081,  3.414,  3.893,  4.995,  5.954,  6.819,  8.280,  8.722,  8.882, 10.868, 11.180, 11.754,
			13.710, 13.715, 15.057, 15.484, 16.469, 16.817, 18.628]**1.0;
		var tscale = 100.0 / freq / (freqlist**(2-clip(decay,0,2)));
		var ascale =freqlist**clip(voice,0,4);
		var sound = Mix.arFill(15, {arg i; EnvGen.ar(Env.perc(0.01*tscale[i], 0.5*tscale[i], 0.2*ascale[i] ), timeScale:sustain*5)
			* SinOsc.ar(freq * freqlist[i] * Line.kr(1, 1+accelerate, sustain))});
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan))
	}).add
);


// hooking into a nice synth piano already in supercollider
// uses the "velocity" parameter to affect how hard the keys are pressed
// "sustain" controls envelope and decay time
(
	SynthDef(\superpiano,{|out, sustain=1, pan, velocity=1, detune=0.1, muffle=1, stereo=0.2, freq=440 |
		var env = EnvGen.ar(Env.linen(0.002, 0.996, 0.002, 1,-3), timeScale:sustain, doneAction:2);
		// the +0.01 to freq is because of edge case rounding internal to the MdaPiano synth
		var sound = MdaPiano.ar(freq+0.01, vel:velocity*100, hard:0.8*velocity, decay:0.1*sustain,
			tune:0.5, random:0.05, stretch:detune, muffle:0.8*muffle, stereo:stereo);
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
	}).add
);

// waveguide mesh, hexagonal drum-like membrane
(
	SynthDef(\HEX,{|out, speed=1, sustain=1, pan, freq, accelerate |
		var env = EnvGen.ar(Env.linen(0.02, 0.96, 0.02, 1,-3), timeScale:sustain, doneAction:2);
		var tension = 0.05*freq/400 * Line.kr(1,accelerate+1, sustain);
		var loss = 1.0 - (0.01 * speed / freq);
		var sound = MembraneHexagon.ar(Decay.ar(Impulse.ar(0,0,1), 0.01), tension, loss);
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
	}).add
);


// Kick Drum using Rumble-San's implementation as a starting point
// http://blog.rumblesan.com/post/53271713518/drum-sounds-in-supercollider-part-1
// "n" controls the kick frequency in a nonstandard way
// "sustain" affects overall envelope timescale, "accelerate" sweeps the click filter freq,
// "pitch1" affects the click frequency, and "decay" changes the click duration relative to the overall timescale
(
	SynthDef(\BD, {|out, sustain=1, pan, accelerate, n, pitch1=1, decay=1 |
		var env, sound, dur, clickdur;
		env = EnvGen.ar(Env.linen(0.01, 0, 0.5, 1, -3), timeScale:sustain, doneAction:2);
		sound = SinOsc.ar((n - 25.5).midicps);
		clickdur = 0.02*sustain*decay;
		sound = sound + (LPF.ar(WhiteNoise.ar(1), 1500*pitch1*Line.kr(1,1+accelerate,clickdur) ) * Line.ar(1, 0, clickdur));
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
	}).add
);


// A vaguely 808-ish kick drum
// "n" controls the chirp frequency, "sustain" the overall timescale, "speed" the filter sweep speed,
// and "voice" the sinewave feedback
(
	SynthDef(\808, {|out, speed=1, sustain=1, pan, voice=0, n |
		var env, sound, freq;
		n = ((n>0)*n) + ((n<1)*3);
		freq = (n*10).midicps;
		env = EnvGen.ar(Env.linen(0.01, 0, 1, 1, -3), timeScale:sustain, doneAction:2);
		sound = LPF.ar(SinOscFB.ar(XLine.ar(freq.expexp(10, 2000, 1000, 8000), freq, 0.025/speed), voice), 9000);
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
	}).add
);


// Hi-hat using Rumble-San's implementation as a starting point
// http://blog.rumblesan.com/post/53271713518/drum-sounds-in-supercollider-part-1
// using "n" in a weird way to provide some variation on the frequency
// "sustain" affects the overall envelope rate, "accelerate" sweeps the filter
(
	SynthDef(\HH, {|out, sustain=1, pan, accelerate, n |
		var env, sound, accel, freq;
		env = EnvGen.ar(Env.linen(0.01, 0, 0.3, 1, -3), timeScale:sustain, doneAction:2);
		accel = Line.kr(1, 1+accelerate, 0.2*sustain);
		freq = 2000*accel*(n/5 + 1).wrap(0.5,2);
		sound = HPF.ar(LPF.ar(WhiteNoise.ar(1), 3*freq), freq);
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
	}).add
);


// Snare drum using Rumble-San's implementation as a starting point
// http://blog.rumblesan.com/post/53271713909/drum-sounds-in-supercollider-part-2
// again using "n" for some variation on frequency, "decay" for scaling noise duration relative to tonal part
// "sustain" for overall timescale, "accelerate" for tonal glide
(
	SynthDef(\SN, {|out, sustain=1, pan, accelerate, n, decay=1 |
		var env, sound, accel;
		env = EnvGen.ar(Env.linen(0.01, 0, 0.6, 1, -3), timeScale:sustain, doneAction:2);
		accel = Line.kr(1, 1+accelerate, 0.2);
		sound = LPF.ar(Pulse.ar(100*accel*(n/5+1).wrap(0.5,2)), Line.ar(1030, 30, 0.2*sustain));
		sound = sound + (BPF.ar(HPF.ar(WhiteNoise.ar(1), 500), 1500) * Line.ar(1, 0, 0.2*decay));
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
	}).add
);


// Hand clap using Rumble-San's implementation as a starting point
// http://blog.rumblesan.com/post/53271713909/drum-sounds-in-supercollider-part-2
// "delay" controls the echo delay, "speed" will affect the decay time, "n" changes how spread is calculated
// "pitch1" will scale the bandpass frequency, and "sustain" the overall timescale
(
	SynthDef(\CLAP, {|out, speed=1, sustain=1, pan, n, delay=1, pitch1=1 |
		var env, sound;
		var spr = 0.005 * delay;
		env = EnvGen.ar(Env.linen(0.01, 0, 0.6, 1, -3), timeScale:sustain, doneAction:2);
		sound = BPF.ar(LPF.ar(WhiteNoise.ar(1), 7500*pitch1), 1500*pitch1);
		sound = Mix.arFill(4, {arg i; sound * 0.5 * EnvGen.ar(Env.new([0,0,1,0],[spr*(i**(n.clip(0,5)+1)),0,0.04/speed]))});
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
	}).add
);


// a controllable synth siren, defaults to 1 second, draw it out with "sustain"
(
	SynthDef(\SIREN, {|out, sustain=1, pan, freq |
		var env, sound;
		env = EnvGen.ar(Env.linen(0.05, 0.9, 0.05, 1, -2), timeScale:sustain, doneAction:2);
		sound = VarSaw.ar(freq * (1.0 + EnvGen.kr(Env.linen(0.25,0.5,0.25,3,0), timeScale:sustain, doneAction:2)),
			0, width:Line.kr(0.05,1,sustain));
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
	}).add
);


// The next four synths respond to the following parameters in addition to gain, pan, n, and all the "effect" parameters
// (including attack, hold, and release).  Default values in parentheses.
//
// sustain - scales overall duration
// decay(0) - amount of decay after initial attack
// accelerate(0) - pitch glide
// semitone(12) - how far off in pitch the secondary oscillator is (need not be integer)
// pitch1(1) - filter frequency scaling multiplier, the frequency itself follows the pitch set by "n"
// speed(1)- LFO rate
// lfo(1) - how much the LFO affects the filter frequency
// resonance(0.2) - filter resonance
// voice(0.5) - depends on the individual synth

// a moog-inspired square-wave synth; variable-width pulses with filter frequency modulated by an LFO
// "voice" controls the pulse width (exactly zero or one will make no sound)
(
	SynthDef(\SSQ, {|out, speed=1, decay=0, sustain=1, pan, accelerate, freq,
		voice=0.5, semitone=12, resonance=0.2, lfo=1, pitch1=1|
		var env = EnvGen.ar(Env.pairs([[0,0],[0.05,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -3), timeScale:sustain, doneAction:2);
		var basefreq = freq* Line.kr(1, 1+accelerate, sustain);
		var basefreq2 = basefreq / (2**(semitone/12));
		var lfof1 = min(basefreq*10*pitch1, 22000);
		var lfof2 = min(lfof1 * (lfo + 1), 22000);
		var sound = (0.7 * Pulse.ar(basefreq, voice)) + (0.3 * Pulse.ar(basefreq2, voice));
		sound = MoogFF.ar(
			sound,
			SinOsc.ar(basefreq/64*speed, 0).range(lfof1,lfof2),
			resonance*4);
		sound = sound.tanh * 2;
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
	}).add
);


// a moog-inspired sawtooth synth; slightly detuned saws with triangle harmonics, filter frequency modulated by LFO
// "voice" controls a relative phase and detune amount
(
	SynthDef(\SSAW, {|out, speed=1, decay=0, sustain=1, pan, accelerate, freq,
		voice=0.5, semitone=12, resonance=0.2, lfo=1, pitch1=1|
		var env = EnvGen.ar(Env.pairs([[0,0],[0.05,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -3), timeScale:sustain, doneAction:2);
		var basefreq = freq * Line.kr(1, 1+accelerate, sustain);
		var basefreq2 = basefreq * (2**(semitone/12));
		var lfof1 = min(basefreq*10*pitch1, 22000);
		var lfof2 = min(lfof1 * (lfo + 1), 22000);
		var sound = MoogFF.ar(
			(0.5 * Mix.arFill(3, {|i|  SawDPW.ar(basefreq * ((i-1)*voice/50+1), 0)})) + (0.5 * LFTri.ar(basefreq2, voice)),
			LFTri.ar(basefreq/64*speed, 0.5).range(lfof1,lfof2),
			resonance*4);
		sound = sound.tanh*2;
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
	}).add
);


// a moog-inspired PWM synth; pulses multiplied by phase-shifted pulses, double filtering with an envelope on the second
// "voice" controls the phase shift rate
(
	SynthDef(\SPWM, {|out, speed=1, decay=0, sustain=1, pan, accelerate, freq,
		voice=0.5, semitone=12, resonance=0.2, lfo=1, pitch1=1|
		var env = EnvGen.ar(Env.pairs([[0,0],[0.05,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -3), timeScale:sustain, doneAction:2);
		var env2 = EnvGen.ar(Env.pairs([[0,0.1],[0.1,1],[0.4,0.5],[0.9,0.2],[1,0.2]], -3), timeScale:sustain/speed);
		var basefreq = freq * Line.kr(1, 1+accelerate, sustain);
		var basefreq2 = basefreq / (2**(semitone/12));
		var lfof1 = min(basefreq*10*pitch1, 22000);
		var lfof2 = min(lfof1 * (lfo + 1), 22000);
		var sound = 0.7 * PulseDPW.ar(basefreq) * DelayC.ar(PulseDPW.ar(basefreq), 0.2, Line.kr(0,voice,sustain)/basefreq);
		sound = 0.3 * PulseDPW.ar(basefreq2) * DelayC.ar(PulseDPW.ar(basefreq2), 0.2, Line.kr(0.1,0.1+voice,sustain)/basefreq) + sound;
		sound = MoogFF.ar(sound, SinOsc.ar(basefreq/32*speed, 0).range(lfof1,lfof2), resonance*4);
		sound = MoogFF.ar(sound, min(env2*lfof2*1.1, 22000), 3);
		sound = sound.tanh*5;
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
	}).add
);


// "voice" scales the comparator frequencies, higher values will sound "breathier"
(
	SynthDef(\COMPARATOR, {|out, speed=1, decay=0, sustain=1, pan, accelerate, freq,
		voice=0.5, resonance=0.5, lfo=1, pitch1=1|
		var env = EnvGen.ar(Env.pairs([[0,0],[0.05,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -3), timeScale:sustain, doneAction:2);
		var basefreq = freq * Line.kr(1, 1+accelerate, sustain);
		var sound = VarSaw.ar(basefreq, 0, Line.ar(0,1,sustain));
		var freqlist =[ 1.000, 2.188,  5.091,  8.529,  8.950,  9.305, 13.746, 14.653, 19.462, 22.003, 24.888, 25.991,
			26.085, 30.509, 33.608, 35.081, 40.125, 42.023, 46.527, 49.481]**(voice/5);
		sound = Splay.arFill(16, {|i| sound > LFTri.ar(freqlist[i])}, 1);
		sound = MoogFF.ar(
			sound,
			pitch1 * 4 * basefreq + SinOsc.ar(basefreq/64*speed, 0, lfo*basefreq/2) + LFNoise2.ar(1,lfo*basefreq),
			LFNoise2.ar(0,0.1,4*resonance));
		OffsetOut.ar(out, DirtPan.ar(0.5*sound, ~dirt.numChannels, pan, env));
	}).add
);


// uses the Atari ST emulation UGen with 3 oscillators
// "slide" is for a linear frequency glide that will repeat "speed" times (can be fractional or negative)
// "accelerate" is for an overall glide,
// "pitch2" and "pitch3" control the ratio of harmonics
// "voice" causes variations in the levels of the 3 oscillators
(
	SynthDef(\CHIP, {|out, sustain=1, pan, freq, speed=1, slide=0, pitch2=2, pitch3=3, accelerate, voice=0|
		var env, basefreq, sound, va, vb, vc;
		env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01,1,-1), timeScale:sustain, doneAction:2);
		basefreq = freq + wrap2(slide * 100 * Line.kr(-1,1+(2*speed-2),sustain), slide * 100);
		basefreq = basefreq * Line.kr(1, accelerate+1, sustain);
		va = (voice < 0.5) * 15;
		vb = ((2*voice) % 1 < 0.5) * 15;
		vc = ((4*voice) % 1 < 0.5) * 15;
		sound= AY.ar( AY.freqtotone(basefreq), AY.freqtotone(pitch2*basefreq), AY.freqtotone(pitch3*basefreq),
			vola:va, volb:vb, volc:vc)/2;
		sound = tanh(sound)*2;
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
	}).add
);


// digital noise in several flavors with a bandpass filter
// "voice" at 0 is a digital noise for which "n" controls rate, at 1 is Brown+White noise for which "n" controls knee frequency
// "accelerate" causes glide in n, "speed" will cause it to repeat
// "pitch1" scales the bandpass frequency (which tracks "n")
// "slide" works like accelerate on the bandpass
// "resonance" is the filter resonance
(
	SynthDef(\NZ, {|out, sustain=1, pan, freq, accelerate, slide=0, pitch1=1, speed=1, resonance=0, voice=0|
		var env, basefreq, sound, ffreq, acc;
		env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01,1,-1), timeScale:sustain, doneAction:2);
		acc = accelerate * freq * 4;
		basefreq = freq * 8 + wrap2(acc* Line.kr(-1,1+(2*speed-2), sustain), acc);
		ffreq = basefreq*5*pitch1* Line.kr(1,1+slide, sustain);
		ffreq = clip(ffreq, 60,20000);
		sound = XFade2.ar( LFDNoise0.ar(basefreq.min(22000), 0.5),
			XFade2.ar(BrownNoise.ar(0.5), WhiteNoise.ar(0.5), basefreq.cpsmidi/127),
			2*voice-1);
		sound = HPF.ar(BMoog.ar(sound, ffreq, resonance, 3), 20);
		sound = clip(sound, -1,1) * 0.3;
		OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
	}).add
);


// tuning fork
// from my own experimentation and from "On the acoustics of tuning forks", Rossing Russell and Brown
(
SynthDef(\FORK, {|out, sustain=1, pan, freq, accelerate=0|
	var sound, env;
	freq = freq * Line.kr(1, 1+accelerate, sustain);
	env = EnvGen.ar(Env.linen(0.001, 0.998, 0.001), timeScale:sustain, doneAction:2);
	sound = 0.2 * SinOsc.ar([1.0, 6.1, 16.7, 20.1] * freq) * XLine.ar([0.3, 1, 1.3, 2], [1e-4, 1e-7, 1e-6, 1e-7], sustain*[4,4,0.5,0.333]);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// hammond B3 sim
// freq adjustments courtesy Tom Wiltshire (electricdruid.net)
// drawbar settings selectable with "voice" and from many public domain sources,
// Google "Hammond drawbar settings" and add your own in the big SelectX block
// "perc" "percf" and "decay" are an attempt at the percussion, no idea if it sounds at all reasonable
// vintage Hammonds had percf as 2 or 3 (switchable), two perc levels (maybe roughly 0.7 and 1.2?),
// and two decay options (roughly 0 and maybe 1ish?)
// "vibrato", "vrate", "perc", "percf" are all new params you'll need to define in Tidal if you want to change them
(
SynthDef(\superhammond, {|out, sustain=1, decay=0, pan, freq, vibrato=0.5, vrate=7,
	voice=0, perc=0, percf=2 |
	var freqs, amps, sound, click, env, ampscale, attrel;
	attrel = (sustain/2).clip(0,0.005);
	env = EnvGen.ar(Env.linen(attrel, sustain-(2*attrel), attrel), doneAction:2);
	freqs = [0.5, 1.4988, 1, 2, 2.9976, 4, 5.0409, 5.9953, 8] * freq;
	freqs = 2**(freqs < 63) * freqs; // fold up bottom register
	freqs = freqs / (2**(freqs > 6000)); // fold down high harmonics
	freqs = freqs / (2**(freqs > 6000)); // do it again for the really high notes
	amps = SelectX.kr(voice, #[
		[1, 4, 5, 4, 3, 1, 0, 0, 0], // 0: bass violin 16'
		[0, 0, 8, 0, 4, 0, 0, 0, 0], // 1: tibia 8'
		[0, 7, 8, 1, 2, 0, 0, 0, 0], // 2: bassoon 8'
		[0, 0, 7, 8, 8, 8, 8, 7, 2], // 3: french trumpet 8'
		[4, 0, 5, 5, 4, 5, 3, 3, 6], // 4: string ensemble
		[8, 8, 5, 3, 2, 4, 5, 8, 8], // 5: Blues
		[8, 8, 8, 0 ,0, 0, 0, 0, 3], // 6: Jazz 1
		[8, 8, 8, 8, 8, 8, 8, 8, 8], // 7: Full Shout
		[8, 0, 0, 0, 0, 0, 8, 8, 8], // 8: Bro' Jack
		[0, 0, 8, 8, 0, 0, 0, 0, 0]  // 9: Jazz 2
	]);
	amps = amps - [0, 0, 0, 0, 0, 0, 0.5, 1, 1.5]; // damp brilliance a bit
	amps = 2**(amps-8);
	click = WhiteNoise.ar(1) * XLine.ar(1,1e-6, 0.1);
	sound = 0.5 * Mix.ar( SinOsc.ar(freqs*(2*click+1), (2pi ! 9).rand, amps/amps.sum) );
	sound = perc * 0.5 * SinOsc.ar(freq*percf, 2pi.rand) * XLine.ar(1,1e-6,2*decay+1) + sound;
	sound = sound + BAllPass.ar(sound, 1000*LFTri.kr(vrate,0,vibrato/2,1));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// vibraphone simulation, adapted with some help from Kevin Larke's thesis Real Time Vibraphone Pitch and Timbre Classification
// "decay" - use larger values to damp higher harmonics (default 0)
// "velocity" - higher velocity will brighten the sound a bit (default 1)
// "accelerate" - for a linear pitch bend
// "modamp" - amplitude of the tremolo (0-2 is OK, default 1)
// "modfreq" - frequency of the tremolo (default 7)
// "detune" - adjusts a high harmonic to give the sound a different character
(
SynthDef(\supervibe, {|out, sustain=1, decay=0, pan, freq, accelerate=0, velocity=1,
	modamp=1, modfreq=7.0, detune=0 |
	// most envelope shaping is done with XLines later, this envelope is just to clean up overall
	var env = EnvGen.ar(Env.linen(0.001, 0.998, 0.001), timeScale:sustain, doneAction:2);
	var sound, mod, freqs, hifreqs, decays;
	freqs = freq * Line.kr(1, 1+accelerate, sustain) * [1, 4, 10, 13.75+detune];
	hifreqs = freq * Line.kr(1, 1+accelerate, sustain) * [19.2, 20, 21.2];
	mod = SinOsc.kr(modfreq, Rand(0,2pi)).range(1-([0.5,0.3,0.3,0.5]*modamp),1);
	sound = 0.3 * [1, 1.1*velocity, 0.6*velocity*velocity, 0.5*velocity] * SinOsc.ar(freqs);
	decays = [1, 0.7*exp(-1.0*decay), 0.5*exp(-1.0*decay), 0.4*exp(-1.0*decay)];
	sound = XLine.ar(1e-6, 1, 1/freqs) * XLine.ar(1, 1e-6, decays*4*sustain) * sound * mod; // main attacks and decays
	sound = (XLine.ar(0.3*(velocity+1e-6),1e-6,0.02) * SinOsc.ar(hifreqs)).sum + sound.sum; // hi frequency onset
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// Hoover, adapted from Wouter Snoei's
// http://superdupercollider.blogspot.com/2009/06/more-dominator-deconstruction.html
// "slide" is used for the amount of initial pitch glide, positive slides up in pitch, negative slides down
// also responds to "decay" for a different envelope shape and "accelerate" for constant pitch glide
// uncomment the two lines with "rrand" for a different every time you evaulate it
(
SynthDef(\superhoover, {|out, sustain=1, decay=0, pan, freq, accelerate=0, slide=0|
	var env = EnvGen.ar(Env.pairs([[0,0],[0.03,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -1), timeScale:sustain, doneAction:2);
	var pwm, mix, fglide;
	fglide = EnvGen.ar(Env.perc(0.05, 0.3, 1, \lin), timeScale:sustain) * (-1*slide/4) + 1;
	freq = freq * fglide * Line.kr(1, 1+accelerate, sustain);
	freq = SinOsc.kr( [2.94, 3.0, 3.07], [3.0, 5.5, 1.2] ).exprange(0.995, 1.005) * freq;
	// freq = SinOsc.kr( {2.9 rrand: 3.1}!3, {2pi.rand}!3 ).exprange(0.995, 1.005) * freq;
	pwm = SinOsc.kr( [1.3, 2.9, 4.4] ).range(1/8, 7/8);
	// pwm = SinOsc.kr( {1.0 rrand: 5.0}!3 ).range(1/8, 7/8);
	mix = ([1,0.9,1.1]*LFSaw.ar(freq*[0.25, 0.5, 1], [1, 1.01, 1.02]).range(0,1) * (1 - LFPulse.ar(freq*[0.5,1,2], [0,0,0], pwm))).sum * 0.15;
	mix = mix + LFPar.ar(freq * 0.25, 0, 0.1).sum;
	mix = BPeakEQ.ar(mix, 6000, 1, 3);
	mix = BPeakEQ.ar(mix, 3500, 1, 6);
	mix = mix.dup + CombC.ar(mix.dup, 1/200, SinOsc.kr(3, [0.5pi, 1.5pi]).range(1/300, 1/200), 0);
	OffsetOut.ar(out, DirtPan.ar(1.4*mix, ~dirt.numChannels, pan, env));
}).add
);


// phased saws
// "decay" and "accelerate" used as in some synths above, for envelope shaping and pitch bend, respectively
// "slide" here is how fast it moves through the phase (default 1)
// "detune" is for oscillator detuning and defaults to 1
(
SynthDef(\ZOW, {|out, sustain=1, pan, accelerate, freq, decay=0, slide=1, detune=1 |
	var env = EnvGen.ar(Env.pairs([[0,0],[0.07,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -1), timeScale:sustain, doneAction:2);
	var basefreq = freq * Line.kr(1, 1+accelerate, sustain);
	var sound = VarSaw.ar(basefreq, 0, Line.ar(0,0.5,sustain*20/slide));
	var sound2 = VarSaw.ar(basefreq*(detune/100+1), 0, Line.ar(0,0.5,sustain*20/slide));
	var sound3 = VarSaw.ar(basefreq*(-1*detune/100+1), 0, Line.ar(0,0.5,sustain*20/slide));
	sound = sound - DelayN.ar(sound2,0.2, Line.ar(0,1,5*sustain/slide)/basefreq)
	  + DelayN.ar(sound3,0.2, Line.ar(0,1,20*sustain/slide)/basefreq);
	OffsetOut.ar(out, DirtPan.ar(sound/2, ~dirt.numChannels, pan, env));
}).add
);


// impulse noise with a fadein/out
(
SynthDef(\STATIC, {|out, sustain=1, pan, freq |
	var env = EnvGen.ar(Env.sine(1, 0.5), timeScale:sustain, doneAction:2);
	var sound = Dust.ar(freq*40) > 0.5;
	sound = Pulse.ar(freq*sound*4,0.5,0.5);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env))
}).add
);




// BS ADD-INS

// BASIC SINE
(
SynthDef(\S, {|out, sustain=1, pan, f |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = SinOsc.ar(f);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// BASIC SQUARE
(
SynthDef(\SQ, {|out, sustain=1, pan, f |
	var env = EnvGen.ar(Env.linen(0.001, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = LFPulse.ar(f);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// BLIP (BAND LIMITED IMPULSE)
(
SynthDef(\BLIP, {|out, sustain=1, pan, f |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = Blip.ar(f);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// BASIC SAW
(
SynthDef(\SAW, {|out, sustain=1, pan, f |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = LFSaw.ar(f);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// BASIC TRI
(
SynthDef(\TRI, {|out, sustain=1, pan, f |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = LFTri.ar(f);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// GREY NOISE
(
SynthDef(\GREY, {|out, sustain=1, pan |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = GrayNoise.ar();
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// PHASE MODULATION
(
SynthDef(\PM, {|out, sustain=1, pan, f, f2=100, indx=10 |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = PMOsc.ar(f, f2, indx);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


//LFD CLIP NOISE
(
SynthDef(\LFD, {|out, sustain=1, pan, f |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = LFDClipNoise.ar(f);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);

//LFD NOISE 0
(
SynthDef(\LFD0, {|out, sustain=1, pan, f |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = LFDNoise0.ar(f);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// BROWN NOISE
(
SynthDef(\BROWN, {|out, sustain=1, pan, f |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = BrownNoise.ar(f);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// PINK NOISE
(
SynthDef(\PINK, {|out, sustain=1, pan, f |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = PinkNoise.ar(f);
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);



// GRAVITY GRID NOISE
(
SynthDef(\GG, {|out, sustain=1, pan, f, gf1=0.25|
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = 0.1*GravityGrid.ar(Impulse.kr(LFNoise0.kr([gf1,0.231],90,100)),[100.2,10.5], LFNoise0.kr(10,0.8),LFNoise0.kr(10,0.8));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);


// Fhn2DN
(
SynthDef(\FHN, {|out=0, pan=0, amp=0.9, decay=0, sustain=1, dust1=8, dust2=13, dust3=5, dust4=3 |
    var sig;
	var env = EnvGen.ar(Env.pairs([[0,0],[0.05,1],[0.2,1-decay],[0.95,1-decay],[1,0]], -3), timeScale:sustain, doneAction:2);
	sig=Fhn2DN.ar(30, 22050, TExpRand.kr(0.001, 0.2, Dust.kr(8)), TExpRand.kr(0.001, 0.2, Dust.kr(13)), TRand.kr(0.1, 0.4, Dust.kr(5)),TRand.kr(0.1, 1.9, Dust.kr(3)), mul:amp);
	OffsetOut.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan));
}).add
)


// FEEDBACK SINE
(
SynthDef(\FBS, {|out=0, pan=0, f, sustain=1, index=1, fb=0, im1=1, im2=1 |
	var sig;
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	sig= FBSineN.ar(f, LFNoise2.kr(index,im1,im2), fb, 1.005, 0.7) * 0.2;
OffsetOut.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan, env));
}).add
)


// HAIR CELL
(
SynthDef(\CILIA, {|out, sustain=1, pan, f |
	var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	var sound = HairCell.ar(SinOsc.ar(f));
	OffsetOut.ar(out, DirtPan.ar(sound, ~dirt.numChannels, pan, env));
}).add
);



// MACRO SYNTHS

// NOISE RING (saw)
(
SynthDef(\NZRNG, {| out=0, pan=0, amp=0.8, decay=0, sustain=1, change=0.5, chance=0.5, f=17 |
	var sig;
	var nz = (Demand.ar(Impulse.ar(f), 0, DNoiseRing(change, chance, numBits: 32))).linlin(0, 2**32, 40, 40+48).midicps.poll;
	sig=Saw.ar(nz)!2;
	OffsetOut.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan));
}).add
)


// LINEAR CONGRUENTIAL GENS
(
SynthDef(\LCGC, {| out=0, pan=0, amp=0.8, decay=0, sustain=1, mul=500, add=1000, f=17 |
	var sig;
	sig={Impulse.ar(LinCongC.ar(f, LFNoise2.kr(0.2, 0.1, 1),LFNoise2.kr(0.4, 0.1, 0.1),LFNoise2.kr(0.8), 0, mul, add)
) * 0.4 };
	OffsetOut.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan));
}).add
)

// LIN CON N
(
SynthDef(\LCGN, {| out=0, pan=0, amp=0.8, decay=0, sustain=1, mul=500, add=1000, f=17 |
	var sig;
	sig={Blip.ar(LinCongN.ar(f, LFNoise2.kr(0.13, 0.5, 1), LFNoise2.kr(0.17, 0.1, 0.1), LFNoise2.kr(0.19), 0, mul, add), 500) * 0.4 };
	OffsetOut.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan));
}).add
)


// L-SYS
(
SynthDef(\help_sinegrain,
    { arg out=0, freq=440, sustain=0.05, pan=0;
        var env;
		a = Prewrite(0, (
			0: #[2,0],
			1: #[0,0,1],
			2: #[1,0,1]
		), 4).asStream;
        env = EnvGen.kr(Env.perc(0.01, sustain, 0.2), doneAction: Done.freeSelf);
		OffsetOut.ar(out, DirtPan.ar(SinOsc.ar(a.next * 7 + 80).midicps), ~dirt.numChannels, pan, env)};
).add;
)


// GEOM
(
SynthDef(\GEOM, {| f=440, sustain, pan=0, growth, trigf=10, length, out=0 |
	var a, freq, trig, sig;
		var env = EnvGen.ar(Env.linen(0.01, 0.98, 0.01, 1,-3), timeScale:sustain, doneAction:2);
	a = Dgeom(1, growth, length);
	trig = trigf;
	f = Demand.kr(trig, 0, a) * 30 +340;/ooool
	SinOsc(f) * 0.1;
	OffsetOut.ar(out, DirtPan.ar(sig, ~dirt.numChannels, pan, env));
}).add;
)
