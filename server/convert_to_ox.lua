


-- dont use fixing veriable. its fucked lol sorry not sorry xx
fixing = false

local _converted = false
local _converting = false
local _cleanupRun = false 
local DOOR_ID_MAP = {} 
local _unsupportedFeatures = {
    jobPermissions = {}, 
    propertyData = {}, 
    workplaceRestrictions = {}, 
    dutyRestrictions = {}, 
    complexJobRestrictions = {}, 
}


local Logger = nil
AddEventHandler('Doors:Shared:DependencyUpdate', RetrieveComponents)
function RetrieveComponents()
    Logger = exports['mythic-base']:FetchComponent('Logger')
end


function SafeLog(level, message, ...)
    if Logger then
        if Logger[level] then
            Logger[level]('Doors', message, ...)
        end
    else
        
        print(string.format('[Doors] [%s] %s', level:upper(), message))
    end
end


function CoordsToVector3(coords)
    if type(coords) == 'vector3' then
        return coords
    elseif type(coords) == 'table' then
        if coords.x and coords.y and coords.z then
            return vector3(coords.x, coords.y, coords.z)
        end
    end
    return nil
end


function MergeDoorData(existingData, newData)
    if not existingData then
        return newData
    end
    if not newData then
        return existingData
    end
    
    
    if not newData.model or not newData.coords or not newData.coords.x or not newData.coords.y or not newData.coords.z then
        return existingData 
    end
    
    local merged = {}
    
    
    merged.model = newData.model or existingData.model
    merged.heading = newData.heading or existingData.heading or 0
    merged.state = newData.state or existingData.state or 0
    
    
    if newData.coords then
        
        if type(newData.coords) == 'vector3' then
            merged.coords = { x = newData.coords.x, y = newData.coords.y, z = newData.coords.z }
        elseif type(newData.coords) == 'table' and newData.coords.x and newData.coords.y and newData.coords.z then
            merged.coords = { x = newData.coords.x, y = newData.coords.y, z = newData.coords.z }
        else
            merged.coords = newData.coords
        end
    elseif existingData.coords then
        
        if type(existingData.coords) == 'vector3' then
            merged.coords = { x = existingData.coords.x, y = existingData.coords.y, z = existingData.coords.z }
        elseif type(existingData.coords) == 'table' and existingData.coords.x and existingData.coords.y and existingData.coords.z then
            merged.coords = { x = existingData.coords.x, y = existingData.coords.y, z = existingData.coords.z }
        else
            merged.coords = existingData.coords
        end
    end
    
    
    if not merged.coords or not merged.coords.x or not merged.coords.y or not merged.coords.z then
        return existingData 
    end
    
    
    merged.lockpick = newData.lockpick or existingData.lockpick
    merged.passcode = newData.passcode or existingData.passcode
    
    merged.auto = newData.auto ~= nil and newData.auto or existingData.auto
    
    merged.maxDistance = newData.maxDistance or existingData.maxDistance or 2.0
    
    
    merged.groups = {}
    if existingData.groups then
        for job, grade in pairs(existingData.groups) do
            merged.groups[job] = grade
        end
    end
    if newData.groups then
        for job, grade in pairs(newData.groups) do
            
            if not merged.groups[job] or grade < merged.groups[job] then
                merged.groups[job] = grade
            end
        end
    end
    
    
    merged.characters = {}
    local charSet = {}
    if existingData.characters then
        for _, sid in ipairs(existingData.characters) do
            if not charSet[sid] then
                table.insert(merged.characters, sid)
                charSet[sid] = true
            end
        end
    end
    if newData.characters then
        for _, sid in ipairs(newData.characters) do
            if not charSet[sid] then
                table.insert(merged.characters, sid)
                charSet[sid] = true
            end
        end
    end
    
    
    merged.items = {}
    local itemSet = {}
    if existingData.items then
        for _, item in ipairs(existingData.items) do
            if not itemSet[item] then
                table.insert(merged.items, item)
                itemSet[item] = true
            end
        end
    end
    if newData.items then
        for _, item in ipairs(newData.items) do
            if not itemSet[item] then
                table.insert(merged.items, item)
                itemSet[item] = true
            end
        end
    end
    
    
    local mergedDoors = {}
    if existingData.doors then
        for _, door in ipairs(existingData.doors) do
            if door and type(door) == 'table' and door.model and door.coords then
                
                local doorCopy = {}
                for k, v in pairs(door) do
                    if k == 'coords' then
                        
                        if type(v) == 'vector3' then
                            doorCopy[k] = { x = v.x, y = v.y, z = v.z }
                        elseif type(v) == 'table' and v.x and v.y and v.z then
                            doorCopy[k] = { x = v.x, y = v.y, z = v.z }
                        else
                            doorCopy[k] = v
                        end
                    else
                        doorCopy[k] = v
                    end
                end
                table.insert(mergedDoors, doorCopy)
            end
        end
    end
    if newData.doors then
        for _, door in ipairs(newData.doors) do
            if door and type(door) == 'table' and door.model and door.coords then
                
                local exists = false
                local doorCoords = CoordsToVector3(door.coords)
                if doorCoords then
                    for _, existingDoor in ipairs(mergedDoors) do
                        if existingDoor.coords then
                            local existingCoords = CoordsToVector3(existingDoor.coords)
                            if existingCoords then
                                local dist = #(existingCoords - doorCoords)
                                if dist < 0.1 then
                                    exists = true
                                    break
                                end
                            end
                        end
                    end
                end
                if not exists then
                    
                    local doorCopy = {}
                    for k, v in pairs(door) do
                        if k == 'coords' then
                            if type(v) == 'vector3' then
                                doorCopy[k] = { x = v.x, y = v.y, z = v.z }
                            elseif type(v) == 'table' and v.x and v.y and v.z then
                                doorCopy[k] = { x = v.x, y = v.y, z = v.z }
                            else
                                doorCopy[k] = v
                            end
                        else
                            doorCopy[k] = v
                        end
                    end
                    table.insert(mergedDoors, doorCopy)
                end
            end
        end
    end
    
    
    if #mergedDoors == 2 then
        merged.doors = mergedDoors
    else
        merged.doors = nil 
    end
    
    return merged
