class_name QFT extends RefCounted

static var useWarpedRotationalAxys : bool = false
static var enhFac : float = .1
static var R : Vector3 = Vector3(.0, .0, 1.0)
static var C : Vector3 = Vector3(1.0, .0, .0)
static var UnitV3 : Vector3 = Vector3(1.0, 1.0, 1.0).normalized()
#static var lerpAbsMax = 0


static func BitReverseOld(n : int, bits: int)  -> int:
	var reversedN = n
	var count = bits - 1
	
	n >>= 1
	while (n > 0):
		reversedN = (reversedN << 1) | (n & 1)
		count -= 1
		n = n >> 1
	#return reversedN;

	return ((reversedN << count) & ((1 << bits) - 1));


static func BitReverse(n : int, bits: int)  -> int:
	var reversedN = 0
	for _i in bits:
		reversedN = (reversedN << 1) | (n & 1)
		n = n >> 1
	return reversedN;


# normalize all quaternions so that the resulting units range from 0 to 1
static func normalizeQuats(data: Array[Quaternion]) -> Array[Quaternion]:
	var result : Array[Quaternion] = []
	var N = data.size()
	var mx = 0
	var mn = 0
	
	for i in N:
		result.append(Quaternion(0,0,0,0))

	for f in N:
		if mx < data[f].x:
			mx = data[f].x
		if mx < data[f].y:
			mx = data[f].y
		if mx < data[f].z:
			mx = data[f].z
		if mx < data[f].w:
			mx = data[f].w
		if mn > data[f].x:
			mn = data[f].x
		if mn > data[f].y:
			mn = data[f].y
		if mn > data[f].z:
			mn = data[f].z
		if mn > data[f].w:
			mn = data[f].w
	
	mn = 0
	
	for n in N:
		result[n].x = inverse_lerp(mn, mx, data[n].x)	
		result[n].y = inverse_lerp(mn, mx, data[n].y)	
		result[n].z = inverse_lerp(mn, mx, data[n].z)	
		result[n].w = inverse_lerp(mn, mx, data[n].w)	

	return result

static func getUnitQuaternion(omega : float, rV : Vector3 ) -> Quaternion:
	var a = cos(omega) # * .5) # .5 factor only relevant for 3D rotations
	var b = sin(omega) # * .5)

	var _v = rV
	_v = _v.normalized()
	var _4d_rot = Quaternion()
	_4d_rot.w = 1
	_4d_rot.x = _v.x
	_4d_rot.y = _v.y
	_4d_rot.z = _v.z
	
	#NOTE: rot.w has to be cos(omega) for this to work i.e. not rotation works only for unit quat spheres where w is cos(omega) and v*sin(omega) where v is normalized
	var rot = Quaternion(0,0,0,0)
	rot.w = a * _4d_rot.w
	rot.z = b * _4d_rot.x
	rot.x = b * _4d_rot.y
	rot.y = b * _4d_rot.z

	#assert(rot.is_normalized())	
	rot.normalized()

	return rot
	
