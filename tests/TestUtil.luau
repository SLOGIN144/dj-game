--!strict
-- Tiny assertion helpers for the *.spec modules. Each helper raises an error the runner reports.

local TestUtil = {}

local function prefix(label: string?): string
	return if label then label .. ": " else ""
end

function TestUtil.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(string.format("%sexpected %s, got %s", prefix(label), tostring(expected), tostring(actual)), 2)
	end
end

function TestUtil.near(actual: number?, expected: number, tolerance: number?, label: string?)
	local allowed = tolerance or 1e-6
	if actual == nil or math.abs(actual - expected) > allowed then
		error(
			string.format(
				"%sexpected %s (within %s), got %s",
				prefix(label),
				tostring(expected),
				tostring(allowed),
				tostring(actual)
			),
			2
		)
	end
end

function TestUtil.truthy(value: any, label: string?)
	if not value then
		error(string.format("%sexpected a truthy value, got %s", prefix(label), tostring(value)), 2)
	end
end

return TestUtil
