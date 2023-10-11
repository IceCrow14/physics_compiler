-- JMS extractor module

-- Description: extracts 3D geometry data from source JMS file, adapted to the latest standardized JMS exporter for 3DS Max/Blender (* verify compatibility on both)

local jms_extractor = {}

function jms_extractor.line_to_table(line) -- Takes a line (string) from a file and returns tab separated (numeric) values to a table
	local data = {}
	local i = 1
	local datum_start_i = 1
	local datum_end_i
	local datum
	while i <= #line do
		if string.sub(line, i, i) == "	" then
			datum_end_i = i - 1
			datum = tonumber(string.sub(line, datum_start_i, datum_end_i))
			table.insert(data, datum)
			datum_start_i = i + 1
		end
		if i == #line and string.sub(line, i, i) ~= "	" then
			datum_end_i = i
			datum = tonumber(string.sub(line, datum_start_i, datum_end_i))
			table.insert(data, datum)
		end
		i = i + 1
	end
	return data
end

function jms_extractor.get_node_count(composed_absolute_path)
	local node_count
	local i = 1
	for line in io.lines(composed_absolute_path) do
		if i == 3 then -- Third line of file on latest format is the node count
			node_count = tonumber(line)
			break
		end
		i = i + 1
	end
	return node_count
end

function jms_extractor.get_node_data(composed_absolute_path)
	local node_data = {}
	local node_count = jms_extractor.get_node_count(composed_absolute_path)
	local i = 1
	local skip
	local skip_line_count = 3
	local node_index = 0 -- Real node indeces, starting from 0, opposed to Lua indeces starting from 1
	local node_name
	local node_first_child_index
	local node_next_sibling_index
	local node_relative_rotation_quaternion -- Relative rotation in quaternion "ijkw" notation, to parent node
	local node_relative_translation -- Relative translation in "ijk" notation, to parent node (do not confuse with world/absolute translation)
	for line in io.lines(composed_absolute_path) do
		skip = false
		if i <= skip_line_count then -- First node name line starts right after node count line
			skip = true
		end
		while not skip do
			skip = true
			if not node_name then
				node_name = line
				node_data[node_index] = {} -- Initialize node data table
				node_data[node_index].name = node_name
			elseif not node_first_child_index then
				node_first_child_index = tonumber(line)
				node_data[node_index].first_child_index = node_first_child_index
			elseif not node_next_sibling_index then
				node_next_sibling_index = tonumber(line)
				node_data[node_index].next_sibling_index = node_next_sibling_index
			elseif not node_relative_rotation_quaternion then
				node_relative_rotation_quaternion = jms_extractor.line_to_table(line)
				node_data[node_index].relative_rotation_quaternion = node_relative_rotation_quaternion
			elseif not node_relative_translation then
				node_relative_translation = jms_extractor.line_to_table(line)
				node_data[node_index].relative_translation = node_relative_translation
			else
				skip = false -- On node jump, try again with next node index
				node_index = node_index + 1
				if node_index >= node_count then
					break
				end
				node_name = nil
				node_first_child_index = nil
				node_next_sibling_index = nil
				node_relative_rotation_quaternion = nil
				node_relative_translation = nil
			end
		end
		i = i + 1
	end
	return node_data
end

function jms_extractor.get_materials_count(composed_absolute_path) -- It is not necessary to extract materials data for a .physics tag, but it is to get the amount of materials and count the lines such section takes on the file
	local materials_count
	local node_count = jms_extractor.get_node_count(composed_absolute_path)
	local i = 1
	local skip
	local skip_line_count = 3 + 5 * node_count -- Each node on the JMS file takes 5 lines, plus 3 lines at the start of the file
	for line in io.lines(composed_absolute_path) do
		skip = false
		if i <= skip_line_count then
			skip = true
		end
		if not skip then
			materials_count = tonumber(line)
			break
		end
		i = i + 1
	end
	return materials_count
end

function jms_extractor.get_mass_point_count(composed_absolute_path)
	local mass_point_count
	local node_count = jms_extractor.get_node_count(composed_absolute_path)
	local materials_count = jms_extractor.get_materials_count(composed_absolute_path)
	local i = 1
	local skip
	local skip_line_count = 3 + 5 * node_count + 1 + 2 * materials_count -- * Verify that each material is always 2 lines in size (for now, it seems they are). Plus one line from the materials count line right after the node data section
	for line in io.lines(composed_absolute_path) do
		skip = false
		if i <= skip_line_count then
			skip = true
		end
		if not skip then
			mass_point_count = tonumber(line)
			break
		end
		i = i + 1
	end
	return mass_point_count
end

function jms_extractor.get_mass_point_data(composed_absolute_path)
	local mass_point_data = {}
	local node_count = jms_extractor.get_node_count(composed_absolute_path)
	local materials_count = jms_extractor.get_materials_count(composed_absolute_path)
	local mass_point_count = jms_extractor.get_mass_point_count(composed_absolute_path)
	local i = 1
	local skip
	local skip_line_count = 3 + 5 * node_count + 1 + 2 * materials_count + 1 -- Plus one line from the mass point count line
	local mass_point_index = 0 -- Real mass point indeces, starting from 0, opposed to Lua indeces starting from 1
	local mass_point_name
	local mass_point_powered_mass_point
	local mass_point_parent_node
	local mass_point_relative_rotation_quaternion
	local mass_point_relative_translation
	local mass_point_radius
	for line in io.lines(composed_absolute_path) do
		skip = false
		if i <= skip_line_count then
			skip = true
		end
		while not skip do
			skip = true
			if not mass_point_name then
				mass_point_name = line
				mass_point_data[mass_point_index] = {} -- Initialize mass point data table
				mass_point_data[mass_point_index].name = mass_point_name
			elseif not mass_point_powered_mass_point then
				mass_point_powered_mass_point = tonumber(line)
				mass_point_data[mass_point_index].powered_mass_point = mass_point_powered_mass_point
			elseif not mass_point_parent_node then
				mass_point_parent_node = tonumber(line)
				mass_point_data[mass_point_index].parent_node = mass_point_parent_node
			elseif not mass_point_relative_rotation_quaternion then
				mass_point_relative_rotation_quaternion = jms_extractor.line_to_table(line)
				mass_point_data[mass_point_index].relative_rotation_quaternion = mass_point_relative_rotation_quaternion
			elseif not mass_point_relative_translation then
				mass_point_relative_translation = jms_extractor.line_to_table(line)
				mass_point_data[mass_point_index].relative_translation = mass_point_relative_translation
			elseif not mass_point_radius then
				mass_point_radius = tonumber(line)
				mass_point_data[mass_point_index].radius = mass_point_radius
			else
				skip = false -- On mass point jump, try again with next mass point index
				mass_point_index = mass_point_index + 1
				if mass_point_index >= mass_point_count then
					break
				end
				mass_point_name = nil
				mass_point_powered_mass_point = nil
				mass_point_parent_node = nil
				mass_point_relative_rotation_quaternion = nil
				mass_point_relative_translation = nil
				mass_point_radius = nil
			end
		end
		i = i + 1
	end
	return mass_point_data
end

return jms_extractor