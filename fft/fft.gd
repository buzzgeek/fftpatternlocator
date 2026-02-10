class_name FFT extends RefCounted

static func ifft(amplitudes: Array) -> Array:
	var N = len(amplitudes)

	for i in range(0,N):
		amplitudes[i] = amplitudes[i].conj()

	# apply fourier transform
	amplitudes = fft(amplitudes)

	for i in range(0,N):
		amplitudes[i] = amplitudes[i].conj()

	for i in range(0, N):
		if not amplitudes[i] is Complex:
			continue

		# scale
		amplitudes[i] = amplitudes[i].div(N)

	return amplitudes

# fft - alot faster than the dft but it uses recursion
static func fft(amplitudes: Array) -> Array:
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
		var term = Complex.new(0, (-2.0 * PI * k) / float(N))
		var amp = term.cexp().mul(odd[k])

		amplitudes[k] = even[k].sum(amp)
		amplitudes[k + hN] = even[k].sub(amp)
			
	return amplitudes


static func alt_fft(amplitudes: Array) -> Array:
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

	even = alt_fft(even)
	odd = alt_fft(odd)

	for k in range(0, hN):
		var term = Complex.new(0, (-2.0 * PI * k) / float(N))
		var amp = term.cexp().mul(odd[k])

		amplitudes[k] = even[k].sum(amp)
		
		amplitudes[hN + k] = even[k].sub(amp)
			
	return amplitudes


#dft - very slow
static func dft(data: Array[Complex], frequencies: Array[FreqComp]) -> Array[Complex]:
	var result : Array[Complex] = []
	var N = data.size()
	
	result.resize(N)
	for i in result.size():
		result[i] = Complex.new(0,0)
	
	for freq in frequencies:
		for n in N:
			var omega = -2.0 * PI * freq.frequency * float(n) / float(N)

			var term = Complex.new(0, omega) # note real part could be anythin because current implementatin discards it when calling cexp
			var r = data[n].mul(term.cexp())

			result[freq.frequency] = result[freq.frequency].sum(r)
	
	return result

# very expensive dft with all 0 to n frequencies
static func dftAll(data: Array[Complex]) -> Array[Complex]:
	var result : Array[Complex] = []
	var N = data.size()
	
	result.resize(N)
	for i in result.size():
		result[i] = Complex.new(0,0)
	
	for k in N:
		for n in N:
			var omega = (-TAU) * float(k) * float(n) / float(N)
			var term = Complex.new(0, omega)
			var r = data[n].mul(term.cexp())
			
			result[k] = result[k].sum(r)
	
	return result

# very expensive dft with half of all 0 to n frequencies (twice as fast as the previous dft but slightly different outcome - less colorfull??) - does not use reqursion
static func alt_dftAll(data: Array[Complex]) -> Array[Complex]:
	var result : Array[Complex] = []
	var N = data.size()
	
	result.resize(N)
	for i in result.size():
		result[i] = Complex.new(0,0)
	
	# note we are going thru the first half of frequencies only, the other half we get implicitly (almost but one frequency)
	for k in N/2:
		for n in N:
			var omega = (-TAU) * float(k) * float(n) / float(N)
			var term = Complex.new(0, omega)
			var r = data[n].mul(term.cexp())
			
			result[k] = result[k].sum(r)

			# by evaluating output data it looks like I need to swap the real and imag components for the other half of the signal
			# I really don't understand why this works?? It does not seem correct but the image result is prety close to the image result of the fft or dft with all freqs
			var tmp = Complex.new(r.imag, r.real) # swap the real and imag components
			
			# this is kinda strange too - there needs to b a slight shift in the symetrie by on step
			# this works better if the orig signal contained imag and real components???
			if(k != 0):
				result[N - k] = result[N - k].sum(tmp)

	var k = N/2
	#var res = result[k]
	# one single frequency is missing - let us calculate it
	for n in N:
		var omega = (-TAU) * float(k) * float(n) / float(N)
		var term = Complex.new(0, omega)
		var r = data[n].mul(term.cexp())
		
		result[k] = result[k].sum(r)
	
	return result


# inverse dft for multiple frequencies based on goertzel algorythm with sample rate equal to data length
# sample frequencyComponents [{ "frequency" : 1Hz, "magnitude": 0.5, "phase" : 1/PI}, ...]
static func idft(frequencyComponents: Array[FreqComp], length) -> Array[Complex]:
	var N = length	# number of samples is equal to sample rate
	var data : Array[Complex] = []
	
	for n in N:
		data.append(Complex.new(0,0)) 
	
	for comps in frequencyComponents:
		var omega = (2 * PI * comps.frequency) / N
		
		for n in N:
			data[n].real += comps.magnitude * cos(omega * n + comps.phase)
			data[n].imag += comps.magnitude * sin(omega * n + comps.phase)
		
	return data
