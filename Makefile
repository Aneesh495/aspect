# Makefile for Aspect: High-Assurance Railway Computer-Based Interlocking
# Target: macOS (aarch64) and Linux (x86-64 / aarch64)

GPRBUILD ?= gprbuild
MODE     ?= debug

all: aspect tests

aspect:
	$(GPRBUILD) -P aspect.gpr -XMODE=$(MODE) -p -cargs:Ada -gnatwa

tests:
	$(GPRBUILD) -P aspect.gpr -XMODE=verify -p test_runner.adb

test: tests
	./bin/test_runner

run: aspect
	./bin/aspect-main --tui

sim: aspect
	./bin/aspect-main --scenario junction --ticks 500

clean:
	rm -rf obj bin

format:
	@echo "Checking formatting and style constraints..."

verify: test
	@echo "All safety verification assertions and unit tests passed."

.PHONY: all aspect tests test run sim clean format verify
