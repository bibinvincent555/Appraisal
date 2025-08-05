#!/bin/bash

# -------------------------------------------
# Usage Check
# -------------------------------------------
UID_FILE="$1"

if [[ -z "$UID_FILE" || ! -f "$UID_FILE" ]]; then
  echo "❌ Please provide a valid file containing StudyInstanceUIDs to retry."
  echo "👉 Usage: ./retry_failed_for_file.sh failed_uids/<your_failed_file>.txt"
  exit 1
fi

# -------------------------------------------
# CONFIGURATION
# -------------------------------------------
API_URL="http://192.168.180.203:8080/dcm4chee-arc"
LOCAL_AET="APACSVNA"
REMOTE_AET="APACS"
DEST_AET="APACSVNA"

LOG_DIR="./logs"
SUMMARY_FILE="./retry_summary.csv"
BASENAME=$(basename "$UID_FILE" .txt)
LOG_FILE="$LOG_DIR/${BASENAME}_retry.log"
RETRY_FAILED_FILE="./failed_uids/${BASENAME}_retry_failed.txt"

# -------------------------------------------
# Ensure required folders exist
# -------------------------------------------
mkdir -p "$LOG_DIR" "./failed_uids"

# -------------------------------------------
# Get fresh token function
# -------------------------------------------
get_token() {
  ./get_token.sh
}

# -------------------------------------------
# Start
# -------------------------------------------
echo "🔁 Retrying migration for UIDs in: $UID_FILE"
echo "-----------------------------" > "$LOG_FILE"
echo "Start time: $(date)" >> "$LOG_FILE"

TOTAL=0
SUCCESS=0
FAILURE=0

mapfile -t UNIQUE_UIDS < <(sort -u "$UID_FILE")

TOKEN=$(get_token)
[[ -z "$TOKEN" ]] && echo "❌ Failed to get token. Exiting." && exit 1

for STUDY_UID in "${UNIQUE_UIDS[@]}"; do
  [[ -z "$STUDY_UID" ]] && continue
  TOTAL=$((TOTAL + 1))
  echo "➡️  Retrying Study: $STUDY_UID"

  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$API_URL/aets/$LOCAL_AET/dimse/$REMOTE_AET/studies/export/dicom:$DEST_AET?StudyInstanceUID=$STUDY_UID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{}")

  # If token expired or service unavailable
  if [[ "$RESPONSE" == "401" || "$RESPONSE" == "000" ]]; then
    echo "⚠️  Token expired or server error. Retrying with fresh token..."
    TOKEN=$(get_token)
    [[ -z "$TOKEN" ]] && echo "❌ Cannot continue without token." && exit 1

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "$API_URL/aets/$LOCAL_AET/dimse/$REMOTE_AET/studies/export/dicom:$DEST_AET?StudyInstanceUID=$STUDY_UID" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{}")
  fi

  if [[ "$RESPONSE" == "202" ]]; then
    echo "[SUCCESS] $STUDY_UID" >> "$LOG_FILE"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "[FAILURE] $STUDY_UID - HTTP $RESPONSE" >> "$LOG_FILE"
    echo "$STUDY_UID" >> "$RETRY_FAILED_FILE"
    FAILURE=$((FAILURE + 1))
  fi

  # sleep 0.5  # Optional delay
done

# -------------------------------------------
# Summary
# -------------------------------------------
echo "End time: $(date)" >> "$LOG_FILE"
echo "✅ Success: $SUCCESS" >> "$LOG_FILE"
echo "❌ Failure: $FAILURE" >> "$LOG_FILE"

echo "${BASENAME},$TOTAL,$SUCCESS,$FAILURE" >> "$SUMMARY_FILE"
echo "📝 Retry log saved: $LOG_FILE"
[[ "$FAILURE" -gt 0 ]] && echo "⚠️  Failed UIDs saved to: $RETRY_FAILED_FILE"

