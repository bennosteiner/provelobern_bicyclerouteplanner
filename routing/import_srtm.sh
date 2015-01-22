#!/bin/sh
AS_POSTGRES="sudo -u postgres"
DB="provelo"

mkdir -p srtm
cd srtm

if [ ! -e srtm_38_03.zip ]
then
	echo "Downloading Switzerland SRTM data"
	wget -c ftp://srtm.csi.cgiar.org/SRTM_V41/SRTM_Data_GeoTiff/srtm_38_03.zip
	wget -c ftp://srtm.csi.cgiar.org/SRTM_V41/SRTM_Data_GeoTiff/srtm_39_03.zip
fi

echo "Extracting SRTM data"
unzip -o srtm_38_03.zip
unzip -o srtm_39_03.zip

echo "Creating virtual dem with a custom bounding box (could be trimmed down further)"
gdalbuildvrt  -te 5.18162 45.2794 11.2781 48.3485 swiss_srtm.vrt srtm_38_03.tif srtm_39_03.tif

echo "Creating SQL data"
raster2pgsql -s EPSG:4326 -I -M -d -t auto swiss_srtm.vrt srtm > srtm.sql

echo "Creating and importing database"
$AS_POSTGRES createdb $DB
$AS_POSTGRES psql -d $DB -c "CREATE EXTENSION postgis;"
$AS_POSTGRES psql -d $DB -f srtm.sql 


echo "Tests should print 48MB and 472m"
TEST1="SELECT pg_size_pretty(pg_total_relation_size('srtm'));"
TEST2="select ST_Value(rast, ST_SetSRID(ST_MakePoint(6,46),4326)) from srtm where ST_Intersects(rast, ST_SetSRID(ST_MakePoint(6,46),4326));"
$AS_POSTGRES psql -d $DB -c "$TEST1"
$AS_POSTGRES psql -d $DB -c "$TEST2"

