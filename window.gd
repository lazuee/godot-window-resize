#	https://github.com/lazuee/godot-window-resize
extends Node2D

signal resolution(size: Vector2i)
@onready var defaultSize := Vector2i(int(ProjectSettings.get_setting_with_override("display/window/size/viewport_width")), int(ProjectSettings.get_setting_with_override("display/window/size/viewport_height")))
@onready var currentSize := DisplayServer.window_get_size()
@onready var previousSize := DisplayServer.window_get_size()
@onready var aspectRatio := _get_aspect_ratio(defaultSize)

var ignoreSize := Vector2i.ZERO
var _timer : Timer = null

func _ready() -> void:
	_window_set_size.call_deferred()
	get_viewport().size_changed.connect(_window_set_size)

func _calculate_gcd(size: Vector2i) -> int:
	while size.y != 0:
		var temp = size.x
		size.x = size.y
		size.y = temp % size.y
	return size.x

func _get_aspect_ratio(size: Vector2i) -> Vector2i:
	var divisor = _calculate_gcd(size)
	@warning_ignore("integer_division")
	return Vector2i(size.x / divisor, size.y / divisor)
	
func _window_set_size() -> void:
	currentSize = DisplayServer.window_get_size()
	if _timer != null:
		if _timer.is_inside_tree(): _timer.start()
		else: push_warning("Timer is not in the SceneTree")
		return

	_timer = Timer.new()
	_timer.name = "Resize"
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.wait_time = 0.5

	_timer.timeout.connect(func():
		if _timer.is_stopped(): return
		_timer.stop()

		var windowSize := _window_get_size()
		DisplayServer.window_set_size(windowSize)

		if DisplayServer.window_get_position().y < 0:
			DisplayServer.window_set_position(Vector2i(DisplayServer.window_get_position().x, 0))

		if currentSize < defaultSize / 4:
			currentSize = defaultSize
			windowSize = _window_get_size()
			DisplayServer.window_set_min_size(windowSize / 4)
			DisplayServer.window_set_size(windowSize / 4)

		resolution.emit(windowSize)
		previousSize = windowSize
		ignoreSize = Vector2i.ZERO
	)

	add_child(_timer)
	if _timer.is_stopped(): _timer.start()

func _window_fix_size(size: Vector2i):
	@warning_ignore("integer_division")
	var width = round((aspectRatio.x * size.y) / aspectRatio.y)
	@warning_ignore("integer_division")
	var height = round((size.x * aspectRatio.y) / aspectRatio.x)
	
	if _get_aspect_ratio(size) != aspectRatio:
		if _get_aspect_ratio(Vector2i(width, size.y)) == aspectRatio: size.x = width
		elif _get_aspect_ratio(Vector2i(size.x, height)) == aspectRatio: size.y = height
	return size

func _window_get_size() -> Vector2i:
	var windowSize := currentSize

	if currentSize.x != previousSize.x && ignoreSize.x == 0:
		@warning_ignore("integer_division")
		windowSize = _window_fix_size(Vector2i(currentSize.x, currentSize.x / aspectRatio.x * aspectRatio.y))
		print("Changed width: %s aspect ratio: %s" % [windowSize, _get_aspect_ratio(windowSize)])
		ignoreSize.y = 1
	elif currentSize.x == previousSize.x && ignoreSize.x == 1:
		ignoreSize.x = 0

	if currentSize.y != previousSize.y && ignoreSize.y == 0:
		@warning_ignore("integer_division")
		windowSize = _window_fix_size(Vector2i(currentSize.y / aspectRatio.y * aspectRatio.x, currentSize.y))
		print("Changed height: %s aspect ratio: %s" % [windowSize, _get_aspect_ratio(windowSize)])
		ignoreSize.x = 1
	elif currentSize.y == previousSize.y && ignoreSize.y == 1:
		ignoreSize.y = 0

	return windowSize
