-- ServiceLocator - Central service registry for dependency injection
-- Allows services to find each other without direct requires

local ServiceLocator = {}

local services = {}
local initialized = false

function ServiceLocator:Register(name, service)
	if services[name] then
		warn("Service already registered: " .. name)
		return
	end
	services[name] = service
end

function ServiceLocator:Get(name)
	return services[name]
end

function ServiceLocator:Has(name)
	return services[name] ~= nil
end

-- Bootstrap sets this once every service is registered. Handlers poll
-- IsInitialized before calling in, so they never resolve a half-built locator.
function ServiceLocator:SetInitialized(value)
	initialized = value
end

function ServiceLocator:IsInitialized()
	return initialized
end

return ServiceLocator
