--!strict
-- Runs every *.spec module next to this script when the Track Tagger place starts in Play mode.
-- Prints one summary line, plus a warning per failing test.

local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

type Spec = { [string]: () -> () }

local passed, failed = 0, 0

local specs = {}
for _, child in script.Parent:GetChildren() do
	if child:IsA("ModuleScript") and string.match(child.Name, "%.spec$") then
		table.insert(specs, child)
	end
end
table.sort(specs, function(a, b)
	return a.Name < b.Name
end)

for _, module in specs do
	local loaded, spec = pcall(require, module)
	if not loaded then
		failed += 1
		warn(string.format("[Tests] %s failed to load: %s", module.Name, tostring(spec)))
		continue
	end

	local names = {}
	for name in spec :: Spec do
		table.insert(names, name)
	end
	table.sort(names)

	for _, name in names do
		local ok, err = pcall((spec :: Spec)[name])
		if ok then
			passed += 1
		else
			failed += 1
			warn(string.format("[Tests] FAIL %s > %s: %s", module.Name, name, tostring(err)))
		end
	end
end

print(string.format("[Tests] %d passed, %d failed", passed, failed))
