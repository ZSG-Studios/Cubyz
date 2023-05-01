const std = @import("std");
const Allocator = std.mem.Allocator;

const main = @import("root");
const Array2D = main.utils.Array2D;
const RandomList = main.utils.RandomList;
const random = main.random;
const JsonElement = main.JsonElement;
const terrain = main.server.terrain;
const CaveMapFragment = terrain.CaveMap.CaveMapFragment;
const CaveMap = terrain.CaveMap;
const CaveBiomeMap = terrain.CaveBiomeMap;
const noise = terrain.noise;
const FractalNoise = noise.FractalNoise;
const RandomlyWeightedFractalNoise = noise.RandomlyWeightedFractalNoise;
const PerlinNoise = noise.PerlinNoise;
const Biome = terrain.biomes.Biome;
const vec = main.vec;
const Vec3d = vec.Vec3d;
const Vec3f = vec.Vec3f;
const Vec3i = vec.Vec3i;

pub const id = "cubyz:crystal";

pub const priority = 65537;

pub const generatorSeed = 0x9b450ffb0d415317;

const crystalColor = [_][]const u8 {
	"red", "orange", "yellow", "green", "cyan", "blue", "violet", "purple", // 8 Base colors
	"dark_red", "dark_green", "light_blue", "brown", // 4 darker colors
	"white", "gray", "dark_gray", "black", // 4 grayscale colors
};
var glowCrystals: [crystalColor.len]u16 = undefined;

const surfaceDist = 2; // How far away crystal can spawn from the wall.

pub fn init(parameters: JsonElement) void {
	_ = parameters;
	// Find all the glow crystal ores:
	inline for(crystalColor[0..], glowCrystals[0..]) |color, *block| {
		const oreID = "cubyz:glow_crystal/" ++ color;
		block.* = main.blocks.getByID(oreID);
	}
}

pub fn deinit() void {

}

pub fn generate(worldSeed: u64, chunk: *main.chunk.Chunk, caveMap: CaveMap.CaveMapView, biomeMap: CaveBiomeMap.CaveBiomeMapView) Allocator.Error!void {
	if(chunk.pos.voxelSize > 2) return;
	const size = chunk.width;
	// Generate caves from all nearby chunks:
	var x = chunk.pos.wx - main.chunk.chunkSize;
	while(x < chunk.pos.wx + size + main.chunk.chunkSize) : (x += main.chunk.chunkSize) {
		var y = chunk.pos.wy - main.chunk.chunkSize;
		while(y < chunk.pos.wy + size + main.chunk.chunkSize) : (y += main.chunk.chunkSize) {
			var z = chunk.pos.wz - main.chunk.chunkSize;
			while(z < chunk.pos.wz + size + main.chunk.chunkSize) : (z += main.chunk.chunkSize) {
				var seed = random.initSeed3D(worldSeed, .{x, y, z});
				considerCoordinates(x, y, z, chunk, caveMap, biomeMap, &seed);
			}
		}
	}
}

fn distSqr(x: f32, y: f32, z: f32) f32 {
	return x*x + y*y + z*z;
}

