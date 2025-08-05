#!/bin/bash

# Usage: ./extract_studyuids_by_basepath.sh /mnt/disk3

# -------------------------------
# Input
# -------------------------------
BASEPATH="$1"

if [[ -z "$BASEPATH" || ! -d "$BASEPATH" ]]; then
  echo "❌ Please provide a valid basepath directory."
  echo "👉 Usage: $0 /mnt/disk3"
  exit 1
fi

# -------------------------------
# Configuration
# -------------------------------
MYSQL_USER="root"
MYSQL_PASS="Bibin"
MYSQL_HOST="192.168.180.203"
MYSQL_PORT="3307"
DB_NAME="pacsdb_m"

BASE_DIR="/home/ahis/APACS_APACSVNA_MIGRATION/TEST_11/work"
GROUP_DIR="$BASE_DIR/studyuid_groups"
DISK_LIST_DIR="$BASE_DIR/DISK_LIST"
LOG_FILE="$GROUP_DIR/$(basename "$BASEPATH")_log.txt"

mkdir -p "$GROUP_DIR" "$DISK_LIST_DIR"

# -------------------------------
# Dependency Check
# -------------------------------
for cmd in mysql curl jq readlink tee find; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "❌ Required command '$cmd' is not installed."
        exit 1
    fi
done

# -------------------------------
# Logging
# -------------------------------
exec > >(tee "$LOG_FILE") 2>&1
echo "🕒 Extracting UIDs from basepath: $BASEPATH"
echo "---------------------------------------------------"

# -------------------------------
# Skip symlinked basepaths
# -------------------------------
if [[ -L "$BASEPATH" ]]; then
    echo "🚫 Skipped symlink basepath: $BASEPATH"
    exit 1
fi

# -------------------------------
# Walk and Extract
# -------------------------------
safe_name=$(echo "$BASEPATH" | sed 's|/|_|g' | sed 's|^_||' | sed 's|[^a-zA-Z0-9_-]|_|g')
TMP_UID_FILE="$GROUP_DIR/${safe_name}.txt"
rm -f "$TMP_UID_FILE"

find "$BASEPATH" -type f ! -xtype l | while IFS= read -r full_path; do
    rel_path="${full_path#$BASEPATH/}"

    SQL_QUERY="SELECT s.study_iuid
    FROM files f
    JOIN instance i ON f.instance_fk = i.pk
    JOIN series se ON i.series_fk = se.pk
    JOIN study s ON se.study_fk = s.pk
    WHERE f.filepath = '$rel_path'
    LIMIT 1;"

    study_uid=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASS" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -N -e "$SQL_QUERY" "$DB_NAME")

    if [[ -n "$study_uid" && -f "$full_path" && ! -L "$full_path" ]]; then
        echo "$study_uid" >> "$TMP_UID_FILE"
        echo "✅ $rel_path → $study_uid"
    elif [[ -n "$study_uid" && -L "$full_path" ]]; then
        echo "🚫 Skipped symlink match: $rel_path"
    elif [[ -n "$study_uid" ]]; then
        echo "⚠️ File not found anymore: $rel_path"
    else
        echo "❌ Not found in DB: $rel_path"
    fi
done

if [[ -f "$TMP_UID_FILE" ]]; then
    FINAL_OUT="$DISK_LIST_DIR/${safe_name}.txt"
    sort -u "$TMP_UID_FILE" > "$FINAL_OUT"
    echo "➡️  UID list created: $FINAL_OUT"
else
    echo "🚫 No matching UIDs found."
fi

echo "✅ Done: $(date)"

