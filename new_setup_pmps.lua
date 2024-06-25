-- TODO: I guess I will use this library to read new types from JSON files in the root folder...
--       export the object functions, they will come in handy. Also add a way to read and validate presets from a file and parse them from valid JSONs
--       import JSON files from a dedicated folder, each individual JSON representing a preset...
-- * REPLACE CD REFERENCES WITH SCRIPT LOCATION REFERENCES! *
-- TODO: this is not system-agnostic...

local module = {}

local system_utilities = require("new_system_utilities")

local dkjson = require("lib\\dkjson\\dkjson")

-- TODO: push this and the export thing to system utilities, and fix all references to them
function module.import_types()
	-- Reads all the type JSON files from the designated types directory
	local types = {}
	if not system_utilities.is_valid_path(".\\types") then
		print("error: invalid JSON types directory")
		return
	end

	local type_list = system_utilities.get_json_files_in_dir(".\\types")
	for k, v in pairs(type_list) do
		-- print(v)
		local type_path = ".\\types\\"..v..".json"
		local type_file = io.open(type_path)
		local content = type_file:read("*a")
		type_file:close()
		local object = dkjson.decode(content)
		types[v] = object
		-- table.insert(types, object)
	end

	return types
end

function module.export_standard_types()
	local standard_types = module.get_standard_types()
	for _, type in pairs(standard_types) do
		local json = module.encode_type(type)
		local file_name = type.name
		local file_path = "./types/"..file_name..".json"
		local file = io.open(file_path, "w")
		if (file) then
			file:write(json)
			file:close()
		end
	end
end

function module.decode_type(type_json_string)
	-- Takes a string for argument, just a string straight from a JSON file
	-- TODO: finish this
	local type = dkjson.decode(type_json_string)
	-- TODO: here, check that the JSON matches a Type definition, and check that each PoweredMassPoint table matches a PoweredMassPoint definition
	return type
end

function module.encode_type(type)
	-- "type" is the object table to be encoded in a string in JSON notation
	-- * indent adds line breaks and indentations so the output JSON is human-readable and not a bunch of gibberish
	-- * keyorder is self-explanatory. This order is partially based on the tag-structure, though some keys are arbitrarily defined to account for additional variables from this Lua code
	local json = dkjson.encode(type, {
        indent = true,
        keyorder = {
			-- Type
            "name",
            "properties",
            "pmps",
			-- Powered Mass Point (arbitrary)
            "flags",
			-- Properties
            "radius",
            "moment_scale",
            "mass",
            "density",
            "gravity_scale",
            "ground_friction",
            "ground_depth",
            "ground_damp_fraction",
            "ground_normal_k1",
            "ground_normal_k0",
            "water_friction",
            "water_depth",
            "water_density",
            "air_friction",
			-- Powered Mass Point
            "water_lift",
            "air_lift",
            "thrust",
            "antigrav",
            "antigrav_strength",
            "antigrav_offset",
            "antigrav_height",
            "antigrav_damp_fraction",
            "antigrav_normal_k1",
            "antigrav_normal_k0"
        }
    })
	return json
end

function module.get_standard_types()
	return {
		-- TODO: make all of these part of the "module" table, and update their references, and remove their "exporter" functions
		HumanTankType(),
		HumanJeepType(),
		HumanBoatType(),
		HumanPlaneType(),
		AlienScoutType(),
		AlienFighterType(),
		TurretType()
	}
end

function module.Type()
	return Type()
end

function module.Properties()
	return Properties()
end

function module.PoweredMassPoint()
	return PoweredMassPoint()
end

function Type()
	local type = {}
	type.name = ""
	type.properties = Properties()
	type.pmps = {}
	return type
end

function Properties()
	local properties = {}
	properties.radius = 0
	properties.moment_scale = 0
	properties.mass = 0
	-- * center_of_mass is geometry dependent
	properties.density = 0
	properties.gravity_scale = 0
	properties.ground_friction = 0
	properties.ground_depth = 0
	properties.ground_damp_fraction = 0
	properties.ground_normal_k1 = 0
	properties.ground_normal_k0 = 0
	properties.water_friction = 0
	properties.water_depth = 0
	properties.water_density = 0
	properties.air_friction = 0
	-- * xx_moment is geometry dependent
	-- * yy_moment is geometry dependent
	-- * zz_moment is geometry dependent
	return properties
end

