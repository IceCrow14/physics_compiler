@ECHO OFF
SET CURRENT_DIRECTORY=%CD%
SET ROOT_DIRECTORY=%~dp0..\
SET BUILD_DIRECTORY=%~dp0
CD %ROOT_DIRECTORY%
.\build\srlua_5.1_windows_x86\glue.exe .\build\srlua_5.1_windows_x86\srlua.exe .\main.lua physics_compiler.exe
CD %CURRENT_DIRECTORY%