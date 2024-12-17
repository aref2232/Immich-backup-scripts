#!/bin/bash

# Variables
SOURCE_BACKUP="odrive:immich-backup"                        # Source: immich-backup on OneDrive
DEST_BACKUP="gdrive:PATH-TO-IMMICH-SAVE-LOCATION/immich-backup"        # Destination for immich-backup on Google Drive

SOURCE_DB="odrive:immich-backup-DB"                         # Source: immich-backup-DB on OneDrive
DEST_DB="gdrive:PATH-TO-IMMICH-SAVE-LOCATION/immich-backup-DB"         # Destination for immich-backup-DB on Google Drive

LOG_FILE="$HOME/immich_sync_script/rclone_sync_log.txt"     # Log file path

# Function to print section headers
print_header() {
    echo "====================="
    echo "$1: $(date)"
}

# Function to sync folders
sync_folder() {
    local SRC=$1
    local DST=$2
    local DESC=$3

    print_header "Syncing $DESC started"
    rclone sync "$SRC" "$DST" \
        --progress \
        --ignore-existing \
        --transfers 8 \
        --checkers 8 \
        --checksum \
        --log-file="$LOG_FILE" \
        --log-level INFO

    # Check if the sync command was successful
    if [ $? -eq 0 ]; then
        print_header "$DESC sync completed successfully"
    else
        print_header "ERROR: $DESC sync failed"
        echo "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

# Start Sync Process
print_header "Starting Sync Process"


# Sync immich-backup-DB folder
sync_folder "$SOURCE_DB" "$DEST_DB" "immich-backup-DB folder"


# Sync immich-backup folder
sync_folder "$SOURCE_BACKUP" "$DEST_BACKUP" "immich-backup folder"


# End Sync Process
print_header "Sync Process Completed"
