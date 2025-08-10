#!/bin/bash
# Script: footnote_startup.sh
# Purpose: Change to project directory, checkout git branch, and run lime test

cd /home/footnote/src/FootNote || exit 1

# Run git checkout (just checkout current branch—if you want a specific branch, replace 'git checkout' with 'git checkout branchname')
git checkout

# Run lime test for linux
lime test linux
