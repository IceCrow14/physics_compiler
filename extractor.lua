-- Extractor module

-- Extracts 3D geometry data from source JMS files, adapted to the latest standardized JMS exporter for 3DS Max/Blender 

-- TODO: (* verify compatibility on both *)
-- TODO: add an optional argument for "stacked get" functions so when this argument is present, they do not compute/extract anything, just return the next block start position
-- TODO: all these "get count" functions look very similar... Maybe I can merge them into a single one, taking a secondary parameter, like the start position?
-- TODO: i guess I could also replace all "block_size" constants with a call to get the length of the object definition? but not with #, that's only for numeric index tables...
-- TODO: make this system-agnostic (if applicable), and remove obsolete, discarded, and complete TODOs

local module = {}

function module.get_jms_mass_point_table(jms_path)
    local mass_points = {}
    local next_block_position
    local mass_point_count, start_position = module.get_jms_mass_point_count(jms_path)
    local mass_point
    local mass_point_index = 0
    local file = io.open(jms_path)
    local block_size = 6
    local line_counter = 1
    local line_count = block_size * mass_point_count
    file:seek("set", start_position)
    for line in file:lines() do
        if line_counter == line_count then
            -- This gets the position after the end of the last line of the node data block: this is, at the start of the region count block
            -- At this point, it's still necessary to process this line using the block counter (cannot call break here)
            -- (and is also the only place to get the next block position, this cannot be done after the next line is read by the iterator)
            next_block_position = file:seek()
        elseif line_counter > line_count then
            break
        end
        -- The reason behind starting this block_counter at "line_counter - 1 = 0" and not at "line_counter = 1" is so it starts at 0
        -- This way, the loop will catch the starting line as a new block: when "block_counter = 0" is applied the modulo operation, it returns 0
        -- This matches the pattern of all the following blocks, whose block_counter reaches "block_size + 1" and whose modulo is also 0 before resetting
        -- Also, each node must be added manually to the mass points table, since table.insert() starts adding elements from index 1, not from index 0
        local block_counter = (line_counter - 1) % block_size
        if (block_counter == 0) then
            mass_point = JmsMassPoint()
            mass_point.name = line
            mass_points[mass_point_index] = mass_point
            mass_point_index = mass_point_index + 1
        else
            if block_counter == 1 then
                mass_point.powered_mass_point = tonumber(line)
            elseif block_counter == 2 then
                mass_point.parent_node = tonumber(line)
            elseif block_counter == 3 then
                mass_point.relative_rotation_quaternion = module.line_to_vector(line)
            elseif block_counter == 4 then
                mass_point.relative_translation_vector = module.line_to_vector(line)
            elseif block_counter == 5 then
                mass_point.radius = tonumber(line)
            end
        end
        line_counter = line_counter + 1
    end
    file:close()
    return mass_points, next_block_position
end

function module.get_jms_mass_point_count(jms_path)
    -- * Expects a valid file path that can be opened by the running process: no bullshit and no baby guard mechanisms
    -- * A standalone file descriptor is necessary to seek and get file positions, to skip already scanned file chunks, unlike what io.lines() does
    local count
    local next_block_position
    local _, start_position = module.get_jms_material_table(jms_path)
    local file = io.open(jms_path)
    file:seek("set", start_position)
    count = file:read("*l")
    next_block_position = file:seek()
    file:close()
    return count, next_block_position
end

function module.get_jms_material_table(jms_path)
    -- * Expects a valid file path that can be opened by the running process: no bullshit and no baby guard mechanisms
    -- * A standalone file descriptor is necessary to seek and get file positions, to skip already scanned file chunks, unlike what io.lines() does
    local materials = {}
    local next_block_position
    local materials_count, start_position = module.get_jms_material_count(jms_path)
    local material
    local material_index = 0
    local file = io.open(jms_path)
    local block_size = 2
    local line_counter = 1
    local line_count = block_size * materials_count
    file:seek("set", start_position)
    for line in file:lines() do
        if line_counter == line_count then
            -- This gets the position after the end of the last line of the node data block: this is, at the start of the mass point count block
            -- At this point, it's still necessary to process this line using the block counter (cannot call break here)
            -- (and is also the only place to get the next block position, this cannot be done after the next line is read by the iterator)
            next_block_position = file:seek()
        elseif line_counter > line_count then
            break
        end
        -- The reason behind starting this block_counter at "line_counter - 1 = 0" and not at "line_counter = 1" is so it starts at 0
        -- This way, the loop will catch the starting line as a new block: when "block_counter = 0" is applied the modulo operation, it returns 0
        -- This matches the pattern of all the following blocks, whose block_counter reaches "block_size + 1" and whose modulo is also 0 before resetting
        -- Also, each material must be added manually to the materials table, since table.insert() starts adding elements from index 1, not from index 0
        local block_counter = (line_counter - 1) % block_size
        if (block_counter == 0) then
            material = JmsMaterial()
            material.name = line
            materials[material_index] = material
            material_index = material_index + 1
        else
            if block_counter == 1 then
                material.unknown = line
            end
        end
        line_counter = line_counter + 1
    end
    file:close()
    return materials, next_block_position
end

function module.get_jms_material_count(jms_path)
    -- * Expects a valid file path that can be opened by the running process: no bullshit and no baby guard mechanisms
    -- * A standalone file descriptor is necessary to seek and get file positions, to skip already scanned file chunks, unlike what io.lines() does
    local count
    local next_block_position
    local _, start_position = module.get_jms_node_table(jms_path)
    local file = io.open(jms_path)
    file:seek("set", start_position)
    count = file:read("*l")
    next_block_position = file:seek()
    file:close()
    return count, next_block_position