end


function DoorDataEquals(data1, data2)
    if not data1 or not data2 then
        return data1 == data2
    end
    
    
    if data1.model ~= data2.model then return false end
    
    
    if data1.coords and data2.coords then
        local coords1 = CoordsToVector3(data1.coords)
        local coords2 = CoordsToVector3(data2.coords)
        if coords1 and coords2 then
            local dist = #(coords1 - coords2)
            if dist > 0.01 then return false end
        elseif coords1 ~= coords2 then
            return false
        end
    elseif data1.coords ~= data2.coords then
        return false
    end
    
    if (data1.heading or 0) ~= (data2.heading or 0) then return false end
    if (data1.state or 0) ~= (data2.state or 0) then return false end
    
    
    local groups1 = data1.groups or {}
    local groups2 = data2.groups or {}
    for job, grade in pairs(groups1) do
        if groups2[job] ~= grade then return false end
    end
    for job, grade in pairs(groups2) do
        if groups1[job] ~= grade then return false end
    end
    
    
    local chars1 = {}
    if data1.characters then
        for _, sid in ipairs(data1.characters) do
            chars1[sid] = true
        end
    end
    local chars2 = {}
    if data2.characters then
        for _, sid in ipairs(data2.characters) do
            chars2[sid] = true
        end
    end
    for sid in pairs(chars1) do
        if not chars2[sid] then return false end
    end
    for sid in pairs(chars2) do
        if not chars1[sid] then return false end
    end
    
    
    local items1 = {}
    if data1.items then
        for _, item in ipairs(data1.items) do
            items1[item] = true
        end
    end
    local items2 = {}
    if data2.items then
        for _, item in ipairs(data2.items) do
            items2[item] = true
        end
    end
    for item in pairs(items1) do
        if not items2[item] then return false end
    end
    for item in pairs(items2) do
        if not items1[item] then return false end
    end
    
    return true
end




function ConvertRestrictedAccess(restricted, doorName)
    if not restricted or type(restricted) ~= 'table' or #restricted == 0 then
        return nil, nil, nil
    end

    local groups = {}
    local characters = {}
    local items = {}

    for _, restriction in ipairs(restricted) do
        if restriction.type == 'job' then
            if restriction.job then
                
                
                local minGrade = restriction.gradeLevel or 0
                
                
                
                if not groups[restriction.job] then
                    groups[restriction.job] = minGrade
                else
                    
                    if minGrade < groups[restriction.job] then
                        groups[restriction.job] = minGrade
                    end
                end
                
                
                
                if restriction.workplace and restriction.workplace ~= false then
                    if not _unsupportedFeatures.workplaceRestrictions[doorName] then
                        _unsupportedFeatures.workplaceRestrictions[doorName] = {}
                    end
                    table.insert(_unsupportedFeatures.workplaceRestrictions[doorName], {
                        job = restriction.job,
                        workplace = restriction.workplace
                    })
                end
                
                if restriction.reqDuty then
                    if not _unsupportedFeatures.dutyRestrictions[doorName] then
                        _unsupportedFeatures.dutyRestrictions[doorName] = {}
                    end
                    table.insert(_unsupportedFeatures.dutyRestrictions[doorName], {
                        job = restriction.job,
                        reqDuty = restriction.reqDuty
                    })
                end
                
                if restriction.jobPermission and restriction.jobPermission ~= false then
                    if not _unsupportedFeatures.complexJobRestrictions[doorName] then
                        _unsupportedFeatures.complexJobRestrictions[doorName] = {}
                    end
                    table.insert(_unsupportedFeatures.complexJobRestrictions[doorName], {
                        job = restriction.job,
                        jobPermission = restriction.jobPermission
                    })
                end
                
                
            elseif restriction.jobPermission then
                
                if not _unsupportedFeatures.jobPermissions[doorName] then
                    _unsupportedFeatures.jobPermissions[doorName] = {}
                end
                table.insert(_unsupportedFeatures.jobPermissions[doorName], {
                    jobPermission = restriction.jobPermission
                })
            end
        elseif restriction.type == 'character' then
            if restriction.SID then
                
                local sid = tonumber(restriction.SID) or restriction.SID
                table.insert(characters, sid)
            end
        elseif restriction.type == 'propertyData' then
            
            if not _unsupportedFeatures.propertyData[doorName] then
                _unsupportedFeatures.propertyData[doorName] = {}
            end
            table.insert(_unsupportedFeatures.propertyData[doorName], {
                key = restriction.key,
                value = restriction.value
            })
        end
    end

    
    if next(groups) == nil then groups = nil end
    if #characters == 0 then characters = nil end
    if #items == 0 then items = nil end

    return groups, characters, items
end


function CalculateHeading(coords)
    if not coords then
        return 0
    end
    if type(coords) == 'vector4' then
        return coords.w or 0
    elseif type(coords) == 'table' then
        if coords.w then
            return coords.w
        elseif coords.heading then
            return coords.heading
        end
    end
    return 0
end


