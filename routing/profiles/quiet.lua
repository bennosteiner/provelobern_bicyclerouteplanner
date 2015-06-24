require("lib/access")
require("lib/maxspeed")
require("lib/elevation")

-- Begin of globals
barrier_whitelist = { [""] = true, ["cycle_barrier"] = true, ["bollard"] = true, ["entrance"] = true, ["cattle_grid"] = true, ["border_control"] = true, ["toll_booth"] = true, ["sally_port"] = true, ["gate"] = true, ["no"] = true }
access_tag_whitelist = { ["yes"] = true, ["permissive"] = true, ["designated"] = true }
access_tag_blacklist = { ["no"] = true, ["private"] = true, ["agricultural"] = true, ["forestery"] = true }
access_tag_restricted = { ["destination"] = true, ["delivery"] = true }
access_tags_hierachy = { "bicycle", "vehicle", "access" }
cycleway_tags = {["track"]=true,["lane"]=true,["opposite"]=true,["opposite_lane"]=true,["opposite_track"]=true,["share_busway"]=true,["sharrow"]=true,["shared"]=true }
service_tag_restricted = { ["parking_aisle"] = true }
restriction_exception_tags = { "bicycle", "vehicle", "access" }

default_speed = 16

walking_speed = 6

velocity_gains = {
  ["primary"] = 1,
  ["secondary"] = 1,
  ["tertiary"] = 1
}

-- Define the get_inclination_factor in the Elevation module
Elevation.get_inclination_factor = function (inclination)
  local i = inclination

  if i < -0.07 then return 1.6
  elseif i < -0.06 then return 1.55
  elseif i < -0.05 then return 1.5
  elseif i < -0.04 then return 1.45
  elseif i < -0.03 then return 1.4
  elseif i < -0.02 then return 1.3
  elseif i < -0.01 then return 1.2
  elseif i < 0.00 then return 1.1

  elseif i < 0.01 then return 0.85
  elseif i < 0.02 then return 0.7
  elseif i < 0.03 then return 0.6
  elseif i < 0.04 then return 0.5
  elseif i < 0.05 then return 0.45
  elseif i < 0.06 then return 0.4
  elseif i < 0.07 then return 0.35
  else return 0.3
  end
end

bicycle_speeds = {
  ["cycleway"] = 18,
  ["primary"] = 12,
  ["primary_link"] = 12,
  ["secondary"] = 12,
  ["secondary_link"] = 12,
  ["tertiary"] = 16,
  ["tertiary_link"] = 16,
  ["residential"] = 18,
  ["unclassified"] = 18,
  ["living_street"] = 18,
  ["road"] = 18,
  ["service"] = 18,
  ["track"] = 16,
  ["path"] = 16
}

pedestrian_speeds = {
  ["footway"] = 5,
  ["pedestrian"] = 5,
  ["steps"] = 1
}

railway_speeds = {
  ["train"] = 0,
  ["railway"] = 0,
  ["subway"] = 0,
  ["light_rail"] = 0,
  ["monorail"] = 0,
  ["tram"] = 0
}

platform_speeds = {
  ["platform"] = walking_speed
}

amenity_speeds = {
  ["parking"] = 10,
  ["parking_entrance"] = 10
}

man_made_speeds = {
  ["pier"] = walking_speed
}

route_speeds = {
  ["ferry"] = 5,
  ["shuttle_train"] = 5
}

surface_penalties = { 
    ["gravel"] = 0.8,
    ["ground"] = 0.8,
    ["unpaved"] = 0.9,
    ["grass"] = 0.5,
    ["dirt"] = 0.5,
    ["cobblestone"] = 0.5, 
    ["pebblestone"] = 0.9, 
    ["compacted"] = 0.9, 
    ["wood"] = 0.95,
    ["grit"] = 0.6,
    ["sand"] = 0.4
}

take_minimum_of_speeds  = true
obey_oneway       = true
obey_bollards       = false
use_restrictions    = true
ignore_areas      = true    -- future feature
traffic_signal_penalty  = 5
u_turn_penalty      = 20
use_turn_restrictions   = false
turn_penalty      = 45
turn_bias         = 1.0


--modes
mode_normal = 1
mode_pushing = 2
mode_ferry = 3
mode_train = 4


local function parse_maxspeed(source)
    if not source then
        return 0
    end
    local n = tonumber(source:match("%d*"))
    if not n then
        n = 0
    end
    if string.match(source, "mph") or string.match(source, "mp/h") then
        n = (n*1609)/1000;
    end
    return n
end


function get_exceptions(vector)
  for i,v in ipairs(restriction_exception_tags) do
    vector:Add(v)
  end
end

