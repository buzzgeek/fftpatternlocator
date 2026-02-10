extends StaticBody2D
#const FFT = preload("res://fft/Fft.gd")
#const QFT = preload("res://fft/qft.gd")
#const FreqComp = preload("res://fft/FreqComp.gd")

var img : Image
var mutex : Mutex
var semaphore : Semaphore
var thread: Thread
var exit_thread := false
var terminated := false
var ampFactor := 1.0
var threshold := 0.9
var pattern : Array[Complex] = []
var complex : Array[Complex] = []
var quaternion: Array[Quaternion] = []
var quatMat = []
var rev_complex : Array[Complex] = []
var stm: Array[Complex] = []
var freqcomps: Array[FreqComp] = []
var targetFreqComps: Array[FreqComp] = []
var playground: Array[Complex] = []
var timer: Timer

var stmIndex = 0
var haveMinMax = false
var useSTM = false
var biasWeight = 1.0
var secret = "SUNLIGHT" # for example needs to have a len of 8 bytes
var decoy = "OBVIOUS" # no size constraints
var secretcomp: Array[Complex] = []
var decoycomp: Array[Complex] = []
var rangeMin = "A".to_ascii_buffer()[0]
var rangeMax = "Z".to_ascii_buffer()[0]
var rangeTotal = rangeMax - rangeMin
var invlerpTotal = inverse_lerp(0, 255, rangeTotal)
var maxChannelVal = 1.0 - invlerpTotal
var qseed = 0.0 # used for QFT obfuscation
var firstTex = false

@export var extractedSecret = ""
@export var extractedDecoy = ""

@onready var size = $CollisionShape2D.shape.size

@export var relevantIndex : int :
	set(value):
		
		relevantIndex = value
		
		if id == relevantIndex:
			semaphore.post()
			queue_redraw()
			if !timer.is_stopped() and id != relevantIndex:
				timer.stop()
			else:
				timer.start()

@export var tex : Texture2D:
	set(value):
		if !firstTex or !useQuaternion or true: #QFT
			firstTex = true
			tex = value
			mutex.lock()
			img = tex.get_image()
			mutex.unlock()
			semaphore.post()
			if id != relevantIndex:
				queue_redraw()
			

@export var side : int = 80 
@export var step : int = 5 
@export var id : int = -1
@export var useInverse = true
@export var filter = 1.1
@export var useCompleteData = false
@export var difThreshold = 0.01
@export var useGradientChange = false
@export var memoryGain = 0.05
@export var memoryLoss = 0.05
@export var cutoffFactor = 0.5
@export var useCornerMask = false
@export var useCircularMask = true # deprecated needs to be true for now
@export var useInverseCircularMask = true
@export var maskRadius = .5
@export var hideSecret = false
@export var hideDecoy = false
@export var applyFftTwice = false
@export var useQuaternion = false
@export var useGreyImage = true
@export var lerpAbsMax = 10.0
@export var enhFac = 1.0
@export var useWarpedRotationalAxys = false
@export var enhanceImage = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	exit_thread = false
	thread = Thread.new()
	thread.start(_thread_function)
	size.x = side
	size.y = side
	stm.resize(0)
	stmIndex = 0
	timer = Timer.new()
	timer.autostart = false
	timer.one_shot = false
	timer.wait_time = 1.0
	timer.connect("timeout", _on_timer_timeout)
	add_child(timer)
	
	for i in secret.length():
		var aval = secret.to_ascii_buffer()[i]
		var cval = 1.0 - inverse_lerp(rangeMin, rangeMax , aval)
		var comp = Complex.new(cval, cval)
		secretcomp.append(comp)

	for i in decoy.length():
		var aval = decoy.to_ascii_buffer()[i]
		var cval = 1.0 - inverse_lerp(rangeMin, rangeMax , aval)
		var comp = Complex.new(cval, cval)
		decoycomp.append(comp)

	
	# using fft data is not a good idea, due to increased introduced incaccuracies	
	#secretcomp = FFT.fft(secretcomp)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
		
