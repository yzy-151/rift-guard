extends "res://scripts/battle_devices.gd"
func tick(sim, dt: float) -> void:
	var started := Time.get_ticks_usec()
	super.tick(sim, dt)
	sim._record("plants", started)
