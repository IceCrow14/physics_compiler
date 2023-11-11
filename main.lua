-- Main script

-- Description: integrates all the modules and starts the application

-- TODO: migrate "properties/presets" to a file, similar to engine types

local setup = require("setup")
local jms_extractor = require("jms_extractor")
local exporter = require("exporter")
local operations = require("operations")
local parser = require("parser")

local settings

setup.setup()
settings = setup.get_settings()

function run_help_message() -- TODO: update this whenever usage syntax changes
	local message = {
	                 "Usage: lua main.lua [ -h | -p | <jms_path> <mass> <properties> ]",
	                 "",
	                 "Physics compiler for Halo Custom Edition by IceCrow14",
	                 "",
	                 "Options:",
	                 "  -h                           Show this help message and exit.",
	                 "  -p                           Show a list of selectable sets of vehicle properties.",
	                 "  -e                           Show a list of available vehicle engine types.",
	                 "",
	                 "Arguments:",
	                 "  jms_path                     Relative path of the JMS file, in quotes",
	                 "  mass                         Total vehicle mass",
	                 "  properties                   Name of the set of vehicle properties",
	                 "",
	                 "Example: lua main.lua \"vehicles\\my_vehicle\\physics\\my_vehicle_collision_and_physics_model.jms\" 5000 warthog"
	                }
	message = table.concat(message, "\n")
	print(message)
end

function run_presets_message(properties_table)
	local message = {
	                 "Sets:"
	                }
	for _, set in pairs(properties_table) do -- TODO: these are added in unspecified order. Next, I might replace this so entries are displayed by order of insertion. Nevermind, they already are.
		table.insert(message, "  "..set.name)
	end
	message = table.concat(message, "\n")
	print(message)
end

function run_invalid_pattern_message()
	local message = {
	                 "Invalid pattern of arguments, please review usage help.",
	                 "",
	                 "No operations were done."
	                }
	message = table.concat(message, "\n")
	print(message)
end



function command_line_guide(arguments)
	if #arguments == 0 then
		-- Show help message
		run_help_message()
	else
		if #arguments == 1 and arguments[1] == "-h" then
			-- Show help message
			run_help_message()
		elseif #arguments == 1 and arguments[1] == "-p" then -- TODO: keep an eye on this, update when addition of custom presets is introduced
			-- Show presets list
			local properties_table = parser.new_properties_table()
			run_presets_message(properties_table)
		elseif #arguments == 1 and arguments[1] == "-e" then
			-- Show engines list
			-- TODO
		else
			if #arguments == 3 then
				-- Validate input arguments and run application if valid
				local relative_jms_path = exporter.compose_relative_path(arguments[1])
				local mass = tonumber(arguments[2])
				local set = arguments[3]

				local properties_sets_table = parser.new_properties_table()
				local selected_properties_set = parser.get_properties(set, properties_sets_table)

				local absolute_jms_path
				local relative_tag_path

				local jms_node_table
				local jms_mass_point_table
				local center_of_mass
				local inertial_matrix
				local inverse_inertial_matrix
				local mass_point_table
				local powered_mass_point_table

				local composed_properties_set
				local composed_mass
				local composed_center_of_mass
				local composed_xx_moment
				local composed_yy_moment
				local composed_zz_moment
				local composed_inertial_matrix
				local composed_inverse_inertial_matrix
				local composed_powered_mass_point_table
				local composed_mass_point_table

				-- assert() -- TODO: relative path to data folder points to a valid location
				assert(type(mass) == "number" and mass > 0) -- TODO: mass as number returns a positive number
				assert(selected_properties_set) -- TODO: set name is a that of an existing set

				absolute_jms_path = exporter.compose_absolute_path(settings.data_path, relative_jms_path)
				absolute_jms_path = string.sub(absolute_jms_path, 2, -2) -- Removes quotes inside the string, or at least, it should...

				relative_tag_path = exporter.remove_physics_subdirectory(relative_jms_path)
				relative_tag_path = exporter.swap_file_extension(relative_tag_path)

				jms_node_table = jms_extractor.get_node_data(absolute_jms_path) -- FIXME: Lua doing picky Lua things... The I/O library functions won't accept a path with quotes.
				jms_mass_point_table = jms_extractor.get_mass_point_data(absolute_jms_path)
				center_of_mass = operations.get_centroid_vector(jms_mass_point_table, jms_node_table)
				inertial_matrix = operations.get_inertial_matrix(center_of_mass, mass, jms_mass_point_table, jms_node_table)
				inverse_inertial_matrix = operations.get_inverse_inertial_matrix(inertial_matrix)
				mass_point_table = parser.new_mass_point_table(mass, jms_mass_point_table, jms_node_table)
				powered_mass_point_table = parser.parse_engines(mass_point_table, setup.get_engine_types() ) -- TODO: cleanup, engine_class_list
				composed_properties_set = exporter.compose_properties(selected_properties_set)
				composed_mass = exporter.compose_mass(mass)
				composed_center_of_mass = exporter.compose_center_of_mass(center_of_mass)
				composed_xx_moment = exporter.compose_inertial_moment(inertial_matrix, 1)
				composed_yy_moment = exporter.compose_inertial_moment(inertial_matrix, 2)
				composed_zz_moment = exporter.compose_inertial_moment(inertial_matrix, 3)
				composed_inertial_matrix = exporter.compose_inertial_matrix(inertial_matrix)
				composed_inverse_inertial_matrix = exporter.compose_inertial_matrix(inverse_inertial_matrix)
				composed_powered_mass_point_table = exporter.compose_powered_mass_point_table(powered_mass_point_table)
				composed_mass_point_table = exporter.compose_mass_point_table(mass_point_table)

				exporter.create_tag(settings, relative_tag_path)
				exporter.add_properties(settings, relative_tag_path, composed_properties_set)
				exporter.add_mass(settings, relative_tag_path, composed_mass)
				exporter.add_inertial_data(settings, relative_tag_path, composed_center_of_mass, composed_xx_moment, composed_yy_moment, composed_zz_moment, composed_inertial_matrix, composed_inverse_inertial_matrix)
				exporter.add_powered_mass_points(settings, relative_tag_path, composed_powered_mass_point_table)
				exporter.add_mass_points(settings, relative_tag_path, composed_mass_point_table)
			else
				-- Show "invalid pattern" message, suggest using help menu
				run_invalid_pattern_message()
			end
		end
	end
end

command_line_guide(arg)