function PoweredMassPoint()
	local pmp = {}
	pmp.name = ""
	pmp.flags = {}
	pmp.flags.ground_friction = 0
	pmp.flags.water_friction = 0
	pmp.flags.air_friction = 0
	pmp.flags.water_lift = 0
	pmp.flags.air_lift = 0
	pmp.flags.thrust = 0
	pmp.flags.antigrav = 0
	pmp.antigrav_strength = 0
	pmp.antigrav_offset = 0
	pmp.antigrav_height = 0
	pmp.antigrav_damp_fraction = 0
	pmp.antigrav_normal_k1 = 0
	pmp.antigrav_normal_k0 = 0
	return pmp
end

-- SCORPION
function HumanTankType()
	local human_tank = Type()
	human_tank.name = "human tank"
	human_tank.properties.radius = -1
	human_tank.properties.moment_scale = 1
	human_tank.properties.mass = 20000
	human_tank.properties.density = 8
	human_tank.properties.gravity_scale = 1
	human_tank.properties.ground_friction = 0.2
	human_tank.properties.ground_depth = 0.25
	human_tank.properties.ground_damp_fraction = 0.05
	human_tank.properties.ground_normal_k1 = 0.707107
	human_tank.properties.ground_normal_k0 = 0.5
	human_tank.properties.water_friction = 0.05
	human_tank.properties.water_depth = 0.25
	human_tank.properties.water_density = 1
	human_tank.properties.air_friction = 0.001
	human_tank.pmps[0] = PoweredMassPoint()
	human_tank.pmps[1] = PoweredMassPoint()
	local front = human_tank.pmps[0]
	local back = human_tank.pmps[1]
	front.name = "left"
	front.flags.ground_friction = 1
	back.name = "right"
	back.flags.ground_friction = 1
	return human_tank
end

-- WARTHOG / ROCKET WARTHOG
function HumanJeepType()
	local human_jeep = Type()
	human_jeep.name = "human jeep"
	human_jeep.properties.radius = -1
	human_jeep.properties.moment_scale = 1
	human_jeep.properties.mass = 5000
	human_jeep.properties.density = 5
	human_jeep.properties.gravity_scale = 1
	human_jeep.properties.ground_friction = 0.23
	human_jeep.properties.ground_depth = 0.15
	human_jeep.properties.ground_damp_fraction = 0.05
	human_jeep.properties.ground_normal_k1 = 0.707107
	human_jeep.properties.ground_normal_k0 = 0.5
	human_jeep.properties.water_friction = 0.05
	human_jeep.properties.water_depth = 0.25
	human_jeep.properties.water_density = 1
	human_jeep.properties.air_friction = 0.005
	human_jeep.pmps[0] = PoweredMassPoint()
	human_jeep.pmps[1] = PoweredMassPoint()
	local front = human_jeep.pmps[0]
	local back = human_jeep.pmps[1]
	front.name = "front"
	front.flags.ground_friction = 1
	back.name = "back"
	back.flags.ground_friction = 1
	return human_jeep
end

-- I still don't know the behavior difference between these PMPs, I just know they are set up like this, otherwise -THEY JUST DON'T WORK- at all
-- Maybe controls are inverted in the 'back' hydrofoil, like the 'back' wheels of the warthog are
-- DOOZY
function HumanBoatType()
	local human_boat = Type()
	human_boat.name = "human boat"
	human_boat.properties.radius = -1
	human_boat.properties.moment_scale = 1
	human_boat.properties.mass = 2500
	human_boat.properties.density = 0.5
	human_boat.properties.gravity_scale = 1
	human_boat.properties.ground_friction = 0.2
	human_boat.properties.ground_depth = 0.2
	human_boat.properties.ground_damp_fraction = 0.05
	human_boat.properties.ground_normal_k1 = 0.707107
	human_boat.properties.ground_normal_k0 = 0.5
	human_boat.properties.water_friction = 0.05
	human_boat.properties.water_depth = 0.2
	human_boat.properties.water_density = 1
	human_boat.properties.air_friction = 0.001
	human_boat.pmps[0] = PoweredMassPoint() 
	human_boat.pmps[1] = PoweredMassPoint()
	human_boat.pmps[2] = PoweredMassPoint()
	local hydrofoil_plus_propellor = human_boat.pmps[0]
	local hydrofoil_front = human_boat.pmps[1]
	local hydrofoil_back = human_boat.pmps[2]
	hydrofoil_plus_propellor.name = "hydrofoil + propellor"
	hydrofoil_plus_propellor.flags.water_friction = 1
	hydrofoil_plus_propellor.flags.water_lift = 1
	hydrofoil_front.name = "hydrofoil (front)"
	hydrofoil_front.flags.water_lift = 1
	hydrofoil_back.name = "hydrofoil (back)"
	hydrofoil_back.flags.water_lift = 1
	return human_boat
