# cython: language_level=3, cdivision=True, wraparound=False, boundscheck=False, initializedcheck=False

from pippi.soundbuffer cimport SoundBuffer
from pippi.wavetables cimport Wavetable, to_wavetable, to_window, SINE
from pippi cimport interpolation
from pippi.rand cimport rand
from pippi.defaults cimport DEFAULT_CHANNELS, DEFAULT_SAMPLERATE
from pippi.fx cimport _norm
from pippi.dsp cimport _mag
import numpy as np
from libc.math cimport signbit

cdef class Waveset:
    def __cinit__(
            Waveset self, 
            object values, 
            int crossings=3, 
            int limit=-1, 
            int modulo=1, 
            int samplerate=-1,
        ):

        self.samplerate = samplerate
        self.limit = limit
        self.modulo = modulo
        self.crossings = max(crossings, 2)

        self.load(values)

    def __getitem__(self, position):
        return self.wavesets[position]

    def __iter__(self):
        return iter(self.wavesets)

    def __len__(self):
        return len(self.wavesets)

    cpdef void load(Waveset self, object values):
        cdef double[:] raw
        cdef double[:] waveset
        cdef double original_mag = 0
        cdef int waveset_length
        cdef double val, last
        cdef int crossing_count=0, waveset_count=0, waveset_output_count=0, mod_count=0
        cdef int i=1, start=-1, end=-1

        self.wavesets = []
        self.max_length = 0
        self.min_length = 0

        if isinstance(values, SoundBuffer):
            original_mag = _mag(values.frames)
            values = values.remix(1)
            raw = np.ravel(np.array(_norm(values.frames, original_mag), dtype='d'))
            if self.samplerate <= 0:
                self.samplerate = values.samplerate

        elif isinstance(values, Wavetable):
            raw = values.data

        else:
            raw = np.ravel(np.array(values, dtype='d'))

        if self.samplerate <= 0:
            self.samplerate = DEFAULT_SAMPLERATE

        cdef int length = len(raw)

        last = raw[0]
        start = 0
        mod_count = 0

        while i < length:
            if (signbit(last) and not signbit(raw[i])) or (not signbit(last) and signbit(raw[i])):
                crossing_count += 1

                if crossing_count == self.crossings:
                    waveset_count += 1
                    mod_count += 1
                    crossing_count = 0

                    if mod_count == self.modulo:
                        mod_count = 0
                        waveset_length = i-start
                        waveset = np.zeros(waveset_length, dtype='d')
                        waveset = raw[start:i]
                        self.wavesets += [ waveset ]

                        self.max_length = max(self.max_length, waveset_length)

                        if self.min_length == 0:
                            self.min_length = waveset_length
                        else:
                            self.min_length = min(self.min_length, waveset_length)

                        waveset_output_count += 1

                        if self.limit == waveset_output_count:
                            break

                    start = i

            last = raw[i]
            i += 1

    cpdef void up(Waveset self, int factor=2):
        pass

    cpdef void down(Waveset self, int factor=2):
        pass

    cpdef void invert(Waveset self):
        pass

    cpdef SoundBuffer harmonic(Waveset self, list harmonics=None, list weights=None):
        if harmonics is None:
            harmonics = [1,2,3]

        if weights is None:
            weights = [1,0.5,0.25]

        cdef list out = []
        cdef int i, length, j, k, h, plength
        cdef double maxval
        cdef double[:] partial
        cdef double[:] cluster

        for i in range(len(self.wavesets)):
            length = len(self.wavesets[i])
            maxval = max(np.abs(self.wavesets[i])) 
            cluster = np.zeros(length, dtype='d')
            for h in harmonics:
                plength = length * h
                partial = np.zeros(plength, dtype='d')
                for j in range(h):
                    for k in range(length):
                        partial[k*j] = self.wavesets[i][k] * maxval

                partial = interpolation._linear(partial, length)

                for j in range(length):
                    cluster[j] += partial[j]

            for j in range(length):
                cluster[j] *= maxval

            out += [ cluster ]

        return self.render(out)

    cpdef SoundBuffer substitute(Waveset self, object waveform):
        cdef double[:] wt = to_wavetable(waveform)
        cdef list out = []
        cdef int i, length
        cdef double maxval
        cdef double[:] replacement

        for i in range(len(self.wavesets)):
            length = len(self.wavesets[i])
            maxval = max(np.abs(self.wavesets[i])) 
            replacement = interpolation._linear(wt, length)

            for j in range(length):
                replacement[j] *= maxval

            out += [ replacement ]

        return self.render(out)

    cpdef SoundBuffer morph(Waveset self, Waveset target, object curve=None):
        if curve is None:
            curve = SINE

        cdef double[:] wt = to_window(curve)
        cdef int slength = len(self)
        cdef int tlength = len(target)
        cdef int maxlength = max(slength, tlength)
        cdef int i=0, si=0, ti=0
        cdef double prob=0, pos=0
        cdef list out = []

        while i < maxlength:
            pos = <double>i / maxlength
            prob = interpolation._linear_pos(wt, pos)
            if rand(0,1) > prob:
                si = <int>(pos * slength)
                out += [ self[si] ]
            else:
                ti = <int>(pos * tlength)
                out += [ target[ti] ]

            i += 1

        return self.render(out)

    cpdef SoundBuffer render(Waveset self, list wavesets=None, int channels=-1, int samplerate=-1):
        channels = DEFAULT_CHANNELS if channels < 1 else channels
        samplerate = self.samplerate if samplerate < 1 else samplerate

        if wavesets is None:
            wavesets = self.wavesets

        cdef int i=0, c=0, j=0, oi=0
        cdef long framelength = 0
        cdef int numsets = len(wavesets)
        for i in range(numsets):
            framelength += len(wavesets[i])

        cdef double[:,:] out = np.zeros((framelength, channels), dtype='d')        

        for i in range(numsets):
            for j in range(len(wavesets[i])):
                for c in range(channels):
                    out[oi][c] = wavesets[i][j]
                oi += 1

        return SoundBuffer(out, channels=channels, samplerate=samplerate)

    cpdef void normalize(Waveset self, double ceiling=1):
        cdef int i=0, j=0
        cdef double normval = 1
        cdef double maxval = 0 
        cdef int numsets = len(self.wavesets)

        for i in range(numsets):
            maxval = max(np.abs(self.wavesets[i])) 
            normval = ceiling / maxval
            for j in range(len(self.wavesets[i])):
                self.wavesets[i][j] *= normval
