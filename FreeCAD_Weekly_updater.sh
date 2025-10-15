#!/bin/bash
# FreeCAD Weekly AppImage Updater for Arch Linux + XFCE
# This script downloads the latest FreeCAD weekly AppImage and integrates it into the system

set -e

# Configuration
INSTALL_DIR="$HOME/.local/share/applications/AppImages"
DESKTOP_FILE="$HOME/.local/share/applications/freecad-weekly.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
RELEASES_URL="https://github.com/FreeCAD/FreeCAD/releases"

echo "=== FreeCAD Weekly AppImage Updater ==="
echo

# Create directories if they don't exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$ICON_DIR"
mkdir -p "$(dirname "$DESKTOP_FILE")"

# Fetch the releases page
echo "Fetching latest release information..."
RELEASES_HTML=$(curl -sL "$RELEASES_URL")

# Find the first weekly release tag
LATEST_TAG=$(echo "$RELEASES_HTML" | grep -oP 'href="/FreeCAD/FreeCAD/releases/tag/weekly-[0-9]{4}\.[0-9]{2}\.[0-9]{2}"' | head -1 | grep -oP 'weekly-[0-9]{4}\.[0-9]{2}\.[0-9]{2}')

if [ -z "$LATEST_TAG" ]; then
    echo "Error: Could not find latest weekly release tag"
    exit 1
fi

echo "Latest weekly release: $LATEST_TAG"

# Find the actual AppImage filename by checking what files exist in the release
echo "Checking for available x86_64 AppImage..."
RELEASE_API_URL="https://api.github.com/repos/FreeCAD/FreeCAD/releases/tags/${LATEST_TAG}"
RELEASE_JSON=$(curl -sL "$RELEASE_API_URL")

# Extract the x86_64 AppImage filename (with any py version)
APPIMAGE_NAME=$(echo "$RELEASE_JSON" | grep -oP '"name":\s*"FreeCAD_'"${LATEST_TAG}"'-Linux-x86_64-py[^"]*\.AppImage"' | grep -oP 'FreeCAD_[^"]*\.AppImage' | head -1)

if [ -z "$APPIMAGE_NAME" ]; then
    echo "Error: Could not find x86_64 AppImage for release $LATEST_TAG"
    exit 1
fi

APPIMAGE_PATH="$INSTALL_DIR/$APPIMAGE_NAME"
DOWNLOAD_URL="https://github.com/FreeCAD/FreeCAD/releases/download/${LATEST_TAG}/${APPIMAGE_NAME}"

echo "Found AppImage: $APPIMAGE_NAME"
echo

# Check for currently installed version by looking for any FreeCAD weekly AppImage
INSTALLED_FILE=$(find "$INSTALL_DIR" -maxdepth 1 -name "FreeCAD_weekly-*-Linux-x86_64*.AppImage" -type f | head -1)

if [ -n "$INSTALLED_FILE" ]; then
    INSTALLED_NAME=$(basename "$INSTALLED_FILE")
    INSTALLED_VERSION=$(echo "$INSTALLED_NAME" | grep -oP 'weekly-[0-9]{4}\.[0-9]{2}\.[0-9]{2}')
    echo "Currently installed version: $INSTALLED_VERSION"
    echo "Installed file: $INSTALLED_FILE"
else
    echo "Currently installed version: Not installed"
fi
echo

# Check if we already have this exact file - EXIT BEFORE DOWNLOADING
if [ -f "$APPIMAGE_PATH" ]; then
    echo "✓ Already have the latest version installed!"
    echo "  File: $APPIMAGE_PATH"
    echo "  No action needed."
    exit 0
fi

# If we get here, we need to download
if [ -n "$INSTALLED_FILE" ]; then
    echo "Update needed: $INSTALLED_VERSION → $LATEST_TAG"
    echo "Will remove old file: $INSTALLED_FILE"
else
    echo "Installing FreeCAD Weekly for the first time"
fi
echo

echo "Download URL: $DOWNLOAD_URL"
echo "Install path: $APPIMAGE_PATH"
echo

