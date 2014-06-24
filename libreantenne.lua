----------------------------------------------------------------------
-- Mumble/IRC/MPD bot with lua
--
-- require "socket"
-- require "mpd"
-- require "os"
----------------------------------------------------------------------


-- Boolean if users need to be registered on the server to trigger sounds
local require_registered = true

-- Boolean if sounds should stop playing when another is triggered
local interrupt_sounds = false

-- Boolean if the bot should move into the user's channel to play the sound
local should_move = false

local disable_jingle_ts = 0

local mpd_client = {loaded = false}

----------------------------------------------------------------------
-- Table with keys being the keywords and values being the sound files
----------------------------------------------------------------------
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
    rappelons4 = "telechargement.ogg",
    rappelons5 = "rappelons5.ogg",
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
    bienvenue1 = "bienvenue_triskel.ogg",
    bienvenue2 = "bienvenue_himi.ogg",
    penis = "penis.ogg",
    encore = "encore.ogg",
    culotte = "culotte.ogg",
    bite = "bite.ogg",
    batard = "batard.ogg",
    businessman = "businessman.ogg",
    puteflo = "puteflo.ogg",
    con2 = "con2.ogg",
    aahh = "aahh.ogg",
    zoo1 = "zoo1.ogg",
    zoo2 = "zoo2.ogg",
    ascaris = "ascaris.ogg",
    pertinent = "pertinent.ogg",
    bienvenuejap = "bienvenu_jap_himi.ogg",
    boisson = "boisson.ogg",
    accueil = "accueil.ogg",
    message = "message.ogg"
}

----------------------------------------------------------------------
-- commands array
----------------------------------------------------------------------
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
   random = "random",
   consume = "consume",
   help = "help",
   fadevol = "fadevol",
   song = "song",
   listeners = "listeners",
   disablej = "disablej",
   enablej669 = "enablej",
   keep = "keep",
   n = "next?",
   stop = "stop",
   shuffle = "shuffle",
   xfade = "xfade"
}

local g_bans = {
}


----------------------------------------------------------------------
-- global configuration variables
----------------------------------------------------------------------
local configuration_file="./bot.conf"
local flags = {

   loaded = false,

   debug = "",         -- debug flags -> integer

   mumble_user = "",   -- mumble bot username -> string

   irc_server = "",    -- irc server address -> IP or DNS
   irc_port = "",      -- irc server port -> integer 2**16   
   irc_chan = "",      -- irc chan -> string

   mpd_server = "",    -- mpd server address -> IP or DNS
   mpd_port = "",      -- mpd port -> integer 2**16
   mpd_password = "",  -- mpd password -> string

   mumble_server = "", -- mumble server address -> IP or DNS
   mumble_port = "",   -- mumble port -> integer 2**16
   mumble_chan = "",    -- mumble chan -> string

   web_server = "",    -- mpd web server -> string
   web_port = "",      -- mpd port -> integer 2**16

   jingle_conf = "",   -- jingle configuration file path string
   jingle_path = ""    -- jingle music path -> string
}

-- violet local msg_prefix = "<span style='color:#738'>&#x266B;&nbsp;-&nbsp;"
-- local msg_prefix = "<span style='color:#384'>&#x266B;&nbsp;-&nbsp;"
-- local msg_prefix = "<span style='color:#339933'>&#x266B;&nbsp;-&nbsp;"
local msg_prefix = "<span style='color:#777'>&#x266B;&nbsp;-&nbsp;"
local msg_suffix = "&nbsp;-&nbsp;&#x266B;</span>"

----------------------------------------------------------------------
-- Sound file path prefix
----------------------------------------------------------------------
local prefix = "jingles/"
local mpd_connect = mpd_connect


function piepan.format_clock(timestamp)
        local timestamp = tonumber(timestamp)
        return string.format("%.2d:%.2d:%.2d", timestamp/(60*60), timestamp/60%60, timestamp%60)
end

