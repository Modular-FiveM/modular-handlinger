local carry = {
	InProgress = false,
	targetSrc = -1,
	type = "",
	personCarrying = {
		animDict = "missfinale_c2mcs_1",
		anim = "fin_c2_mcs_1_camman",
		flag = 49,
	},
	personCarried = {
		animDict = "nm",
		anim = "firemans_carry",
		attachX = 0.27,
		attachY = 0.15,
		attachZ = 0.63,
		flag = 33,
	}
}

local cpr = {
    dict = "mini@cpr@char_a@cpr_str",
    name = "cpr_pumpchest",
    tries = Config.Tries,
    isTrying = false
}

CreateThread(function()
    exports.ox_target:addGlobalPlayer({
        {
            label = 'Bær på skulderen',
            icon = 'fa-solid fa-handshake-angle',
            distance = 2,
            canInteract = function(entity)
                if carry.InProgress then
                    return false
                elseif carry.type == "beingcarried" then
                    return false
                elseif IsPedFatallyInjured(PlayerPedId()) then
                    return false
                end

                return true
            end,

            onSelect = function(data)
                local player = GetPlayerServerId(NetworkGetEntityOwner(data.entity))
                carry.InProgress = true
                carry.targetSrc = player
                TriggerServerEvent("CarryPeople:sync", player)
                lib.requestAnimDict(carry.personCarrying.animDict)
                carry.type = "carrying"
                lib.showTextUI(Config.TextUI.carrying)
            end
        },
        {
            label = 'Udøv CPR',
            icon = 'fa-solid fa-stethoscope',
            distance = 2,
            canInteract = function(entity)
                if cpr.tries <= 0 then 
                    return false 
                end

                if cpr.isTrying then
                    return false
                end

                return IsEntityDead(entity)
            end,
            
            onSelect = function(data)
                CPR(data.entity)
            end
        }
    })
end)

local keybind = lib.addKeybind({
    name = 'modular:putdownplayer',
    description = 'Press ' .. Config.TGLCarry .. ' to let go/put down the player',
    defaultMapper = 'KEYBOARD',
    defaultKey = Config.TGLCarry,
    onPressed = function(self)
        if carry.InProgress then
            carry.InProgress = false
            ClearPedSecondaryTask(PlayerPedId())
            DetachEntity(PlayerPedId(), true, false)
            TriggerServerEvent("CarryPeople:stop", carry.targetSrc)
            carry.targetSrc = 0
            carry.type = ""
            lib.hideTextUI()
        end
    end
})

RegisterNetEvent("CarryPeople:syncTarget", function(targetSrc)
	local targetPed = GetPlayerPed(GetPlayerFromServerId(targetSrc))
	carry.InProgress = true
	lib.requestAnimDict(carry.personCarried.animDict)
	AttachEntityToEntity(PlayerPedId(), targetPed, 0, carry.personCarried.attachX, carry.personCarried.attachY, carry.personCarried.attachZ, 0.5, 0.5, 180, false, false, false, false, 2, false)
	carry.type = "beingcarried"
    lib.showTextUI(Config.TextUI.beingCarried)
end)

RegisterNetEvent("CarryPeople:cl_stop", function()
	carry.InProgress = false
    carry.type = ""
	ClearPedSecondaryTask(PlayerPedId())
	DetachEntity(PlayerPedId(), true, false)
    lib.hideTextUI()
end)

CreateThread(function()
	while true do
		if carry.InProgress then
			if carry.type == "beingcarried" then
				if not IsEntityPlayingAnim(PlayerPedId(), carry.personCarried.animDict, carry.personCarried.anim, 3) then
					TaskPlayAnim(PlayerPedId(), carry.personCarried.animDict, carry.personCarried.anim, 8.0, -8.0, 100000, carry.personCarried.flag, 0, false, false, false)
                    lib.showTextUI(Config.TextUI.beingCarried)
                end
			elseif carry.type == "carrying" then
				if not IsEntityPlayingAnim(PlayerPedId(), carry.personCarrying.animDict, carry.personCarrying.anim, 3) then
					TaskPlayAnim(PlayerPedId(), carry.personCarrying.animDict, carry.personCarrying.anim, 8.0, -8.0, 100000, carry.personCarrying.flag, 0, false, false, false)
                    lib.showTextUI(Config.TextUI.carrying)
                end
			end
		end

		Wait(0)
	end
end)

function CPR(entity)
    local chance = math.floor(math.random(1, 3))
    cpr.isTrying = true

    lib.requestAnimDict(cpr.dict)
    TaskPlayAnim(PlayerPedId(), cpr.dict, cpr.name, 8.0, 8.0, 5000, 1, 1)
    Wait(5000)
    ClearPedTasks(PlayerPedId())
    
    cpr.tries -= 1

    if chance == 1 then
        notifyPreset('Du har reddet personen!', 'success')
        TriggerServerEvent('modular-cpr:reviveplayer', GetPlayerServerId(NetworkGetEntityOwner(entity)))
    else
        notifyPreset('(' .. cpr.tries .. '/' .. Config.Tries .. ' forsøg tilbage)', 'error')
    end

    cpr.isTrying = false

    if cpr.tries <= 0 then
        notifyPreset('Du kan udøve CPR igen om ' .. Config.CPRCooldown .. ' sekunder', 'info')
        Wait(Config.CPRCooldown * 1000)
        cpr.tries = Config.Tries
        notifyPreset('Du kan udøve CPR igen', 'success')
    end
end

function notifyPreset(text, _type)
    lib.notify({ description = text, type = _type, position = 'top' })
end


RegisterNetEvent('reviveTarget:modular-cpr', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 200)
     
    for i = 1, 3 do -- vRP's bullshit skal bruge et par ekstra gange, for at revive nogen gange... #vRPErLort
        Wait(50)
        SetEntityHealth(ped, 200)
    end
end)