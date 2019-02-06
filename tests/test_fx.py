from unittest import TestCase
from pippi import dsp, interpolation, wavetables, fx, oscs
import numpy as np
import random

class TestFx(TestCase):
    def test_vspeed(self):
        g = dsp.read('tests/sounds/guitar10s.wav')
        lfo = wavetables.window(dsp.SINE, 4096)
        snd = fx.vspeed(g, lfo, 0.5, 1)
        snd = fx.norm(snd, 1)
        g = dsp.read('tests/sounds/guitar10s.wav')
        snd = snd + g
        snd.write('tests/renders/fx_vspeed.wav')

    def test_envelope_follower(self):
        snd = dsp.read('tests/sounds/linux.wav')
        osc = oscs.Osc(dsp.SINE)
        carrier = osc.play(snd.dur)
        out = carrier * snd.toenv()
        out.write('tests/renders/fx_envelope_follower.wav')

    def test_delay(self):
        snd = dsp.read('tests/sounds/guitar10s.wav')
        snd = fx.delay(snd, 1, 0.5)
        snd = fx.norm(snd, 1)
        snd.write('tests/renders/fx_delay.wav')

    def test_vdelay(self):
        snd = dsp.read('tests/sounds/guitar10s.wav')
        tlfo = wavetables.randline(3, 30, 0, 1)
        lfo = wavetables.randline(30, 4096, 0, 1)
        snd = fx.vdelay(snd, lfo, 0.1, 0.75, 0.5)
        snd = fx.norm(snd, 1)
        snd.write('tests/renders/fx_vdelay.wav')

    def test_mdelay(self):
        snd = dsp.read('tests/sounds/guitar10s.wav')
        ndelays = 20
        snd = fx.mdelay(snd, [ random.triangular(0, 8) for _ in range(ndelays) ], 0.7)
        snd = fx.norm(snd, 1)
        snd.write('tests/renders/fx_mdelay.wav')

    def test_compressor(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        ratio = 4
        threshold = -10
        attack = 0.2
        release = 0.2

        out = fx.compressor(snd, ratio, threshold, attack, release)
        out.write('tests/renders/fx_compressor.wav')

    def test_paulstretch(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        stretch = 30

        out = fx.paulstretch(snd, stretch)
        out.write('tests/renders/fx_paulstretch.wav')

    def test_mincer(self):
        snd = dsp.read('tests/sounds/linux.wav')
        length = 20
        position = wavetables.randline(10) * 2 + 0.5
        pitch = wavetables.randline(10)

        out = fx.mincer(snd, length, position, pitch)
        out.write('tests/renders/fx_mincer.wav')

    def test_saturator_nodc(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        drive = 10
        dcoffset = 0
        dcblock = False

        out = fx.saturator(snd, drive, dcoffset, dcblock)
        out = fx.norm(out, 1)
        out.write('tests/renders/fx_saturator_nodc.wav')

    def test_saturator_dc(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        drive = 10
        dcoffset = 0.1
        dcblock = True

        out = fx.saturator(snd, drive, dcoffset, dcblock)
        out.write('tests/renders/fx_saturator_dc.wav')

    def test_butlp(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        freq = 100

        out = fx.lpf(snd, freq)
        out.write('tests/renders/fx_lpf.wav')

    def test_buthp(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        freq = 1000

        out = fx.hpf(snd, freq)
        out.write('tests/renders/fx_hpf.wav')

    def test_butbp(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        freq = 500

        out = fx.bpf(snd, freq)
        out.write('tests/renders/fx_bpf.wav')

    def test_butbr(self):
        snd = dsp.read('tests/sounds/guitar1s.wav')
        freq = 500

        out = fx.brf(snd, freq)
        out.write('tests/renders/fx_brf.wav')
