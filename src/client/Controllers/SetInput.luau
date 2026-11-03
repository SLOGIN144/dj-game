--!strict
-- Player input for a set: the main button (Space, click or tap, with press and release), the
-- crossfader (← / → held, or dragging the crossfader with mouse or finger), cards (1-3 or click)
-- and restart (R or tapping the results). SetDirector sets the callbacks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local SetUI = require(script.Parent.Parent.UI.SetUI)

local SetInput = {}
SetInput.__index = SetInput

local CARD_KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }

export type SetInput = typeof(setmetatable(
	{} :: {
		crossfader: number,
		held: boolean,
		onPress: () -> (),
		onRelease: () -> (),
		onCard: (number) -> (),
		onRestart: () -> (),
		onCrossfaderMoved: () -> (),
		_ui: SetUI.SetUI,
		_dragging: InputObject?,
		_connections: { RBXScriptConnection },
	},
	SetInput
))

local function nothing() end

function SetInput.new(ui: SetUI.SetUI): SetInput
	local self = setmetatable({
		crossfader = 0,
		held = false,
		onPress = nothing,
		onRelease = nothing,
		onCard = function(_: number) end,
		onRestart = nothing,
		onCrossfaderMoved = nothing,
		_ui = ui,
		_dragging = nil :: InputObject?,
		_connections = {},
	}, SetInput)

	local function press()
		if not self.held then
			self.held = true
			ui:setButtonPressed(true)
			self.onPress()
		end
	end
	local function release()
		if self.held then
			self.held = false
			ui:setButtonPressed(false)
			self.onRelease()
		end
	end
	local function dragTo(x: number)
		local track = ui.crossfaderTrack
		self.crossfader = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		self.onCrossfaderMoved()
	end

	table.insert(
		self._connections,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if input.KeyCode == Enum.KeyCode.Space then
				press()
			elseif CARD_KEYS[input.KeyCode] then
				self.onCard(CARD_KEYS[input.KeyCode])
			elseif input.KeyCode == Enum.KeyCode.R then
				self.onRestart()
			end
		end)
	)
	table.insert(
		self._connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.KeyCode == Enum.KeyCode.Space then
				release()
			elseif input == self._dragging then
				self._dragging = nil
			end
		end)
	)
	table.insert(
		self._connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			local dragging = self._dragging
			if
				dragging
				and (input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement)
				and (dragging.UserInputType ~= Enum.UserInputType.Touch or input == dragging)
			then
				dragTo(input.Position.X)
			end
		end)
	)

	-- Main button by mouse or touch.
	table.insert(
		self._connections,
		ui.mainButton.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				press()
				local ended
				ended = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						ended:Disconnect()
						release()
					end
				end)
			end
		end)
	)

	-- Crossfader drag (anywhere on its track).
	table.insert(
		self._connections,
		ui.crossfaderTrack.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				self._dragging = input
				dragTo(input.Position.X)
			end
		end)
	)

	for i, card in ui.cardButtons do
		table.insert(
			self._connections,
			card.Activated:Connect(function()
				self.onCard(i)
			end)
		)
	end
	table.insert(
		self._connections,
		ui:resultsFrame().InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				self.onRestart()
			end
		end)
	)
	return self
end

-- Moves the crossfader while ← or → is held. Call once per frame.
function SetInput.update(self: SetInput, dt: number)
	local direction = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		direction -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		direction += 1
	end
	if direction ~= 0 then
		self.crossfader = math.clamp(self.crossfader + direction * Balance.Blend.keySpeed * dt, 0, 1)
		self.onCrossfaderMoved()
	end
end

function SetInput.destroy(self: SetInput)
	for _, connection in self._connections do
		connection:Disconnect()
	end
end

return SetInput
