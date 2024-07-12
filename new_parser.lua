-- Parser module

-- Generates tag-structured mass points from JMS mass points

local module = {}

-- TODO: replace the imported module path and name when I rename it
local calculator = require("./new_calculator")
local system_utilities = require("./new_system_utilities")
local dkjson = require("./lib/dkjson/dkjson")

function module.get_mass_point_table(jms_mass_point_relative_mass_table, jms_mass_point_table, jms_node_table, total_mass, engine_list, powered_mass_point_list)
    local mass_point_table = {}
    -- TODO: make certain parameters optional: mass, density... That can be retrieved from a presets list
    local mass_point
    local mass_point_transformation_matrix
    local parsed_data
    local parsed_mass_point
    for jms_mass_point_index, jms_mass_point in pairs(jms_mass_point_table) do
        mass_point = module.MassPoint()
        mass_point_transformation_matrix = calculator.get_jms_mass_point_transformation_matrix(jms_mass_point_index, jms_mass_point_table, jms_node_table)
        mass_point_table[jms_mass_point_index] = mass_point
        -- Mass point names cannot be longer than 32 characters, so square bracket data must be removed from names, otherwise Invader won't run
        mass_point.name = module.purge_name(jms_mass_point.name)
        -- powered_mass_point (this is included in the JMS but always -1, so not valid, must be parsed from the name, unless... )
        -- TODO: maybe this powered_mass_point exporting feature could be restored, or introduced in the JMS exporter program, not here
        mass_point.model_node = jms_mass_point.parent_node
        -- flags: metallic (parsed from name)
        -- TODO: relative mass/mass (taken from calculator, and possibly, optional to be parsed from name) (note: no, forbid mass overrides, these would mess with other calculations)
        mass_point.relative_mass = jms_mass_point_relative_mass_table[jms_mass_point_index]
        mass_point.mass = mass_point.relative_mass * total_mass
        -- TODO: relative density/density (possibly optional to be parsed from name, when relative mass is not)
        --       currently, since the default is a relative density of 1, vehicles should take the value from the global properties...
        -- position/forward/up taken from the mass point transformation matrix
        mass_point.position.x = mass_point_transformation_matrix[1][4]
        mass_point.position.y = mass_point_transformation_matrix[2][4]
        mass_point.position.z = mass_point_transformation_matrix[3][4]
        mass_point.position = calculator.jms_units_to_world_units(mass_point.position)
        -- TODO: verify these in an unusual test case, with rotated mass points (they should be correct, though) (these are unit-less unit vectors, funny)
        mass_point.forward.x = mass_point_transformation_matrix[1][1]
        mass_point.forward.y = mass_point_transformation_matrix[1][2]
        mass_point.forward.z = mass_point_transformation_matrix[1][3]
        mass_point.up.x = mass_point_transformation_matrix[3][1]
        mass_point.up.y = mass_point_transformation_matrix[3][2]
        mass_point.up.z = mass_point_transformation_matrix[3][3]
        -- friction type (parsed from name?)
        -- friction scales (parsed from name?)
        mass_point.radius = calculator.jms_units_to_world_units(jms_mass_point.radius)

        -- TODO: testing... It seems this should be complete
        -- At this point, the mass point name is purged, but the JMS mass point name isn't, so we need the unpurged name to extract its data
        parsed_data = module.parse_name_data(jms_mass_point.name)
        parsed_mass_point = module.parsed_data_to_mass_point(parsed_data, engine_list, powered_mass_point_list)
        module.copy_parsed_data_to_mass_point(parsed_mass_point, mass_point)

    end

    return mass_point_table
end

-- ===== Engines =====
function module.purge_name(name)
    -- This sounds ominous, because it is: removes square bracket data from mass point names so Invader and the Halo engine accept them
    -- Mass point names apparently cannot be longer than 32 characters, so this takes care of that
    -- The catch is: this is not reversible, so you won't see these name properties in Guerilla or Invader-edit
    local i = #name
    local character
    local first_square_bracket
    local first_padding
    local j = #name
    while i >= 1 do
        character = string.sub(name, i, i)
        if character == "[" then
            first_square_bracket = i
            j = i
            -- TODO: get this done, basically first_padding looks for the first space after the last word before square bracket data
            repeat
                j = j - 1
                first_padding = string.sub(name, j, j)
            until first_padding ~= " "
        end
        i = i - 1
    end
    return string.sub(name, 1, j)
end

