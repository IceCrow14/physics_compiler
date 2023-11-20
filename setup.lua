-- Setup module

-- Description: checks whether Halo and Invader paths are valid and set on first time execution, also, creates and restores default data files

local setup = {}
local parser = require("parser")
local dkjson = require("lib\\dkjson\\dkjson")
local settings_path -- Settings file path
local engine_types_path -- Engine types file path

function setup.setup()
	local settings_handle
	local engine_types_handle
	local root = get_root_directory()
	-- Settings file check
	settings_path = root.."\\settings.txt"
	settings_handle = io.open(settings_path, "r")
	while not settings_handle do
		local data_path -- Halo CE data folder path
		local tags_path -- Halo CE tags folder path
		local invader_edit_path -- Invader-edit dependency path
		print("SETUP: Failed to access settings file. First run?")
		data_path = request_path("Insert Halo CE data folder full path: ")
		tags_path = request_path("Insert Halo CE tags folder full path: ")
		invader_edit_path = request_path("Insert invader-edit.exe full path: ")
		settings_handle = io.open(settings_path, "w")
		if settings_handle then
			settings_handle:write("tags_path="..tags_path.."\n")
			settings_handle:write("data_path="..data_path.."\n")
			settings_handle:write("invader_edit_path="..invader_edit_path.."\n")
			settings_handle:close()
		end
		print("SETUP: Created default settings file.")
		settings_handle = io.open(settings_path, "r")
	end
	settings_handle:close()
	-- Engine types file check
	engine_types_path = root.."\\engine_types.txt"
	engine_types_handle = io.open(engine_types_path, "r")
	while not engine_types_handle do
		create_engine_types_file()
		print("SETUP: Created default engine type list file.")
		engine_types_handle = io.open(engine_types_path, "r")
	end
	engine_types_handle:close()
end

function setup.get_settings()
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

