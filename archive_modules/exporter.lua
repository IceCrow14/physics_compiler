-- Exporter module

-- Description: Accesses Invader via command-line processes to create and edit the final .physics tag.

-- Lua gets picky with path names passed to native I/O functions so I resorted to old reliable Windows Batch to solve concatenated paths
-- Note that these won't perform all the checks CMD has to validate paths, but at least prevents issues related to paths provided by the user, in regards to whether they contain spaces, quotes or not
-- "swap_file_extension" and "remove_physics_subdirectory" can be stacked and both take a relative JMS path in order to compose the path of the physics tag

local exporter = {}

local operations = require("operations")

function exporter.swap_file_extension(relative_path)
	local end_of_extension
	local start_of_extension
	local dot
	local new_relative_path
	for i = -1, -#relative_path, -1 do
		if not end_of_extension and string.sub(relative_path, i, i) ~= '"' then
			end_of_extension = i
		end
		if string.sub(relative_path, i, i) == "." then
			dot = i
			start_of_extension = i + 1
			break
		end
	end
	if end_of_extension == -1 then -- Prevents an issue with unquoted paths
		return string.sub(relative_path, 1, dot).."physics"
	end
	return string.sub(relative_path, 1, dot).."physics"..string.sub(relative_path, end_of_extension + 1, -1)
end

function exporter.remove_physics_subdirectory(relative_path)
	local start_backslash
	local new_relative_path
	for i = -1, -#relative_path, -1 do
		if string.sub(relative_path, i, i + 8) == "\\physics\\" then
			start_backslash = i
			break
		end
	end
	if not start_backslash then
		print("EXPORTER: Relative path does not contain a physics subdirectory")
		return relative_path
	end
	return string.sub(relative_path, 1, start_backslash - 1).."\\"..string.sub(relative_path, start_backslash + 9, -1)
end

