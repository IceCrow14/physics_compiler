-- Physics compiler new main file (On Windows, call this using launcher.cmd! Otherwise, relative paths will fail and everything will break)
-- * the root directory is accessible through system environment variable "root_directory" (includes the trailing slash)
-- * The goal is to create a system that is compatible with both Linux and Windows now, for the time being, I will use this file to run tests
-- * It seems I can grab the srlua from the LuaDist GitHub archive! For each OS variation! I may replace my current srlua dependency with each OS's srlua variant
-- * dkjson's JSON "keyorder" applies in nested tables too

local new_system_utilities = require("new_system_utilities")
local new_extractor = require("new_extractor")
local new_calculator = require("new_calculator")
local new_parser = require("new_parser")
local new_exporter = require("new_exporter")
local new_setup_pmps = require("new_setup_pmps")

local dkjson = require("lib/dkjson/dkjson")

-- TODO: arguments that create new types, modify existing types, and restore original types, etc... Will come later
-- TODO: push this somewhere else... Also, the color text codes are platform-dependent, as far as I know... 
function help_message(signal)
    local message = [[
Physics compiler

Usage: launcher.cmd [options] <type> <jms_path> <physics_path>

Options:
  -h                 Shows this help message
  -s                 Run interactive mode to setup paths and settings
  -m                 Mass value (overrides the mass value from the vehicle type properties)
  -i                 Invader-edit path
  -t                 Tags directory

Arguments:
  - type               Vehicle type from the "types" folder
  - jms_path           JMS source file path and extension
  - physics_path       Output tag file path and extension
]]
    if signal == "no_settings_file" then
        message = message..[[ [33m
WARNING: settings.json file not found, if this is your first time running this application, 
         start over using option -s to enable interactive mode and set up your environment, 
         you will be required to provide valid paths to use this program. [0m
]]
        return message
    end
    return message
end

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
-- TODO: I put these here because I want an initial check that asks the user to configure paths using -s mode on a first run basis
-- And print a special colored message asking them to do that when paths haven't been configured
-- Or rather... TODO: default to the "help" or "no arguments" mode until settings are defined
local settings = new_system_utilities.import_settings()
local is_help_mode
local is_setup_mode
local mass
local invader_edit_path
local tags_directory
local data_directory
local type_name
local jms_path
local tag_path
local properties
local type_table

-- Since Lua doesn't have native optables support, I had to handle the argument logic myself
for k, v in pairs(arg) do
    if #arg == 0 then
        is_help_mode = true
        break
    end
    if v == "-h" then
        is_help_mode = true
        break
    end
    if v == "-s" then
        is_setup_mode = true
        break
    end
    -- This check must go after the -s option check, or it will block it and prevent the user from running it
    if not settings then
        is_help_mode = true
        break
    end
    if v == "-m" then
        -- This optional parameter allows passing a custom mass, but why? Because mass affects all inertia and mass distribution calculations
        mass = tonumber(arg[k + 1])
        if not mass then
            print("error: invalid -m argument")
            return 1
        end
    end
    if v == "-i" then
        invader_edit_path = arg[k + 1]
        if not invader_edit_path then
            print("error: invalid -i argument")
            return 1
        end
        if not new_system_utilities.is_valid_path(invader_edit_path) then
            print("error: invalid -i argument (file does not exist)")
            return 1
        end
        -- TODO: maybe add a last check to confirm that the file is accessible (or implement in the system utilities module?)
    end
    if v == "-t" then
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
    if #arg < 3 then
        print("error: invalid or insufficient arguments to create physics tag")
        return 1
    end
end

-- ===== Help message mode =====
if is_help_mode then
    -- This returns "true" if the settings.json is absent; "no_settings_file" otherwise
    local no_settings_file = settings and true or "no_settings_file"
    print(help_message(no_settings_file))
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
-- TODO: refactor this and make it system-agnostic (and maybe push it to the system utilities module)
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