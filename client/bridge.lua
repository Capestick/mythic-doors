


local DOOR_ID_MAP = {}
local DOORS_IDS = {}
local ELEVATOR_STATE = {}
local _newDuty = false
local GLOBAL_PED = PlayerPedId()


local _showingDoorInfo = false
local _lookingAtDoor = false
local _lookingAtDoorCoords = nil
local _lookingAtDoorRadius = nil

AddEventHandler("Doors:Shared:DependencyUpdate", RetrieveComponents)
function RetrieveComponents()
	Logger = exports["mythic-base"]:FetchComponent("Logger")
	Callbacks = exports["mythic-base"]:FetchComponent("Callbacks")
	Game = exports["mythic-base"]:FetchComponent("Game")
	Utils = exports["mythic-base"]:FetchComponent("Utils")
	Menu = exports["mythic-base"]:FetchComponent("Menu")
	Notification = exports["mythic-base"]:FetchComponent("Notification")
	Action = exports["mythic-base"]:FetchComponent("Action")
	Jobs = exports["mythic-base"]:FetchComponent("Jobs")
	Targeting = exports["mythic-base"]:FetchComponent("Targeting")
	ListMenu = exports["mythic-base"]:FetchComponent("ListMenu")
	Progress = exports["mythic-base"]:FetchComponent("Progress")
	Polyzone = exports["mythic-base"]:FetchComponent("Polyzone")
	Keybinds = exports["mythic-base"]:FetchComponent("Keybinds")
	UISounds = exports["mythic-base"]:FetchComponent("UISounds")
	Sounds = exports["mythic-base"]:FetchComponent("Sounds")
	Properties = exports["mythic-base"]:FetchComponent("Properties")
	Doors = exports["mythic-base"]:FetchComponent("Doors")
end


local function LoadDoorIdMap()
	local success, map = pcall(function()
		return exports['doors']:GetDoorIdMap()
	end)
	
	if success and map then
		DOOR_ID_MAP = map
	end
end


local function BuildDoorsIds()
	if not _doorConfig then return end
	for k, v in ipairs(_doorConfig) do
		if v.id and not DOORS_IDS[v.id] then
			DOORS_IDS[v.id] = k
		end
	end
end


local function GetOxDoorId(doorId)
	if type(doorId) == 'string' then
		local mapped = DOOR_ID_MAP[doorId]
		if mapped then return mapped end
		
		if DOORS_IDS[doorId] then
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
	
	local success, door = pcall(function()
		return exports.ox_doorlock:getDoor(oxId)
	end)
	
	if success and door then
		return door
	end
	
	return nil
end


DOORS = {
	IsLocked = function(self, doorId)
		local door = GetOxDoor(doorId)
		if door then
			return door.state == 1
		end
		return false
	end,
	
	CheckRestriction = function(self, doorId)
		if not _doorConfig then return false end
		
		local doorIndex = doorId
		if type(doorId) == "string" then
			doorIndex = DOORS_IDS[doorId]
		end
		
		if not doorIndex or not _doorConfig[doorIndex] then
			return false
		end
		
		local doorData = _doorConfig[doorIndex]
		if not LocalPlayer.state.Character then
			return false
		end

		if type(doorData.restricted) ~= 'table' or #doorData.restricted == 0 then
			return true
		end

		if Jobs.Permissions:HasJob('dgang', false, false, 99, true) then
			return true
		end

		local stateId = LocalPlayer.state.Character:GetData('SID')

		for k, v in ipairs(doorData.restricted) do
			if v.type == 'character' then
				if stateId == v.SID then
					return true
				end
			elseif v.type == 'job' then
				if v.job then
					if Jobs.Permissions:HasJob(v.job, v.workplace, v.grade, v.gradeLevel, v.reqDuty, v.jobPermission) then
						return true
					end
				elseif v.jobPermission then
					if Jobs.Permissions:HasPermission(v.jobPermission) then
						return true
					end
				end
			elseif v.type == 'propertyData' then
				if Properties.Keys:HasAccessWithData(v.key, v.value) then
					return true
				end
			end
		end
		
		return false
	end,
}

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["mythic-base"]:RegisterComponent("Doors", DOORS)
end)


function CheckDoorAuth(doorId)
	
	if not _doorAuthCache then
		_doorAuthCache = {}
	end
	
	local cacheKey = tostring(doorId)
	local cached = _doorAuthCache[cacheKey]
	
	if cached and (GetGameTimer() - cached.time) < 60000 and cached.duty == LocalPlayer.state.onDuty then
		return cached.hasPermission
	end
	
	local hasPermission = Doors:CheckRestriction(doorId)
	_doorAuthCache[cacheKey] = {
		hasPermission = hasPermission,
		time = GetGameTimer(),
		duty = LocalPlayer.state.onDuty
	}
	
	return hasPermission
