-- Applies, stacks and expires status effects on characters, and replicates them to clients.
-- There is no one stacking rule: each modifier kind stacks its own way, linear or exponential.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registries = Shared:WaitForChild("Registries")
local Utilities = Shared:WaitForChild("Utilities")
local Data = Shared:WaitForChild("Data")

local StatusRegistry = require(Registries:WaitForChild("StatusEffectRegistry"))

-- Ensure StatusRegistry is initialized
if StatusRegistry.Init then
	StatusRegistry.Init()
end
local Signal = require(Utilities:WaitForChild("Signal"))
local BalanceTable = require(Data:WaitForChild("BalanceTable"))

local StatusService = {}

StatusService.StatusChanged = Signal.new()

StatusService._started = false
StatusService._connections = {}
StatusService._active = {} -- [characterModel] = { [statusId] = statusInstance }
StatusService._services = {}

local function now()
	return os.clock()
end

local function isCharacter(target)
	return typeof(target) == "Instance"
		and target:IsA("Model")
		and target.Parent ~= nil
end

local function getHumanoid(character)
	if not isCharacter(character) then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function getPlayerFromCharacter(character)
	if not isCharacter(character) then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function resolveCharacter(target)
	if typeof(target) ~= "Instance" then
		return nil
	end

	if target:IsA("Player") then
		return target.Character, target
	end

	if target:IsA("Model") then
		return target, Players:GetPlayerFromCharacter(target)
	end

	if target.Parent and target.Parent:IsA("Model") then
		return target.Parent, Players:GetPlayerFromCharacter(target.Parent)
	end

	return nil
end

local function shallowCopy(t)
	local out = {}
	for k, v in pairs(t or {}) do
		out[k] = v
	end
	return out
end

local function deepGet(tbl, key)
	if not tbl then
		return nil
	end
	return tbl[key]
end

function StatusService:Init(services)
	StatusService._services = services or {}

	if StatusService._started then
		return
	end
	StatusService._started = true

	local heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		StatusService.Step(dt)
	end)

	table.insert(StatusService._connections, heartbeatConn)
end

function StatusService.SetReplicationService(replicationService)
	StatusService._services.ReplicationService = replicationService
end

function StatusService.SetDamageService(damageService)
	StatusService._services.DamageService = damageService
end

function StatusService.SetCooldownService(cooldownService)
	StatusService._services.CooldownService = cooldownService
end

function StatusService.SetCharacterService(characterService)
	StatusService._services.CharacterService = characterService
end

function StatusService.BindCharacter(character)
	if not isCharacter(character) then
		return
	end

	if not StatusService._active[character] then
		StatusService._active[character] = {}
	end
end

function StatusService.UnbindCharacter(character)
	if not isCharacter(character) then
		return
	end

	local bucket = StatusService._active[character]
	if not bucket then
		return
	end

	for statusId, statusState in pairs(bucket) do
		local def = StatusRegistry:Get(statusId)
		if def and def.OnRemove then
			pcall(def.OnRemove, {
				Character = character,
				Player = getPlayerFromCharacter(character),
				Status = statusState,
				Definition = def,
				Source = statusState.Source,
				Service = StatusService,
			})
		end
		StatusService:_replicate("Removed", character, statusState, def)
	end

	StatusService._active[character] = nil
end

function StatusService:HasStatus(target, statusId)
	local character = resolveCharacter(target)
	if not character then
		return false
	end

	local bucket = StatusService._active[character]
	if not bucket then
		return false
	end

	return bucket[statusId] ~= nil
end

function StatusService:GetStatus(target, statusId)
	local character = resolveCharacter(target)
	if not character then
		return nil
	end

	local bucket = StatusService._active[character]
	if not bucket then
		return nil
	end

	return bucket[statusId]
end

function StatusService:GetActiveStatuses(target)
	local character = resolveCharacter(target)
	if not character then
		return {}
	end

	local bucket = StatusService._active[character]
	if not bucket then
		return {}
	end

	local out = {}
	for _, state in pairs(bucket) do
		table.insert(out, state)
	end
	return out
end

