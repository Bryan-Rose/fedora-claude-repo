# Everything the PR CI job "check" runs. Offline; never runs the real build.
# Needs: ShellCheck, golang (actionlint is fetched and checksum-verified by the Go module proxy).
ACTIONLINT ?= go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12

.PHONY: check
check:
	shellcheck ci/*.sh tests/*.sh
	$(ACTIONLINT)
	tests/run.sh