----------------------------------------------------------------------
-- format_song function
----------------------------------------------------------------------
function piepan.format_song(song)
        -- piepan.showtable(song)
        local ret = ''
	if(not song ) then return '(Rien)' end
        if(song['Artist']) then ret = ret .. song['Artist'] .. ' - ' end
        if(song['Album']) then ret = ret .. song['Album'] .. ' - ' end
        if(song['Title']) then ret = ret .. song['Title'] end
        if(song['Date']) then ret = ret .. ' (' .. song['Date'] .. ')' end
        if('' == ret) then ret = song['file'] end
        return ret
end


function piepan.send_song_infos()
	print("Sending song info ...")
        local song = mpd_client:currentsong()
        local status = mpd_client:status()
        -- print("Volume : " .. status['volume'])
        -- piepan.showtable(s)
        local tstr = ''
        if(status['time']) then
        	time_pair = piepan.splitPlain(status['time'],':')
                -- print("Time : " .. status['time'] .. tostring(time_pair[1]))
                tstr = '[' .. piepan.format_clock(time_pair[1])
                tstr = tstr .. ' / ' .. piepan.format_clock(time_pair[2]) .. ']'
        end
        local summary = piepan.format_song(song) or ''

        local ret = summary .. ' - ' .. tstr .. ' [vol ' .. tostring(status['volume'] or '?') .. '% R' .. (status['random'] or '?') .. ' C' .. (status['consume'] or '?') .. ']'
                -- msg.user:send(ret)
        print("Summary : " .. ret)
        piepan.me.channel:send(msg_prefix .. "Lecture en cours : " .. ret .. msg_suffix)
end
----------------------------------------------------------------------
-- function mpdmonitor : scan for mpd changes
----------------------------------------------------------------------
function piepan.mpdmonitor(params)
	local last_song = ''
	-- client = piepan.MPD.mpd_connect(flags["mpd_server"],flags["mpd_port"],true)
	while true do
		if not mpd_client or not mpd_client.loaded or mpd_client.password == nil then
                	print("Reconnecting to mpd server ...")
                	mpd_client = piepan.MPD.mpd_connect(flags["mpd_server"],flags["mpd_port"],true)
                	mpd_client.loaded = true

			-- we do not need auth here; skip the password message
	        end


		-- print("*MON* connecting ...")
		local current_song = mpd_client:currentsong()['file'] or ''
		-- print("*MON* checking song : " .. current_song)
		if(current_song ~= last_song) then
			print("*MON* Song changed : " .. current_song)
			last_song = current_song
			piepan.send_song_infos()
		end
		-- print("*MON* waiting ...")
		-- time.sleep(1.0)
		piepan.MPD.sleep(1.0)
		-- client:idle({"database", "playlist" })
		-- client:idle({"database", "update", "stored_playlist", "playlist", "player", "mixer", "output_options" })
		-- print("*MON* stopped waiting.")
	end
	-- client:close()
end
function piepan.mpdmonitor_completed(info)

end

----------------------------------------------------------------------
-- piepan functions
----------------------------------------------------------------------

function piepan.mpdauth(mpd_client)
	print("Auth ...")
	print(mpd_client:password(flags["mpd_password"]))
end

function piepan.onConnect()
   if piepan.args.soundboard then
      prefix = piepan.args.soundboard
   end
   print ("Loading configuration...")
   if (parseConfiguration())
   then
      print("ok.")
   else
      print("error.")
   end
   print('Connecting to MPD server '.. flags["mpd_server"] ..':' .. flags["mpd_port"] ..' ...')
   mpd_client = piepan.MPD.mpd_connect(flags["mpd_server"],flags["mpd_port"],true)
   mpd_client.loaded = true
   piepan.mpdauth(mpd_client)
   print("Starting monitor ...")
   piepan.Thread.new(piepan.mpdmonitor,piepan.mpdmonitor_completed,{})
   
end

----------------------------------------------------------------------
-- added to check files existance from:
-- https://stackoverflow.com/questions/4990990/lua-check-if-a-file-exists
----------------------------------------------------------------------
function file_exists(name)
   local f = io.open(name,"r")
   if (f~=nil)
   then io.close(f) 
      return true 
   else 
      return false 
   end
