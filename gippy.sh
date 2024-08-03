#!/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Script name and description
script_name="gippy.sh" # Filename of the script
display_name="Gippy" # Display name of the script
script_description="The GPG Zip Tool"
script_version="1.1.9"
github_account="disappointingsupernova"
repo_name="gippy"
github_repo="https://raw.githubusercontent.com/$github_account/$repo_name/main/$script_name"
log_file="/var/log/${display_name}.log"
log_messages=""
no_update=0 #Script should check for updates on startup

# Default PGP certificate fingerprint
pgp_certificate="7D2D35B359A3BB1AE7A2034C0CB5BB0EFE677CA8"

# Ensure gpg-agent is running
if ! pgrep -x "gpg-agent" > /dev/null; then
    eval $(gpg-agent --daemon)
fi

# Function to display usage
function usage() {
    echo "Usage: $0 -e email_address -a application -z zipname -b backuplocations [-p pgp_certificate] [-c commands] [-o output] [--update] [--no-update] [--version]"
    echo "Try '$0 -h' for more information."
    exit 1
}

# Function to display help
function help() {
    echo "$display_name - $script_description"
    echo
    echo "Usage: $0 -e email_address -a application -z zipname -b backuplocations [-p pgp_certificate] [-c commands] [-o output] [--update] [--no-update] [--version] [--help]"
    echo
    echo "Options:"
    echo "  -e    Email address to send the backup"
    echo "  -a    Application name"
    echo "  -z    Name for the zip file (will be stored in a temporary location)"
    echo "  -b    Backup locations (comma-separated list of directories to back up)"
    echo "  -p    PGP certificate fingerprint (optional, default: 7D2D35B359A3BB1AE7A2034C0CB5BB0EFE677CA8)"
    echo "  -c    Commands to include in the email body (comma-separated)"
    echo "  -o    Output location to save the encrypted zip file (if specified, email is not sent)"
    echo "  --update  Update the script to the latest version from GitHub"
    echo "  --no-update  Skip the update check"
    echo "  --version, -v  Display the script version and exit"
    echo "  --help, -h    Display this help and exit"
    echo
    echo "Description:"
    echo "This script creates a zip archive of specified directories, encrypts it using GPG,"
    echo "and emails it to the provided email address. The zip archive and temporary files"
    echo "are stored in a randomly generated temporary directory, which is cleaned up after"
    echo "the email is sent."
    echo
    echo "If the -c option is provided, the outputs of the specified commands will be included"
    echo "in the encrypted body of the email. Commands should be provided as a comma-separated"
    echo "list."
    echo
    echo "If the -o option is provided, the encrypted zip file will be moved to the specified"
    echo "output location instead of being emailed. All other temporary files will be removed."
    exit 0
}

# Function to display version
function version() {
    echo "$display_name version $script_version"
    exit 0
}

# Function to log messages
function log_message() {
    local message="$1"
    local timestamped_message="$(date +'%Y-%m-%d %H:%M:%S') - $message"
    echo "$timestamped_message"
    echo "$timestamped_message" >> "$log_file"
    log_messages+="$timestamped_message"$'\n'
}

# Function to find the full path of a command
function find_command() {
    local cmd="$1"
    local path
    path=$(which "$cmd")
    if [ -z "$path" ]; then
        log_message "Error: $cmd not found. Please ensure it is installed and available in your PATH."
        exit 1
    fi
    echo "$path"
}

# Paths to required commands
ZIP_CMD=$(find_command zip)
GPG_CMD=$(find_command gpg)
SENDMAIL_CMD=$(find_command sendmail)
CURL_CMD=$(find_command curl)

# Function to check if a command is installed, and install it if not
function ensure_command() {
    local cmd="$1"
    local deb_pkg="$2"
    local rpm_pkg="$3"
    if ! command -v $cmd &> /dev/null; then
        log_message "Installing $cmd"
        if command -v apt-get &> /dev/null; then
            sudo apt-get install $deb_pkg -y
        elif command -v yum &> /dev/null; then
            sudo yum install $rpm_pkg -y
        else
            log_message "Unsupported package manager. Please install $cmd manually."
            exit 1
        fi
    fi
}

# Function to update the script
function update_script() {
    local script_path="$(realpath "$0")"
    $CURL_CMD -s -o "$script_path" $github_repo
    chmod +x "$script_path"
    log_message "$display_name has been updated to the latest version. Please restart the script."
    exit 0
}

