# Makefile — offline checks (no root)
.PHONY: check smoke doctor help
ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

help:
	@echo "make smoke   - offline shell unit checks"
	@echo "make doctor  - runtime dependency doctor"
	@echo "make check   - smoke"

smoke check:
	@bash "$(ROOT)scripts/smoke-test.sh"

doctor:
	@bash "$(ROOT)bin/buzz-desktop-headless" doctor --install-hints
