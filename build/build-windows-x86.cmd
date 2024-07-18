@REM Note: even though the "srlua" executable is meant for 32-bit systems, the whole program has been developed for 64-bit systems
@REM Temporarily copies (and then deletes) Lua 5.1 DLLs to the srlua folder so they are used as the base Lua interpreter
@REM For reference: I used the Lua 5.1 DLLs from Lua for Windows (at the moment, I don't know if they are all the same). No, this didn't work, either
@ECHO OFF
SET CURRENT_DIRECTORY=%CD%
SET ROOT_DIRECTORY=%~dp0..\
SET BUILD_DIRECTORY=%~dp0
CD %ROOT_DIRECTORY%
@REM TODO: copy the Lua 5.1 DLLs to the same directory as the glue and srlua files (lua5.1 and lua51, both .dll and .lib)
ECHO === FILE NOT READY YET ===
@REM .\lib\srlua-Windows-x86\bin\glue.exe .\lib\srlua-Windows-x86\bin\srlua.exe .\main.lua physics-compiler-windows-x86.exe
CD %CURRENT_DIRECTORY%