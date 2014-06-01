--
-- Soundboard example.
--
-- Sounds are triggered when #<keyword> appears in a text message, where
-- keyword has been defined below in the sounds table.
--
-- require "socket"
-- require "mpd"


-- local mpd = mpd

-- Boolean if users need to be registered on the server to trigger sounds
local require_registered = true

-- Boolean if sounds should stop playing when another is triggered
local interrupt_sounds = false

-- Boolean if the bot should move into the user's channel to play the sound
local should_move = false

-- Table with keys being the keywords and values being the sound files
local sounds = {
    tvois = "tvois.ogg",
    chaud1 = "chaud1.ogg",
    chaud2 = "chaud2.ogg",
    chaud3 = "chaud3.ogg",
    chaud4 = "chaud4.ogg",
    chaud5 = "chaud5.ogg",
    chaud6 = "chaud_himi2.ogg",
    chaud7 = "chaud_est.ogg",
    quoinon = "quoi_non.ogg",
    cage = "cage.ogg",
    enerve = "enerve.ogg",
    fouet1 = "fouet1.ogg",
    fouet2 = "fouet2.ogg",
    pantalon= "pantalon.ogg",
    pantalon2= "pantalon2.ogg",
    rappelons1 = "merde.ogg",
    rappelons2 = "enfants.ogg",
    rappelons3 = "enfants2.ogg",
    radiobatard1 = "radio_batard.ogg",
    radiobatard2 = "radio_batard2.ogg",
    ohoo = "ohoo.ogg",
    paspossible = "pas_possible.ogg",
    microco = "micro_co.ogg",
    fdp = "fdp.ogg",
    chagasse = "chagasse.ogg",
    sodo = "sodo.ogg",
    faim = "faim.ogg",
    rire1 = "rire_crack.ogg",
    shoote = "shoot.ogg",
    flo1 = "flo1.ogg",
    flo2 = "bonjour_flo2.ogg",
    mens = "menstruations.ogg",
    re = "re.ogg",
    combat = "combat_himi.ogg",
    yeux1 = "yeux_ciel.ogg",
    yeux2 = "baisse_les_yeux.ogg",
    nice = "nice.ogg"
}
local commands = {
	setvol = "setvol",
	v = "volume",
	volume = "volume",
	youtube = "youtube",
	y = "youtube",
	last = "last",
	next = "next",
	prev = "prev",
	play = "play",
	pause = "pause",
	s = "song",
	song = "song"
}
-- Sound file path prefix
local prefix = "jingles/"
local mpd_connect = mpd_connect
---------------
function piepan.onConnect()
    if piepan.args.soundboard then
        prefix = piepan.args.soundboard
    end
    print ("Bridgitte chargée")
end