-- TODO: this cannot be used to raw-copy to the mass point object, its inputs must be preprocessed before
function module.copy_parsed_data_to_mass_point(data, mass_point)
    -- Expects a (partial) parsed mass point as "data" and copies its values to a mass point object 
    -- (expects mass point to contain all items from data, nested or not)
    for k, v in pairs(data) do
        -- TODO: add check that "ignores" fields that are not present in the mass point object, and throw a warning about it, I suppose
        if type(v) == "table" then
            local nested_data_table = data[k]
            local nested_mass_point_table = mass_point[k]
            module.copy_parsed_data_to_mass_point(nested_data_table, nested_mass_point_table)
        end
        mass_point[k] = data[k]
    end
end

function module.parsed_data_to_mass_point(data, engines, powered_mass_points)
    -- Expects a parsed data table, then processes its data and formats it to a mass point compatible format, so its contents can be easily copied
    -- See "parse_key_value_pair" for the list of parsable values, and how they are processed. At the moment the list is:
    --   * engine (engine file name)
    --   * metallic
    --   * powered_mass_point (powered mass point name, from the file of the selected type)
    -- If none of these are provided, then nothing of this is changed on the mass point
    -- Returns a (partial) parsed mass point
    local mass_point = {}
    local engine
    if data.engine then
        engine = module.engine_name_to_engine(data.engine, engines)
        -- If the engine JSON is not found in the engines folder, this is ignored
        if engine then
            mass_point.powered_mass_point = module.powered_mass_point_name_to_index(engine.powered_mass_point_name, powered_mass_points)
            mass_point.flags = {}
            mass_point.flags.metallic = engine.flags.metallic
            mass_point.friction_type = engine.friction_type
            mass_point.friction_parallel_scale = engine.friction_parallel_scale
            mass_point.friction_perpendicular_scale = engine.friction_perpendicular_scale
        else
            print("warning: engine type not found in engines directory \""..data.engine.."\"")
        end
    end
    -- These properties override the values from the engine object when specified explicitly, in the mass point name
    if data.flags then
        mass_point.flags = {}
        mass_point.flags.metallic = data.flags.metallic
    end
    if data.powered_mass_point_name then
        mass_point.powered_mass_point = module.powered_mass_point_name_to_index(data.powered_mass_point_name, powered_mass_points)
    end
    return mass_point
end

function module.engine_name_to_engine(name, engines)
    -- Expects an engine name, looks up said name to find a match in the engines table from the designated JSON engines directory
    -- Returns an engine object on success, nil on failure
    for k, v in pairs(engines) do
        if v.name == name then
            return v
        end
    end
end

function module.powered_mass_point_name_to_index(name, powered_mass_points)
    -- Expects a powered mass point name, looks up said name to find a match in the powered mass points table from the selected vehicle Type
    -- returns a non-negative zero-based index on success, nil on failure
    -- Reminder: uses the pairs iterator to avoid funky behavior caused by zero-based indeces
    for k, v in pairs(powered_mass_points) do
        if v.name == name then
            return k
        end
    end
end

function module.parse_name_data(name)
    -- Parses a mass point name and extracts extra information from it, including but not limited to:
    -- * mass point engine
    -- * mass point flags
    -- Looks for, and parses properties in square brackets like "[engine=front tire]", "[powered_mass_point_name=front]" or "[flags.metallic=1]"
    -- * Avoid using square brackets in names for anything that isn't a parsable property, and restrain from nesting square brackets,
    --   this parser will not keep track of nesting levels, assumes all square brackets are linear,
    --   also avoid using quotes (""), equal signs (=) and spaces in key and value pairs in square brackets
    -- Returns a parsed data table
    local data = {}
    local i = 1
    local character
    local key
    local key_start
    local key_end
    local value
    local value_start
    local value_end
    local recording = false
    while i <= string.len(name) do
        character = string.sub(name, i, i)
        if character == "[" then
            if recording then
                print("error: failed to parse data from: \""..name.."\" (incorrect square bracket usage)")
                return
            end
            recording = true
            key_start = i + 1
            key_end = i
        end
        if character == "=" and recording then
            -- This check runs if there are multiple equal signs inside a single pair of square brackets, otherwise runs as normal
            if key then
                print("error: failed to parse data from: \""..name.."\" (found banned characters in key or value names)")
                return
            end
            key_end = i - 1
            key = string.sub(name, key_start, key_end)
            value_start = i + 1
            value_end = i
        end
        if character == "]" then
            if not recording then
                print("error: failed to parse data from: \""..name.."\" (incorrect square bracket usage)")
                return
            end
            value_end = i - 1
            value = string.sub(name, value_start, value_end)
            local parsed = module.parse_key_value_pair(data, key, value)
            if not parsed then
                print("warning: failed to save key-value pair for key \""..key.."\" from mass point \""..name.."\" (unknown or unsupported key)")
            end
            key = nil
            key_start = nil
            key_end = nil
            value = nil
            value_start = nil
            value_end = nil
            recording = false
        end
        i = i + 1
    end
    return data
