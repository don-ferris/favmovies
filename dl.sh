#!/bin/bash

# Global variables
INPUT_FILE="./gimme/gimme.list"
SYNC_SCRIPT="./gimme/sync.sh"
LOG_FILE="./gimme/gimme.log"
TEMP_FILE="./gimme/gimme.tmp"
OUTDIR="./_new"  # Output directory for downloads
MAX_CONCURRENT_DOWNLOADS=4  # Maximum number of concurrent downloads
SYNC_PAUSE=30  # Pause duration in seconds before each download

# Function to run the sync script before each download
run_sync_script() {
    if [[ ! -x "$SYNC_SCRIPT" ]]; then
        printf "Error: Sync script '%s' does not exist or is not executable.\n" "$SYNC_SCRIPT" >&2
        return 1
    fi

    # Execute the sync script
    if ! "$SYNC_SCRIPT"; then
        printf "Error: Failed to execute the sync script.\n" >&2
        return 1
    fi
}

# Function to log errors to gimme.log, prepending them to the top
log_error() {
    local message="$1"

    # Prepend the message to the log file
    if ! printf "%s\n" "$message" | cat - "$LOG_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$LOG_FILE"; then
        printf "Error: Failed to write to log file '%s'.\n" "$LOG_FILE" >&2
    fi
}

# Function to download a file using wget to the specified OUTDIR and then remove it from the list
download_file() {
    local url="$1"

    # Run the sync script before downloading
    if ! run_sync_script; then
        log_error "Error: Failed to run sync script before downloading URL: $url"
        return
    fi

    # Pause before starting the download
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

# Function to download files concurrently with visible output using xargs
download_files_concurrently_with_xargs() {
    # Check if the input file exists
    if [[ ! -f "$INPUT_FILE" ]]; then
        printf "Error: File '%s' does not exist.\n" "$INPUT_FILE" >&2
        return 1
    fi

    # Check if the output directory exists, if not create it
    mkdir -p "$OUTDIR"

    # Filter URLs starting with 'http' and pass them to xargs for concurrent downloading
    grep -E '^http' "$INPUT_FILE" | xargs -n 1 -P "$MAX_CONCURRENT_DOWNLOADS" -I {} bash -c 'download_file "$@"' _ {}
}

# Main function to encapsulate the script logic
main() {
    # Initialize the log file if it doesn't exist
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
    fi

    # Export functions and variables to be used by xargs
    export -f run_sync_script log_error download_file
    export INPUT_FILE LOG_FILE TEMP_FILE SYNC_PAUSE SYNC_SCRIPT OUTDIR

    # Download the files concurrently using xargs with visible progress output
    download_files_concurrently_with_xargs
}

# Execute the main function
main
