-- Made By Dude112113
-- YoDudes Builder, was originally made for YoDune projects
-- Only supports windows, small change that it gets linux support


local lfs = require "lfs"
local luapackfs = require "luapak.fs"
local deps_analyser = require "luapak.deps_analyser"
local merger = require "luapak.merger"
local wrapper = require "luapak.wrapper"


local CC = "cl"


local function execute(cmd)
	print("> " .. cmd)
	local f = assert(io.popen("\"" .. cmd .. "\""))
	local s = assert(f:read('*a'))
	f:close()
	return s
end

local function file_exists(file)
	local f = io.open(file, "r")
	return f ~= nil and f:close()
end

local function file_read(file)
	local f = assert(io.open(file, "r"), "Failed to open for read: " .. file)
	local data = f:read("*a")
	f:close()
	return data
end

local function file_copy(src, out)
	print("Copying \"" .. src .. "\" to \"" .. out .. "\"")
	local sf = io.open(src, "rb")
	if sf == nil then
		print("Failed to open for read " .. src)
		return false
	else
		local dirMakingPath = ""
		for path in out:match("(.*[/\\])"):gmatch("([^/\\]+)") do
			dirMakingPath = dirMakingPath .. path .. "/"
			if dirMakingPath ~= "build/" then
				lfs.mkdir(dirMakingPath)
			end
		end
		local of = io.open(out, "wb")
		if of == nil then
			print("Failed to open for write " .. out)
			return false
		else
			of:write(sf:read("*a"))
		end
		of:close()
		sf:close()
	end
	return true
end

local function remove_directory(dir)
	for path in lfs.dir(dir) do
		if path ~= "." and path ~= ".." then
			path = dir .. "/" .. path
			if lfs.attributes(path)["mode"] == "directory" then
				remove_directory(path)
			else
				os.remove(path)
			end
		end
	end
	lfs.rmdir(dir)
end

local function setup_compiler(arch)
	if execute(CC) ~= "" then
		return true
	else
		print("Failed to find compiler, make sure the compiler is accessible. (try running 'vcvarsall.bat'?)")
		return false
	end
	return true
end