end

function module.parse_key_value_pair(t, k, v)
    -- This thing is the definition of KISS and, to a lower degree, technical debt
    -- I didn't want to write an overly complicated recursive function for something like this
    -- * Parses a key-value pair and saves it to table "t", accepts keys from a list of supported key value pairs, and parses dot annotated keys as tables
    if k == "metallic" then
        t.flags = {}
        t.flags.metallic = tonumber(v)
        -- If the parsed value is not valid, then it is discarded (all other checks are performed later in "parsed_data_to_mass_point")
        if t.flags.metallic ~= 0 and t.flags.metallic ~= 1 then
            t.flags.metallic = nil
        end
    elseif k == "powered_mass_point" then
        t.powered_mass_point_name = tostring(v)
    elseif k == "engine" then
        t.engine = tostring(v)
    else
        -- Returns nil on failure so the caller can trigger an error message on this mass point, if the key was not parsable or unknown
        return nil
    end
    return true
end

-- TODO: delete old function. And consider making a unified "import from folder" function, since this, and import types are very similar.
--       Same goes for "export", "encode" and "decode" functions
-- function module.import_engines()
--     -- Reads all the Engine JSON files from the designated engines directory
--     local engines = {}
-- 	if not system_utilities.is_valid_path(".\\engines") then
-- 		print("error: invalid JSON engines directory")
-- 		return
-- 	end
-- 	local engine_list = system_utilities.get_json_files_in_dir(".\\engines")
-- 	for k, v in pairs(engine_list) do
-- 		local engine_path = ".\\engines\\"..v..".json"
-- 		local engine_file = io.open(engine_path)
-- 		local content = engine_file:read("*a")
-- 		engine_file:close()
--         -- TODO: call "decode_engine" instead of dkjson's decode. Also, create decode_engine function, similarly to decode_type from PMP setup module
-- 		local object = dkjson.decode(content)
-- 		engines[v] = object
-- 	end
-- 	return engines
-- end

function module.import_engines()
	-- Reads all the Engine JSON files from the designated engines directory
	local engines = {}
	local engines_root_path = system_utilities.generate_path("./engines")
	local engines_list
	if not system_utilities.is_valid_path(engines_root_path) then
		print("error: invalid JSON engines directory (missing or inaccessible \"engines\" folder)")
		return
	end
	engines_list = system_utilities.get_json_files_in_dir(engines_root_path)
	for _, v in pairs(engines_list) do
		local path = system_utilities.generate_path(engines_root_path, "/", v, ".json")
		local file = io.open(path)
		local content
		local object
		if not file then
			print("error: failed to import engine file \""..path.."\"")
		else
			content = file:read("*a")
			file:close()
			-- TODO: call "decode_type" instead of dkjson's decode
			object = dkjson.decode(content)
			-- "v" is the engine and file name without the JSON extension, so the Engine object is stored at key [Engine name]
			engines[v] = object
		end
	end
	return engines
end

-- function module.export_standard_engines()
	-- local standard_engines = module.get_standard_engines()
	-- for _, engine in pairs(standard_engines) do
	-- 	local json = module.encode_engine(engine)
	-- 	local file_name = engine.name
	-- 	local file_path = "./engines/"..file_name..".json"
	-- 	local file = io.open(file_path, "w")
	-- 	if (file) then
	-- 		file:write(json)
	-- 		file:close()
	-- 	end
	-- end
-- end

function module.export_standard_engines()
	local standard_engines = module.get_standard_engines()
	for _, v in pairs(standard_engines) do
		local json = module.encode_engine(v)
		local name = v.name
		local path = system_utilities.generate_path("./engines/", name, ".json")
		local file = io.open(path, "w")
		if not file then
			print("error: failed to export engine file \""..path.."\"")
		else
			file:write(json)
			file:close()
		end
	end
end

