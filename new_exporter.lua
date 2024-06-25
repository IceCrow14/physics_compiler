-- Exporter module

-- Handles export of generated physics data to the final physics tag file

-- Note: I resorted to format numbers as 6 decimal precision floats everywhere because using exponential notation seemed to yield wildly unequivalent values in Invader/Six Shooter

-- For my, and the user's sanity... Values are quoted automatically in Invader calls; quotes are not necessary in keys because spaces are represented by underscores

-- TODO: maybe add Invader as a Git dependency?... This would save plenty of issues, and let users have an "opt-out" option if they have their own installation of Invader

local module = {}

-- TODO: replace the imported module path and name when I rename it
local calculator = require("new_calculator")

function module.export_tag(create, fill, os_type)
    -- Expects "create" to be the Invader-edit create tag command, and likewise, expects "fill" to be the command list containing "insert" and "set" commands
    -- All these commands are expected to be system-agnostic: system-specific subroutines will handle calling them based on the running OS

    -- TODO: no, eff' it. I'll have separate functions for each OS, I don't want this to be overly intrusive and cause issues related to weird edge cases
    -- os.execute will return the status/exit code of each command: whichever option returns 0 was successful, and since these are mutually exclusive, they determine the running OS
    -- Adding "@" at the start suppresses the command itself from being displayed in the terminal, regardless of the OS
    -- (but since there is no system-agnostic way to redirect output to nowhere, the screen is cleared, well... )

    -- local is_linux = os.execute("@uname")
    -- local is_windows = os.execute("@ver")

    -- TODO: test both of these using the executables: both of them
    -- TODO: maybe add exit code in return statements, and pass it as the main command's exit code?
    if (os_type == "linux") then
        print("Exporting tag in Linux... ")
        -- Linux can run programs specified in quotes directly, unlike Windows, no funny makeup needed
        os.execute(create)
        for i, v in ipairs(fill) do
            os.execute(v)
        end
        return
    elseif (os_type == "windows") then
        -- In Windows, it is necessary to run Invader using CALL because this program will add quotes to the Invader executable path 
        -- (programs in quotes are not recognized as such, and do not run, unless run with CALL (in background), or with START (in new foreground) using tricky argument combinations)
        print("Exporting tag in Windows... ")
        os.execute("CALL "..create)
        for i, v in ipairs(fill) do
            os.execute("CALL "..v)
        end
        return
    end
    print("Attempt to call export_tag without specifying an OS... ")
    return
end

function module.invader_fill_tag_command_list(invader_edit_path, tags_directory, tag_path, final_properties, final_matrices, final_powered_mass_points, final_mass_points)
    -- TODO: fix the comments
    -- This function runs Invader multiple times, once for every tag field that is written to the tag
    -- This sacrifices memory in favor of compatibility on multiple OS's... Until I develop something more efficient, if ever necessary
    -- To call all the generated commands, it is necessary to use use an OS specific subroutine method
    -- tag_path is relative to the tags directory (it seems it can be also specified as an absolute path, or relative to the current directory)
    -- Structs must be created using "insert" commands before attempting to fill in tag data, this includes matrix blocks, PMP blocks, and mass point blocks
    -- Returns a standard numbered table that starts with index 1 and is iterable in ascending order with "ipairs()"

    local command_list = {}
    local command
    -- Properties
    for k, v in pairs(final_properties) do
        -- Properties do not contain nested fields, so their keys can be used right away, there's no need to calculate root keys for them
        module.get_invader_set_command_list(invader_edit_path, tags_directory, tag_path, k, v, command_list)
    end
    -- Inertial matrices
    -- (Get struct count)
    local matrix_count = 0
    for k, v in pairs(final_matrices) do
        -- This should be 2 all the time, the physics tag only accepts two structs in the "Inertial matrix and inverse" block
        matrix_count = matrix_count + 1
    end
    -- (Insert structs command)
    command = module.invader_insert_command(invader_edit_path, tags_directory, tag_path, "inertial_matrix_and_inverse", matrix_count)
    table.insert(command_list, command)
    -- (Set commands)
    for k, v in pairs(final_matrices) do
        local root_key = "inertial_matrix_and_inverse["..k.."].matrix"
        module.get_invader_set_command_list(invader_edit_path, tags_directory, tag_path, root_key, v, command_list)
    end
    -- Powered mass points
    -- (Get struct count)
    local powered_mass_point_count = 0
    for k, v in pairs(final_powered_mass_points) do
        powered_mass_point_count = powered_mass_point_count + 1
    end
    -- (Insert structs command)
    command = module.invader_insert_command(invader_edit_path, tags_directory, tag_path, "powered_mass_points", powered_mass_point_count)
    table.insert(command_list, command)
    -- (Set commands)
    for k, v in pairs(final_powered_mass_points) do
        local root_key = "powered_mass_points["..k.."]"
        module.get_invader_set_command_list(invader_edit_path, tags_directory, tag_path, root_key, v, command_list)
    end
    -- Mass points
    -- (Get struct count)
    local mass_point_count = 0
    for k, v in pairs(final_mass_points) do
        mass_point_count = mass_point_count + 1
    end
    -- (Insert structs command)
    command = module.invader_insert_command(invader_edit_path, tags_directory, tag_path, "mass_points", mass_point_count)
    table.insert(command_list, command)
    -- (Set commands)
    for k, v in pairs(final_mass_points) do
        local root_key = "mass_points["..k.."]"
        module.get_invader_set_command_list(invader_edit_path, tags_directory, tag_path, root_key, v, command_list)
    end
    return command_list
