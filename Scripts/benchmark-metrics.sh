#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
iterations="${1:-120}"

cd "$project_root"
swift run -c release PerformanceProbe --iterations "$iterations"
