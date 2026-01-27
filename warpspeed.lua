_addon.name = 'warpspeed'
_addon.author = 'eLii'
_addon.command = 'bmu'

require('luau')
require('logger')

local packets	 = require('packets')
local tables	 = require('tables')
local strings	 = require('strings')
local res		 = require('resources')

local GROUP_TBL = L{
	{ctype='unsigned int',	 	label='ID',					fn=id},
	{ctype='unsigned short',	label='Index',				fn=index},
	{ctype='bit[2]',			label='Party Number'},
	{ctype='bit[1]',			label='Party Leader',		fn=bool},
	{ctype='bit[1]',			label='Alliance Leader',	fn=bool},
	{ctype='bit[1]',			label='PartyR Flag'},
	{ctype='bit[1]',			label='AllianceR Flag'},
	{ctype='bit[1]',			label='MasterComFlg'},
	{ctype='bit[1]',			label='SubMasterComFlg'},
	{ctype='unsigned char',		label='padding00'},
	{ctype='unsigned short',	label='Zone',				fn=zone},
	{ctype='unsigned short',	label='_unknown2'},
}
                          --0x0c8 = alliance id
packets.raw_fields.incoming[0x0C8] = L{
	{ctype='unsigned char',	 label='_unknown1'},								 -- 04
	{ctype='data[3]',		   label='_junk1'},									-- 05
	{ref=GROUP_TBL,			 count=18},										  -- 08
	{ctype='data[0x18]',		label='_unknown3'},								 -- E0   Always 0?
}

local members		= S{}
local queue			= T{}
local busy			= false
local by_id			= windower.ffxi.get_mob_by_id
local do_actions	= function(b)
	busy = false

	if queue:length() == 0 then
		busy = b
		return 

	end

	local action = queue:remove(1)
	local target = by_id(action.id)
	
	if target then
		windower.send_command(action.input)
	end
end

local members = T{}
windower.register_event('incoming chunk',function(id, original)
	if not S{0x0C8,0x028}:contains(id) then return false end

	local parsed = packets.parse('incoming', original)

	if id == 0x028 then -- character casting id
		local actor		 = by_id(parsed['Actor'])
		local target	 = by_id(parsed['Target 1 ID'])
		local category	 = parsed['Category']
		local param		 = parsed['Param']

		busy = true
		
		if S{4,5}:contains(category) then

			if category == 4 and res.spells[param] and res.spells[param].cast_delay then -- This is spells
				local recast = windower.ffxi.get_spell_recasts()[res.spells[param].recast_id]
				do_actions:schedule(res.spells[param].cast_delay + recast + 1)
				return 1
				
			elseif res.items[param] and res.items[param].cast_delay then
				do_actions:schedule(res.items[param].cast_delay + 1)
				return 2
				
			end
			
		elseif param == 28787 then

			-- The action failed. We need to handle what to do if it fails and the queue is still has actions.
			coroutine.schedule(function() busy = false end, 2)

		end

	else
		local current = S{}

		for i = 1, 18 do
			local id = parsed[string.format("ID %d", i)]

			if id == 0 then
				break
			end
			current:add(id)

		end
		members = current
	end

end)

windower.register_event('addon command', function(...)
    if not windower.ffxi.get_info().logged_in then return end
	local command = T{...}
	local members = S{}
	local player = windower.ffxi.get_player()
	
	if not player then
	end

	if command:first() == 'scottie' then
		
		for id in members:it() do -- Let's change this to array-like so we can keep order and always cast on other first, then add our id at the end.
			if id ~= player.id then -- Let's wait to add ourself.
				queue:insert({ id = id, input = string.format('input /ma "Warp II" %s', id) })
			end
		    do_actions()
			
		end

[[		do -- Queue the action on ourselves now.
			queue:insert({ id=player.id, input=string.format('input /ma "Warp" %s', player.id) })

		end
		do_actions]]
		return 
    end
end)

windower.register_event('login','load',function()
    local data = windower.packets.last_incoming(0x0C8)
	if data then windower.packets.inject_incoming(0x0C8, data) end
end)