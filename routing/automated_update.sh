#!/bin/sh

echo "Start automated OSM update and OSRM network generation"

cd /var/www/vhosts/provelobern-geomapfish/private/provelobern_bicyclerouteplanner/routing

# folder cleanup
python cleanup.py

if [ $? -ne 0 ]; then
    echo "error on folder cleanup"
    exit 1
fi

# Remove all temporary switzerland-padded.osm files except last one
find 2* -name switzerland-padded.osm | sort | head -n -1 | xargs rm

# osm update
./download_osm_and_prepare.sh

if [ $? -ne 0 ]; then
    echo "error on osm update"
    exit 1
fi

# go to latest dir, filtering on folder starting with 2
FOLDER=$(ls -d 2*/ | tail -1)
echo "going into $FOLDER folder"
cd $FOLDER

# import osm
../import_osm.sh

if [ $? -ne 0 ]; then
    echo "error on import osm"
    exit 1
fi

# generate new network
../generate_new_network.sh

if [ $? -ne 0 ]; then
    echo "error on generate new network"
    exit 1
fi