local function build(opts)
	assert(opts.entrypoint ~= nil, "Missing 'entrypoint' option.")
	assert(file_exists(opts.entrypoint), "'entrypoint' \"" .. opts.entrypoint .. "\" file is not found")
	assert(opts.luaDir ~= nil, "Missing 'luaDir' option.")
	assert(opts.luaLib ~= nil, "Missing 'luaLib' option.")
	local entrypointName = opts.entrypoint:gsub(".lua", "")
	opts.outputDir = opts.outputDir or "build"
	opts.outputFile = opts.outputFile or entrypointName .. ".c"
	opts.outputExe = opts.outputExe or entrypointName .. ".exe"
	opts.luaIncludes = opts.luaIncludes or {opts.luaDir, opts.luaDir .. "\\include"}
	opts.luaLibPath = opts.luaLibPath or opts.luaDir
	opts.copyFiles = opts.copyFiles or {}
	opts.mergeDeps = opts.mergeDeps or false
	opts.debug = opts.debug or false
	opts.path = opts.path or nil
	opts.cpath = opts.cpath or nil
	opts.searchPath = opts.searchPath or package.path
	opts.searchCPath = opts.searchCPath or package.cpath

	if not setup_compiler(opts.arch) then
		os.exit(1)
	end

	print("Removing \"build/\"")
	remove_directory(opts.outputDir)
	lfs.mkdir(opts.outputDir)

	local searchPaths = {}
	for path in opts.searchPath:gmatch("([^;]+)") do
		table.insert(searchPaths, path)
	end
	local searchCPaths = {}
	for cpath in opts.searchCPath:gmatch("([^;]+)") do
		table.insert(searchCPaths, cpath)
	end

	local mergedDeps = {}
	local movedDeps = {}
	local deps, missingDeps, ignoredDeps, errs = deps_analyser.analyse(opts.entrypoint, opts.searchPath .. ";" .. opts.searchCPath .. ";;")
	for i, v in pairs(errs) do
		print("deps_analyser error:", i, v)
	end
	for dep, path in pairs(deps) do
		if opts.mergeDeps and not luapackfs.is_binary_file(path) then
			-- It will get merged later on because it is in mergedDeps
			mergedDeps[dep] = path
		else
			local name = path:gsub(".*[/\\](.*)$", "%1")
			local depPath = {}
			for s in dep:gmatch("([^%.]*)%.?") do
				if s ~= "" then
					table.insert(depPath, s)
				end
			end
			table.remove(depPath, #depPath)
			local depBaseDir = table.concat(depPath, "/")
			file_copy(path, opts.outputDir .. "/" .. depBaseDir .. "/" .. name)
			movedDeps[dep] = path
		end
	end

	local inputFile = opts.entrypoint
	local mergedFile
	if opts.mergeDeps then
		inputFile = opts.outputDir .. "/__merged.lua"
		mergedFile = assert(io.open(inputFile, "w"), "Failed to open " .. inputFile)
		if opts.path ~= nil then
			mergedFile:write("package.path = \"" .. opts.path:gsub("\\", "\\\\") .. "\"\n")
		end
		if opts.cpath ~= nil then
			mergedFile:write("package.cpath = \"" .. opts.cpath:gsub("\\", "\\\\") .. "\"\n")
		end
		if opts.path ~= nil or opts.cpath ~= nil then
			mergedFile:write("\n\n")
		end

		local mergeChunks = {}
		for name, path in pairs(mergedDeps) do
			mergeChunks[name] = file_read(path)
		end
		local depsStr = merger.merge_modules(mergeChunks, opts.debug)
		mergedFile:write(depsStr)

		local epf = assert(io.open(opts.entrypoint, "r"), "Failed to open " .. opts.entrypoint)
		mergedFile:write(epf:read("*a"))
		epf:close()

		mergedFile:close()
	end

	local code = wrapper.generate(file_read(inputFile), nil, {compress=not opts.debug})
	local f = assert(io.open(opts.outputDir .. "/" .. opts.outputFile, "w"), "Failed to open " .. opts.outputDir .. "/" .. opts.outputFile)
	f:write(code)
	f:close()

	local includeArgs = ""
	for _, include in ipairs(opts.luaIncludes) do
		includeArgs = includeArgs .. "/I \"" .. include .. "\" "
	end
	local buildOutput = execute(CC .. " /Fo\"" .. opts.outputDir .. "/\" " .. includeArgs .. "\"" .. opts.outputDir .. "/" .. opts.outputFile .. "\" /link /LIBPATH:\"" .. opts.luaLibPath .. "\" \"" .. opts.luaLib .. "\" /out:\"" .. opts.outputDir .. "/" .. opts.outputExe .. "\"")
	print(buildOutput)
	if buildOutput:find("fatal error") ~= nil then
		print("- An error occurned during the build process, see above for more info... (Build output contained 'fatal error')\n")
		os.exit(1)
	elseif not file_exists(opts.outputDir .. "/" .. opts.outputExe) then
		print("- Seems like an error has occurred, see above for more info... (Missing executable after build)\n")
		os.exit(1)
	end

	print("- Build success...")
	if opts.mergeDeps then
		print("- Merged the following dependencies lua code")
		for dep, path in pairs(mergedDeps) do
			print(dep .. " : " .. path)
		end
	end
	print("- Moved the following dependencies to build directory")
	for dep, path in pairs(movedDeps) do
		print(dep .. " : " .. path)
	end
	print("- Ignored the following dependencies")
	for _, dep in pairs(ignoredDeps) do
		print(dep)
	end
	print("- Failed to find the following dependencies")
	for _, dep in pairs(missingDeps) do
		print(dep)
	end
	-- print("")

	for out, src in pairs(opts.copyFiles) do
		if type(out) == "number" then
			out = src
		end
		file_copy(src, opts.outputDir .. "/" .. out)
	end
end


return build