# Download the AppImage
echo "Downloading FreeCAD AppImage..."
if ! curl -L -o "$APPIMAGE_PATH.tmp" "$DOWNLOAD_URL"; then
    echo "Error: Download failed"
    rm -f "$APPIMAGE_PATH.tmp"
    exit 1
fi

# Remove old version if it exists
if [ -n "$INSTALLED_FILE" ] && [ "$INSTALLED_FILE" != "$APPIMAGE_PATH" ]; then
    echo "Removing old version: $INSTALLED_FILE"
    rm -f "$INSTALLED_FILE"
fi

# Move to final location
mv "$APPIMAGE_PATH.tmp" "$APPIMAGE_PATH"

# Make executable
chmod +x "$APPIMAGE_PATH"

echo "AppImage downloaded successfully"
echo "Installed to: $APPIMAGE_PATH"
echo

# Create a symlink with a simple name for easy access and desktop entry
SYMLINK_PATH="$INSTALL_DIR/FreeCAD-weekly.AppImage"
if [ -L "$SYMLINK_PATH" ] || [ -f "$SYMLINK_PATH" ]; then
    rm -f "$SYMLINK_PATH"
fi
ln -s "$APPIMAGE_PATH" "$SYMLINK_PATH"
echo "Created symlink: $SYMLINK_PATH -> $APPIMAGE_NAME"
echo

# Extract icon and desktop file from AppImage
echo "Extracting icon and desktop file..."
cd /tmp
rm -rf squashfs-root

"$SYMLINK_PATH" --appimage-extract "org.freecad.FreeCAD.svg" 2>/dev/null || true
"$SYMLINK_PATH" --appimage-extract "org.freecad.FreeCAD.desktop" 2>/dev/null || true

# Copy icon
if [ -f "squashfs-root/org.freecad.FreeCAD.svg" ]; then
    cp "squashfs-root/org.freecad.FreeCAD.svg" "$ICON_DIR/freecad-weekly.svg"
    echo "Icon extracted successfully"
    ICON_PATH="freecad-weekly"
else
    echo "Warning: Could not extract icon, using default"
    ICON_PATH="application-x-executable"
fi

# Use the extracted desktop file as a base if available
if [ -f "squashfs-root/org.freecad.FreeCAD.desktop" ]; then
    echo "Using extracted desktop file as base"
    cp "squashfs-root/org.freecad.FreeCAD.desktop" "$DESKTOP_FILE"
    # Update the Exec line to use our symlink
    sed -i "s|^Exec=.*|Exec=$SYMLINK_PATH %f|" "$DESKTOP_FILE"
    # Update the Name to indicate it's the weekly build
    sed -i "s|^Name=.*|Name=FreeCAD Weekly|" "$DESKTOP_FILE"
    # Update the Icon
    sed -i "s|^Icon=.*|Icon=$ICON_PATH|" "$DESKTOP_FILE"
    # Add version info
    if ! grep -q "X-AppImage-Version" "$DESKTOP_FILE"; then
        echo "X-AppImage-Version=$LATEST_TAG" >> "$DESKTOP_FILE"
    else
        sed -i "s|^X-AppImage-Version=.*|X-AppImage-Version=$LATEST_TAG|" "$DESKTOP_FILE"
    fi
else
    echo "Creating desktop entry from scratch..."
    # Create .desktop file
    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=FreeCAD Weekly
GenericName=CAD Application
Comment=Feature-rich Open Source 3D parametric modeler (Weekly Build)
Exec=$SYMLINK_PATH %f
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Graphics;Science;Engineering;
MimeType=application/x-extension-fcstd;
StartupNotify=true
StartupWMClass=FreeCAD
Keywords=CAD;3D;Parametric;Engineering;
X-AppImage-Version=$LATEST_TAG
EOF
fi

# Cleanup extracted files
rm -rf squashfs-root

# Update desktop database
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# Update icon cache
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

echo
echo "=== Installation Complete ==="
echo "FreeCAD Weekly ($LATEST_TAG) has been installed"
echo "Location: $APPIMAGE_PATH"
echo "Desktop entry: $DESKTOP_FILE"
echo
echo "You should now see 'FreeCAD Weekly' in your applications menu."
echo "If it doesn't appear immediately, try logging out and back in."
echo
echo "To update to the latest version, simply run this script again."
