#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MAC_VARIANT="${1:-row4}"
if [ "${MAC_VARIANT}" != "row4" ] && [ "${MAC_VARIANT}" != "serial" ] && [ "${MAC_VARIANT}" != "full16" ] && [ "${MAC_VARIANT}" != "apb" ]; then
  echo "ERROR: expected variant 'row4', 'serial', 'full16', or 'apb', got '${MAC_VARIANT}'"
  exit 2
fi

TOP_MODULE="tinynpu_top"
NETLIST_BASENAME="tinynpu_top_synth.v"
if [ "${MAC_VARIANT}" = "apb" ]; then
  TOP_MODULE="tinynpu_apb_wrapper"
  NETLIST_BASENAME="tinynpu_apb_wrapper_synth.v"
fi

SYNTH_ROOT="${REPO_ROOT}/build/synth"
SYNTH_DIR="${SYNTH_ROOT}/${MAC_VARIANT}"
LOG_FILE="${SYNTH_DIR}/yosys.log"
STAT_FILE="${SYNTH_DIR}/stat.txt"
NETLIST_FILE="${SYNTH_DIR}/${NETLIST_BASENAME}"
SUMMARY_FILE="${SYNTH_DIR}/synth_summary.json"
LATEST_SUMMARY_FILE="${SYNTH_ROOT}/synth_summary.json"
RUN_SCRIPT="${SYNTH_DIR}/synth_yosys.ys"

mkdir -p "${SYNTH_DIR}"
cd "${REPO_ROOT}"
sed \
  -e "s|@SYNTH_DIR@|build/synth/${MAC_VARIANT}|g" \
  -e "s|@TOP_MODULE@|${TOP_MODULE}|g" \
  -e "s|@NETLIST_PATH@|build/synth/${MAC_VARIANT}/${NETLIST_BASENAME}|g" \
  scripts/synth_yosys.ys > "${RUN_SCRIPT}"

if ! command -v yosys >/dev/null 2>&1; then
  echo "ERROR: yosys not found in PATH" | tee "${LOG_FILE}"
  exit 127
fi

YOSYS_CMD=(yosys)
if [ "${MAC_VARIANT}" = "serial" ]; then
  YOSYS_CMD+=( -D TINYNPU_MAC_SERIAL )
elif [ "${MAC_VARIANT}" = "full16" ]; then
  YOSYS_CMD+=( -D TINYNPU_MAC_FULL16 )
fi
YOSYS_CMD+=( -s "${RUN_SCRIPT}" )

if ! "${YOSYS_CMD[@]}" > "${LOG_FILE}" 2>&1; then
  tail -n 80 "${LOG_FILE}"
  exit 1
fi

if [ -f "${STAT_FILE}" ]; then
  python3 scripts/parse_yosys_stats.py "${STAT_FILE}" "${LOG_FILE}" "${NETLIST_FILE}" "${SUMMARY_FILE}" "${MAC_VARIANT}" "${TOP_MODULE}"
  cp "${SUMMARY_FILE}" "${LATEST_SUMMARY_FILE}"
fi
