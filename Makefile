.PHONY: baseline iouring collect process

baseline:
	bash scripts/run_baseline.sh

iouring:
	bash scripts/run_io_uring.sh

collect:
	bash scripts/collect_logs.sh

process:
	python scripts/process_logs.py --run-id $(RUN_ID)
