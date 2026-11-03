--!strict
-- Short money text for the HUD and the buttons: $950, $1.2K, $3.4M. Always rounds down, so the
-- screen never shows more than the player has.

local Format = {}

local SUFFIXES: { { size: number, letter: string } } = {
	{ size = 1e12, letter = "T" },
	{ size = 1e9, letter = "B" },
	{ size = 1e6, letter = "M" },
	{ size = 1e3, letter = "K" },
}

-- One decimal at most, without a trailing ".0".
local function short(value: number): string
	local text = string.format("%.1f", math.floor(value * 10) / 10)
	return (string.gsub(text, "%.0$", ""))
end

function Format.money(value: number): string
	local whole = math.floor(value)
	for _, suffix in SUFFIXES do
		if whole >= suffix.size then
			local scaled = whole / suffix.size
			return "$" .. (if scaled < 100 then short(scaled) else tostring(math.floor(scaled))) .. suffix.letter
		end
	end
	return "$" .. tostring(whole)
end

function Format.rate(perSecond: number): string
	if perSecond < 10 then
		return "+$" .. short(perSecond) .. "/s"
	end
	return "+" .. Format.money(perSecond) .. "/s"
end

return Format
