local Enums = require(script.Parent.Enums)

local StateMachineDefinitions = {}

StateMachineDefinitions.ValidStates = {
	[Enums.CharacterState.Idle] = true,
	[Enums.CharacterState.Walking] = true,
	[Enums.CharacterState.Sprinting] = true,
	[Enums.CharacterState.Stunned] = true,
	[Enums.CharacterState.Ragdolled] = true,
	[Enums.CharacterState.Attacking] = true,
	[Enums.CharacterState.AbilityActive] = true,
	[Enums.CharacterState.OnObjective] = true,
	[Enums.CharacterState.Dead] = true,
	[Enums.CharacterState.Recovery] = true,
	[Enums.CharacterState.Dashing] = true,
	[Enums.CharacterState.Hitstun] = true,
	[Enums.CharacterState.Blockstun] = true,
	[Enums.CharacterState.Knockback] = true,
	[Enums.CharacterState.KnockedDown] = true,
}

StateMachineDefinitions.Transitions = {
	[Enums.CharacterState.Idle] = {
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Ragdolled] = true,
		[Enums.CharacterState.Attacking] = true,
		[Enums.CharacterState.AbilityActive] = true,
		[Enums.CharacterState.OnObjective] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.Walking] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Sprinting] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Ragdolled] = true,
		[Enums.CharacterState.Attacking] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.Sprinting] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Ragdolled] = true,
		[Enums.CharacterState.Attacking] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.Stunned] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.Ragdolled] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.Attacking] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Ragdolled] = true,
		[Enums.CharacterState.Dead] = true,
		[Enums.CharacterState.Recovery] = true,
	},
	[Enums.CharacterState.AbilityActive] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Ragdolled] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.OnObjective] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Ragdolled] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.Dead] = {
		[Enums.CharacterState.Idle] = true,
	},
	[Enums.CharacterState.Recovery] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Sprinting] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Ragdolled] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.Dashing] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Ragdolled] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.Hitstun] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.Blockstun] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.Knockback] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Walking] = true,
		[Enums.CharacterState.Stunned] = true,
		[Enums.CharacterState.Ragdolled] = true,
		[Enums.CharacterState.Dead] = true,
	},
	[Enums.CharacterState.KnockedDown] = {
		[Enums.CharacterState.Idle] = true,
		[Enums.CharacterState.Ragdolled] = true,
		[Enums.CharacterState.Dead] = true,
	},
}

-- Alias for Transitions (used by StateService)
StateMachineDefinitions.AllowedTransitions = StateMachineDefinitions.Transitions

function StateMachineDefinitions:IsValidState(state)
	return self.ValidStates[state] == true
end

function StateMachineDefinitions:CanTransition(fromState, toState)
	if not self:IsValidState(fromState) or not self:IsValidState(toState) then
		return false
	end
	return self.Transitions[fromState] and self.Transitions[fromState][toState] == true
end

return StateMachineDefinitions
