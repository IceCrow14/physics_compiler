-- Calculator module (previously "operations" module)

-- Provides functions for calculations related to geometry, mathematics and others

-- TODO: add "moment scale" argument to the inertial matrix function, I guess... And add multiplying factor where applied
-- TODO: add "get_xx/yy/zz moment(s)" function that takes these values from the pivots of the inertial matrix and returns them as a Vector3D

local module = {}

function module.get_moments_vector(inertial_matrix)
    -- TODO: wait... Is this right? Got it! These values are determined not only by the matrix, but also by the "radius" mysterious global value
    -- * When radius is negative, uses "the new updated" physics according to the Guerilla dialog and the pivot values from the matrix
    -- * Otherwise, they differ by a small amount, I still don't know by how much: regardless of the "radius" value, only its sign determines the outcomes
    -- Returns the xx_moment, yy_moment and zz_moment geometry dependent values that go in the properties section
    -- These values are unitless, so they are not scaled to Halo world units
    local moments = module.Vector3D(
        inertial_matrix[1][1],
        inertial_matrix[2][2],
        inertial_matrix[3][3]
    )
    return moments
end

function module.get_inverse_inertial_matrix(inertial_matrix)
    -- I don't remember how exactly I came up with this monster of code, I just remember I based this off some mathematics theory I found online (it works)
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

function module.get_inertial_matrix(total_mass, center_of_mass_vector, jms_mass_point_relative_mass_table, jms_mass_point_table, jms_node_table)
    -- TODO: take a moment_scale argument, passed from a valid properties table
    --       also note that moment scale must be a value between 0 and 1, inclusive, according to Guerilla dialogs
    -- IMPORTANT: "moment scale" in the physics tag scales inertial matrix (and inverse matrix) values
    -- (moment scale should be 1 by default, otherwise values calculated by Guerilla will differ with values calculated here)
	-- Returns values in ready-to-export Halo world units (where applicable), this inertial matrix can be directly passed to the tag using Invader
	local inertial_matrix = {
        {0, 0, 0},
        {0, 0, 0},
        {0, 0, 0}
    }
    local transformation_matrix
    local translation_vector
    local radius
    local mass
    local i_cm
	for mass_point_index, mass_point in pairs(jms_mass_point_table) do
		transformation_matrix = module.get_jms_mass_point_transformation_matrix(mass_point_index, jms_mass_point_table, jms_node_table)
		translation = module.Vector3D(0, 0, 0)
        radius = module.jms_units_to_world_units(mass_point.radius)
        mass = jms_mass_point_relative_mass_table[mass_point_index] * total_mass
        -- i_cm = Inertia moment of a sphere at its center of mass
        i_cm = (2/5) * mass * radius ^ 2
        translation.x = module.jms_units_to_world_units(transformation_matrix[1][4] - center_of_mass_vector.x)
        translation.y = module.jms_units_to_world_units(transformation_matrix[2][4] - center_of_mass_vector.y)
        translation.z = module.jms_units_to_world_units(transformation_matrix[3][4] - center_of_mass_vector.z)
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

function module.get_center_of_mass_vector(jms_mass_point_relative_mass_table, jms_mass_point_table, jms_node_table)
    local center_of_mass = module.Vector3D(0, 0, 0)
    local mass_point_transformation_matrix
    local mass_point_influence
    for mass_point_index, _ in pairs(jms_mass_point_table) do
        mass_point_transformation_matrix = module.get_jms_mass_point_transformation_matrix(mass_point_index, jms_mass_point_table, jms_node_table)
        mass_point_influence = module.Vector3D(
            -- Each component is, respectively: mass point X/Y/Z * mass point relative mass
            mass_point_transformation_matrix[1][4] * jms_mass_point_relative_mass_table[mass_point_index],
            mass_point_transformation_matrix[2][4] * jms_mass_point_relative_mass_table[mass_point_index],
            mass_point_transformation_matrix[3][4] * jms_mass_point_relative_mass_table[mass_point_index]
        )
        center_of_mass.x = center_of_mass.x + mass_point_influence.x
        center_of_mass.y = center_of_mass.y + mass_point_influence.y
        center_of_mass.z = center_of_mass.z + mass_point_influence.z
    end
    return center_of_mass
end

