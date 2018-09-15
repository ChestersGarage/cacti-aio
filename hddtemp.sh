hddtemp -qdFu F /dev/sd[b|c|d|e|f|g|h|i|j]

# Run in the context of the container
hddtemp -qdF ${HDDTEMP_OPTIONS}

# Run in the context of user-based setup in Cacti
hddtemp -qdFu ${UNIT} ${DISK_LIST}
Need cacti to aggregate the list of disks into a single string