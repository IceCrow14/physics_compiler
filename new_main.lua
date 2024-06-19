-- Physics compiler new main file (On Windows, call using launcher.cmd! Otherwise, relative paths will fail and everything will break)
-- * the root directory is accessible through system environment variable "root_directory" (includes the trailing slash)
-- * The goal is to create a system that is compatible with both Linux and Windows now, for the time being, I will use this file to run tests
-- 
-- * It seems I can grab the srlua from the LuaDist GitHub archive! For each OS variation! I may replace my current srlua dependency with each OS's srlua variant
-- JSON "keyorder" applies in nested tables too (save keyorders, they're not written anywhere else!)
-- 
local new_system_utilities = require("new_system_utilities")
local new_extractor = require("new_extractor")
local new_calculator = require("new_calculator")
local new_parser = require("new_parser")
local new_exporter = require("new_exporter")
local new_setup_pmps = require("new_setup_pmps")

local dkjson = require("lib/dkjson/dkjson")

function request_input(prompt)
    io.write(prompt)
    return io.read("*l")
end

function setup()
    local settings = {}
    settings.invader_edit_path = ""
    settings.tags_directory = ""
    settings.data_directory = ""
    repeat
        settings.invader_edit_path = request_input("Enter invader-edit path: ")
    until new_system_utilities.is_valid_path(settings.invader_edit_path)
    repeat
        settings.tags_directory = request_input("Enter tags directory: ")
    until new_system_utilities.is_valid_path(settings.tags_directory)
    repeat
        settings.data_directory = request_input("Enter data directory: ")
    until new_system_utilities.is_valid_path(settings.data_directory)
    local settings_json = dkjson.encode(settings, {
        indent = true,
        keyorder = {
            "invader_edit_path",
            "tags_directory",
            "data_directory"
        }
    })
    new_system_utilities.export_settings_json(settings_json)
end

-- TODO: change this variable to "linux" in the Linux branch
local os_type = new_system_utilities.get_running_os()

local is_help_mode
local is_setup_mode

-- TODO: I put these here because I want an initial check that asks the user to configure paths using -s mode on a first run basis
-- And print a special colored message asking them to do that when paths haven't been configured
-- Or rather... TODO: default to the "help" or "no arguments" mode until settings are defined
local settings = new_system_utilities.import_settings()

local mass
local invader_edit_path
local tags_directory
local data_directory

local type_name
local jms_path
local tag_path

local properties
local type_table

print("Physics compiler")

for k, v in pairs(arg) do
    -- print("- "..k.." = "..v)

    -- TODO: Ok, here we go... Since Lua doesn't have native optables support, I have to handle the argument logic myself...
    -- physics_compiler [options] <type> <jms_path> <physics_path>
    -- no arguments: help message
    -- options:
    -- -h - Help message (ignores all arguments)
    -- -s - Setup paths interactively
    -- -m - Mass value (overrides type mass)
    -- -i - Invader path
    -- -t - tags directory
    -- TODO: arguments that create new types, modify existing types, and restore original types, etc... These will come later
    -- 
    -- IF RUNNING FOR A FIRST TIME, OR DON'T KNOW WHAT TO DO, SUGGEST RUNNING "physics_compiler -s"
    -- Also... Have these do nothing, unless all other arguments have been parsed correctly (or if invalid arguments are found/help message is called)

    if (#arg == 0) then
        -- print("<help message, no arguments>")
        is_help_mode = true
        break
        -- return 0
    end
    if (v == "-h") then
        -- print("<help message>")
        is_help_mode = true
        break
        -- return 0
    end
    if (v == "-s") then
        is_setup_mode = true
        break
    end
    if (v == "-m") then
        -- This optional parameter allows passing a custom mass, but why? Because mass affects all inertia and mass distribution calculations
        mass = tonumber(arg[k + 1])
        if not mass then
            print("error: invalid -m argument")
            return 1
        end
    end
    if (v == "-i") then
        invader_edit_path = arg[k + 1]
        if not invader_edit_path then
            print("error: invalid -i argument")
            return 1
        end
        if not new_system_utilities.is_valid_path(invader_edit_path) then
            print("error: invalid -i argument (file does not exist)")
            return 1
        end
        -- TODO: a last check to confirm that the file is accessible (or implement in the system utilities module?)
    end
    if (v == "-t") then
        tags_directory = arg[k + 1]
        if not tags_directory then
            print("error: invalid -t argument")
            return 1
        end
        if not new_system_utilities.is_valid_path(tags_directory) then
            print("error: invalid -t argument (directory does not exist)")
            return 1
        end
        -- TODO: a last check to confirm that the file is accessible (or implement in the system utilities module?)
    end
    -- At this point, the script expects a valid, sufficient argument set to create a tag, all help/interactive mode checks have been passed
    if (#arg < 3) then
        print("error: invalid or insufficient arguments to create physics tag")
        return 1
    end
end
-- ===== Help message mode =====
-- TODO?
if not settings then
    is_help_mode = true
end
if is_help_mode then

    -- TODO: here display the generic help message, and test if the "settings" file was found or not: if not, display the scary special first time message. Boooh, scary message
    -- * * * * *

    return 0
end

-- ===== Setup interactive mode =====
if is_setup_mode then
    setup()
    return 0
end

-- ===== Standard mode =====
type_name = arg[#arg -2]
jms_path = arg[#arg - 1]
tag_path = arg[#arg]

-- Type check
-- TODO: refactor this and make it system-agnostic
local available_types = new_system_utilities.get_json_files_in_dir(".\\types")
local is_valid_type = false
for i, v in ipairs(available_types) do
    if v == type_name then
        is_valid_type = true
        break
    end
end
if not is_valid_type then
    print("error: invalid type")
    return 1
end
local all_types = new_setup_pmps.import_types()
for k, v in pairs(all_types) do
    if k == type_name then
        type_table = v
        break
    end
end

-- Mass override check
if not mass then
    -- If mass not provided by the user, then uses the mass from the type definition
    mass = type_table.properties.mass
end


if not invader_edit_path then
    -- If not defined by the user from the arguments list, take it from the settings file
    invader_edit_path = settings.invader_edit_path
end
if not tags_directory then
    -- If not defined by the user from the arguments list, take it from the settings file
    invader_edit_path = settings.tags_directory
end

-- JMS file check
local jms_file = io.open(jms_path, "r")
if not jms_file then
    print("error: invalid JMS file")
    return 1
end

-- Physics path check
-- TODO: add a check here to protect the user from doing something dumb such as passing an invalid output tag path, and getting a flood of error messages from Invader

-- Properties
properties = type_table.properties
-- Oopsie here... I don't want shortened names anywhere other than absolutely necessary
powered_mass_points = type_table.pmps

-- ===== Extraction stage =====
local jms_nodes = new_extractor.get_jms_node_table(jms_path)
-- TODO: remove? JMS materials are irrelevant in this program
-- local jms_materials = new_extractor.get_jms_material_table(jms_path)
local jms_mass_points = new_extractor.get_jms_mass_point_table(jms_path)
local jms_mass_point_relative_masses = new_calculator.get_jms_mass_point_relative_mass_table(jms_mass_points, "equal")
-- TODO: rename function to "jms" center of mass vector, and arguments name where required
local jms_center_of_mass = new_calculator.get_center_of_mass_vector(jms_mass_point_relative_masses, jms_mass_points, jms_nodes)
-- ===== Processing stage =====
local mass_points = new_parser.get_mass_point_table(jms_mass_point_relative_masses, jms_mass_points, jms_nodes, mass)
local inertial_matrix = new_calculator.get_inertial_matrix(mass, jms_center_of_mass, jms_mass_point_relative_masses, jms_mass_points, jms_nodes)
local inverse_inertial_matrix = new_calculator.get_inverse_inertial_matrix(inertial_matrix)
local moments_vector = new_calculator.get_moments_vector(inertial_matrix)
-- ===== Final stage =====
local final_properties = new_exporter.FinalProperties(properties, jms_center_of_mass, moments_vector)
local final_inertial_matrices = new_exporter.FinalInertialMatrixAndInverse(inertial_matrix, inverse_inertial_matrix)
local final_powered_mass_points = new_exporter.FinalPoweredMassPoints(powered_mass_points)
local final_mass_points = new_exporter.FinalMassPoints(mass_points)
local create_tag_command = new_exporter.invader_create_tag_command(invader_edit_path, tags_directory, tag_path)
local fill_tag_commands = new_exporter.invader_fill_tag_command_list(invader_edit_path, tags_directory, tag_path, final_properties, final_inertial_matrices, final_powered_mass_points, final_mass_points)
new_exporter.export_tag(create_tag_command, fill_tag_commands, os_type)