extends SceneTree

const Startup = preload("res://scripts/systems/startup_progress.gd")
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func fixture(prior_visible: bool, prior_paused: bool = false) -> Dictionary:
	paused = prior_paused
	var owner := Node3D.new()
	owner.visible = prior_visible
	root.add_child(owner)
	var child := MeshInstance3D.new()
	child.mesh = BoxMesh.new()
	owner.add_child(child)
	var progress := Startup.new()
	progress.setup(owner)
	verify(owner.visible == false, "owner suspended during startup")
	verify(child.visible, "child local visibility not changed")
	verify(not child.is_visible_in_tree(), "child inherited effective visibility suspended")
	verify(progress._layer.get_child(0).is_visible_in_tree(), "CanvasLayer ColorRect remains visible through hidden Node3D parent")
	verify(paused, "existing startup pause unchanged")
	return {"owner":owner,"child":child,"progress":progress}

func run() -> void:
	for prior_visible: bool in [true,false]:
		var current := fixture(prior_visible)
		var owner: Node3D = current.owner
		var child: MeshInstance3D = current.child
		var progress: RefCounted = current.progress
		verify(progress.finish(), "finish success")
		verify(owner.visible == prior_visible, "finish restores exact prior local visibility")
		verify(child.visible, "finish preserves child local visibility")
		verify(child.is_visible_in_tree() == prior_visible, "finish restores effective child visibility")
		verify(not progress._owner_visibility_captured, "finish clears pending restoration")
		verify(progress.complete, "finish keeps completion contract")
		owner.visible = not prior_visible
		progress.cancel()
		verify(owner.visible == not prior_visible, "cancel after finish cannot restore twice or overwrite later visibility")
		cases.append({"case":"finish","priorVisible":prior_visible,"restoredExactPrior":true,"CanvasLayerStateVerified":true})
		paused = false
		owner.free()
		await process_frame
	for prior_visible: bool in [true,false]:
		for prior_paused: bool in [true,false]:
			var current := fixture(prior_visible,prior_paused)
			var owner: Node3D = current.owner
			var child: MeshInstance3D = current.child
			var progress: RefCounted = current.progress
			progress.cancel()
			verify(owner.visible == prior_visible, "cancel restores exact prior local visibility")
			verify(child.visible, "cancel preserves child local visibility")
			verify(paused == prior_paused, "cancel preserves exact previous pause")
			verify(not progress._owner_visibility_captured and not progress.active, "cancel restoration ends once")
			owner.visible = not prior_visible
			progress.cancel()
			verify(owner.visible == not prior_visible, "second cancel does not overwrite later visibility")
			cases.append({"case":"cancel","priorVisible":prior_visible,"priorPaused":prior_paused,"restoredExactPrior":true})
			paused = false
			owner.free()
			await process_frame
	var removed := fixture(true)
	var removed_owner: Node3D = removed.owner
	root.remove_child(removed_owner)
	removed.progress.cancel()
	verify(removed_owner.visible, "removed but live owner safely restored")
	verify(not paused, "removed owner cancel restores pause")
	cases.append({"case":"removed_live_owner_cancel","restoredExactPrior":true})
	removed_owner.free()
	await process_frame
	var freed := fixture(true)
	freed.owner.free()
	freed.progress.cancel()
	verify(not freed.progress._owner_visibility_captured, "freed owner weakref restoration safely cleared")
	verify(not paused and not freed.progress.active, "freed owner cancel retains pause and active contract")
	cases.append({"case":"freed_owner_cancel","invalidOwnerNotAccessed":true})
	await process_frame
	var receipt := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"cases":cases,
		"headless":true,"nativeCanvasPixelsVerified":false,"nativeDrawCallsVerified":false,"nativeRuntimeReady":false}
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var file := FileAccess.open(args[0],FileAccess.WRITE)
		file.store_string(JSON.stringify(receipt,"\t")+"\n")
	print("STARTUP_VISIBILITY_LIFECYCLE "+JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