function node_function (node)
  local barrier = node.tags:Find ("barrier")
  local access = Access.find_access_tag(node, access_tags_hierachy)
  local traffic_signal = node.tags:Find("highway")

	-- flag node if it carries a traffic light
	if traffic_signal == "traffic_signals" then
		node.traffic_light = true
	end

	-- parse access and barrier tags
	if access and access ~= "" then
		if access_tag_blacklist[access] then
			node.bollard = true
		else
			node.bollard = false
		end
	elseif barrier and barrier ~= "" then
		if barrier_whitelist[barrier] then
			node.bollard = false
		else
			node.bollard = true
		end
	end

	-- return 1
end

function way_function (way)
  -- initial routability check, filters out buildings, boundaries, etc
  local highway = way.tags:Find("highway")
  local route = way.tags:Find("route")
  local man_made = way.tags:Find("man_made")
  local railway = way.tags:Find("railway")
  local amenity = way.tags:Find("amenity")
  local public_transport = way.tags:Find("public_transport")
  if (not highway or highway == '') and
  (not route or route == '') and
  (not railway or railway=='') and
  (not amenity or amenity=='') and
  (not man_made or man_made=='') and
  (not public_transport or public_transport=='')
  then
    return
  end

  -- don't route on ways or railways that are still under construction
  if highway=='construction' or railway=='construction' then
    return
  end

  -- access
  local access = Access.find_access_tag(way, access_tags_hierachy)
  if access_tag_blacklist[access] then
    return
  end

  -- other tags
  local name = way.tags:Find("name")
  local ref = way.tags:Find("ref")
  local junction = way.tags:Find("junction")
  local maxspeed = parse_maxspeed(way.tags:Find ( "maxspeed") )
  local maxspeed_forward = parse_maxspeed(way.tags:Find( "maxspeed:forward"))
  local maxspeed_backward = parse_maxspeed(way.tags:Find( "maxspeed:backward"))
  local barrier = way.tags:Find("barrier")
  local oneway = way.tags:Find("oneway")
  local onewayClass = way.tags:Find("oneway:bicycle")
  local cycleway = way.tags:Find("cycleway")
  local cycleway_left = way.tags:Find("cycleway:left")
  local cycleway_right = way.tags:Find("cycleway:right")
  local duration = way.tags:Find("duration")
  local service = way.tags:Find("service")
  local area = way.tags:Find("area")
  local foot = way.tags:Find("foot")
  local surface = way.tags:Find("surface")
  local bicycle = way.tags:Find("bicycle")
  local bridge = way.tags:Find("bridge")

  -- name
  if "" ~= ref and "" ~= name then
    way.name = name .. ' / ' .. ref
  elseif "" ~= ref then
    way.name = ref
  elseif "" ~= name then
    way.name = name
  else
    -- if no name exists, use way type
    -- this encoding scheme is excepted to be a temporary solution
    way.name = "{highway:"..highway.."}"
  end

  -- roundabout handling
  if "roundabout" == junction then
    way.roundabout = true;
  end

  -- speed
  if route_speeds[route] then
    -- ferries (doesn't cover routes tagged using relations)
    way.forward_mode = mode_ferry
    way.backward_mode = mode_ferry
    way.ignore_in_grid = true
    if durationIsValid(duration) then
      way.duration = math.max( 1, parseDuration(duration) )
    else
       way.forward_speed = route_speeds[route]
       way.backward_speed = route_speeds[route]
    end
  elseif railway and platform_speeds[railway] then
    -- railway platforms (old tagging scheme)
    way.forward_speed = platform_speeds[railway]
    way.backward_speed = platform_speeds[railway]
  elseif platform_speeds[public_transport] then
    -- public_transport platforms (new tagging platform)
    way.forward_speed = platform_speeds[public_transport]
    way.backward_speed = platform_speeds[public_transport]
    elseif railway and railway_speeds[railway] then
      way.forward_mode = mode_train
      way.backward_mode = mode_train
     -- railways
    if access and access_tag_whitelist[access] then
      way.forward_speed = railway_speeds[railway]
      way.backward_speed = railway_speeds[railway]
    end
  elseif amenity and amenity_speeds[amenity] then
    -- parking areas
    way.forward_speed = amenity_speeds[amenity]
    way.backward_speed = amenity_speeds[amenity]
  elseif bicycle_speeds[highway] then
    -- regular ways
    way.forward_speed = bicycle_speeds[highway]
    way.backward_speed = bicycle_speeds[highway]
  elseif access and access_tag_whitelist[access] then
    -- unknown way, but valid access tag
    way.forward_speed = default_speed
    way.backward_speed = default_speed
  else
    -- biking not allowed, maybe we can push our bike?
    -- essentially requires pedestrian profiling, for example foot=no mean we can't push a bike
    if foot ~= 'no' and junction ~= "roundabout" then
      if pedestrian_speeds[highway] then
        -- pedestrian-only ways and areas
        way.forward_speed = pedestrian_speeds[highway]
        way.backward_speed = pedestrian_speeds[highway]
        way.forward_mode = mode_pushing
        way.backward_mode = mode_pushing
      elseif man_made and man_made_speeds[man_made] then
        -- man made structures
        way.forward_speed = man_made_speeds[man_made]
        way.backward_speed = man_made_speeds[man_made]
        way.forward_mode = mode_pushing
        way.backward_mode = mode_pushing
      elseif foot == 'yes' then
        way.forward_speed = walking_speed
        way.backward_speed = walking_speed
        way.forward_mode = mode_pushing
        way.backward_mode = mode_pushing
      elseif foot_forward == 'yes' then
        way.forward_speed = walking_speed
        way.forward_mode = mode_pushing
        way.backward_mode = 0
      elseif foot_backward == 'yes' then
        way.forward_speed = walking_speed
        way.forward_mode = 0
        way.backward_mode = mode_pushing
      end
    end
  end

  -- direction
  local impliedOneway = false
  if junction == "roundabout" or highway == "motorway_link" or highway == "motorway" then
    impliedOneway = true
  end

  if onewayClass == "yes" or onewayClass == "1" or onewayClass == "true" then
    way.backward_mode = 0
  elseif onewayClass == "no" or onewayClass == "0" or onewayClass == "false" then
    -- prevent implied oneway
  elseif onewayClass == "-1" then
    way.forward_mode = 0
  elseif oneway == "no" or oneway == "0" or oneway == "false" then
    -- prevent implied oneway
  elseif cycleway and string.find(cycleway, "opposite") == 1 then
    if impliedOneway then
      way.forward_mode = 0
      way.backward_mode = mode_normal
      way.backward_speed = bicycle_speeds["cycleway"]
    end
  elseif cycleway_left and cycleway_tags[cycleway_left] and cycleway_right and cycleway_tags[cycleway_right] then
    -- prevent implied
  elseif cycleway_left and cycleway_tags[cycleway_left] then
    if impliedOneway then
      way.forward_mode = 0
      way.backward_mode = mode_normal
      way.backward_speed = bicycle_speeds["cycleway"]
    end
  elseif cycleway_right and cycleway_tags[cycleway_right] then
    if impliedOneway then
      way.forward_mode = mode_normal
      way.backward_speed = bicycle_speeds["cycleway"]
      way.backward_mode = 0
    end
  elseif oneway == "-1" then
    way.forward_mode = 0
  elseif oneway == "yes" or oneway == "1" or oneway == "true" or impliedOneway then
    way.backward_mode = 0
  end
  
  -- pushing bikes
  if bicycle_speeds[highway] or pedestrian_speeds[highway] then
    if foot ~= "no" and junction ~= "roundabout" then
      if way.backward_mode == 0 then
        way.backward_speed = walking_speed
        way.backward_mode = 0
      elseif way.forward_mode == 0 then
        way.forward_speed = walking_speed
        way.forward_mode = 0
      end
    end
  end

  -- cycleways
  if cycleway and cycleway_tags[cycleway] then
    way.forward_speed = bicycle_speeds["cycleway"]
  elseif cycleway_left and cycleway_tags[cycleway_left] then
    way.forward_speed = bicycle_speeds["cycleway"]
  elseif cycleway_right and cycleway_tags[cycleway_right] then
    way.forward_speed = bicycle_speeds["cycleway"]
  end

  -- dismount
  if bicycle == "dismount" then
    way.forward_mode = mode_pushing
    way.backward_mode = mode_pushing
    way.forward_speed = walking_speed
    way.backward_speed = walking_speed
  end

  -- surfaces
  if surface then
    surface_speed = surface_penalties[surface]
    if surface_speed then
      	way.forward_speed = way.forward_speed * surface_speed
        way.backward_speed = way.backward_speed * surface_speed
    end
  end

  if (cycleway) then
    local velocity_gain = velocity_gains[highway]
    if (velocity_gain) then
      way.forward_speed = way.forward_speed + velocity_gain
      way.backward_speed = way.backward_speed + velocity_gain
    end
  end

  -- elevation
  -- limiting speed on each of the way segments would be more accurate
  -- print('ID ' ..way.id..' XX')
  if "" == bridge then -- bridge are skipped from the elevation rule
    Elevation.compute_speed( way, get_inclination_factor )
  end

  -- maxspeed
  MaxSpeed.limit( way, maxspeed, maxspeed_forward, maxspeed_backward )
end

function turn_function (angle)
  -- compute turn penalty as angle^2, with a left/right bias
  k = turn_penalty/(90.0*90.0)

  -- check if going strait (or nearly straigt) -> apply smallest turn penalty
  -- 0.1rad is about 5.7°

  if angle>=0 then
    if angle <= 0.1 then angle = 0.1 end
    return angle*angle*k/turn_bias
  else
    if angle >= -0.1 then angle = -0.1 end
    return angle*angle*k*turn_bias
  end
end
