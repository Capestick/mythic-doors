


local DOOR_ID_MAP = {}
local OX_DOOR_CACHE = {} 


local Callbacks, Logger, Utils, Fetch, Jobs, Properties

AddEventHandler('Doors:Shared:DependencyUpdate', RetrieveComponents)
function RetrieveComponents()
    Callbacks = exports['mythic-base']:FetchComponent('Callbacks')
    Logger = exports['mythic-base']:FetchComponent('Logger')
    Utils = exports['mythic-base']:FetchComponent('Utils')
    Fetch = exports['mythic-base']:FetchComponent('Fetch')
    Jobs = exports['mythic-base']:FetchComponent('Jobs')
    Properties = exports['mythic-base']:FetchComponent('Properties')
end


local function LoadDoorIdMap()
    local success, map = pcall(function()
        return exports['doors']:GetDoorIdMap()
    end)
    
    if success and map then
        DOOR_ID_MAP = map
    end
end


local function GetOxDoorId(doorId)
    
    if type(doorId) == 'string' then
        local mapped = DOOR_ID_MAP[doorId]
        if mapped then return mapped end
        
        
        if DOORS_IDS and DOORS_IDS[doorId] then
            return DOOR_ID_MAP[DOORS_IDS[doorId]]
        end
    else
        return DOOR_ID_MAP[doorId]
    end
    
    return nil
end


local function GetOxDoor(doorId)
    local oxId = GetOxDoorId(doorId)
    if not oxId then return nil end
    
    
    if OX_DOOR_CACHE[oxId] then
        return OX_DOOR_CACHE[oxId]
    end
    
    
    local success, door = pcall(function()
        return exports.ox_doorlock:getDoor(oxId)
    end)
    
    if success and door then
        OX_DOOR_CACHE[oxId] = door
        return door
    end
    
    return nil
end


local DOORS_IDS = {}
local function BuildDoorsIds()
    if not _doorConfig then return end
    for k, v in ipairs(_doorConfig) do
        if v.id and not DOORS_IDS[v.id] then
            DOORS_IDS[v.id] = k
        end
    end
end


local function InitializeElevatorCache()
    if not ELEVATOR_CACHE and _elevatorConfig then
        ELEVATOR_CACHE = {}
        for k, v in ipairs(_elevatorConfig) do
            ELEVATOR_CACHE[k] = {
                floors = {}
            }
            for k2, v2 in pairs(v.floors) do
                ELEVATOR_CACHE[k].floors[k2] = {
                    locked = v2.defaultLocked or false
                }
            end
        end
    end
end


local Logger = nil
local function RetrieveComponents()
    Logger = exports['mythic-base']:FetchComponent('Logger')
end


local function CheckPlayerAuth(source, doorPermissionData)
    if type(doorPermissionData) ~= 'table' or #doorPermissionData == 0 then
        return true
    end

    local player = Fetch:Source(source)
    if not player then return false end
    
    local char = player:GetData('Character')
    if not char then return false end
    
    local stateId = char:GetData('SID')

    
    if Jobs.Permissions:HasJob(source, 'dgang', false, false, 99, true) then
        return true
    end

    for _, v in ipairs(doorPermissionData) do
        if v.type == 'character' then
            if stateId == v.SID then
                return true
            end
        elseif v.type == 'job' then
            if v.job then
                if Jobs.Permissions:HasJob(source, v.job, v.workplace, v.grade, v.gradeLevel, v.reqDuty, v.jobPermission) then
                    return true
                end
            elseif v.jobPermission then
                if Jobs.Permissions:HasPermission(source, v.jobPermission) then
                    return true
                end
            end
        elseif v.type == 'propertyData' then
            if Properties.Keys:HasAccessWithData(source, v.key, v.value) then
                return true
            end
        end
    end
    
    return false
end


