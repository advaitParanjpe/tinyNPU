.PHONY: all help check precommit sim sim-apb sim-apb-dma sim-dma-desc sim-serial sim-full16 golden vectors synth synth-apb synth-dma-desc synth-serial synth-full16 results results-serial results-full16 compare clean

all: vectors golden sim synth results

help:
	@echo "tinyNPU targets:"
	@echo "  make check          Run lightweight repository checks"
	@echo "  make golden         Print fixed Python golden-model vectors"
	@echo "  make sim            Run default row4 simple-bus simulation"
	@echo "  make sim-apb        Run APB wrapper simulation"
	@echo "  make sim-apb-dma    Run testbench-only DMA-style APB model simulation"
	@echo "  make sim-dma-desc   Run synthesizable DMA descriptor-wrapper simulation"
	@echo "  make synth          Synthesize default row4 core with Yosys"
	@echo "  make synth-apb      Synthesize APB wrapper with Yosys"
	@echo "  make synth-dma-desc Synthesize DMA descriptor wrapper with Yosys"
	@echo "  make compare        Run sim/synth/results for row4, serial, and full16"
	@echo "  make precommit      Run commit-readiness regression"
	@echo "  make clean          Remove build artifacts"

check:
	python3 scripts/check_repo.py

precommit: check golden compare sim-apb sim-apb-dma sim-dma-desc synth-apb synth-dma-desc

sim:
	python3 sim/run_sim.py --mac-variant row4

sim-apb:
	python3 sim/run_apb_sim.py

sim-apb-dma:
	python3 sim/run_apb_dma_sim.py

sim-dma-desc:
	python3 sim/run_dma_descriptor_wrapper_sim.py

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

synth-apb:
	scripts/synth_yosys.sh apb

synth-dma-desc:
	scripts/synth_yosys.sh dma_desc

synth-serial:
	scripts/synth_yosys.sh serial

synth-full16:
	scripts/synth_yosys.sh full16

results: sim synth
	python3 scripts/save_result_snapshot.py --version v19 --mac-variant row4 --datapath "4-lane row MAC" --sim-summary build/sim/row4/sim_summary.json --synth-summary build/synth/row4/synth_summary.json

results-serial: sim-serial synth-serial
	python3 scripts/save_result_snapshot.py --version v19 --mac-variant serial --datapath "serial MAC baseline" --sim-summary build/sim/serial/sim_summary.json --synth-summary build/synth/serial/synth_summary.json

results-full16: sim-full16 synth-full16
	python3 scripts/save_result_snapshot.py --version v19 --mac-variant full16 --datapath "16-lane full parallel MAC" --sim-summary build/sim/full16/sim_summary.json --synth-summary build/synth/full16/synth_summary.json

compare: results results-serial results-full16

clean:
	rm -rf build
