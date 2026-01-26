#!/usr/bin/env bash
# Hardware Detection Script for EndOS Installer
# Detects CPU, GPU, and determines driver requirements

# Output in JSON format for easy parsing in QML

# Detect CPU
CPU=$(lscpu | grep "Model name" | sed 's/Model name: *//' | xargs)

# Detect GPU
GPU=$(lspci | grep -E "VGA|3D|Display" | sed 's/.*: //' | head -1)

# Check if NVIDIA drivers are needed
NEEDS_NVIDIA=false
if lspci | grep -E "VGA|3D" | grep -iq "NVIDIA"; then
    NEEDS_NVIDIA=true
fi

# Check if AMD drivers are needed
NEEDS_AMD=false
if lspci | grep -E "VGA|3D" | grep -iq "AMD|ATI"; then
    NEEDS_AMD=true
fi

# Output JSON
cat << EOF
{
    "cpu": "$CPU",
    "gpu": "$GPU",
    "needsNvidiaDriver": $NEEDS_NVIDIA,
    "needsAMDDriver": $NEEDS_AMD
}
EOF