func normalizeComplexArray(data : Array[Complex]) -> Array[Complex]:
	var mx = 0
	var mn = 0
	var result : Array[Complex] = []
	result.resize(data.size())
	for i in result.size():
		result[i] = Complex.new(0,0)
	
	for f in data.size():
		if mx < data[f].real:
			mx = data[f].real 
		if mx < data[f].imag:
			mx = data[f].imag 
		if mn > data[f].real:
			mn = data[f].real 
		if mn > data[f].imag:
			mn = data[f].imag 
	
	#TODO: ponder why this does not work?
	#if !(is_zero_approx(mn)	and is_equal_approx(mx, 1.0)) and !is_zero_approx(mx):	
	for f in complex.size():
		result[f].real = inverse_lerp(mn, mx, data[f].real)		
		result[f].imag = inverse_lerp(mn, mx, data[f].imag)		
	
		#print("min: %.2f - max: %.2f" % [mn, mx])

	return result

func _draw() -> void:
	# the folllowing section draws "single" pixels which is very expensive
	var cnt = 0					
	var dataLen = (side/float(step))*(side/float(step))
	if id != relevantIndex && tex != null:			
		# simply drawing the underlying texture is much cheaper and faster than drawing each pixel separatelly
		draw_texture(tex, Vector2(), Color(1.0, 1.0, 1.0, 0.5))
	elif tex != null:
		mutex.lock()
		
		if img != null:
			if complex.size() > 0:
				var i = 0
				cnt = 0
				
				#if !useCompleteData and !useQuaternion:
					#complex = normalizeComplexArray(complex)
					
				for r in range(0, side, step):
					for c in range(0, side, step):
						
						var amplitude = 0.0
						var col = Color.BLACK
						
						if complex[i] != null:
							amplitude = complex[i].mod()
							
							if useCompleteData:
								if complex[i].mod() > 0:
									col = Color.hex(int(complex[i].real))
							elif amplitude > 0.0:
								# using the red channel values as blue channel values produces surprisingly good images
								# i.e. the original blue channel value has been completely ignored
								# the factors are "magic" numbers, i.e. somewhat arbitrarily chosen
								
								var red = complex[i].real
								var green = complex[i].imag
								var blue =  complex[i].real
								var alpha = 1.0
								
								#QFT
								if useQuaternion:
									alpha = quaternion[i].w # this is how it really should be, but it looks less interesting
									red = quaternion[i].x
									green = quaternion[i].y
									blue = quaternion[i].z
								
								if useGreyImage:
									green = red
									blue = red
								
								# the typical normalized fft image looks quite boring
								# this "enhances" the image but his representation is incorrect
								if !useInverse && enhanceImage:
									var mn = 0
									var mx = 0
									if mx < alpha:
										mx = alpha
									if mx < red:
										mx = red
									if mx < green:
										mx = green
									if mx < blue:
										mx = blue
									if mn > alpha:
										mn = alpha
									if mn > red:
										mn = red
									if mn > green:
										mn = green
									if mn > blue:
										mn = blue

									alpha = 1.0 #inverse_lerp(mn, mx, alpha)	
									red = inverse_lerp(mn, mx, red)	
									green = inverse_lerp(mn, mx, green)	
									blue = inverse_lerp(mn, mx, blue)	
								
								if hideSecret && !useQuaternion:
									red += 0.2
									green += 0.2 
									blue += 0.1
							
								red = clampf(red, 0.0, 1.0)
								green = clampf(green, 0.0, 1.0)
								blue = clampf(blue, 0.0, 1.0)
								alpha = clampf(alpha, 0.0, 1.0)
								if useGreyImage:
									alpha = 1.0
								col = Color(red, green, blue, alpha)
						
						if !useQuaternion || quaternion[i].length() > 0:
							cnt += 1
						
						if i == stmIndex and useSTM:
							col = Color.GREEN
						
						draw_rect(Rect2(r, c, step, step), col)
						i = i + 1

				if freqcomps.size() > 0:
					cnt  = freqcomps.size()
				
				var dataCompressionRate = cnt / dataLen
			
				var sStatus = "%1.2f - %d in %d" % [dataCompressionRate, cnt,  dataLen]
				draw_string(ThemeDB.fallback_font, Vector2(2,30), sStatus, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.DARK_RED)
				
				var s = 1/sqrt(dataLen)
				qseed += PI * s
				if qseed > 4*PI or qseed < - 4*PI:
					s *= -1

		mutex.unlock()
	else:
		draw_rect(Rect2(0,0, side, side), Color.BLUE, false)
	
	if false:
		draw_string(ThemeDB.fallback_font, Vector2(10,30), str(id))

	if tex != null && false:
		draw_texture(tex, Vector2())
	