end

function StopShowingDoorInfo()
	if not _showingDoorInfo then return end
	Action:Hide()
	_showingDoorInfo = false
end

function StartShowingDoorInfo(doorId)
	_showingDoorInfo = doorId
	
	local door = GetOxDoor(doorId)
	local isLocked = door and door.state == 1 or false
	
	local actionMsg = "{keybind}primary_action{/keybind} "
		.. (isLocked and "Unlock Door" or "Lock Door")
	Action:Show(actionMsg)
end


AddEventHandler('Keybinds:Client:KeyUp:primary_action', function()
	if _lookingAtDoor and _showingDoorInfo then
		StopShowingDoorInfo()
		DoorAnim()
		
		
		local success = pcall(function()
			return exports.ox_doorlock:useClosestDoor()
		end)
		
		if success then
			Sounds.Do.Play:One('doorlocks.ogg', 0.2)
		end
	end
end)


AddEventHandler('Targeting:Client:TargetChanged', function(entity)
	if entity and IsEntityAnObject(entity) then
		
		
		local playerCoords = GetEntityCoords(PlayerPedId())
		
		
		local success, closestDoor = pcall(function()
			return exports.ox_doorlock:getDoorFromName('closest') 
		end)
		
		
		if _doorConfig then
			for k, doorData in ipairs(_doorConfig) do
				if doorData.model and doorData.coords then
					local dist = #(playerCoords - doorData.coords)
					local maxDist = doorData.autoDist or 2.0
					
					if dist <= maxDist then
						
						if GetEntityModel(entity) == doorData.model then
							local oxId = GetOxDoorId(k)
							if oxId then
								_lookingAtDoor = k
								_lookingAtDoorCoords = doorData.coords
								_lookingAtDoorRadius = maxDist
								
								if not doorData.special then
									CreateThread(function()
										while _lookingAtDoor == k do
											local dist = #(_lookingAtDoorCoords - GetEntityCoords(PlayerPedId()))
											local canSee = dist <= _lookingAtDoorRadius and CheckDoorAuth(k)
											if not _showingDoorInfo and canSee then
												StartShowingDoorInfo(k)
											elseif _showingDoorInfo and not canSee then
												StopShowingDoorInfo()
											end
											Wait(500)
										end
										StopShowingDoorInfo()
									end)
								end
								return
							end
						end
					end
				end
			end
		end
	elseif _lookingAtDoor then
		_lookingAtDoor = false
		_lookingAtDoorCoords = nil
		StopShowingDoorInfo()
	end
end)


function DoorAnim()
	CreateThread(function()
		while not HasAnimDictLoaded('anim@heists@keycard@') do
			RequestAnimDict('anim@heists@keycard@')
			Wait(10)
		end

		TaskPlayAnim(LocalPlayer.state.ped, 'anim@heists@keycard@', 'exit', 8.0, 1.0, -1, 48, 0, 0, 0, 0)
		Wait(750)
		StopAnimTask(LocalPlayer.state.ped, 'anim@heists@keycard@', 'exit', 1.0)
	end)
end


RegisterNetEvent('ox_doorlock:stateChanged', function(source, doorId, isLocked)
	
	local oldDoorId = nil
	for oldId, oxId in pairs(DOOR_ID_MAP) do
		if oxId == doorId then
			oldDoorId = oldId
			break
		end
	end
	
	
	if oldDoorId then
		TriggerEvent('Doors:Client:UpdateState', oldDoorId, isLocked)
	end
	
	
	if _showingDoorInfo then
		StartShowingDoorInfo(_showingDoorInfo)
	end
end)


RegisterNetEvent("Doors:Client:UpdateState", function(door, state)
	
	local oxId = GetOxDoorId(door)
	if oxId then
		
		if _showingDoorInfo == door then
			StartShowingDoorInfo(door)
		end
	end
end)

RegisterNetEvent("Doors:Client:SetForcedOpen", function(door)
	
	local oxId = GetOxDoorId(door)
	if oxId then
		
		pcall(function()
			exports.ox_doorlock:setDoorState(oxId, 0)
		end)
	end
end)


function CreateElevators()
	if ELEVATOR_STATE then
		for k, v in pairs(ELEVATOR_STATE) do
			if v.floors then
				for floorId, floorData in pairs(v.floors) do
					if floorData.zone then
						if #floorData.zone > 0 then
							for j, b in ipairs(floorData.zone) do
								CreateElevatorFloorTarget(b, k, floorId, j)
							end
						else
							CreateElevatorFloorTarget(floorData.zone, k, floorId, 1)
						end
					end
				end
			end
		end
	end
