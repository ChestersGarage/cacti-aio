#!/bin/bash

# HDDTemp run script for Cacti
# Usage: hddtemp.sh [F|C] [single disk device]
# Example: hddtemp.sh F /dev/sdb


hddtemp -qdFu $1 $2