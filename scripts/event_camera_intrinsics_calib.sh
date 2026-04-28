#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

WORKSPACE_DIR="${REPO_ROOT}"
SETUP_BASH="${WORKSPACE_DIR}/devel/setup.bash"

INPUT_BAG=""
OUTPUT_DIR=""
RECON_BAG=""
EVENT_TOPIC=""
IMAGE_TOPIC=""
FPS="30"
CUTOFF_PERIOD="40"
TIME_OFFSET="0"
CAMERA_MODEL="pinhole-radtan"
BAG_FREQ="30"
APPROX_SYNC=""
TARGET_YAML=""
TARGET_TYPE=""
TARGET_ROWS=""
TARGET_COLS=""
ROW_SPACING_M=""
COL_SPACING_M=""
TAG_ROWS=""
TAG_COLS=""
TAG_SIZE_M=""
TAG_SPACING=""

SHOW_EXTRACTION=0
KALIBR_VERBOSE=0
EXPORT_POSES=0
KEEP_TEMP=0
SKIP_RECONSTRUCTION=0

usage() {
  cat <<'EOF'
Usage:
  event_camera_intrinsics_calib.sh --input-bag BAG --output-dir DIR --event-topic TOPIC \
    [--target-yaml FILE | --target-type checkerboard|apriltag ...] [options]

Required:
  --input-bag PATH              Input ROS1 bag containing the event topic.
  --output-dir PATH             Directory for the reconstructed bag, generated target YAML, logs, and Kalibr results.
  --event-topic TOPIC           Event topic to reconstruct, for example /dvxplorer_left/events.

Target configuration:
  --target-yaml PATH            Existing Kalibr target YAML. If provided, target geometry flags are ignored.
  --target-type TYPE            Target type: checkerboard or apriltag.

Checkerboard target arguments:
  --target-rows N               Number of inner corners along rows.
  --target-cols N               Number of inner corners along cols.
  --row-spacing-m VALUE         Checkerboard row spacing in meters.
  --col-spacing-m VALUE         Checkerboard col spacing in meters.

AprilTag target arguments:
  --tag-rows N                  Number of tags along rows.
  --tag-cols N                  Number of tags along cols.
  --tag-size-m VALUE            AprilTag edge size in meters.
  --tag-spacing VALUE           Ratio of inter-tag gap to tag size.

Optional reconstruction arguments:
  --workspace-dir PATH          Catkin workspace root. Default: repository root.
  --setup-bash PATH             setup.bash to source. Default: WORKSPACE_DIR/devel/setup.bash.
  --recon-bag PATH              Output bag path for reconstructed images.
  --image-topic TOPIC           Output image topic written by bag_to_frames. Default: EVENT_TOPIC + /image_raw.
  --fps VALUE                   Reconstruction frame rate. Default: 30.
  --cutoff-period N             simple_image_recon cutoff period. Default: 30.
  --time-offset SEC             Positive offset passed to bag_to_frames. Default: 0.
  --skip-reconstruction         Skip bag_to_frames and use an existing reconstructed bag.

Optional Kalibr arguments:
  --camera-model MODEL          Kalibr camera model. Default: pinhole-radtan.
  --bag-freq VALUE              Kalibr --bag-freq. Default: 5.
  --approx-sync SEC             Kalibr --approx-sync. Optional.
  --show-extraction             Pass --show-extraction to Kalibr.
  --kalibr-verbose              Pass --verbose to Kalibr.
  --export-poses                Pass --export-poses to Kalibr.

Other:
  --keep-temp                   Keep generated temporary target YAML.
  -h, --help                    Show this help.
EOF
}

