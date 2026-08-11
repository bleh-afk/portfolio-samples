local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConstants = require(ReplicatedStorage.Shared.Core.GameConstants)

local AdminPermissionService = {}

function AdminPermissionService:Init()
	return self
end

function AdminPermissionService:IsAdmin(player)
	if not player then
		return false
	end

	return GameConstants.AllowedAdminUserIds[player.UserId] == true
end

function AdminPermissionService:RequireAdmin(player)
	if not self:IsAdmin(player) then
		return false, "Not authorized"
	end
	return true
end

return AdminPermissionService
