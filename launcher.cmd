@REM This launcher is needed to wrap the main script, so it inherits the directory path from the shell. Lua 5.1 cannot get the script path by itself reliably, and that brings a lot of stability issues
@SET original_directory=%CD%
@SET root_directory=%~dp0
@CD %root_directory%
@REM All arguments are passed intact with %*
@REM TODO: on release, replace this Lua call with a call to the .exe file
@lua main.lua %*
@CD %original_directory%