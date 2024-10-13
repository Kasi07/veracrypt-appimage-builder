#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Create a VeraCrypt AppImage.

Options:
  -h, --help              Show this help message and exit
  -v, --version VERSION   Specify the VeraCrypt version to use
  -d, --directory DIR     Specify the output directory for the AppImage (default: current directory)
  --no-progress           Hide download progress
  -t, --type TYPE         Specify the VeraCrypt type (gui, gtk2-gui, console) (default: gui)

If no version is specified, the latest version from GitHub will be used.
EOF
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to download files
download_file() {
    local url="$1"
    local output="$2"
    if [ "$DOWNLOAD_TOOL" = "wget" ]; then
        if [ "$show_progress" = true ]; then
            wget --show-progress -q "$url" -O "$output" || { echo "Error: Failed to download $url"; exit 1; }
        else
            wget -q "$url" -O "$output" || { echo "Error: Failed to download $url"; exit 1; }
        fi
    else
        if [ "$show_progress" = true ]; then
            curl -L "$url" -o "$output" --progress-bar || { echo "Error: Failed to download $url"; exit 1; }
        else
            curl -sL "$url" -o "$output" || { echo "Error: Failed to download $url"; exit 1; }
        fi
    fi
}

# Function to get the latest VeraCrypt version
get_latest_version() {
    local latest_version
    if [ "$DOWNLOAD_TOOL" = "wget" ]; then
        latest_version=$(wget -qO- "https://api.github.com/repos/veracrypt/VeraCrypt/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")') || { echo "Error: Failed to fetch latest version"; exit 1; }
    else
        latest_version=$(curl -s "https://api.github.com/repos/veracrypt/VeraCrypt/releases/latest" | grep -oP '"tag_name": "\K(.*)(?=")') || { echo "Error: Failed to fetch latest version"; exit 1; }
    fi
    echo "${latest_version#VeraCrypt_}"
}

# Initialize variables
show_progress=true
veracrypt_type="gui"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            version="$2"
            shift 2
            ;;
        -d|--directory)
            output_dir="$2"
            shift 2
            ;;
        --no-progress)
            show_progress=false
            shift
            ;;
        -t|--type)
            veracrypt_type="$2"
            shift 2
            ;;
        *)
            echo "An invalid option \"$1\" was specified; use -h or --help for usage instructions"
            show_help
            exit 1
            ;;
    esac
done

# Validate veracrypt_type
if [[ ! "$veracrypt_type" =~ ^(gui|gtk2-gui|console)$ ]]; then
    echo "Error: Invalid VeraCrypt type. Use 'gui', 'gtk2-gui', or 'console'."
    exit 1
fi

# Set default output directory if not specified
output_dir="${output_dir:-$(pwd)}"

# Check if output directory exists and is writable
if [ ! -d "$output_dir" ] || [ ! -w "$output_dir" ]; then
    echo "Error: Output directory does not exist or is not writable: $output_dir"
    exit 1
fi

# Determine which download tool to use
if command_exists wget; then
    DOWNLOAD_TOOL="wget"
elif command_exists curl; then
    DOWNLOAD_TOOL="curl"
else
    echo "Error: wget or curl is required for downloading files. Please ensure one is installed before running."
    exit 1
fi

# Get the latest version if not specified
if [ -z "$version" ]; then
    version=$(get_latest_version)
    echo "Detected VeraCrypt version: $version (latest version available)"
else
    echo "Using specified VeraCrypt version: $version"
fi

# Create working directory in /tmp
work_dir=$(mktemp -d) || { echo "Error: Failed to create temporary directory"; exit 1; }
cd "$work_dir"

# Download VeraCrypt release
url="https://github.com/veracrypt/VeraCrypt/releases/download/VeraCrypt_${version}/veracrypt-${version}-setup.tar.bz2"
echo "Initiating download of VeraCrypt version $version..."
download_file "$url" "veracrypt-${version}-setup.tar.bz2"

# Download SHA512 checksums
checksum_url="https://launchpad.net/veracrypt/trunk/${version}/+download/veracrypt-${version}-sha512sum.txt"
download_file "$checksum_url" "veracrypt-${version}-sha512sum.txt"

# Extract the correct checksum for the setup file
expected_checksum=$(grep "veracrypt-${version}-setup.tar.bz2" "veracrypt-${version}-sha512sum.txt" | awk '{print $1}') || { echo "Error: Failed to extract checksum from veracrypt-${version}-sha512sum.txt"; exit 1; }

# Calculate the actual checksum of the downloaded file
if command_exists sha512sum; then
    actual_checksum=$(sha512sum "veracrypt-${version}-setup.tar.bz2" | awk '{print $1}')