end

----------------------------------------------------------------------
-- parseConfiguration function, no arguments 
----------------------------------------------------------------------
function parseConfiguration ()
   local conf_file = nil
   local term = {}
   if (file_exists(configuration_file)) then
      conf_file = assert(io.open(configuration_file, "r"))
      if not conf_file then
          print ("Failed to open " .. configuration_file .. " for reading")
          return false
      end

      -- local line = conf_file:read()
   else
      return false
   end

   
   for line in conf_file:lines()
   do
      local i = 0
      if not (string.match(line,'^#') or  
	      string.match(line,'^$'))
      then
	 for word in string.gmatch(line, '([^ ]+)')
	 do
	    term[i] = word
	    i=i+1
	 end
	 setConfiguration(term)
      end
   end
   flags['loaded'] = true
   return true
end

----------------------------------------------------------------------
-- setConfiguration with defined terms into flags array.
----------------------------------------------------------------------
function setConfiguration (array)
   -- debug configuration flags
   if (string.match(array[0], "debug") and
       string.match(array[1],"%d+")) 
   then
      flags["debug"] = tonumber(array[1])

   -- irc server configuration flags
   elseif (string.match(array[0], 'irc') and
	   string.match(array[1], 'server') and
	   array[2]~='') 
   then
      flags["irc_server"] = array[2]

   -- irc port configuration flags
   elseif (string.match(array[0], 'irc') and
	   string.match(array[1], 'port') and
	   string.match(array[2],"%d+")) 
   then
      if (tonumber(array[2])>0 and
	  tonumber(array[2])<65536)
      then
	 flags["irc_port"]=tonumber(array[2])
      end

   -- irc chan configuration flags
   elseif (string.match(array[0], 'irc') and
	   string.match(array[1], 'chan') and
	   array[2]~='') 
   then
      flags["irc_chan"]=array[2]
      
   -- mumble server configuration flag
   elseif (string.match(array[0], 'mumble') and
	   string.match(array[1], 'server') and
	   array[2]~='') 
   then
      flags["mumble_server"]=array[2]
   
   -- mumble port configuration flag
   elseif (string.match(array[0], 'mumble') and
	   string.match(array[1], 'port') and
	   string.match(array[2], "%d+")) 
   then
      if (tonumber(array[2])>0 and
	  tonumber(array[2])<65536)
      then
	 flags["mumble_port"]=tonumber(array[2])
      end
   
   -- mumble chan configuration flag
   elseif (string.match(array[0], 'mumble') and
	   string.match(array[1], 'chan') and
	   array[2]~='')
   then
      flags["mumble_chan"]=array[2]
   
   -- mpd server configuration flag
   elseif (string.match(array[0], 'mpd') and
	   string.match(array[1], 'server') and
	   array[2]~='') 
   then
      flags["mpd_server"]=array[2]
   
   -- mpd port configuration flag
   elseif (string.match(array[0], 'mpd') and
	   string.match(array[1], 'port') and
	   string.match(array[2], "%d+"))
   then
      if (tonumber(array[2])>0 and
	  tonumber(array[2])<65536)
      then
	 flags["mpd_port"]=tonumber(array[2])
      end

  -- mpd password configuration flag
   elseif (string.match(array[0], 'mpd') and
           string.match(array[1], 'password') and
           array[2]~='')
   then
      flags["mpd_password"]=array[2]
 
   -- mpd web server configuration flag
   elseif (string.match(array[0], 'web') and
	   string.match(array[1], 'server') and
	   array[2]~='')
   then
      flags["web_server"]=array[2]

   -- mpd web port configuration flag
   elseif (string.match(array[0], 'web') and
	   string.match(array[1], 'port') and
	   string.match(array[2], "%d+"))
   then
      if (tonumber(array[2])>0 and
	  tonumber(array[2])<65536)
      then
	 flags["web_port"]=tonumber(array[2])
      end
   end
