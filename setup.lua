-- Setup module

-- Description: checks whether Halo and Invader paths are valid and set on first time execution

local module = {}
local cd -- Current directory
local cd_handle -- Process handle for CD shell command
local settings_path -- Settings file absolute path
local settings_handle -- Settings file handle
local data_path -- Halo CE data folder
local tags_path -- Halo CE tags folder
local invader_edit_path -- Invader-edit dependency path

function module.setup()
	cd_handle = io.popen("CD", "r")
	cd = cd_handle:read("*l")
	cd_handle:close()
	settings_path = cd.."\\settings.txt"
	settings_handle = io.open(settings_path, "r")
	while not settings_handle do
		local data_path_valid
		local tags_path_valid
		local invader_edit_path_valid
		print("SETUP: Failed to access settings file")
		while not data_path_valid do
			local cmd_command
			local cmd_handle
			local cmd_output
			io.write("Insert Halo CE data folder full path (in quotes): ") -- Full paths asked in quotes to allow the use of paths with space characters
			data_path = io.read("*l")
			cmd_command = "IF EXIST \""..data_path.."\" ECHO true"
			cmd_handle = io.popen(cmd_command, "r")
			cmd_output = cmd_handle:read("*l")
			cmd_handle:close()
			if cmd_output == "true" then
				data_path_valid = true
				break
			end
			print("SETUP: Invalid path")
		end
		while not tags_path_valid do
			local cmd_command
			local cmd_handle
			local cmd_output
			io.write("Insert Halo CE tags folder full path (in quotes): ")
			tags_path = io.read("*l")
			cmd_command = "IF EXIST \""..tags_path.."\" ECHO true"
			cmd_handle = io.popen(cmd_command, "r")
			cmd_output = cmd_handle:read("*l")
			cmd_handle:close()
			if cmd_output == "true" then
				tags_path_valid = true
				break
			end
			print("SETUP: Invalid path")
		end
		while not invader_edit_path_valid do
			local cmd_command
			local cmd_handle
			local cmd_output
			io.write("Insert invader-edit.exe full path (in quotes): ")
			invader_edit_path = io.read("*l")
			cmd_command = "IF EXIST \""..invader_edit_path.."\" ECHO true"
			cmd_handle = io.popen(cmd_command, "r")
			cmd_output = cmd_handle:read("*l")
			cmd_handle:close()
			if cmd_output == "true" then
				invader_edit_path_valid = true
				break
			end
			print("SETUP: Invalid path")
		end
		settings_handle = io.open(settings_path, "w")
		if settings_handle then
			settings_handle:write("tags_path="..tags_path.."\n") -- Writes variable names followed by paths to settings file
			settings_handle:write("data_path="..data_path.."\n")
			settings_handle:write("invader-edit_path="..invader_edit_path.."\n")
			settings_handle:close()
		end
	end
	settings_handle = io.open(settings_path, "r")
	data_path = string.sub(settings_handle:read("*l"), 11) -- string.sub used to take away variable name from line
	tags_path = string.sub(settings_handle:read("*l"), 11)
	invader_edit_path = string.sub(settings_handle:read("*l"), 19)
end

function module.get_settings()
	local setting_table = {}
	local setting_name
	local setting_value
	for line in io.lines(settings_path) do
		local i = 1
		local equal_sign_position
		while i <= #line do -- No binary search for 'U'. Ooooh!
			if string.sub(line, i, i) == "=" then
				equal_sign_position = i
				setting_name = string.sub(line, 1, equal_sign_position - 1)
				setting_value = string.sub(line, equal_sign_position + 1, -1)
				break
			end
			i = i + 1
		end
		setting_table[setting_name] = setting_value
	end
	return setting_table
end

return module