#NOTE: we want to rotate in all 4 dimensions not just in 3D but we still choose 3D rotational Axis atm - need to test if any 4D unit quaternion worx as well for the rotation
#NOTE: It is required to rotate in all 4 dimension if all color channels rgba are used in the quaternion!!
static func rotateQuaternion(data : Quaternion, omega : float, rV : Vector3 ) -> Quaternion:
	var a = cos(omega) # * .5) # .5 factor only relevant for 3D rotations
	var b = sin(omega) # * .5)

	var _v = rV
	_v = _v.normalized()
	var _4d_rot = Quaternion()
	_4d_rot.w = 1
	_4d_rot.x = _v.x
	_4d_rot.y = _v.y
	_4d_rot.z = _v.z
	
	#NOTE: rot.w has to be cos(omega) for this to work i.e. not rotation works only for unit quat spheres where w is cos(omega) and v*sin(omega) where v is normalized
	var rot = Quaternion(0,0,0,0)
	rot.w = a * _4d_rot.w
	rot.z = b * _4d_rot.x
	rot.x = b * _4d_rot.y
	rot.y = b * _4d_rot.z

	#assert(rot.is_normalized())	
	rot.normalized()
	
	#var rotConj = Quaternion(rot)
	#rotConj.x = -rotConj.x
	#rotConj.y = -rotConj.y
	#rotConj.z = -rotConj.z
	
	# the conjugate of a unit quaternion is equal to the inverse of the given unit quaternion
	# assert(rotConj == rot.inverse()) #only important for 3D rotations
	
	# NOTE: this is the actual magic - quaternion multiplication includes rotation
	#var res = rot * data * rotConj # rotate  in 3D
	var res = rot * data #rotate in 4D

	#if false: #check for complex numbers only - deprecated for now coz it worx if data values have form 0 + ai + bj + 0k -> Quaternion(w: = 0.0, x: = a, y := b, z := 0), needs
		## to be rotated around the z - axis Quaternion(w: = 0.0, x: = 0, y := 0, z := 1)
		## let's do this in the complex space and check if the rotation can be translated for quaternion to complex if we spin around
		## to create a circle in the ij plane by spinning a unit vector in around the k axys
		#var cxRot = Complex.new(0, omega)
		#var cxData = cxRot.cexp().mul(Complex.new(data.x, data.y))
		#var cxRes = Quaternion()
		#cxRes.w = 0
		#cxRes.x = cxData.real
		#cxRes.y = cxData.imag
		#cxRes.z = 0
#
		##check if the rotations provide approx the same result...they do...test successful!
		#assert(cxRes.is_equal_approx(res))
	
	return res

#NOTE: this is a fast inverse of the fft but note that we need to perform a partial conjucation depending on the rotational axis
# w never gets conjugated
# the axis component that is being used for the rotation does not get conjugated
# all other axis due get conjugated
# that also impllies that we cannot rotate arround a non-axis vector
# Btw, the dft method does not have this issue, any rotational axis can be chosen

static func ifft_recursive(amplitudes: Array) -> Array:
	var N = len(amplitudes)

	for i in range(0,N):
		#amplitudes[i].x = -amplitudes[i].x
		amplitudes[i].y = -amplitudes[i].y
		amplitudes[i].z = -amplitudes[i].z

	# apply the fourier transform
	amplitudes = fft(amplitudes)

	for i in range(0,N):
		#amplitudes[i].x = -amplitudes[i].x
		amplitudes[i].y = -amplitudes[i].y
		amplitudes[i].z = -amplitudes[i].z

	amplitudes = normalizeQuats(amplitudes)				
	
	return amplitudes

static func ifft(amplitudes: Array) -> Array:
	# apply the inverse fourier transform (eg, reverse rotation)
	amplitudes = fft(amplitudes, true)

	# normalize the result (usally a division by data length, but normaliztion is more flexible)
	#amplitudes = normalizeQuats(amplitudes)				
	
	return amplitudes

# non-recursive implementation of cooley-tukey algorithm
static func fft(amplitudes: Array, inverse = false) -> Array:
	var result : Array[Quaternion] = []
	var N = amplitudes.size()
	var bits : int = log(N) / log(2)
	var anAxys = Vector3(1.0, 1.0, 1.0).normalized() # this is an arbitrary rotational axis, but it must be longer than 0
	
	result.resize(N)
	for i in N:
		var j = BitReverse(i, bits)
		result[j] = amplitudes[i]

	var s = 1
	while s <= bits:
		var m = pow(2, s)
		var h =  int(m/2)
		var i = 0
		while i < N:
			for j in h:
				var term = -TAU  * float(j) / (float(m))
				if inverse:
					term = -term
				
				var idx_even = i + j
				var idx_odd = i + j + h
				
				var even = result[idx_even]
			
				anAxys = anAxys.normalized()				
					
				var odd = rotateQuaternion(result[idx_odd], term, anAxys )
				
				result[idx_even] = even + odd
				result[idx_odd] = even - odd
			#
			i += m
		s = s + 1

	result = normalizeQuats(result)

	return result
	
	
