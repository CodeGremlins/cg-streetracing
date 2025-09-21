Config = {}
Config.Debug = true
Config.CountdownSeconds = 5
Config.MinPlayersToStart = 1
Config.AutoDNFTimeSeconds = 90
Config.CheckpointMaxDistance = 25.0
Config.StrictOrder = true
Config.RequireVehicle = true
Config.AllowLateSpectate = true
Config.CheckpointMarker = {
	type = 1,
	scale = vector3(3.0, 3.0, 1.5),
	color = { r = 255, g = 120, b = 0, a = 160 }
}
Config.CheckpointBlip = {
	sprite = 1,
	colour = 47,
	scale = 0.8
}
Config.RaceTerminal = {
	coords = vec3(-75.15, -819.24, 326.18),
	size = vec3(1.5, 1.5, 1.5),
	debug = false
}
Config.Races = {
	test_loop = {
		label = 'Downtown Test Loop',
		laps = 2,
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