function ConvertDoorToOx(door, doorIndex)
    if not door.model or not door.coords then
        return nil, nil
    end

    local doorName = door.id or ('door_' .. doorIndex)
    
    
    local coords = door.coords
    local heading = CalculateHeading(coords) or 0
    
    
    if type(coords) == 'vector4' then
        coords = vector3(coords.x, coords.y, coords.z)
    elseif type(coords) == 'table' and coords.w then
        coords = vector3(coords.x, coords.y, coords.z)
    elseif type(coords) == 'table' and coords.x and coords.y and coords.z then
        
        coords = vector3(coords.x, coords.y, coords.z)
    end
    
    
    if not heading or type(heading) ~= 'number' then
        heading = 0
    end

    
    local groups, characters, items = ConvertRestrictedAccess(door.restricted, doorName)

    
    
    local model = tonumber(door.model) or door.model
    if not model or not coords then
        return nil, nil
    end
    
    
    local coordsTable = nil
    if type(coords) == 'vector3' then
        coordsTable = { x = coords.x, y = coords.y, z = coords.z }
    elseif type(coords) == 'table' and coords.x and coords.y and coords.z then
        coordsTable = { x = coords.x, y = coords.y, z = coords.z }
    else
        return nil, nil
    end
    
    
    if not coordsTable.x or not coordsTable.y or not coordsTable.z then
        return nil, nil
    end
    if type(coordsTable.x) ~= 'number' or type(coordsTable.y) ~= 'number' or type(coordsTable.z) ~= 'number' then
        return nil, nil
    end
    
    
    local headingNum = math.floor(heading + 0.5)
    if type(headingNum) ~= 'number' or headingNum ~= headingNum then 
        headingNum = 0
    end
    
    
    local isGarageDoor = false
    if doorName and string.find(string.lower(doorName), "garage") then
        isGarageDoor = true
    elseif door.autoRate or door.autoDist then
        isGarageDoor = true
    end
    
    local oxDoor = {
        model = model,
        coords = coordsTable,
        heading = headingNum,
        state = door.locked and 1 or 0,
        maxDistance = door.maxDist or (isGarageDoor and 5.0 or 2.0), 
    }
    
    
    if isGarageDoor then
        oxDoor.auto = true
    end
    
    
    if door.canLockpick == true then
        oxDoor.lockpick = true
    end
    
    if groups and next(groups) then
        oxDoor.groups = groups
    end
    if characters and #characters > 0 then
        oxDoor.characters = characters
    end
    if items and #items > 0 then
        oxDoor.items = items
    end
    if door.passcode then
        oxDoor.passcode = door.passcode
    end

    
    if door.double then
        local doubleDoorIndex = nil
        if type(door.double) == 'string' then
            for i, d in ipairs(_doorConfig) do
                if d.id == door.double then
                    doubleDoorIndex = i
                    break
                end
            end
        else
            doubleDoorIndex = door.double
        end

        if doubleDoorIndex and _doorConfig[doubleDoorIndex] then
            local doubleDoor = _doorConfig[doubleDoorIndex]
            if doubleDoor.model and doubleDoor.coords then
                local doubleCoords = doubleDoor.coords
                if type(doubleCoords) == 'vector4' then
                    doubleCoords = vector3(doubleCoords.x, doubleCoords.y, doubleCoords.z)
                elseif type(doubleCoords) == 'table' and doubleCoords.w then
                    doubleCoords = vector3(doubleCoords.x, doubleCoords.y, doubleCoords.z)
                end
                
                local doubleHeading = CalculateHeading(doubleDoor.coords) or 0
                local doubleModel = tonumber(doubleDoor.model) or doubleDoor.model
                
                if doubleModel and doubleCoords then
                    
                    local doubleCoordsTable = nil
                    if type(doubleCoords) == 'vector3' then
                        doubleCoordsTable = { x = doubleCoords.x, y = doubleCoords.y, z = doubleCoords.z }
                    elseif type(doubleCoords) == 'table' and doubleCoords.x and doubleCoords.y and doubleCoords.z then
                        doubleCoordsTable = { x = doubleCoords.x, y = doubleCoords.y, z = doubleCoords.z }
                    end
                    
                    if doubleCoordsTable and doubleModel then
                        
                        if type(doubleCoordsTable.x) == 'number' and type(doubleCoordsTable.y) == 'number' and type(doubleCoordsTable.z) == 'number' then
                            
                            
                            oxDoor.doors = {
                                {
                                    model = model,
                                    coords = coordsTable,
                                    heading = headingNum,
                                },
                                {
                                    model = doubleModel,
                                    coords = doubleCoordsTable,
                                    heading = math.floor(doubleHeading + 0.5),
                                }
                            }
                        end
                    end
                end
            end
        end
    end

    
    if not oxDoor.model or not oxDoor.coords or not oxDoor.coords.x or not oxDoor.coords.y or not oxDoor.coords.z then
        return nil, nil
    end
    
    
    if oxDoor.doors and type(oxDoor.doors) == 'table' then
        local validDoors = {}
        for _, door in ipairs(oxDoor.doors) do
            if door and type(door) == 'table' and door.model and door.coords and door.coords.x and door.coords.y and door.coords.z then
                if type(door.coords.x) == 'number' and type(door.coords.y) == 'number' and type(door.coords.z) == 'number' then
                    table.insert(validDoors, door)
                end
            end
        end
        if #validDoors == 2 then
            
            oxDoor.doors = validDoors
        else
            
            oxDoor.doors = nil
        end
    end
    
    return oxDoor, doorName
end


function IsConvertedDoor(doorName)
    if not doorName then return false end
    
    
    for _, doorConfig in ipairs(_doorConfig) do
        if doorConfig.id == doorName then
            return true
        end
    end
    
    
    if string.match(doorName, '^door_%d+$') then
        return true
    end
    
    return false