function string:split(sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        self:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

function piepan.formatSong(song)

	piepan.showtable(song)
	s = ''
	if(song['Artist']) then 
		s = s .. song['Artist'] .. ' - '
	end
	if(song['Album']) then 
		s = s .. song['Album'] .. ' - '
	end 
	if(song['Title']) then 
		s = s .. song['Title']
	end
	if(song['Date']) then 
		s = s .. ' (' .. song['Date'] .. ')'
	end
	if('' == s) then 
		s = song['file']
	end
	return s
end

function piepan.trim(s)
-- from PiL2 20.4
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function piepan.url_encode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str	
end

function piepan.showtable(t)
	for key,value in pairs(t) do
		print("Found member " .. key);
	end
end

function piepan.tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

function piepan.countsubstring( s1, s2 )
 local magic =  "[%^%$%(%)%%%.%[%]%*%+%-%?]"
 local percent = function(s)return "%"..s end
    return select( 2, s1:gsub( s2:gsub(magic,percent), "" ) )
end
function piepan.youtubedl(url)
	n1,n2 = string.find(url,' ')
	if(n1) then
		link = string.sub(url,n1+1)
		link = link:gsub("%b<>", "")
		piepan.me.channel:send("Loading [" .. link .. "] ...")
		print("Loading [" .. link .. "] ...")
		local file = assert(io.popen('./yt_dl.sh ' .. link, 'r'))
		local output = file:read('*all')
		file:close()
		print(output)
		n1,n2 = string.find(output,"[avconv] Destination: ",nil,true)
		if(n1) then
			n3,n4 = string.find(output,"\n",n2)
			if(n3) then
				file = piepan.trim(string.sub(output,n2,n3))
				print("Found : [" .. file .. "]")
				piepan.me.channel:send("Downloaded : [" .. file .. "]")
				client:update('download')
				-- client:idle('download')
				-- socket.sleep(5)
				os.execute("sleep " .. tonumber(5))
				uri = '"download/' .. file .. '"'
				-- print(client:add("file://" .. uri))
				print(client:sendrecv("add " .. uri))
				-- client:add("download/" .. file)
				print("Adding : [" .. uri .. "]")
				piepan.me.channel:send("Song added to the playlist.")
			else
				print("Failed to find EOL")
			end
		else
			print("Failed to find '[avconv] Destination' in " .. output)
		end
		-- piepan.me.channel:send(output)
	end
end
function piepan.onMessage(msg)
    if msg.user == nil then
        return
    end
    print("Received message : " .. msg.text) 
    local search = string.match(msg.text, "#(%w+)")

    if not search then
    	return
    end
    if sounds[search] then
	local soundFile = prefix .. sounds[search]
	if require_registered and msg.user.userId == nil then
		msg.user:send("You must be registered on the server to trigger sounds.")
		return
	end
	if piepan.Audio.isPlaying() and not interrupt_sounds then
		return
	end
	if piepan.me.channel ~= msg.user.channel then
		if not should_move then
			return
		end
		piepan.me:moveTo(msg.user.channel)
	end

	piepan.Audio.stop()
	piepan.me.channel:play(soundFile)
    end
    if(commands[search] or msg.text:starts('#v+') or msg.text:starts('#v-')) then
	c = commands[search]
	client = piepan.MPD.mpd_connect("212.129.4.80",6600,true)
	if("setvol" == c) then
		vol = tonumber(string.sub(msg.text,8))
		vol = math.max(0,math.min(100,vol))
		client:set_vol(vol)
		piepan.me.channel:send("Volume ajusté à " .. tostring(vol) .. "%")
	elseif(msg.text:starts('#v+')) then
		print("V+" .. tostring(piepan.countsubstring(msg.text,'+')))
		s = client:status()
		v = tonumber(s['volume'])
		v = math.min(100,v + 5 * piepan.countsubstring(msg.text,'+'))
		client:set_vol(v)
		piepan.me.channel:send("Volume ajusté à " .. tostring(v) .. "%")
	elseif(msg.text:starts('#v-')) then
		print("V-")
		s = client:status()
		v = tonumber(s['volume'])
		v = math.max(0,v - 5 * piepan.countsubstring(msg.text,'-'))
		client:set_vol(v)
		piepan.me.channel:send("Volume ajusté à " .. tostring(v) .. "%")
	elseif("youtube" == c) then
		
		n1,n2 = string.find(msg.text,' ')
		if(n1) then
			link = string.sub(msg.text,n1+1)
			link = link:gsub("%b<>", "")
			piepan.me.channel:send("Loading [" .. link .. "] ...")
			print("Loading [" .. link .. "] ...")
			local file = assert(io.popen('./yt_dl.sh ' .. link, 'r'))
			local output = file:read('*all')
			file:close()
			print(output)
			n1,n2 = string.find(output,"[avconv] Destination: ",nil,true)
			if(n1) then
				n3,n4 = string.find(output,"\n",n2)
				if(n3) then
					file = piepan.trim(string.sub(output,n2,n3))
					print("Found : [" .. file .. "]")
					piepan.me.channel:send("Downloaded : [" .. file .. "]")
					client:update('download')
					-- client:idle('download')
					-- socket.sleep(5)
					os.execute("sleep " .. tonumber(5))
					uri = '"download/' .. file .. '"'
					-- print(client:add("file://" .. uri))
					print(client:sendrecv("add " .. uri))
					-- client:add("download/" .. file)
					print("Adding : [" .. uri .. "]")
					piepan.me.channel:send("Song added to the playlist.")
				else
					print("Failed to find EOL")
				end
			else
				print("Failed to find '[avconv] Destination' in " .. output)
			end
			-- piepan.me.channel:send(output)
		end
		
	elseif("last" == c) then
		pli = client:playlistinfo()
		-- piepan.showtable(pli)
		pli_len = piepan.tablelength(pli)
		print("Playlist length = " .. tostring(pli_len))
		last = pli[pli_len]['Id']
		-- piepan.showtable(pli[pli_len])
		print("Last : " .. tostring(last))
		client:playid(tonumber(last))
	elseif("next" == c) then
		print(client:next())
		piepan.me.channel:send("Ok")
	elseif("play" == c) then
		print(client:pause(0))
		piepan.me.channel:send("Ok")
	elseif("pause" == c) then
		print(client:pause(1))
		piepan.me.channel:send("Ok")
	elseif("prev" == c) then
		print(client:previous())
		piepan.me.channel:send("Ok")
	elseif("volume" == c) then
		s = client:status()
		piepan.me.channel:send("Volume : " .. tostring(s['volume']) .. "%")
	elseif ("song" == c) then
		print("Sending song info ...")
		song = client:currentsong()
		s = client:status()
		print(s['volume'])
		-- piepan.printtable(song)
		-- piepan.printtable(s)
		-- print("Status : " .. s) 
		tstr = ''
		if(s['time']) then
			t = s['time'].split(':')
		-- tstr = '[' + str(datetime.timedelta(seconds=int(t[0])))
		-- tstr += ' / ' + str(datetime.timedelta(seconds=int(t[1]))) + ']'
			tstr = t
		end
		summary = piepan.formatSong(song)
		
		ret = summary -- .. ' - ' .. tstr .. ' [vol ' .. (s['volume'] or '?') .. '% R' .. (s['random'] or '?') .. ' C' .. (s['consume'] or '?') .. ']'
		-- msg.user:send(ret)
		print("Summary : " .. ret)
		piepan.me.channel:send(ret)
	end
    end

end
