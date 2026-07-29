.PHONY: check smoke doctor verify verify-full help
ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

help:
	@echo "make smoke         - offline shell unit checks"
	@echo "make verify        - server verify (offline)"
	@echo "make verify-full   - server verify + start/stop stack (needs Desktop)"
	@echo "make doctor        - dependency doctor"
	@echo "make check         - bash -n + smoke"

check:
	@bash -n "$(ROOT)bin/buzz-desktop-headless"
	@bash -n "$(ROOT)lib/common.sh"
	@bash -n "$(ROOT)scripts/smoke-test.sh"
	@bash -n "$(ROOT)scripts/verify-server.sh"
	@bash "$(ROOT)scripts/smoke-test.sh"

smoke:
	@bash "$(ROOT)scripts/smoke-test.sh"

verify:
	@bash "$(ROOT)scripts/verify-server.sh"

verify-full:
	@BD_FUNCTIONAL=1 bash "$(ROOT)scripts/verify-server.sh"

doctor:
	@bash "$(ROOT)bin/buzz-desktop-headless" doctor --install-hints
