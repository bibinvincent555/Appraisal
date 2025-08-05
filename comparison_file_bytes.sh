#!/bin/bash
# File: compare_apacs_vs_apacsvna.sh
# Description: Compare all files in APACS vs APACSVNA by filename only, ignoring folder structure.

set -e

# ------------------------------
# Prompt user for paths
# ------------------------------
APACS_ROOT="$1"
APACSVNA_ROOT="$2"

if [[ -z "$APACS_ROOT" || -z "$APACSVNA_ROOT" ]]; then
  echo "❌ Usage: $0 <APACS_ROOT> <APACSVNA_ROOT>"
  exit 1
fi

if [[ ! -d "$APACS_ROOT" ]]; then
  echo "❌ Invalid APACS directory."
  exit 1
fi

if [[ ! -d "$APACSVNA_ROOT" ]]; then
  echo "❌ Invalid APACSVNA directory."
  exit 1
fi

# ------------------------------
# Temp working files
# ------------------------------
TMP_DIR="./compare_temp"
mkdir -p "$TMP_DIR"
APACS_LIST="$TMP_DIR/apacs_filenames.txt"
APACSVNA_LIST="$TMP_DIR/apacsvna_filenames.txt"
MISSING_IN_VNA="$TMP_DIR/missing_in_apacsvna.txt"
EXTRA_IN_VNA="$TMP_DIR/extra_in_apacsvna.txt"
COMMON_LIST="$TMP_DIR/common_filenames.txt"

# ------------------------------
# Function to list filenames
# ------------------------------
function generate_filename_list() {
  local root_dir="$1"
  local output_file="$2"
  echo "⏳ Scanning $root_dir ..."
  find "$root_dir" -type f -exec basename {} \; | sort -u > "$output_file"
}

# ------------------------------
# Generate filename lists
# ------------------------------
generate_filename_list "$APACS_ROOT" "$APACS_LIST"
generate_filename_list "$APACSVNA_ROOT" "$APACSVNA_LIST"

# ------------------------------
# Compare filenames
# ------------------------------
echo "🔍 Comparing filenames..."
comm -23 "$APACS_LIST" "$APACSVNA_LIST" > "$MISSING_IN_VNA"
comm -13 "$APACS_LIST" "$APACSVNA_LIST" > "$EXTRA_IN_VNA"
comm -12 "$APACS_LIST" "$APACSVNA_LIST" > "$COMMON_LIST"

# ------------------------------
# Byte size calculation
# ------------------------------
APACS_BYTES=$(find "$APACS_ROOT" -type f -exec du -b {} + | awk '{sum += $1} END {print sum}')
VNA_BYTES=$(find "$APACSVNA_ROOT" -type f -exec du -b {} + | awk '{sum += $1} END {print sum}')

# ------------------------------
# Results
# ------------------------------
echo "✅ Comparison complete."
echo "❌ Files present in APACS but missing in APACSVNA: $(wc -l < "$MISSING_IN_VNA")"
echo "ℹ️ File list: $MISSING_IN_VNA"

echo "📂 Files present in APACSVNA but not in APACS: $(wc -l < "$EXTRA_IN_VNA")"
echo "ℹ️ File list: $EXTRA_IN_VNA"

echo "✔️ Common files in both: $(wc -l < "$COMMON_LIST")"
echo "📃 File list: $COMMON_LIST"

echo "📊 Total bytes in APACS: $APACS_BYTES"
echo "📊 Total bytes in APACSVNA: $VNA_BYTES"

# Optional: Clean up
# rm -r "$TMP_DIR"

exit 0

