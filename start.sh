#!/bin/bash
# Script: footnote_startup.sh
# Purpose: Change to project directory, checkout git branch, and run lime test

cd /home/footnote/src/FootNote || exit 1

# Run git pull to ensure we have the latest changes
git pull

# Run lime test for linux
lime test linux
