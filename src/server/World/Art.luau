--!strict
-- Imported art (GDD: asset workflow). A model in ServerStorage › Art › <location> named after an
-- item (or "Shell" for a location's room, or a street prop id under "street") replaces its
-- blockout parts. Its pivot goes where the model sheets say: an item's at the bottom centre of its
-- blockout, the Shell's at the plot origin. Copies are anchored, and any script inside is removed.

local ServerStorage = game:GetService("ServerStorage")

local Art = {}

-- The imported model for `name` in `folderName`, if there is one.
function Art.find(folderName: string, name: string): Model?
	local root = ServerStorage:FindFirstChild("Art")
	local folder = if root then root:FindFirstChild(folderName) else nil
	local model = if folder then folder:FindFirstChild(name) else nil
	return if model and model:IsA("Model") then model else nil
end

-- A clean, anchored copy of `model` with its pivot at `cframe`, parented to `parent`.
function Art.place(model: Model, cframe: CFrame, parent: Instance): Model
	local copy = model:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	copy:PivotTo(cframe)
	copy.Parent = parent
	return copy
end

return Art
