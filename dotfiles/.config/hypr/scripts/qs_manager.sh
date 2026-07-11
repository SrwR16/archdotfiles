#!/usr/bin/env bash
set -euo pipefail

quickshell ipc call main handleCommand "$@"
