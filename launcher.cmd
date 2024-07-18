@REM This launcher is needed to wrap the main script, so it inherits the directory path from the shell. Lua 5.1 cannot get the script path by itself reliably, and that brings a lot of stability issues
@REM With this launcher, you can start the program from any location, as long as remains in the project root folder
@REM It also launches the executable file, if found, instead of attempting to run the main script with Lua
@ECHO OFF
SET original_directory=%CD%
SET root_directory=%~dp0
CD %root_directory%
@REM All arguments are passed intact with %*
@REM TODO: on release, replace this Lua call with a call to the .exe file
SET EXE_PATH=".\physics-compiler-windows.exe"
IF EXIST "%EXE_PATH%" (
    @REM ECHO "Exe exists"
) ELSE (
    @REM ECHO "Exe doesn't exist"
    lua .\main.lua %*
)
CD %original_directory%