function setup.get_engine_types()
	local engine_types_table = {}
	local engine_types_handle
	local run = false
	engine_types_handle = io.open(engine_types_path, "r")
	if engine_types_handle then
		run = true
		engine_types_handle:close()
	end
	if run == true then
		local i = 1
		local json_start_line
		local json_end_line
		local json
		for line in io.lines(engine_types_path) do
			local first_character = string.sub(line, 1, 1)
			if first_character == "{" then
				json_start_line = i
				json_end_line = nil
			elseif first_character == "}" then
				json_end_line = i
				-- Create new entry at engine_types_table, and copy these line indeces as fields inside said entry (then delete said indeces after importing the JSON, and before decoding it, so they are not added to the decoded JSON string)
				table.insert(engine_types_table, {})
				engine_types_table[#engine_types_table].json_start_line = json_start_line
				engine_types_table[#engine_types_table].json_end_line = json_end_line
				-- Reset json_start_line
				json_start_line = nil
			end
			i = i + 1
		end
		for i, engine_table in ipairs(engine_types_table) do
			json = get_engine_json(engine_table.json_start_line, engine_table.json_end_line)
			engine_table.json_start_line = nil
			engine_table.json_end_line = nil
			engine_types_table[i] = dkjson.decode(json)
		end
	end
	return engine_types_table
end

function get_root_directory()
	local raw_source = debug.getinfo(2).source -- To get the file path: pass "1" if function is called from main script. Here is "2" because it's called from a (direct) module of main script
	local source = string.sub(raw_source, 2, #raw_source) -- Removes the initial "@" character added by Lua
	local directory_end = -1
	for i = -1, -#source, -1 do
		local character = string.sub(source, i, i)
		if character == "\\" then
			directory_end = i - 1
			break -- Exits loop at the first backslash match
		end
	end
	return string.sub(source, 1, directory_end)
end

function get_current_directory() -- TODO: remove, deprecated and replaced by get_root_directory()
	local cd
	local handle
	handle = io.popen("CD", "r")
	cd = handle:read("*l")
	handle:close()
	return cd
end

function get_engine_json(json_start_line, json_end_line)
	local i = 1
	local json_lines = {}
	local json
	for line in io.lines(engine_types_path) do
		if i >= json_start_line then
			table.insert(json_lines, line)
			if i == json_end_line then
				json = table.concat(json_lines, "\n")
				return json
			end
		end
		i = i + 1
	end
	return json
end

function create_settings_file() -- TODO: and replace old code in setup.setup()
end

function create_engine_types_file()
	-- This private function creates (or restores) the original engine types file, containing a list of default engine types found in the base game
	local engine_types_table = {}
	local engine_types_handle
	-- Tires
	local front_tire = parser.new_engine_interface() -- Front tires (ideal for control, little slide, produces forward friction)
	local back_tire = parser.new_engine_interface() -- Back tires (ideal for sliding, little control, produces forward friction)
	front_tire.type = "tire"
	front_tire.variant = "front"
	front_tire.pmp_flags.ground_friction = true
	front_tire.mp_friction_type = "forward"
	front_tire.mp_friction_parallel_scale = 0.75
	front_tire.mp_friction_perpendicular_scale = 0.45
	back_tire.type = "tire"
	back_tire.variant = "back"
	back_tire.pmp_flags.ground_friction = true
	back_tire.mp_friction_type = "forward"
	back_tire.mp_friction_parallel_scale = 0.45
	back_tire.mp_friction_perpendicular_scale = 0.75
	-- Treads
	local tread = parser.new_engine_interface() -- Treads (ideal for control, very little slide, produces forward friction)
	tread.type = "tread"
	tread.variant = "default"
	tread.pmp_flags.ground_friction = true
	-- Antigrav (WIP: these are tricky, but I will define each that is used in original Halo vehicles for now)
	local ghost_antigrav = parser.new_engine_interface() -- Ghost antigrav (medium separation from the ground, medium antigravity strength)
	local wraith_front_antigrav = parser.new_engine_interface() -- Wraith front antigrav (short separation from the ground, strong antigravity strength)
	local wraith_rear_antigrav = parser.new_engine_interface() -- Wraith rear antigrav (short separation from the ground, weak antigravity strength)
	local banshee_body_antigrav = parser.new_engine_interface() -- Banshee body antigrav (medium separation from the ground, weak antigravity strength, produces forward thrust)
	local banshee_wing_antigrav = parser.new_engine_interface() -- Banshee wing antigrav (very short separation from the ground, weak antigravity strength, produces forward thrust)	
	ghost_antigrav.type = "antigrav"
	ghost_antigrav.variant = "ghost"
	ghost_antigrav.pmp_flags.antigrav = true
	ghost_antigrav.pmp_antigrav_strength = 1.5
	ghost_antigrav.pmp_antigrav_height = 0.75
	ghost_antigrav.pmp_antigrav_damp_fraction = 0.02
	ghost_antigrav.pmp_antigrav_normal_k1 = 0.5
	ghost_antigrav.pmp_antigrav_normal_k0 = 0.258819
	ghost_antigrav.mp_flags.metallic = true
	wraith_front_antigrav.type = "antigrav"
	wraith_front_antigrav.variant = "wraith_front"
	wraith_front_antigrav.pmp_flags.antigrav = true
	wraith_front_antigrav.pmp_antigrav_strength = 2
	wraith_front_antigrav.pmp_antigrav_height = 0.5
	wraith_front_antigrav.pmp_antigrav_damp_fraction = 0.01
	wraith_front_antigrav.pmp_antigrav_normal_k1 = 0.5
	wraith_rear_antigrav.type = "antigrav"
	wraith_rear_antigrav.variant = "wraith_rear"
	wraith_rear_antigrav.pmp_flags.antigrav = true
	wraith_rear_antigrav.pmp_antigrav_strength = 1
	wraith_rear_antigrav.pmp_antigrav_height = 0.5
	wraith_rear_antigrav.pmp_antigrav_damp_fraction = 0.01
	wraith_rear_antigrav.pmp_antigrav_normal_k1 = 0.5
	banshee_body_antigrav.type = "antigrav"
	banshee_body_antigrav.variant = "banshee_body"
	banshee_body_antigrav.pmp_flags.antigrav = true
	banshee_body_antigrav.pmp_antigrav_strength = 1
	banshee_body_antigrav.pmp_antigrav_height = 0.75
	banshee_body_antigrav.pmp_antigrav_damp_fraction = 0.01
	banshee_body_antigrav.pmp_antigrav_normal_k1 = 0.1
	banshee_body_antigrav.mp_flags.metallic = true
	banshee_body_antigrav.mp_friction_type = "forward"
	banshee_body_antigrav.mp_friction_parallel_scale = 0.25
	banshee_wing_antigrav.type = "antigrav"
	banshee_wing_antigrav.variant = "banshee_wing"
	banshee_wing_antigrav.pmp_flags.antigrav = true
	banshee_wing_antigrav.pmp_antigrav_strength = 1
	banshee_wing_antigrav.pmp_antigrav_height = 0.25
	banshee_wing_antigrav.pmp_antigrav_damp_fraction = 0.01
	banshee_wing_antigrav.pmp_antigrav_normal_k1 = 0.1
	banshee_wing_antigrav.mp_flags.metallic = true
	banshee_wing_antigrav.mp_friction_type = "forward"
	banshee_wing_antigrav.mp_friction_parallel_scale = 0.25
	-- TODO: define "hull/inert" mass point engines
	-- Aircraft thrusters/lifters/draggers (WIP: these are even trickier... "human plane" vehicle types do not rely on powered mass points to create movement, instead, everything is based on friction scales defined in mass points only)
	-- TODO: define these

	-- Add formatted engines to export table
	table.insert(engine_types_table, front_tire)
	table.insert(engine_types_table, back_tire)
	table.insert(engine_types_table, tread)
	table.insert(engine_types_table, ghost_antigrav)
	table.insert(engine_types_table, wraith_front_antigrav)
	table.insert(engine_types_table, wraith_rear_antigrav)
	table.insert(engine_types_table, banshee_body_antigrav)
	table.insert(engine_types_table, banshee_wing_antigrav)
	-- Export engine types to file
	engine_types_handle = io.open(engine_types_path, "w")
	if engine_types_handle then
		for _, engine in ipairs(engine_types_table) do
			local json = parser.engine_to_readable_json(engine)
			engine_types_handle:write(json)
			engine_types_handle:write("\n")
		end
		engine_types_handle:close()
	end
end

function request_path(prompt)
	-- This private functions validates paths entered by the user, returns the requested path when a valid one is provided
	local path
	local is_valid_path = false
	while not is_valid_path do
		local command
		local handle
		local output
		io.write(prompt)
		path = '"'..io.read("*l")..'"' -- Paths are quoted systematically to allow the use of paths with space characters. Paths can be provided with quotes or without them, as long as they are paired
		command = "IF EXIST "..path.." ECHO true"
		handle = io.popen(command, "r")
		output = handle:read("*l")
		if output == "true" then
			is_valid_path = true
			break
		end
		print("SETUP: Invalid path, please provide an existing path, accesible for the current user")
	end
	return path
end

return setup