-- Operations module

-- Description: performs geometry and processing operations

-- For convenience, most of the math functions work in 3DS Max units unless otherwise specified; to convert -first order- results to Halo engine units use 'jms_units_to_world_units()'

local operations = {}

function operations.get_node_parent_index(node, node_data)
	assert(type(node) == "number")
	assert(type(node_data) == "table")
	local lookup_node = node
	local i = 0 -- Loop node
	local i_first_child
	local i_next_sibling
	if node == 0 then
		return -1 -- No parent
	end
	repeat
		i_first_child = node_data[i].first_child_index
		i_next_sibling = node_data[i].next_sibling_index
		if i_next_sibling == lookup_node then -- Is the previous sibling
			lookup_node = i
			i = -1 -- Reset loop and attempt to get the parent node with previous sibling
		end
		i = i + 1
	until i_first_child == lookup_node -- Is the parent node
	return i - 1 -- Adjusted to loop exit
end

function operations.new_vector(x, y, z)
	local vector = {}
	vector.x = x
	vector.y = y
	vector.z = z
	return vector
end

function operations.new_quaternion(w, x, y, z)
	local quaternion = {}
	quaternion.w = w
	quaternion.x = x
	quaternion.y = y
	quaternion.z = z
	return quaternion
end

function operations.new_rotation_matrix(quaternion)
	local rotation_matrix = {
	                         {0, 0, 0},
	                         {0, 0, 0},
	                         {0, 0, 0}
	                        }
	rotation_matrix[1][1] = quaternion.w ^ 2 + quaternion.x ^ 2 - quaternion.y ^ 2 - quaternion.z ^ 2 -- Alternatively: 1 - 2 * quaternion.y ^ 2 - 2 * quaternion.z ^ 2
	rotation_matrix[1][2] = 2 * quaternion.x * quaternion.y - 2 * quaternion.w * quaternion.z
	rotation_matrix[1][3] = 2 * quaternion.x * quaternion.z + 2 * quaternion.w * quaternion.y
	rotation_matrix[2][1] = 2 * quaternion.x * quaternion.y + 2 * quaternion.w * quaternion.z
	rotation_matrix[2][2] = quaternion.w ^ 2 - quaternion.x ^ 2 + quaternion.y ^ 2 - quaternion.z ^ 2 -- Alternatively: 1 - 2 * quaternion.x ^ 2 - 2 * quaternion.z ^ 2
	rotation_matrix[2][3] = 2 * quaternion.y * quaternion.z - 2 * quaternion.w * quaternion.x
	rotation_matrix[3][1] = 2 * quaternion.x * quaternion.z - 2 * quaternion.w * quaternion.y
	rotation_matrix[3][2] = 2 * quaternion.y * quaternion.z + 2 * quaternion.w * quaternion.x
	rotation_matrix[3][3] = quaternion.w ^ 2 - quaternion.x ^ 2 - quaternion.y ^ 2 + quaternion.z ^ 2 -- Alternatively: 1 - 2 * quaternion.x ^ 2 - 2 * quaternion.y ^ 2
	return rotation_matrix
end

function operations.new_transformation_matrix(position_vector, rotation_matrix) -- Position and rotation can be obtained from a transformation matrix
	local transformation_matrix = {
	                               {0, 0, 0, 0},
	                               {0, 0, 0, 0},
	                               {0, 0, 0, 0},
	                               {0, 0, 0, 0}
	                              }
	transformation_matrix[1][4] = position_vector.x
	transformation_matrix[2][4] = position_vector.y
	transformation_matrix[3][4] = position_vector.z
	for row = 1, 4 do
		for column = 1, 4 do
			if row < 4 and column < 4 then
				transformation_matrix[row][column] = rotation_matrix[row][column]
			end
		end
	end
	transformation_matrix[4][4] = 1
	return transformation_matrix
end

function operations.apply_transform(transformation_matrix_A, transformation_matrix_B) -- Applies transform B onto transformation matrix A (multiplies matrix A by matrix B)
	local new_transformation_matrix = {
	                                   {0, 0, 0, 0},
	                                   {0, 0, 0, 0},
	                                   {0, 0, 0, 0},
	                                   {0, 0, 0, 0}
	                                  }
	local element
	for row = 1, 4 do
		for column = 1, 4 do
			element = 0
			for product = 1, 4 do
				element = element + transformation_matrix_A[row][product] * transformation_matrix_B[product][column] -- Does the sum of products for each term
			end
			new_transformation_matrix[row][column] = element
		end
	end
	return new_transformation_matrix