elif command_exists shasum; then
    actual_checksum=$(shasum -a 512 "veracrypt-${version}-setup.tar.bz2" | awk '{print $1}')
else
    echo "Error: Neither sha512sum nor shasum is available. Cannot verify file integrity."
    exit 1
fi

# Verify the checksum
if [ "$expected_checksum" = "$actual_checksum" ]; then
    echo "Checksum verification successful."
else
    echo "Error: Checksum verification failed. The downloaded file may be corrupted or tampered with."
    exit 1
fi

# Extract the setup.tar to veracrypt_archive
echo "Extracting VeraCrypt files..."
mkdir veracrypt_archive || { echo "Error: Failed to create veracrypt_archive directory"; exit 1; }
tar -xjf "veracrypt-${version}-setup.tar.bz2" -C veracrypt_archive || { echo "Error: Failed to extract VeraCrypt archive"; exit 1; }

# Change to veracrypt_archive directory
cd veracrypt_archive

# Make the setup script executable
chmod +x "veracrypt-${version}-setup-${veracrypt_type}-x64" || { echo "Error: Failed to make setup script executable"; exit 1; }

# Extract veracrypt tar from self extracting script with --noexec option
./veracrypt-${version}-setup-${veracrypt_type}-x64 --noexec --target . || { echo "Error: Failed to extract VeraCrypt tar"; exit 1; }
PACKAGE_START=$(head -n 100 veracrypt_install_${veracrypt_type}_x64.sh | grep -n '^PACKAGE_START=' | cut -d'=' -f2) || { echo "Error: Failed to find PACKAGE_START"; exit 1; }
tail -n +$PACKAGE_START veracrypt_install_${veracrypt_type}_x64.sh > veracrypt_${version}_${veracrypt_type}_amd64.tar.gz || { echo "Error: Failed to extract VeraCrypt package"; exit 1; }

# Return to work directory
cd ..

# Create veracrypt.AppDir and extract VeraCrypt files into it
echo "Creating AppImage structure..."
mkdir veracrypt.AppDir || { echo "Error: Failed to create veracrypt.AppDir"; exit 1; }
tar -xzf "veracrypt_archive/veracrypt_${version}_${veracrypt_type}_amd64.tar.gz" -C veracrypt.AppDir || { echo "Error: Failed to extract VeraCrypt files to AppDir"; exit 1; }

# Change to veracrypt.AppDir
cd veracrypt.AppDir

# Copy or download Icon
if [ -f ./usr/share/pixmaps/veracrypt.xpm ]; then
    cp ./usr/share/pixmaps/veracrypt.xpm .
else
    download_file "https://raw.githubusercontent.com/veracrypt/VeraCrypt/master/src/Resources/Icons/VeraCrypt-256x256.xpm" "veracrypt.xpm"
fi

# Create desktop file
cat > veracrypt.desktop <<EOF || { echo "Error: Failed to create desktop file"; exit 1; }
[Desktop Entry]
Version=1.0
Name=VeraCrypt
GenericName=VeraCrypt
Exec=veracrypt
Icon=veracrypt
Terminal=false
Type=Application
Categories=Utility;
EOF

# Download AppRun
echo "Fetching AppRun for the AppImage..."
download_file "https://github.com/AppImage/AppImageKit/releases/latest/download/AppRun-x86_64" "AppRun"
chmod a+x AppRun || { echo "Error: Failed to make AppRun executable"; exit 1; }

# Return to work directory
cd ..

# Download appimagetool
echo "Retrieving appimagetool to create the final AppImage..."
download_file "https://github.com/AppImage/AppImageKit/releases/latest/download/appimagetool-x86_64.AppImage" "appimagetool-x86_64.AppImage"
chmod a+x appimagetool-x86_64.AppImage || { echo "Error: Failed to make appimagetool executable"; exit 1; }

# Create AppImage
echo "Generating AppImage..."
./appimagetool-x86_64.AppImage veracrypt.AppDir ./Veracrypt-${version}-${veracrypt_type}-x86_64.AppImage || { echo "Error: Failed to create AppImage"; exit 1; }

# Move AppImage to output directory
mv Veracrypt-${version}-${veracrypt_type}-x86_64.AppImage "$output_dir/" || { echo "Error: Failed to move AppImage to output directory"; exit 1; }

# Clean up
cd /
rm -rf "$work_dir" || { echo "Error: Failed to remove temporary directory"; exit 1; }

echo "Successfully created VeraCrypt AppImage (${veracrypt_type}) and saved to $output_dir"
