
/// Like FractalNoise, except in 3D and it generates values on demand and caches results, instead of generating everything at once.
pub const Cached3DFractalNoise = @import("Cached3DFractalNoise.zig");

/// Uses a recursive subdivision algorithm to generate a noise map.
pub const FractalNoise = @import("FractalNoise.zig");

/// The same as fractal noise, but uses random weigths during interpolation phase.
/// This generates a rough terrain with some cliffs.
pub const RandomlyWeightedFractalNoise = @import("RandomlyWeightedFractalNoise.zig");

/// The same as fractal noise, but uses random weigths during interpolation phase.
/// This generates a rough terrain with some cliffs.
pub const PerlinNoise = @import("PerlinNoise.zig");

/// Blue noise (aka Poisson Disk Sampling) is a pattern that ensures that all points have a minimum distance towards their neigbors.
/// This contains a static blue noise pattern that is calculated once and then used everywhere around the world. because it is so big the player will never notice issues.
pub const BlueNoise = @import("BlueNoise.zig");