end

function operations.get_node_transformation_matrix(node, node_data)
	assert(type(node) == "number")
	assert(type(node_data) == "table")
	local parent = operations.get_node_parent_index(node, node_data)
	local relative_translation_vector = operations.new_vector(
	                                                          node_data[node].relative_translation[1], 
	                                                          node_data[node].relative_translation[2], 
	                                                          node_data[node].relative_translation[3]
	                                                         )
	local relative_rotation_quaternion = operations.new_quaternion(
	                                                               -node_data[node].relative_rotation_quaternion[4], -- Sign inverted on "w" term to match the right-handed frame of reference of 3DS Max
	                                                               node_data[node].relative_rotation_quaternion[1], 
	                                                               node_data[node].relative_rotation_quaternion[2], 
	                                                               node_data[node].relative_rotation_quaternion[3]
	                                                              )
	local relative_rotation_matrix = operations.new_rotation_matrix(relative_rotation_quaternion)
	local transformation_matrix = operations.new_transformation_matrix(relative_translation_vector, relative_rotation_matrix)
	if parent == -1 then
		return transformation_matrix
	end
	return operations.apply_transform(operations.get_node_transformation_matrix(parent, node_data), transformation_matrix) -- Solves recursively
end

function operations.get_mass_point_transformation_matrix(mass_point, mass_point_data, node_data)
	assert(type(mass_point) == "number")
	assert(type(mass_point_data) == "table")
	assert(type(node_data) == "table")
	local parent_node = mass_point_data[mass_point].parent_node
	local parent_node_transformation_matrix = operations.get_node_transformation_matrix(parent_node, node_data)
	local relative_translation_vector = operations.new_vector(
	                                                          mass_point_data[mass_point].relative_translation[1], 
	                                                          mass_point_data[mass_point].relative_translation[2], 
	                                                          mass_point_data[mass_point].relative_translation[3]
	                                                         )
	local relative_rotation_quaternion = operations.new_quaternion(
	                                                               -mass_point_data[mass_point].relative_rotation_quaternion[4], -- Sign inverted for "w" term to match the right-handed frame of reference of 3DS Max
	                                                               mass_point_data[mass_point].relative_rotation_quaternion[1], 
	                                                               mass_point_data[mass_point].relative_rotation_quaternion[2], 
	                                                               mass_point_data[mass_point].relative_rotation_quaternion[3]
	                                                              )
	local relative_rotation_matrix = operations.new_rotation_matrix(relative_rotation_quaternion)
	local transformation_matrix = operations.new_transformation_matrix(relative_translation_vector, relative_rotation_matrix)
	return operations.apply_transform(parent_node_transformation_matrix, transformation_matrix)
end

function operations.get_mass_point_relative_volumes(mass_point_data)
	local mass_point_relative_volumes = {}
	local mass_point_volumes = {}
	local total_volume = 0
	for index, data in pairs(mass_point_data) do
		mass_point_volumes[index] = 4/3 * math.pi * data.radius ^ 3
		total_volume = total_volume + mass_point_volumes[index]
	end
	for index, volume in pairs(mass_point_volumes) do
		mass_point_relative_volumes[index] = volume/total_volume
	end
	return mass_point_relative_volumes
end