fn considerCrystal(x: i32, y: i32, z: i32, chunk: *main.chunk.Chunk, seed: *u64, useNeedles: bool, types: []u16) void {
	const relX = x - chunk.pos.wx;
	const relY = y - chunk.pos.wy;
	const relZ = z - chunk.pos.wz;
	const typ = types[random.nextIntBounded(u32, seed, @intCast(u32, types.len))];
	// Make some crystal spikes in random directions:
	var spikes: u32 = 4;
	if(useNeedles) spikes += 2;
	spikes += random.nextIntBounded(u32, seed, spikes); // Use somewhat between spikes and 2*spikes spikes.
	for(0..spikes) |_| {
		const length = 8 + random.nextFloat(seed)*24;
		// Choose a random direction:
		const theta = 2*std.math.pi*random.nextFloat(seed);
		const phi = std.math.acos(1 - 2*random.nextFloat(seed));
		const delX = @sin(phi)*@cos(theta);
		const delY = @sin(phi)*@sin(theta);
		const delZ = @cos(phi);
		var j: f32 = 0;
		while(j < length) {
			const x2 = @intToFloat(f32, relX) + delX*j;
			const y2 = @intToFloat(f32, relY) + delY*j;
			const z2 = @intToFloat(f32, relZ) + delZ*j;
			var size: f32 = 0;
			if(useNeedles)
				size = 0.7
			else
				size = 12*(length - j)/length/@intToFloat(f32, spikes);
			const xMin = @floatToInt(i32, x2 - size);
			const xMax = @floatToInt(i32, x2 + size);
			const yMin = @floatToInt(i32, y2 - size);
			const yMax = @floatToInt(i32, y2 + size);
			const zMin = @floatToInt(i32, z2 - size);
			const zMax = @floatToInt(i32, z2 + size);
			var x3: i32 = xMin;
			while(x3 <= xMax) : (x3 += 1) {
				var y3: i32 = yMin;
				while(y3 <= yMax) : (y3 += 1) {
					var z3: i32 = zMin;
					while(z3 <= zMax) : (z3 += 1) {
						const dist = distSqr(@intToFloat(f32, x3) - x2, @intToFloat(f32, y3) - y2, @intToFloat(f32, z3) - z2);
						if(dist < size*size) {
							if(x3 >= 0 and x3 < chunk.width and y3 >= 0 and y3 < chunk.width and z3 >= 0 and z3 < chunk.width) {
								const block: main.blocks.Block = chunk.getBlock(x3, y3, z3);
								if(block.typ == 0 or block.degradable() or block.blockClass() == .fluid) {
									chunk.updateBlockInGeneration(x3, y3, z3, .{.typ = typ, .data = 0}); // TODO: Use natural standard.
								}
							}
						}
					}
				}
			}
			if(size > 2) size = 2;
			j += size/2; // Make sure there are no crystal bits floating in the air.
			if(size < 0.5) break; // Also preventing floating crystal bits.
		}
	}
}

fn considerCoordinates(x: i32, y: i32, z: i32, chunk: *main.chunk.Chunk, caveMap: CaveMap.CaveMapView, biomeMap: CaveBiomeMap.CaveBiomeMapView, seed: *u64) void {
	var oldSeed = seed.*;
	const crystalSpawns = biomeMap.getBiomeAndSeed(x + main.chunk.chunkSize/2 - chunk.pos.wx, y + main.chunk.chunkSize/2 - chunk.pos.wy, z + main.chunk.chunkSize/2 - chunk.pos.wz, seed).crystals;
	random.scrambleSeed(seed);
	var differendColors: u32 = 1;
	if(random.nextInt(u1, seed) != 0) {
		// ¹⁄₄ Chance that a cave has multiple crystals.
		while(random.nextInt(u1, seed) != 0 and differendColors < 32) {
			differendColors += 1; // Exponentially diminishing chance to have more differend crystals per cavern.
		}
	}
	var _colors: [32]u16 = undefined;
	const colors = _colors[0..differendColors];
	for(colors) |*color| {
		color.* = glowCrystals[random.nextIntBounded(u16, seed, glowCrystals.len)];
	}
	const useNeedles = random.nextInt(u1, seed) != 0; // Different crystal type.
	// Spawn the crystals using the old position specific seed:
	seed.* = oldSeed;
	for(0..crystalSpawns) |_| {
		// Choose some in world coordinates to start generating:
		const worldX = x + random.nextIntBounded(u31, seed, main.chunk.chunkSize);
		const worldY = y + random.nextIntBounded(u31, seed, main.chunk.chunkSize);
		const worldZ = z + random.nextIntBounded(u31, seed, main.chunk.chunkSize);
		const relX = worldX - chunk.pos.wx;
		const relY = worldY - chunk.pos.wy;
		const relZ = worldZ - chunk.pos.wz;
		if(caveMap.isSolid(relX, relY, relZ)) { // Only start crystal in solid blocks
			// Only start crystal when they are close to the surface (±SURFACE_DIST blocks)
			if(
				(worldX - x >= surfaceDist and !caveMap.isSolid(relX - surfaceDist, relY, relZ))
				or (worldX - x < main.chunk.chunkSize - surfaceDist and !caveMap.isSolid(relX + surfaceDist, relY, relZ))
				or (worldY - y >= surfaceDist and !caveMap.isSolid(relX, relY - surfaceDist, relZ))
				or (worldY - y < main.chunk.chunkSize - surfaceDist and !caveMap.isSolid(relX, relY + surfaceDist, relZ))
				or (worldZ - z >= surfaceDist and !caveMap.isSolid(relX, relY, relZ - surfaceDist))
				or (worldZ - z < main.chunk.chunkSize - surfaceDist and !caveMap.isSolid(relX, relY, relZ + surfaceDist))
			) {
				// Generate the crystal:
				considerCrystal(worldX, worldY, worldZ, chunk, seed, useNeedles, colors);
			}
		}
	}
}
