#!/bin/sh
#  Host unit tests for the terminal's platform-free units: the CSI parser and the
#  screen model.  A HOST test on purpose (docs/terminal-emulation.md) - no boot,
#  no screen, no timing.  gprbuild is not on PATH in this sandbox, so the alr
#  toolchain bins are prepended; they come first so the host GNAT wins.
set -e
cd "$(dirname "$0")"
TB=$(ls -d "${HOME}/.local/share/alire/toolchains"/*/bin 2>/dev/null | tr '\n' ':')
PATH="${TB}${PATH}" gprbuild -p -P unit_tests.gpr
./bin/terminal_csi_test
./bin/terminal_screen_test
./bin/terminal_emul_test
