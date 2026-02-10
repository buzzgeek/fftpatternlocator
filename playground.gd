extends Node2D

@onready var video = $VideoStreamPlayer
@onready var status = $RichTextLabel
@export var CellAgent: PackedScene

# There is some strange dependency between side and step for the fft and ifft to reconstruct the origal data. 
# This is rather strange behavior. I expected the ifft to be able to recontruct the original data independent of the 
# original length of the sample data
# for example:
# anything below 5 for step does not work if the side is multiple of 80?!? 
# only known initial prerequisite was that the data array has to have length mod 2 == 0 
#
# this "magical" behavior needs to be investigated
# the following rule needs to apply as well
# side ^ 2 / step ^ 2 => integer ^ 2 
# eg (side = 32 step = 2), (side = 16 step = 1) and (side = 40 step = 5) all apply to this rule and the resulting image looks good
# side:80 step:5 rows:3 cols:3
#
# note: steps and fine tunig can lead to higher compression if step is reduced to a minimum
# if filter is 0 that does not apply
# eg ( step:1, filter: 0.0005, maskPct: .5) has higer compression than ( step:8, filter: 0.0005, maskPct: .5)
# if filter is 0 the compression rate does not change for different step values
# # using the red channel value as blue channel value produces suprislingy good images (i.e. the blue channel is completely ignored in the provided example)
var side = 128
var step = 4
var rows = 3
var cols = 4
var offset = 80
var useInverseFFT = false
var useQuaternion = true
var enhanceImage = true
var useGreyImage = false
var lerpAbsMax = 1.0
var enhFac = 1.
var useWarpedRotationalAxys = false #redacted for now
var applyFftTwice = false # try useInveseFFT = false and applyFftTwice = true for surpising result
var useCompleteData = false # use complete rgba value as real of complex number instead of red for real and green for imag
var useCornerMask = false # works but the resulting image has poor quality
var useCircularMask = false
var useInverseCircularMask = false
var maskRadius = 0#.1 # flat value compression - note!!!!: use 0.7 for good hidden message results!!!
var cutoffFactor = 1.0 # coarse filter via mask, works but the resulting image has poor quality
var filter = 0#.001 # fine tuning via amplitude minimum values has the most impact on data compression - very effective compresion, dynamic
var useGradientChange = false
var difThreshold = 0.01 #value difference that triggers the gradient change
var memoryGain = 0.05
var memoryLoss = 0.05
var cells = {}
var t: Texture2D
var gap = 10
var cell_offset = side * .5
var pos = Vector2(0,0)
var selId = -1
var hideSecret = true # introducing secrets or watermark is possible but generation is unreliable if base image has alot of features (eg. showcase) - for bes results use maxRadius = 0.7
var hideDecoy = false # hide a decoy eg. obvious secret message
var currentChild = null
var expectedSecret = "SUNLIGHT"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn_cells()
	video.visible = false
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.connect("timeout", _on_timer_timeout)
	add_child(timer)
	timer.start()
	status.bbcode_enabled = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	t = video.get_video_texture()
	var x = 0
	var y = 0
	for cell in cells.values():
		var id = cell.get_ref().id
		y = (id / cols) * side
		x = (id % cols) * side
		x += offset
		y += offset
		var at = AtlasTexture.new()
		at.set_atlas(t)
		at.set_region (Rect2(Vector2(x,y), Vector2(side,side)))
		cell.get_ref().tex = at
		
func spawn_cells () -> void:
	var id = 0
	for r in range(rows):
		for c in range(cols):
			var cell = CellAgent.instantiate()
			cell.id = id
			cell.side = side
			cell.step = step
			cell.cutoffFactor = cutoffFactor
			cell.filter = filter
			cell.useInverse = useInverseFFT
			cell.applyFftTwice = applyFftTwice
			cell.useCompleteData = useCompleteData
			cell.useCornerMask = useCornerMask
			cell.useCircularMask = useCircularMask
			cell.useInverseCircularMask = useInverseCircularMask
			cell.maskRadius = maskRadius
			cell.difThreshold =  difThreshold
			cell.memoryGain = memoryGain
			cell.memoryLoss = memoryLoss
			cell.useGradientChange = useGradientChange
			cell.position.x = c * (side + gap) + cell_offset
			cell.position.y = r * (side + gap) + cell_offset 
			cell.hideSecret = hideSecret
			cell.hideDecoy = hideDecoy
			cell.useQuaternion = useQuaternion
			cell.useGreyImage = useGreyImage
			cell.lerpAbsMax = lerpAbsMax
			cell.enhFac = enhFac
			cell.useWarpedRotationalAxys = useWarpedRotationalAxys
			cell.enhanceImage = enhanceImage

			cells[cell.get_instance_id()] = weakref(cell)
			add_child(cell)
			id = id + 1

func _on_timer_timeout() -> void:
	if currentChild != null:
		var defcol = "[color=#ffffffff]"
		if currentChild.extractedSecret.length() > 0 or currentChild.extractedDecoy.length() > 0:
			var seccol = defcol
			if currentChild.extractedSecret.contains(expectedSecret):
				seccol = "[color=#00ff00ff]"
			status.text = "%s decoy: %s %ssecret: %s" % [defcol, currentChild.extractedDecoy, seccol, currentChild.extractedSecret]


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			pos.x = int(event.position.x / (side + gap))
			pos.y = int(event.position.y / (side + gap))
			selId = pos.y * cols + pos.x
			for child in get_children():
				if "relevantIndex" in child:
					child.relevantIndex = selId
					if child.id == selId:
						currentChild = child
			status.text = "selected id: " + str(selId)			