# fft for quaternions - prety fast and it worx
static func fft_recursive(amplitudes: Array) -> Array:
	var xAxys = Vector3(1.0, .0, .0).normalized()
	var yAxys = Vector3(.0, 1.0, .0).normalized()
	var zAxys = Vector3(.0, .0, 1.0).normalized()
	var anAxys = Vector3(1., 1., 1.).normalized()
	var N = len(amplitudes)
	if N <= 1:
		return amplitudes
		
	var hN = N / 2
	var even = []
	var odd = []
	
	even.resize(hN)
	odd.resize(hN)

	for i in range(0, hN):
		even[i] = amplitudes[i * 2]
		odd[i] = amplitudes[i * 2 + 1]

	even = fft(even)
	odd = fft(odd)

	for k in range(0, hN):
		var term = -TAU  * float(k) / float(N)
		var amp = rotateQuaternion(odd[k], term, xAxys)

		amplitudes[k] = even[k] + amp
		amplitudes[hN + k] = even[k] - amp
			
	return amplitudes


#NOTE: this function looks kinda like a dft with complex numbers and it works
#special case: 
#rotatation around z axis rot = cos(omega/2) + sin(omega/2)k for quaternions q = ai + bj where k and real part are zero translates directly into 2D complex rotation where c = a + bi
#static func dft(data: Array[Quaternion], applyNorm : bool = true, inverse : bool = false ) -> Array[Quaternion]:
static func dft(data: Array[Quaternion], inverse : bool = false) -> Array[Quaternion]:
	var result : Array[Quaternion] = []
	var N = data.size()
	#var max = 0
	#var min = 0
	var xAxys = Vector3(1.0, .0, .0).normalized()
	var yAxys = Vector3(.0, 1.0, .0).normalized()
	var zAxys = Vector3(.0, .0, 1.0).normalized()
	var anAxys = Vector3(1., 1., 1.).normalized()
	
	result.resize(N)
	for i in result.size():
		result[i] = Quaternion(0,0,0,0)
	
	var qtot = Quaternion(0,0,0,0)
	for k in N:
		qtot = Quaternion(0,0,0,0)
		for n in N:
			var omega = -TAU / float(N) * float(k) * float(n)
			if inverse:
				omega = -omega
			#rotate around axies
			var r = rotateQuaternion(data[n], omega, anAxys)
			# we can add multiple unit rotations, if we like, and it still worx - disabled for now due to performance issues
			#r = rotateQuaternion(data[n], omega, xAxys)
			#r = rotateQuaternion(data[n], omega, yAxys)
			#r = rotateQuaternion(data[n], omega, zAxys)
			
			qtot += r
		
		result[k] += qtot
	
	# this would work too and it would be alot faster 
	#if inverse:
		#for k in N:
			#result[k] = result[k] / float(N)
	
	# but this approach has been used that so we can manipulate the quaternion arithmetic by changing its rules regading rotation
	if inverse:
		result = normalizeQuats(result)	
		
	return result

# this does function does not work
static func dht(data: Array[Quaternion], inverse : bool = false) -> Array[Quaternion]:
	var result : Array[Quaternion] = []
	var N = data.size()
	#var max = 0
	#var min = 0
	var xAxys = Vector3(1.0, .0, .0).normalized()
	var yAxys = Vector3(.0, 1.0, .0).normalized()
	var zAxys = Vector3(.0, .0, 1.0).normalized()
	var anAxys = Vector3(1., 1., 1.).normalized()
	
	var hdata = data.duplicate()
	#for i in N/2:
		#hdata[N/2 + i] = Quaternion(0,0,0,1)
		
	result.resize(N)
	for i in result.size():
		result[i] = Quaternion(0,0,0,0)
	
	#var qtot = Quaternion(0,0,0,0)
	for k in N/2:
		#qtot = Quaternion(0,0,0,0)
		for n in N:
			var omega = -TAU / float(N) * float(k) * float(n)
			if inverse:
				omega = -omega
			#rotate around axies
			var r = rotateQuaternion(hdata[n], omega, xAxys)
			var v = Vector3(r.x, r.y, r.z)
			var ir = Quaternion(0,0,0,0)
			ir.x = v.x
			ir.y = v.y
			ir.z = v.z
			ir.w = r.w
			
			# we can add multiple unit rotations, if we like, and it still worx - disabled for now due to performance issues
			#r = rotateQuaternion(data[n], omega, xAxys)
			#r = rotateQuaternion(data[n], omega, yAxys)
			#r = rotateQuaternion(data[n], omega, zAxys)
			result[k] += ir
			if(k != 0):
				result[N - k] -= ir
			#result[N - (k + 1)] -= ir

			#qtot += r
		
		#result[k] += qtot
	
	# this would work too and it would be alot faster 
	#if inverse:
		#for k in N:
			#result[k] = result[k] / float(N)
	
	# but this approach has been used that so we can manipulate the quaternion arithmetic by changing its rules regading rotation
	if inverse:
		result = normalizeQuats(result)	
		
	return result


