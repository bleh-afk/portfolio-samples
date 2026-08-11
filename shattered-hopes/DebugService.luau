local GameConstants = require(game:GetService("ReplicatedStorage").Shared.Core.GameConstants)
local DummyUtil = require(game:GetService("ReplicatedStorage").Shared.Utilities.DummyUtil)

local DebugService = {}

DebugService._logs = {}

function DebugService:Init()
	return self
end

function DebugService:Add(level, source, message, data)
	level = tostring(level or "info"):lower()
	source = DummyUtil.SanitizeText(source or "System", 40)
	message = DummyUtil.SanitizeText(message or "", 140)

	local entry = {
		Time = os.clock(),
		Level = level,
		Source = source,
		Message = message,
		Data = data and DummyUtil.DeepCopy(data) or nil,
	}

	table.insert(self._logs, entry)
	if #self._logs > GameConstants.MaxLogs then
		table.remove(self._logs, 1)
	end

	return entry
end

function DebugService:Info(source, message, data)
	return self:Add("info", source, message, data)
end

function DebugService:Warn(source, message, data)
	return self:Add("warn", source, message, data)
end

function DebugService:Error(source, message, data)
	return self:Add("error", source, message, data)
end

function DebugService:GetRecentLogs()
	local copy = {}
	for i, entry in ipairs(self._logs) do
		copy[i] = {
			Time = entry.Time,
			Level = entry.Level,
			Source = entry.Source,
			Message = entry.Message,
			Data = entry.Data and DummyUtil.DeepCopy(entry.Data) or nil,
		}
	end
	return copy
end

function DebugService:Clear()
	table.clear(self._logs)
end

return DebugService
