--!strict
-- Server-made prompts meant for one player (the blown speaker's "Fix", a delivery's boxes and
-- outlines) carry an "OwnerUserId" attribute; every other client switches them off locally, so
-- visitors don't see them. A delivery's prompts also depend on what the owner carries: a box can be
-- picked up only with empty hands, and an outline takes only its own box ("BoxItem" and
-- "OutlineItem" hold the item id, "Carrying" on the player the id in their hands). The server still
-- checks who triggered a prompt and when.

local Players = game:GetService("Players")

local PromptFilter = {}

-- Prompts whose state follows what the player carries (a plain table: a weak one can lose Instances).
local carryPrompts: { [ProximityPrompt]: boolean } = {}

local function fits(prompt: ProximityPrompt): boolean
	local carrying = Players.LocalPlayer:GetAttribute("Carrying")
	local outlineItem = prompt:GetAttribute("OutlineItem")
	if typeof(outlineItem) == "string" then
		return carrying == outlineItem
	end
	return typeof(carrying) ~= "string" -- a box: only with empty hands
end

local function check(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local owner = instance:GetAttribute("OwnerUserId")
	if typeof(owner) == "number" and owner ~= Players.LocalPlayer.UserId then
		instance.Enabled = false
		return
	end
	if
		typeof(instance:GetAttribute("BoxItem")) == "string"
		or typeof(instance:GetAttribute("OutlineItem")) == "string"
	then
		carryPrompts[instance] = true
		instance.Destroying:Connect(function()
			carryPrompts[instance] = nil
		end)
		instance.Enabled = fits(instance)
	end
end

function PromptFilter.start()
	workspace.DescendantAdded:Connect(check)
	for _, descendant in workspace:GetDescendants() do
		check(descendant)
	end
	Players.LocalPlayer:GetAttributeChangedSignal("Carrying"):Connect(function()
		for prompt in carryPrompts do
			if prompt.Parent then
				prompt.Enabled = fits(prompt)
			end
		end
	end)
end

return PromptFilter
