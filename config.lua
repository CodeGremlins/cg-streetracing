Config = {}

-- General settings
Config.Debug = true
Config.CountdownSeconds = 5
Config.MinPlayersToStart = 1
Config.AutoDNFTimeSeconds = 90 -- Time after winner finish to DNF others

-- Anti-exploit checkpoint validation
-- Server will only accept a checkpoint update if player is within this distance (meters)
Config.CheckpointMaxDistance = 25.0
-- If true, server will reject skipping ahead more than 1 checkpoint (already enforced logically)
Config.StrictOrder = true
-- Optionally require vehicle (false allows on foot testing)
Config.RequireVehicle = true
-- Allow players to spectate a race after start
Config.AllowLateSpectate = true

-- Marker / blip settings
Config.CheckpointMarker = {
	type = 1, -- marker type
	scale = vector3(3.0, 3.0, 1.5),
	color = { r = 255, g = 120, b = 0, a = 160 }
}

Config.CheckpointBlip = {
	sprite = 1,
	colour = 47,
	scale = 0.8
}

-- ox_target zone to open race menu (placeholder position)
Config.RaceTerminal = {
	coords = vec3(-75.15, -819.24, 326.18),
	size = vec3(1.5, 1.5, 1.5),
	debug = false
}

-- Sample races definition
-- Each checkpoint: { x, y, z }
Config.Races = {
	test_loop = {
		label = 'Downtown Test Loop',
			laps = 2, -- Demonstrate multi-lap (set to 1 for single lap)
		payout = 2500,
		checkpoints = {
			vec3(-256.69, -979.60, 31.22),
			vec3(-118.21, -1045.34, 27.27),
			vec3(72.58, -1029.41, 29.43),
			vec3(215.74, -919.88, 30.69),
			vec3(111.42, -785.52, 31.44),
			vec3(-36.51, -824.64, 31.61),
			vec3(-147.80, -919.41, 28.71)
		}
	}
}

return Config

