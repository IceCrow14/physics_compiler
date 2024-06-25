-- System utilities module

-- This module is intended to contain (extended) system specific utilities, including but not limited to perform file system checks
-- The purpose of pushing all system specific code to this module is to keep the main script and most other modules as system-agnostic as possible
-- (new_setup_pmps.lua)
-- (new_parser.lua)

local module = {}

local dkjson = require("lib\\dkjson\\dkjson")

function module.import_settings()
    local file_path = ".\\settings.json"
    if not module.is_valid_path(file_path) then
        -- print("error: failed to import settings from JSON file (invalid path)")
        return
    end
    local file = io.open(file_path)
    local content = file:read("*a")
    file:close()
    local settings = dkjson.decode(content)
    return settings
end

function module.export_settings_json(settings_json)
    -- Expects a single level settings table
    local file = io.open(".\\settings.json", "w")
    file:write(settings_json)
    io.close()
end

function module.get_json_files_in_dir(directory)
    -- Gets all file names found in the given directory, if valid
    -- In Windows, DIR with option /B enables bare mode, removes all heading information and summary from the output, leaving only the file names
    local files = {}
    if not module.is_valid_path(directory) then
        return
    end
    local file_list = io.popen("DIR /B "..module.add_quotes(directory))
    local line
    repeat
        if line and string.sub(line, -5, -1) == ".json" then
            local bare_file_name = string.sub(line, 1, -6)
            -- print(bare_file_name)
            table.insert(files, bare_file_name)
        end
        line = file_list:read("*l")
    until not line
    file_list:close()
    return files
end

function module.is_valid_path(path)
    -- TODO: tests whether the file/directory exists and, note: regardless of if it is accessible by the current user
    -- In Windows, DIR is used to test if a file/directory exists; >NUL 2>&1 are file descriptor redirections to suppress command output
    local file_exists = os.execute("CALL DIR "..module.add_quotes(path).." >NUL 2>&1")
    if (file_exists ~= 0) then
        return false
    end
    return true
end

function module.get_running_os()
    return "windows"
end

function module.add_quotes(x)
    -- TODO: I already defined this function in somewhere else... Maybe I can have that other module import the function from here
    return "\""..x.."\""
end

return module