# TODO: refactor based on new knowledge
# this function can be inverted but does not resemple a full fft equivalent 
static func qdft2x2(data: Array[Quaternion], useInverse : bool) -> Array[Quaternion]:
	var N = data.size()
	var result : Array[Quaternion] = []
	var zero = Quaternion(0.0, 0.0, 0.0, 1.0) 

	#sphere.resize(N)
	result.resize(N)
	for i in result.size():
		result[i] = zero
	
	for f in N:
		print("step %d of %d" % [f, N])
		var totq = Quaternion(0,0,0,0)
		for n in N:
			var dataSphere = projectDataToUnitSphere(data, n, useInverse)
			for ds in dataSphere:
				totq += ds
		
		result[f] += totq
	
	#result = normalizeQuats(result)

	return result

#TODO: refactor
# very expensive function used to analyze data for debuging purposes 
static func CountUnique(data: Array[Quaternion]) -> int:
	var map: Array[Quaternion]  = []
	var mx = 0
	var mn = 0
	
	var found = false
	var c = 0
	
	for f in data.size():
		if mx < data[f].x:
			mx = data[f].x
		if mx < data[f].y:
			mx = data[f].y
		if mx < data[f].z:
			mx = data[f].z
		if mx < data[f].w:
			mx = data[f].w
		if mn > data[f].x:
			mn = data[f].x
		if mn > data[f].y:
			mn = data[f].y
		if mn > data[f].z:
			mn = data[f].z
		if mn > data[f].w:
			mn = data[f].w
	
	for q in data:
		found = false
		for i in map.size():
			if q == map[i]:
				found = true
				break
		if !found:
			map.append(q)
		
		if c % data.size()/2 == 0:
			# create a copy and pseudo normalize value (eg min and max are not correct)
			var qn = Quaternion(q)
			qn.x = inverse_lerp(mn, mx, qn.x)
			qn.y = inverse_lerp(mn, mx, qn.y)
			qn.z = inverse_lerp(mn, mx, qn.z)
			qn.w = inverse_lerp(mn, mx, qn.w)
			print(qn)	
		c += 1	
	
	print("min: %.2f - max: %.2f" % [mn, mx])
	
	return map.size()

