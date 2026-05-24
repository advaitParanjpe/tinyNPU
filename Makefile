.PHONY: all check precommit sim sim-serial sim-full16 golden vectors synth synth-serial synth-full16 results results-serial results-full16 compare clean

all: vectors golden sim synth results

check:
	python3 scripts/check_repo.py

precommit: check golden compare

sim:
	python3 sim/run_sim.py --mac-variant row4

sim-serial:
	python3 sim/run_sim.py --mac-variant serial

sim-full16:
	python3 sim/run_sim.py --mac-variant full16

golden:
	python3 model/golden_matmul.py --print-fixed

vectors:
	python3 model/golden_matmul.py --generate-json --generate-svh --num-tests 50 --seed 1 --out tests/test_vectors/generated_matmul_tests.json --svh-out tests/test_vectors/generated_matmul_tests.svh

synth:
	scripts/synth_yosys.sh row4

synth-serial:
	scripts/synth_yosys.sh serial

synth-full16:
	scripts/synth_yosys.sh full16

results: sim synth
	python3 scripts/save_result_snapshot.py --version v14 --mac-variant row4 --datapath "4-lane row MAC" --sim-summary build/sim/row4/sim_summary.json --synth-summary build/synth/row4/synth_summary.json

results-serial: sim-serial synth-serial
	python3 scripts/save_result_snapshot.py --version v14 --mac-variant serial --datapath "serial MAC baseline" --sim-summary build/sim/serial/sim_summary.json --synth-summary build/synth/serial/synth_summary.json

results-full16: sim-full16 synth-full16
	python3 scripts/save_result_snapshot.py --version v14 --mac-variant full16 --datapath "16-lane full parallel MAC" --sim-summary build/sim/full16/sim_summary.json --synth-summary build/synth/full16/synth_summary.json

compare: results results-serial results-full16

clean:
	rm -rf build
