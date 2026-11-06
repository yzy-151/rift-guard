extends SceneTree
const MOTION = preload("res://scripts/poster_motion.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func run() -> void:
	var owner := Node.new()
	root.add_child(owner)
	owner.process_mode = Node.PROCESS_MODE_DISABLED
	var paper := Control.new()
	paper.position = Vector2(113, 208)
	paper.size = Vector2(310, 420)
	paper.scale = Vector2(.9, .9)
	paper.pivot_offset = Vector2(9, 11)
	paper.modulate = Color(.9, .8, .7, .95)
	owner.add_child(paper)
	var poses: Array[Dictionary] = [{"node": paper, "offset": Vector2(0, 44), "delay": .06, "scale": .96}]
	var tween: Tween = MOTION.enter(owner, poses)
	tween.pause()
	check(paper.position == Vector2(113, 252) and paper.modulate.a == 0, "entrance begins from a translated transparent paper pose")
	tween.custom_step(.22)
	check(paper.modulate.a > .6 and paper.position.y < 221, "paper reveals promptly and approaches its layout position")
	tween.custom_step(.6)
	check(paper.position.is_equal_approx(Vector2(113, 208)) and paper.scale.is_equal_approx(Vector2(.9, .9)), "finite animation lands exactly at the layout position and scale")
	for index in 30:
		tween = MOTION.enter(owner, poses)
		tween.pause()
		tween.custom_step(.10)
		var superseded: Tween = tween
		tween = MOTION.enter(owner, poses)
		tween.pause()
		var old_active := superseded.custom_step(.6)
		check(not old_active and paper.position.is_equal_approx(Vector2(113, 252)), "reopening cancels the previous animation without position drift %d" % index)
		MOTION.reset(owner)
		check(paper.position.is_equal_approx(Vector2(113, 208)) and paper.pivot_offset == Vector2(9, 11) and paper.modulate.is_equal_approx(Color(.9, .8, .7, .95)), "hiding restores complete baseline %d" % index)
	tween = MOTION.enter(owner, poses, true)
	tween.pause()
	check(paper.position == Vector2(113, 208) and paper.scale == Vector2(.9, .9), "reduced effects retains layout geometry from the first frame")
	tween.custom_step(.15)
	check(paper.modulate.a > .94 and paper.position == Vector2(113, 208), "reduced entrance finishes its opacity fade within 0.15 seconds")
	MOTION.reset(owner)
	owner.queue_free()
	await process_frame
	print("POSTER MOTION QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