# project the 2x2 rgba image onto an unit sphere expressed via a 2x2 array of quats that rotates arround the QFT.R vector/axys.
# The images is alsow wrapped around the surface rotating around the QFT.R vector/axys frequency times 
# Distributes the values of the matrix over a unit sphere by rotating once over given axis QFT.R and than half over a second axis QFT.C
# NOTE: The invesere of the function is obtained by calling this fuction 4 times onto the previously endcoded data - i don't know why, but it works
static func projectDataOnToUnitSphere(data : Array[Quaternion], frequency: float = 1.0, unitSphere3D : Quaternion = Quaternion(UnitV3.x, UnitV3.y, UnitV3.z, 0.0)) -> Array[Quaternion]:
	var result : Array[Quaternion] = []
	
	# normalize provided data just in casw
	unitSphere3D = unitSphere3D.normalized()
	R = R.normalized()
	C = C.normalized()

	#data contains a 2D Matrix - Godot does not provide good 2D Array support
	var N = data.size()
	var rN = sqrt(N)
	var cN = rN
	result.resize(N)
	for i in N:
		result[i] = Quaternion(0,0,0,1)
	
	for r in rN:
		var omegaR = frequency * -PI * ((r + 1) / float(rN + 1)) * enhFac
		var omR = R * sin(omegaR)
		
		#rotate with discrete step (r + 1) / float(rN + 1) arround R axis
		var rotR = Quaternion(cos(omegaR), omR.x, omR.y, omR.z)
		if useWarpedRotationalAxys:
			rotR = Quaternion(R.x * sin(omegaR), R.y * sin(omegaR), R.z * sin(omegaR), cos(omegaR))
		rotR = rotR.normalized() # make sure the quat is normalized
		for c in cN:
			#rotate with discrete step (c + 1) / float(cN + 1) arround C axis
			#note the sin calls are not really necessary but the results are good looking :)
			var omegaC =  -PI * ((c + 1) / float(cN + 1)) * .5 * enhFac
			var omC = C * sin(omegaC)
			var rotC = Quaternion(cos(omegaC), omC.x, omC.y, omC.z )
			
			if useWarpedRotationalAxys:
				rotC = Quaternion(C.x * sin(omegaC), C.y * sin(omegaC), C.z * sin(omegaC), cos(omegaC))
			rotC = rotC.normalized() # make sure the quat is normalized
			
			var fq
			
			fq = rotR * unitSphere3D * rotR.inverse()
			fq = rotC * fq * rotC.inverse()
			
			#multiply unit sphere with data to encode magnitude and phases
			var f = r*rN+c
			fq *= data[f]
			
			result[f] += fq

	return result
#

# project the 2x2 rgba image as an unit sphere expressed via a 2x2 array of quats that rotates arround the QFT.R vector/axys.
# The images is alsow wrapped around the surface rotating around the QFT.R vector/axys frequency times 
# Distributes the values of the matrix over a unit sphere by rotating once over given axis QFT.R and than half over a second axis QFT.C
# NOTE: The inverse cannot be obtained by running this function multiple times. Please use the provided useInverse variable instead
static func projectDataToUnitSphere(data : Array[Quaternion], frequency: float = 1.0, useInverse : bool = false) -> Array[Quaternion]:
	var result : Array[Quaternion] = []
	#var max = 0
	
	R = R.normalized()
	C = C.normalized()

	#data contains a 2D Matrix - Godot does not provide good 2D Array support
	var N = data.size()
	var sN = sqrt(N)
	result.resize(N)
	for i in N:
		result[i] = Quaternion(0,0,0,1)
	
	for r in sN:
		var omegaR = -PI * float(N) * frequency * r 
		var oR = R * sin(omegaR)
		if useInverse:
			omegaR = -omegaR
		
		#rotate with discrete step (r + 1) / float(rN + 1) arround R axis
		var rotR = Quaternion(cos(omegaR),oR.x, oR.y, oR.z)
		rotR = rotR.normalized() # make sure the quat is normalized

		for c in sN:
			#rotate with discrete step (c + 1) / float(cN + 1) arround C axis
			#note the sin calls are not really necessary but the results are good looking :)
			#var omegaC =  -PI * ((c + 1) / float(sN + 1)) * .5 # * enhFac
			var omegaC =  -PI * (c / float(sN)) * .5 # * enhFac
			var oC = C * sin(omegaC)
			if useInverse:
				omegaR = -omegaR
			var rotC = Quaternion(cos(omegaC), oC.x, oC.y, oC.z)
			rotC = rotC.normalized() # make sure the quat is normalized
			
			var fq = data[r*sN+c]
			if !useInverse:
				fq = rotC * fq * rotC.inverse()
				fq = rotR * fq * rotR.inverse()
			else:
				fq = rotR.inverse() * fq * rotR
				fq = rotC.inverse() * fq * rotC
		
			result[r*sN+c] += fq

	return result