end


function CleanupInvalidDoors()
    if not MySQL then
        return false
    end
    
    
    if fixing then
        SafeLog('Warn', 'Fixing flag is set - deleting all converted doors for re-conversion...')
        
        local allDoors = MySQL.query.await('SELECT id, name FROM ox_doorlock')
        if not allDoors or #allDoors == 0 then
            SafeLog('Info', 'No doors found in database')
            _converted = false
            return true
        end
        
        local deletedCount = 0
        for _, door in ipairs(allDoors) do
            if IsConvertedDoor(door.name) then
                MySQL.query.await('DELETE FROM ox_doorlock WHERE id = ?', { door.id })
                deletedCount = deletedCount + 1
            end
        end
        
        SafeLog('Warn', string.format('Deleted ^3%d^7 converted doors - will re-convert', deletedCount))
        _converted = false
        return true
    end
    
    SafeLog('Info', 'Validating and cleaning up invalid doors in database...')
    
    local allDoors = MySQL.query.await('SELECT id, name, data FROM ox_doorlock')
    if not allDoors or #allDoors == 0 then
        SafeLog('Info', 'No doors found in database')
        return false
    end
    
    SafeLog('Info', string.format('Checking ^3%d^7 doors for validity...', #allDoors))
    
    local invalidDoors = {}
    local fixedDoors = 0
    local convertedDoorsToDelete = {} 
    
    
    for _, door in ipairs(allDoors) do
        local isConverted = IsConvertedDoor(door.name)
        
        
        if not door.data then
            if isConverted then
                table.insert(invalidDoors, door.id)
                table.insert(convertedDoorsToDelete, door.id)
            else
                SafeLog('Warn', string.format('User door ID %d (%s) has no data - may cause ox_doorlock errors', door.id, door.name or 'unknown'))
            end
        else
            local success, doorData = pcall(json.decode, door.data)
            if not success or not doorData then
                if isConverted then
                    table.insert(invalidDoors, door.id)
                    table.insert(convertedDoorsToDelete, door.id)
                else
                    SafeLog('Warn', string.format('User door ID %d (%s) has invalid JSON - may cause ox_doorlock errors', door.id, door.name or 'unknown'))
                end
            else
                
                local hasRequiredFields = doorData.model and doorData.coords and doorData.coords.x and doorData.coords.y and doorData.coords.z
                local hasValidTypes = hasRequiredFields and 
                    type(doorData.model) == 'number' and 
                    type(doorData.coords.x) == 'number' and 
                    type(doorData.coords.y) == 'number' and 
                    type(doorData.coords.z) == 'number' and
                    (doorData.heading == nil or type(doorData.heading) == 'number') and
                    (doorData.state == nil or type(doorData.state) == 'number')
                
                if not hasRequiredFields or not hasValidTypes then
                    if isConverted then
                        SafeLog('Warn', string.format('Converted door ID %d (%s) missing required fields or invalid types', door.id, door.name or 'unknown'))
                        table.insert(invalidDoors, door.id)
                        table.insert(convertedDoorsToDelete, door.id)
                    else
                        SafeLog('Error', string.format('USER DOOR ID %d (%s) IS INVALID - This may be causing the ox_doorlock error! Missing: model=%s, coords=%s, coords.x=%s, coords.y=%s, coords.z=%s', 
                            door.id, door.name or 'unknown',
                            tostring(doorData.model ~= nil),
                            tostring(doorData.coords ~= nil),
                            tostring(doorData.coords and doorData.coords.x ~= nil),
                            tostring(doorData.coords and doorData.coords.y ~= nil),
                            tostring(doorData.coords and doorData.coords.z ~= nil)))
                    end
                elseif isConverted then
                    
                    
                    local isValid = true
                    local needsFix = false
                    local fixedData = {}
                    
                    
                    if not doorData.model then
                        isValid = false
                    else
                        fixedData.model = tonumber(doorData.model) or doorData.model
                        if not fixedData.model then
                            isValid = false
                        end
                    end
                    
                    
                    if not doorData.coords then
                        isValid = false
                    else
                        local coords = doorData.coords
                        if type(coords) == 'table' and coords.x and coords.y and coords.z then
                            if type(coords.x) == 'number' and type(coords.y) == 'number' and type(coords.z) == 'number' then
                                fixedData.coords = { x = coords.x, y = coords.y, z = coords.z }
                            else
                                isValid = false
                            end
                        elseif type(coords) == 'vector3' then
                            fixedData.coords = { x = coords.x, y = coords.y, z = coords.z }
                            needsFix = true
                        else
                            isValid = false
                        end
                    end
                    
                    
                    if doorData.heading == nil then
                        fixedData.heading = 0
                        needsFix = true
                    else
                        fixedData.heading = math.floor((tonumber(doorData.heading) or 0) + 0.5)
                    end
                    
                    
                    if doorData.state == nil then
                        fixedData.state = 0
                        needsFix = true
                    else
                        fixedData.state = doorData.state == 1 and 1 or 0
                    end
                    
                    
                    if doorData.doors and type(doorData.doors) == 'table' then
                        local validDoors = {}
                        for _, door in ipairs(doorData.doors) do
                            if door and type(door) == 'table' and door.model and door.coords then
                                local doorCoords = door.coords
                                if type(doorCoords) == 'table' and doorCoords.x and doorCoords.y and doorCoords.z then
                                    if type(doorCoords.x) == 'number' and type(doorCoords.y) == 'number' and type(doorCoords.z) == 'number' then
                                        local validDoor = {
                                            model = tonumber(door.model) or door.model,
                                            coords = { x = doorCoords.x, y = doorCoords.y, z = doorCoords.z },
                                            heading = math.floor((tonumber(door.heading) or 0) + 0.5)
                                        }
                                        if validDoor.model then
                                            table.insert(validDoors, validDoor)
                                        end
                                    end
                                end
                            end
                        end
                        if #validDoors > 0 then
                            fixedData.doors = validDoors
                            if #validDoors ~= #doorData.doors then
                                needsFix = true
                            end
                        elseif #doorData.doors > 0 then
                            
                            fixedData.doors = nil
                            needsFix = true
                        end
                    end
                    
                    if not isValid then
                        SafeLog('Warn', string.format('Converted door ID %d (%s) is invalid - will be removed', door.id, door.name or 'unknown'))
                        table.insert(invalidDoors, door.id)
                        table.insert(convertedDoorsToDelete, door.id)
                    elseif needsFix or (doorData.doors and #doorData.doors > 0 and not fixedData.doors) then
                        
                        SafeLog('Warn', string.format('Converted door ID %d (%s) needs fixing - will be re-converted', door.id, door.name or 'unknown'))
                        table.insert(convertedDoorsToDelete, door.id)
                    end
                end
            end
        end
    end
    
    
    local criticalInvalidDoors = {}
    local allDoorsCheck = MySQL.query.await('SELECT id, name, data FROM ox_doorlock')
    if allDoorsCheck then
        for _, door in ipairs(allDoorsCheck) do
            if door.data then
                local success, doorData = pcall(json.decode, door.data)
                if success and doorData then
                    
                    if not doorData.model or type(doorData.model) ~= 'number' then
                        table.insert(criticalInvalidDoors, {id = door.id, name = door.name, reason = 'missing or invalid model'})
                    elseif not doorData.coords or not doorData.coords.x or not doorData.coords.y or not doorData.coords.z then
                        table.insert(criticalInvalidDoors, {id = door.id, name = door.name, reason = 'missing or invalid coords'})
                    elseif type(doorData.coords.x) ~= 'number' or type(doorData.coords.y) ~= 'number' or type(doorData.coords.z) ~= 'number' then
                        table.insert(criticalInvalidDoors, {id = door.id, name = door.name, reason = 'coords not numbers'})
                    end
                end
            end
        end
    end
    
    if #criticalInvalidDoors > 0 then
        SafeLog('Error', string.format('Found ^1%d^7 doors with CRITICAL missing fields that will cause ox_doorlock to fail:', #criticalInvalidDoors))
        for _, invalidDoor in ipairs(criticalInvalidDoors) do
            SafeLog('Error', string.format('  - Door ID %d (%s): %s', invalidDoor.id, invalidDoor.name or 'unknown', invalidDoor.reason))
            
            MySQL.query.await('DELETE FROM ox_doorlock WHERE id = ?', { invalidDoor.id })
        end
        SafeLog('Warn', string.format('Deleted ^1%d^7 critical invalid doors', #criticalInvalidDoors))
        return true 
    end
    
    
    if #convertedDoorsToDelete > 0 then
        SafeLog('Warn', string.format('Found ^3%d^7 converted doors with issues - deleting all converted doors for re-conversion', #convertedDoorsToDelete))
        
        
        local allConvertedDoors = MySQL.query.await('SELECT id, name FROM ox_doorlock')
        local deletedCount = 0
        for _, door in ipairs(allConvertedDoors) do
            if IsConvertedDoor(door.name) then
                MySQL.query.await('DELETE FROM ox_doorlock WHERE id = ?', { door.id })
                deletedCount = deletedCount + 1
            end
        end
        
        SafeLog('Warn', string.format('Deleted ^3%d^7 converted doors - will re-convert on next run', deletedCount))
        
        
        _converted = false
        
        return true 
    end
    
    
    if #invalidDoors > 0 then
        for _, doorId in ipairs(invalidDoors) do
            MySQL.query.await('DELETE FROM ox_doorlock WHERE id = ?', { doorId })
        end
        SafeLog('Warn', string.format('Removed ^3%d^7 invalid doors from database', #invalidDoors))
    end
    
    if fixedDoors > 0 then
        SafeLog('Info', string.format('Fixed ^2%d^7 doors in database', fixedDoors))
    end
    
    if #invalidDoors == 0 and fixedDoors == 0 and #convertedDoorsToDelete == 0 then
        SafeLog('Info', 'All converted doors are valid')
    end
    
    if #invalidDoors > 0 or fixedDoors > 0 or #convertedDoorsToDelete > 0 then
        return true
    end
    
    return false
end


function CleanupDuplicates()
    SafeLog('Info', 'Checking for duplicate doors...')
    
    local allDoors = MySQL.query.await('SELECT id, name, data FROM ox_doorlock ORDER BY id ASC')
    if not allDoors or #allDoors == 0 then
        return false
    end
    
    local doorGroups = {} 
    local duplicatesToRemove = {}
    
    
    for _, door in ipairs(allDoors) do
        local doorData = json.decode(door.data)
        if doorData and doorData.model and doorData.coords then
            
            local coords = doorData.coords
            local key = string.format('%s_%.2f_%.2f_%.2f', doorData.model, coords.x, coords.y, coords.z)
            
            if not doorGroups[key] then
                doorGroups[key] = {}
            end
            table.insert(doorGroups[key], {
                id = door.id,
                name = door.name,
                data = doorData
            })
        end
    end
    
    
    for key, doors in pairs(doorGroups) do
        if #doors > 1 then
            
            table.sort(doors, function(a, b) return a.id < b.id end)
            
            for i = 2, #doors do
                table.insert(duplicatesToRemove, doors[i].id)
                SafeLog('Warn', string.format('Found duplicate door: ID %d (%s) - same as ID %d (%s)', 
                    doors[i].id, doors[i].name, doors[1].id, doors[1].name))
            end
        end
    end
    
    
    if #duplicatesToRemove > 0 then
        SafeLog('Warn', string.format('Removing ^3%d^7 duplicate doors...', #duplicatesToRemove))
        
        for _, doorId in ipairs(duplicatesToRemove) do
            MySQL.update.await('DELETE FROM ox_doorlock WHERE id = ?', { doorId })
        end
        
        SafeLog('Info', string.format('Removed ^3%d^7 duplicate doors', #duplicatesToRemove))
        return true 
    else
        SafeLog('Info', 'No duplicate doors found')
        return false 
    end
end

function ConvertDoorsToOx()
    if _converted or _converting then 
        SafeLog('Trace', 'Conversion already completed or in progress, skipping...')
        return 
    end
    _converting = true

    SafeLog('Info', 'Starting conversion to ox_doorlock...')

    
    if not MySQL then
        SafeLog('Error', 'MySQL not available for conversion')
        return
    end

    MySQL.ready(function()
        local convertedCount = 0
        local skippedCount = 0
        local updatedCount = 0
        local insertedCount = 0
        local hasChanges = false
        local doubleDoorsProcessed = {}
        local processedDoors = {} 
        
        
        for doorIndex, door in ipairs(_doorConfig) do
            if processedDoors[doorIndex] then
                goto continue
            end
            
            
            local isDoubleDoorPart = false
            local doubleDoorIndex = nil
            
            if door.double then
                if type(door.double) == 'string' then
                    
                    for i, d in ipairs(_doorConfig) do
                        if d.id == door.double then
                            doubleDoorIndex = i
                            break
                        end
                    end
                else
                    doubleDoorIndex = door.double
                end
                
                if doubleDoorIndex then
                    isDoubleDoorPart = true
                end
            end
            
            
            
            if isDoubleDoorPart and doubleDoorIndex and doubleDoorIndex < doorIndex then
                
                skippedCount = skippedCount + 1
                goto continue
            end

            local oxDoor, doorName = ConvertDoorToOx(door, doorIndex)
            
            if oxDoor then
                
                local existing = MySQL.query.await('SELECT id, data FROM ox_doorlock WHERE name = ?', { doorName })
                
                if existing and #existing > 0 then
                    
                    local doorId = existing[1].id
                    local existingDataJson = existing[1].data
                    local success, existingData = pcall(json.decode, existingDataJson)
                    if not success or not existingData then
                        SafeLog('Warn', string.format('Skipping door %s - failed to decode existing data', doorName))
                        skippedCount = skippedCount + 1
                        goto continue
                    end
                    
                    DOOR_ID_MAP[doorIndex] = doorId
                    if door.id then
                        DOOR_ID_MAP[door.id] = doorId
                    end
                    
                    
                    if doubleDoorIndex and _doorConfig[doubleDoorIndex] then
                        DOOR_ID_MAP[doubleDoorIndex] = doorId
                        if _doorConfig[doubleDoorIndex].id then
                            DOOR_ID_MAP[_doorConfig[doubleDoorIndex].id] = doorId
                        end
                        processedDoors[doubleDoorIndex] = true
                    end
                    
                    
                    local mergedData = MergeDoorData(existingData, oxDoor)
                    
                    
                    if not mergedData.model or not mergedData.coords or not mergedData.coords.x or not mergedData.coords.y or not mergedData.coords.z then
                        SafeLog('Warn', string.format('Skipping door %s - invalid merged data', doorName))
                        skippedCount = skippedCount + 1
                        goto continue
                    end
                    
                    local mergedDataJson = json.encode(mergedData)
                    
                    
                    if not DoorDataEquals(existingData, mergedData) then
                        MySQL.update.await('UPDATE ox_doorlock SET data = ? WHERE id = ?', {
                            mergedDataJson,
                            doorId
                        })
                        updatedCount = updatedCount + 1
                        hasChanges = true
                    end
                    convertedCount = convertedCount + 1
                else
                    
                    local coordsCheck = MySQL.query.await('SELECT id, name, data FROM ox_doorlock')
                    local foundExisting = false
                    local existingId = nil
                    local existingDoorData = nil
                    
                    if coordsCheck then
                        for _, existingDoor in ipairs(coordsCheck) do
                            if existingDoor.data then
                                local success, existingData = pcall(json.decode, existingDoor.data)
                                if success and existingData and existingData.model == oxDoor.model and existingData.coords then
                                    local existingCoords = CoordsToVector3(existingData.coords)
                                    local newCoords = CoordsToVector3(oxDoor.coords)
                                    if existingCoords and newCoords then
                                        local dist = #(existingCoords - newCoords)
                                        if dist < 0.5 then
                                            foundExisting = true
                                            existingId = existingDoor.id
                                            existingDoorData = existingDoor
                                            
                                            
                                            if existingDoor.name ~= doorName then
                                                MySQL.update.await('UPDATE ox_doorlock SET name = ? WHERE id = ?', {
                                                    doorName,
                                                    existingId
                                                })
                                                hasChanges = true
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    if foundExisting and existingId then
                        
                        DOOR_ID_MAP[doorIndex] = existingId
                        if door.id then
                            DOOR_ID_MAP[door.id] = existingId
                        end
                        
                        if doubleDoorIndex and _doorConfig[doubleDoorIndex] then
                            DOOR_ID_MAP[doubleDoorIndex] = existingId
                            if _doorConfig[doubleDoorIndex].id then
                                DOOR_ID_MAP[_doorConfig[doubleDoorIndex].id] = existingId
                            end
                            processedDoors[doubleDoorIndex] = true
                        end
                        
                        
                        local existingData = json.decode(existingDoorData.data)
                        local mergedData = MergeDoorData(existingData, oxDoor)
                        
                        
                        if not mergedData.model or not mergedData.coords or not mergedData.coords.x or not mergedData.coords.y or not mergedData.coords.z then
                            SafeLog('Warn', string.format('Skipping door %s - invalid merged data', doorName))
                            skippedCount = skippedCount + 1
                            goto continue
                        end
                        
                        local mergedDataJson = json.encode(mergedData)
                        
                        
                        if not DoorDataEquals(existingData, mergedData) then
                            MySQL.update.await('UPDATE ox_doorlock SET data = ? WHERE id = ?', {
                                mergedDataJson,
                                existingId
                            })
                            updatedCount = updatedCount + 1
                            hasChanges = true
                        end
                        convertedCount = convertedCount + 1
                    else
                        
                        
                        if not oxDoor.model or not oxDoor.coords or not oxDoor.coords.x or not oxDoor.coords.y or not oxDoor.coords.z then
                            SafeLog('Warn', string.format('Skipping door %s - invalid door data', doorName))
                            skippedCount = skippedCount + 1
                            goto continue
                        end
                        
                        local insertId = MySQL.insert.await('INSERT INTO ox_doorlock (name, data) VALUES (?, ?)', {
                            doorName,
                            json.encode(oxDoor)
                        })
                        
                        if insertId then
                            DOOR_ID_MAP[doorIndex] = insertId
                            if door.id then
                                DOOR_ID_MAP[door.id] = insertId
                            end
                            
                            
                            if doubleDoorIndex and _doorConfig[doubleDoorIndex] then
                                DOOR_ID_MAP[doubleDoorIndex] = insertId
                                if _doorConfig[doubleDoorIndex].id then
                                    DOOR_ID_MAP[_doorConfig[doubleDoorIndex].id] = insertId
                                end
                                processedDoors[doubleDoorIndex] = true
                            end
                            
                            insertedCount = insertedCount + 1
                            hasChanges = true
                            convertedCount = convertedCount + 1
                        end
                    end
                end

                processedDoors[doorIndex] = true
            else
                skippedCount = skippedCount + 1
            end

            ::continue::
        end

        
        local duplicatesRemoved = CleanupDuplicates()
        if duplicatesRemoved then
            hasChanges = true
        end
        
        
        SafeLog('Info', 'Running post-conversion cleanup...')
        local hadInvalid = CleanupInvalidDoors()
        if hadInvalid then
            
            if not _converted then
                SafeLog('Info', 'Re-running conversion after cleanup...')
                _converting = false
                ConvertDoorsToOx() 
                return
            end
            hasChanges = true
        end
        
        _converted = true
        _converting = false

        SafeLog('Info', string.format('Converted ^2%d^7 doors to ox_doorlock (skipped %d, updated %d, inserted %d)', 
            convertedCount, skippedCount, updatedCount, insertedCount))
        
        
        local unsupportedDoors = {} 
        local unsupportedDetails = {}
        
        for featureType, doors in pairs(_unsupportedFeatures) do
            local doorCount = 0
            for doorName, data in pairs(doors) do
                if not unsupportedDoors[doorName] then
                    unsupportedDoors[doorName] = true
                end
                doorCount = doorCount + 1
            end
            if doorCount > 0 then
                unsupportedDetails[featureType] = {
                    count = doorCount
                }
            end
        end
        
        local uniqueUnsupportedCount = 0
        for _ in pairs(unsupportedDoors) do
            uniqueUnsupportedCount = uniqueUnsupportedCount + 1
        end
        
        if uniqueUnsupportedCount > 0 then
            SafeLog('Info', string.format('^3%d^7 doors converted with additional restrictions handled by bridge:', uniqueUnsupportedCount))
            
            if unsupportedDetails.jobPermissions then
                SafeLog('Info', string.format('  - ^3%d^7 doors have jobPermission restrictions (bridge handles)', unsupportedDetails.jobPermissions.count))
            end
            if unsupportedDetails.propertyData then
                SafeLog('Info', string.format('  - ^3%d^7 doors have propertyData restrictions (bridge handles)', unsupportedDetails.propertyData.count))
            end
            if unsupportedDetails.workplaceRestrictions then
                SafeLog('Info', string.format('  - ^3%d^7 doors have workplace restrictions (bridge handles)', unsupportedDetails.workplaceRestrictions.count))
            end
            if unsupportedDetails.dutyRestrictions then
                SafeLog('Info', string.format('  - ^3%d^7 doors have reqDuty restrictions (bridge handles)', unsupportedDetails.dutyRestrictions.count))
            end
            if unsupportedDetails.complexJobRestrictions then
                SafeLog('Info', string.format('  - ^3%d^7 doors have complex job restrictions (bridge handles)', unsupportedDetails.complexJobRestrictions.count))
            end
        end
        
        
        
        if hasChanges then
            SafeLog('Info', 'Changes detected - restarting ox_doorlock resource...')
            
            
            
            print('^3[DOORS]^0restart ox_doorlock resource')
        else
            SafeLog('Info', 'No changes detected - skipping ox_doorlock restart')
        end
    end) 
end


function AggressivelyFindAndDeleteInvalidDoors()
    if not MySQL then
        return 0
    end
    
    SafeLog('Warn', 'Aggressively scanning all doors for issues that would cause ox_doorlock errors...')
    
    local allDoors = MySQL.query.await('SELECT id, name, data FROM ox_doorlock')
    if not allDoors or #allDoors == 0 then
        return 0
    end
    
    local deletedCount = 0
    local problematicDoors = {}
    
    for _, door in ipairs(allDoors) do
        if not door.data then
            table.insert(problematicDoors, {id = door.id, name = door.name, reason = 'missing data field'})
        else
            local success, doorData = pcall(json.decode, door.data)
            if not success or not doorData then
                table.insert(problematicDoors, {id = door.id, name = door.name, reason = 'invalid JSON'})
            else
                
                local issues = {}
                
                
                if not doorData.model then
                    table.insert(issues, 'missing model')
                elseif type(doorData.model) ~= 'number' then
                    table.insert(issues, 'model is not a number')
                end
                
                
                if not doorData.coords then
                    table.insert(issues, 'missing coords')
                else
                    if type(doorData.coords) ~= 'table' then
                        table.insert(issues, 'coords is not a table')
                    else
                        if not doorData.coords.x or type(doorData.coords.x) ~= 'number' then
                            table.insert(issues, 'coords.x missing or not number')
                        end
                        if not doorData.coords.y or type(doorData.coords.y) ~= 'number' then
                            table.insert(issues, 'coords.y missing or not number')
                        end
                        if not doorData.coords.z or type(doorData.coords.z) ~= 'number' then
                            table.insert(issues, 'coords.z missing or not number')
                        end
                    end
                end
                
                
                if doorData.heading ~= nil and type(doorData.heading) ~= 'number' then
                    table.insert(issues, 'heading is not a number')
                end
                
                
                if doorData.state ~= nil and type(doorData.state) ~= 'number' then
                    table.insert(issues, 'state is not a number')
                end
                
                
                if doorData.doors then
                    if type(doorData.doors) ~= 'table' then
                        table.insert(issues, 'doors is not a table')
                    else
                        
                        
                        if #doorData.doors == 0 then
                            table.insert(issues, 'doors array is empty (should be removed or have exactly 2 entries)')
                        elseif #doorData.doors ~= 2 then
                            table.insert(issues, string.format('doors array must have exactly 2 entries, found %d', #doorData.doors))
                        else
                            
                            if not doorData.doors[1] or type(doorData.doors[1]) ~= 'table' then
                                table.insert(issues, 'doors[1] missing or not a table')
                            end
                            if not doorData.doors[2] or type(doorData.doors[2]) ~= 'table' then
                                table.insert(issues, 'doors[2] missing or not a table')
                            end
                        end
                        for i, doorEntry in ipairs(doorData.doors) do
                            if type(doorEntry) ~= 'table' then
                                table.insert(issues, string.format('doors[%d] is not a table', i))
                            else
                                if not doorEntry.model or type(doorEntry.model) ~= 'number' then
                                    table.insert(issues, string.format('doors[%d].model missing or invalid', i))
                                end
                                if not doorEntry.coords then
                                    table.insert(issues, string.format('doors[%d].coords missing', i))
                                elseif type(doorEntry.coords) ~= 'table' then
                                    table.insert(issues, string.format('doors[%d].coords is not a table', i))
                                else
                                    if not doorEntry.coords.x or type(doorEntry.coords.x) ~= 'number' then
                                        table.insert(issues, string.format('doors[%d].coords.x missing or invalid', i))
                                    end
                                    if not doorEntry.coords.y or type(doorEntry.coords.y) ~= 'number' then
                                        table.insert(issues, string.format('doors[%d].coords.y missing or invalid', i))
                                    end
                                    if not doorEntry.coords.z or type(doorEntry.coords.z) ~= 'number' then
                                        table.insert(issues, string.format('doors[%d].coords.z missing or invalid', i))
                                    end
                                end
                            end
                        end
                    end
                end
                
                if #issues > 0 then
                    table.insert(problematicDoors, {
                        id = door.id,
                        name = door.name,
                        reason = table.concat(issues, ', ')
                    })
                end
            end
        end
    end
    
    
    for _, problematic in ipairs(problematicDoors) do
        SafeLog('Error', string.format('Deleting problematic door ID %d (%s): %s', problematic.id, problematic.name or 'unknown', problematic.reason))
        MySQL.query.await('DELETE FROM ox_doorlock WHERE id = ?', { problematic.id })
        deletedCount = deletedCount + 1
    end
    
    if deletedCount > 0 then
        SafeLog('Warn', string.format('Aggressively deleted ^1%d^7 problematic doors', deletedCount))
    else
        SafeLog('Info', 'No problematic doors found in aggressive scan')
    end
    
    return deletedCount
end






    






exports('GetDoorIdMap', function()
    return DOOR_ID_MAP
end)

exports('GetOxDoorId', function(doorId)
    if type(doorId) == 'string' then
        return DOOR_ID_MAP[doorId]
    else
        return DOOR_ID_MAP[doorId]
    end
end)



CreateThread(function()
    
    while not MySQL do
        Wait(100)
    end
    
    
    Wait(500)
    
    if not _cleanupRun then
        _cleanupRun = true
        CleanupInvalidDoors()
    end
end)

AddEventHandler('Core:Shared:Ready', function()
    exports['mythic-base']:RequestDependencies('Doors', {
        'Callbacks',
        'Logger',
        'Utils',
        'Fetch',
    }, function(error)
        if #error > 0 then return end
        RetrieveComponents()
        
        
        
        CreateThread(function()
            Wait(500) 
            if not _cleanupRun then
                _cleanupRun = true
                CleanupInvalidDoors()
            end
            Wait(1000) 
            ConvertDoorsToOx()
        end)
    end)
end)
