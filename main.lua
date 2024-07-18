-- Physics compiler new main file (On Windows, call this using launcher.cmd! Otherwise, relative paths will fail and everything will break)
-- On Windows only, the root directory is accessible through local environment variable "root_directory" (includes the trailing slash)
-- * The goal is to create a system that is compatible with both Linux and Windows now, for the time being, I will use this file to run tests
-- * I may replace my current srlua dependency with each OS's srlua variant
-- * dkjson's JSON "keyorder" applies in nested tables too
-- TODO: refresh Git files, remove all cached files (because some of them show up as duplicate in the root folder) and add the current ones again
-- TODO: adapt the system to also ask for a data folder in setup, and provide an alternative to override the data location via command-line, and... Pass it to invader
--       ... and, add special parsing code to locate and handle the "physics" folder in the data folder
-- TODO: I cannot test Linux functionality from WSL by calling the Lua executable for Windows, I need to use a Unix-based Lua executable
-- TODO: add options to restore standard engine and type definitions
-- TODO: add support for relative paths from data folder files (invader-edit in particular has no support for setting a custom data directory using -d )

-- TODO: add logic to turn convert relative settings paths into absolute settings paths: this is intended to allow users to enter paths relative to the tags and data folders, respectively
--       the alternative is to disallow absolute paths in JMS paths and output tag paths... By appending root paths always

-- TODO: arguments that create new types, modify existing types, and restore original types, etc... Will come later

-- Lua is smart enough to figure out slashes in imported module paths without human intervention, and also because "generate_path()" cannot be called here
-- All module paths are relative to the root folder: this application expects the launcher script to change directory into the project folder, regardless of the starting shell location
local system_utilities = require("./system_utilities")
local extractor = require("./extractor")
local calculator = require("./calculator")
local parser = require("./parser")
local exporter = require("./exporter")
local setup_pmps = require("./setup_pmps")
local dkjson = require("./lib/dkjson/dkjson")

function get_help_message(signal, help_message, no_settings_message)
    local message = help_message
    if signal == "no_settings_file" then
        message = message.."\n\n"..system_utilities.color_text(no_settings_message, "yellow")
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
    until system_utilities.is_valid_path(settings.invader_edit_path)
    repeat
        settings.tags_directory = request_input("Enter tags directory: ")
    until system_utilities.is_valid_path(settings.tags_directory)
    repeat
        settings.data_directory = request_input("Enter data directory: ")
    until system_utilities.is_valid_path(settings.data_directory)
    local settings_json = dkjson.encode(settings, {
        indent = true,
        keyorder = {
            "invader_edit_path",
            "tags_directory",
            "data_directory"
        }
    })
    system_utilities.export_settings_json(settings_json)
end

-- ===== Startup =====
-- I put these variables here because I want an initial check that asks the user to configure paths using "-s" mode on a first run basis
-- And print a special message asking them to do that when paths haven't been configured
-- The positioning of the closing brackets of these multi-line strings is intentional: this is intended to prevent the script from showing duplicate new line breaks
local help_message = [[
Physics compiler

Usage: launcher[.cmd] [options] <type> <jms_path> <physics_path>

Options:
  -h                 Shows this help message
  -s                 Run interactive mode to setup paths and settings
  -m                 Mass value (overrides the mass value from the vehicle type properties)
  -i                 Invader-edit path
  -d                 Data directory
  -t                 Tags directory

Arguments:
  - type               Vehicle type from the "types" folder
  - jms_path           JMS source file path and extension
  - physics_path       Output tag file path and extension]]
local no_settings_message = [[
WARNING: settings.json file not found, if this is your first time running this application, 
         start over using option -s to enable interactive mode and set up your environment, 
         you will be required to provide valid paths to use this program.]]
