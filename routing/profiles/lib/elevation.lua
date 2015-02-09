local math = math
local print = print
local string = string
local assert = assert
local table = table
local tonumber = tonumber

local luasql = require "luasql.postgres"
local sqlenv = assert( luasql.postgres() )
local sqlcon = assert( sqlenv:connect("dbname=provelo", "provelo", "provelo", "localhost") )

module "Elevation"


local function get_inclination_factor(inclination)
  local i = inclination

  if i < -0.15 then return 2.9479592079
  elseif i < -0.10 then return 2.5466721397
  elseif i < -0.05 then return 1.9485465016
  elseif i < -0.04 then return 1.8105115095
  elseif i < -0.03 then return 1.6645574312
  elseif i < -0.02 then return 1.5099581678
  elseif i < -0.01 then return 1.346454972
  elseif i < 0.00 then return 1.1751165029

  elseif i < 0.01 then return 1.0
  elseif i < 0.02 then return 0.830002976
  elseif i < 0.03 then return 0.678150767
  elseif i < 0.04 then return 0.553977798
  elseif i < 0.05 then return 0.458592821
  elseif i < 0.10 then return 0.388053339
  elseif i < 0.15 then return 0.211273485
  else return 0.142745166
  end
end


local function compute_inclination(h1, h2, length)
  if (length == 0) then
    return 0.0 -- no inclination
  else
    return (h2 - h1) / length
  end
end


local function compute_average_inclination_factors(segments)
  local forward = 0
  local backward = 0

  local count = table.getn(segments)
  for i = 1, count, 1 do
    local s = segments[i]
    local inclination = compute_inclination(s.p1_height, s.p2_height, s.length)
    local fwdFactor = get_inclination_factor(inclination)
    local bwdFactor = get_inclination_factor(0.0 - inclination)
--    print('Inclination ' .. inclination .. ' (' .. s.p2_height .. ' - ' .. s.p1_height .. ') / ' .. s.length .. ' [ -> ' .. fwdFactor .. ', <- ' .. bwdFactor .. ']')
    forward = forward + s.length * fwdFactor
    backward = backward + s.length * bwdFactor
  end

  if count > 0 then
    local totalLength = segments[1].total
--    print('fb' .. forward .. ' ' .. backward .. ' / ' .. totalLength)
    return { forward = forward / totalLength, backward = backward / totalLength }
  else
    return { forward = 1.0, backward = 1.0 }
  end
end

local simplifyRequest = true

local function query_database(way_id)
  -- Splits the way in segments and compute lengths and elevations.
  local sqlqueryLight = "with temp as "
    .. "(select "
      .. "ST_Length(way::geography, false) as total_length, "
      .. "ST_PointN(way, 1) as p1, "
      .. "ST_PointN(way, ST_NPoints(way)) as p2 "
      .. "from (select way from planet_osm_line as line where line.osm_id = " .. way_id .. " ) "
    .. "as g) "
    .. "select "
      .. "ST_Value(srtm1.rast, p1) as p1_height, "
      .. "ST_Value(srtm2.rast, p2) as p2_height, "
--      .. "ST_AsText(p1) as p1_str, ST_AsText(p2) as p2_str, "
      .. "total_length as length, "
      .. "total_length "
    .. "from temp, srtm as srtm1, srtm as srtm2 "
      .. "where ST_Intersects(srtm1.rast, p1) and ST_Intersects(srtm2.rast, p2) ;"
  local sqlqueryFull = "with temp as "
    .. "(select "
      .. "ST_Length(way::geography, false) as total_length, "
      .. "ST_PointN(way, generate_series(1, ST_NPoints(way)-1)) as p1, "
      .. "ST_PointN(way, generate_series(1, ST_NPoints(way)-1) + 1) as p2 "
      .. "from (select way from planet_osm_line as line where line.osm_id = " .. way_id .. " ) "
    .. "as g) "
    .. "select "
      .. "ST_Value(srtm1.rast, p1) as p1_height, "
      .. "ST_Value(srtm2.rast, p2) as p2_height, "
--      .. "ST_AsText(p1) as p1_str, ST_AsText(p2) as p2_str, "
      .. "ST_Distance(p1::geometry, p2::geometry, false) as length, "
      .. "total_length "
    .. "from temp, srtm as srtm1, srtm as srtm2 "
      .. "where ST_Intersects(srtm1.rast, p1) and ST_Intersects(srtm2.rast, p2) ;"
  local sqlquery = simplifyRequest and sqlqueryLight or sqlqueryFull
  
--  print(sqlquery)
  local cursor = assert( sqlcon:execute(sqlquery) )
  
  local segments = {}
  local count = cursor:numrows();
--  print ("Way " .. way_id .. " has " .. count .. " segments")
  local row = cursor:fetch( {}, "a")
  while row do
    -- Handle corner cases where some height is missing
    local h1 = row.p1_height
    local h2 = row.p2_height
    if not h1 and h2 then h1 = h2 end
    if not h2 and h1 then h2 = h1 end
    if not (h1 and h2) then
      h1 = 0
      h2 = 0
    end

--    print(string.format("-> (%s - %s) %s / %s", h1, h2, row.length, row.total_length))
    table.insert(segments, {
      p1_height = tonumber(h1),
      p2_height = tonumber(h2),
      length = tonumber(row.length),
      total = tonumber(row.total_length)
    })
    row = cursor:fetch( {}, "a")
  end

  return segments
end

function compute_speed(way)
  -- Compute the speed on the whole way
  -- A better algorithm would consider each segment and compute an average
  -- speed weighted by the segment lengths

  local segments = query_database(way.id)
  local factors = compute_average_inclination_factors(segments)
--  print(string.format("%f, %f", factors.forward, factors.backward))
  way.forward_speed = way.forward_speed * factors.forward
  way.backward_speed = way.backward_speed * factors.backward
end
