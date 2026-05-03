#!/usr/bin/env bash
set -euo pipefail
exec ssh -o BatchMode=yes localhost "journalctl -u piclaw -n 50 --no-pager"
