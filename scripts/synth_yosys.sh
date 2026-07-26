#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MAC_VARIANT="${1:-row4}"
if [ "${MAC_VARIANT}" != "row4" ] && [ "${MAC_VARIANT}" != "row4_pipe" ] && [ "${MAC_VARIANT}" != "row4_pipe2" ] && [ "${MAC_VARIANT}" != "row4_pipe2_dupa" ] && [ "${MAC_VARIANT}" != "row4_pipe3" ] && [ "${MAC_VARIANT}" != "systolic4x4" ] && [ "${MAC_VARIANT}" != "serial" ] && [ "${MAC_VARIANT}" != "full16" ] && [ "${MAC_VARIANT}" != "apb" ] && [ "${MAC_VARIANT}" != "dma_desc" ] && [ "${MAC_VARIANT}" != "axi_lite" ] && [ "${MAC_VARIANT}" != "axi_read_dma" ] && [ "${MAC_VARIANT}" != "axi_dma" ]; then
  echo "ERROR: expected variant 'row4', 'row4_pipe', 'row4_pipe2', 'row4_pipe2_dupa', 'row4_pipe3', 'systolic4x4', 'serial', 'full16', 'apb', 'dma_desc', 'axi_lite', 'axi_read_dma', or 'axi_dma', got '${MAC_VARIANT}'"
  exit 2
fi

TOP_MODULE="tinynpu_top"
NETLIST_BASENAME="tinynpu_top_synth.v"
SUMMARY_MAC_VARIANT="${MAC_VARIANT}"
if [ "${MAC_VARIANT}" = "apb" ]; then
  TOP_MODULE="tinynpu_apb_wrapper"
  NETLIST_BASENAME="tinynpu_apb_wrapper_synth.v"
  SUMMARY_MAC_VARIANT="row4"
elif [ "${MAC_VARIANT}" = "dma_desc" ]; then
  TOP_MODULE="tinynpu_dma_descriptor_wrapper"
  NETLIST_BASENAME="tinynpu_dma_descriptor_wrapper_synth.v"
  SUMMARY_MAC_VARIANT="row4"
elif [ "${MAC_VARIANT}" = "axi_lite" ]; then
  TOP_MODULE="tinynpu_axi_lite_wrapper"
  NETLIST_BASENAME="tinynpu_axi_lite_wrapper_synth.v"
  SUMMARY_MAC_VARIANT="row4"
elif [ "${MAC_VARIANT}" = "axi_read_dma" ]; then
  TOP_MODULE="tinynpu_axi_read_dma_wrapper"
  NETLIST_BASENAME="tinynpu_axi_read_dma_wrapper_synth.v"
  SUMMARY_MAC_VARIANT="row4"
elif [ "${MAC_VARIANT}" = "axi_dma" ]; then
  TOP_MODULE="tinynpu_axi_dma_wrapper"
  NETLIST_BASENAME="tinynpu_axi_dma_wrapper_synth.v"
  SUMMARY_MAC_VARIANT="row4"
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
elif [ "${MAC_VARIANT}" = "systolic4x4" ]; then
  YOSYS_CMD+=( -D TINYNPU_MAC_SYSTOLIC4X4 )
elif [ "${MAC_VARIANT}" = "row4_pipe3" ]; then
  YOSYS_CMD+=( -D TINYNPU_MAC_ROW4_PIPE3 )
elif [ "${MAC_VARIANT}" = "row4_pipe2_dupa" ]; then
  YOSYS_CMD+=( -D TINYNPU_MAC_ROW4_PIPE2_DUPA )
elif [ "${MAC_VARIANT}" = "row4_pipe2" ]; then
  YOSYS_CMD+=( -D TINYNPU_MAC_ROW4_PIPE2 )
elif [ "${MAC_VARIANT}" = "row4_pipe" ]; then
  YOSYS_CMD+=( -D TINYNPU_MAC_ROW4_PIPE )
elif [ "${MAC_VARIANT}" = "full16" ]; then
  YOSYS_CMD+=( -D TINYNPU_MAC_FULL16 )
fi
YOSYS_CMD+=( -s "${RUN_SCRIPT}" )

if ! "${YOSYS_CMD[@]}" > "${LOG_FILE}" 2>&1; then
  tail -n 80 "${LOG_FILE}"
  exit 1
fi

if [ -f "${STAT_FILE}" ]; then
  python3 scripts/parse_yosys_stats.py "${STAT_FILE}" "${LOG_FILE}" "${NETLIST_FILE}" "${SUMMARY_FILE}" "${SUMMARY_MAC_VARIANT}" "${TOP_MODULE}"
  cp "${SUMMARY_FILE}" "${LATEST_SUMMARY_FILE}"
fi
