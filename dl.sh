#!/bin/bash

# Global variables
INPUT_FILE="./gimme/gimme.list"
SYNC_SCRIPT="./gimme/sync.sh"
LOG_FILE="./gimme/gimme.log"
TEMP_FILE="./gimme/gimme.tmp"
OUTDIR="./gimme/downloads"  # Output directory for downloads
MAX_CONCURRENT_DOWNLOADS=5  # Maximum number of concurrent downloads
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

# Function to download a file using wget and then remove it from the list
download_file() {
    local url="$1"

    # Ensure the output directory exists
    mkdir -p "$OUTDIR"

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

# Function to download files concurrently
download_files_concurrently() {
    local url
    local -a pids=()
    local num_downloads=0

    # Check if the input file exists
    if [[ ! -f "$INPUT_FILE" ]]; then
        printf "Error: File '%s' does not exist.\n" "$INPUT_FILE" >&2
        return 1
    fi

    # Create a temporary file to hold remaining URLs
    cp "$INPUT_FILE" "$TEMP_FILE"

    # Read the temporary file line by line
    while IFS= read -r url; do
        # Check if the line starts with 'http'
        if [[ "$url" =~ ^http ]]; then
            # Start the download in the background
            download_file "$url" &
            pids+=($!)

            # Increment the download counter
            ((num_downloads++))

            # If the number of concurrent downloads reaches the limit, wait for at least one to complete
            if (( num_downloads >= MAX_CONCURRENT_DOWNLOADS )); then
                wait -n  # Wait for at least one background job to finish
                num_downloads=$((num_downloads - 1))  # Decrease counter after one completes
            fi
        fi
    done < "$TEMP_FILE"

    # Wait for any remaining background downloads to complete
    wait

    # Cleanup temporary file
    rm -f "$TEMP_FILE"
}

# Main function to encapsulate the script logic
main() {
    # Initialize the log file if it doesn't exist
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
    fi

    # Download the files concurrently after synchronization
    download_files_concurrently
}

# Execute the main function
main
