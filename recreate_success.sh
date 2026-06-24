#!/bin/bash
# Recreate Success Installer for sensors.gorilla

set -e

INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

echo "Copying sensors.gorilla to $INSTALL_DIR/sensors.gorilla..."
cp sensors.gorilla "$INSTALL_DIR/sensors.gorilla"
chmod +x "$INSTALL_DIR/sensors.gorilla"

echo "=================================================="
echo "sensors.gorilla successfully installed!"
echo "=================================================="
echo "Usage: sensors.gorilla      (snapshot view)"
echo "       sensors.gorilla -w   (live watch)"
echo ""
echo "Note: For SSD health & lifespan metrics, please"
echo "ensure smartmontools is installed on your system:"
echo "  sudo apt install smartmontools"
echo "=================================================="
