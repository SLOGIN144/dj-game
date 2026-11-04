--!strict
-- Server-made prompts meant for one player (the blown speaker's "Fix") carry an "OwnerUserId"
-- attribute; every other client switches them off locally, so visitors don't see them. The server
-- still checks who triggered a prompt.

local Players = game:GetService("Players")

local PromptFilter = {}

local function check(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local owner = instance:GetAttribute("OwnerUserId")
	if typeof(owner) == "number" and owner ~= Players.LocalPlayer.UserId then
		instance.Enabled = false
	end
end

function PromptFilter.start()
	workspace.DescendantAdded:Connect(check)
	for _, descendant in workspace:GetDescendants() do
		check(descendant)
	end
end

return PromptFilter