end

-- Human plane maneuverability is controlled through friction types and parallel/perpendicular scales in MPs, PMPs are ignored by this vehicle type
-- PELICAN / COVENANT DROPSHIP (BOTH USE THE SAME VALUES AND MASS POINTS; NONE)
function HumanPlaneType()
	local human_plane = Type()
	human_plane.name = "human plane"
	human_plane.properties.radius = 4
	human_plane.properties.moment_scale = 0.3
	human_plane.properties.mass = 10000
	human_plane.properties.density = 4
	human_plane.properties.gravity_scale = 1
	human_plane.properties.ground_friction = 0.2
	human_plane.properties.ground_depth = 0.2
	human_plane.properties.ground_damp_fraction = 0.05
	human_plane.properties.ground_normal_k1 = 0.707107
	human_plane.properties.ground_normal_k0 = 0.5
	human_plane.properties.water_friction = 0.05
	human_plane.properties.water_depth = 0.25
	human_plane.properties.water_density = 1
	human_plane.properties.air_friction = 0.02
	return human_plane
end

-- TODO: This type... I don't know what I will do with it; it can have up to the 32 PMP limit count, but I haven't experimented that much with what each PMP after index 7 does
-- Maybe just limit this type to 2 PMPs, just in case the developer wants to create a front/back 'leaning' vehicle when in the air
-- * this matches the PMP pattern of all vanilla hovering vehicles: two PMPs, one for frontal "strong" antigravity, and one for the sides or the back "weak" antigravity
-- * unlike ground and water vehicles' PMPs, these PMPs operate exactly the same regardless of their index/position in the tag
-- * this allows having multiple antigravity intensities: one for each PMP
-- There are 3 possible "hover" vehicles: ghost, wraith and banshee. Each one has unique values, though they do not differ much. This template is based off the ghost
-- ... And... I still don't know what "antigrav offset" does. Tried tweaking it on the ghost, using values from -5000 to 5000 and no difference
-- GHOST
function AlienScoutType()
	local alien_scout = Type()
	alien_scout.name = "alien scout"
	alien_scout.properties.radius = -1
	alien_scout.properties.moment_scale = 1
	alien_scout.properties.mass = 2000
	alien_scout.properties.density = 3
	alien_scout.properties.gravity_scale = 1
	alien_scout.properties.ground_friction = 0.2
	alien_scout.properties.ground_depth = 0.15
	alien_scout.properties.ground_damp_fraction = 0.05
	alien_scout.properties.ground_normal_k1 = 0.707107
	alien_scout.properties.ground_normal_k0 = 0.5
	alien_scout.properties.water_friction = 0.05
	alien_scout.properties.water_depth = 0.25
	alien_scout.properties.water_density = 1
	alien_scout.properties.air_friction = 0.0025
	alien_scout.pmps[0] = PoweredMassPoint()
	alien_scout.pmps[1] = PoweredMassPoint()
	local primary_antigravity = alien_scout.pmps[0]
	local secondary_antigravity = alien_scout.pmps[1]
	primary_antigravity.name = "primary antigravity"
	secondary_antigravity.name = "secondary antigravity"
	primary_antigravity.flags.antigrav = 1
	primary_antigravity.antigrav_strength = 1.5
	primary_antigravity.antigrav_height = 0.75
	primary_antigravity.antigrav_damp_fraction = 0.02
	primary_antigravity.antigrav_normal_k0 = 0.5
	primary_antigravity.antigrav_normal_k1 = 0.258819
	secondary_antigravity.flags.antigrav = 1
	secondary_antigravity.antigrav_strength = 1.5
	secondary_antigravity.antigrav_height = 0.75
	secondary_antigravity.antigrav_damp_fraction = 0.02
	secondary_antigravity.antigrav_normal_k0 = 0.5
	secondary_antigravity.antigrav_normal_k1 = 0.258819
	return alien_scout
end

