@REM This launcher is needed to wrap the main script, so it inherits the directory path from the shell. Lua 5.1 cannot get the script path by itself reliably, and that brings a lot of stability issues
@REM With this launcher, you can start the program from any location, as long as remains in the project root folder
@ECHO OFF
SET original_directory=%CD%
SET root_directory=%~dp0
CD %root_directory%
@REM This line launches the embedded Lua 5.1 interpreter for Windows x64, downloaded from LuaBinaries' Source Forge repository
@REM All arguments are passed intact with %*
CALL ".\lua\windows-x64\lua5.1.exe" ".\main.lua" %*
CD %original_directory%