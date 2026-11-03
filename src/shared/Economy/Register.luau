--!strict
-- The register at a plot's entrance: income piles up until the owner collects it, up to a cap.

local Balance = require(script.Parent.Parent.Config.Balance)

local Register = {}

function Register.capacity(incomePerSecond: number): number
	return incomePerSecond * Balance.Register.capMinutes * 60
end

-- The register's amount after `dt` more seconds of income. Above the cap (income dropped) it
-- stays where it is rather than losing money.
function Register.fill(amount: number, incomePerSecond: number, dt: number): number
	local cap = Register.capacity(incomePerSecond)
	if amount >= cap then
		return amount
	end
	return math.min(cap, amount + incomePerSecond * dt)
end

return Register
