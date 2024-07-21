local Config = lib.require('config')
local stevo_lib = exports['stevo_lib']:import()


function police_dispatch()
	--- Police Dispatch Here.
end

CreateThread(function()


	if Config.interaction.type == 'target' then

		local options = {
			options = {
				{
					name = 'stevo_drugsell:sell',
					icon = Config.interaction.targeticon,
					label = Config.interaction.targetlabel,
					distance = Config.interaction.targetdistance,
					action = attempt_sell,
					canInteract = function(entity)
						return not IsEntityDead(entity) and not IsEntityPositionFrozen(entity) and does_have_drugs() and can_ped_buy(entity) and GetPedType(entity) ~= 28 and not IsPedInAnyVehicle(PlayerPedId(), true) and not IsPedInAnyVehicle(PlayerPedId(), true)
					end
				},
			},
			distance = 5,
			rotation = vec3(0.0,0.0,0.0)

		}

		stevo_lib.target.addGlobalPed('drugselling_global', options)
	end

	if Config.interaction.type == '3dtext' then
		local function drawPedText(coords)
			local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z+1)
		
			if onScreen then
				SetTextScale(0.4, 0.4)
				SetTextFont(4)
				SetTextProportional(1)
				SetTextColour(255, 255, 255, 255)
				SetTextOutline()
				SetTextEntry("STRING")
				SetTextCentre(true)
				AddTextComponentString(Config.interaction.text)
				DrawText(_x, _y)
			end
		end
	
	
		local function getClosestPed(coords, maxDistance)
			local peds = GetGamePool('CPed')
			local closestPed, closestCoords
			maxDistance = maxDistance or 2.0
		
			for i = 1, #peds do
				local ped = peds[i]
		
				if not IsPedAPlayer(ped) then
					local pedCoords = GetEntityCoords(ped)
					local distance = #(coords - pedCoords)
		
					if distance < maxDistance then
						maxDistance = distance
						closestPed = ped
						closestCoords = pedCoords
					end
				end
			end
		
			return closestPed, closestCoords
		end

		
		Citizen.CreateThread(function()
			while true do
				local closestPed, closestPedCoords = getClosestPed(GetEntityCoords(cache.ped), 2)
				if closestPed ~= nil and can_ped_buy(closestPed) and does_have_drugs() then

					
	
					while closestPed ~= nil and can_ped_buy(closestPed) do
						drawPedText(closestPedCoords)
						if IsControlJustPressed(1, 38) then 
							attempt_sell(closestPed)
						end
						Citizen.Wait(0) 
						closestPed, closestPedCoords = getClosestPed(GetEntityCoords(cache.ped), 2)
					end
				else
					Citizen.Wait(1000)
				end
			end
		end)
	end
end)

function does_have_drugs()
	local has_drugs = false
	for item, itemInfo in pairs(Config.drugs) do
		local count = exports.ox_inventory:Search('count', item)
		if count >= 1 then
			has_drugs = true
		end
	end

	return has_drugs
end

function prepare_buyer_offer()
    local buyer_offer = nil


    for item, itemInfo in pairs(Config.drugs) do
        if buyer_offer ~= nil then
            break
        end

        local base_price = itemInfo.base_price
        local max_sale = itemInfo.max_sale
        local count = exports.ox_inventory:Search('count', item)


        if count >= 1 then
            if count > max_sale then 
                count = max_sale 
            end

            local offer_amount = base_price * count

            buyer_offer = {
                count = count,
                item = item,
                amount = offer_amount,
				rep = itemInfo.rep_sale
            }
        end
    end

    return buyer_offer
end

function ped_cooldown(entity)

	
    Entity(entity).state:set('stevo_drugcooldown', false, true) 

    Citizen.SetTimeout(Config.buyer_cooldown, function()
        if not entity then return end
        Entity(entity).state:set('stevo_drugcooldown', true, true) 
    end)

end

function can_ped_buy(closestPed)
	if IsEntityDead(closestPed) then return false end 
	if IsEntityPositionFrozen(closestPed) then return false end 
	if GetPedType(closestPed) == 28 then return false end 
	if IsPedInAnyVehicle(closestPed, true) then return false end
	if IsPedInAnyVehicle(PlayerPedId(), true) then return false end
    local cooldown = Entity(closestPed).state.stevo_drugcooldown

    if cooldown == false then
        return true
    else

        return false
    end
end

function show_player_reputation(current_reputation)
    local current_replevel = Config.reps[1] 
    local next_level = nil

    for i, rep in ipairs(Config.reps) do
        if current_reputation >= rep.min_reputation then
            current_replevel = rep
            next_level = Config.reps[i + 1]
        else
            break
        end
    end

    local current_min_reputation = current_replevel.min_reputation
    local next_min_reputation = next_level and next_level.min_reputation or current_min_reputation
    local reputation_range = next_min_reputation - current_min_reputation
    local reputation_progress = current_reputation - current_min_reputation
    local percentage_complete = math.floor((reputation_progress / reputation_range) * 100)

  
    stevo_lib.Notify(('%s (%d%% Complete)'):format(
        current_replevel.label,
        percentage_complete
    ), 'info', 5000)
