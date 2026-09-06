HC := ./bin/hc

.PHONY: help setup doctor login new build run test submit submit-only clean check

help:
	@$(HC) help

setup:
	@$(HC) setup

doctor:
	@$(HC) doctor

login:
	@$(HC) login

# make new CONTEST=abc473
new:
	@test -n "$(CONTEST)" || (echo "usage: make new CONTEST=abc473" >&2; exit 2)
	@$(HC) new $(CONTEST)

# From repository root:
#   make test CONTEST=abc473 TASK=a
build run test submit submit-only:
	@test -n "$(CONTEST)" || (echo "CONTEST is required, e.g. CONTEST=abc473" >&2; exit 2)
	@test -n "$(TASK)" || (echo "TASK is required, e.g. TASK=a" >&2; exit 2)
	@$(HC) $@ $(CONTEST) $(TASK)

clean:
	@$(HC) clean

# Stubbed tests for bin/hc itself (no network access).
check:
	@./tests/hc_new_test.sh
