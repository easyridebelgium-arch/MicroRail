extends SceneTree
## Run: godot --headless --path . --script res://tools/check_script_warnings.gd
## Promote enabled naming/usage warnings only in this process, without editing settings.
## Integer truncation is reviewed/documented at its calculation sites instead.
var checked := 0
var failures := 0
func _initialize() -> void:
	for property in ProjectSettings.get_property_list():
		var setting: String = property.name
		if not setting.begins_with("debug/gdscript/warnings/") or setting.ends_with("/integer_division"): continue
		var value: Variant = ProjectSettings.get_setting(setting)
		if typeof(value) == TYPE_INT and value == 1: ProjectSettings.set_setting(setting, 2)
	walk("res://scripts")
	print("Script warning audit: %d scripts, %d failures" % [checked, failures])
	quit(1 if failures else 0)
func walk(directory: String) -> void:
	for filename in DirAccess.get_files_at(directory):
		if not filename.ends_with(".gd"): continue
		checked += 1
		var script_resource := load(directory.path_join(filename)) as GDScript
		if script_resource == null or not script_resource.can_instantiate():
			failures += 1
			printerr("Warning audit failed: ", directory.path_join(filename))
	for child in DirAccess.get_directories_at(directory): walk(directory.path_join(child))