# Function to check for script updates
function check_for_updates() {
    local latest_version=$($CURL_CMD -s https://raw.githubusercontent.com/$github_account/$repo_name/main/VERSION)
    if [ "$script_version" != "$latest_version" ]; then
        log_message "A new version of $display_name is available (version $latest_version)."
        read -p "Do you want to update? (y/n): " choice
        if [ "$choice" = "y" ]; then
            update_script
        fi
    fi
}

# Ensure required commands are installed
ensure_command zip zip zip
ensure_command gpg gnupg gnupg2
ensure_command mail mailutils mailx
ensure_command curl curl curl

# Parse command line arguments and ensure they are all provided
while getopts "e:a:z:b:p:c:o:hv-:" opt; do
    case ${opt} in
        e) email_address=${OPTARG} ;;
        a) application=${OPTARG} ;;
        z) zipname=${OPTARG} ;;
        b) backuplocations=${OPTARG} ;;
        p) pgp_certificate=${OPTARG} ;;
        c) commands=${OPTARG} ;;
        o) output=${OPTARG} ;;
        h) help ;;
        v) version ;;
        -)
            case "${OPTARG}" in
                update) update_script ;;
                no-update) no_update=1 ;;
                version) version ;;
                help) help ;;
                *) usage ;;
            esac
            ;;
        *) usage ;;
    esac
done

# Check for script updates if not skipped
if [ "$no_update" -ne 1 ]; then
    check_for_updates
fi

# Check if all required arguments are provided
if [ -z "$email_address" ] && [ -z "$output" ]; then
    usage
fi
if [ -z "$application" ] || [ -z "$zipname" ] || [ -z "$backuplocations" ]; then
    usage
fi

# Create a random folder in /tmp
random_folder=$(mktemp -d -t ${display_name}_XXXXXXXXXX)
zipname="$random_folder/$zipname"
encryptedziplocation="$zipname.gpg"

function check_for_stored_pgp_key() {
    if ! $GPG_CMD --list-keys "$pgp_certificate" &> /dev/null; then
        error="Missing PGP Key"
        process_error
    else
        create_email_content
    fi
}

function create_email_content() {
    IFS=',' read -ra backup_array <<< "$backuplocations"
    $ZIP_CMD -r "$zipname" "${backup_array[@]}"
    
    $GPG_CMD --sign --encrypt -r "$pgp_certificate" "$zipname"
    
    {
        echo "$application - $(hostname) - $(date)"
        if [ -n "$commands" ]; then
            echo
            echo "Command Outputs:"
            IFS=',' read -ra cmd_array <<< "$commands"
            for cmd in "${cmd_array[@]}"; do
                echo "Output of $cmd:"
                $cmd
                echo
            done
        fi
        echo
        echo "Log messages:"
        echo "$log_messages"
    } > "$random_folder/pgp_message.txt"
    
    $GPG_CMD --sign --encrypt -a -r "$pgp_certificate" "$random_folder/pgp_message.txt"
    
    if [ -n "$output" ]; then
        mv "$encryptedziplocation" "$output"
        cleanup_no_email
    else
        send_email
    fi
}

function process_error() {
    log_message "Error: $error"
    {
        echo "From: error@$(hostname)"
        echo "To: $email_address"
        echo "Subject: Error $application - $(hostname) - $(date) - $display_name"
        echo
        echo "$error"
        echo "$application - $(hostname)"
        echo
        echo "Log messages:"
        echo "$log_messages"
    } | $SENDMAIL_CMD -t
}

function send_email() {
    temp_err_file=$(mktemp)
    {
        echo "From: gpg@$(hostname)"
        echo "To: $email_address"
        echo "Subject: $application - $(hostname) - $display_name"
        echo "MIME-Version: 1.0"
        echo "Content-Type: multipart/mixed; boundary=\"GIPPY-BOUNDARY\""
        echo
        echo "--GIPPY-BOUNDARY"
        echo "Content-Type: text/plain"
        echo
        cat "$random_folder/pgp_message.txt.asc"
        echo
        echo "--GIPPY-BOUNDARY"
        echo "Content-Type: application/octet-stream; name=\"$(basename "$encryptedziplocation")\""
        echo "Content-Transfer-Encoding: base64"
        echo "Content-Disposition: attachment; filename=\"$(basename "$encryptedziplocation")\""
        echo
        base64 "$encryptedziplocation"
        echo
        echo "--GIPPY-BOUNDARY--"
    } | $SENDMAIL_CMD -t 2> "$temp_err_file"

    if [ $? -eq 0 ]; then
        log_message "Email sent successfully to $email_address"
    else
        error=$(cat "$temp_err_file")
        log_message "$error"
        error="Failed to send email to $email_address. Possible reason: attachment too large."
        process_error
    fi
    rm "$temp_err_file"
    cleanup
}

function cleanup() {
    rm -r "$random_folder"
}

function cleanup_no_email() {
    rm "$random_folder/pgp_message.txt" "$random_folder/pgp_message.txt.asc" "$zipname"
    rmdir "$random_folder"
}

function begin() {
    check_for_stored_pgp_key
}

begin