function operations.get_centroid_vector(mass_point_data, node_data) -- * This function assumes all mass points are of equal density (to 1) to calculate the position of the centroid, therefore relative volumes are used instead of relative masses
	assert(type(mass_point_data) == "table")
	assert(type(node_data) == "table")
	local centroid = operations.new_vector(0, 0, 0)
	local mass_point_relative_volumes = operations.get_mass_point_relative_volumes(mass_point_data)
	local mass_point_transformation_matrix
	local mass_point_influence
	for index, data in pairs(mass_point_data) do
		mass_point_transformation_matrix = operations.get_mass_point_transformation_matrix(index, mass_point_data, node_data)
		mass_point_influence = operations.new_vector(
		                                             mass_point_transformation_matrix[1][4] * mass_point_relative_volumes[index], 
		                                             mass_point_transformation_matrix[2][4] * mass_point_relative_volumes[index], 
		                                             mass_point_transformation_matrix[3][4] * mass_point_relative_volumes[index]
		                                            )

		--[[ DEBUG: This yields the "unweighted" centroid, where all mass points are assumed of equal mass
		mass_point_influence = operations.new_vector(
		                                             mass_point_transformation_matrix[1][4] * 1/(#mass_point_relative_volumes + 1), 
		                                             mass_point_transformation_matrix[2][4] * 1/(#mass_point_relative_volumes + 1), 
		                                             mass_point_transformation_matrix[3][4] * 1/(#mass_point_relative_volumes + 1)
		                                            )
		--]]

		centroid.x = centroid.x + mass_point_influence.x
		centroid.y = centroid.y + mass_point_influence.y
		centroid.z = centroid.z + mass_point_influence.z
	end
	return centroid
end

function operations.get_inertial_matrix(centroid_vector, total_mass, mass_point_data, node_data)
	-- * Ignores density in mass point mass calculation (game engine density field is not linked to actual density)
	-- * Returns values in ready-to-export Halo world units (where applicable), no further processing is necessary
	local inertial_matrix = {
	                         {0, 0, 0},
	                         {0, 0, 0},
	                         {0, 0, 0}
	                        }
	local mass_point_relative_volumes = operations.get_mass_point_relative_volumes(mass_point_data)
	for index, data in pairs(mass_point_data) do
		local transformation_matrix = operations.get_mass_point_transformation_matrix(index, mass_point_data, node_data)
		local translation = operations.new_vector(0, 0, 0)
		local radius = operations.jms_units_to_world_units(data.radius)
		local mass = mass_point_relative_volumes[index] * total_mass
		local i_cm = (2/5) * mass * radius ^ 2 -- Inertia moment of a sphere at its center of mass
		translation.x = operations.jms_units_to_world_units(transformation_matrix[1][4] - centroid_vector.x)
		translation.y = operations.jms_units_to_world_units(transformation_matrix[2][4] - centroid_vector.y)
		translation.z = operations.jms_units_to_world_units(transformation_matrix[3][4] - centroid_vector.z)		
		inertial_matrix[1][1] = inertial_matrix[1][1] + (i_cm + mass * (translation.y ^ 2 + translation.z ^ 2)) -- i_xx. Adds the individual contributions of each mass sphere to the moments of inertia (i_aa) and products of inertia (i_ab or i_ba) based on the parallel axis theorem
		inertial_matrix[2][2] = inertial_matrix[2][2] + (i_cm + mass * (translation.x ^ 2 + translation.z ^ 2)) -- i_yy
		inertial_matrix[3][3] = inertial_matrix[3][3] + (i_cm + mass * (translation.x ^ 2 + translation.y ^ 2)) -- i_zz
		inertial_matrix[1][2] = inertial_matrix[1][2] - (mass * translation.x * translation.y) -- i_xy. Signs of these products of inertia must be flipped to match the Halo engine frame of reference
		inertial_matrix[1][3] = inertial_matrix[1][3] - (mass * translation.x * translation.z) -- i_xz
		inertial_matrix[2][3] = inertial_matrix[2][3] - (mass * translation.y * translation.z) -- i_yz
		inertial_matrix[2][1] = inertial_matrix[1][2] -- i_yx. These products of inertia are symmetric: i_ab = i_ba
		inertial_matrix[3][1] = inertial_matrix[1][3] -- i_zx
		inertial_matrix[3][2] = inertial_matrix[2][3] -- i_zy
	end
	return inertial_matrix
end

function operations.get_inverse_inertial_matrix(inertial_matrix)
	local inverse_matrix = {
	                        {0, 0, 0},
	                        {0, 0, 0},
	                        {0, 0, 0}
	                       }
	local determinant = 0
	local rightwards = 0
	local leftwards = 0
	for i = 1, #inverse_matrix do
		local product = 1
		for j = 1, #inverse_matrix - 1 do
			local row = j + 1
			local column = i + j
			column = column <= #inverse_matrix and column or (column - #inverse_matrix)
			product = product * inertial_matrix[row][column]
		end
		rightwards = rightwards + inertial_matrix[1][i] * product
	end
	for i = #inverse_matrix, 1, -1 do
		local product = 1
		for j = 1, #inverse_matrix - 1 do
			local row = j + 1
			local column = i - j
			column = column >= 1 and column or (#inverse_matrix + column)
			product = product * inertial_matrix[row][column]
		end
		leftwards = leftwards - inertial_matrix[1][i] * product
	end
	determinant = determinant + rightwards + leftwards
	for i = 1, #inverse_matrix do
		for j = 1, #inverse_matrix do
			local sign = math.mod(i, 2) == math.mod(j, 2) and 1 or -1
			local rows = {1, 2, 3}
			local columns = {1, 2, 3}
			table.remove(rows, i)
			table.remove(columns, j)
			inverse_matrix[j][i] = sign * (inertial_matrix[rows[1]][columns[1]] * inertial_matrix[rows[2]][columns[2]] - inertial_matrix[rows[2]][columns[1]] * inertial_matrix[rows[1]][columns[2]]) / determinant
		end
	end
	return inverse_matrix
end

function operations.jms_units_to_world_units(data)
	assert(type(data) == "number" or type(data) == "table")
	local world_units
	if type(data) == "number" then
		world_units = data/100
		return world_units
	elseif type(data) == "table" then -- Vector or matrix
		for index, _ in pairs(data) do
			data[index] = operations.jms_units_to_world_units(data[index])
		end
		return data
	end
end

function operations.parse_tires(mass_point_data) -- TODO: finish migrating this to 'parser' module. Attempts to find a "[...] [front[#]/back[#]/axle[#]] [tire]" pattern and create PMPs for each front/back/axle set of tires
	local tires = {}
	local pmps = {}	
	for index, data in pairs(mass_point_data) do
		local name_as_words = operations.get_as_words(data.name)
		local tire_pattern = name_as_words[#name_as_words] or ""
		local axle_pattern = name_as_words[#name_as_words - 1] or "" -- An axle is a basically a rod that passes through a pair (or more) of wheels by their center so they turn together
		local is_tire_pattern = operations.is_pattern_match(tire_pattern, "tire")
		local is_front_pattern = operations.is_pattern_match(axle_pattern, "front") -- TODO: move these settings to a file, and have their specific sub-properties saved there, allowing the user to create new presets
		local is_back_pattern = operations.is_pattern_match(axle_pattern, "back")
		local is_axle_pattern = operations.is_pattern_match(axle_pattern, "axle") -- Matches any other axle position not identifiable by "front" or "back", useful if you are creating a maniac mechanical nightmare
		if is_tire_pattern then
			local tire = {}
			tire.name = data.name
			tire.pattern = "none"
			if is_front_pattern then
				tire.pattern = "front"
			elseif is_back_pattern then
				tire.pattern = "back"
			elseif is_axle_pattern then
				tire.pattern = "axle"
			end
			tires[index] = tire
		end
	end
	for index, tire in pairs(tires) do
		local pmp_exists = false
		local name_as_words = operations.get_as_words(tire.name)
		local axle_name = name_as_words[#name_as_words - 1] or ""
		for _, pmp in pairs(pmps) do
			if axle_name == pmp.name then
				pmp_exists = true
				table.insert(pmp.tire_list, index)
				break
			end
		end
		if not pmp_exists then
			if tire.pattern ~= "none" then
				local pmp = {}
				pmp.name = axle_name
				pmp.pattern = tire.pattern
				pmp.tire_list = {}
				table.insert(pmp.tire_list, index)
				table.insert(pmps, pmp)
			else
				print("OPERATIONS: Warning, possible tire mass point not linked to a PMP ("..tire.name..")")
			end
		end
	end
	return tires, pmps
end

function operations.parse_treads(mass_point_data) -- TODO: finish migrating this to 'parser' module. This, and also, parse 'feet' mass points as treads (pending to discuss)
	-- body
end

function operations.parse_antigrav(mass_point_data) -- TODO: finish migrating this to 'parser' module.
	-- body
end

return operations