func _thread_function() -> void:
	while true:
		semaphore.wait()
		mutex.lock()
		var should_exit = exit_thread
		mutex.unlock()
		
		if should_exit:
			break
	
		if id != relevantIndex:	
			continue
		
		var totR = 0
		var dataLen = (side/float(step))*(side/float(step))
		var rl = int(sqrt(dataLen))
		
		# generate a cricular bitmap mask to filter unwanted values
		var mask = generateCircleBitmap(rl, floor(rl * maskRadius))
		if useInverseCircularMask:
			mask = generateInverseCircleBitmap(rl, floor(rl * maskRadius))
			#for xm in rl:
				#for ym in rl:
					#mask.set_bit(xm, ym, !secretMask.get_bit(xm, ym))
	
		
		# generate a bitmap masks to hold the secret
		var secretMask : BitMap = BitMap.new()
		secretMask.resize(Vector2(rl,rl))
		
		var x = rl / 2
		var y = rl / 2

		if step <= 8:
			#secretMask.set_bit(x-2,y-2, true)
			#secretMask.set_bit(x-2,y-1, true)
			#secretMask.set_bit(x-1,y-2, true)
			#secretMask.set_bit(x-1,y-1, true)
			#secretMask.set_bit(x+1,y+1, true)
			#secretMask.set_bit(x+2,y+1, true)
			#secretMask.set_bit(x+1,y+2, true)
			#secretMask.set_bit(x+2,y+2, true)
			secretMask.set_bit(x-1, y+2, true)
			secretMask.set_bit(x-2, y+1, true)
			secretMask.set_bit(x-2, y-1, true)
			secretMask.set_bit(x-1, y-2, true)
			secretMask.set_bit(x+1, y+2, true)
			secretMask.set_bit(x+2, y+1, true)
			secretMask.set_bit(x+2, y-1, true)
			secretMask.set_bit(x+1, y-2, true)
		
		
		if playground.size() < dataLen:
			playground.clear()
			for i in dataLen:
				playground.append(Complex.new(0,0))
		
		if tex != null && true:
			if img != null:
				mutex.lock()
				pattern.clear()
				quaternion.clear()
				quatMat.clear()

				var i = 0
				totR = 0
				for r in range(0, side, step):
					#var quatRow: Array[Quaternion] = []
					#quatMat.append(quatRow)
					for c in range(0, side, step):
						var col = img.get_pixel(r,c)
						if useCompleteData:
							# store the full color in the real part
							# note: the imag part is not used at all
							pattern.append(Complex.new(col.to_rgba32(), 0.0))
						else:
							var rval = clampf(col.r, 0.0, maxChannelVal)
							var ival = clampf(col.g, 0.0, maxChannelVal)
							var aval = Complex.new(rval, ival )
							if useGreyImage:
								aval = Complex.new(rval, 0 )
							# store red and green chanel values in real and imag parts
							pattern.append(aval)
							
							#QFT
							if useQuaternion:
								var quat = Quaternion()
								if useGreyImage:
									quat.w = 0.0 # has to be 0.0?
									quat.x = col.r
									quat.y = col.r
									quat.z = 0.0 # does not have to be 0.0 but is useful to test if complex rotation can be done with same function
								else:
									quat.w = col.a
									quat.x = col.r
									quat.y = col.g
									quat.z = col.b
									#Test to see if all channels are encoded - they are but 4D rotation is required
									#if true and i >= dataLen / 2:
										#quat.w = 0.2

								quaternion.append(quat)

						totR += col.r
						i = i + 1
				
				if hideDecoy:
					# add obvious secret message to beginning of image
					for si in decoy.length():
							pattern[si].real = decoycomp[si].real
							pattern[si].imag = decoycomp[si].imag

						
				#short term memory of avg red value
				stm.append(Complex.new(totR/float(dataLen), 0.0))
				if stm.size() > dataLen:
					stm.pop_front() #a bit expensive cause godot does not know linked lists 
				
				stmIndex += 1
				stmIndex %= int(dataLen)

				complex.clear()
				
				if not useSTM:
					for tok in pattern:
						var c = Complex.new(tok.real, tok.imag)
						complex.append(c)
				else:		
					for tok in stm:
						var c = Complex.new(tok.real,tok.imag)
						complex.append(c)	
				
				# check if padding is required
				if complex.size() < dataLen:
					for _i in dataLen - complex.size():
						complex.append(Complex.new(0,0))	

				# decode the decoy
				# note: occurs bevor applying fft 
				if hideDecoy:
					var decodeObvious : Array[Complex] = []
					for io in decoy.length():
						decodeObvious.append(Complex.new(0.0, lerp(rangeMin, rangeMax, 1.0 - complex[io].imag)))

					var obvious_msg = ""
					for chr in decodeObvious:							
						obvious_msg += "%c" % chr.imag
					obvious_msg += "\n"
					extractedDecoy = obvious_msg
				#QFT
				if useQuaternion:
					QFT.enhFac = enhFac
					QFT.useWarpedRotationalAxys = useWarpedRotationalAxys

					if false:
						quaternion = QFT.qdft2x2(quaternion, false)
						if useInverse:
							quaternion = QFT.qdft2x2(quaternion, true)
					else:
						quaternion = QFT.fft(quaternion)
						
						freqcomps.clear()
						if useCircularMask || !is_zero_approx(filter):
							for qhz in quaternion.size():
								if mask.get_bit(qhz / rl, qhz % rl) || (!is_zero_approx(filter) && quaternion[qhz].length() < filter):
									quaternion[qhz].x = .0
									quaternion[qhz].y = .0
									quaternion[qhz].z = .0
									quaternion[qhz].w = .0
								else:
									freqcomps.append(FreqComp.new()) # used for compression rate calculations, only
						
						#quaternion = QFT.dht(quaternion)
						if useInverse:
							quaternion = QFT.ifft(quaternion)
							#quaternion = QFT.dht(quaternion, true)

					#var count = QFT.CountUnique(quaternion)
					
				else:
					# fastest call for complex numbers - it is kinda slow here becose the Complex number is not native to Godot
					# doing this with Quaternions is a lot faster, because Quaternions have been implemented in Godot
					complex = FFT.fft(complex)
					#complex = FFT.alt_fft(complex)
					#complex = FFT.dftAll(complex) #check if provided same result as fft -> worx now, yes it does :)
					#complex = FFT.alt_dftAll(complex) #check if provided same result as fft -> worx now, yes it does :)
				
					if applyFftTwice:
						# kinda rotates the orig image by 180 degrees
						# note: we need to prep the real and imag parts for this to work nicely i.e. devide each componnent by the data length
						for c in complex:
							c.real /= dataLen
							c.imag /= dataLen
						complex = FFT.fft(complex) 
					
						# doing it again returns the original image (eg. this if block seems to do what the ifft is doing --> are they equal?)
						if false: #disabled for now	
							complex = FFT.fft(complex)
							for c in complex:
								c.real /= dataLen
								c.imag /= dataLen
							complex = FFT.fft(complex)

					# needed later on but will be removed soon
					if useCornerMask:
						rev_complex.clear()
						for c in complex:
							rev_complex.append(Complex.new(c.real, c.imag))
						rev_complex.reverse()

					 #apply filter and build frequency components array that is used lateron with the inverse discrete fourier transform function call
					var hz : int = 0 #it is important to start at 0Hz
					var cutoff = int(dataLen * cutoffFactor)
					var limit = rl
				
					for c in complex:
						var keyValue = 0
						if useCompleteData:
							var col = Color.hex(c.mod() / dataLen)
							keyValue = (col.r + col.g + col.b) / 3.0
						else:
							keyValue = c.mod() / dataLen

						if not useGradientChange:
							if keyValue > filter: #disable frequencies if bellow a given filter threshold
								if !useCornerMask and hz < cutoff:
									playground[hz].real = c.real
									playground[hz].imag = c.imag
								else:
									if hz < cutoff:
										# evaluate the top left triangle of the image if cut in half from corner to corner
										if hz % rl < limit:
											playground[hz].real = c.real
											playground[hz].imag = c.imag
										elif false: # deprecated
											# kinda worx but so does setting imag and real to 0
											# note real and imag have been swapped, seems to be important
											# this is just a test only reason why i have chosen the factor as is that the fft image looks like it might work
											# I am focsuing on mirroring patterns im the images
											var factor = float(limit)/rl 
											#factor = 0 #0 semms to provide the best outcome if the original data is not beeing used
											playground[hz].real = rev_complex[hz].imag * factor
											playground[hz].imag = rev_complex[hz].real * factor
									else: # check to see if there is symmetry between frequency values...there is not at least not a simple one
										var m = hz - cutoff 
										m = cutoff - (m + 1)
										
										var rn = hz / rl
										var cn = rl - hz % rl - 1
										var l = (rn * rl) + cn
										
										playground[l].real = playground[m].imag
										playground[l].imag = playground[m].real
										
										# just remove the values 
										playground[l].real = 0
										playground[l].imag = 0
							
							else:
								playground[hz].real = 0
								playground[hz].imag = 0
						elif hz < cutoff: 
							if !useCornerMask or (useCornerMask and hz % rl < limit):
								var dif = (c.mod() - playground[hz].mod()) / dataLen
								if not is_zero_approx(dif):
									if dif > difThreshold:
										playground[hz].real += c.real * memoryGain
										playground[hz].real = minf(playground[hz].real, c.real)
										playground[hz].imag += c.imag * memoryGain
										playground[hz].imag = minf(playground[hz].imag, c.imag)
									else:
										playground[hz].real -= playground[hz].real * memoryLoss
										playground[hz].real = maxf(playground[hz].real, c.real)
										playground[hz].imag -= playground[hz].imag * memoryLoss
										playground[hz].imag = maxf(playground[hz].imag, c.imag)
						
						# apply circular mask which is highly effective to compress the data (loss-full)
						# note: if the negated mask is used - edges can be detected...somewhat
						if useCircularMask:
							if mask.get_bit(hz / rl, hz % rl):
								playground[hz].real = 0
								playground[hz].imag = 0
								
						hz += 1
						if hz % rl == 0:
							limit -= 1

					freqcomps.clear()
					var j = 0
					for p in playground:
						var keyValue = 0
						if useCompleteData:
							var col = Color.hex(p.mod() / dataLen)
							keyValue = (col.r + col.g + col.b) / 3.0
						else:
							keyValue = p.mod() / dataLen
					
						if keyValue > 0.0: #filter: #disable frequencies if bellow a given filter threshold
							var freq = FreqComp.new()
							freq.frequency = j
							#freq.magnitude = complex[j].mod() / dataLen #actual magnitude
							freq.magnitude = p.mod() / dataLen #playground magnitude works better than actual magnitude !?
							freq.phase = atan2(p.imag, p.real)
							freqcomps.append(freq)
						elif hideSecret:
							var freq = FreqComp.new()
							freq.frequency = j
							freq.magnitude = 0 #playground magnitude works better than actual magnitude !?
							freq.phase = 0
							freqcomps.append(freq)
							
						j += 1
					
					if hideSecret:
						# add secret message
						#buzz
						#var index = get_next_index(floor(dataLen / 2), secretMask)
						var index = get_next_index(0, secretMask)
						for si in secret.length():
							playground[index].real = secretcomp[si].real
							playground[index].imag = secretcomp[si].imag
								
							index = get_next_index(index, secretMask)
						
						# sanity check if encoding and decoding is working
						if !useInverse:
								#extract hidden message
								var hidden_msg = ""
								#buzz
								#index = get_next_index(floor(dataLen / 2), secretMask)
								index = get_next_index(0, secretMask)

								# decode the secrete message
								var decode : Array[Complex] = []
								for hm in secret.length():
									decode.append(Complex.new(0.0, lerp(rangeMin, rangeMax, 1.0 - playground[index].real)))
									
									index = get_next_index(index, secretMask)

								for chr in decode:							
									hidden_msg += "%c" % chr.imag
								hidden_msg += "\n"
								
								extractedSecret = hidden_msg
					
					#use the playground data instead of the orig image				
					if freqcomps.size() > 0:
						complex.clear()
						for plg in playground:
							complex.append(plg)

					
					if useInverse:
						if freqcomps.size() > 0 and !hideSecret:
							complex = FFT.idft(freqcomps, dataLen)
							#complex = FFT.ifft(complex)
							if false:# testing dft method
								complex = FFT.dft(complex, freqcomps)
								complex = FFT.ifft(complex)
						else:
							complex = FFT.ifft(complex)
						
						if hideSecret:
							var sec_msg : Array[Complex] = []
							for fr in complex:
								sec_msg.append(fr)
			
							#if useInverse:
							sec_msg = FFT.fft(sec_msg)
							
							#extract hidden message
							var hidden_msg = ""
							#var index = get_next_index(floor(dataLen / 2), secretMask)
							var index = get_next_index(0, secretMask)

							# decode the secrete message
							var decode : Array[Complex] = []
							for hm in secret.length():
								decode.append(Complex.new(0.0, lerp(rangeMin, rangeMax, 1.0 - sec_msg[index].imag)))
								index = get_next_index(index, secretMask)

							for chr in decode:							
								hidden_msg += "%c" % chr.imag
							hidden_msg += "\n"
							
							extractedSecret = hidden_msg
			
							complex.clear()
							for sm in sec_msg:
								complex.append(sm)

							complex = FFT.ifft(complex)
							
				mutex.unlock()
		
		call_deferred("queue_redraw")

