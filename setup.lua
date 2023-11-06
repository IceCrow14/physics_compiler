-- Setup module

-- Description: checks whether Halo and Invader paths are valid and set on first time execution

-- TODO: assert valid paths are provided by the user when prompted, otherwise the whole thing falls apart
-- TODO: add validation in 'setup' function for 'engine_types' file

local setup = {}
local cd -- Current directory
local cd_handle -- Process handle for CD shell command
local settings_path -- Settings file absolute path
local settings_handle -- Settings file handle
local data_path -- Halo CE data folder
local tags_path -- Halo CE tags folder
local invader_edit_path -- Invader-edit dependency path

-- NEW
local engine_types_path
local engine_types_handle

local parser = require("parser")
local dkjson = require("lib\\dkjson\\dkjson")

function setup.setup()
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
			data_path = "\""..io.read("*l").."\""
			cmd_command = "IF EXIST "..data_path.." ECHO true"
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
			tags_path = "\""..io.read("*l").."\""
			cmd_command = "IF EXIST "..tags_path.." ECHO true"
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
			invader_edit_path = "\""..io.read("*l").."\""
			cmd_command = "IF EXIST "..invader_edit_path.." ECHO true"
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
			settings_handle:write("invader_edit_path="..invader_edit_path.."\n")
			settings_handle:close()
		end
		settings_handle = io.open(settings_path, "r")
	end
	data_path = string.sub(settings_handle:read("*l"), 11) -- string.sub used to take away variable name on settings file from line
	tags_path = string.sub(settings_handle:read("*l"), 11)
	invader_edit_path = string.sub(settings_handle:read("*l"), 19)
	settings_handle:close()
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

-- NEW
--[[
function setup.get_engine_types()
	local engine_types_table = {}

	local json_start
	local json_end
	local json

	for line in io.lines(engine_types_path) do
		local i = 1
		if string.sub(line, 1, 1) == "{" then
			json_start = i
			json_end = nil
		else if string.sub(line, 1, 1) == "}" then
			json_end = i

			json_start
		end
		i = i + 1
	end

end
]]

function setup.new_engine_types()
	local engine_types_table = {}

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
	-- Antigrav (WIP: these are kind of tricky, but I will define each that is used in original Halo vehicles for now)
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

	-- Export engine types
	table.insert(engine_types_table, front_tire)
	table.insert(engine_types_table, back_tire)
	table.insert(engine_types_table, tread)
	table.insert(engine_types_table, ghost_antigrav)
	table.insert(engine_types_table, wraith_front_antigrav)
	table.insert(engine_types_table, wraith_rear_antigrav)
	table.insert(engine_types_table, banshee_body_antigrav)
	table.insert(engine_types_table, banshee_wing_antigrav)

	engine_types_path = cd.."\\engine_types.txt" -- TODO: remove from here, initialize/validate at setup.setup()
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

function setup.get_engine_types()
	local engine_types_table = {}
	local run = false

	engine_types_path = cd.."\\engine_types.txt" -- TODO: remove from here, initialize/validate at setup.setup()

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
				-- Create new entry at engine_types_table, and copy these line indeces in fields inside said entry (then delete said indeces after exporting)
				table.insert(engine_types_table, {}) -- It works
				engine_types_table[#engine_types_table].json_start_line = json_start_line
				engine_types_table[#engine_types_table].json_end_line = json_end_line
				-- Reset json_start_line
				json_start_line = nil
			end
			i = i + 1
		end
		for i, v in ipairs(engine_types_table) do
			json = setup.get_engine_json( v.json_start_line, v.json_end_line )
			v.json_start_line = nil
			v.json_end_line = nil
			engine_types_table[i] = dkjson.decode(json)
		end
	end
	return engine_types_table
end

function setup.get_engine_json(json_start_line, json_end_line)
	local i = 1
	local json_lines = {}
	local json

	engine_types_path = cd.."\\engine_types.txt" -- TODO: remove from here, initialize/validate at setup.setup()

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

return setup