end

function reputation_menu()
	local current_reputation, player_name = lib.callback.await('stevo_drugsell:getReputation', false)
	local current_replevel = Config.reps[1] 
    local next_level = nil

	
    for i, rep in ipairs(Config.reps) do
        if current_reputation >= rep.min_reputation then
            current_replevel = rep
            next_level = Config.reps[i + 1]
        else
            break
        end
    end

	local current_min_reputation = current_replevel.min_reputation
    local next_min_reputation = next_level and next_level.min_reputation or current_min_reputation
    local reputation_range = next_min_reputation - current_min_reputation
    local reputation_progress = current_reputation - current_min_reputation
    local percentage_complete = math.floor((reputation_progress / reputation_range) * 100)
	lib.registerContext({
		id = 'reputation_menu',
		title = player_name.."'s Rep",
		options = {
		  {
			title = current_replevel.label,
			description = current_replevel.description,
			colorScheme = 'red',
			progress = math.floor(percentage_complete),
		  },
		}
	  })
	  lib.showContext('reputation_menu')
end

RegisterCommand('checkrep', reputation_menu)

function sale_anim(buyer_ped, player)

	local bag_model = lib.requestModel(joaat('prop_meth_bag_01'))
	local cash_model = lib.requestModel(joaat('prop_anim_cash_note'))
	local anim_dict = lib.requestAnimDict('mp_common')
	local anim_dict_2 = lib.requestAnimDict('weapons@holster_fat_2h')

	local bag = CreateObject(bag_model, 0, 0, 0, true, false, false)
	local cash = CreateObject(cash_model, 0, 0, 0, true, false, false)
	AttachEntityToEntity(bag, player, 90, 0.07, 0.01, -0.01, 136.33, 50.23, -50.26, true, true, false, true, 1, true)
	AttachEntityToEntity(cash, buyer_ped, GetPedBoneIndex(buyer_ped, 28422), 0.07, 0, -0.01, 18.12, 7.21, -12.44, true, true, false, true, 1, true)
	TaskPlayAnim(player, anim_dict, 'givetake1_a', 8.0, 8.0, -1, 32, 0.0, false, false, false)
	TaskPlayAnim(buyer_ped, anim_dict, 'givetake1_a', 8.0, 8.0, -1, 32, 0.0, false, false, false)

	Wait(1500)
	AttachEntityToEntity(bag, buyer_ped, GetPedBoneIndex(buyer_ped, 28422), 0.07, 0.01, -0.01, 136.33, 50.23, -50.26, true, true, false, true, 1, true)
	AttachEntityToEntity(cash, player, 90, 0.07, 0, -0.01, 18.12, 7.21, -12.44, true, true, false, true, 1, true)
	TaskPlayAnim(player, anim_dict_2, 'holster', 5.0, 1.5, 3000, 32, 0.0, false, false, false)
	TaskPlayAnim(buyer_ped, anim_dict_2, 'holster', 5.0, 1.5, 3000, 32, 0.0, false, false, false)
	Wait(500)

	DeleteEntity(bag)
	DeleteEntity(cash)
	Wait(100)
	PlayPedAmbientSpeechNative(buyer_ped, 'GENERIC_THANKS', 'SPEECH_PARAMS_STANDARD')
	TaskWanderStandard(buyer_ped, 10.0, 10)
	RemovePedElegantly(buyer_ped)
end

function attempt_sell(entity)

	
	local buyer_ped = entity

	ClearPedTasks(buyer_ped)

	local sellChance = {
        max = 100,
        min = 0,
        chance = 50, 
    },


	math.randomseed(GetGameTimer())

	local chance = math.random(sellChance.min, sellChance.max)



	if chance <= sellChance.chance then
		TaskSetBlockingOfNonTemporaryEvents(buyer_ped, true)
		TaskTurnPedToFaceEntity(buyer_ped, cache.ped, -1)

		Wait(500)
		

		PlayPedAmbientSpeechNative(buyer_ped, "GENERIC_HI", "SPEECH_PARAMS_FORCE_NORMAL")

		local data = prepare_buyer_offer()


		sale_anim(buyer_ped, PlayerPedId())
		
		local attempted_sale, level_up, current_reputation, msg = lib.callback.await('stevo_drugsell:sale', false, data)

		if Config.police.require and attempted_sale == 'nopol' then 
			stevo_lib.Notify('Not enough police to sell!', 'error', 5000)
			return
		end
			
		stevo_lib.Notify('Sold x'..data.count..' for $'..attempted_sale, 'success', 5000)

		if level_up then 
			stevo_lib.Notify(msg, 'info', 5000)
		else
			show_player_reputation(current_reputation)
		end
		
		ped_cooldown(buyer_ped)

	else
		if Config.callpoliceondeny then police_dispatch() end
		ped_cooldown(buyer_ped)
		PlayPedAmbientSpeechNative(buyer_ped, "GENERIC_FRIGHTENED_HIGH", "SPEECH_PARAMS_FORCE_SHOUTED")
		TaskSmartFleePed(buyer_ped, PlayerPedId(), 10000.0, -1)
	end
	
end