func get_next_index(cid : int, bitmap : BitMap) -> int:
	
	var sz = bitmap.get_size().x
	var ln = sz * sz
	
	for i in range(cid + 1, ln):
		if bitmap.get_bit(i/sz,i%sz):
			return i
	
	return 0

func generateCircleBitmap(x, r) -> BitMap:
	if r >= x:
		print("radius must be less than matrix size")
#
	var bitmap : BitMap = BitMap.new()
	var center = floor(x / 2); # Center of the matrix

	bitmap.resize(Vector2(x,x))

	for i in x:
		for j in x:
			var distance = sqrt((i - center) * (i - center) + (j - center) * (j - center))
			if distance < r:
				bitmap.set_bit(i, j, true)
	
	return bitmap

func generateInverseCircleBitmap(x, r) -> BitMap:
	if r >= x:
		print("radius must be less than matrix size")
#
	var bitmap : BitMap = BitMap.new()
	var center = floor(x / 2); # Center of the matrix

	bitmap.resize(Vector2(x,x))

	for i in x:
		for j in x:
			var distance = sqrt((i - center) * (i - center) + (j - center) * (j - center))
			if distance > r:
				bitmap.set_bit(i, j, true)
	
	return bitmap


func _on_timer_timeout() -> void:
	pass

	
func _exit_tree() -> void:
	if !terminated:
		terminated = true
		mutex.lock()
		exit_thread = true
		mutex.unlock()
		semaphore.post()
		thread.wait_to_finish()
		print("background thread terminated")
