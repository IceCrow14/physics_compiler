-- System utilities module

-- This module is intended to contain (extended) system specific utilities, including but not limited to perform file system checks
-- The purpose of pushing almost all system specific code to this module is to keep the main script and most other modules as system-agnostic as possible

local module = {}

local dkjson = require("./lib/dkjson/dkjson")

function module.color_text(text, color, style)
    -- Expects a text string, and optionally, a color and a style
    -- Returns a string with special ANSI escape sequences for coloring and styling text (invalid color or style names are ignored)
    -- (Starting from Windows 10, Windows supports ANSI escape sequences in console)
    -- TODO: once it is confirmed that styled text shows up correctly on Linux hosts, remove system-specific logic
    local new_text = text
    local colors = {}
    local styles = {}
    local picked_color
    local picked_style
    local is_windows_host = module.is_windows_host()
    local escape_character_windows = ""
    local escape_character_linux = "" -- I though this would require using \e instead of the literal escape character used by Windows. This makes things easier
    -- Styles
    styles.reset = "[0m"
    styles.bold = "[1m"
    styles.underline = "[4m"
    styles.inverse = "[7m"
    -- Normal foreground colors
    colors.black = "[30m"
    colors.red = "[31m"
    colors.green = "[32m"
    colors.yellow = "[33m"
    colors.blue = "[34m"
    colors.magenta = "[35m"
    colors.cyan = "[36m"
    colors.white = "[37m"
    -- Strong foreground colors
    colors.strong_white = "[90m"
    colors.strong_red = "[91m"
    colors.strong_green = "[92m"
    colors.strong_yellow = "[93m"
    colors.strong_blue = "[94m"
    colors.strong_magenta = "[95m"
    colors.strong_cyan = "[96m"
    colors.strong_white = "[97m"
    -- (I won't bother adding support for background colors, I find them unnecessary right now)
    -- To change color and style of text, print an ESC character followed by the respective color or style sequence
    -- In these statements, it must be checked that the color and style are valid, or this will return an error from attempting to concatenate a "nil" value
    -- On a Windows host, "and" returns a character sequence that evaluates to true and is assigned, otherwise, the Linux sequence evaluates to true and is assigned
    if colors[color] then
        picked_color = is_windows_host and escape_character_windows..colors[color] or escape_character_linux..colors[color]
    end
    if styles[style] then
        picked_style = is_windows_host and escape_character_windows..styles[style] or escape_character_linux..styles[style]
    end
    if picked_color then
        new_text = picked_color..new_text
    end
    if picked_style then
        new_text = picked_style..new_text
    end
    if (picked_color or picked_style) then
        -- To return console style and color to normal, print a "reset" character sequence (ESC[0m)
        new_text = is_windows_host and new_text..escape_character_windows..styles.reset or new_text..escape_character_linux..styles.reset
    end
    return new_text
end

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
    file:close()
end

function module.get_json_files_in_dir(directory)
    -- Gets all file names found in the given directory, if valid
    local files = {}
    local path = module.generate_path(directory)
    local quoted_path = module.add_quotes(path)
    local is_windows_host = module.is_windows_host()
    local file_list
    local line
    if not module.is_valid_path(path) then
        return
    end
    if is_windows_host then
        -- In Windows, DIR with option /B enables bare mode, removes all heading information and summary from the output, leaving only the file names
        file_list = io.popen("DIR /B "..quoted_path)
    else
        -- In Linux, dir with options -a and -1 lists all files in the directory (including files starting with dot) one file by line
        file_list = io.popen("dir -1 -a "..quoted_path)
    end
    repeat
        local bare_file_name
        if line and string.sub(line, -5, -1) == ".json" then
            if is_windows_host then
                bare_file_name = string.sub(line, 1, -6)
            else
                -- In Linux, spaces in file names are escaped as "\ " and require additional processing
                -- For instance, in Windows a file name that looks like "human jeep", looks like "human\ jeep" in Linux
                -- This line of code removes escaped backslashes from file names so they can be matched to the Type name passed by the user
                bare_file_name = string.gsub(string.sub(line, 1, -6) , "\\", "")
            end
            table.insert(files, bare_file_name)
        end
        line = file_list:read("*l")
        -- TODO: remove this test when the problem is solved... Spaces in file names are read as "\ " instead of just " " in Linux, apparently
        --       I think the issue was caused by using pre-compiled Invader binaries for Windows, I should try testing this on a Linux build
        -- if line then
        --     print(bare_file_name)
        --     print("LINE "..line)
        -- end
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
