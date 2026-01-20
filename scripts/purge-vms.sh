#!/bin/bash
set -e

echo "Deleting and purging all Multipass VMs..."
multipass delete --all --purge

echo "Cleanup complete."