DOORS = {
    SetLock = function(self, doorId, newState, doneDouble)
        local oxId = GetOxDoorId(doorId)
        if not oxId then
            if Logger then
                Logger:Warn('Doors', 'Door ID not found in map: ' .. tostring(doorId))
            end
            return nil
        end

        local door = GetOxDoor(doorId)
        if not door then
            if Logger then
                Logger:Warn('Doors', 'Door not found in ox_doorlock: ' .. tostring(oxId))
            end
            return nil
        end

        local currentState = door.state == 1
        if newState == nil then
            newState = not currentState
        end

        
        local oxState = newState and 1 or 0

        
        local success = exports.ox_doorlock:setDoorState(oxId, oxState)
        
        if success then
            
            
            local doorIndex = nil
            if type(doorId) == 'string' then
                for i, d in ipairs(_doorConfig) do
                    if d.id == doorId then
                        doorIndex = i
                        break
                    end
                end
            else
                doorIndex = doorId
            end
            
            if doorIndex then
                TriggerClientEvent('Doors:Client:UpdateState', -1, doorIndex, newState)
            end
            
            if not doneDouble then
                
                local doorIndex = nil
                if type(doorId) == 'string' then
                    for i, d in ipairs(_doorConfig) do
                        if d.id == doorId then
                            doorIndex = i
                            break
                        end
                    end
                else
                    doorIndex = doorId
                end

                if doorIndex and _doorConfig[doorIndex] and _doorConfig[doorIndex].double then
                    local doubleId = _doorConfig[doorIndex].double
                    if type(doubleId) == 'string' then
                        
                        for i, d in ipairs(_doorConfig) do
                            if d.id == doubleId then
                                doubleId = i
                                break
                            end
                        end
                    end
                    if doubleId then
                        self:SetLock(doubleId, newState, true)
                    end
                end
            end

            
            OX_DOOR_CACHE[oxId] = nil
            
            return newState
        end

        return nil
    end,

    IsLocked = function(self, doorId)
        local oxId = GetOxDoorId(doorId)
        if not oxId then return false end

        local door = GetOxDoor(doorId)
        if not door then return false end

        return door.state == 1
    end,

    SetForcedOpen = function(self, doorId)
        local oxId = GetOxDoorId(doorId)
        if not oxId then return end

        
        exports.ox_doorlock:setDoorState(oxId, 0)
        
        
        local doorIndex = nil
        if type(doorId) == 'string' then
            for i, d in ipairs(_doorConfig) do
                if d.id == doorId then
                    doorIndex = i
                    break
                end
            end
        else
            doorIndex = doorId
        end
        
        if doorIndex then
            TriggerClientEvent('Doors:Client:SetForcedOpen', -1, doorIndex)
        end
        
        
        OX_DOOR_CACHE[oxId] = nil
    end,

    SetElevatorLock = function(self, elevatorId, floorId, newState)
        
        
        InitializeElevatorCache()
        
        local data = _elevatorConfig and _elevatorConfig[elevatorId] or nil

        if data and ELEVATOR_CACHE and ELEVATOR_CACHE[elevatorId] and ELEVATOR_CACHE[elevatorId].floors and ELEVATOR_CACHE[elevatorId].floors[floorId] then
            local isLocked = ELEVATOR_CACHE[elevatorId].floors[floorId].locked
            if newState == nil then
                newState = not isLocked
            end

            if data and newState ~= isLocked then
                ELEVATOR_CACHE[elevatorId].floors[floorId].locked = newState
                TriggerClientEvent('Doors:Client:UpdateElevatorState', -1, elevatorId, floorId, newState)
            end
            return newState
        end
        return nil
    end
}


AddEventHandler('Proxy:Shared:RegisterReady', function()
    exports['mythic-base']:RegisterComponent('Doors', DOORS)
end)


AddEventHandler('ox_doorlock:stateChanged', function(source, doorId, isLocked)
    
    OX_DOOR_CACHE[doorId] = nil
end)


AddEventHandler('Core:Shared:Ready', function()
    exports['mythic-base']:RequestDependencies('Doors', {
        'Callbacks',
        'Logger',
        'Utils',
        'Fetch',
        'Jobs',
        'Properties',
    }, function(error)
        if #error > 0 then return end
        RetrieveComponents()
        
        
        SetTimeout(3000, function()
            LoadDoorIdMap()
        end)
    end)
end)


AddEventHandler('Doors:Shared:DependencyUpdate', RetrieveComponents)


CreateThread(function()
    Wait(2000) 
    if _doorConfig then
        BuildDoorsIds()
    end
    
    InitializeElevatorCache()
end)
