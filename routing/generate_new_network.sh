#!/bin/sh

# Eventually update the profiles directory then launch script.
# All profile networks will be generated.
# If all went well, the data in /var/sig/osrm will be overwritten.
# Then the osrm-routed daemons must be restarted.


PROFILES='fast quiet ebike'
#PROFILES='upstream'
OSMFILE=`ls *.osm.pbf |head -n 1 | sed 's/.pbf//'`
NO_OSM_CLEAN=""
if [ "X" = "X$OSMFILE" ]
then
  OSMFILE=`ls *.osm`
  NO_OSM_CLEAN="1"
fi

CHECK_DIR=`pwd | sed 's/.*\///' | head -c 2`
if [ "X$CHECK_DIR" != "X20" ]
then
  echo "Must be called from a 20XXX directory"
  exit 1
fi

if [ $# -ge 1 ]
then
  PROFILES="$*"
fi

set -o errexit

cleanup() {
  echo 'Cleaning up'
  rm -f /tmp/stxxl
}
trap "cleanup" INT TERM EXIT


# Uncompress since osrm runs out of memory when using the pbf file directly
if [ ! -e $OSMFILE ]
then
	echo "Uncompressing $OSMFILE.pbf to $OSMFILE"
	osmosis --read-pbf file="$OSMFILE.pbf" --write-xml file="$OSMFILE"
else
	echo "Skipping uncompression to $OSMFILE"
fi


for profile in $PROFILES
do
  cd profiles
  rm -f $profile.osm
  ln -s ../$OSMFILE $profile.osm

	# Extract with profile
	echo "Extracting data with profile $profile"
	STXXLCFG=../../.stxxl osrm-extract $profile.osm -p $profile.lua

	# Prepare
	echo "Preparing network $profile"
	STXXLCFG=../../.stxxl osrm-prepare $profile.osrm -p $profile.lua

	rm -f $profile.osm
	rm -f $profile.osrm
	cd ..
done

echo "Cleaning $OSMFILE and /tmp/stxxl"
[ -z "$NO_OSM_CLEAN" ] && rm -f $OSMFILE
rm -f /tmp/stxxl

echo "Updating production networks in /var/sig/osrm/"
for profile in $PROFILES
do
  mkdir -p /var/sig/osrm/$profile
  \rm -rf /var/sig/osrm/$profile/*
	\cp -Rf profiles/$profile.osrm* profiles/$profile.lua /var/sig/osrm/$profile/
done

echo "Restarting daemons for each profile"
for profile in $PROFILES
do
	sudo /etc/init.d/osrm-$profile restart
done


echo "Generation and restart of $PROFILES succeeded"
