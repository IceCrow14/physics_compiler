-- Parser module

-- Description: analyses mass point names in order to detect and generate powered mass points automatically

-- With the "engine" interface in place, in the future it will be possible to create user defined engine types and variants, for now, I'll resort to create the most common ones myself and set them as defaults

parser = {}

local exporter = require("exporter")
local operations = require("operations")

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
 	-- MP fields
 	engine.mp_flags = {}
 	engine.mp_flags.metallic = false
 	engine.mp_friction_type = "point" -- Enum: "point" / "forward" / "left" / "up"
 	engine.mp_friction_parallel_scale = 1
 	engine.mp_friction_perpendicular_scale = 1
 	return engine
end

function parser.new_tire_class(variant, mp_friction_parallel_scale, mp_friction_perpendicular_scale)
	assert(
		   type(variant) == "string" and 
		   type(mp_friction_parallel_scale) == "number" and 
		   type(mp_friction_perpendicular_scale) == "number" and
		   variant ~= ""
		  )
	local engine = parser.new_engine_interface()
	engine.type = "tire"
	engine.variant = variant
	-- PMP fields
	engine.pmp_flags.ground_friction = true
	-- MP fields
	engine.mp_friction_type = "forward"
	engine.mp_friction_parallel_scale = mp_friction_parallel_scale
	engine.mp_friction_perpendicular_scale = mp_friction_perpendicular_scale
	return engine
end

function parser.new_front_tire(name)
	assert(
		   type(name) == "string"
		  )
	local engine = parser.new_tire_class("front", 0.75, 0.45)
	engine.name = name
	return engine
end

function parser.new_back_tire(name)
	assert(
		   type(name) == "string"
		  )
	local engine = parser.new_tire_class("back", 0.45, 0.75)
	engine.name = name
	return engine
end

function parser.new_default_tire(name)
	assert(
		   type(name) == "string"
		  )
	local engine = parser.new_tire_class("default", (0.75 + 0.45)/2, (0.75 + 0.45)/2)
	engine.name = name
	return engine
end

function parser.new_tread_class() -- TODO
	-- body
end

function parser.new_antigrav_class() -- TODO
	-- body
end

function parser.get_engine_class_list()
	local engine_class_list = {}
	table.insert(engine_class_list, parser.new_front_tire(""))
	table.insert(engine_class_list, parser.new_back_tire(""))
	table.insert(engine_class_list, parser.new_default_tire(""))
	-- TODO: add the rest of the engine classes, once defined
	return engine_class_list
end

function parser.parse_tires(mass_point_data) -- TODO: WIP, also, consider merging this with other parse_[engine] functions into a single one
	local pmps = {}
	local tires = {}
	for index, data in pairs(mass_point_data) do
		local mass_point_engine_class = parser.get_mass_point_engine_class(index, mass_point_data)
	end
end

function parser.get_mass_point_engine_class(mass_point, mass_point_data)
	assert(
		   type(mass_point) == "number" and
		   type(mass_point_data) == "table"
		  )
	local mass_point_engine_class
	local engine_class_list = parser.get_engine_class_list()
	local name_as_words = parser.get_as_words(mass_point_data[mass_point].name)
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
	return mass_point_engine_class
end

function parser.new_mass_point_interface() -- I won't touch this until tomorrow, I'm drunk
	local mass_point = {}
	mass_point.name = ""
	mass_point.powered_mass_point = -1
	mass_point.model_node = 0
	mass_point.flags = {}
	mass_point.flags.metallic = false
	mass_point.relative_mass = 1
	mass_point.mass = 0
	mass_point.relative_density = 1
	mass_point.density = 0 -- TODO: verify this doesn't cause trouble down the road
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

function parser.new_mass_point_table(total_mass, mass_point_data, node_data) -- TODO: integrate with PMP parsers. Also, convert numbers to strings
	local mass_point_table = {}
	local mass_point_relative_volumes = operations.get_mass_point_relative_volumes(mass_point_data)
	for index, data in pairs(mass_point_data) do
		local mass_point
		local mass_point_transformation_matrix = operations.get_mass_point_transformation_matrix(index, mass_point_data, node_data)
		mass_point_table[index] = parser.new_mass_point(data.name)
		mass_point = mass_point_table[index]
		mass_point.name = exporter.compose_relative_path(mass_point.name) -- !@#$. Even mass point nodes with spaces have to be composed...
		mass_point.powered_mass_point = string.format("%d", -1) -- TODO: get from PMP parsers instead of "-1"
		mass_point.model_node = string.format("%d", data.parent_node)
		mass_point.flags.metallic = string.format("%d", mass_point.flags.metallic and 1 or 0) -- TODO: figure out what this flag does, I guess... Maybe "true" means attract projectiles with magnetism enabled?
		mass_point.relative_mass = string.format("%.6f", mass_point_relative_volumes[index])
		mass_point.mass = string.format("%.6f", total_mass * mass_point_relative_volumes[index]) -- TODO: verify this doesn't cause trouble down the road
		mass_point.relative_density = string.format("%.6f", mass_point.relative_density) -- TODO: leave as 1 until I figure out what this does
		mass_point.density = string.format("%.6f", mass_point.density) -- TODO: figure out what this value does, and replace with presets density on all mass points
		-- TODO: replace position numeric values with a single "exportable" string, like in the old exporter module
		mass_point.position.x = operations.jms_units_to_world_units(mass_point_transformation_matrix[1][4])
		mass_point.position.y = operations.jms_units_to_world_units(mass_point_transformation_matrix[2][4])
		mass_point.position.z = operations.jms_units_to_world_units(mass_point_transformation_matrix[3][4])
		mass_point.position = string.format("%.6f", mass_point.position.x)..","..string.format("%.6f", mass_point.position.y)..","..string.format("%.6f", mass_point.position.z)
		mass_point.forward.x = mass_point_transformation_matrix[1][1] -- TODO: get from transformation matrix, and verify these are the good ones (they should be)
		mass_point.forward.y = mass_point_transformation_matrix[1][2]
		mass_point.forward.z = mass_point_transformation_matrix[1][3]
		mass_point.forward = string.format("%.6f", mass_point.forward.x)..","..string.format("%.6f", mass_point.forward.y)..","..string.format("%.6f", mass_point.forward.z)
		mass_point.up.x = mass_point_transformation_matrix[3][1] -- TODO: get from transformation matrix, and verify these are the good ones (they should be)
		mass_point.up.y = mass_point_transformation_matrix[3][2]
		mass_point.up.z = mass_point_transformation_matrix[3][3]
		mass_point.up = string.format("%.6f", mass_point.up.x)..","..string.format("%.6f", mass_point.up.y)..","..string.format("%.6f", mass_point.up.z)
		-- mass_point.friction_type -- TODO: get from PMP parsers, and assert that it is a valid enum value
		assert(
			   mass_point.friction_type == "point" or
			   mass_point.friction_type == "forward" or
			   mass_point.friction_type == "left" or
			   mass_point.friction_type == "up"
			  )
		mass_point.friction_parallel_scale = string.format("%.6f", mass_point.friction_parallel_scale) -- TODO: get from PMP parsers
		mass_point.friction_perpendicular_scale = string.format("%.6f", mass_point.friction_perpendicular_scale) -- TODO: get from PMP parsers
		mass_point.radius = string.format("%.6f", operations.jms_units_to_world_units(data.radius))
	end
	return mass_point_table
end

return parser