function StatusService:RemoveStatus(target, statusId)
	local character = resolveCharacter(target)
	if not character then
		return false
	end

	local bucket = StatusService._active[character]
	if not bucket then
		return false
	end

	local state = bucket[statusId]
	if not state then
		return false
	end

	local def = StatusRegistry:Get(statusId)
	bucket[statusId] = nil

	if def and def.OnRemove then
		pcall(def.OnRemove, {
			Character = character,
			Player = getPlayerFromCharacter(character),
			Status = state,
			Definition = def,
			Source = state.Source,
			Service = StatusService,
		})
	end

	StatusService:_replicate("Removed", character, state, def)
	StatusService.StatusChanged:Fire("Removed", character, statusId, state)

	return true
end

function StatusService:ClearAll(target)
	local character = resolveCharacter(target)
	if not character then
		return
	end

	local bucket = StatusService._active[character]
	if not bucket then
		return
	end

	local toRemove = {}
	for statusId in pairs(bucket) do
		table.insert(toRemove, statusId)
	end
	for _, statusId in ipairs(toRemove) do
		StatusService:RemoveStatus(character, statusId)
	end
end

function StatusService:ClearPlayer(player)
	-- Clear all status effects for a player's character
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local character = player.Character
	if character then
		StatusService:ClearAll(character)
		StatusService.UnbindCharacter(character)
	end
end

function StatusService:ApplyStatus(target, statusId, source, overrides)
	local character = resolveCharacter(target)
	if not character then
		return nil, "InvalidTarget"
	end

	local def = StatusRegistry:Get(statusId)
	if not def then
		return nil, "UnknownStatus"
	end

	StatusService.BindCharacter(character)

	local bucket = StatusService._active[character]
	local existing = bucket[statusId]
	local baseDuration = overrides and overrides.Duration or def.Duration or 0
	local tickInterval = overrides and overrides.TickInterval or def.TickInterval or 1
	local maxStacks = overrides and overrides.MaxStacks or def.MaxStacks or 1
	local refreshBehavior = overrides and overrides.RefreshBehavior
		or def.RefreshBehavior
		or "RefreshDuration"

	if existing then
		if refreshBehavior == "Ignore" then
			return existing, "Ignored"
		elseif refreshBehavior == "Replace" then
			bucket[statusId] = nil
			existing = nil
		elseif refreshBehavior == "Stack" then
			existing.Stacks = math.min(existing.Stacks + 1, maxStacks)
			existing.Remaining = math.max(existing.Remaining, baseDuration)
			existing.Duration = math.max(existing.Duration, baseDuration)
			existing.NextTick = now() + tickInterval
		else
			existing.Remaining = baseDuration
			existing.Duration = baseDuration
			existing.NextTick = now() + tickInterval
		end
	end

	if not existing then
		local instance = {
			Id = statusId,
			Definition = def,
			Source = source,
			Stacks = overrides and overrides.Stacks or 1,
			Duration = baseDuration,
			Remaining = baseDuration,
			TickInterval = tickInterval,
			NextTick = now() + tickInterval,
			AppliedAt = now(),
			Overides = shallowCopy(overrides),
			Data = shallowCopy(overrides and overrides.Data or nil),
		}

		bucket[statusId] = instance
		existing = instance
	end

	if def.OnApply then
		pcall(def.OnApply, {
			Character = character,
			Player = getPlayerFromCharacter(character),
			Status = existing,
			Definition = def,
			Source = source,
			Service = StatusService,
		})
	end

	StatusService:_replicate("Applied", character, existing, def)
	StatusService.StatusChanged:Fire("Applied", character, statusId, existing)

	return existing
end

function StatusService:RefreshStatus(target, statusId, source, overrides)
	local character = resolveCharacter(target)
	if not character then
		return nil
	end

	local bucket = StatusService._active[character]
	if not bucket or not bucket[statusId] then
		return StatusService.ApplyStatus(character, statusId, source, overrides)
	end

	local state = bucket[statusId]
	local def = StatusRegistry:Get(statusId)
	local duration = overrides and overrides.Duration or state.Duration or def.Duration or 0

	state.Duration = duration
	state.Remaining = duration
	state.NextTick = now()
		+ (overrides and overrides.TickInterval or state.TickInterval or def.TickInterval or 1)
	state.Source = source or state.Source
	state.Overides = shallowCopy(overrides or state.Overides)

	StatusService:_replicate("Refreshed", character, state, def)
	StatusService.StatusChanged:Fire("Refreshed", character, statusId, state)

	return state
end

