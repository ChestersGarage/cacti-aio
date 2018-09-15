#!/bin/bash

# HDDTemp run script for Docker cli
# Usage: hddtemp.sh [F|C] [disk device match pattern]
# Example: hddtemp.sh F /dev/sd[b|c|d|e|f]


hddtemp -qdFu $1 $2