#!/bin/bash

# HDDTemp run script for Docker cli
# Usage: hddtemp.sh [F|C] [disk device match pattern]
# Example: hddtemp.sh F /dev/sd[b|c|d|e|f]

if [[ $1 == "F" ]] || [[ $1 == "C" ]]
then
	hddtemp -qdF -u $1 $2
else
	hddtemp -qdF $1
fi
