_addon.name = 'warpspeed'
_addon.author = 'Latravant (Ragnarok)'
_addon.command = 'warp9'

local packets = require('packets')
local tables = require('tables')
local strings = require('strings')
local res = require('resources')

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

	members = T{}
  
  -- Build a set of current player IDs.
	for i = 0, 17 do
        local party = (i / 6):floor() + 1
		local key = {'p%i', 'a1%i', 'a2%i'}[party]:format(i % 6)
		local function get_party_members(local_members)
			local members = T{}
			for k, v in pairs(windower.ffxi.get_party()) do
				if type(v) == 'table' then
					if local_members:contains(v.name) then
						members:append(v.name)
					end
				end
			end
			
			return members
		end
		
		if id == windower.ffxi.get_player().id then
			party_index = members[party]
			--party_index = members[party]
		return members[party]
		end

		if id > 0 then
			if not members[party] then members[party] = T{} end

			members[party]:insert(id)
		end
	end
end)

windower.register_event('addon command', function(...)
    if not windower.ffxi.get_info().logged_in then
        return
    end

	local zone = windower.ffxi.get_info()['zone']
	local party = windower.ffxi.get_party()
	
	local commands = T{...}
	local args = {...}
	--local cmds = {...}
	--local args = {...}
	
	
	--local zone = windower.ffxi.get_info().zone
	--local party = windower.ffxi.get_party()		
	if command == 'd2ga' or 'd2all' then
		for i = 1,5 do
		--for i = 1,5 do
			local members = party['p' ..i]
			if party['p'..i] ~= nil then
				if party[idx] and party[idx].name:lower() == player then
					repeat
					local party_index = i - 1
					until i == 1
						for id in members[party_index]:it() do
							windower.send_command(string.format('input /ma "Warp II" %s', id))
						end
				end	--until i == 0
							
					return party_index

			elseif party['p'..i] == 0 then
				for id in members[party_index]:it() do
				--if member.id == player.id then return true end
				--local me = get_member(player.id, player.name, true)
					windower.send_command(string.format('input /ma "Warp" %s', id))
					--windower.send_command(string.format('input /ma "Warp" <me>'))
				end
				return false
			end
		end
	elseif command == 'debug' then
		table.print(events.registered)
	end
end)