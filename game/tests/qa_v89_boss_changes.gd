extends SceneTree
func _initialize():call_deferred("run")
func run():
 var s=load("res://scripts/combat_simulation.gd").new()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 s.reset_stage("stage_03",squad,42);s.start();s.enemies.clear()
 for h in s.heroes:h.deployed=true;h.hp=10000;h.max_hp=10000;h.invulnerable_timer=0
 s.heroes[0].pos=Vector2(650,350);s.heroes[1].pos=Vector2(450,350);s.heroes[2].pos=Vector2(650,470)
 var k=s.spawn_enemy(Vector2(950,350),"boss_03");k.damage=100
 s._start_kindred_warning(k,"kindred_lasers")
 assert(k.special_warning_positions.size()==5)
 s._execute_kindred_special(k,"kindred_lasers")
 assert(s.heroes[0].hp<10000 and s.heroes[1].hp<10000,"beam must penetrate both collinear heroes")
 assert(s.heroes[2].hp==10000,"hero outside narrow rays must remain unharmed")
 var g=s.spawn_enemy(Vector2(950,350),"boss_galio")
 s._start_galio_warning(g,"galio_durand");assert(g.special_warning_radius==570)
 s._start_galio_warning(g,"galio_entrance");assert(g.special_warning_radius==850)
 g.boss_phase=3;s._start_galio_warning(g,"galio_entrance");assert(g.special_warning_radius==1050)
 for phase in s.database.boss_patterns.boss_03.phases:assert("kindred_lasers" in phase.moves)
 print("V89 PASS: piercing, safe gap, five beams, all phase rotations, Galio radii")
 quit()
