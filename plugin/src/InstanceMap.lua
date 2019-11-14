local Log = require(script.Parent.Parent.Log)

--[[
	A bidirectional map between instance IDs and Roblox instances. It lets us
	keep track of every instance we know about.

	TODO: Track ancestry to catch when stuff moves?
]]
local InstanceMap = {}
InstanceMap.__index = InstanceMap

function InstanceMap.new(onInstanceChanged)
	local self = {
		fromIds = {},
		fromInstances = {},
		instancesToSignal = {},
		onInstanceChanged = onInstanceChanged,
	}

	return setmetatable(self, InstanceMap)
end

function InstanceMap:debugState()
	local buffer = {}

	for id, instance in pairs(self.fromIds) do
		table.insert(buffer, string.format("- %s: %s", id, instance:GetFullName()))
	end

	return table.concat(buffer, "\n")
end

function InstanceMap:insert(id, instance)
	self.fromIds[id] = instance
	self.fromInstances[instance] = id
	self:__connectSignals(instance)
end

function InstanceMap:removeId(id)
	local instance = self.fromIds[id]

	if instance ~= nil then
		self:__disconnectSignals(instance)
		self.fromIds[id] = nil
		self.fromInstances[instance] = nil
	else
		Log.warn("Attempted to remove nonexistant ID %s", tostring(id))
	end
end

function InstanceMap:removeInstance(instance)
	local id = self.fromInstances[instance]
	self:__disconnectSignals(instance)

	if id ~= nil then
		self.fromInstances[instance] = nil
		self.fromIds[id] = nil
	else
		Log.warn("Attempted to remove nonexistant instance %s", tostring(instance))
	end
end

function InstanceMap:destroyInstance(instance)
	local id = self.fromInstances[instance]

	if id ~= nil then
		self:destroyId(id)
	else
		Log.warn("Attempted to destroy untracked instance %s", tostring(instance))
	end
end

function InstanceMap:destroyId(id)
	local instance = self.fromIds[id]
	self:removeId(id)

	if instance ~= nil then
		local descendantsToDestroy = {}

		for otherInstance in pairs(self.fromInstances) do
			if otherInstance:IsDescendantOf(instance) then
				table.insert(descendantsToDestroy, otherInstance)
			end
		end

		for _, otherInstance in ipairs(descendantsToDestroy) do
			self:removeInstance(otherInstance)
		end

		instance:Destroy()
	else
		Log.warn("Attempted to destroy nonexistant ID %s", tostring(id))
	end
end

function InstanceMap:__connectSignals(instance)
	-- TODO: Connect to different event for ValueBase objects?

	self.instancesToSignal[instance] = instance.Changed:Connect(function(propertyName)
		Log.trace("%s.%s changed", instance:GetFullName(), propertyName)

		if self.onInstanceChanged ~= nil then
			self.onInstanceChanged(instance, propertyName)
		end
	end)
end

function InstanceMap:__disconnectSignals(instance)
	if self.instancesToSignal[instance] ~= nil then
		self.instancesToSignal[instance]:Disconnect()
		self.instancesToSignal[instance] = nil
	end
end

return InstanceMap