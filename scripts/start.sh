#!/usr/bin/env bash

set -euo pipefail

TARGET_TYPE="${1:-checkerboard}"

usage() {
  cat <<'EOF'
Usage:
  bash scripts/start.sh [checkerboard|apriltag]

Default:
  checkerboard
EOF
}

COMMON_ARGS=(
  --input-bag data/calibr.bag
  --output-dir data/calib_output
  --event-topic /capture_node/events
  --show-extraction
)

case "${TARGET_TYPE}" in
  checkerboard)
    bash scripts/event_camera_intrinsics_calib.sh \
      "${COMMON_ARGS[@]}" \
      --target-type checkerboard \
      --target-rows 5 \
      --target-cols 6 \
      --row-spacing-m 0.002 \
      --col-spacing-m 0.002
    ;;
  apriltag)
    bash scripts/event_camera_intrinsics_calib.sh \
      "${COMMON_ARGS[@]}" \
      --target-type apriltag \
      --tag-rows 4 \
      --tag-cols 4 \
      --tag-size-m 0.005 \
      --tag-spacing 0.5
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
