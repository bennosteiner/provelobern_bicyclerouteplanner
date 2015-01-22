#!/bin/sh

NOW=`date '+%Y_%m_%d_%Hh'`
OSMFILE='switzerland-padded.osm'

mkdir -p $NOW

cd $NOW
echo "Moving to `pwd` directory"

# Download osm data
if [ ! -e $OSMFILE.pbf ]
then
  echo "Downloading hourly updated data for Switzerland and neighbouring cities to $OSMFILE.pbf"
  wget http://planet.osm.ch/$OSMFILE.pbf
else
  echo "Skipped download of osm data to existing $OSMFILE.pbf"
fi


\cp -Rf ../profiles .

for profile in $PROFILES
do
  mkdir -p $profile
  cd $profile

  cat ../profiles/$profile.lua > $profile.lua
  ln -fs ../profiles/lib
  ln -fs ../$OSMFILE $profile.osm
done