log() {
  printf '[INFO] %s\n' "$*"
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_file() {
  [[ -f "$1" ]] || die "File not found: $1"
}

require_dir() {
  [[ -d "$1" ]] || die "Directory not found: $1"
}

is_positive_number() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

is_non_negative_number() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

append_cmd() {
  local quoted=()
  local arg
  for arg in "$@"; do
    quoted+=("$(printf '%q' "${arg}")")
  done
  printf '%s\n' "${quoted[*]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace-dir)
      WORKSPACE_DIR="$2"
      shift 2
      ;;
    --setup-bash)
      SETUP_BASH="$2"
      shift 2
      ;;
    --input-bag)
      INPUT_BAG="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --recon-bag)
      RECON_BAG="$2"
      shift 2
      ;;
    --event-topic)
      EVENT_TOPIC="$2"
      shift 2
      ;;
    --image-topic)
      IMAGE_TOPIC="$2"
      shift 2
      ;;
    --fps)
      FPS="$2"
      shift 2
      ;;
    --cutoff-period)
      CUTOFF_PERIOD="$2"
      shift 2
      ;;
    --time-offset)
      TIME_OFFSET="$2"
      shift 2
      ;;
    --camera-model)
      CAMERA_MODEL="$2"
      shift 2
      ;;
    --bag-freq)
      BAG_FREQ="$2"
      shift 2
      ;;
    --approx-sync)
      APPROX_SYNC="$2"
      shift 2
      ;;
    --target-yaml)
      TARGET_YAML="$2"
      shift 2
      ;;
    --target-type)
      TARGET_TYPE="$2"
      shift 2
      ;;
    --target-rows)
      TARGET_ROWS="$2"
      shift 2
      ;;
    --target-cols)
      TARGET_COLS="$2"
      shift 2
      ;;
    --row-spacing-m)
      ROW_SPACING_M="$2"
      shift 2
      ;;
    --col-spacing-m)
      COL_SPACING_M="$2"
      shift 2
      ;;
    --tag-rows)
      TAG_ROWS="$2"
      shift 2
      ;;
    --tag-cols)
      TAG_COLS="$2"
      shift 2
      ;;
    --tag-size-m)
      TAG_SIZE_M="$2"
      shift 2
      ;;
    --tag-spacing)
      TAG_SPACING="$2"
      shift 2
      ;;
    --show-extraction)
      SHOW_EXTRACTION=1
      shift
      ;;
    --kalibr-verbose)
      KALIBR_VERBOSE=1
      shift
      ;;
    --export-poses)
      EXPORT_POSES=1
      shift
      ;;
    --keep-temp)
      KEEP_TEMP=1
      shift
      ;;
    --skip-reconstruction)
      SKIP_RECONSTRUCTION=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "${INPUT_BAG}" ]] || die "--input-bag is required"
[[ -n "${OUTPUT_DIR}" ]] || die "--output-dir is required"
[[ -n "${EVENT_TOPIC}" ]] || die "--event-topic is required"

require_dir "${WORKSPACE_DIR}"
require_file "${SETUP_BASH}"
require_file "${INPUT_BAG}"

is_positive_number "${FPS}" || die "--fps must be a positive number"
is_positive_integer "${CUTOFF_PERIOD}" || die "--cutoff-period must be a positive integer"
is_non_negative_number "${TIME_OFFSET}" || die "--time-offset must be a non-negative number"
is_positive_number "${BAG_FREQ}" || die "--bag-freq must be a positive number"

if [[ -n "${APPROX_SYNC}" ]]; then
  is_positive_number "${APPROX_SYNC}" || die "--approx-sync must be a positive number"
fi

if [[ -z "${IMAGE_TOPIC}" ]]; then
  IMAGE_TOPIC="${EVENT_TOPIC}/image_raw"
fi

mkdir -p "${OUTPUT_DIR}"
TMP_DIR="${OUTPUT_DIR}/tmp"
RECON_DIR="${OUTPUT_DIR}/reconstructed"
RESULTS_DIR="${OUTPUT_DIR}/kalibr"
LOG_DIR="${OUTPUT_DIR}/logs"
mkdir -p "${TMP_DIR}" "${RECON_DIR}" "${RESULTS_DIR}" "${LOG_DIR}"

if [[ -z "${RECON_BAG}" ]]; then
  INPUT_STEM="$(basename "${INPUT_BAG}" .bag)"
  RECON_BAG="${RECON_DIR}/${INPUT_STEM}_reconstructed.bag"
fi

GENERATED_TARGET=0
if [[ -n "${TARGET_YAML}" ]]; then
  require_file "${TARGET_YAML}"
else
  [[ -n "${TARGET_TYPE}" ]] || die "Either --target-yaml or --target-type must be provided"
  case "${TARGET_TYPE}" in
    checkerboard)
      [[ -n "${TARGET_ROWS}" ]] || die "--target-rows is required for checkerboard"
      [[ -n "${TARGET_COLS}" ]] || die "--target-cols is required for checkerboard"
      [[ -n "${ROW_SPACING_M}" ]] || die "--row-spacing-m is required for checkerboard"
      [[ -n "${COL_SPACING_M}" ]] || die "--col-spacing-m is required for checkerboard"
      is_positive_integer "${TARGET_ROWS}" || die "--target-rows must be a positive integer"
      is_positive_integer "${TARGET_COLS}" || die "--target-cols must be a positive integer"
      is_positive_number "${ROW_SPACING_M}" || die "--row-spacing-m must be a positive number"
      is_positive_number "${COL_SPACING_M}" || die "--col-spacing-m must be a positive number"
      TARGET_YAML="${TMP_DIR}/target_checkerboard.yaml"
      cat > "${TARGET_YAML}" <<EOF