end

function CreateElevatorFloorTarget(zoneData, elevatorId, floorId, zoneId)
	Targeting.Zones:AddBox(
		('elevators_'.. elevatorId .. '_level_'.. floorId .. '_' .. zoneId),
		'elevator',
		zoneData.center,
		zoneData.length,
		zoneData.width,
		{
			heading = zoneData.heading,
			minZ = zoneData.minZ,
			maxZ = zoneData.maxZ,
		},
		{
			{ 
				icon = 'elevator', 
				text = 'Use Elevator', 
				event = 'Doors:Client:OpenElevator',
				data = {
					elevator = elevatorId,
					floor = floorId,
				},
				minDist = 3.0,
				isEnabled = function()
					return (not LocalPlayer.state.Character:GetData("ICU") or LocalPlayer.state.Character:GetData("ICU").Released) and not LocalPlayer.state.isCuffed
				end,
			}
		},
		3.0,
		true
	)
end


AddEventHandler("Doors:Client:OpenElevator", function(hitEntity, data)
	if not ELEVATOR_STATE then return end

	local elevatorData = ELEVATOR_STATE[data.elevator]
	if elevatorData and LocalPlayer.state.loggedIn then
		local menu = {
			main = {
				label = elevatorData.name or "Elevator",
				items = {},
			},
		}

		local isAuthed = false
		if elevatorData.canLock and CheckElevatorPermissions(elevatorData.canLock) then
			isAuthed = true
		end

		for floorId, floorData in pairs(elevatorData.floors) do
			local isDisabled = false
			local description = nil

			if floorData.locked then
				if not floorData.bypassLock or not CheckElevatorPermissions(floorData.bypassLock) then
					isDisabled = true
				end
				description = "Authorized Access Only (Locked)"
			end

			if data.floor == floorId then
				isDisabled = true
				description = "You are Currently on This Level"
			end

			if isAuthed then
				isDisabled = false
			end

			table.insert(menu.main.items, {
				level = floorId,
				label = floorData.name or "Level ".. floorId,
				disabled = isDisabled,
				description = description,
				event = "Doors:Client:UseElevator",
				data = { elevator = data.elevator, floor = floorId },
				submenu = isAuthed and string.format("auth-%s", floorId) or false
			})

			if isAuthed then
				if data.floor == floorId then
					isDisabled = true
				end

				menu[string.format("auth-%s", floorId)] = {
					label = (floorData.name or "Level ".. floorId),
					items = {
						{
							level = floorId,
							label = "Visit This Floor",
							disabled = isDisabled,
							description = description,
							event = "Doors:Client:UseElevator",
							data = { elevator = data.elevator, floor = floorId },
							submenu = false
						},
						{
							label = floorData.locked and "Unlock Floor" or "Lock Floor",
							description = "Lock/Unlock this Floor",
							event = "Doors:Client:LockElevator",
							data = { elevator = data.elevator, floor = floorId },
						}
					}
				}
			end
		end

		table.sort(menu.main.items, function(a, b)
			return a.level < b.level
		end)

		ListMenu:Show(menu)
	end
end)

AddEventHandler("Doors:Client:LockElevator", function(data)
	if ELEVATOR_STATE[data.elevator] and LocalPlayer.state.loggedIn then
		Callbacks:ServerCallback("Doors:Elevators:ToggleLocks", data, function(success, newState)
			if success then
				if newState then
					Notification:Error("Elevator Locked")
				else
					Notification:Success("Elevator Unlocked")
				end
			end
		end)
	end
end)

AddEventHandler("Doors:Client:UseElevator", function(data)
	local elevatorData = ELEVATOR_STATE[data.elevator]
	if elevatorData and elevatorData.floors and LocalPlayer.state.loggedIn then
		local floorData = elevatorData.floors[data.floor]
		if floorData and floorData.coords then
			Callbacks:ServerCallback("Doors:Elevator:Validate", floorData, function()
				Progress:ProgressWithTickEvent({
					name = "door_elevator",
					duration = 2000,
					label = "Awaiting Elevator",
					useWhileDead = false,
					canCancel = true,
					ignoreModifier = true,
					tickrate = 100,
					controlDisables = {
						disableMovement = true,
						disableCarMovement = false,
						disableMouse = false,
						disableCombat = true,
					},
				}, function()
					if LocalPlayer.state.isCuffed then
						return Progress:Cancel()
					end
				end, function(cancelled)
					if not cancelled and not ELEVATOR_STATE[data.elevator].locked then
						DoScreenFadeOut(500)
						while not IsScreenFadedOut() do Wait(10) end
			
						SetEntityCoords(GLOBAL_PED, floorData.coords.x, floorData.coords.y, floorData.coords.z)
						SetEntityHeading(GLOBAL_PED, floorData.coords.w)
						Sounds.Play:Distance(5.0, "elevator-bell.ogg", 0.4)
						Wait(250)
						DoScreenFadeIn(500)
					end
				end)
			end)
		end
	end
end)

