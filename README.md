# VeraCrypt AppImage Builder

This script automates the process of creating an AppImage for VeraCrypt, allowing for easy distribution and use of VeraCrypt across various Linux distributions.

## Features

- Automatically downloads the latest VeraCrypt release (or a specified version)
- Verifies the downloaded package using SHA512
- Creates an AppImage that can run on most Linux distributions
- Allows specifying custom output directory
- Option to hide download progress for quieter operation

## Prerequisites

- Bash shell
- wget or curl (for downloading files)
- shasum or sha512
- Internet connection

## Usage

1. Make the script executable:
   ```
   chmod +x veracrypt-appimage-builder.sh
   ```
2. Run the script:
   ```
   ./veracrypt-appimage-builder.sh [OPTIONS]
   ```

### Options

- `-h, --help`: Show help message and exit
- `-v, --version VERSION`: Specify the VeraCrypt version to use
- `-d, --directory DIR`: Specify the output directory for the AppImage (default: current directory)
- `--no-progress`: Hide download progress

## Examples

1. Create an AppImage with the latest VeraCrypt version:
   ```
   ./veracrypt-appimage-builder.sh
   ```
2. Create an AppImage for a specific VeraCrypt version:
   ```
   ./veracrypt-appimage-builder.sh -v 1.25.9
   ```
