#!/usr/bin/env bash

# -e: Immediately exit if any command has a non-zero exit status.
# -x: Print all executed commands to the terminal.
# -u: Exit if an undefined variable is used.
# -o pipefail: Exit if any command in a pipeline fails.
set -exuo pipefail

FLEET_GITOPS_DIR="${FLEET_GITOPS_DIR:-./}"
FLEET_GLOBAL_FILE="${FLEET_GLOBAL_FILE:-$FLEET_GITOPS_DIR/default.yml}"
FLEETCTL="${FLEETCTL:-fleetctl}"

# Validate that global file contains org_settings
grep -Exq "^org_settings:.*" "$FLEET_GLOBAL_FILE"

# Real run
$FLEETCTL gitops -f "$FLEET_GLOBAL_FILE"