function module.encode_engine(engine)
	-- "engine" is the object table to be encoded in a string in JSON notation
	-- * indent adds line breaks and indentations so the output JSON is human-readable and not a bunch of gibberish
	-- * keyorder is self-explanatory. This order is partially based on the tag-structure, though some keys are arbitrarily defined to account for additional variables from this Lua code
	local json = dkjson.encode(engine, {
        indent = true,
        keyorder = {
            "name",
            "powered_mass_point_name",
            "flags",
            "metallic",
            "friction_type",
            "friction_parallel_scale",
            "friction_perpendicular_scale"
        }
    })
	return json
end

function module.get_standard_engines()
    -- TODO: finish adding all missing engine types to this list, and export them again to the engines folder
    return {
        -- ...
        module.FighterBody(),
        module.FighterWing(),
        module.FighterWingTip(),
        module.LeftTread(),
        module.RightTread(),
        module.BackTire(),
        module.FrontTire()
        -- ...
    }
end

--[[
Hull
Metallic hull
Front tire
Back tire
Tread
Ghost wing
Ghost seat
Banshee nose (forward booster)
Banshee wing root (up dragger)
Banshee wing tip (forward booster)
Plane hover thruster (up dragger)
Plane nose (forward booster)
Plane wing tip (up dragger)

... TODO: add all of these
]] 

function module.FighterBody()
    -- Fighter body behaves the same as fighter wing tip, with a single difference: the powered mass point it attaches to
    -- * body represents the "fuselage" of the aircraft, and the forward friction type and scales make it slide forward/backwards easily, like a cylinder
    -- * attaches to powered mass point "primary antigrativty", also known as "body antigrav" in the banshee physics tag
    -- * Unlike other vehicle types, where powered mass point positions grant special behaviors to powered mass points, 
    --   powered mass point positions of the "alien fighter" vehicle type are arbitrary and all powered mass points behave the same way, 
    --   this means that "body antigrav" at position 0 and "wing antigrav" at position 1 would behave exactly the same if given the same antigrav values
    -- Unlike standard "hull" and "metallic hull" engine types, "fighter body" grants the hover effect that prevents the banshee from touching the ground
    local engine = module.Engine()
    engine.name = "fighter body"
    engine.powered_mass_point_name = "primary antigravity"
    engine.friction_type = "forward"
    engine.friction_parallel_scale = 0.25
    engine.friction_perpendicular_scale = 1
    return engine
end

function module.FighterWing()
    -- Fighter wing is an "engine" representing the wing root and wing span of an aircraft with wings, it features the following:
    -- * "up" friction type, with values that make it bounce up when hitting the gound, and slide easily instead of slowing down, like ground vehicles do
    -- * does not attach to any powered mass point, as this represents an unpowered wing structure, only affected by aerodynamics, not by an engine
    -- the friction type seems to deal only with ground friction, it seems to have no effect in air friction:
    -- * "up" ignores forward/backward and lateral friction, leaving only the friction response perpendicular to the ground (generally, pointing up/down)
    -- * tested on the "fighter" vehicle type, this may be different in the "plane" vehicle type
    local engine = module.Engine()
    engine.name = "fighter wing"
    engine.powered_mass_point_name = ""
    engine.friction_type = "up"
    engine.friction_parallel_scale = 2
    engine.friction_perpendicular_scale = 0.25
    return engine
end

function module.FighterWingTip()
    -- Fighter wing tip behaves similar to "fighter body" except that it attaches to a powered mass point with lower antigravity intensity
    -- * attaches to powered mass point "secondary antigrativty", also known as "wing antigrav" in the banshee physics tag
    local engine = module.Engine()
    engine.name = "fighter body"
    engine.powered_mass_point_name = "secondary antigravity"
    engine.friction_type = "forward"
    engine.friction_parallel_scale = 0.25
    engine.friction_perpendicular_scale = 1
    return engine
end

function module.GhostSeat()
end

function module.GhostWing()
end

function module.LeftTread()
    -- * left tread attaches to "left" powered mass point at position 0: this position controls the front/back behavior of the left track
    local engine = module.Engine()
    engine.name = "left tread"
    engine.powered_mass_point_name = "left"
    engine.friction_type = "point"
    engine.friction_parallel_scale = 1
    engine.friction_perpendicular_scale = 1
    return engine
end

function module.RightTread()
    -- The tread engine behaves similarly to front/back tires, both are powered by ground friction, differences are:
    -- * treads are divided in left and right, instead of in front and back
    -- * tread position determines the rotation direction of each tread when rotating about itself to drive in the same direction a the player's camera
    -- * right tread attaches to "right" powered mass point at position 1: this position controls the front/back behavior of the right track
    -- * both friction scales are 1: treads provide strong traction that prevents the vehicle from sliding, and offer a quick brake response
    local engine = module.Engine()
    engine.name = "right tread"
    engine.powered_mass_point_name = "right"
    engine.friction_type = "point"
    engine.friction_parallel_scale = 1
    engine.friction_perpendicular_scale = 1
    return engine
