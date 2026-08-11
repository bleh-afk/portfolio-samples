-- CombatStateMachine - Manages character combat states for fighting game mechanics
-- State mirrors onto character attributes so the client can read it; frames are 60ths of a second.

local CombatStateMachine = {}

CombatStateMachine.States = {
	Idle = "Idle",
	Attacking = "Attacking",
	Dashing = "Dashing",
	Hitstun = "Hitstun",
	Blockstun = "Blockstun",
	Knockback = "Knockback",
	KnockedDown = "KnockedDown",
	Dead = "Dead",
}

-- [character] = {state, frame, startTime, canCancel, duration}
local characterStates = {}

function CombatStateMachine.GetState(character)
	local stateData = characterStates[character]
	if not stateData then
		return CombatStateMachine.States.Idle, 0, true
	end
	return stateData.state, stateData.frame, stateData.canCancel
end

function CombatStateMachine.SetState(character, state, duration)
	if not character then return end

	local stateData = characterStates[character] or {}
	stateData.state = state
	stateData.frame = 0
	stateData.startTime = os.clock()
	stateData.canCancel = false
	stateData.duration = duration or 0

	characterStates[character] = stateData

	-- Set attribute for client sync
	character:SetAttribute("CombatState", state)
	character:SetAttribute("CombatStateFrame", 0)
	character:SetAttribute("CanCancel", false)
end

function CombatStateMachine.UpdateFrame(character, frame)
	local stateData = characterStates[character]
	if stateData then
		stateData.frame = frame
		character:SetAttribute("CombatStateFrame", frame)
	end
end

function CombatStateMachine.SetCancelable(character, canCancel)
	local stateData = characterStates[character]
	if stateData then
		stateData.canCancel = canCancel
		character:SetAttribute("CanCancel", canCancel)
	end
end

function CombatStateMachine.CanAct(character)
	local state = CombatStateMachine.GetState(character)

	if state == CombatStateMachine.States.Idle then
		return true
	end

	-- Anything else is actionable only inside a cancel window
	local stateData = characterStates[character]
	if stateData and stateData.canCancel then
		return true
	end

	return false
end

function CombatStateMachine.HasIFrames(character)
	local state = CombatStateMachine.GetState(character)

	if state == CombatStateMachine.States.Dashing then
		-- I-frames are handled by the dash ability
		return character:GetAttribute("HasIFrames") or false
	end

	if state == CombatStateMachine.States.Knockback then
		return true
	end

	if state == CombatStateMachine.States.KnockedDown then
		return true
	end

	return false
end

function CombatStateMachine.ResetToIdle(character)
	CombatStateMachine.SetState(character, CombatStateMachine.States.Idle)
	CombatStateMachine.SetCancelable(character, true)
end

function CombatStateMachine.CleanupCharacter(character)
	characterStates[character] = nil
end

function CombatStateMachine.ApplyHitstun(character, frames)
	CombatStateMachine.SetState(character, CombatStateMachine.States.Hitstun, frames / 60)
	-- Frame counter will be handled by a heartbeat connection
end

function CombatStateMachine.ApplyBlockstun(character, frames)
	CombatStateMachine.SetState(character, CombatStateMachine.States.Blockstun, frames / 60)
end

function CombatStateMachine.ApplyKnockback(character, duration)
	CombatStateMachine.SetState(character, CombatStateMachine.States.Knockback, duration)
end

function CombatStateMachine.ApplyKnockdown(character, frames)
	CombatStateMachine.SetState(character, CombatStateMachine.States.KnockedDown, frames / 60)
end

function CombatStateMachine.InitializeCharacter(character)
	CombatStateMachine.ResetToIdle(character)
end

return CombatStateMachine