end

function module.get_jms_node_table(jms_path)
    -- * Expects a valid file path that can be opened by the running process: no bullshit and no baby guard mechanisms
    -- * A standalone file descriptor is necessary to seek and get file positions, to skip already scanned file chunks, unlike what io.lines() does
    --   When using the manual file:lines() iterator, it is necessary to close the file handle after using it, unlike with io.lines()
    -- Line_counter is relative to the start position after the node count block, not relative to the start of the file
    -- block_counter is a line counter relative to the start of each node block
    -- node_index holds the JMS node index starting from 0, as explained in the JmsNode object definition
    local nodes = {}
    local next_block_position
    local node_count, start_position = module.get_jms_node_count(jms_path)
    local node
    local node_index = 0
    local file = io.open(jms_path)
    local block_size = 5
    local line_counter = 1
    local line_count = block_size * node_count
    file:seek("set", start_position)
    for line in file:lines() do
        if line_counter == line_count then
            -- This gets the position after the end of the last line of the node data block: this is, at the start of the materials count block
            -- At this point, it's still necessary to process this line using the block counter (cannot call break here)
            -- (and is also the only place to get the next block position, this cannot be done after the next line is read by the iterator)
            next_block_position = file:seek()
        elseif line_counter > line_count then
            break
        end
        -- The reason behind starting this block_counter at "line_counter - 1 = 0" and not at "line_counter = 1" is so it starts at 0
        -- This way, the loop will catch the starting line as a new block: when "block_counter = 0" is applied the modulo operation, it returns 0
        -- This matches the pattern of all the following blocks, whose block_counter reaches "block_size + 1" and whose modulo is also 0 before resetting
        -- Also, each node must be added manually to the nodes table, since table.insert() starts adding elements from index 1, not from index 0
        local block_counter = (line_counter - 1) % block_size
        if (block_counter == 0) then
            node = JmsNode()
            node.name = line
            nodes[node_index] = node
            node_index = node_index + 1
        else
            if block_counter == 1 then
                node.first_child_node = tonumber(line)
            elseif block_counter == 2 then
                node.next_sibling_node = tonumber(line)
            elseif block_counter == 3 then
                -- This produces a 4-dimensional vector in "ijkw" notation, see JmsNode for details
                node.relative_rotation_quaternion = module.line_to_vector(line)
            elseif block_counter == 4 then
                -- This produces a 3-dimensional vector in "ijk" notation, see JmsNode for details
                node.relative_translation_vector = module.line_to_vector(line)
            end
        end
        line_counter = line_counter + 1
    end
    file:close()
    return nodes, next_block_position
end

function module.line_to_vector(line)
    -- \t is the escape sequence for horizontal tabs
    -- This function expects a line string conformed by a series of parsable numbers separated by tab characters, and adds each to the vector table
    local vector = {}
    local value_start
    local value_end
    local value
    for i = 1, #line do
        local character = string.sub(line, i, i)
        if character == "\t" then
            local previous_character = string.sub(line, i - 1, i - 1)
            if previous_character ~= "\t" then
                value_end = i - 1
            end
        else
            if not value_start then
                value_start = i
            end
            if i == #line then
                value_end = i
            end
        end
        if value_start and value_end then
            value = tonumber(string.sub(line, value_start, value_end))
            value_start = nil
            value_end = nil
            table.insert(vector, value)
        end
    end
    return vector
end

function module.get_jms_node_count(jms_path)
    -- * Expects a valid file path that can be opened by the running process: no bullshit and no baby guard mechanisms
    -- * A standalone file descriptor is necessary to seek and get file positions, to skip already scanned file chunks, unlike what io.lines() does
    --   When using the manual file:lines() iterator, it is necessary to close the file handle after using it, unlike with io.lines()
    local count
    local next_block_position
    local file = io.open(jms_path)
    local line_counter = 1
    for line in file:lines() do
        -- The third line of the file in the latest format contains the node count
        if line_counter == 3 then
            count = tonumber(line)
            next_block_position = file:seek()
            break
        end
        line_counter = line_counter + 1
    end
    file:close()
	return count, next_block_position
end

function JmsMassPoint()
    local mass_point = {}
    mass_point.name = ""
    mass_point.powered_mass_point = -1
    mass_point.parent_node = -1
    mass_point.relative_rotation_quaternion = {}
    mass_point.relative_translation_vector = {}
    mass_point.radius = 0
    return mass_point
end

function JmsMaterial()
    -- TODO: confirm that material blocks are comformed by just two lines: a name and a <none> line, I suppose
    --       this seems to be a common behavior in all JMS files I have seen (update this definition and its respective "get" function as necessary)
    local material = {}
    material.name = ""
    material.unknown = ""
    return material
end

function JmsNode()
    -- JMS node indeces start from 0, Lua indeces start from 1; at some points these must be converted back and forth
    -- Relative rotation quaternion is in "ijkw" notation, relative to the parent node
    -- Relative translation is in "ijk" notation, relative to the parent node (along the axes of the rotated frame of reference, not the world's)
    local node = {}
    node.name = ""
    node.first_child_node = 0
    node.next_sibling_node = 0
    node.relative_rotation_quaternion = {}
    node.relative_translation_vector = {}
    return node
end

return module