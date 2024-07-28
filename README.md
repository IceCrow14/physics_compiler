# PhyCom (physics_compiler)
PhyCom (codename for "Physics Compiler") is a tool for creating .physics tags for Halo Custom Edition.

The purpose of this tool is to create physics for custom vehicles made from scratch.

The days of tinkering with old physics tags from stock vehicles through trial-and-error, and cursing at cryptic error messages from the Halo Editing Kit are gone.

## Quick Start Guide
(TODO)

## Installing
PhyCom uses Invader to perform multiple tag manipulation tasks. You need to install Invader before running this application.

The official Invader source code repository is: https://github.com/SnowyMouse/invader

### Windows
It is recommended that you download a Windows build from the Releases section. This application has been designed to be used in 64-bit Windows operating systems, particularly, Windows 10 and later.

You can also download the source code and use it in a "portable" fashion, just make sure to also download all required submodules from the "lib" directory.

### Linux
At the moment, there are no fully stand-alone builds for Linux, though you can set up a working environment easily by following a few steps. You will have to install a Lua 5.1 interpreter, and customize the "launcher" script.

1. Install a Lua 5.1 interpreter
You can achieve this by using your package manager of choice, and installing a Lua 5.1 interpreter package. For instance, in Debian-like distributions (such as Ubuntu) you may use "apt" to install Lua 5.1 as follows:
```
sudo apt install lua5.1
```
2. Customize your launcher script
If you installed Lua 5.1 using the command shown above, then you are all set. Otherwise, you will have to customize the launcher script to point to your Lua 5.1 executable, either by indicating the alias for your Lua executable, or by specifying the path to your Lua 5.1 interpreter.

Inside the "launcher" file, modify the value of the "lua_alias" variable to point to your Lua 5.1 interpreter. For instance:

Assume your Lua 5.1 interpreter is started by alias **lua-five-dot-one**, then set lua_alias as follows:
```
lua_alias="lua-five-dot-one"
```
Or you can provide the path to the executable file.
```
lua_alias="/path/to/lua/lua-five-dot-one"
```

## Running
Start by running the launcher script from your terminal of choice.

On the first run, you will be greeted by a warning message, and asked to provide the path to your Halo Custom Edition installation folder, as well as the path to your Invader installation folder.

Don't worry if you make a mistake, if you want to change these paths later, you can do that by calling the launcher script using option **-s** to start over.
```
launcher[.cmd] -s
```

### Windows
Open a Command Prompt window, and run the following (replace paths where required):
```
CD path\to\folder\physics_compiler
launcher.cmd
```

### Linux
Open a Terminal window, and run the following (replace paths where required):
```
cd path/to/folder/physics_compiler
launcher
```

(TODO)
Once you set up your environment, the next step is to call the launcher script again, and provide the following inputs in order to create a new physics tag:
* (Optional) Vehicle mass in Halo mass units
* Vehicle type definition
* Path to a valid JMS file containing the collision geometry, and the mass point spheres of your collision model (relative to "data" folder)
* Path of the output physics tag (relative to "tags" folder)

```
launcher[.cmd] [-m <mass>] <type> <jms_path> <physics_path>
```

For instance:
```
launcher "human jeep" vehicles\my_car\physics\my_car.jms vehicles\my_car\my_car.physics
```
```
launcher.cmd -m 9999 "alien fighter" ".\vehicles\my_plane\physics\my_plane.jms" ".\vehicles\my_plane\my_plane.physics"
```