function StatusService:GetStacks(target, statusId)
	local state = StatusService.GetStatus(target, statusId)
	if not state then
		return 0
	end
	return state.Stacks or 1
end

function StatusService:GetDamageMultiplier(target, damageType, source)
	local character = resolveCharacter(target)
	if not character then
		return 1
	end

	local bucket = StatusService._active[character]
	if not bucket then
		return 1
	end

	local multiplier = 1

	for _, state in pairs(bucket) do
		local def = state.Definition
		local mods = def and def.Modifiers
		if mods then
			local dmgTypeMultipliers = mods.DamageTypeMultipliers
			if dmgTypeMultipliers and damageType then
				local specific = dmgTypeMultipliers[damageType]
				if typeof(specific) == "number" then
					-- Linear stacking: each stack adds (specific - 1) more multiplier.
					-- e.g. Fire = 1.5 with 3 stacks gives 1 + 0.5*3 = 2.5x, not 1.5^3 = 3.375x.
					multiplier *= (1 + (specific - 1) * (state.Stacks or 1))
				end
			end

			local taken = mods.DamageTakenMultiplier
			if typeof(taken) == "number" then
				multiplier *= (taken ^ (state.Stacks or 1))
			end
		end

		local affinities = def and (def.Affinities or def.Resistances or def.Weaknesses)
		if affinities and damageType then
			local specific = affinities[damageType]
			if typeof(specific) == "number" then
				multiplier *= (specific ^ (state.Stacks or 1))
			end
		end
	end

	return multiplier
end

function StatusService:GetStatModifier(target, statName)
	local character = resolveCharacter(target)
	if not character then
		return 1, 0
	end

	local bucket = StatusService._active[character]
	if not bucket then
		return 1, 0
	end

	local multiplier = 1
	local additive = 0

	for _, state in pairs(bucket) do
		local def = state.Definition
		local mods = def and def.Modifiers
		if mods then
			local statValue = mods[statName]

			if typeof(statValue) == "number" then
				multiplier *= (statValue ^ (state.Stacks or 1))
			elseif typeof(statValue) == "table" then
				local kind = statValue.Type or "Multiplier"
				local value = statValue.Value or 0
				local stacks = state.Stacks or 1

				if kind == "Multiplier" then
					multiplier *= (value ^ stacks)
				elseif kind == "Additive" then
					additive += value * stacks
				elseif kind == "Override" then
					multiplier = value
					additive = 0
				elseif kind == "PerStackReduction" then
					-- Linear additive reduction: each stack reduces by value (e.g. 0.2 = 20%)
					multiplier *= math.max(0, 1 - (value * stacks))
				end
			end
		end
	end

	return multiplier, additive
end

function StatusService:ResolveStat(target, statName, baseValue)
	local multiplier, additive = StatusService:GetStatModifier(target, statName)
	return (baseValue * multiplier) + additive
end

function StatusService:CanMove(target)
	local character = resolveCharacter(target)
	if not character then
		return true
	end

	-- Check for status effects that block movement
	if StatusService:HasStatus(character, "Stunned") then
		return false
	end
	if StatusService:HasStatus(character, "Root") then
		return false
	end
	if StatusService:HasStatus(character, "Freeze") then
		return false
	end
	return true
end

function StatusService:CanCast(target)
	local character = resolveCharacter(target)
	if not character then
		return true
	end

	-- Check for status effects that block abilities
	if StatusService:HasStatus(character, "Stunned") then
		return false
	end
	if StatusService:HasStatus(character, "Helplessness") then
		return false
	end
	if StatusService:HasStatus(character, "Silence") then
		return false
	end
	if StatusService:HasStatus(character, "Disable") then
		return false
	end

	return true
end