end

function module.BackTire()
    -- The back tire engine produces reduced forward movement and sliding
    -- * attaches to the "back" powered mass point at position 1: this position controls "inverted" forward movement by ground friction:
    --   transversal direction is inverted (usually along Y axis), pushes forward-left when driving forward-right, and viceversa
    -- * lower parallel friction means decreased speeding and braking response (forward and in reverse)
    -- * higher perpendicular friction means decreased lateral sliding and sharper direction switching (makes turns and brakes more intense laterally)
    local engine = module.Engine()
    engine.name = "back tire"
    engine.powered_mass_point_name = "back"
    engine.friction_type = "forward"
    engine.friction_parallel_scale = 0.45
    engine.friction_perpendicular_scale = 0.65
    return engine
end

function module.FrontTire()
    -- The front tire engine produces increased forward movement and sliding
    -- * attaches to the "front" powered mass point at position 0: this position controls standard forward movement by ground friction
    -- * higher parallel friction means increased speeding and braking response (forward and in reverse)
    -- * lower perpendicular friction means increased lateral sliding and softer direction switching (makes turns and brakes less intense laterally)
    local engine = module.Engine()
    engine.name = "front tire"
    engine.powered_mass_point_name = "front"
    engine.friction_type = "forward"
    engine.friction_parallel_scale = 0.75
    engine.friction_perpendicular_scale = 0.45
    return engine
end

function module.Engine()
    -- TODO: remove or rework as necessary, and finish, too.
    --       also move "metallic" flag to another parsable type, maybe
    -- An engine is a pseudo mass point object containing only fields that enable and affect movement generation on a mass point
    -- "name" is the identifier name of the engine, that must be specified in the mass point name, from the 3D modelling software before exporting
    -- "powered_mass_point_name" is the name of the powered mass point this mass point will try to attach to: 
    -- * the powered mass point is expected to exist in the selected vehicle type
    -- * Example: the engine with powered_mass_point_name equal to "front" will look for the PMP named "front" in the vehicle type JSON file, 
    --            and will attach the mass point to said powered mass point (so the mass point inherits its "movement" capability: ground, antigrav, etc.)
    local engine = {}
    -- This field is the identifier the parser will look for in the mass point name, to pass these properties to the mass point
    engine.name = ""
    -- This field is not passed directly to the mass point, rather, it is used to match the PMP name to a PMP index that is passed to the mass point
    engine.powered_mass_point_name = ""
    engine.flags = {}
    engine.flags.metallic = 0
    engine.friction_type = "point"
    engine.friction_parallel_scale = 1
    engine.friction_perpendicular_scale = 1
    return engine
end

function module.MassPoint()
    -- This function produces a MassPoint object that matches the structure from the "Mass Points" block of the physics tag, unlike JmsMassPoint
    -- powered_mass_point = -1 defaults to no assigned powered mass point (meaning this mass point doesn't produce movement)
    -- model_node = 0 defaults to this mass point being linked to the root node, also known as the root frame, or "frame root"
    -- flags.metallic = 0 (unchecked bit) defaults to this mass point not being metallic (whatever that means, maybe related to projectile magnetism)
    -- TODO: ...
    -- friction_type = "point" defaults to the mass point acting as a sphere facing friction from all directions (along the X, Y and Z axes)
    -- friction scales = 1 default to acting as rigid spheres that do not slide by themselves (these scales are lower in tire and tank tread mass points)
    -- TODO: ...
    local mass_point = {}
    mass_point.name = ""
    mass_point.powered_mass_point = -1
    mass_point.model_node = 0
    mass_point.flags = {}
    mass_point.flags.metallic = 0
    mass_point.relative_mass = 1
    mass_point.mass = 0
    mass_point.relative_density = 1
    mass_point.density = 0
    mass_point.position = calculator.Vector3D(0, 0, 0)
    mass_point.forward = calculator.Vector3D(1, 0, 0)
    mass_point.up = calculator.Vector3D(0, 0, 1)
    mass_point.friction_type = "point"
    mass_point.friction_parallel_scale = 1
    mass_point.friction_perpendicular_scale = 1
    mass_point.radius = 0
    return mass_point
end

return module