function CheckElevatorPermissions(restricted)
	if LocalPlayer.state.Character then
		if type(restricted) ~= "table" then
			return true
		end

		local stateId = LocalPlayer.state.Character:GetData("SID")
		for k, v in ipairs(restricted) do
			if v.type == "character" then
				if stateId == v.SID then
					return true
				end
			elseif v.type == "job" then
				if v.job then
					if Jobs.Permissions:HasJob(v.job, v.workplace, v.grade, v.gradeLevel, v.reqDuty, v.jobPermission) then
						return true
					end
				elseif v.jobPermission then
					if Jobs.Permissions:HasPermission(v.jobPermission) then
						return true
					end
				end
			end
		end
	end
	return false
end

RegisterNetEvent('Doors:Client:UpdateElevatorState', function(elevator, floor, state)
	if ELEVATOR_STATE[elevator] and ELEVATOR_STATE[elevator].floors and ELEVATOR_STATE[elevator].floors[floor] then
		ELEVATOR_STATE[elevator].floors[floor].locked = state
	end
end)


function CreateGaragePolyZones()
	
	
end

function DoGarageKeyFobAction()
	if LocalPlayer.state.loggedIn then
		local playerCoords = GetEntityCoords(PlayerPedId())
		local inZone = Polyzone:IsCoordsInZone(playerCoords, false, 'door_garage_id')
		if inZone and inZone.door_garage_id then
			if Doors:CheckRestriction(inZone.door_garage_id) then
				
				local oxId = GetOxDoorId(inZone.door_garage_id)
				if oxId then
					local success = pcall(function()
						return exports.ox_doorlock:useClosestDoor()
					end)
					
					if success then
						UISounds.Play:FrontEnd(-1, "Bomb_Disarmed", "GTAO_Speed_Convoy_Soundset")
					end
				else
					
					Callbacks:ServerCallback('Doors:ToggleLocks', inZone.door_garage_id, function(success, newState)
						if success then
							if newState then
								UISounds.Play:FrontEnd(-1, "OOB_Cancel", "GTAO_FM_Events_Soundset")
							else
								UISounds.Play:FrontEnd(-1, "Bomb_Disarmed", "GTAO_Speed_Convoy_Soundset")
							end
						end
					end)
				end
			else
				UISounds.Play:FrontEnd(-1, "Hack_Failed", "DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS")
				Notification:Error('Not Authorized')
			end
		end
	end
end


RegisterNetEvent("Characters:Client:Spawn", function()
	GLOBAL_PED = PlayerPedId()
	StopShowingDoorInfo()
	
	CreateThread(function()
		while LocalPlayer.state.loggedIn do
			GLOBAL_PED = PlayerPedId()
			Wait(5000)
		end
	end)
end)

RegisterNetEvent("Characters:Client:Logout", function()
	StopShowingDoorInfo()
end)

RegisterNetEvent("Job:Client:DutyChanged", function(state)
	_newDuty = state
	
	_doorAuthCache = {}
end)


AddEventHandler("Core:Shared:Ready", function()
	exports["mythic-base"]:RequestDependencies("Doors", {
		"Logger",
		"Callbacks",
		"Game",
		"Utils",
		"Menu",
		"Notification",
		"Action",
		"Jobs",
		"Targeting",
		"ListMenu",
		"Progress",
		"Polyzone",
		"Keybinds",
		"UISounds",
		"Sounds",
		"Doors",
		"Properties",
	}, function(error)
		if #error > 0 then return end
		RetrieveComponents()

		Keybinds:Add('doors_garage_fob', 'f10', 'keyboard', 'Doors - Use Garage Keyfob', function()
			DoGarageKeyFobAction()
		end)

		
		if _elevatorConfig then
			for k, v in ipairs(_elevatorConfig) do
				ELEVATOR_STATE[k] = v
			end
			CreateElevators()
		end

		
		BuildDoorsIds()
		
		
		SetTimeout(3000, function()
			LoadDoorIdMap()
		end)
	end)
end)
