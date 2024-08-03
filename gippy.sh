#!/bin/bash

# Script name and description
script_name="gippy.sh" # Filename of the script
display_name="Gippy" # Display name of the script
script_description="The GPG Zip Tool"
script_version="1.0.1"
github_account="disappointingsupernova"
repo_name="gippy"
github_repo="https://raw.githubusercontent.com/$github_account/$repo_name/main/$script_name"

# Default PGP certificate fingerprint
pgp_certificate="7D2D35B359A3BB1AE7A2034C0CB5BB0EFE677CA8"

# Function to display usage
function usage() {
    echo "Usage: $0 -e email_address -a application -z zipname -b backuplocation [-p pgp_certificate] [-c commands] [-o output] [--update]"
    echo "Try '$0 -h' for more information."
    exit 1
}

# Function to display help
function help() {
    echo "$display_name - $script_description"
    echo
    echo "Usage: $0 -e email_address -a application -z zipname -b backuplocation [-p pgp_certificate] [-c commands] [-o output] [--update]"
    echo
    echo "Options:"
    echo "  -e    Email address to send the backup"
    echo "  -a    Application name"
    echo "  -z    Name for the zip file (will be stored in a temporary location)"
    echo "  -b    Backup location (directory to back up)"
    echo "  -p    PGP certificate fingerprint (optional, default: $pgp_certificate)"
    echo "  -c    Commands to include in the email body (comma-separated)"
    echo "  -o    Output location to save the encrypted zip file (if specified, email is not sent)"
    echo "  --update  Update the script to the latest version from GitHub"
    echo "  -h    Display this help and exit"
    echo
    echo "Description:"
    echo "This script creates a zip archive of a specified directory, encrypts it using GPG,"
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

# Function to check if a command is installed, and install it if not
function ensure_command() {
    local cmd="$1"
    local deb_pkg="$2"
    local rpm_pkg="$3"
    if ! command -v $cmd &> /dev/null; then
        echo "Installing $cmd"
        if command -v apt-get &> /dev/null; then
            sudo apt-get install $deb_pkg -y
        elif command -v yum &> /dev/null; then
            sudo yum install $rpm_pkg -y
        else
            echo "Unsupported package manager. Please install $cmd manually."
            exit 1
        fi
    fi
}

# Function to update the script
function update_script() {
    local script_path="$(realpath "$0")"
    curl -s -o "$script_path" $github_repo
    chmod +x "$script_path"
    echo "$display_name has been updated to the latest version. Please restart the script."
    exit 0
}

# Function to check for script updates
function check_for_updates() {
    local latest_version=$(curl -s https://raw.githubusercontent.com/$github_account/$repo_name/main/VERSION)
    if [ "$script_version" != "$latest_version" ]; then
        echo "A new version of $display_name is available (version $latest_version)."
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

# Check for non-interactive update flag
if [[ " $@ " =~ " --update " ]]; then
    update_script
fi

# Check for script updates
check_for_updates

# Parse command line arguments and ensure they are all provided
while getopts "e:a:z:b:p:c:o:h" opt; do
    case ${opt} in
        e) email_address=${OPTARG} ;;
        a) application=${OPTARG} ;;
        z) zipname=${OPTARG} ;;
        b) backuplocation=${OPTARG} ;;
        p) pgp_certificate=${OPTARG} ;;
        c) commands=${OPTARG} ;;
        o) output=${OPTARG} ;;
        h) help ;;
        *) usage ;;
    esac
done

# Check if all required arguments are provided
if [ -z "$email_address" ] && [ -z "$output" ]; then
    usage
fi
if [ -z "$application" ] || [ -z "$zipname" ] || [ -z "$backuplocation" ]; then
    usage
fi

# Create a random folder in /tmp
random_folder=$(mktemp -d -t ${display_name}_XXXXXXXXXX)
zipname="$random_folder/$zipname"
encryptedziplocation="$zipname.gpg"

function check_for_stored_pgp_key() {
    if ! gpg --list-keys "$pgp_certificate" &> /dev/null; then
        error="Missing PGP Key"
        process_error
    else
        create_email_content
    fi
}

function create_email_content() {
    zip -r "$zipname" "$backuplocation"
    gpg --sign --encrypt -r "$pgp_certificate" "$zipname"
    
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
    } > "$random_folder/pgp_message.txt"
    
    gpg --sign --encrypt -a -r "$pgp_certificate" "$random_folder/pgp_message.txt"
    
    if [ -n "$output" ]; then
        mv "$encryptedziplocation" "$output"
        cleanup_no_email
    else
        send_email
    fi
}

function process_error() {
    echo -e "$error\n$application - $(hostname)" | mail -s "Error $application - $(hostname) - $(date)" "$email_address" --append="FROM:error@$(hostname)"
}

function send_email() {
    mail -s "$application - $(hostname)" "$email_address" --attach="$encryptedziplocation" --append="FROM:gpg@$(hostname)" < "$random_folder/pgp_message.txt.asc"
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
