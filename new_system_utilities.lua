-- System utilities module

-- This module is intended to contain (extended) system specific utilities, including but not limited to perform file system checks
-- The purpose of pushing all system specific code to this module is to keep the main script and most other modules as system-agnostic as possible
-- (new_setup_pmps.lua)
-- (new_parser.lua)

local module = {}

local dkjson = require("./lib/dkjson/dkjson")

function module.generate_path(...)
    -- Takes a variable argument list, expects the arguments to be a sequence of strings; components for a file or directory path (include separators as components)
    -- Produces a valid, adapted file or directory path according to the host OS, returns "nil" on failure
    local arguments = {...}
    local path = ""
    local is_windows_host = module.is_windows_host()
    if not arguments then
        return
    end
    if #arguments <= 0 then
        return
    end
    for _, path_component in ipairs(arguments) do
        if is_windows_host then
            path = path..module.to_windows_path(path_component)
        else
            path = path..module.to_unix_path(path_component)
        end
    end
    return path
end

function module.to_unix_path(windows_path)
    return string.gsub(windows_path, "\\", "/")
end

function module.to_windows_path(unix_path)
    return string.gsub(unix_path, "/", "\\")
end

function module.import_settings()
    local file_path = module.generate_path("./settings.json")
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
    -- Expects a single-level settings table
    local file = io.open(module.generate_path("./settings.json"), "w")
    file:write(settings_json)
    io.close()
end

function module.get_json_files_in_dir(directory)
    -- Gets all file names found in the given directory, if valid
    -- In Windows, DIR with option /B enables bare mode, removes all heading information and summary from the output, leaving only the file names
    local files = {}
    local path = module.generate_path(directory)
    local quoted_path = module.add_quotes(path)
    if not module.is_valid_path(path) then
        return
    end
    local file_list = io.popen("DIR /B "..quoted_path)
    local line
    repeat
        if line and string.sub(line, -5, -1) == ".json" then
            local bare_file_name = string.sub(line, 1, -6)
            table.insert(files, bare_file_name)
        end
        line = file_list:read("*l")
    until not line
    file_list:close()
    return files
end

function module.is_valid_path(path)
    -- Tests whether the file or directory exists, regardless of whether it is accessible by the current user
    local quoted_path = module.add_quotes(module.generate_path(path)) -- TODO: maybe don't generate the path here? In order to test the path as it is
    local is_windows_host = module.is_windows_host()
    local file_exists = false
    -- In Windows, DIR is used to test if a file or directory exists; >NUL 2>&1 are file descriptor redirections to suppress command output
    if is_windows_host then
        file_exists = os.execute("CALL DIR "..quoted_path.." >NUL 2>&1")
    else
        -- In Linux, the test command ([  ]) with option "-e" can be used to test if a file exists, regardless of file type (file, directory, etc.); >/dev/null 2>&1 are file descriptors to suppress command output
        file_exists = os.execute("[ -e "..quoted_path.." ] >/dev/null 2>&1")
    end
    -- Returns 0 on success, otherwise returns a non-zero exit code (this works the same on either OS)
    if (file_exists == 0) then
        file_exists = true
    end
    return file_exists
end

function module.is_windows_host()
    -- On Windows, the environment variable "OS" returns "Windows_NT", on Linux it is undefined; same goes for "WINDIR" except its value may differ
    -- Attempts to get the running OS using OS-specific commands are trickier and require unnecessarily complicated processing
    local is_windows = os.getenv("os") == "Windows_NT"
    local is_windir_found = os.getenv("windir") ~= nil
    -- Returns "true" if Windows, "false" if Linux or any unsupported system
    return is_windows or is_windir_found
end

function module.add_quotes(x)
    -- TODO: I already defined this function somewhere else... Maybe I can have that other module import the function from here
    return "\""..x.."\""
end

return module
