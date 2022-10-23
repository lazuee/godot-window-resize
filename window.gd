#	https://github.com/lazuee/godot-window-resize
extends Node


signal configured

var _timer : Timer = null

var _data := {
	"is_called": false,
	"curr_size": DisplayServer.window_get_size(),
	"prev_size": DisplayServer.window_get_size(),
}

#	Start!
func _enter_tree() -> void:
	_on_size_changed.call_deferred()
	get_viewport().size_changed.connect(_on_size_changed)

func _on_size_changed() -> void:
	var _size = _get_size(DisplayServer.window_get_size())
#	Update current size, if it's not equal
	if _size != Vector2i.ZERO:
		_data["curr_size"] = _size
		_set_window.call_deferred()

#	Calculate size by aspect ratio
func _get_size(size: Vector2i) -> Vector2i:
	if (_data["prev_size"].x != size.x):
		_data["prev_size"].x = size.x
		return Vector2i(size.x, round(size.x / 16.0 * 9.0))
	elif (_data["prev_size"].y != size.y):
		_data["prev_size"].y = size.y
		return Vector2i(round(size.y / 9.0 * 16.0), size.y)

	return Vector2i.ZERO

#	Set Window (mode/size)
func _set_window() -> void:
	if _timer != null:
#		Reset timeout, if still resizing
		if _timer.is_inside_tree(): _timer.start()
		else: push_warning("Timer is not in the SceneTree")

		return

	_timer = Timer.new()
	_timer.name = "Resize"
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.wait_time = 1.0

	_timer.timeout.connect(_on_timeout.bind(_timer))
	add_child(_timer)

	if _timer.is_stopped(): _timer.start()

func _on_timeout(timer: Timer):
		if timer.is_stopped(): return
		timer.stop()

#		Recommend Minimum Window size: 960,540
#		DisplayServer.window_set_min_size(Vector2(960,540))

		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			var prev_size = DisplayServer.window_get_size()
			var curr_size = _data["curr_size"]
			if prev_size.x != curr_size.x or prev_size.y != curr_size.y:
				# Check Aspect ratio at https://calculateaspectratio.com
				print("prev size: %s, current size: %s" % [prev_size, curr_size])
				DisplayServer.window_set_size(_data["curr_size"])

#				Set Window centered
#				_set_window_centered.call_deferred()

		configured.emit()

func _set_window_centered():
	var resolution: Vector2i = DisplayServer.screen_get_size()
	var window: Window = get_tree().get_root()
	window.position = resolution / 2 - window.size / 2
