# Gippy - The GPG Zip Tool

Gippy is a bash script that creates a zip archive of specified directories, encrypts it using GPG, and either emails it to a provided email address or saves it to a specified location.

## Description

Gippy automates the process of creating a secure, encrypted backup of directories and either emailing it or saving it to a specified location. The script uses zip to create the archive, gpg to encrypt it, and `sendmail` to send it. If command outputs are specified, they are included in the email body.

## Features

- Creates a zip archive of specified directories.
- Encrypts the zip archive using a PGP certificate.
- Emails the encrypted zip archive to a provided email address.
- Optionally includes the outputs of specified commands in the encrypted email body.
- Can save the encrypted zip archive to a specified location instead of emailing it.
- Ensures `zip`, `gpg`, `mailutils`, `sendmail`, and `curl` are installed before execution on both Debian-based and Redhat-based systems.
- Checks for updates from a GitHub repository and prompts the user to install updates.
- Supports non-interactive updating with the `--update` option.
- Allows skipping update checks with the `--no-update` option.
- Logs activity and checks for email success. Logs are included in the email body.

## Requirements

- `zip`
- `gpg`
- `mailutils` (for email functionality)
- `sendmail` (for email functionality)
- `curl` (for update checking)

## Usage

```bash
./gippy.sh -e email_address -a application -z zipname -b backuplocations [-p pgp_certificate] [-c commands] [-o output] [--update]
```

## Options

    -e : Email address to send the backup. Required unless -o is specified.
    -a : Application name. Required.
    -z : Name for the zip file (will be stored in a temporary location). Required.
    -b : Backup locations (comma-separated list of directories to back up). Required.
    -p : PGP certificate fingerprint (optional, default: 7D2D35B359A3BB1AE7A2034C0CB5BB0EFE677CA8).
    -c : Commands to include in the email body (comma-separated).
    -o : Output location to save the encrypted zip file (if specified, email is not sent).
    --update : Update the script to the latest version from GitHub.
    -h : Display help and exit.

## Examples

Email Backup with Default PGP Certificate:
``` bash
./gippy.sh -e user@example.com -a "My Application" -z backup.zip -b /etc/myapp
```

Email Multiple Backup Locations with Default PGP Certificate:
``` bash
./gippy.sh -e user@example.com -a "My Application" -z backup.zip -b /etc/myapp,/etc/iptables 
```

Email Backup with Custom PGP Certificate and Command Outputs:
``` bash
./gippy.sh -e user@example.com -a "My Application" -z backup.zip -b /etc/myapp -p 1234567890ABCDEF1234567890ABCDEF12345678 -c "/usr/sbin/iptables-save,/usr/bin/ip6tables-save"
```

Save Backup to File:
``` bash
./gippy.sh -a "My Application" -z backup.zip -b /etc/myapp -o /path/to/output/backup.zip.gpg
```


## Installation

Download the gippy.sh script and make it executable:

``` bash
chmod +x gippy.sh
```
## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Author

Developed by [DisappointingSupernova](https://github.com/disappointingsupernova). For support, contact github@disappointingsupernova.space.