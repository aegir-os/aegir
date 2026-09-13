#!/bin/sh
#  Host test for the CSI parser.
#
#  A HOST test on purpose (docs/terminal-emulation.md): the parser is
#  platform-free, so its checks need no boot, no screen and no timing.  gprbuild
#  is not on PATH in this sandbox, so the alr toolchain bins are added here; it
#  comes before PATH so the host GNAT wins.
set -e
cd "$(dirname "$0")"
TB=$(ls -d "${HOME}/.local/share/alire/toolchains"/*/bin 2>/dev/null | tr '\n' ':')
PATH="${TB}${PATH}" gprbuild -p -P csi_test.gpr
exec ./bin/terminal_csi_test
