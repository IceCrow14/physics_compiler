-- Parser module

-- Generates tag-structured mass points from JMS mass points

local module = {}

-- TODO: replace the imported module path and name when I rename it
local calculator = require("new_calculator")

function module.get_mass_point_table(jms_mass_point_relative_mass_table, jms_mass_point_table, jms_node_table, total_mass)
    local mass_point_table = {}

    -- TODO: make certain parameters optional: mass, density... That can be retrieved from a presets list
    -- TODO: add code that parses individual physics parameters, or "engine" mass points...

    -- TODO: ...
    local mass_point
    local mass_point_transformation_matrix
    for jms_mass_point_index, jms_mass_point in pairs(jms_mass_point_table) do
        mass_point = module.MassPoint()
        mass_point_transformation_matrix = calculator.get_jms_mass_point_transformation_matrix(jms_mass_point_index, jms_mass_point_table, jms_node_table)
        mass_point_table[jms_mass_point_index] = mass_point
        -- TODO: the name with "custom flags" must be tweaked, I guess? Or keep it intact for reversability with the modelling software?
        mass_point.name = jms_mass_point.name
        -- powered_mass_point (this is included in the JMS but always -1, so not valid, must be parsed from the name)
        mass_point.model_node = jms_mass_point.parent_node
        -- flags: metallic (parsed from name)
        -- TODO: relative mass/mass (taken from calculator, and possibly, optional to be parsed from name) (note: no, forbid mass overrides, these would mess with other calculations)
        mass_point.relative_mass = jms_mass_point_relative_mass_table[jms_mass_point_index]
        mass_point.mass = mass_point.relative_mass * total_mass
        -- TODO: relative density/density (possibly optional to be parsed from name, when relative mass is not)
        
        -- position/forward/up taken from the mass point transformation matrix
        mass_point.position.x = mass_point_transformation_matrix[1][4]
        mass_point.position.y = mass_point_transformation_matrix[2][4]
        mass_point.position.z = mass_point_transformation_matrix[3][4]
        mass_point.position = calculator.jms_units_to_world_units(mass_point.position)
        -- TODO: verify these in an unusual test case, with rotated mass points (they should be correct, though) (these are unit-less unit vectors, funny)
        mass_point.forward.x = mass_point_transformation_matrix[1][1]
        mass_point.forward.y = mass_point_transformation_matrix[1][2]
        mass_point.forward.z = mass_point_transformation_matrix[1][3]
        mass_point.up.x = mass_point_transformation_matrix[3][1]
        mass_point.up.y = mass_point_transformation_matrix[3][2]
        mass_point.up.z = mass_point_transformation_matrix[3][3]
        -- friction type (parsed from name?)
        -- friction scales (parsed from name?)
        mass_point.radius = calculator.jms_units_to_world_units(jms_mass_point.radius)
    end

    return mass_point_table
end

function module.Tire(variant)
    -- TODO: finish this
    local engine = {}
    engine.powered_mass_point_name = ""
    -- engine
    return engine
end

function module.Engine()
    -- TODO: remove or rework as necessary, and finish, too
    -- An engine is a mass point object with all its fields cleared as "nil", excepting fields that are meant to be changed on a mass point
    local engine = module.MassPoint()

    return engine
end

function module.MassPoint()
    -- This function produces a MassPoint object that matches the structure from the "Mass Points" block of the physics tag, unlike JmsMassPoint
    -- powered_mass_point = -1 defaults to no assigned powered mass point (meaning this mass point doesn't produce movement)
    -- model_node = 0 defaults to this mass point being linked to the root node, also known as the root frame, or "frame root"
    -- flags.metallic = 0 (unchecked bit) defaults to this mass point not being metallic (whatever that means, maybe related to projectile magnetism)
    -- TODO: ...
    -- friction_type = "point" defaults to the mass point acting as a sphere facing friction from all directions (along the X, Y and Z axes)
    -- friction scales = 1 default to acting as rigid spheres that do not slide by themselves (these scales are lower in tire and tank tread mass points)
    -- TODO: ...
    local mass_point = {}
    mass_point.name = ""
    mass_point.powered_mass_point = -1
    mass_point.model_node = 0
    mass_point.flags = {}
    mass_point.flags.metallic = 0
    mass_point.relative_mass = 1
    mass_point.mass = 0
    mass_point.relative_density = 1
    mass_point.density = 0
    mass_point.position = calculator.Vector3D(0, 0, 0)
    mass_point.forward = calculator.Vector3D(1, 0, 0)
    mass_point.up = calculator.Vector3D(0, 0, 1)
    mass_point.friction_type = "point"
    mass_point.friction_parallel_scale = 1
    mass_point.friction_perpendicular_scale = 1
    mass_point.radius = 0
    return mass_point
end

return module