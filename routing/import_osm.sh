#!/bin/sh
AS_POSTGRES="sudo -u postgres"
OSMFILE="switzerland-padded.osm.pbf"
DB="provelo"

CHECK_DIR=`pwd | sed 's/.*\///' | head -c 2`
if [ "X$CHECK_DIR" != "X20" ]
then
  echo "Must be called from a 20XXX directory"
  exit 1
fi

$AS_POSTGRES osm2pgsql --slim --drop --latlong -r pbf -S ../osm_import_style -d $DB -c $OSMFILE

$AS_POSTGRES psql -d $DB -c "GRANT SELECT ON planet_osm_line TO provelo;"
$AS_POSTGRES psql -d $DB -c "CREATE INDEX planet_osm_line_way_id_index ON planet_osm_line (osm_id);"

# Tests
echo "Retrieve the altitude of a given OSM node"
$AS_POSTGRES psql -d $DB -c "select ST_X(way), ST_Y(way) from srtm, planet_osm_point where planet_osm_point.osm_id = 669855777 and ST_Intersects(rast, way)  limit 3;"

echo "Retrieve a set of altitude:"
$AS_POSTGRES psql -d $DB -c "select osm_id, ST_X(way), ST_Y(way) from srtm, planet_osm_point where planet_osm_point.osm_id in ('669855777', '2869805536', '2142407666') and ST_Intersects(rast, way);"