end

function module.get_invader_set_command_list(invader_edit_path, tags_directory, tag_path, key, value, destination)
    -- Takes an object or table of fields to be set with Invader-edit set commands (in argument "value")
    -- Expects all the self-explanatory arguments, in addition to a "destination" table where all commands originated from this function are inserted
    -- The purpose of this table is to collect all the commands, regardless of the nested table they come from, in a single place, so they can be accessed by a standard k/v loop
    local command
    if type(value) == "table" then
        local new_key
        for child_key, child_value in pairs(value) do
            new_key = key.."."..child_key
            module.get_invader_set_command_list(invader_edit_path, tags_directory, tag_path, new_key, child_value, destination)
        end
        return
    end
    command = add_quotes(invader_edit_path).." -t "..add_quotes(tags_directory).." -n -S "..key.." "..add_quotes(value).." "..add_quotes(tag_path)
    table.insert(destination, command)
    return
end

--[[function module.InvaderSetCommand(invader_edit_path, tags_directory, tag_path, key, value)
    -- TODO: deprecate and remove this shit
    -- TODO: maybe create an alternate recursive function that pushes the recursive commands to a provided table, instead or returning nested tables? 
    -- Creates an Invader-edit set command with no safeguards (-n -S)
    -- Is recursive, returns recursive tables containing commands for child keys (trees?) if the field (value) is a table
    local command
    if type(value) == "table" then
        local command_list = {}
        local new_key
        for child_key, child_value in pairs(value) do
            new_key = key.."."..child_key
            command = module.InvaderSetCommand(invader_edit_path, tags_directory, tag_path, new_key, child_value)
            table.insert(command_list, command)
        end
        return command_list
    end
    command = add_quotes(invader_edit_path).." -t "..add_quotes(tags_directory).." -n -S "..key.." "..add_quotes(value).." "..add_quotes(tag_path)
    return command
end]]

function module.invader_insert_command(invader_edit_path, tags_directory, tag_path, key, count)
    -- Returns an Invader-edit insert structs command, not recursive
    local command = add_quotes(invader_edit_path).." -t "..add_quotes(tags_directory).." -I "..key.." "..count.." end "..add_quotes(tag_path)
    return command
end

function module.invader_create_tag_command(invader_edit_path, tags_directory, tag_path)
    -- TODO: right now, the default is that this command overwrites the existing tag if it exists; address this and make it interactive, I guess. This is low priority, though
    -- * tag_path is relative to the tags directory; the "current directory" of the relative tags path can be referenced with "." even, or using absolute paths
    -- Note: this script contains the "subroutine" code only, this must be called by a subroutine as a CALL in Windows, or as a function in Linux (at least, in Bash)
    -- TODO: I won't bother fixing ugly paths here (nevermind! I will), let users sort it out by adding quotes when using path names with spaces. No. They still have to quote their stuff, but regardless, this is necessary
    local command = add_quotes(invader_edit_path).." -t "..add_quotes(tags_directory).." -N "..add_quotes(tag_path)
    return command
end

function add_quotes(x)
    -- TODO: add "module" prefix, and replace wherever this is called
    return "\""..x.."\""
