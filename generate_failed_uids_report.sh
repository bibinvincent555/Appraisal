#!/bin/bash

# -----------------------------
# Source (v2) PACS DB (e.g., dcm4chee v2)
# -----------------------------
SRC_DB_HOST="192.168.180.203"
SRC_DB_PORT="3306"
SRC_DB_USER="root"
SRC_DB_PASS="Amma@123"
SRC_DB_NAME="pacsdb_m"

# -----------------------------
# Target (v5) PACS DB (e.g., dcm4chee v5.30)
# -----------------------------
TGT_DB_HOST="192.168.180.203"
TGT_DB_PORT="3306"
TGT_DB_USER="root"
TGT_DB_PASS="Amma@123"
TGT_DB_NAME="pacsdbvna_m"

# -----------------------------
# Output
# -----------------------------
REPORT_FILE="byte_level_mismatches.csv"
echo "StudyInstanceUID,SOPInstanceUID,SourceSize,TargetSize,Status" > "$REPORT_FILE"

echo "🔍 Running byte-level validation..."

# -----------------------------
# Get all instances from source
# -----------------------------
mysql -u "$SRC_DB_USER" -p"$SRC_DB_PASS" -h "$SRC_DB_HOST" -P "$SRC_DB_PORT" -D "$SRC_DB_NAME" -N -e "
SELECT i.sop_iuid, f.file_size, i.study_iuid
FROM file f
JOIN instance i ON f.instance_fk = i.pk
WHERE f.file_status = 0;" > /tmp/source_files.txt

total=$(wc -l < /tmp/source_files.txt)
count=0

# -----------------------------
# Compare each file entry
# -----------------------------
while IFS=$'\t' read -r sop_uid src_size study_uid; do
  ((count++))

  # Fetch target info
  tgt_info=$(mysql -u "$TGT_DB_USER" -p"$TGT_DB_PASS" -h "$TGT_DB_HOST" -P "$TGT_DB_PORT" -D "$TGT_DB_NAME" -N -e "
    SELECT object_size FROM location
    JOIN instance ON location.instance_fk = instance.pk
    WHERE instance.sop_iuid = '$sop_uid'
    AND location.status = 0
    ORDER BY location.pk DESC LIMIT 1;")

  # Result logic
  if [[ -z "$tgt_info" ]]; then
    echo "$study_uid,$sop_uid,$src_size,,MISSING" >> "$REPORT_FILE"
  elif [[ "$tgt_info" -eq "$src_size" ]]; then
    : # Do nothing for match (optional: log matched)
  else
    echo "$study_uid,$sop_uid,$src_size,$tgt_info,MISMATCH" >> "$REPORT_FILE"
  fi

  # Optional progress print
  if (( count % 1000 == 0 )); then
    echo "Progress: $count / $total"
  fi

done < /tmp/source_files.txt

echo "✅ Byte-level validation complete."
echo "⚠️ Mismatches (if any) saved to: $REPORT_FILE"