function module.get_jms_mass_point_relative_mass_table(jms_mass_point_table, distribution)
    -- This function generates a mass distribution based on one of the following choices (if distribution argument is omitted, defaults to "equal"):
    -- 1. [equal] vehicle mass is equally distributed among all mass points, regardless of their size/volume
    -- 2. [proportional] each individual mass point gets a mass proportional to its size/volume
    -- Unlike real life, in the Halo engine, mass, density and volume are not related to each other; they perform separately
    -- Mass controls inertia effects and weight distribution
    -- Density only controls buoyancy in water, regardless of mass
    -- Volume is just a measure of object size in a 3D space, though it can be used as a basis for certain calculations
    -- * Reminder: since jms node indeces start at 0, all table insert and length operations must be handled manually, and not with standard functions
    local mass_point_relative_masses = {}
    if distribution == "proportional" then
        local mass_point_relative_volumes = module.get_jms_mass_point_relative_volume_table(jms_mass_point_table)
        for mass_point, mass_point_volume in pairs(mass_point_relative_volumes) do
            -- Since Halo density is irrelevant, this assumes all mass points are of equal real world density (assumed to be 1 mass unit/volume unit)
            -- Therefore, mass point relative volume multiplied by 1 returns the relative mass point mass
            -- Then, the goal is to multiply relative mass by the total vehicle mass to get the individual (proportional) mass of each mass point
            mass_point_relative_masses[mass_point] = mass_point_volume
        end
        return mass_point_relative_masses
    end
    -- This runs if distribution is "equal" or not specified: first counts the mass points, then assigns relative masses equally
    local mass_point_count = 0
    for mass_point, _ in pairs(jms_mass_point_table) do
        mass_point_count = mass_point_count + 1
    end
    for mass_point, _ in pairs(jms_mass_point_table) do
        -- This does the same as leaving all relative masses as 1 (or whatever equal amount)
        -- What makes a difference is setting them to different relative mass values: then, mass distribution is recalculated accordingly
        mass_point_relative_masses[mass_point] = 1/mass_point_count
    end
    return mass_point_relative_masses
end

function module.get_jms_mass_point_relative_volume_table(jms_mass_point_table)
    local mass_point_relative_volumes = {}
	local mass_point_volumes = {}
	local total_volume = 0
	for mass_point_index, mass_point in pairs(jms_mass_point_table) do
		mass_point_volumes[mass_point_index] = 4/3 * math.pi * mass_point.radius ^ 3
		total_volume = total_volume + mass_point_volumes[mass_point_index]
	end
	for mass_point_index, mass_point_volume in pairs(mass_point_volumes) do
		mass_point_relative_volumes[mass_point_index] = mass_point_volume/total_volume
	end
	return mass_point_relative_volumes
end

function module.get_jms_mass_point_transformation_matrix(mass_point, jms_mass_point_table, jms_node_table)
	local parent_node = jms_mass_point_table[mass_point].parent_node
	local parent_node_transformation_matrix = module.get_jms_node_transformation_matrix(parent_node, jms_node_table)
	local relative_translation_vector3d = module.Vector3D(
        jms_mass_point_table[mass_point].relative_translation_vector[1], 
        jms_mass_point_table[mass_point].relative_translation_vector[2], 
        jms_mass_point_table[mass_point].relative_translation_vector[3]
    )
	local relative_rotation_quaternion = module.Quaternion(
        -- (Sign inverted for "w" term to match the right-handed frame of reference of 3DS Max)
        -- Reminder: this decision has been reversed: Halo and 3DS Max use inverse systems of reference (one is right handed, the other left handed)
        --           now, the sign of "w" is left untouched, not negative (so not inverted)
        -- The reason behind this was that this sign was inverting the rotations of mass points, affecting their "up" and "forward" vectors, now it's fine
        -- I think the issue was caused by ignoring that mass point rotations are relative to parent node rotations, or they are specified as negative in the JMS file, something along those lines 
        jms_mass_point_table[mass_point].relative_rotation_quaternion[4],
        jms_mass_point_table[mass_point].relative_rotation_quaternion[1], 
        jms_mass_point_table[mass_point].relative_rotation_quaternion[2], 
        jms_mass_point_table[mass_point].relative_rotation_quaternion[3]
    )
	local relative_rotation_matrix = module.RotationMatrix3D(relative_rotation_quaternion)
	local transformation_matrix = module.TransformationMatrix(relative_translation_vector3d, relative_rotation_matrix)
	return module.apply_transform(parent_node_transformation_matrix, transformation_matrix)
end

function module.get_jms_node_transformation_matrix(node, jms_node_table)
	local parent = module.get_parent_jms_node_index(node, jms_node_table)
	local relative_translation_vector3d = module.Vector3D(
        jms_node_table[node].relative_translation_vector[1], 
        jms_node_table[node].relative_translation_vector[2], 
        jms_node_table[node].relative_translation_vector[3]
    )
	local relative_rotation_quaternion = module.Quaternion(
        -- Sign inverted on term "w" to match the right-handed frame of reference of 3DS Max
        -- TODO: test reversing this too to match Halo's frame of reference rather than 3DS Max's (by removing the negative sign). Nvm, this is fine as it is right now.
        -jms_node_table[node].relative_rotation_quaternion[4], 
        jms_node_table[node].relative_rotation_quaternion[1], 
        jms_node_table[node].relative_rotation_quaternion[2], 
        jms_node_table[node].relative_rotation_quaternion[3]
    )
	local relative_rotation_matrix = module.RotationMatrix3D(relative_rotation_quaternion)
	local transformation_matrix = module.TransformationMatrix(relative_translation_vector3d, relative_rotation_matrix)
	if parent == -1 then
		return transformation_matrix
	end
    -- Solves recursively
	return module.apply_transform(module.get_jms_node_transformation_matrix(parent, jms_node_table), transformation_matrix)
