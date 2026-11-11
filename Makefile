IV = iverilog -Wall
RTL = rtl/pe.v rtl/systolic_array.v rtl/skew.v rtl/controller.v rtl/mm_accel.v
N ?= 4
K ?= 4
COUNT ?= 100

.PHONY: test pe skew array vectors accel seq model perf synth fmax clean

test: pe skew array accel

sim:
	mkdir -p sim

pe: sim
	$(IV) -o sim/pe_tb rtl/pe.v tb/pe_tb.v
	vvp -n sim/pe_tb

skew: sim
	$(IV) -o sim/skew_tb rtl/skew.v tb/skew_tb.v
	vvp -n sim/skew_tb

array: sim
	$(IV) -o sim/array_tb rtl/pe.v rtl/systolic_array.v tb/array_tb.v
	vvp -n sim/array_tb

vectors:
	python3 scripts/gen_vectors.py --n $(N) --k $(K) --count $(COUNT)

accel: sim vectors
	$(IV) -P mm_accel_tb.N=$(N) -P mm_accel_tb.K=$(K) -o sim/mm_accel_tb $(RTL) tb/mm_accel_tb.v
	vvp -n sim/mm_accel_tb

seq: sim vectors
	$(IV) -DDUT=seq_mac -P mm_accel_tb.N=$(N) -P mm_accel_tb.K=$(K) -o sim/seq_tb rtl/seq_mac.v tb/mm_accel_tb.v
	vvp -n sim/seq_tb

model:
	python3 scripts/os_model.py

perf: sim
	python3 scripts/perf.py

synth:
	bash scripts/synth.sh

fmax:
	bash scripts/fmax.sh

clean:
	rm -rf sim data
