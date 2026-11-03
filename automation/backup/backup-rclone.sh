#!/usr/bin/env bash
# ==============================================================================
# Homelab Automated Offsite Backup Script via Rclone
# Backs up application data directories, runs database dumps, and syncs
# archives to an offsite remote (e.g. encrypted Rclone remote / S3 / Hetzner).
# ==============================================================================

set -euo pipefail
umask 077

# --- Dependency Verification ---
for cmd in docker rclone tar gzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[!] Error: Required tool '$cmd' is not installed or not in PATH." >&2
        exit 1
    fi
done

# --- Configuration (Adjust for your environment or pass via env vars) ---
BACKUP_ROOT="${BACKUP_ROOT:-/opt/homelab}"
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive-encrypted:homelab-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
PAPERLESS_CONTAINER="${PAPERLESS_CONTAINER:-paperless_db}"
PAPERLESS_DB_USER="${PAPERLESS_DB_USER:-paperless}"
DATE_TAG="$(date +'%Y-%m-%d_%H%M%S')"

# Secure temporary workspace
LOCAL_TEMP_DIR="$(mktemp -d /tmp/homelab-backup.XXXXXX)"

cleanup() {
    local exit_code=$?
    if [[ -d "${LOCAL_TEMP_DIR:-}" ]]; then
        echo "[*] Cleaning up temporary workspace..."
        rm -rf "${LOCAL_TEMP_DIR}"
    fi
    exit "${exit_code}"
}
trap cleanup EXIT INT TERM

echo "[+] Starting homelab backup run at $(date)"

# --- Step 1: PostgreSQL Dumps (Example for Paperless) ---
if docker ps --format '{{.Names}}' | grep -qw "${PAPERLESS_CONTAINER}"; then
    echo "[*] Creating PostgreSQL dump for ${PAPERLESS_CONTAINER}..."
    docker exec "${PAPERLESS_CONTAINER}" pg_dumpall -U "${PAPERLESS_DB_USER}" | gzip > "${LOCAL_TEMP_DIR}/paperless_db_${DATE_TAG}.sql.gz"
else
    echo "[!] Notice: ${PAPERLESS_CONTAINER} container not running or not found. Skipping SQL dump."
fi

# --- Step 2: Archive Application Volumes ---
ARCHIVE_NAME="homelab_volumes_${DATE_TAG}.tar.gz"
echo "[*] Compacting application volumes from ${BACKUP_ROOT} into ${ARCHIVE_NAME}..."

if [[ -d "${BACKUP_ROOT}" ]]; then
    tar -czf "${LOCAL_TEMP_DIR}/${ARCHIVE_NAME}" \
        --exclude='*.log' \
        --exclude='tmp' \
        --exclude='cache' \
        --exclude='redisdata' \
        --exclude='pgdata' \
        -C "${BACKUP_ROOT}" .
else
    echo "[!] Warning: BACKUP_ROOT '${BACKUP_ROOT}' does not exist. Skipping volume tarball."
fi

# --- Step 3: Offsite Sync via Rclone ---
echo "[*] Transferring archives to offsite storage: ${RCLONE_REMOTE}..."
rclone copy "${LOCAL_TEMP_DIR}" "${RCLONE_REMOTE}/${DATE_TAG}" \
    --transfers 4 \
    --checkers 8 \
    --fast-list

# --- Step 4: Enforce Retention Policy on Remote ---
echo "[*] Pruning remote backups older than ${RETENTION_DAYS} days..."
rclone delete "${RCLONE_REMOTE}" --min-age "${RETENTION_DAYS}d" || true
rclone rmdirs "${RCLONE_REMOTE}" --leave-root || true

echo "[✓] Backup cycle completed successfully at $(date)!"
