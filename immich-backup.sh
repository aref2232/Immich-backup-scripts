#!/bin/sh

# Check for required commands
if ! command -v rclone >/dev/null 2>&1; then
    echo "Error: rclone is not installed."
    exit 1
elif ! command -v crc32 >/dev/null 2>&1; then
    echo "Error: crc32 is not installed."
    exit 1
elif ! command -v restic >/dev/null 2>&1; then
    echo "Error: restic is not installed."
    exit 1
fi

# Restic password
export RESTIC_PASSWORD="PASSWORD_HERE"  # Replace with your chosen password

# Paths
UPLOAD_LOCATION="/mnt/Immich/library"                  # Main directory containing Immich data
DB_BACKUP_LOCATION="$UPLOAD_LOCATION/database-backup"  # Temporary directory for database backups
BACKUP_REPO="rclone:onedrive:immich-backup"            # Rclone path for Restic repository
BACKUP_REPO_DB="onedrive:immich-backup-DB"
LOG_FILE="$HOME/immich_backup_script/log.txt"          # Log file path

# Ensure the log directory exists
mkdir -p "$HOME/immich_backup_script" || { echo "Error: Failed to create log directory." >&2; exit 1; }

# Ensure the database-backup directory exists
mkdir -p "$DB_BACKUP_LOCATION"

# Start logging
{
    echo "====================="
    echo "Backup started: $(date)"
    
    # Step 1: Backup Database and Upload
    echo "Backing up Immich database..."
    DB_BACKUP_FILE="$DB_BACKUP_LOCATION/immich-database-$(date +%Y%m%d%H%M%S).sql.gz"
    
    if docker ps -q -f name=immich_postgres; then
        docker exec -t immich_postgres pg_dumpall --clean --if-exists --username=postgres | gzip > "$DB_BACKUP_FILE"
    else
        echo "Error: immich_postgres container not running. Skipping database backup."
        exit 1
    fi

    if [ -f "$DB_BACKUP_FILE" ]; then
        CRC32HASH=$(crc32 "$DB_BACKUP_FILE")
        BASE_NAME="${DB_BACKUP_FILE%.sql.gz}"
        NEW_FILE_NAME="${BASE_NAME}_$CRC32HASH.sql.gz"
        CRC32_FILE="onedrive:immich-backup-DB/crc32_hashes.txt"
        LOCAL_CRC32_FILE="/tmp/crc32_hashes.txt"
        rclone cat "$CRC32_FILE" > "$LOCAL_CRC32_FILE"
        
        # Check if the CRC32 file exists
        if ! rclone lsf "$CRC32_FILE" > /dev/null 2>&1; then
            echo "" | rclone rcat "$CRC32_FILE"
        fi
        
        LOCAL_BACKUP_FILE=$(basename "$NEW_FILE_NAME")       
        if grep -q "$CRC32HASH" "$LOCAL_CRC32_FILE"; then
            sed -i "s|^$CRC32HASH|&,$LOCAL_BACKUP_FILE|" "$LOCAL_CRC32_FILE"
            echo "File with hash $CRC32HASH already exists. Added $NEW_FILE_NAME to it."
        else
            echo "$CRC32HASH == $LOCAL_BACKUP_FILE" >> "$LOCAL_CRC32_FILE"
            echo "New entry for $CRC32HASH added."
            echo "Uploading database backup to cloud..."
            if ! rclone copy "$DB_BACKUP_FILE" "$BACKUP_REPO_DB/database-backup"; then
                echo "Upload failed. Keeping local database backup for troubleshooting." >&2
                exit 1
            fi
            echo "Upload successful. Deleting local database backup..."
            rm -f "$LOCAL_BACKUP_FILE"
        fi

        rm -f "$LOCAL_BACKUP_FILE"
        rclone delete "$CRC32_FILE"
        rclone copy "$LOCAL_CRC32_FILE" "$CRC32_FILE"
        rm "$LOCAL_CRC32_FILE"
        echo "CRC32 hash file updated and uploaded to rclone."
    else
        echo "Database backup file not created. Skipping upload."
    fi

    # Step 2: Backup Immich Data
    if ! restic -r "$BACKUP_REPO" snapshots > /dev/null 2>&1; then
        restic -r "$BACKUP_REPO" init
    fi

    echo "Backing up Immich data to cloud..."
    restic -r "$BACKUP_REPO" backup "$UPLOAD_LOCATION" \
        --exclude "$UPLOAD_LOCATION/encoded-video/" \
        --exclude "$UPLOAD_LOCATION/thumbs/" \
        --verbose

    # Step 3: Prune Old Snapshots
    echo "Pruning old Restic snapshots (anything older than a month will only have 1 snapshot saved up to 6 months, anything this month will be saved)"
    restic -r "$BACKUP_REPO" forget \
        --keep-daily 0 \
        --keep-monthly 1 \
        --keep-within 6m \
        --prune

    echo "Backup completed successfully: $(date)"
} >> "$LOG_FILE" 2>&1