end

function module.FinalMassPoints(mass_points)
    -- TODO: test out, and rename variables and iterators... Yes, it works, it seems
    -- Expects a mass point table (not a JMS mass point table)
    local final = {}
    for k, v in pairs(mass_points) do
        local final_mass_point = {}
        final_mass_point.name = v.name
        final_mass_point.powered_mass_point = string.format("%d", v.powered_mass_point)
        final_mass_point.model_node = string.format("%d", v.model_node)
        final_mass_point.flags = {}
        final_mass_point.flags.metallic = string.format("%d", v.flags.metallic == 1 and 1 or 0)
        final_mass_point.relative_mass = string.format("%.6f", v.relative_mass)
        final_mass_point.mass = string.format("%.6f", v.mass)
        final_mass_point.relative_density = string.format("%.6f", v.relative_density)
        final_mass_point.density = string.format("%.6f", v.density)
        final_mass_point.position = string.format("%.6f", v.position.x)..","..string.format("%.6f", v.position.y)..","..string.format("%.6f", v.position.z)
        final_mass_point.forward = string.format("%.6f", v.forward.x)..","..string.format("%.6f", v.forward.y)..","..string.format("%.6f", v.forward.z)
        final_mass_point.up = string.format("%.6f", v.up.x)..","..string.format("%.6f", v.up.y)..","..string.format("%.6f", v.up.z)
        final_mass_point.friction_type = v.friction_type
        final_mass_point.friction_parallel_scale = string.format("%.6f", v.friction_parallel_scale)
        final_mass_point.friction_perpendicular_scale = string.format("%.6f", v.friction_perpendicular_scale)
        final_mass_point.radius = string.format("%.6f", v.radius)
        final[k] = final_mass_point
    end
    return final
end

function module.FinalPoweredMassPoints(powered_mass_points)
    -- Expects a powered mass points table from a Type object
    local final_powered_mass_points = {}
    for powered_mass_point_index, powered_mass_point in pairs(powered_mass_points) do
        -- In Lua boolean comparisons, "or" returns the first operand that evaluates as "true"; and "and" returns the second operand if both operands evaluate as "true"
        -- Otherwise, when the comparison fails, returns "false", regardless or the operands
        -- In this context, flags cannot be evaluated as "flag and 1 or 0" because flag is expected to be 0 or 1, both of which evaluate as true, so the result string would always be 1
        local final_powered_mass_point = {}
        final_powered_mass_point.name = powered_mass_point.name
        final_powered_mass_point.flags = {}
        final_powered_mass_point.flags.ground_friction = string.format("%d", powered_mass_point.flags.ground_friction == 1 and 1 or 0)
        final_powered_mass_point.flags.water_friction = string.format("%d", powered_mass_point.flags.water_friction == 1 and 1 or 0)
        final_powered_mass_point.flags.air_friction = string.format("%d", powered_mass_point.flags.air_friction == 1 and 1 or 0)
        final_powered_mass_point.flags.water_lift = string.format("%d", powered_mass_point.flags.water_lif == 1 and 1 or 0)
        final_powered_mass_point.flags.air_lift = string.format("%d", powered_mass_point.flags.air_lift == 1 and 1 or 0)
        final_powered_mass_point.flags.thrust = string.format("%d", powered_mass_point.flags.thrust == 1 and 1 or 0)
        final_powered_mass_point.flags.antigrav = string.format("%d", powered_mass_point.flags.antigrav == 1 and 1 or 0)
        final_powered_mass_point.antigrav_strength = string.format("%.6f", powered_mass_point.antigrav_strength)
        final_powered_mass_point.antigrav_offset = string.format("%.6f", powered_mass_point.antigrav_offset)
        final_powered_mass_point.antigrav_height = string.format("%.6f", powered_mass_point.antigrav_height)
        final_powered_mass_point.antigrav_damp_fraction = string.format("%.6f", powered_mass_point.antigrav_damp_fraction)
        final_powered_mass_point.antigrav_normal_k1 = string.format("%.6f", powered_mass_point.antigrav_normal_k1)
        final_powered_mass_point.antigrav_normal_k0 = string.format("%.6f", powered_mass_point.antigrav_normal_k0)
        final_powered_mass_points[powered_mass_point_index] = final_powered_mass_point
    end
    return final_powered_mass_points
