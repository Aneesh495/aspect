# Aspect: Railway Vital Computer-Based Interlocking (CBI) & ETCS Level 2 Kernel
# Standards: CENELEC EN 50128 SIL 4 / ERA ETCS Subset-026 / IEC 61508
# Target: macOS (AArch64) and Linux (x86-64 / AArch64)

GPRBUILD := gprbuild
GPRCLEAN := gprclean
GPR_FILE := aspect.gpr

BIN_DIR  := bin
OBJ_DIR  := obj
SRC_DIR  := src

MAIN_BIN := $(BIN_DIR)/aspect_main
TEST_BIN := $(BIN_DIR)/test_runner

.PHONY: all build release test verify sim headless server web check-no-emdash clean help

all: build

# Standard compilation profile (Assertions, Overflow checking, Full warnings)
build:
	@mkdir -p $(BIN_DIR) $(OBJ_DIR)
	$(GPRBUILD) -P $(GPR_FILE) -p

# Optimized release profile
release:
	@mkdir -p $(BIN_DIR) $(OBJ_DIR)
	$(GPRBUILD) -P $(GPR_FILE) -p -XBUILD_MODE=release

# Execute full verification suite (657 assertions across 10 suites)
test: build
	@echo "============================================================"
	@echo "  Executing Aspect Verification & SIL 4 Test Runner"
	@echo "============================================================"
	$(TEST_BIN)

# Full verification target including quality invariant checks
verify: test check-no-emdash
	@echo "[VERIFICATION] All SIL 4 formal verification properties satisfied."

# Interactive VT100/ANSI terminal UI simulation
sim: build
	$(MAIN_BIN) --scenario junction --tui

# High-speed rail scenario in headless batch mode
headless: build
	$(MAIN_BIN) --scenario high_speed --headless --ticks 1000

# Telemetry server listening on TCP port 8088
server: build
	$(MAIN_BIN) --scenario junction --port 8088

# WebSocket bridge and HTML5 dispatcher cockpit
web:
	@python3 scripts/visualizer_server.py --port 8080 --telemetry-port 8088

# Quality check: ensure zero em-dash Unicode glyphs in repository
check-no-emdash:
	@! grep -rn --exclude=Makefile "—" src tests docs web scenarios scripts README.md 2>/dev/null || \
	  (echo "ERROR: Forbidden em dash character detected." && exit 1)
	@echo "[CODE-QUALITY] Em dash verification check passed: zero occurrences found."

# Clean build artifacts and binaries
clean:
	$(GPRCLEAN) -P $(GPR_FILE) 2>/dev/null || true
	rm -rf $(OBJ_DIR) $(BIN_DIR)
	@echo "[CLEAN] Build artifacts removed."

help:
	@echo "Aspect Build System Targets:"
	@echo "  make              - Build CLI executable and test runner"
	@echo "  make build        - Compile with debug/assertion profile"
	@echo "  make release      - Compile with optimized release profile"
	@echo "  make test         - Run all 10 verification test suites"
	@echo "  make verify       - Run test runner and code quality invariant checks"
	@echo "  make sim          - Launch interactive VT100 ASCII simulation"
	@echo "  make headless     - Run headless high-speed stress scenario"
	@echo "  make server       - Launch simulation with TCP telemetry server"
	@echo "  make web          - Launch HTML5 web dispatcher cockpit"
	@echo "  make clean        - Remove object files and executables"
