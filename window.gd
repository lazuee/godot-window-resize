#	https://github.com/lazuee/godot-window-resize
extends Node2D

signal resolution(size: Vector2i, ignoreSize: Vector2i)

@onready var defaultSize := Vector2i(int(ProjectSettings.get_setting_with_override("display/window/size/viewport_width")), int(ProjectSettings.get_setting_with_override("display/window/size/viewport_height")))
@onready var previousSize := Vector2i.ZERO
@onready var currentSize := DisplayServer.window_get_size()
@onready var aspectRatio := _get_aspect_ratio(defaultSize)

var ignoreSize := Vector2i.ZERO
var _timer : Timer = null

func _ready() -> void:
	_window_set_size()
	_window_set_centered()
	get_viewport().size_changed.connect(_window_set_size)

func _calculate_gcd(size: Vector2i) -> int:
	while size.y != 0:
		var sizeX = size.x
		size.x = size.y
		size.y = sizeX % size.y
	return size.x

func _get_aspect_ratio(size: Vector2i) -> Vector2i:
	var divisor = _calculate_gcd(size)
	@warning_ignore("integer_division")
	return Vector2i(size.x / divisor, size.y / divisor)

func _window_set_centered():
	DisplayServer.window_set_position(DisplayServer.screen_get_size() / 2 - DisplayServer.window_get_size() / 2)

func _window_set_size() -> void:
	currentSize = DisplayServer.window_get_size()
	if _timer != null:
		if _timer.is_inside_tree(): _timer.start()
		else: push_warning("Timer is not in the SceneTree")
		return

	_timer = Timer.new()
	_timer.name = "Resize"
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.wait_time = 1.0

	_timer.timeout.connect(func():
		if _timer.is_stopped(): return
		_timer.stop()

		if DisplayServer.window_get_position().y < 0:
			DisplayServer.window_set_position(Vector2i(DisplayServer.window_get_position().x, 0))

		var windowSize := _window_get_size()
		# Current window size is too small, set minimum window size
		if currentSize < defaultSize / 4:
			currentSize = defaultSize / 4
			windowSize = _window_get_size()
			DisplayServer.window_set_min_size(windowSize)
		
		# Current window size aspect ratio is incorrect, resize it
		if _get_aspect_ratio(windowSize) != aspectRatio:
			if windowSize == previousSize:
				currentSize = DisplayServer.window_get_size()
				windowSize = _window_get_size()
			
		if windowSize != previousSize:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				# If not windowed mode, set the current window size
				windowSize = DisplayServer.window_get_size()
			else: previousSize = windowSize

			# Set current window size
			DisplayServer.window_set_size(windowSize)
			resolution.emit(windowSize, ignoreSize)
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
		ignoreSize.y = 1
	elif currentSize.x == previousSize.x && ignoreSize.x == 1:
		ignoreSize.x = 0

	if currentSize.y != previousSize.y && ignoreSize.y == 0:
		@warning_ignore("integer_division")
		windowSize = _window_fix_size(Vector2i(currentSize.y / aspectRatio.y * aspectRatio.x, currentSize.y))
		ignoreSize.x = 1
	elif currentSize.y == previousSize.y && ignoreSize.y == 1:
		ignoreSize.y = 0

	return windowSize