end

function module.FinalInertialMatrixAndInverse(inertial_matrix, inverse_inertial_matrix)
    -- TODO: This could be abstracted to a function called twice with different arguments
    local final_matrices = {}
    final_matrices[0] = {}
    for row_index, row in ipairs(inertial_matrix) do
        final_matrices[0][row_index] = {}
        for column_index, column in ipairs(inertial_matrix) do
            final_matrices[0][row_index][column_index] = string.format("%.6f", inertial_matrix[row_index][column_index])
        end
        final_matrices[0][row_index] = table.concat(final_matrices[0][row_index], ",")
    end
    final_matrices[0] = table.concat(final_matrices[0], ",")
    final_matrices[1] = {}
    for row_index, row in ipairs(inverse_inertial_matrix) do
        final_matrices[1][row_index] = {}
        for column_index, column in ipairs(inverse_inertial_matrix) do
            final_matrices[1][row_index][column_index] = string.format("%.6f", inverse_inertial_matrix[row_index][column_index])
        end
        final_matrices[1][row_index] = table.concat(final_matrices[1][row_index], ",")
    end
    final_matrices[1] = table.concat(final_matrices[1], ",")
    return final_matrices
end

function module.FinalProperties(properties, center_of_mass, moments_vector, override_mass)
    -- Expects a properties table (as in, a presets table) from a Type object, a center of mass vector, and a moments vector
    -- Note: expects a (in-memory?, no, not anymore, unless... Maybe, unless mass and any other properties are manipulated before daring touch anything from the calculator module) properties table, because there may be "parsed" parameters that affect global properties in mass point names... No. Forbid (some of) them, they would cause a mess
    -- Returns a table of strings ready to export to Invader, to the global properties (unnamed) section of the physics tag
    -- Note: space or tab separated values will not be quoted automatically, this must be done at the command line level function that calls Invader
    local final_properties = {}
    final_properties.radius = string.format("%.6f", properties.radius)
	final_properties.moment_scale = string.format("%.6f", properties.moment_scale)
    -- TODO: fix this, make sure that override mass effectively replaces the properties mass value when specified, and add comments explaining this
	final_properties.mass = (override_mass and string.format("%.6f", override_mass)) or string.format("%.6f", properties.mass)
    -- * center_of_mass is geometry dependent
    final_properties.center_of_mass = {}
    for axis, value in pairs(center_of_mass) do
        -- The center of mass is not precalculated to world units because it is used to calculate the inertial and inverse matrices in JMS units: this is the only exception in this file
        final_properties.center_of_mass[axis] = string.format("%.6f", calculator.jms_units_to_world_units(value))
    end
    -- Vector string components are concatenated manually because table.concat doesn't work here, since it looks only for numbered items in the target table, not string-key ones
    -- This is disgusting, but gets the job done
    final_properties.center_of_mass = string.format("%.6f", final_properties.center_of_mass.x)..","..string.format("%.6f", final_properties.center_of_mass.y)..","..string.format("%.6f", final_properties.center_of_mass.z)
	final_properties.density = string.format("%.6f", properties.density)
	final_properties.gravity_scale = string.format("%.6f", properties.gravity_scale)
	final_properties.ground_friction = string.format("%.6f", properties.ground_friction)
	final_properties.ground_depth = string.format("%.6f", properties.ground_depth)
	final_properties.ground_damp_fraction = string.format("%.6f", properties.ground_damp_fraction)
	final_properties.ground_normal_k1 = string.format("%.6f", properties.ground_normal_k1)
	final_properties.ground_normal_k0 = string.format("%.6f", properties.ground_normal_k0)
	final_properties.water_friction = string.format("%.6f", properties.water_friction)
	final_properties.water_depth = string.format("%.6f", properties.water_depth)
	final_properties.water_density = string.format("%.6f", properties.water_density)
	final_properties.air_friction = string.format("%.6f", properties.air_friction)
    -- These are individual fields, unlike matrices and the center of mass
    -- * xx_moment is geometry dependent
	-- * yy_moment is geometry dependent
	-- * zz_moment is geometry dependent
    final_properties.xx_moment = string.format("%.6f", moments_vector.x)
    final_properties.yy_moment = string.format("%.6f", moments_vector.y)
    final_properties.zz_moment = string.format("%.6f", moments_vector.z)
    return final_properties
end

return module