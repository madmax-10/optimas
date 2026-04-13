#!/usr/bin/env bash
set -euo pipefail

#############################################
# Edit these if needed (no CLI arguments)
WORKDIR=""                 # e.g., "/abs/path/to/build" or leave empty
CMD="bash run.sh"          # run the benchmark driver script once per iteration
N=10                       # number of runs
TIMEOUT_SECS=300           # per-run timeout in seconds
#############################################

# cd if requested
if [[ -n "$WORKDIR" ]]; then
  cd "$WORKDIR"
fi

# Preflight: if CMD starts with a path, ensure it exists/executable
PROG="${CMD%% *}"
if [[ "$PROG" == */* && ! -e "$PROG" ]]; then
  echo "ERROR: Program not found: $PROG" >&2
  exit 1
fi

# Helper: strip ANSI escape codes
strip_ansi() { sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g'; }

outer_sum="0"
outer_count=0

for i in $(seq 1 "$N"); do
  echo "Run $i..." >&2
  raw="$(mktemp)"
  clean="$(mktemp)"

  # Run the command in the background, capture BOTH stdout+stderr
  ( eval "$CMD" ) >"$raw" 2>&1 &
  pid=$!

  # Manual timeout guard
  deadline=$((SECONDS + TIMEOUT_SECS))
  while kill -0 "$pid" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
      echo "Run $i timed out after ${TIMEOUT_SECS}s — killing PID $pid" >&2
      kill -TERM "$pid" 2>/dev/null || true
      sleep 1
      kill -KILL "$pid" 2>/dev/null || true
      echo "Last output:" >&2
      tail -n 50 "$raw" >&2 || true
      rm -f "$raw" "$clean"
      exit 1
    fi
    sleep 1
  done

  # Normalize output (strip CRs and ANSI codes)
  tr -d '\r' < "$raw" | strip_ansi > "$clean"

  # Extract all per-grid times (in microseconds)
  # Matches:
  #   "Average execution time of accuracy kernel: 340.687531 (us)"
  #   "Average execution time of the kernel: 436.530792 (us)"
  inner_sum="0"
  inner_count=0
  while read -r val; do
    inner_sum="$(awk -v a="$inner_sum" -v b="$val" 'BEGIN{printf "%.12f", a+b}')"
    inner_count=$((inner_count + 1))
  done < <(
    awk -F':' '
      /Average[[:space:]]+execution[[:space:]]+time[[:space:]]+of[[:space:]]+(the|accuracy)[[:space:]]+kernel[[:space:]]*:/ {
        rhs=$2
        sub(/\(us\).*/, "", rhs)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", rhs)
        if (rhs ~ /^[0-9]*\.?[0-9]+$/) print rhs
      }
    ' "$clean"
  )

  if (( inner_count == 0 )); then
    echo "Run $i: found no per-grid 'Average execution time ... (us)' lines." >&2
    grep -n "Average execution time" "$clean" >&2 || true
    echo "Last 20 lines:" >&2
    tail -n 20 "$clean" >&2 || true
    rm -f "$raw" "$clean"
    exit 1
  fi

  # Average for this run (microseconds)
  run_avg_us="$(awk -v s="$inner_sum" -v c="$inner_count" 'BEGIN{printf "%.12f", s/c}')"
  echo "  Run $i: averaged ${inner_count} grids -> ${run_avg_us} us" >&2

  outer_sum="$(awk -v a="$outer_sum" -v b="$run_avg_us" 'BEGIN{printf "%.12f", a+b}')"
  outer_count=$((outer_count + 1))

  rm -f "$raw" "$clean"
done

final_avg_us="$(awk -v s="$outer_sum" -v c="$outer_count" 'BEGIN{printf "%.12f", s/c}')"
echo "$final_avg_us"

