extends SceneTree
var canceled_units := 0
func _initialize() -> void:
 _run.call_deferred()
func _run() -> void:
 var expected := ""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--test-user-dir="): expected=arg.trim_prefix("--test-user-dir=")
 if expected.is_empty() or OS.get_user_data_dir().get_file()!=expected:
  print("MID_CANCEL_GAP namespace_mismatch")
  quit(2)
  return
 var packed := load("res://scenes/main.tscn") as PackedScene
 var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 var game: Node=packed.instantiate()
 root.add_child(game)
 var progress: RefCounted=game._startup_progress
 var frames := 0
 var first_orphan_units := -1
 var reached := false
 while frames<2000 and is_instance_valid(game) and not game.startup_complete:
  await process_frame
  frames+=1
  var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
  var expansion: Node=game.get_node_or_null("TaiwanExpansion")
  var temporary: Node=expansion.get_node_or_null("_StartupTemporaryScenes") if is_instance_valid(expansion) else null
  var temporary_live: bool=is_instance_valid(temporary) and temporary.get_child_count()>0
  if progress._phase=="expansion" and temporary_live:
   if first_orphan_units<0: first_orphan_units=progress._total_units
   elif progress._total_units>first_orphan_units:
    reached=true
    canceled_units=progress._total_units
    break
 var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 var complete_before: bool = game.startup_complete
 game.queue_free()
 for i in 6: await process_frame
 var after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 var result := {"reachedMidExpansionMesh":reached,"frames":frames,"firstOrphanUnits":first_orphan_units,"canceledUnits":canceled_units,"baselineOrphans":baseline,"beforeCancelOrphans":before,"afterCancelOrphans":after,"ownerFreed":not is_instance_valid(game),"runningAfterCancel":progress.running(),"completeAfterCancel":progress.complete,"pauseRestored":not paused,"readyBeforeCancel":complete_before,"midMeshTrigger":"ownedTemporaryChildProgressesAcrossTwoBatches","headlessOnly":true,"nativeRenderingProven":false}
 print("MID_CANCEL_GAP "+JSON.stringify(result))
 quit(0 if reached and after<=baseline and not progress.running() and not progress.complete and not paused else 1)
