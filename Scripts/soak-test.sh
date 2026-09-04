#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: Scripts/soak-test.sh <duration-seconds> [sample-interval-seconds] [PulseBar.app] [warmup-seconds]" >&2
    echo "Examples: 28800 for 8 hours, 86400 for 24 hours" >&2
    exit 64
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
duration_seconds="$1"
sample_interval="${2:-30}"
provided_app="${3:-}"
warmup_seconds="${4:-30}"
work_root="$(mktemp -d /tmp/pulsebar-soak.XXXXXX)"
samples_file="$work_root/samples.tsv"
app_log="$work_root/PulseBar.log"
app_pid=""

# 退出时终止本脚本启动的进程并清理临时采样及日志，不触碰其他应用实例。
cleanup() {
    if [[ -n "$app_pid" ]] && kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi
    rm -rf "$work_root"
}
trap cleanup EXIT

if ! [[ "$duration_seconds" =~ ^[0-9]+$ ]] || (( duration_seconds < 10 )); then
    echo "Duration must be an integer of at least 10 seconds" >&2
    exit 64
fi
if ! [[ "$sample_interval" =~ ^[0-9]+$ ]] || (( sample_interval < 1 )); then
    echo "Sample interval must be a positive integer" >&2
    exit 64
fi
if ! [[ "$warmup_seconds" =~ ^[0-9]+$ ]]; then
    echo "Warmup duration must be a non-negative integer" >&2
    exit 64
fi

cd "$project_root"
if [[ -n "$provided_app" ]]; then
    app_path="$provided_app"
else
    derived_data="$work_root/DerivedData"
    xcodebuild -quiet \
        -project PulseBar.xcodeproj \
        -scheme PulseBar \
        -configuration Release-AppStore \
        -derivedDataPath "$derived_data" \
        build
    app_path="$derived_data/Build/Products/Release-AppStore/PulseBar.app"
fi

app_binary="$app_path/Contents/MacOS/PulseBar"
test -x "$app_binary"

"$app_binary" -onboarding.completed.v1 YES >"$app_log" 2>&1 &
app_pid="$!"
sleep 3
if ! kill -0 "$app_pid" 2>/dev/null; then
    echo "FAIL: PulseBar exited during launch" >&2
    sed -n '1,120p' "$app_log" >&2
    exit 1
fi

network_observed=0
warmup_deadline=$(($(date +%s) + warmup_seconds))
while (( $(date +%s) < warmup_deadline )); do
    if ! kill -0 "$app_pid" 2>/dev/null; then
        echo "FAIL: PulseBar crashed or exited during warmup" >&2
        sed -n '1,160p' "$app_log" >&2
        exit 1
    fi
    if lsof -nP -a -p "$app_pid" -i 2>/dev/null | tail -n +2 | grep -q .; then
        network_observed=1
    fi
    now="$(date +%s)"
    remaining=$((warmup_deadline - now))
    sleep_for="$sample_interval"
    if (( remaining < sleep_for )); then sleep_for="$remaining"; fi
    if (( sleep_for > 0 )); then sleep "$sleep_for"; fi
done

start_epoch="$(date +%s)"
deadline=$((start_epoch + duration_seconds))
printf 'elapsed_seconds\tphysical_footprint_kb\tcpu_percent\n' >"$samples_file"

while (( $(date +%s) < deadline )); do
    if ! kill -0 "$app_pid" 2>/dev/null; then
        echo "FAIL: PulseBar crashed or exited during soak" >&2
        sed -n '1,160p' "$app_log" >&2
        exit 1
    fi
    now="$(date +%s)"
    footprint_kb="$(
        /usr/bin/footprint --pid "$app_pid" --format bytes --noCategories 2>/dev/null \
            | awk '/phys_footprint:/ { print int($2 / 1024); exit }'
    )"
    cpu="$(ps -o pcpu= -p "$app_pid" | tr -d ' ')"
    printf '%s\t%s\t%s\n' "$((now - start_epoch))" "$footprint_kb" "$cpu" >>"$samples_file"
    if lsof -nP -a -p "$app_pid" -i 2>/dev/null | tail -n +2 | grep -q .; then
        network_observed=1
    fi
    sleep "$sample_interval"
done

read -r sample_count first_footprint last_footprint max_footprint footprint_growth max_cpu <<<"$(
    awk -F '\t' '
        NR == 2 { first = $2 }
        NR > 1 {
            count += 1
            last = $2
            if ($2 > maxrss) maxrss = $2
            if ($3 > maxcpu) maxcpu = $3
        }
        END { print count, first, last, maxrss, last - first, maxcpu }
    ' "$samples_file"
)"

echo "PulseBar soak result"
echo "warmup: ${warmup_seconds}s, duration: ${duration_seconds}s, samples: $sample_count"
echo "physical footprint: first=${first_footprint}KB, last=${last_footprint}KB, max=${max_footprint}KB, growth=${footprint_growth}KB"
echo "max observed CPU: ${max_cpu}%"
echo "external sockets observed: $network_observed"

if (( network_observed != 0 )); then
    echo "FAIL: external network socket observed" >&2
    exit 1
fi
if (( max_footprint >= 61440 )); then
    echo "FAIL: physical footprint exceeded the 60 MB product budget" >&2
    exit 1
fi
if (( footprint_growth > 10240 )); then
    echo "FAIL: physical footprint grew by more than 10 MB" >&2
    exit 1
fi

echo "PASS: soak completed without crash, external sockets, or memory-budget violation"