function StatusService.Step(dt)
	for character, bucket in pairs(StatusService._active) do
		if not isCharacter(character) then
			StatusService._active[character] = nil
			continue
		end

		local humanoid = getHumanoid(character)
		if humanoid == nil then
			StatusService:ClearAll(character)
			StatusService._active[character] = nil
			continue
		end

		for statusId, state in pairs(bucket) do
			local def = state.Definition or StatusRegistry:Get(statusId)
			if not def then
				bucket[statusId] = nil
				continue
			end

			-- Process tick BEFORE reducing remaining time
			-- This ensures the final tick always fires before removal
			local tickInterval = state.TickInterval or def.TickInterval
			local shouldTick = tickInterval and tickInterval > 0 and now() >= (state.NextTick or 0)

			if shouldTick then
				state.NextTick = now() + tickInterval

				if def.OnTick then
					pcall(def.OnTick, {
						Character = character,
						Player = getPlayerFromCharacter(character),
						Status = state,
						Definition = def,
						Source = state.Source,
						Service = StatusService,
					})
				end

				if def.TickDamage and StatusService._services.DamageService then
					local source = state.Source
					local amount, damageType

					-- Handle both number and table formats for TickDamage
					if typeof(def.TickDamage) == "number" then
						amount = def.TickDamage
						damageType = def.DamageType or statusId
					elseif typeof(def.TickDamage) == "table" then
						amount = def.TickDamage.Amount or 0
						damageType = def.TickDamage.DamageType or def.DamageType or statusId
					else
						amount = 0
						damageType = statusId
					end

					local stacks = state.Stacks or 1
					local finalDamage = amount * stacks

					local damageMultiplier =
						StatusService:GetDamageMultiplier(character, damageType, source)
					finalDamage *= damageMultiplier

					StatusService._services.DamageService.ApplyDamage(
						source or character,
						character,
						finalDamage,
						damageType,
						{
							SourceReason = "StatusTick",
							StatusId = statusId,
						}
					)
				end

				StatusService:_replicate("Tick", character, state, def)
				StatusService.StatusChanged:Fire("Tick", character, statusId, state)
			end

			-- Now reduce remaining time
			state.Remaining -= dt

			if state.Remaining <= 0 then
				StatusService:RemoveStatus(character, statusId)
				continue
			end
		end
	end
end

function StatusService:GetAllModifiers(target)
	local character = resolveCharacter(target)
	if not character then
		return {}
	end

	local bucket = StatusService._active[character]
	if not bucket then
		return {}
	end

	local result = {}

	for _, state in pairs(bucket) do
		local def = state.Definition
		local mods = def and def.Modifiers
		if mods then
			for statName, value in pairs(mods) do
				if statName ~= "DamageTypeMultipliers" then
					result[statName] = result[statName] or {
						Multiplier = 1,
						Additive = 0,
					}

					if typeof(value) == "number" then
						result[statName].Multiplier *= (value ^ (state.Stacks or 1))
					elseif typeof(value) == "table" then
						local kind = value.Type or "Multiplier"
						local v = value.Value or 0
						if kind == "Multiplier" then
							result[statName].Multiplier *= (v ^ (state.Stacks or 1))
						elseif kind == "Additive" then
							result[statName].Additive += v * (state.Stacks or 1)
						elseif kind == "Override" then
							result[statName].Multiplier = v
							result[statName].Additive = 0
						elseif kind == "PerStackReduction" then
							local total = v * (state.Stacks or 1)
							result[statName].Multiplier *= math.max(0, 1 - total)
						end
					end
				end
			end
		end
	end

	return result
end

function StatusService:_replicate(action, character, state, def)
	if state and state.Data and state.Data.Internal then return end
	if def and def.Replication == false then return end

	local replicationService = StatusService._services.ReplicationService
	if not replicationService then
		return
	end

	local player = getPlayerFromCharacter(character)

	local payload = {
		Action = action,
		Character = character,
		Player = player,
		StatusId = state and state.Id,
		DisplayName = def and def.DisplayName,
		Description = def and def.Description,
		Category = def and def.Category,
		Stacks = state and state.Stacks or 1,
		Remaining = state and state.Remaining or 0,
		Duration = state and state.Duration or 0,
		HideTimer = def and def.HideTimer or false,
		Source = state and state.Source,
		Replication = def and def.Replication,
		Data = state and state.Data,
	}

	if replicationService and replicationService.BroadcastStatus then
		replicationService:BroadcastStatus(payload)
	end
end

function StatusService:DebugDump(target)
	local character = resolveCharacter(target)
	if not character then
		return {}
	end

	local bucket = StatusService._active[character]
	if not bucket then
		return {}
	end

	local dump = {}

	for statusId, state in pairs(bucket) do
		dump[statusId] = {
			Stacks = state.Stacks,
			Remaining = state.Remaining,
			Duration = state.Duration,
			TickInterval = state.TickInterval,
			Source = state.Source,
		}
	end

	return dump
end

return StatusService
