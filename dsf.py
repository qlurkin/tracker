from dataclasses import dataclass

import numpy as np
from matplotlib import pyplot as plt
from numpy.typing import NDArray
from pandas.core.generic import dt


def dsf(
    f: NDArray[np.floating], d: NDArray[np.floating], r: float, n: float
) -> NDArray[np.floating]:
    return (
        np.sin(f)
        - r * np.sin(f - d)
        - np.pow(r, n + 1.0) * (np.sin(f + (n + 1.0) * d) - r * np.sin(f + n * d))
    ) / (1.0 + r * r - 2.0 * r * np.cos(d))


def dsf2(
    phase: NDArray[np.floating],
    harmonic_spacing: float,
    roughness: float,
    n: float,
) -> NDArray[np.floating]:
    return dsf(
        phase * 2.0 * np.pi, phase * 2.0 * np.pi * harmonic_spacing, roughness, n
    )


roughness = 0.5


def saw(phase, n):
    return dsf2(phase, 1.0, roughness, n)


def square(phase, n):
    return dsf2(phase, 2.0, roughness, n)


def ideal_square(phase, n):
    res = 0
    for k in range(0, n):
        res += 1 / (2 * k + 1) * np.sin((2 * k + 1) * phase * 2 * np.pi)
    return 4 / np.pi * res


def naive_square(phase):
    res = np.ones(phase.shape)
    res[phase > 0.5] = -1
    return res


def poly_blep(phase, phase_increment):
    res = np.zeros(phase.shape)
    x = phase[phase < phase_increment] / phase_increment
    res[phase < phase_increment] = x + x - x * x - 1.0

    x = (phase[phase > 1.0 - phase_increment] - 1.0) / phase_increment
    res[phase > 1.0 - phase_increment] = x * x + x + x + 1.0
    return res


def poly_square(phase, phase_increment):
    res = naive_square(phase)
    res += poly_blep(phase, phase_increment)
    res -= poly_blep(np.fmod(phase + 0.5, 1.0), phase_increment)
    return res


@dataclass
class Biquad:
    b0: float = 0
    b1: float = 0
    b2: float = 0
    a1: float = 0
    a2: float = 0
    x1: float = 0
    x2: float = 0
    y1: float = 0
    y2: float = 0

    @staticmethod
    def low_pass(phase_increment):
        # w0 = 2 * np.pi * cutoff / sample_rate
        w0 = phase_increment
        c = np.cos(w0)
        s = np.sin(w0)
        a = s * np.sqrt(2) / 2
        a0 = 1 + a

        res = Biquad()
        res.b0 = (1 - c) / 2 / a0
        res.b1 = (1 - c) / a0
        res.b2 = (1 - c) / 2 / a0
        res.a1 = -2 * c / a0
        res.a2 = (1 - a) / a0

        return res

    def __call__(self, X):
        res = []
        for x in X:
            y = (
                self.b0 * x
                + self.b1 * self.x1
                + self.b2 * self.x2
                - self.a1 * self.y1
                - self.a2 * self.y2
            )

            self.x2 = self.x1
            self.x1 = x

            self.y2 = self.y1
            self.y1 = y

            res.append(y)

        return np.array(res)


lp = Biquad.low_pass(0.05)

p = np.linspace(0, 1, 1000)
n = 10
y_saw = saw(p, n)
y_square = square(p, n)

plt.figure()

# plt.plot(p, y_saw)

# plt.plot(p, square(p, 0))
# plt.plot(p, square(p, 1))
# plt.plot(p, square(p, 2))
# plt.plot(p, square(p, 3))
# plt.plot(p, square(p, 4))
# plt.plot(p, square(p, 5))
# plt.plot(p, square(p, 6))
# plt.plot(p, square(p, 7))
# plt.plot(p, square(p, 8))
# plt.plot(p, square(p, 9))
# plt.plot(p, square(p, 10))
plt.plot(p, naive_square(p))
plt.plot(p, poly_square(p, 0.05))
# plt.plot(p, square(p, 100))
plt.plot(p, ideal_square(p, 10))
plt.plot(p, lp(naive_square(p)))

plt.show()