function exporter.compose_relative_path(relative_path)
	local compose_path_command = [[SET HCE_RELATIVE_PATH=]]..relative_path..[[& CALL ECHO "%HCE_RELATIVE_PATH:"=%"]] -- There's a lot to unpack here. I built this so you don't have to shed tears dealing with Batch dark artistry. Reminder: '&' for chaining commands regardless of outcome, 'SET' %var:old=new% for delayed expansion, 'CALL' to delay expression evaluation after environment variable assignments and '^' to pass escaped variable names instead of values to external process call. Also, lack of spaces right after 'SET' assignments are intentional on one-liners like this, and seemingly, Lua only buffers the last two commands. You were warned!
	local compose_path_handle = io.popen(compose_path_command)
	local new_relative_path
	if compose_path_handle then
		new_relative_path = compose_path_handle:read("*l")
		compose_path_handle:close()
	else
		print("EXPORTER: Failed to compose relative path")
	end
	return new_relative_path
end

function exporter.compose_absolute_path(base_path, relative_path)
	local compose_path_command = [[SET HCE_ABSOLUTE_PATH=]]..base_path.."\\"..relative_path..[[& CALL ECHO "%HCE_ABSOLUTE_PATH:"=%"]]

	-- print("ABOUT TO RUN COMPOSE: "..compose_path_command)

	local compose_path_handle = io.popen(compose_path_command)
	local absolute_path
	if compose_path_handle then
		absolute_path = compose_path_handle:read("*l")
		compose_path_handle:close()
	else
		print("EXPORTER: Failed to compose absolute path")
	end
	return absolute_path
end

function exporter.compose_properties(properties) -- TODO: call in main script
	local composed_properties = {}
	composed_properties.name = exporter.compose_relative_path(properties.name)
	composed_properties.radius = string.format("%d", properties.radius) -- TODO: verify
	composed_properties.moment_scale = string.format("%d", properties.moment_scale) -- TODO: verify
	composed_properties.density = string.format("%.6f", properties.density)
	composed_properties.gravity_scale = string.format("%.6f", properties.gravity_scale)
	composed_properties.ground_friction = string.format("%.6f", properties.ground_friction)
	composed_properties.ground_depth = string.format("%.6f", properties.ground_depth)
	composed_properties.ground_damp_fraction = string.format("%.6f", properties.ground_damp_fraction)
	composed_properties.ground_normal_k1 = string.format("%.6f", properties.ground_normal_k1)
	composed_properties.ground_normal_k0 = string.format("%.6f", properties.ground_normal_k0)
	composed_properties.water_friction = string.format("%.6f", properties.water_friction)
	composed_properties.water_depth = string.format("%.6f", properties.water_depth)
	composed_properties.water_density = string.format("%.6f", properties.water_density)
	composed_properties.air_friction = string.format("%.6f", properties.air_friction)
	return composed_properties
end

function exporter.compose_mass(mass)
	local composed_mass = string.format("%.6f", mass)
	return composed_mass
end

function exporter.compose_center_of_mass(center_of_mass)
	local composed_center_of_mass = {
	                                 string.format("%.6f", operations.jms_units_to_world_units(center_of_mass.x)),
	                                 string.format("%.6f", operations.jms_units_to_world_units(center_of_mass.y)),
	                                 string.format("%.6f", operations.jms_units_to_world_units(center_of_mass.z))
	                                }
	composed_center_of_mass = table.concat(composed_center_of_mass, ",")
	return composed_center_of_mass
end

function exporter.compose_inertial_moment(inertial_matrix, pivot) -- Used to compose XX, YY, and ZZ moments. Pivot can be 1, 2 or 3; translates to x, y and z respectively
	local composed_inertial_moment = inertial_matrix[pivot][pivot]
	composed_inertial_moment = string.format("%.6f", composed_inertial_moment)
	return composed_inertial_moment
end

function exporter.compose_inertial_matrix(inertial_matrix) -- This can also be used to get the composed inverse inertial matrix
	local composed_inertial_matrix = {}
	for row_index, row in ipairs(inertial_matrix) do
		local composed_row = {}
		for column_index, element in ipairs(row) do
			composed_row[column_index] = string.format("%.6f", element) -- string.format("%.5e", element) -- TODO: I resorted to format these numbers as 6 decimal precision floats because using exponential notation seems to yield wildly unequivalent values in Invader/Six Shooter
		end
		local composed_row = table.concat(composed_row, ",")
		table.insert(composed_inertial_matrix, composed_row)
	end
	composed_inertial_matrix = table.concat(composed_inertial_matrix, ",")
	return composed_inertial_matrix
end

function exporter.compose_powered_mass_point_table(powered_mass_point_table)
	for index, powered_mass_point in pairs(powered_mass_point_table) do
		powered_mass_point.name = exporter.compose_relative_path(powered_mass_point.name)
		powered_mass_point.flags.ground_friction = string.format("%d", powered_mass_point.flags.ground_friction and 1 or 0)
		powered_mass_point.flags.water_friction = string.format("%d", powered_mass_point.flags.water_friction and 1 or 0)
		powered_mass_point.flags.air_friction = string.format("%d", powered_mass_point.flags.air_friction and 1 or 0)
		powered_mass_point.flags.water_lift = string.format("%d", powered_mass_point.flags.water_lift and 1 or 0)
		powered_mass_point.flags.air_lift = string.format("%d", powered_mass_point.flags.air_lift and 1 or 0)
		powered_mass_point.flags.thrust = string.format("%d", powered_mass_point.flags.thrust and 1 or 0)
		powered_mass_point.flags.antigrav = string.format("%d", powered_mass_point.flags.antigrav and 1 or 0)
		powered_mass_point.antigrav_strength = string.format("%.6f", powered_mass_point.antigrav_strength)
		powered_mass_point.antigrav_offset = string.format("%.6f", powered_mass_point.antigrav_offset)
		powered_mass_point.antigrav_height = string.format("%.6f", powered_mass_point.antigrav_height)
		powered_mass_point.antigrav_damp_fraction = string.format("%.6f", powered_mass_point.antigrav_damp_fraction)
		powered_mass_point.antigrav_normal_k1 = string.format("%.6f", powered_mass_point.antigrav_normal_k1)
		powered_mass_point.antigrav_normal_k0 = string.format("%.6f", powered_mass_point.antigrav_normal_k0)
	end
	return powered_mass_point_table -- TODO: refactor this so the source table isn't altered
end

function exporter.compose_mass_point_table(mass_point_table) -- Converts non-string values to strings so they can be passed directly as CLI arguments
	for index, mass_point in pairs(mass_point_table) do
		mass_point.name = exporter.compose_relative_path(mass_point.name)
		mass_point.powered_mass_point = string.format("%d", mass_point.powered_mass_point)
		mass_point.model_node = string.format("%d", mass_point.model_node)
		mass_point.flags.metallic = string.format("%d", mass_point.flags.metallic and 1 or 0)
		mass_point.relative_mass = string.format("%.6f", mass_point.relative_mass)
		mass_point.mass = string.format("%.6f", mass_point.mass)
		mass_point.relative_density = string.format("%.6f", mass_point.relative_density)
		mass_point.density = string.format("%.6f", mass_point.density)
		mass_point.position = string.format("%.6f", mass_point.position.x)..","..string.format("%.6f", mass_point.position.y)..","..string.format("%.6f", mass_point.position.z)
		mass_point.forward = string.format("%.6f", mass_point.forward.x)..","..string.format("%.6f", mass_point.forward.y)..","..string.format("%.6f", mass_point.forward.z)
		mass_point.up = string.format("%.6f", mass_point.up.x)..","..string.format("%.6f", mass_point.up.y)..","..string.format("%.6f", mass_point.up.z)
		assert(
			   mass_point.friction_type == "point" or
			   mass_point.friction_type == "forward" or
			   mass_point.friction_type == "left" or
			   mass_point.friction_type == "up"
			  )
		mass_point.friction_parallel_scale = string.format("%.6f", mass_point.friction_parallel_scale)
		mass_point.friction_perpendicular_scale = string.format("%.6f", mass_point.friction_perpendicular_scale)
		mass_point.radius = string.format("%.6f", mass_point.radius)
	end
	return mass_point_table -- TODO: refactor this so the source table isn't altered
end

function exporter.create_tag(settings_table, composed_relative_tag_path)
	local command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -N "..composed_relative_tag_path -- Overwrite existing tags
	os.execute(command)
end

function exporter.add_properties(settings_table, composed_relative_tag_path, composed_properties)
	local set_value_no_safeguards_command
	for field, value in pairs(composed_properties) do
		if field ~= "name" then
			set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S "..field.." "..value.." "..composed_relative_tag_path
			os.execute(set_value_no_safeguards_command)
		end
	end
end

function exporter.add_mass(settings_table, composed_relative_tag_path, composed_mass)
	local set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S mass "..composed_mass.." "..composed_relative_tag_path
	os.execute(set_value_no_safeguards_command)
end

function exporter.add_inertial_data(settings_table, composed_relative_tag_path, composed_center_of_mass, composed_xx_moment, composed_yy_moment, composed_zz_moment, composed_inertial_matrix, composed_inverse_inertial_matrix)
	local insert_structs_command
	local set_value_no_safeguards_command
	-- Set center of mass
	set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S center_of_mass "..composed_center_of_mass.." "..composed_relative_tag_path
	os.execute(set_value_no_safeguards_command)
	-- Set xx_moment, yy_moment and zz_moment
	set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S xx_moment "..composed_xx_moment.." "..composed_relative_tag_path
	os.execute(set_value_no_safeguards_command)
	set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S yy_moment "..composed_yy_moment.." "..composed_relative_tag_path
	os.execute(set_value_no_safeguards_command)
	set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S zz_moment "..composed_zz_moment.." "..composed_relative_tag_path
	os.execute(set_value_no_safeguards_command)
	-- Add inertial matrix and inverse inertial matrix block
	insert_structs_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -I inertial_matrix_and_inverse 2 end "..composed_relative_tag_path
	os.execute(insert_structs_command)
	-- Set inertial matrix and inverse inertial matrix values
	set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S inertial_matrix_and_inverse[0].matrix "..composed_inertial_matrix.." "..composed_relative_tag_path
	os.execute(set_value_no_safeguards_command)
	set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S inertial_matrix_and_inverse[1].matrix "..composed_inverse_inertial_matrix.." "..composed_relative_tag_path
	os.execute(set_value_no_safeguards_command)
end

function exporter.add_mass_points(settings_table, composed_relative_tag_path, composed_mass_point_table)
	local mass_point_count = 0
	local insert_structs_command
	local set_value_no_safeguards_command
	for _k, _v in pairs(composed_mass_point_table) do
		mass_point_count = mass_point_count + 1
	end
	mass_point_count = string.format("%d", mass_point_count)
	insert_structs_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -I mass_points "..mass_point_count.." end "..composed_relative_tag_path
	os.execute(insert_structs_command)
	for index, mass_point in pairs(composed_mass_point_table) do
		for key, value in pairs(mass_point) do
			if type(value) == "table" then -- TODO: this special handling could be replaced by something better 
				assert(key == "flags") -- This is the only known table in the mass point struct that should pop up
				set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S mass_points["..index.."].flags.metallic "..value.metallic.." "..composed_relative_tag_path
			else
				set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S mass_points["..index.."]."..key.." "..value.." "..composed_relative_tag_path
			end
			os.execute(set_value_no_safeguards_command)
		end
	end
end

function exporter.add_powered_mass_points(settings_table, composed_relative_tag_path, composed_powered_mass_point_table)
	local powered_mass_point_count = 0
	local insert_structs_command
	local set_value_no_safeguards_command
	for _k, _v in pairs(composed_powered_mass_point_table) do
		powered_mass_point_count = powered_mass_point_count + 1
	end
	powered_mass_point_count = string.format("%d", powered_mass_point_count)
	insert_structs_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -I powered_mass_points ".. powered_mass_point_count.." end "..composed_relative_tag_path
	os.execute(insert_structs_command)
	for index, powered_mass_point in pairs(composed_powered_mass_point_table) do
		for key, value in pairs(powered_mass_point) do
			if type(value) == "table" then -- TODO: this special handling could be replaced by something better 
				assert(key == "flags") -- This is the only known table in the mass point struct that should pop up
				for flag, flag_value in pairs(value) do
					set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S powered_mass_points["..index.."].flags."..flag.." "..flag_value.." "..composed_relative_tag_path
					os.execute(set_value_no_safeguards_command)
				end
			else
				set_value_no_safeguards_command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -n -S powered_mass_points["..index.."]."..key.." "..value.." "..composed_relative_tag_path
				os.execute(set_value_no_safeguards_command)
			end
		end
	end
end

--[[ TODO: this might come in handy to handle nested fields in structs
function exporter.get_child_keys(object, ...)
	assert(
		   #arg == 0 or
		   (#arg == 1 and type(arg[1] == "string"))
		  )
	-- return
end
--]]

-- TODO: plenty of export functions from the last prototype left to migrate here

return exporter