local is_windows_host = system_utilities.is_windows_host()
local settings = system_utilities.import_settings()
local is_help_mode
local is_setup_mode
local mass
local settings_paths = {}
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

        settings_paths.invader_edit_path = arg[k + 1]

        local invader_edit_path = arg[k + 1]
        if not invader_edit_path then
            print("error: invalid -i argument")
            return 1
        end
        if not system_utilities.is_valid_path(invader_edit_path) then
            print("error: invalid -i argument (file does not exist)")
            return 1
        end
        -- TODO: maybe add a last check to confirm that the file is accessible (or implement in the system utilities module?)
    end
    if v == "-d" then

        settings_paths.data_directory = arg[k + 1]

        local data_directory = arg[k + 1]
        if not data_directory then
            print("error: invalid -d argument")
            return 1
        end
        if not system_utilities.is_valid_path(data_directory) then
            print("error: invalid -d argument (directory does not exist)")
            return 1
        end
        -- TODO: maybe add a last check to confirm that the file is accessible (or implement in the system utilities module?)
    end
    if v == "-t" then

        settings_paths.tags_directory = arg[k + 1]

        local tags_directory = arg[k + 1]
        if not tags_directory then
            print("error: invalid -t argument")
            return 1
        end
        if not system_utilities.is_valid_path(tags_directory) then
            print("error: invalid -t argument (directory does not exist)")
            return 1
        end
        -- TODO: maybe add a last check to confirm that the file is accessible (or implement in the system utilities module?)
    end
    -- At this point, the script expects a valid, sufficient argument set to create a tag, all help or interactive mode checks have been passed
    if #arg < 3 then
        print("error: invalid or insufficient arguments to create physics tag")
        return 1
    end
end

-- ===== Help message mode =====
if is_help_mode then
    -- This returns "true" if the settings.json is absent; "no_settings_file" otherwise
    local no_settings_file = settings and true or "no_settings_file"
    print(get_help_message(no_settings_file, help_message, no_settings_message))
    return 0
end

-- ===== Setup interactive mode =====
if is_setup_mode then
    setup()
    return 0
end

-- ===== Standard mode =====
local available_type_names = system_utilities.get_json_files_in_dir(system_utilities.generate_path("./types"))
local available_types
local available_engines = parser.import_engines()
local is_valid_type = false

type_name = arg[#arg -2]
jms_path = arg[#arg - 1]
tag_path = arg[#arg]

-- Type check
for _, v in ipairs(available_type_names) do
    if v == type_name then
        is_valid_type = true
        break
    end
end
if not is_valid_type then
    print("error: invalid type")
    return 1
end
available_types = setup_pmps.import_types()
-- The "available types" check validates that the Type name provided by the user points to an existing Type
type_table = available_types[type_name]

-- Mass override check
if not mass then
    -- If a mass value is not explicitly provided by the user, then uses the mass from the type definition
    mass = type_table.properties.mass
end
-- If these are not defined by the user from the arguments list, take them from the settings file
if not settings_paths.invader_edit_path then
    settings_paths.invader_edit_path = settings.invader_edit_path
end
if not settings_paths.data_directory then
    settings_paths.data_directory = settings.data_directory
end
if not settings_paths.tags_directory then
    settings_paths.tags_directory = settings.tags_directory
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
local jms_nodes = extractor.get_jms_node_table(jms_path)
-- We don't save JMS material information because it is irrelevant to this program: if this changes in the future, this is the place to get them
-- local jms_materials = extractor.get_jms_material_table(jms_path)
local jms_mass_points = extractor.get_jms_mass_point_table(jms_path)
local jms_mass_point_relative_masses = calculator.get_jms_mass_point_relative_mass_table(jms_mass_points, "equal")
-- TODO: rename function to "jms" center of mass vector, and arguments name where required
local jms_center_of_mass = calculator.get_center_of_mass_vector(jms_mass_point_relative_masses, jms_mass_points, jms_nodes)
-- ===== Processing stage =====
local mass_points = parser.get_mass_point_table(jms_mass_point_relative_masses, jms_mass_points, jms_nodes, mass, available_engines, type_table.pmps)
local inertial_matrix = calculator.get_inertial_matrix(mass, jms_center_of_mass, jms_mass_point_relative_masses, jms_mass_points, jms_nodes)
local inverse_inertial_matrix = calculator.get_inverse_inertial_matrix(inertial_matrix)
local moments_vector = calculator.get_moments_vector(inertial_matrix)
-- ===== Final stage =====
local final_properties = exporter.FinalProperties(properties, jms_center_of_mass, moments_vector, mass)
local final_inertial_matrices = exporter.FinalInertialMatrixAndInverse(inertial_matrix, inverse_inertial_matrix)
local final_powered_mass_points = exporter.FinalPoweredMassPoints(powered_mass_points)
local final_mass_points = exporter.FinalMassPoints(mass_points)
local create_tag_command = exporter.invader_create_tag_command(settings_paths, tag_path)
local fill_tag_commands = exporter.invader_fill_tag_command_list(settings_paths, tag_path, final_properties, final_inertial_matrices, final_powered_mass_points, final_mass_points)

exporter.export_tag(create_tag_command, fill_tag_commands, is_windows_host)