_addon.name = 'warpspeed'
_addon.version = '0.2'
_addon.author = 'Latravant (Ragnarok)'
_addon.command = ('w9')

require('logger')
require('pack')
local res = require('resources')

local active = false
local queue = {}

local verbose = false

function dbg() table.vprint(queue) end

function cmd(str)
    if str:sub(1,1) == '/' then
        windower.chat.input(str)
    else
        windower.send_command(str)
    end
end

local argdict = {
ret = {'retrace'},
retall = {'retrace'},
d2 = {'warp 2'},
d2all = {'warp 2','warp'},
mea = {'teleport-mea'},
dem = {'teleport-dem'},
holla = {'teleport-holla'},
vahzl = {'teleport-vahzl'},
altepa = {'teleport-altepa'},
yhoat = {'teleport-yhoat'},
jugner = {'recall-jugner'},
meriph = {'recall-meriph'},
pash = {'recall-pash'},
}
-- can change priorities here by simply reordering the lines.
-- TODO: configurable priorities.
local actions = {
    warp2= {
        {job='BLM',type='ma',name='Warp II',level=40}},	
    warp = {
        {job='BLM',type='ma',name='Warp',   level=17}},
    retrace = {
        {job='BLM',type='ma',name='Retrace',level=55}
}

function action_available(action)
    local player = windower.ffxi.get_player()
    if verbose then
        log(player.main_job, player.main_job_level, player.sub_job, player.sub_job_level)
    end

    if not (wc_match(player.main_job, action.job) and player.main_job_level >= action.level) and
        not (wc_match(player.sub_job, action.job) and player.sub_job_level >= action.level) then
            return false
    end

    local recasts = {}
    local recast_id

	if action.type == 'ma' then
        local spell_id = res.spells:with('name', action.name).id
        local spells = windower.ffxi.get_spells()
        recasts = windower.ffxi.get_spell_recasts()
        recast_id = spells[spell_id] and spell_id

        return recasts[recast_id] == 0
    end

    return false
end

function queue_action(...)
    queue[#queue+1] = ...
    active = true
end

function work(job)
    for _, task in ipairs(job) do
        if actions[task] then
            if verbose then
                log('task:', task)
            end
            
            local result = false
            for _, action in ipairs(actions[task]) do
                if action_available(action) then
                    action.command = '/%s "%s" <me>':format(action.type, action.name)
                    result = table.copy(action)
                    
                    break
                end
            end

            if result then
                queue_action(table.update(result, {['task']=task:ucfirst()})) -- 3am hack that I will certainly never ever regret
                next_sequence = 0
            end
        end
    end
end

local midaction = function()
    local acting = false
    local last_action = -1
    local cooldown = false

    return function(param)
        if param ~= nil then
            acting = param and true
            cooldown = type(param) == 'number' and param > 0 and param
            last_action = os.clock()
        end

        if cooldown and os.clock() > (last_action + cooldown) then
            cooldown = false
            acting = false
        end

        return acting
    end
end()

local members = {}
local party_index = nil


windower.register_event('incoming chunk', function(id, original)
	if id ~= 0x0c8 then return false end
	local parsed = packets.parse('incoming', original)
  
  -- Empty Members for new data.
	members = T{}
  
  -- Build a set of current player IDs.
	for i=1, 18 do
		local id = parsed[string.format("ID %d", i)]
		local party = parsed[string.format("Party Index %s", i)]

		if id == windower.ffxi.get_player().id then
			party_index = party
		end
	
		if id > 0 then
			if not members[party] then members[party] = T{} end
			members[party]:insert(id)
		end
	end	
end)

function work(job)
    local player = windower.ffxi.get_player()
    if verbose then log(player.main_job,player.main_job_level,player.sub_job,player.sub_job_level) end
    
    for _,task in ipairs(job) do
        if actions[task] then
            if verbose then log('task:',task) end
            local result = false
            for _,action in ipairs(actions[task]) do
                if (player.main_job == action.job and player.main_job_level >= action.level) or
                    (player.sub_job == action.job and player.sub_job_level >= action.level) then
                    local recasts local recast_id
					if action.type == 'ma' then
                        local spell_id = res.spells:with('name',action.name).id
                        local spells = windower.ffxi.get_spells()
                        recasts = windower.ffxi.get_spell_recasts()
                        recast_id = spells[spell_id] and spell_id
                    end
                    if recasts[recast_id] == 0 then
                        result = table.copy(action)
                    end
                    break
                end
            end
            if result then
                queue_action(table.update(result,{['task']=task:ucfirst()})) -- 3am hack that I will certainly never ever regret
                next_sequence = 0
            end
        end
    end
end

local midaction = function()
    local acting = false
    local last_action = -1
    local cooldown = false
    
    return function(param)
        if param ~= nil then
            acting = param and true
            cooldown = type(param) == 'number' and param > 0 and param
            last_action = os.clock()
        end
        if cooldown and os.clock() > (last_action + cooldown) then
            cooldown = false
            acting = false
        end

        return acting
    end
end()

windower.register_event('addon command', function(...)
    if not windower.ffxi.get_info().logged_in then
        print('Warpspeed: not logged in.')
        return
    end
    
    local args = {...}
    
    local arg = args[1] and args[1]:lower() or 'both'
    local job     
    
    if arg == 'r' then 
        cmd('lua r warpspeed') 
        return
    elseif arg == 'd2all' then
		local zone = windower.ffxi.get_info().zone
		local party = windower.ffxi.get_party()
		local player_name = (windower.ffxi.get_player() or {}).name
		for i = 1,5 do --everyone except for yourself(0)
		local members = "p"..i
			if party["p"..i] ~= nil then
				repeat
				local party_index = i - 1
				until i == 1
					for id in members[party_index]:it() do
						windower.send_command(string.format('input /ma "Warp II" %s', id))
					end
				end
			end
			if party["p"..i] == 0 then
				windower.send_command('Warp ' ..id)	
			end
        return
    else
        log(arg:color(64), 'is an invalid command. Performing default action.')
    end
        
    work(job)
    
end)

windower.register_event('incoming chunk',function(id,org,mod,inj,blk)
    if not active then
        return
    end

    if id == 0x028 then
        p = windower.packets.parse_action(org)
        if p.actor_id ~= windower.ffxi.get_player().id then
            return
        end
        -- this could be much simpler but I like the categorizations
        if p.category >= 2 and p.category <= 8 then -- finish: ranged atk, WS, spells, items; begin: JAs, WSs,
            midaction(2.5)
        elseif p.category == 6 or p.category == 7 or p.category == 14 then -- JA, WS/TP moves, DNC moves
            midaction(2.5)
        elseif p.category == 8 or p.category == 9 or p.category == 12 or p.category == 15 then -- spells, items, ranged attacks, run JAs?
            if p.param == 28787 then
                midaction(2.5)
            else
                midaction(true)
            end
        end
    end
end)

local moving = false
windower.register_event('outgoing chunk',function(id,org,mod,inj,blk)
    if not active then
        return
    end

    local seq = org:unpack('H',3)
    
    if id == 0x015 then
        moving = lastlocation ~= mod:sub(5, 16)
        lastlocation = mod:sub(5, 16)
        if not next_sequence then 
            next_sequence = (seq+5)%0x10000 -- 128 packets is about 1 minute. 5 packets is about 2 seconds.
        end
    end

	if next_sequence and seq >= next_sequence then
        if windower.ffxi.get_player().status > 1 or moving or midaction() then
            return
        end
        
        next_sequence = nil
        
        while #queue > 0 do
            local buffactive = S(windower.ffxi.get_player().buffs):map(function(id) return res.buffs[id].name end)

            local action = table.remove(queue,1)
            if verbose then
                table.print(action)
                log(action.task,buffactive[action.task])
            end
            if not buffactive[action.task] then
                if action.type == 'item' and action.bag > 0 then -- need pull
                    local inventory = windower.ffxi.get_bag_info(0)
                    if inventory.count >= inventory.max then
                        error('Not enough space in inventory to use %s, aborting.':format(action.name))
                        next_sequence = 0
                        return
                    end
                    local bag = windower.ffxi.get_items(action.bag)
                    for slot,item in pairs(bag) do
                        if item.id == action.item_id then
                            windower.ffxi.get_item(action.bag,slot,1)
                            table.insert(queue,1,table.update(action,{retry=true,bag=0}))
                            next_sequence = nil
                            return
                        end
                    end
                elseif action.name == 'Spectral Jig' and buffactive['Sneak'] then
                    if action.retry then
                        error('Cannot cancel Sneak, giving up.')
                        return
                    end
                    log('Sneak active, attempting to cancel the buff...')
                    cmd('cancel sneak')
                    table.insert(queue,1,table.update(action,{retry=true}))
                    return
                end
                log('using %s.':format(action.name))
                cmd(action.command)
                return
            end
        end
        
        active = false
        
    end
    
end)

windower.register_event('zone change','job change','logout','unload',function()
    active = false
    queue = {}
end)

--[[local packets = require('packets')
local tables = require('tables')
local strings = require('strings')

local GROUP_TBL = L{
    {ctype='unsigned int',      label='ID',                 fn=id},
    {ctype='unsigned short',    label='Index',              fn=index},
    {ctype='bit[2]',            label='Party Number'},
    {ctype='bit[1]',            label='Party Leader',       fn=bool},
    {ctype='bit[1]',            label='Alliance Leader',    fn=bool},
    {ctype='bit[1]',            label='PartyR Flag'},
    {ctype='bit[1]',            label='AllianceR Flag'},
    {ctype='bit[1]',            label='MasterComFlg'},
    {ctype='bit[1]',            label='SubMasterComFlg'},
    {ctype='unsigned char',     label='padding00'},
    {ctype='unsigned short',    label='Zone',               fn=zone},
    {ctype='unsigned short',    label='_unknown2'},
}

packets.raw_fields.incoming[0x0C8] = L{
    {ctype='unsigned char',     label='_unknown1'},                                 -- 04
    {ctype='data[3]',           label='_junk1'},                                    -- 05
    {ref=GROUP_TBL,             count=18},                                          -- 08
    {ctype='data[0x18]',        label='_unknown3'},                                 -- E0   Always 0?
}

local members = {}
local party_index = nil

windower.register_event('incoming chunk', function(id, original)
	if id ~= 0x0c8 then return false end
	local parsed = packets.parse('incoming', original)
  
  -- Empty Members for new data.
	members = T{}
  
  -- Build a set of current player IDs.
	for i=1, 18 do
		local id = parsed[string.format("ID %d", i)]
		local party = parsed[string.format("Party Index %s", i)]

		if id == windower.ffxi.get_player().id then
			party_index = party
		end
	
		if id > 0 then
			if not members[party] then members[party] = T{} end
			members[party]:insert(id)
		end
	end	
end)

windower.register_event('addon command', function(command,...)
    if not windower.ffxi.get_info().logged_in then
        return
    end
	
	local command = ' '
	
	local args = L{...}	
	
	if command == 'd2all' then
		local zone = windower.ffxi.get_info().zone
		local party = windower.ffxi.get_party()
		local player_name = (windower.ffxi.get_player() or {}).name
		for i = 1,5 do --everyone except for yourself(0)
		local members = "p"..i
			if party["p"..i] ~= nil then
				repeat
				local party_index = i - 1
				until i == 1
					for id in members[party_index]:it() do
						windower.send_command(string.format('input /ma "Warp II" %s', id))
					end
				end
			end
			if party["p"..i] == 0 then
				windower.send_command('Warp ' ..id)
			end
		end
	end
end)
 ignore this just trying to start from the beginning like zirk said and get the damn command working 
_addon.name = 'warpspeed'
_addon.author = 'Latravant (Ragnarok)'
_addon.command = ('w9')

local packets = require('packets')
local tables = require('tables')
local strings = require('strings')

windower.register_event('addon command', function(command,...)

	local command = ' '
	local args = L{...}	
	
	for command == 'd2all' then do
		windower.send_command('Warp <me>')
	end
	return
end)]]--
