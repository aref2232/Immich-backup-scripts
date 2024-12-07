# Immich-backup-scripts
Scripts to backup/restore immich to rclone remote 
# Immich-backup-scripts
Scripts to backup/restore immich to rclone remote 

This script automates the process of backing up Immich's data and database to a cloud service using **rclone** and **restic**. It handles database backup, CRC32 hash tracking of DB files, and periodic backup of Immich's main data, all while pruning old snapshots to maintain a manageable backup size.

## Features

- Backs up Immich's PostgreSQL database.
- Uploads backups to a cloud storage service via **rclone**.
- Tracks and uploads CRC32 hashes for backup verification.
- Backs up Immich's library and other important data using **restic**.
- Prunes old backups using customizable retention policies (e.g., keep 1 snapshot per month, delete older snapshots).

## Requirements

Before using this script, ensure you have the following installed and configured on your system:

1. **rclone** – Used for managing cloud storage. ([Installation guide](https://rclone.org/install/))
2. **restic** – A fast, secure backup program. ([Installation guide](https://restic.readthedocs.io/en/latest/))
3. **crc32** – A tool for generating CRC32 checksums. You can install it via your package manager or use an alternative.

The script also requires Docker to be running with the Immich PostgreSQL container.

## Setup

1. **Install Dependencies**  
   Make sure `rclone`, `restic`, and `crc32` are installed on your system. You can install them using the following commands:
   
   ```bash
   sudo apt update
   sudo apt install rclone restic crc32

2. Configure rclone
    Set up rclone with your cloud storage provider (e.g., OneDrive, Google Drive, etc.).
    Follow the rclone configuration guide to link your cloud storage.

3. Set Restic Password
    Edit the script and replace "PASSWORD_HERE" with your Restic password.
    This password is used to encrypt your Restic backups.

export RESTIC_PASSWORD="your_password_here"

4 . Update Backup Locations
Set the correct paths for the Immich data and backup locations in the script. Modify the following variables to suit your setup:

    UPLOAD_LOCATION="/mnt/Immich/library"
    DB_BACKUP_LOCATION="/mnt/Immich/library/database-backup"
    BACKUP_REPO="rclone:onedrive:immich-backup"
    BACKUP_REPO_DB="onedrive:immich-backup-DB"

    These paths should point to your Immich library and the backup repository (e.g., an Rclone remote path).

  5. Log Directory
    The script creates log files in ~/immich_backup_script/log.txt by default. Ensure that the script can write to this location.

Usage

  Run the Backup Script
  Run the backup script by executing the following command:

    ./immich_backup_script.sh

  The script will:
        Check if the required tools (rclone, restic, crc32) are installed.
        Backup the Immich database and upload it to the specified cloud storage.
        Backup the Immich library and data using Restic.
        Prune old backups according to the retention policy (e.g., keep 1 snapshot per month for the last 6 months).

   Logs
    The script logs its actions to ~/immich_backup_script/log.txt. You can check this log file to verify the success or failure of the backup process.

Customizing Retention Policy

The script is configured to keep backups for the last 6 months and retain one snapshot per month using Restic. You can modify the retention policy in the following section of the script:

restic -r "$BACKUP_REPO" forget \
    --keep-daily 0 \
    --keep-monthly 1 \
    --keep-within 6m \
    --prune

You can change the --keep-daily, --keep-monthly, and --keep-within flags to fit your backup needs.
Troubleshooting

  Missing Dependencies
    If the script fails due to missing dependencies, make sure rclone, restic, and crc32 are installed and accessible from your system's PATH.
  
   Docker Container Not Running
    If the Immich database container (immich_postgres) is not running, the script will skip the database backup step and exit. Make sure the container is up and running before running the script.

  Permissions Issues
    If the script cannot write to the log or backup directories, ensure that the user running the script has the necessary permissions to create and modify files in those directories.
