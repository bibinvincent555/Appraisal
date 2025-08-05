#!/bin/bash

# Usage: ./run_migration_for_path.sh /mnt/disk3

BASEPATH="$1"

if [[ -z "$BASEPATH" || ! -d "$BASEPATH" ]]; then
  echo "❌ Please provide a valid basepath directory."
  echo "👉 Usage: $0 /mnt/disk3"
  exit 1
fi

# -------------------------------------------
# Config
# -------------------------------------------
API_URL="http://192.168.180.203:8080/dcm4chee-arc"
LOCAL_AET="APACSVNA"
REMOTE_AET="APACS"
DEST_AET="APACSVNA"

DISK_LIST_DIR="./DISK_LIST"
LOG_DIR="./logs"
FAILED_DIR="./failed_uids"
SUMMARY_FILE="./migration_summary.csv"

safe_name=$(echo "$BASEPATH" | sed 's|/|_|g' | sed 's|^_||' | sed 's|[^a-zA-Z0-9_-]|_|g')
DISK_FILE="$DISK_LIST_DIR/${safe_name}.txt"
LOG_FILE="$LOG_DIR/${safe_name}.log"
FAILED_FILE="$FAILED_DIR/${safe_name}_failed.txt"

mkdir -p "$LOG_DIR" "$FAILED_DIR"

# -------------------------------------------
# Token Fetch
# -------------------------------------------
fetch_token() {
  TOKEN=$(./get_token.sh)
  if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    echo "❌ Failed to fetch token. Exiting."
    exit 1
  fi
}
echo "🔑 Fetching Keycloak token..."
fetch_token

# -------------------------------------------
# Logging Init
# -------------------------------------------
echo "📦 Migrating basepath: $BASEPATH"
echo "-----------------------------" > "$LOG_FILE"
echo "Start time: $(date)" >> "$LOG_FILE"

TOTAL=0
SUCCESS=0
FAILURE=0
> "$FAILED_FILE"   # Clear old failed list

# -------------------------------------------
# Input validation
# -------------------------------------------
if [[ ! -s "$DISK_FILE" ]]; then
  echo "❌ UID list $DISK_FILE is missing or empty."
  exit 1
fi

mapfile -t UNIQUE_UIDS < <(sort -u "$DISK_FILE")

for STUDY_UID in "${UNIQUE_UIDS[@]}"; do
  [[ -z "$STUDY_UID" ]] && continue

  TOTAL=$((TOTAL+1))
  echo "➡️  Migrating Study: $STUDY_UID"

  attempt=1
  max_attempts=3
  while [[ $attempt -le $max_attempts ]]; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "$API_URL/aets/$LOCAL_AET/dimse/$REMOTE_AET/studies/export/dicom:$DEST_AET?StudyInstanceUID=$STUDY_UID" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{}")

    if [[ "$RESPONSE" == "202" ]]; then
      echo "[SUCCESS] $STUDY_UID" >> "$LOG_FILE"
      SUCCESS=$((SUCCESS+1))
      break
    elif [[ "$RESPONSE" == "401" && $attempt -eq 1 ]]; then
      echo "⚠️ Token expired. Refreshing..."
      fetch_token
    elif [[ "$RESPONSE" == "000" || "$RESPONSE" =~ ^5 ]]; then
      echo "🔁 [$RESPONSE] Temporary error. Retrying after short wait... (Attempt $attempt)" >> "$LOG_FILE"
      sleep 3
    else
      echo "❌ [$RESPONSE] Permanent failure for $STUDY_UID" >> "$LOG_FILE"
      echo "$STUDY_UID" >> "$FAILED_FILE"
      FAILURE=$((FAILURE+1))
      break
    fi
    attempt=$((attempt+1))
  done

  # Final failure after all retries
  if [[ $attempt -gt $max_attempts ]]; then
    echo "❌ [$RESPONSE] Failed after $max_attempts attempts: $STUDY_UID" >> "$LOG_FILE"
    echo "$STUDY_UID" >> "$FAILED_FILE"
    FAILURE=$((FAILURE+1))
  fi
done

# -------------------------------------------
# Final logs
# -------------------------------------------
echo "End time: $(date)" >> "$LOG_FILE"
echo "✅ Success: $SUCCESS" >> "$LOG_FILE"
echo "❌ Failure: $FAILURE" >> "$LOG_FILE"
echo "${safe_name},$TOTAL,$SUCCESS,$FAILURE" >> "$SUMMARY_FILE"

echo "✅ Migration complete for $BASEPATH. Log: $LOG_FILE"
echo "📄 Failed UIDs (if any) saved to: $FAILED_FILE"

