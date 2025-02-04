#!/bin/bash

# Fix color output for both bash and zsh
if [[ "$SHELL" == *"zsh"* ]]; then
    GREEN=$'\e[32m'
    RESET=$'\e[0m'
else
    GREEN="\e[32m"
    RESET="\e[0m"
fi

green_echo() {
    echo -e "${GREEN}$1${RESET}"
}

# Create timestamp for the archive name
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="zond_bootstrap_${TIMESTAMP}.tar.gz"

green_echo "[+] Creating bootstrap archive: $ARCHIVE_NAME"

# Create bootstrap archive with specific excludes
tar czf "$ARCHIVE_NAME" \
    --exclude='network-keys' \
    --exclude='metaData' \
    --exclude='tosaccepted' \
    --exclude='LOCK' \
    --exclude='LOG*' \
    theQRL/gzonddata/gzond/chaindata \
    theQRL/beacondata/beaconchaindata

if [ $? -eq 0 ]; then
    green_echo "[+] Successfully created bootstrap archive"
    green_echo "[+] Note: This archive contains only chain data. Node-specific files (keys, peer info) are excluded."
    green_echo "[+] Archive location: $PWD/$ARCHIVE_NAME"
    green_echo "[+] Archive size: $(du -h "$ARCHIVE_NAME" | cut -f1)"
else
    green_echo "[!] Error creating bootstrap archive"
    exit 1
fi

green_echo "[+] To use this bootstrap data:"
green_echo "    1. Stop any running nodes"
green_echo "    2. Extract the archive to the target directory"
green_echo "    3. Restart the nodes"
green_echo ""
green_echo "Example extract command:"
green_echo "tar xzf $ARCHIVE_NAME -C /path/to/target/directory"