end

function module.apply_transform(transformation_matrix_a, transformation_matrix_b)
    -- Applies transform B onto transformation matrix A (multiplies matrix A by matrix B, in that order; in matrix multiplication, order matters)
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
                -- Does the sum of products for each term
				element = element + transformation_matrix_a[row][product] * transformation_matrix_b[product][column]
			end
			new_transformation_matrix[row][column] = element
		end
	end
	return new_transformation_matrix
end

function module.get_parent_jms_node_index(argument_node, jms_node_table)
    -- The parent node of any given node only knows its first child node, even though it can have many more child nodes
    -- So, to find out the parent node of any given node, even if it is not the first child node, is: find the argument node's first sibling node first
    if argument_node == 0 then
        -- The argument node is the root node: has no parent
        return -1
    end
    local first_sibling_node = argument_node
    local node_counter = 0
    local first_child_node
    local next_sibling_node
    -- The algorithm starts guessing that the argument node is the first sibling node
    -- If it is not, then it runs the loop again, this time guessing that the previous sibling node is the first sibling node
    -- The loop stops when "first_sibling_node" doesn't find a previous sibling
    -- Therefore, the parent node recognizes the first sibling node as its first child node (and also the argument node)
    repeat
        first_child_node = jms_node_table[node_counter].first_child_node
        next_sibling_node = jms_node_table[node_counter].next_sibling_node
        if next_sibling_node == first_sibling_node then
            first_sibling_node = node_counter
            -- Restarts the loop: this is set to -1 so it turns into "node_counter = 0" after reaching end of block, accounts for the loop increment
            node_counter = -1
        end
        node_counter = node_counter + 1
    until first_child_node == first_sibling_node
    -- This is adjusted to "node_counter - 1" to account for the loop exit increment
    return node_counter - 1
end

function module.jms_units_to_world_units(x)
    -- Note that this calculation will be correct only for first order terms (not squared, cubed of otherwise raised to a power other than 1)
    -- For instance, to convert terms expressed in squared JMS units, this function must be called twice on the operand to return squared world units
    local world_units
    if type(x) == "table" then
        -- This function now returns a new table instead of modifying the argument table
        -- (tables are pass by reference and I wanted these functions to return new objects only, not overwrite the original ones)
        local new_table = {}
        for k, v in pairs(x) do
            new_table[k] = module.jms_units_to_world_units(v)
        end
        return new_table
    end
    -- 1 Halo world unit = 100 JMS units = 10 ft = 3.048 m
    world_units = x/100
    return world_units
end

function module.TransformationMatrix(position_vector, rotation_matrix)
    -- Position and rotation can be obtained from a transformation matrix
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

function module.RotationMatrix3D(quaternion)
	local matrix = {
	    {0, 0, 0},
	    {0, 0, 0},
	    {0, 0, 0}
    }
	matrix[1][1] = quaternion.w ^ 2 + quaternion.x ^ 2 - quaternion.y ^ 2 - quaternion.z ^ 2 -- Alternatively: 1 - 2 * quaternion.y ^ 2 - 2 * quaternion.z ^ 2
	matrix[1][2] = 2 * quaternion.x * quaternion.y - 2 * quaternion.w * quaternion.z
	matrix[1][3] = 2 * quaternion.x * quaternion.z + 2 * quaternion.w * quaternion.y
	matrix[2][1] = 2 * quaternion.x * quaternion.y + 2 * quaternion.w * quaternion.z
	matrix[2][2] = quaternion.w ^ 2 - quaternion.x ^ 2 + quaternion.y ^ 2 - quaternion.z ^ 2 -- Alternatively: 1 - 2 * quaternion.x ^ 2 - 2 * quaternion.z ^ 2
	matrix[2][3] = 2 * quaternion.y * quaternion.z - 2 * quaternion.w * quaternion.x
	matrix[3][1] = 2 * quaternion.x * quaternion.z - 2 * quaternion.w * quaternion.y
	matrix[3][2] = 2 * quaternion.y * quaternion.z + 2 * quaternion.w * quaternion.x
	matrix[3][3] = quaternion.w ^ 2 - quaternion.x ^ 2 - quaternion.y ^ 2 + quaternion.z ^ 2 -- Alternatively: 1 - 2 * quaternion.x ^ 2 - 2 * quaternion.y ^ 2
	return matrix
end

function module.Quaternion(w, x, y, z)
    local quaternion = {}
    quaternion.w = w
    quaternion.x = x
    quaternion.y = y
    quaternion.z = z
    return quaternion
end

function module.Vector3D(x, y, z)
    -- I wanted to name this "3DVector" but function (and variable?) names cannot start with numbers
    local vector = {}
    vector.x = x
    vector.y = y
    vector.z = z
    return vector
end

return module