-- Exporter module

-- Description: Accesses Invader via command-line processes to create and edit the final .physics tag.

-- Lua gets picky with path names passed to native I/O functions so I resorted to old reliable Windows Batch to solve concatenated paths
-- Note that these won't perform all the checks CMD has to validate paths, but at least prevents issues related to paths provided by the user, regardless of whether they contain spaces, quoted or not
-- "swap_file_extension" and "remove_physics_subdirectory" can be stacked and both take a relative JMS path in order to compose the path of the physics tag

local exporter = {}

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
	local compose_path_command = [[SET HCE_RELATIVE_PATH=]]..relative_path..[[& CALL ECHO "%HCE_RELATIVE_PATH:"=%" ]] -- There's a lot to unpack here. I built this so you don't have to shed tears dealing with Batch dark artistry. Reminder: '&' for chaining commands regardless of outcome, 'SET' %var:old=new% for delayed expansion, 'CALL' to delay expression evaluation after environment variable assignments and '^' to pass escaped variable names instead of values to external process call. Also, lack of spaces right after 'SET' assignments are intentional on one-liners like this, and seemingly, Lua only buffers the last two commands. You were warned!
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
	local compose_path_command = [[SET HCE_ABSOLUTE_PATH=]]..base_path.."\\"..relative_path..[[& CALL ECHO "%HCE_ABSOLUTE_PATH:"=%" ]]
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

function exporter.create_tag(settings_table, composed_relative_path)
	local command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." -N "..composed_relative_path -- Overwrite existing tags
	os.execute(command)
	print(command)
end

-- function exporter.set_parameters(settings_table, composed_relative_path) -- TODO
	-- body
-- end

-- function exporter.set_mass(settings_table, composed_relative_path, mass) -- TODO
	-- local command = "CALL "..settings_table.invader_edit_path.." -t "..settings_table.tags_path.." "
-- end

-- TODO: plenty of export functions from the last prototype left to migrate here

return exporter