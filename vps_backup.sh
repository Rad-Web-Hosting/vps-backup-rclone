#!/bin/bash

# ================================
# VPS Full Backup Script Using rclone with Email Alerts
# ================================

# CONFIGURATION
BACKUP_DIR="/root"
BACKUP_NAME="fullbackup-$(date +%F).tar.gz"
REMOTE="gdrive_backup:/VPS-Backups"
RCLONE_PATH="/usr/bin/rclone"
TAR_PATH="/usr/bin/tar"
LOG_FILE="/root/backup_log.txt"
EMAIL_FILE="/root/.backup_email.conf"

# Load or ask for Email Address
if [ -f "$EMAIL_FILE" ]; then
  EMAIL_TO=$(cat "$EMAIL_FILE")
else
  read -p "Enter email address for backup notifications: " EMAIL_TO
  echo "$EMAIL_TO" > "$EMAIL_FILE"
fi

EMAIL_SUBJECT_SUCCESS="[VPS Backup] Success on $(hostname)"
EMAIL_SUBJECT_FAIL="[VPS Backup] Failure on $(hostname)"
MAIL_CMD="/usr/bin/mail"

# DIRECTORIES TO EXCLUDE (no spaces after commas)
EXCLUDES=("/proc" "/sys" "/dev" "/tmp" "/mnt" "/media" "/run")

# FUNCTIONS
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

send_email() {
  local subject="$1"
  $MAIL_CMD -s "$subject" "$EMAIL_TO" < "$LOG_FILE"
}

# Start Backup
log "Backup started."

# Build exclude parameters
EXCLUDE_PARAMS=""
for dir in "${EXCLUDES[@]}"; do
  EXCLUDE_PARAMS="$EXCLUDE_PARAMS --exclude=$dir"
done

# Create tar.gz backup
log "Creating compressed archive."
$TAR_PATH $EXCLUDE_PARAMS -czf "$BACKUP_DIR/$BACKUP_NAME" /
if [ $? -ne 0 ]; then
  log "Error creating tar.gz archive. Exiting."
  send_email "$EMAIL_SUBJECT_FAIL"
  exit 1
fi

# Upload to remote
log "Uploading $BACKUP_NAME to $REMOTE."
$RCLONE_PATH copy "$BACKUP_DIR/$BACKUP_NAME" "$REMOTE"
if [ $? -ne 0 ]; then
  log "Error uploading backup to remote. Exiting."
  send_email "$EMAIL_SUBJECT_FAIL"
  exit 1
fi

# Cleanup local backup (optional)
log "Cleaning up local archive."
rm -f "$BACKUP_DIR/$BACKUP_NAME"

log "Backup completed successfully."
send_email "$EMAIL_SUBJECT_SUCCESS"

exit 0