end

----------------------------------------------------------------------
-- get_listeners, return sum of listeners
----------------------------------------------------------------------
function get_listeners(server, port)
   
   -- check if arguments are okay
   if not (string.match(server, ".+")) then
      print("error on first arg")
      return -1
   end

   if not (string.match(port, "%d+")) then
      print("error on second arg")
      return -1
   end

   -- local UNIX commands
   curl_command="/usr/bin/curl --silent http://"..server..":"..port
   -- grep_command="/bin/grep -r 'Current Listeners' -A1"
   grep_command="/bin/grep 'Current Listeners' -A1"
   get_command=curl_command.."|"..grep_command

   print("get_command : " .. get_command)
   -- open pipe and execute get_command
   local listeners = assert(io.popen(get_command, 'r'), "pipe error")
   -- define 2 "random" string and init buf
   local _start="GOdwkg##"
   local _end="==AHbewA"
   local buf=0

   -- if listeners is not empty
   if (listeners)
   then
      
      -- read all command output line by line
      for line in listeners:lines()
      do
	 
	 -- if line match with streamdata...
	 if (string.match(line, "streamdata"))
	 then

	    -- ...parse it...
	    s=string.gsub(line, "%d+", _start.."%1".._end)
	    s=string.gsub(s, ".*".._start, "")
	    s=string.gsub(s, _end..".*", "")
	    
	    -- ...and generate sum of listeners
	    if (string.match(s,"%d"))
	    then
	       buf=buf+tonumber(s)
	    end
	 end
      end

      -- finaly, close pipe and return buf
      listeners:close()
      return buf
   else

      -- else return -1
      return -1
   end
end

----------------------------------------------------------------------
-- jingle object
----------------------------------------------------------------------
local jingle = {}

function jingle:new ()
   
end

function jingle:load ()
end

----------------------------------------------------------------------
-- split function
----------------------------------------------------------------------
function string:split(sep)
        local sep, fields = sep or ":", {}
        local pattern = string.format("([^%s]+)", sep)
        self:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
end

function piepan.splitPlain(s, delim)
  assert (type (delim) == "string" and string.len (delim) > 0,
          "bad delimiter : " .. delim)
  local start = 1
  local t = {}  -- results table
  -- find each instance of a string followed by the delimiter
  while true do
    local pos = string.find (s, delim, start, true) -- plain find
    if not pos then break end
    table.insert (t, string.sub (s, start, pos - 1))
    start = pos + string.len (delim)
  end -- while
  -- insert final one (after last delimiter)
  table.insert (t, string.sub (s, start))
  return t

end -- function split

----------------------------------------------------------------------
-- format_song function
----------------------------------------------------------------------
function piepan.format_song(song)
	-- piepan.showtable(song)
	ret = ''
	if(song['Artist']) then ret = ret .. song['Artist'] .. ' - ' end
	if(song['Album']) then ret = ret .. song['Album'] .. ' - ' end 
	if(song['Title']) then ret = ret .. song['Title'] end
	if(song['Date']) then ret = ret .. ' (' .. song['Date'] .. ')' end
	if('' == ret) then ret = song['file'] end
	return ret
end

----------------------------------------------------------------------
-- from PiL2 20.4
----------------------------------------------------------------------
function piepan.trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

----------------------------------------------------------------------
-- function url_encode
----------------------------------------------------------------------
function piepan.url_encode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str	
end

----------------------------------------------------------------------
-- function unaccent : replace accents from strings
----------------------------------------------------------------------
local translatechars = function (str, re, tbl)
     return (string.gsub(str, re, function (c) return tbl[c] or c end))
   end

function unaccent(str)
	unaccent_from, unaccent_to =
   "ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöøùúûüý",
   "AAAAAACEEEEIIIINOOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuy"

	unaccent_table = {}
	for i = 1,string.len(unaccent_from) do
		unaccent_table[string.sub(unaccent_from, i, i)] =
		string.sub(unaccent_to, i, i)
	end
	unaccent_re = "([\192-\254])"
	return translatechars(str, unaccent_re, unaccent_table)
