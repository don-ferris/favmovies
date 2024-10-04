#!/bin/bash

# Global variables
INPUT_FILE="./gimme/gimme.list"
SYNC_SCRIPT="./gimme/sync.sh"
LOG_FILE="./gimme/gimme.log"
OUTDIR="./gimme/downloads"  # Output directory for downloads
MAX_CONCURRENT_DOWNLOADS=5  # Maximum number of concurrent downloads
SYNC_PAUSE=30  # Pause duration in seconds before each download

# Function to log errors to gimme.log, prepending them to the top
log_error() {
    local message="$1"

    # Prepend the message to the log file
    if ! printf "%s\n" "$message" | cat - "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"; then
        printf "Error: Failed to write to log file '%s'.\n" "$LOG_FILE" >&2
    fi
}

# Function to download a file using wget and then remove it from the list
download_file() {
    local url="$1"

    # Ensure the output directory exists
    mkdir -p "$OUTDIR"

    # Run the sync script before downloading (no checks, as per your request)
    bash "$SYNC_SCRIPT"
    sleep "$SYNC_PAUSE"

    # Download using wget with the -c flag for resuming downloads and set the output directory
    if wget -c -P "$OUTDIR" "$url"; then
        # Remove the successfully downloaded URL from the original file
        if ! sed -i "\|^$url\$|d" "$INPUT_FILE"; then
            log_error "Error: Failed to remove URL from the list: $url"
        fi
    else
        # If the download fails, log the error
        log_error "Failed to download URL: $url"
    fi
}

# Function to download files concurrently using xargs
download_files_concurrently_with_xargs() {
    # Check if the input file exists
    if [[ ! -f "$INPUT_FILE" ]]; then
        printf "Error: File '%s' does not exist.\n" "$INPUT_FILE" >&2
        return 1
    fi

    # Check if the output directory exists, if not create it
    mkdir -p "$OUTDIR"

    # Export necessary environment variables and functions for xargs to use
    export -f log_error download_file
    export INPUT_FILE LOG_FILE OUTDIR SYNC_SCRIPT SYNC_PAUSE

    # Use xargs to pass URLs and execute download_file concurrently with a display of progress
    grep -E '^http' "$INPUT_FILE" | xargs -n 1 -P "$MAX_CONCURRENT_DOWNLOADS" -I {} bash -c 'download_file "{}"'
}

# Main function to encapsulate the script logic
main() {
    # Initialize the log file if it doesn't exist
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
    fi

    # Use xargs for concurrent downloads with progress display
    download_files_concurrently_with_xargs
}

# Execute the main function
main
