IV = iverilog -Wall
CORE = rtl/pe.v rtl/systolic_array.v rtl/skew.v
RTL = $(CORE) rtl/controller.v rtl/mm_accel.v
N ?= 4
K ?= 4
M ?= 8
P ?= 8
COUNT ?= 100
PIPE ?= 0
PDEF = $(if $(filter 1,$(PIPE)),-DPIPE)

.PHONY: test pe skew controller array wave vectors accel seq stream tiled ws nn gate mutation model perf synth fmax clean

test: pe skew controller array accel stream tiled ws

sim:
	mkdir -p sim

pe: sim
	$(IV) -o sim/pe_tb rtl/pe.v tb/pe_tb.v
	vvp -n sim/pe_tb

skew: sim
	$(IV) -o sim/skew_tb rtl/skew.v tb/skew_tb.v
	vvp -n sim/skew_tb

controller: sim
	$(IV) -P controller_tb.PIPE=$(PIPE) -o sim/controller_tb rtl/controller.v tb/controller_tb.v
	vvp -n sim/controller_tb

array: sim
	$(IV) -o sim/array_tb $(CORE) tb/array_tb.v
	vvp -n sim/array_tb

wave: array
	python3 scripts/plot_wave.py

vectors:
	python3 scripts/gen_vectors.py --n $(N) --k $(K) --count $(COUNT)

accel: sim vectors
	$(IV) $(PDEF) -P mm_accel_tb.N=$(N) -P mm_accel_tb.K=$(K) -o sim/mm_accel_tb $(RTL) tb/mm_accel_tb.v
	vvp -n sim/mm_accel_tb

seq: sim vectors
	$(IV) -DDUT=seq_mac -P mm_accel_tb.N=$(N) -P mm_accel_tb.K=$(K) -o sim/seq_tb rtl/seq_mac.v tb/mm_accel_tb.v
	vvp -n sim/seq_tb

stream: sim vectors
	$(IV) $(PDEF) -P stream_tb.N=$(N) -P stream_tb.K=$(K) -o sim/stream_tb $(CORE) rtl/mm_stream.v tb/stream_tb.v
	vvp -n sim/stream_tb

tiled: sim
	python3 scripts/gen_vectors.py --n $(N) --m $(M) --k $(K) --p $(P) --count 20
	$(IV) $(PDEF) -P tiled_tb.N=$(N) -P tiled_tb.M=$(M) -P tiled_tb.K=$(K) -P tiled_tb.P=$(P) -o sim/tiled_tb $(CORE) rtl/mm_stream.v rtl/mm_tiled.v tb/tiled_tb.v
	vvp -n sim/tiled_tb

ws: sim
	python3 scripts/gen_vectors.py --n $(N) --m $(M) --k $(K) --p $(P) --count 20
	$(IV) -DWS -P tiled_tb.N=$(N) -P tiled_tb.M=$(M) -P tiled_tb.K=$(K) -P tiled_tb.P=$(P) -o sim/ws_tb rtl/skew.v rtl/pe_ws.v rtl/ws_array.v rtl/mm_ws.v tb/tiled_tb.v
	vvp -n sim/ws_tb

nn: sim
	python3 scripts/nn_demo.py

gate:
	bash scripts/gatesim.sh

mutation:
	bash scripts/mutation.sh

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
