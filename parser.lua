-- Parser module

-- Description: analyses mass point names in order to detect and generate powered mass points automatically

-- With the "engine" interface in place, in the future it will be possible to create user defined engine types and variants, for now, I'll resort to create the most common ones myself and set them as defaults

-- TODO: antigrav PMPs (wing tips, wing bodies, etc.) from the original vehicles are significantly harder, if not outright impossible to parse. I'll try to create a new naming convention for such PMPs

local parser = {}

local exporter = require("exporter")
local operations = require("operations")

local dkjson = require("lib\\dkjson\\dkjson") -- NEW

function parser.print_object(object, ...) -- TODO: Debug function, remove on release
	assert(
		   #arg == 0 or 
		   (#arg == 1 and type(arg[1]) == "number")
		  )
	local indent = arg[1] or 0
	local indent_table = {}
	for i = 1, indent do
		table.insert(indent_table, "- ")
	end
	if type(object) == "table" then
		print(table.concat(indent_table).."table")
		for k, v in pairs(object) do
			parser.print_object(v, indent + 1)
		end
	else
		print(table.concat(indent_table)..type(object).." = "..tostring(object))
	end
end

function parser.get_as_words(name)
	assert(
		   type(name) == "string"
		  )
	local words = {}
	local word_start
	local word_end
	for i = 1, #name do
		if not word_start then
			if string.sub(name, i, i) ~= " " then
				word_start = i
			end
		else
			if string.sub(name, i, i) == " " then
				word_end = i - 1
				table.insert(words, string.sub(name, word_start, word_end))
				word_start = nil
			elseif i == #name then
				word_end = i
				table.insert(words, string.sub(name, word_start, word_end))
				word_start = nil
			end
		end
	end
	return words
end

function parser.is_pattern_match(word, pattern, ...) -- Third argument as "true" will find only an exact match
	assert(
		   #arg == 0 or 
		   (#arg == 1 and type(arg[1]) == "boolean")
		  )
	if #arg == 0 or arg[1] == false then
		local word_base = string.sub(word, 1, #pattern)
		return word_base == pattern
	end
	return word == pattern
end

function parser.new_properties_interface() -- TODO: these were previously called "presets"
	local properties = {}
	properties.name = "" -- Skip this field when exporting to tag
	properties.radius = -1 -- -1 is default to indicate use the "new" physics
	properties.moment_scale = 1 -- 1 is default in all original vehicle physics
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
	return properties
end

function parser.new_properties(name, density, gravity_scale, ground_friction, ground_depth, ground_damp_fraction, ground_normal_k1, ground_normal_k0, water_friction, water_depth, water_density, air_friction)
	local properties = parser.new_properties_interface()
	properties.name = name
	properties.density = density
	properties.gravity_scale = gravity_scale
	properties.ground_friction = ground_friction
	properties.ground_depth = ground_depth
	properties.ground_damp_fraction = ground_damp_fraction
	properties.ground_normal_k1 = ground_normal_k1
	properties.ground_normal_k0 = ground_normal_k0
	properties.water_friction = water_friction
	properties.water_depth = water_depth
	properties.water_density = water_density
	properties.air_friction = air_friction
	return properties
end

function parser.new_properties_table() -- TODO: in later versions, replace this function with one capable of reading dynamically generated properties from a file.
	local properties_table = {}
	table.insert(properties_table, parser.new_properties("scorpion", 8, 1, 0.2, 0.25, 0.05, 0.707107, 0.5, 0.05, 0.25, 1, 0.001))
	table.insert(properties_table, parser.new_properties("warthog", 5, 1, 0.23, 0.15, 0.05, 0.707107, 0.5, 0.05, 0.25, 1, 0.005))
	table.insert(properties_table, parser.new_properties("ghost", 3, 1, 0.2, 0.15, 0.05, 0.707107, 0.5, 0.5, 0.25, 1, 0.0025))
	table.insert(properties_table, parser.new_properties("banshee", 4, 1, 0.2, 0.15, 0.05, 0.707107, 0.5, 0.05, 0.25, 1, 0.005))
	table.insert(properties_table, parser.new_properties("c_gun_turret", 6, 1, 0.2, 0.15, 0.05, 0.707107, 0.5, 0.05, 0.25, 1, 0.001))
	return properties_table
end

function parser.get_properties(name, properties_table)
	local selected_properties
	for _, properties in pairs(properties_table) do
		if name == properties.name then
			selected_properties = properties -- TODO: ideally, replace this with a "table.copy" function
		end
	end
	assert(selected_properties)
	return selected_properties
end

function parser.new_engine_interface()
 	local engine = {}
 	engine.type = ""
 	engine.variant = ""
 	-- PMP fields
 	engine.pmp_flags = {}
 	engine.pmp_flags.ground_friction = false
 	engine.pmp_flags.water_friction = false
 	engine.pmp_flags.air_friction = false
 	engine.pmp_flags.water_lift = false
 	engine.pmp_flags.air_lift = false
 	engine.pmp_flags.thrust = false
 	engine.pmp_flags.antigrav = false
 	engine.pmp_antigrav_strength = 0
 	engine.pmp_antigrav_offset = 0
 	engine.pmp_antigrav_height = 0
 	engine.pmp_antigrav_damp_fraction = 0
 	engine.pmp_antigrav_normal_k1 = 0
 	engine.pmp_antigrav_normal_k0 = 0
 	-- MP fields
 	engine.mp_flags = {}
 	engine.mp_flags.metallic = false
 	engine.mp_friction_type = "point" -- Enum: "point" / "forward" / "left" / "up"
 	engine.mp_friction_parallel_scale = 1
 	engine.mp_friction_perpendicular_scale = 1
 	return engine
end

function parser.get_mass_point_engine_class(mass_point, engine_class_list) -- Expects a 'mass_point' object created out of a 'mass_point' interface
	assert(
		   type(mass_point) == "table"
		  )
	local mass_point_engine_class
	-- local engine_class_list = parser.get_engine_class_list() -- TODO: remove
	local name_as_words = parser.get_as_words(mass_point.name)
	local type = name_as_words[#name_as_words] or ""
	local variant = name_as_words[#name_as_words - 1] or ""
	local type_matches = {}
	for _, engine_class in pairs(engine_class_list) do
		if parser.is_pattern_match(type, engine_class.type, true) then
			table.insert(type_matches, engine_class)
		end
	end
	for _, engine_class in pairs(type_matches) do
		if parser.is_pattern_match(variant, engine_class.variant) then
			mass_point_engine_class = engine_class -- TODO: warning, this might be a pass-by-reference copy, verify. Also, look up alternatives to manually defined functions to create engine classes
			break
		end
	end
	return mass_point_engine_class -- TODO: this is a mold, basically. Don't modify it
end

function parser.new_mass_point_interface()
	local mass_point = {}
	mass_point.name = ""
	mass_point.powered_mass_point = -1
	mass_point.model_node = 0
	mass_point.flags = {}
	mass_point.flags.metallic = false
	mass_point.relative_mass = 1
	mass_point.mass = 0
	mass_point.relative_density = 1
	mass_point.density = 0 -- TODO: verify this doesn't cause trouble down the road (it doesn't, it seems)
	mass_point.position = operations.new_vector(0, 0, 0)
	mass_point.forward = operations.new_vector(1, 0, 0)
	mass_point.up = operations.new_vector(0, 0, 1)
	mass_point.friction_type = "point" -- Enum: "point" / "forward" / "left" / "up"
	mass_point.friction_parallel_scale = 1
	mass_point.friction_perpendicular_scale = 1
	mass_point.radius = 0
	return mass_point
end

function parser.new_mass_point(name)
	local mass_point = parser.new_mass_point_interface()
	mass_point.name = name
	return mass_point
end

function parser.new_mass_point_table(total_mass, mass_point_data, node_data)
	local mass_point_table = {}
	local mass_point_relative_volumes = operations.get_mass_point_relative_volumes(mass_point_data)
	for index, data in pairs(mass_point_data) do
		local mass_point
		local mass_point_transformation_matrix = operations.get_mass_point_transformation_matrix(index, mass_point_data, node_data)
		mass_point_table[index] = parser.new_mass_point(data.name)
		mass_point = mass_point_table[index]
		-- mass_point.name -- This field is set at create function
		-- mass_point.powered_mass_point = -1 -- This field is set at the engine parser
		mass_point.model_node = data.parent_node
		-- mass_point.flags.metallic -- TODO: figure out what this flag does, I guess... Maybe "true" means attract projectiles with magnetism enabled?
		mass_point.relative_mass = mass_point_relative_volumes[index]
		mass_point.mass = total_mass * mass_point_relative_volumes[index] -- TODO: verify this doesn't cause trouble down the road (it doesn't, it seems)
		-- mass_point.relative_density -- TODO: leave as 1 until I figure out what this does
		-- mass_point.density -- TODO: figure out what this value does, and replace with presets density on all mass points
		mass_point.position.x = operations.jms_units_to_world_units(mass_point_transformation_matrix[1][4])
		mass_point.position.y = operations.jms_units_to_world_units(mass_point_transformation_matrix[2][4])
		mass_point.position.z = operations.jms_units_to_world_units(mass_point_transformation_matrix[3][4])
		mass_point.forward.x = mass_point_transformation_matrix[1][1] -- TODO: verify these are the good ones in an unusual test case (they should be)
		mass_point.forward.y = mass_point_transformation_matrix[1][2]
		mass_point.forward.z = mass_point_transformation_matrix[1][3]
		mass_point.up.x = mass_point_transformation_matrix[3][1] -- TODO: verify these are the good ones in an unusual test case (they should be)
		mass_point.up.y = mass_point_transformation_matrix[3][2]
		mass_point.up.z = mass_point_transformation_matrix[3][3]
		-- mass_point.friction_type -- This field is set at the engine parser
		assert(
			   mass_point.friction_type == "point" or
			   mass_point.friction_type == "forward" or
			   mass_point.friction_type == "left" or
			   mass_point.friction_type == "up"
			  )
		-- mass_point.friction_parallel_scale -- This field is set at the engine parser
		-- mass_point.friction_perpendicular_scale -- This field is set at the engine parser
		mass_point.radius = operations.jms_units_to_world_units(data.radius)
	end
	return mass_point_table
end

function parser.new_powered_mass_point_interface()
	local powered_mass_point = {}
	powered_mass_point.name = ""
	powered_mass_point.flags = {}
 	powered_mass_point.flags.ground_friction = false
 	powered_mass_point.flags.water_friction = false
 	powered_mass_point.flags.air_friction = false
 	powered_mass_point.flags.water_lift = false
 	powered_mass_point.flags.air_lift = false
 	powered_mass_point.flags.thrust = false
 	powered_mass_point.flags.antigrav = false
 	powered_mass_point.antigrav_strength = 0
 	powered_mass_point.antigrav_offset = 0
 	powered_mass_point.antigrav_height = 0
 	powered_mass_point.antigrav_damp_fraction = 0
 	powered_mass_point.antigrav_normal_k1 = 0
 	powered_mass_point.antigrav_normal_k0 = 0
	return powered_mass_point
end

function parser.new_powered_mass_point(name)
	local powered_mass_point = parser.new_powered_mass_point_interface()
	powered_mass_point.name = name
	return powered_mass_point
end

function parser.inherit_fields(object, engine_class) -- Object refers to a 'mass_point' or a 'powered_mass_point'
	
	-- TODO: this is probably the trickiest function in the whole project, plenty of things can be reworked here (it works, though)

	for field, value in pairs(engine_class) do
		local mp_field_suffix = string.sub(field, 1, 3) -- These positions are based on the length of the prefixes of the engine interface fields
		local pmp_field_suffix = string.sub(field, 1, 4)
		local is_mp_suffix = (mp_field_suffix == "mp_") -- TODO: verify
		local is_pmp_suffix = (pmp_field_suffix == "pmp_") -- TODO: verify
		if is_mp_suffix then
			local mass_point_field = string.sub(field, 4, -1)
			if type(value) == "table" then
				if field == "mp_flags" then -- TODO: replace with dynamic function, special case for nested field "flags.metallic"
					if object.flags.metallic ~= nil then -- This "not nil" check must be explicit, since flag values may be false. If field exists in object (is a mass_point)
						object.flags.metallic = engine_class.mp_flags.metallic
					end
				end
			else
				if object[mass_point_field] then -- If field exists in object (is a mass_point)
					object[mass_point_field] = value
				end
			end
		elseif is_pmp_suffix then
			local powered_mass_point_field = string.sub(field, 5, -1)
			if type(value) == "table" then
				if field == "pmp_flags" then -- TODO: replace with dynamic function, special case for nested fields under "flags" bitmask
					if object.flags.ground_friction ~= nil then -- This "not nil" check must be explicit, since flag values may be false. If field exists in object (is a powered_mass_point)
						object.flags.ground_friction = engine_class.pmp_flags.ground_friction
						object.flags.water_friction = engine_class.pmp_flags.water_friction
						object.flags.air_friction = engine_class.pmp_flags.air_friction
						object.flags.water_lift = engine_class.pmp_flags.water_lift
						object.flags.air_lift = engine_class.pmp_flags.air_lift
						object.flags.thrust = engine_class.pmp_flags.thrust
						object.flags.antigrav = engine_class.pmp_flags.antigrav
					end
				end
			else
				if object[powered_mass_point_field] then -- If field exists in object (is a powered_mass_point)
					object[powered_mass_point_field] = value
				end
			end
		end
	end
end

function parser.parse_engines(mass_point_table, engine_class_list) -- NEW added argument

	-- TODO: another tricky function, same as above

	local pmps = {}
	local pmps_count = 0
	-- local engine_class_list = parser.get_engine_class_list() -- TODO: remove
	for index, mass_point in pairs(mass_point_table) do
		local mass_point_engine_class
		for _, engine_class in pairs(engine_class_list) do
			mass_point_engine_class = parser.get_mass_point_engine_class(mass_point, engine_class_list) -- mass_point_engine_class = parser.get_mass_point_engine_class(mass_point) -- TODO: cleanup
			if mass_point_engine_class then
				break
			end
		end
		if mass_point_engine_class then
			local mass_point_name_as_words = parser.get_as_words(mass_point.name)
			local powered_mass_point_index
			local powered_mass_point_name = mass_point_name_as_words[#mass_point_name_as_words - 1] -- TODO: verifiy. Assumes the PMP has a valid [variant] [type] structure at this point, therefore no ternaries are used
			local powered_mass_point_exists = false
			for pmp_index, pmp in pairs(pmps) do
				if powered_mass_point_name == pmp.name then
					powered_mass_point_index = pmp_index
					powered_mass_point_exists = true
					break
				end
			end
			if not powered_mass_point_exists then
				local pmp = parser.new_powered_mass_point(powered_mass_point_name)
				parser.inherit_fields(pmp, mass_point_engine_class) -- Inherit engine PMP fields to this PMP
				pmps[pmps_count] = pmp -- Indeces must start at 0, table.insert cannot be used here
				powered_mass_point_index = pmps_count
				pmps_count = pmps_count + 1
			end
			parser.inherit_fields(mass_point, mass_point_engine_class) -- Inherit engine MP fields to this mass point
			mass_point.powered_mass_point = powered_mass_point_index
		end
	end
	return pmps
end

function parser.engine_to_readable_json(engine)
	local json_key_order = {
	                        indent = true, 
	                        keyorder = {
	                                    "type",
	                                    "variant",
	                                    "pmp_flags", -- Nested table keys won't be ordered (possible TODO: review library's instructions about creating a "keyorder" file)
	                                    "pmp_antigrav_strength",
	                                    "pmp_antigrav_offset",
	                                    "pmp_antigrav_height",
	                                    "pmp_antigrav_damp_fraction",
	                                    "pmp_antigrav_normal_k1",
	                                    "pmp_antigrav_normal_k0",
	                                    "mp_flags",
	                                    "mp_friction_type",
	                                    "mp_friction_parallel_scale",
	                                    "mp_friction_perpendicular_scale",
	                                    "pmp_flags.water_lift",
	                                    "pmp_flags.air_lift",
	                                    "pmp_flags.thrust",
	                                    "pmp_flags.antigrav"
	                                   }
	                       }
	local json = dkjson.encode(engine, json_key_order)
	return json
end

return parser