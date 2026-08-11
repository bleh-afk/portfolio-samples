-- Loads, validates and serves ability definitions from the character definition folders.
-- Not a config file. Balance values live in BalanceTable; change them there, not here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Core.Enums)
local BalanceTable = require(ReplicatedStorage.Shared.Data.BalanceTable)

local AbilityFolder = ReplicatedStorage.Shared.Definitions.Abilities

local AbilityRegistry = {}

-- Trusted data, only written after validation passes
local abilitiesById = {}
local passivesById = {}

local initialized = false

local function validateAbility(definition)
	if not definition.NameId then
		error("Ability definition missing NameId")
	end

	if not definition.AbilityType then
		error(definition.NameId .. " missing AbilityType")
	end

	if not Enums.AbilityType[definition.AbilityType] then
		error(definition.NameId .. " has invalid AbilityType")
	end

	if not BalanceTable.Abilities[definition.NameId] then
		error(definition.NameId .. " missing BalanceTable entry")
	end

	-- if you need more validation for specific values in BalanceTable, add them here
end

local function validatePassive(definition)
	if not definition.NameId and not definition.Id and not definition.Name then
		error("Passive definition missing identifier (NameId, Id, or Name required)")
	end

	local id = definition.NameId or definition.Id or definition.Name

	if not definition.AbilityType then
		error(id .. " missing AbilityType")
	end

	if definition.AbilityType ~= "Passive" then
		local actual = tostring(definition.AbilityType)
		error(id .. " has AbilityType '" .. actual .. "' but should be 'Passive'")
	end

	local balanceEntry = BalanceTable.Abilities[id]
	if not balanceEntry then
		error("Passive " .. id .. " missing BalanceTable entry")
	end

	if not balanceEntry.IsPassive then
		error("Passive " .. id .. " BalanceTable entry missing IsPassive = true")
	end
end

local function isPassiveDefinition(definition)
	return definition.AbilityType == "Passive"
end

local function loadAbilities()
	for _, folder in ipairs(AbilityFolder:GetChildren()) do
		if folder:IsA("Folder") then
			for _, module in ipairs(folder:GetChildren()) do
				if module:IsA("ModuleScript") then
					local definition = require(module)

					if isPassiveDefinition(definition) then
						validatePassive(definition)

						local id = definition.NameId or definition.Id or definition.Name
						if passivesById[id] then
							error("Duplicate passive ID: " .. id)
						end

						passivesById[id] = definition
					else
						validateAbility(definition)

						if abilitiesById[definition.NameId] then
							error("Duplicate ability ID: " .. definition.NameId)
						end

						abilitiesById[definition.NameId] = definition
					end
				end
			end
		end
	end
end

-- Auto-initialize on first use (works for both server and client)
local function ensureInitialized()
	if not initialized then
		initialized = true
		loadAbilities()
	end
end

function AbilityRegistry.GetAbilityById(id)
	-- data is already validated and stored in abilitiesById, no need to validate again
	ensureInitialized()
	return abilitiesById[id]
end

function AbilityRegistry.AbilityExists(id)
	ensureInitialized()
	return abilitiesById[id] ~= nil
end

function AbilityRegistry.GetM1(abilityId)
	ensureInitialized()
	local ability = abilitiesById[abilityId]
	if not ability then return nil end

	-- BalanceTable is already required at module scope, don't re-require per call
	local balance = BalanceTable.Abilities[abilityId]
	if not balance then return nil end

	return {
		AbilityId = abilityId,
		AbilityType = ability.AbilityType,
		Damage = balance.AbilityDamage or 10,
		Cooldown = balance.AbilityCooldown or 0.5,
		WindupTime = balance.AbilityStartupTime or 0.1,
		RecoveryTime = balance.AbilityEndlag or 0.2,
		StunTime = balance.StunTime or 0,
		Knockback = balance.Knockback or 0,
		MaxTargets = balance.MaxTargets or 1,
		AnimationId = balance.AnimationId or "",
		Hitbox = ability.Hitbox,
	}
end

function AbilityRegistry.GetPassiveById(id)
	-- data is already validated and stored in passivesById
	ensureInitialized()
	return passivesById[id]
end

function AbilityRegistry.PassiveExists(id)
	ensureInitialized()
	return passivesById[id] ~= nil
end

function AbilityRegistry.GetAllPassives()
	ensureInitialized()
	local passives = {}
	for id, passive in pairs(passivesById) do
		table.insert(passives, {id = id, definition = passive})
	end
	return passives
end

function AbilityRegistry.Init()
	ensureInitialized()
	local passiveCount = 0
	for _ in pairs(passivesById) do
		passiveCount = passiveCount + 1
	end
	print(
		"AbilityRegistry loaded: ",
		#AbilityFolder:GetChildren(), " folders, ",
		#AbilityFolder:GetDescendants(), " total abilities (",
		passiveCount, " passives)"
	)
end

return AbilityRegistry