target_type: 'checkerboard'
targetRows: ${TARGET_ROWS}
targetCols: ${TARGET_COLS}
rowSpacingMeters: ${ROW_SPACING_M}
colSpacingMeters: ${COL_SPACING_M}
EOF
      GENERATED_TARGET=1
      ;;
    apriltag)
      [[ -n "${TAG_ROWS}" ]] || die "--tag-rows is required for apriltag"
      [[ -n "${TAG_COLS}" ]] || die "--tag-cols is required for apriltag"
      [[ -n "${TAG_SIZE_M}" ]] || die "--tag-size-m is required for apriltag"
      [[ -n "${TAG_SPACING}" ]] || die "--tag-spacing is required for apriltag"
      is_positive_integer "${TAG_ROWS}" || die "--tag-rows must be a positive integer"
      is_positive_integer "${TAG_COLS}" || die "--tag-cols must be a positive integer"
      is_positive_number "${TAG_SIZE_M}" || die "--tag-size-m must be a positive number"
      is_positive_number "${TAG_SPACING}" || die "--tag-spacing must be a positive number"
      TARGET_YAML="${TMP_DIR}/target_apriltag.yaml"
      cat > "${TARGET_YAML}" <<EOF
target_type: 'aprilgrid'
tagRows: ${TAG_ROWS}
tagCols: ${TAG_COLS}
tagSize: ${TAG_SIZE_M}
tagSpacing: ${TAG_SPACING}
EOF
      GENERATED_TARGET=1
      ;;
    *)
      die "--target-type must be checkerboard or apriltag"
      ;;
  esac
fi

cleanup() {
  if [[ "${KEEP_TEMP}" -eq 0 && "${GENERATED_TARGET}" -eq 1 && -f "${TARGET_YAML}" ]]; then
    rm -f "${TARGET_YAML}"
  fi
}
trap cleanup EXIT

require_command bash

RECON_LOG="${LOG_DIR}/bag_to_frames.log"
KALIBR_LOG="${LOG_DIR}/kalibr_calibrate_cameras.log"

RECON_CMD=(
  rosrun simple_image_recon bag_to_frames
  -i "${INPUT_BAG}"
  -o "${RECON_BAG}"
  -t "${EVENT_TOPIC}"
  -T "${IMAGE_TOPIC}"
  -f "${FPS}"
  -c "${CUTOFF_PERIOD}"
  -O "${TIME_OFFSET}"
)

KALIBR_CMD=(
  rosrun kalibr kalibr_calibrate_cameras
  --target "${TARGET_YAML}"
  --models "${CAMERA_MODEL}"
  --topics "${IMAGE_TOPIC}"
  --bag "${RECON_BAG}"
  --bag-freq "${BAG_FREQ}"
  --dont-show-report
)

if [[ -n "${APPROX_SYNC}" ]]; then
  KALIBR_CMD+=(--approx-sync "${APPROX_SYNC}")
fi
if [[ "${SHOW_EXTRACTION}" -eq 1 ]]; then
  KALIBR_CMD+=(--show-extraction)
fi
if [[ "${KALIBR_VERBOSE}" -eq 1 ]]; then
  KALIBR_CMD+=(--verbose)
fi
if [[ "${EXPORT_POSES}" -eq 1 ]]; then
  KALIBR_CMD+=(--export-poses)
fi

log "Workspace dir: ${WORKSPACE_DIR}"
log "Setup script: ${SETUP_BASH}"
log "Input bag: ${INPUT_BAG}"
log "Reconstructed bag: ${RECON_BAG}"
log "Event topic: ${EVENT_TOPIC}"
log "Image topic: ${IMAGE_TOPIC}"
log "Target yaml: ${TARGET_YAML}"

if [[ "${SKIP_RECONSTRUCTION}" -eq 1 ]]; then
  log "Skipping event reconstruction"
else
  log "Running event reconstruction"
  (
    set -euo pipefail
    source "${SETUP_BASH}"
    append_cmd "${RECON_CMD[@]}"
    "${RECON_CMD[@]}"
  ) 2>&1 | tee "${RECON_LOG}"
fi

require_file "${RECON_BAG}"

log "Running Kalibr camera calibration"
(
  set -euo pipefail
  source "${SETUP_BASH}"
  export KALIBR_MANUAL_FOCAL_LENGTH_INIT=1
  append_cmd "${KALIBR_CMD[@]}"
  "${KALIBR_CMD[@]}"
) 2>&1 | tee "${KALIBR_LOG}"

RECON_BAG_TAG="${RECON_BAG%.bag}"
KALIBR_OUTPUTS=(
  "${RECON_BAG_TAG}-camchain.yaml"
  "${RECON_BAG_TAG}-results-cam.txt"
  "${RECON_BAG_TAG}-report-cam.pdf"
  "${RECON_BAG_TAG}-poses-cam0.csv"
)

for file in "${KALIBR_OUTPUTS[@]}"; do
  if [[ -f "${file}" ]]; then
    cp -f "${file}" "${RESULTS_DIR}/"
  fi
done

log "Calibration completed"
log "Logs:"
log "  ${RECON_LOG}"
log "  ${KALIBR_LOG}"
log "Kalibr results directory: ${RESULTS_DIR}"