-- TODO: This type... Maybe create a command line argument for primary and secondary antigravity PMPs, exclusive for 'alien scout' and 'alien fighter' types (check if antigravity affects 'human plane' types, because it doesn't affect land vehicle types)
--       Too much hassle, I will literally copy the PMP values and definitions, and let the user customize those values as necessary in the physics tag
--       Reduce the number of "antigravity PMPs" to two, and have command line options to customize their strength and other parameters, I guess... Both in the ghost, banshee, and wraith
-- In this type, there must be only 2 PMPs: they only affect antigravity
-- BANSHEE
function AlienFighterType()
	local alien_fighter = Type()
	alien_fighter.name = "alien fighter"
	alien_fighter.properties.radius = -1
	alien_fighter.properties.moment_scale = 1
	alien_fighter.properties.mass = 4000
	alien_fighter.properties.density = 4
	alien_fighter.properties.gravity_scale = 1
	alien_fighter.properties.ground_friction = 0.2
	alien_fighter.properties.ground_depth = 0.15
	alien_fighter.properties.ground_damp_fraction = 0.05
	alien_fighter.properties.ground_normal_k1 = 0.707107
	alien_fighter.properties.ground_normal_k0 = 0.5
	alien_fighter.properties.water_friction = 0.05
	alien_fighter.properties.water_depth = 0.25
	alien_fighter.properties.water_density = 1
	alien_fighter.properties.air_friction = 0.005
	alien_fighter.pmps[0] = PoweredMassPoint()
	alien_fighter.pmps[1] = PoweredMassPoint()
	local primary_antigravity = alien_fighter.pmps[0]
	local secondary_antigravity = alien_fighter.pmps[1]
	primary_antigravity.name = "primary antigravity"
	secondary_antigravity.name = "secondary antigravity"
	primary_antigravity.flags.antigrav = 1
	primary_antigravity.antigrav_strength = 1
	primary_antigravity.antigrav_height = 0.75
	primary_antigravity.antigrav_damp_fraction = 0.01
	primary_antigravity.antigrav_normal_k0 = 0.1
	primary_antigravity.antigrav_normal_k1 = 0
	secondary_antigravity.flags.antigrav = 1
	secondary_antigravity.antigrav_strength = 1
	secondary_antigravity.antigrav_height = 0.25
	secondary_antigravity.antigrav_damp_fraction = 0.01
	secondary_antigravity.antigrav_normal_k0 = 0.1
	secondary_antigravity.antigrav_normal_k1 = 0
	return alien_fighter
end

-- TODO: I may create a "sharp alien hover" vehicle now that I confirmed how antigrav damp fraction, and antigrav normal k1 and k0 work: the same as ground variables do
-- * normal k1 (static friction) is cos(x) where x = max angle of slope (at which the vehicle cannot start moving)
-- * normal k0 (dynamic friction)is cos(x) where x = max angle of slope (at which the vehicle cannot keep moving, even when having speed inertia, once static friction has been broken)
-- * hence, if k1 > k0, the vehicle cannot move at all, because it cannot break static friction first [is it? k0 angles are greater than k1's]

-- This vehicle is kind of a mystery. I haven't tested it, but I suppose it is hard-coded to be impossible to drive. Unless... (it is assigned proper animations, and given a proper physics tag, maybe?)
-- But for the time being, I'm just pasting it here for compatibility purposes: to make a "fixed" turret, just abstain from assigning a physics tag to it in the vehicle tag
-- (SINGLE-PLAYER DEFAULT COVENANT GUN) TURRET
function TurretType()
	local turret = Type()
	turret.name = "turret"
	turret.properties.radius = -1
	turret.properties.moment_scale = 1
	turret.properties.mass = 2000
	turret.properties.density = 6
	turret.properties.gravity_scale = 1
	turret.properties.ground_friction = 0.2
	turret.properties.ground_depth = 0.15
	turret.properties.ground_damp_fraction = 0.05
	turret.properties.ground_normal_k1 = 0.707107
	turret.properties.ground_normal_k0 = 0.5
	turret.properties.water_friction = 0.05
	turret.properties.water_depth = 0.25
	turret.properties.water_density = 1
	turret.properties.air_friction = 0.001
	turret.pmps[0] = PoweredMassPoint()
	turret.pmps[1] = PoweredMassPoint()
	local front = turret.pmps[0]
	local back = turret.pmps[1]
	front.name = "front"
	front.flags.ground_friction = 1
	back.name = "back"
	back.flags.ground_friction = 1
	return turret
end

--[[
human tank
human jeep
human boat
human plane
alien scout
alien fighter
turret
--]]

return module