end
----------------------------------------------------------------------
-- function show tables
----------------------------------------------------------------------
function piepan.showtable(t)
	for key,value in pairs(t) do
		print("Found member " .. key);
	end
end

----------------------------------------------------------------------
-- function tablelenth
----------------------------------------------------------------------
function piepan.tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

----------------------------------------------------------------------
-- function starts
----------------------------------------------------------------------
function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

----------------------------------------------------------------------
-- function string.end
----------------------------------------------------------------------
function string.ends(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end

----------------------------------------------------------------------
-- function countsubstring
----------------------------------------------------------------------
function piepan.countsubstring( s1, s2 )
   local magic =  "[%^%$%(%)%%%.%[%]%*%+%-%?]"
   local percent = function(s)return "%"..s end
   return select( 2, s1:gsub( s2:gsub(magic,percent), "" ) )
end

----------------------------------------------------------------------
-- function youtubedl
----------------------------------------------------------------------
function piepan.youtubedl(params)
	url = piepan.trim(params['url'])
	user = params['user']
	print("youtubedl "..user.." : "..url)
	n1,n2 = string.find(url,' ')
	if(n1) then
		link = string.sub(url,n1+1)
		link = link:gsub("%b<>", "")
		link = link:gsub("'", " ")
		link = link:gsub("%s+", "+")
		link = unaccent(link)
		print("reformated link : " .. link)
		piepan.me.channel:send('# ' .. msg_prefix .. "Chargement en cours : [" .. link .. "] ..." .. msg_suffix)
		print("Loading [" .. link .. "] ...")
		local file = assert(io.popen('./yt_dl.sh '.. user .. ' ' .. link, 'r'))
		local output = file:read('*all')
		file:close()
		print(output)
		n1,n2 = string.find(output,"[avconv] Destination: ",nil,true)
		if(n1) then
			n3,n4 = string.find(output,"\n",n2)
			if(n3) then
				file = piepan.trim(string.sub(output,n2,n3))
				print("Found : [" .. file .. "]")
				piepan.me.channel:send('# ' .. msg_prefix .. "Téléchargement terminé : " .. file .. msg_suffix)
				mpd_client:update('download')
				-- client:idle('download')
				-- socket.sleep(5)
				os.execute("sleep " .. tonumber(5))
				uri = '"download/' .. file .. '"'
				-- print(client:add("file://" .. uri))
				print(mpd_client:sendrecv("add " .. uri))
				-- client:add("download/" .. file)
				print("Adding : [" .. uri .. "]")
				-- piepan.me.channel:send(msg_prefix .. "Morceau ajouté à la liste." .. msg_suffix)
			else
				print("Failed to find EOL")
			end
		else
			n1, n2 = string.find(output,"[download] File is larger",nil,true)
			if(n1) then
				piepan.me.channel:send('# ' .. msg_prefix .. "Fichier trop volumineux (>70Mo)" .. msg_suffix)
			else
				print("Failed to find '[avconv] Destination' in " .. output)
				piepan.me.channel:send(msg_prefix .. "Le téléchargement a merdé." .. msg_suffix)
			end
		end
		-- piepan.me.channel:send(output)
	end
end

----------------------------------------------------------------------
-- function youtubedl_completed
----------------------------------------------------------------------
function piepan.youtubedl_completed(info)
	print("youtubedl_completed")
end

----------------------------------------------------------------------
-- function fadevol
----------------------------------------------------------------------
function piepan.fadevol(dest)
	-- client = piepan.MPD.mpd_connect(flags["mpd_server"],flags["mpd_port"],true)
	-- print("fadevol dest = " .. tostring(dest))
	vol = tonumber(mpd_client:status()['volume'])
	delta = 1
	-- print("fadevol vol = " .. tostring(vol))
	if(vol == dest) then
		-- client:close()
		return 
	end
	if(dest < vol) then delta = - delta end
	print("fadevol " .. tostring(vol) .. " => " .. tostring(dest) .. " d=" .. tostring(delta))
	while true do
		if delta>0 and dest<=vol then break end
		if delta<0 and dest>=vol then break end
		vol = vol + delta
		-- print("fadevol => " .. tostring(vol))
		mpd_client:set_vol(vol)
		--#print("dv " + str(vol) +" %")$
		 -- time.sleep(0.2) -- = 5% par seconde
		piepan.MPD.sleep(0.2)
	end
	-- client:close()
	piepan.me.channel:send(msg_prefix .. "Volume ajusté à " .. tostring(vol) .. "%" .. msg_suffix)
	-- client = nil
	-- print("fadevol done.")
end

----------------------------------------------------------------------
-- function fadevol_completed
----------------------------------------------------------------------
function piepan.fadevol_completed(info)
	-- print("fadevol_completed " .. (info or '?'))
end

----------------------------------------------------------------------
-- function onMessage
----------------------------------------------------------------------
function piepan.onMessage(msg)
    if msg.user == nil then
        return
    end
    if g_bans[msg.user.name] then
    	msg.user:send("You have been banned.")
	return
    end
    print(msg.user.name .. "> " .. msg.text) 
    
    msg.text = msg.text:gsub("<p.->(.-)</p>","%1")

    print("reformated : [" .. msg.text .. "]") 
    
    local search = string.match(msg.text, "^#(%w+)")

    if(msg.text == "Kristel") then
        piepan.me.channel:send('Ok.')
        os.exit()
        return
    end
    if(msg.text == "ping") then
        piepan.me.channel:send('pong')
        return
    end

    if(msg.text == "#l2") then
	piepan.showtable(piepan.users)
	local ucount = 0
	local ucountt = 0
	for uname,u in pairs(piepan.users) do 
	--	print(k,v) 
		print(u)
		piepan.showtable(u)
		if(not u.isServerDeafened and not u.isSelfDeafened) then
			ucount = ucount + 1
		end
		ucountt = ucountt + 1
	end	
	print("count : "..tostring(ucount) .. "/"..tostring(ucountt))
	return
    end


    if not search then
    	return
    end
    if sounds[search] then
	if(os.time()<disable_jingle_ts ) then
		piepan.me.channel:send(msg_prefix .. "Jingles désactivés." .. msg_suffix)
		return
	end
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
	if require_registered and msg.user.userId == nil then
		msg.user:send("Vous devez vous enregistrer pour envoyer des commandes.")
		return
	end

	-- we may have lost the connection since the initial auth	
	
	if not mpd_client or not mpd_client.loaded or mpd_client.password == nil then
		print("Reconnecting to mpd server ...")
		mpd_client = piepan.MPD.mpd_connect(flags["mpd_server"],flags["mpd_port"],true)
		mpd_client.loaded = true
	end
	
	if not flags['loaded'] then
		print("Reloading configuration ...")
		parseConfiguration()
	end

	--	piepan.mpdauth(mpd_client)
	print(mpd_client:password(flags["mpd_password"]))
	-- piepan.showtable(msg.user)
	-- return


	-- print(flags["mpd_server"] .. "  " .. tostring(flags["mpd_port"]))
	-- client = piepan.MPD.mpd_connect(flags["mpd_server"],flags["mpd_port"],true)
	if("setvol" == c) then
		vol = tonumber(string.sub(msg.text,8))
		vol = math.max(0,math.min(100,vol))
		print(mpd_client:set_vol(vol))
		piepan.me.channel:send(msg_prefix .. "Volume ajusté à " .. tostring(vol) .. "%" .. msg_suffix)
	elseif("keep" == c) then
		song = mpd_client:currentsong()
		print("keep: Currently playing " .. song['file'])
		if(string.starts(song['file'],'download/')) then
			dest = './download-keep/'
			-- copy file instead of moving because the song is currently playing
			ret = assert(io.popen('cp "./' .. song['file'] .. '" ' .. dest, 'r'), "failed to copy file")
			
			-- for line in ret:lines()
			-- do
			-- 	print(line)
			-- end
			-- print(ret)
			-- todo check cp ret
			mpd_client:update('download-keep') -- udpate mpd database
			piepan.me.channel:send(msg_prefix .. "Le fichier a été sauvegardé dans le repertoire /download-keep." .. msg_suffix)
		else 
			print('Not a downloaded file.')
			piepan.me.channel:send(msg_prefix .. "Ceci n'est pas un fichier téléchargé." .. msg_suffix)
		end
	elseif("next?" == c) then
		status = mpd_client:status()
		nextid = status['nextsongid']
		print("Next song id : " .. tostring(nextid))
		
		for id, song in pairs(mpd_client:playlistinfo()) do
			-- piepan.showtable(song)
			-- print("checking song " .. song['Id'])
			if(song['Id'] == nextid) then
				summary = piepan.format_song(song)
				-- print(summary)
				piepan.me.channel:send(msg_prefix .. "Prochain morceau : " .. summary .. msg_suffix)
			end
		end
	elseif("enablej" == c) then
		disable_jingle_ts = 0
		piepan.me.channel:send(msg_prefix .. "Jingles activés." .. msg_suffix)
	elseif("disablej" == c) then
		disable_jingle_ts = os.time() + 60 * 5
		piepan.me.channel:send(msg_prefix .. "Jingles désactivés pendant 5 minutes." .. msg_suffix)
	elseif("fadevol" == c) then
		print("fadevol " .. msg.text)
		vol = tonumber(string.sub(msg.text,9))
		vol = math.max(0,math.min(100,vol))
		-- piepan.fadevol(vol)
		piepan.Thread.new(piepan.fadevol,piepan.fadevol_completed,vol)
	elseif(msg.text:starts('#v+')) then
		print("V+" .. tostring(piepan.countsubstring(msg.text,'+')))
		s = mpd_client:status()
		v = tonumber(s['volume'])
		v = math.min(100,v + 5 * piepan.countsubstring(msg.text,'+'))
		piepan.Thread.new(piepan.fadevol,piepan.fadevol_completed,v)
		-- client:set_vol(v)
		-- piepan.me.channel:send(msg_prefix .. "Volume ajusté à " .. tostring(v) .. "%" .. msg_suffix)
	elseif(msg.text:starts('#v-')) then
		print("V-")
		s = mpd_client:status()
		v = tonumber(s['volume'])
		v = math.max(0,v - 5 * piepan.countsubstring(msg.text,'-'))
		piepan.Thread.new(piepan.fadevol,piepan.fadevol_completed,v)
		-- client:set_vol(v)
		-- piepan.me.channel:send(msg_prefix .. "Volume ajusté à " .. tostring(v) .. "%" .. msg_suffix)
	elseif(msg.text:starts('#xfade ')) then
		local val = tonumber(string.sub(msg.text,7))
		val = math.max(0,math.min(10,val))
		mpd_client:set_crossfade(val)
		piepan.me.channel:send("Ok")
	elseif(msg.text:starts('#random ')) then
		local val = tonumber(string.sub(msg.text,8))
		val = math.max(0,math.min(1,val))
		mpd_client:set_random(val)
		piepan.me.channel:send("Ok")
	elseif(msg.text:starts('#consume ')) then
		local val = tonumber(string.sub(msg.text,9))
		val = math.max(0,math.min(1,val))
		mpd_client:set_consume(val)
		piepan.me.channel:send("Ok")
	elseif("shuffle" == c) then
		mpd_client:shuffle()
                piepan.me.channel:send("Ok")
	elseif("youtube" == c) then
		piepan.Thread.new(piepan.youtubedl,piepan.youtubedl_completed ,{url = msg.text, user = msg.user.name})
	elseif("listeners" == c) then
		local listeners = get_listeners("212.129.4.80",8000) 
		print("Listeners : " .. tostring(listeners))
		piepan.showtable(piepan.users)
        	local ucount_nd = 0
        	local ucountt = 0
		local ucount_nm = 0
        	for uname,u in pairs(piepan.users) do
                -- print(u)
                -- piepan.showtable(u)
			if("-" ~= u.name
                                and "|" ~= u.name
                                and "int3rnet" ~= u.name
				and u.channel.id == piepan.me.channel.id) then

                		if(not u.isServerDeafened and not u.isSelfDeafened) then
        	                	ucount_nd = ucount_nd + 1
	        		end
				if(not u.isServerMuted and not u.isSelfMuted) then
					ucount_nm = ucount_nm + 1
				end
	                	ucountt = ucountt + 1
			end
	        end
        	-- print("count : "..tostring(ucount) .. "/"..tostring(ucountt))
	
		piepan.me.channel:send("Nombre d'auditeurs : " .. tostring(listeners) .. " (flux).."  )
		piepan.me.channel:send("Nombre d'animateurs : ".. tostring(ucount_nd) .. " non sourds, ".. tostring(ucount_nm).." non muets sur ".. tostring(ucountt)  .. "."  )
		
	elseif("last" == c) then
		pli = mpd_client:playlistinfo()
		-- piepan.showtable(pli)
		pli_len = piepan.tablelength(pli)
		print("Playlist length = " .. tostring(pli_len))
		last = pli[pli_len]['Id']
		-- piepan.showtable(pli[pli_len])
		print("Last : " .. tostring(last))
		mpd_client:playid(tonumber(last))
	elseif("next" == c) then
		print(mpd_client:next())
		piepan.me.channel:send("Ok")
	elseif("stop" == c) then
		print(mpd_client:stop())
		piepan.me.channel:send("Ok")
	elseif("play" == c) then
		-- print(client:pause(false))
		
		status = mpd_client:status()
		song = mpd_client:currentsong()
		piepan.showtable(song)
		if not song or not song['file'] or song['Pos'] == 0 then
			pli = mpd_client:playlistinfo()
			if piepan.tablelength(pli)>0 then
				print(mpd_client:playid(tonumber(pli[1]['Id'])))
				piepan.me.channel:send("Ok")
			else
				piepan.me.channel:send("Playlist vide.")
			end
		else
			print(mpd_client:unpause())
			piepan.me.channel:send("Ok")
		end
	elseif("pause" == c) then
		print(mpd_client:pause(true))
		piepan.me.channel:send("Ok")
	elseif("prev" == c) then
		print(mpd_client:previous())
		piepan.me.channel:send("Ok")
	elseif("help" == c) then
		s = msg_prefix .. "<b>Commandes</b>" .. msg_suffix
		s = s .. "<pre style='color:#777'><ul>"
		s = s .. "<li>#s : Affiche le morceau en cours de lecture</li>"
		s = s .. "<li>#v : Affiche le volume actuel</li>"
		s = s .. "<li>#y -lien- : Télécharge un morceau et l'ajoute à la playlist</li>"
		s = s .. "<li>#setvol -volume- / #fadevol -volume- : Ajuste le volume à la valeur indiquée</li>"
		s = s .. "<li>#v+ : Augmente le volume de 5% par '+'</li>"
		s = s .. "<li>#v- : Diminue le volume de 5% par '-'</li>"
		s = s .. "<li>#next, #last, #prev, #play, #pause : Contrôles de lecture</li>"
		s = s .. "<li>#random 0/1, #consume 0/1, #xfade 0..N : Change les modes de lecture</li>"
		s = s .. "<li>#keep : copie le fichier en cours de lecture dans un repertoire non temporaire</li>"
		s = s .. "<li>#shuffle : mélange la playlist</li>"
		s = s .. "<li>#disablej : désactive les jingles pendant 5 minutes</li>"
		s = s .. "</ul></pre>"
		piepan.me.channel:send(s)
	elseif("volume" == c) then
		s = mpd_client:status()
		piepan.me.channel:send(msg_prefix .. "Volume : " .. tostring(s['volume']) .. "%" .. msg_suffix)
	elseif ("song" == c) then
		piepan.send_song_infos()
	end
	-- client:close()
    end
end
