--!strict
-- The register at a plot's entrance: income piles up until the owner collects it, up to a cap.

local Balance = require(script.Parent.Parent.Config.Balance)

local Register = {}

-- How much the register holds; the Bigger Register feature (`bigger`) multiplies it.
function Register.capacity(incomePerSecond: number, bigger: boolean?): number
	local cap = incomePerSecond * Balance.Register.capMinutes * 60
	return if bigger then cap * Balance.Register.biggerCap else cap
end

-- The register's amount after `dt` more seconds of income. Above the cap (income dropped) it
-- stays where it is rather than losing money.
function Register.fill(amount: number, incomePerSecond: number, dt: number, bigger: boolean?): number
	local cap = Register.capacity(incomePerSecond, bigger)
	if amount >= cap then
		return amount
	end
	return math.min(cap, amount + incomePerSecond * dt)
end

return Register
