# YodBuild
Made for personal use to build Yodune projects  
Only supports windows, linux support has a small chance of being supported  

# Options and Example
```lua
local build = require "YodBuild"


build {
	-- Mandatory: Path to the folder where the includes, `.lib`, `.dll` and `.exe` reside
	luaDir="C:\\Program Files\\Lua\\LuaJit",
	-- Mandatory: Name of the library file Note: use `lua51.lib` for LuaJIT and NOT `LuaJIT.lib`
	luaLib="lua51.lib",

	-- The directory that the build will be outputted to
	outputDir="build_example",
	-- IGNOREABLE: The file name of the `.c` file
	outputFile="build_example",
	-- The name of the resulting `.exe` file
	outputExe="example.exe",
	-- The paths to search for include files, defaults are `{opts.luaDir, opts.luaDir .. "\\include"}`
	luaIncludes={"C:\\Program Files\\Lua\\LuaJit", "C:\\Program Files\\Lua\\LuaJit\\include"},
	-- The folder to find the `.lib` file in, default is `opts.luaDir`
	luaLibPath="C:\\Program Files\\Lua\\LuaJit",
	-- Files to copy from the working directory to the build directory, ethier `["<OUT>"]="<SRC>"` or array item of `"<SRC/OUT>"`
	copyFiles={
		"help.txt",  -- from `help.txt` to `build/help.txt` for example
		["mods.json"]="default-mods.json",  -- from `default-mods.json` to `build/mods.json` for example
	},

	-- Mandatory: The file of which will be turned into a executable, the entry point...
	entrypoint="main.lua",
	-- Merge dependencies with the executable, so no extra lua files
	mergeDeps=true,
	-- Preserve line numbers ect
	debug=false,
	-- Only Available when `mergeDeps=true`, assigned `package.path` in the merge file automatically (recommended not to use, do this manually)
	path="?.lua;?/init.lua;libs/?.lua;libs/?/init.lua;",
	-- Only Available when `mergeDeps=true`, assigned `package.path` in the merge file automatically (recommended not to use, do this manually)
	cpath="libs/l?.dll;libs/?.dll;",

	-- Path to search for lua files during the dependency analysis process
	searchPath="?.lua;?/init.lua;libs/?.lua;libs/?/init.lua;" .. package.path,
	-- Path to search for binary files during the dependency analysis process
	searchCPath="libs/l?.dll;libs/?.dll;" .. package.cpath
}

```