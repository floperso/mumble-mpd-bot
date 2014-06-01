local socket = require("socket.core")

--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

-- TODO:  kill any timers, threads, callbacks owned by a script when it reloads

piepan = {
    Audio = {},
    User = {},
    UserChange = {},
    Message = {},
    Channel = {},
    ChannelChange = {},
    PermissionDenied = {},
    Permissions = {},
    Thread = {},
    Timer = {},
    MPD = {},

    server = {
        -- has the client been fully synced with the server yet?
        synced = false
    },
    internal = {
        api = {},
        opus = {},
        events = {},
        threads = {},
        timers = {},
        meta = {},
        -- table of Users with the user's session ID as the key
        users = {},
        permissionsMap = {
            write   = 0x1,
            traverse = 0x2,
            enter = 0x4,
            speak = 0x8,
            muteDeafen = 0x10,
            move = 0x20,
            makeChannel = 0x40,
            linkChannel = 0x80,
            whisper = 0x100,
            textMessage = 0x200,
            makeTemporaryChannel = 0x400,
            kick = 0x10000,
            ban = 0x20000,
            register = 0x40000,
            registerSelf = 0x80000
        },
        resolving = {
            users = {},
            channels = {}
        },
        currentAudio,
        state
    },
    -- arguments passed to the piepan executable
    args = {},
    scripts = {},
    users = {},
    channels = {}
}

piepan.Audio.__index = piepan.Audio
piepan.User.__index = piepan.User
piepan.UserChange.__index = piepan.UserChange
piepan.Message.__index = piepan.Message
piepan.Channel.__index = piepan.Channel
piepan.ChannelChange.__index = piepan.ChannelChange
piepan.PermissionDenied.__index = piepan.PermissionDenied
piepan.Permissions.__index = piepan.Permissions
piepan.Timer.__index = piepan.Timer
--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

function piepan.internal.initialize(tbl)
    local password, tokens

    piepan.internal.state = tbl.state

    if tbl.passwordFile then
        local file, err
        if tbl.passwordFile == "-" then
            file, err = io.stdin, "could not read from stdin"
        else
            file, err = io.open(tbl.passwordFile)
        end
        if file then
            password = file:read()
            if tbl.passwordFile ~= "-" then
                file:close()
            end
        else
            print ("Error: " .. err)
        end
    end

    if tbl.tokenFile then
        local file, err = io.open(tbl.tokenFile)
        if file then
            tokens = {}
            for line in file:lines() do
                if line ~= "" then
                    table.insert(tokens, line)
                end
            end
            file:close()
        else
            print ("Error: " .. err)
        end
    end

    piepan.internal.api.apiInit(piepan.internal.api)
    piepan.internal.api.connect(tbl.username, password, tokens)
end

function piepan.internal.meta.__index(tbl, key)
    if key == "internal" then
        return
    end
    return piepan[key]
end
--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

function piepan.internal.events.onLoadScript(argument, ptr)
    local index
    local entry

    if type(argument) == "string" then
        index = #piepan.scripts + 1
        entry = {
            filename = argument,
            ptr = ptr,
            environment = {
                print = print,
                assert = assert,
                collectgarbage = collectgarbage,
                dofile = dofile,
                error = error,
                getmetatable = getmetatable,
                ipairs = ipairs,
                load = load,
                loadfile = loadfile,
                next = next,
                pairs = pairs,
                pcall = pcall,
                print = print,
                rawequal = rawequal,
                rawget = rawget,
                rawlen = rawlen,
                rawset = rawset,
                require = require,
                select = select,
                setmetatable = setmetatable,
                tonumber = tonumber,
                tostring = tostring,
                type = type,
                xpcall = xpcall,

                bit32 = bit32,
                coroutine = coroutine,
                debug = debug,
                io = io,
                math = math,
                os = os,
                package = package,
                string = string,
                table = table
            }
        }
    elseif type(argument) == "number" then
        index = argument
        entry = piepan.scripts[index]
    else
        return false, "invalid argument"
    end

    local script, message = loadfile(entry.filename, "bt", entry.environment)
    if script == nil then
        return false, message
    end
    entry.environment.piepan = {}
    local status, message = pcall(script)
    if status == false then
        return false, message
    end

    piepan.scripts[index] = entry
    if type(entry.environment.piepan) == "table" then
        setmetatable(entry.environment.piepan, piepan.internal.meta)
    end

    return true, index, ptr
end

--
-- Callback execution
--
function piepan.internal.triggerEvent(name, ...)
    for _,script in pairs(piepan.scripts) do
        local func = rawget(script.environment.piepan, name)
        if type(func) == "function" then
            piepan.internal.runCallback(func, ...)
        end
    end
end

function piepan.internal.runCallback(func, ...)
    assert(type(func) == "thread" or type(func) == "function",
        "func should be a coroutine or a function")

    local routine
    if type(func) == "thread" then
        routine = func
    else
        routine = coroutine.create(func)
    end
    local status, message = coroutine.resume(routine, ...)
    if not status then
        print ("Error: " .. message)
    end
end

--
-- Argument parsing
--
function piepan.internal.events.onArgument(key, value)
    assert(type(key) ~= nil, "key cannot be nil")

    value = value or ""
    if piepan.args[key] == nil then
        piepan.args[key] = {value}
    else
        table.insert(piepan.args[key], value)
    end
end
--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

function piepan.Timer.new(func, timeout, data)
    assert(type(func) == "function", "func must be a function")
    assert(type(timeout) == "number" and timeout > 0 and timeout <= 3600,
        "timeout is out of range")

    local id = #piepan.internal.timers + 1
    local timerObj = {
        id = id
    }
    piepan.internal.timers[id] = {
        func = func,
        data = data,
        ptr = nil,
        state = nil
    }
    piepan.internal.api.timerNew(piepan.internal.timers[id], id, timeout,
        piepan.internal.state)

    setmetatable(timerObj, piepan.Timer)
    return timerObj
end

function piepan.Timer:cancel()
    assert(self ~= nil, "self cannot be nil")

    local timer = piepan.internal.timers[self.id]
    if timer == nil then
        return
    end
    piepan.internal.api.timerCancel(timer.ptr)
    piepan.internal.timers[self.id] = nil
    self.id = nil
end

function piepan.internal.events.onUserTimer(id)
    local timer = piepan.internal.timers[id]
    if timer == nil then
        return
    end

    piepan.internal.timers[id] = nil
    piepan.internal.runCallback(timer.func, timer.data)
end
--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

function piepan.Thread.new(worker, callback, data)
    assert(type(worker) == "function", "worker needs to be a function")
    assert(callback == nil or type(callback) == "function",
        "callback needs to be a function or nil")

    local id = #piepan.internal.threads + 1
    local thread = {
        worker = worker,
        callback = callback,
        data = data
    }
    piepan.internal.threads[id] = thread
    piepan.internal.api.threadNew(thread, id)
end

-- TODO:  string.dump the function first so we can prevent it from accessing
--        certain upvalues
function piepan.internal.events.onThreadExecute(id)
    local thread = piepan.internal.threads[id]
    if thread == nil then
        return
    end
    status, val = pcall(thread.worker, thread.data)
    if status == true then
        thread.rtn = val
    end
end

function piepan.internal.events.onThreadFinish(id)
    local thread = piepan.internal.threads[id]
    if thread == nil then
        return
    end
    if thread.callback ~= nil and type(thread.callback) == "function" then
        piepan.internal.runCallback(thread.callback, thread.rtn)
    end
    piepan.internal.threads[id] = nil
end
--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

function piepan.User:moveTo(channel)
    assert(self ~= nil, "self cannot be nil")
    assert(getmetatable(channel) == piepan.Channel,
            "channel must be a piepan.Channel")

    if channel == self.channel then
        return
    end
    piepan.internal.api.userMoveTo(self, channel.id)
end

function piepan.User:kick(message)
    assert(self ~= nil, "self cannot be nil")

    piepan.internal.api.userKick(self, tostring(message))
end

function piepan.User:ban(message)
    assert(self ~= nil, "self cannot be nil")

    piepan.internal.api.userBan(self, tostring(message))
end

function piepan.User:send(message)
    assert(self ~= nil, "self cannot be nil")

    piepan.internal.api.userSend(self, tostring(message))
end

function piepan.User:setComment(comment)
    assert(self ~= nil, "self cannot be nil")
    assert(type(comment) == "string" or comment == nil,
        "comment must be a string or nil")

    if comment == nil then
        comment = ""
    end
    piepan.internal.api.userSetComment(self, comment)
end

function piepan.User:register()
    assert(self ~= nil, "self cannot be nil")

    piepan.internal.api.userRegister(self)
end

function piepan.User:resolveHashes()
    assert(self ~= nil, "self cannot be nil")
    local comment, texture
    local request
    local count = 0

    if self.textureHash ~= nil then
        texture = {self.session}
        count = count + 1
    end
    if self.commentHash ~= nil then
        comment = {self.session}
        count = count + 1
    end
    if texture == nil and comment == nil then
        return
    end

    local running = coroutine.running()
    local tbl = {
        routine = running,
        count = count
    }
    if piepan.internal.resolving.users[self.session] == nil then
        piepan.internal.resolving.users[self.session] = {tbl}
        request = true
    else
        if #piepan.internal.resolving.users <= 0 then
            request = true
        end
        table.insert(piepan.internal.resolving.users[self.session], tbl)
    end
    if request then
        piepan.internal.api.resolveHashes(texture, comment, nil)
    end
    coroutine.yield()
end

function piepan.User:setTexture(bytes)
    assert(self ~= nil, "self cannot be nil")
    assert(type(bytes) == "string" or bytes == nil, "bytes must be a string or nil")

    if bytes == nil then
        bytes = ""
    end

    piepan.internal.api.userSetTexture(bytes)
end
--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

setmetatable(piepan.channels, {
    __call = function (self, path)
        if piepan.channels[0] == nil then
            return nil
        end
        return piepan.channels[0](path)
    end
})

function piepan.Channel:__call(path)
    assert(self ~= nil, "self cannot be nil")

    if path == nil then
        return self
    end
    local channel = self
    for k in path:gmatch("([^/]+)") do
        local current
        if k == "." then
            current = channel
        elseif k == ".." then
            current = channel.parent
        else
            current = channel.children[k]
        end

        if current == nil then
            return nil
        end
        channel = current
    end
    return channel
end

function piepan.Channel:play(filename, callback, data)
    assert(self ~= nil, "self cannot be nil")
    assert(type(filename) == "string", "filename must be a string")

    if piepan.internal.currentAudio ~= nil then
        return false
    end

    local ptr = piepan.internal.api.channelPlay(piepan.internal.state,
        piepan.internal.opus.encoder, filename)
    if not ptr then
        return false
    end
    piepan.internal.currentAudio = {
        callback = callback,
        callbackData = data,
        ptr = ptr
    }
    return true
end

function piepan.internal.events.onAudioFinished()
    assert (piepan.internal.currentAudio ~= nil, "audio must be playing")

    if type(piepan.internal.currentAudio.callback) == "function" then
        piepan.internal.runCallback(piepan.internal.currentAudio.callback,
            piepan.internal.currentAudio.callbackData)
    end

    piepan.internal.currentAudio = nil
end

function piepan.Channel:send(message)
    assert(self ~= nil, "self cannot be nil")

    piepan.internal.api.channelSend(self, tostring(message))
end

function piepan.Channel:setDescription(description)
    assert(self ~= nil, "self cannot be nil")
    assert(type(description) == "string" or description == nil,
        "description must be a string or nil")

    if description == nil then
        description = ""
    end
    piepan.internal.api.channelSetDescription(self, description)
end

function piepan.Channel:remove()
    assert(self ~= nil, "self cannot be nil")

    piepan.internal.api.channelRemove(self)
end

function piepan.Channel:resolveHashes()
    assert(self ~= nil, "self cannot be nil")

    local request
    if self.descriptionHash == nil then
        return
    end

    local running = coroutine.running()
    if piepan.internal.resolving.channels[self.id] == nil then
        piepan.internal.resolving.channels[self.id] = {running}
        request = true
    else
        if #piepan.internal.resolving.channels[self.id] <= 0 then
            request = true
        end
        table.insert(piepan.internal.resolving.channels[self.id], running)
    end
    if request then
        piepan.internal.api.resolveHashes(nil, nil, {self.id})
    end
    coroutine.yield()
end
--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

function piepan.internal.events.onServerConfig(obj)
    if obj.allowHtml ~= nil then
        piepan.server.allowHtml = obj.allowHtml
    end
    if obj.maxMessageLength ~= nil then
        piepan.server.maxMessageLength = obj.maxMessageLength
    end
    if obj.maxImageMessageLength ~= nil then
        piepan.server.maxImageMessageLength = obj.maxImageMessageLength
    end

    piepan.internal.triggerEvent("onConnect")
end

function piepan.internal.events.onServerSync(obj)
    piepan.me = piepan.internal.users[obj.session]
    if obj.welcomeText ~= nil then
        piepan.server.welcomeText = obj.welcomeText
    end
    if obj.maxBandwidth ~= nil then
        piepan.server.maxBandwidth = obj.maxBandwidth
    end
    piepan.server.synced = true
end

function piepan.internal.events.onMessage(obj)
    local message = {
        text = obj.message
    }
    setmetatable(message, piepan.Message)
    if obj.actor ~= nil then
        message.user = piepan.internal.users[obj.actor]
    end
    if obj.channels ~= nil then
        -- TODO:  add __len
        message.channels = {}
        for _,v in pairs(obj.channels) do
            message.channels[v] = piepan.channels[v]
        end
    end
    if obj.users ~= nil then
        -- TODO:  add __len
        message.users = {}
        for _,v in pairs(obj.users) do
            local user = piepan.internal.users[v]
            if user ~= nil then
                message.users[user.name] = user
            end
        end
    end

    piepan.internal.triggerEvent("onMessage", message)
end

function piepan.internal.events.onUserChange(obj)
    local user
    local event = {}
    setmetatable(event, piepan.onUserChange)
    if piepan.internal.users[obj.session] == nil then
        if obj.name == nil then
            return
        end
        user = {
            session = obj.session,
            channel = piepan.channels[0]
        }
        piepan.internal.users[obj.session] = user
        piepan.users[obj.name] = user
        setmetatable(user, piepan.User)
        event.isConnected = true
    else
        user = piepan.internal.users[obj.session]
    end
    event.user = user

    local resolving = {}

    if obj.userId ~= nil then
        user.userId = obj.userId
    end
    if obj.name ~= nil then
        user.name = obj.name
    end
    if obj.channelId ~= nil then
        user.channel = piepan.channels[obj.channelId]
        event.isChangedChannel = true
    end
    if obj.comment ~= nil then
        user.comment = obj.comment
        user.commentHash = nil
        event.isChangedComment = true

        local tbl = piepan.internal.resolving.users[user.session]
        if tbl then
            for k,v in pairs(tbl) do
                v.count = v.count - 1
                if v.count <= 0 then
                    table.insert(resolving, v.routine)
                    piepan.internal.resolving.users[user.session][k] = nil
                end
            end
        end
        -- TODO:  add flag which states if the blob was requested?
    end
    if obj.isServerMuted ~= nil then
        user.isServerMuted = obj.isServerMuted
    end
    if obj.isServerDeafened ~= nil then
        user.isServerDeafened = obj.isServerDeafened
    end
    if obj.isSelfMuted ~= nil then
        user.isSelfMuted = obj.isSelfMuted
    end
    if obj.isRecording ~= nil then
        user.isRecording = obj.isRecording
    end
    if obj.isSelfDeafened ~= nil then
        user.isSelfDeafened = obj.isSelfDeafened
    end
    if obj.isPrioritySpeaker ~= nil then
        user.isPrioritySpeaker = obj.isPrioritySpeaker
    end
    if obj.hash ~= nil then
        user.hash = obj.hash
    end
    if obj.texture ~= nil then
        user.texture = obj.texture
        user.textureHash = nil

        local tbl = piepan.internal.resolving.users[user.session]
        if tbl then
            for k,v in pairs(tbl) do
                v.count = v.count - 1
                if v.count <= 0 then
                    table.insert(resolving, v.routine)
                    piepan.internal.resolving.users[user.session][k] = nil
                end
            end
        end
        -- TODO:  add flag which states if the blob was requested?
    end
    if obj.textureHash ~= nil then
        user.textureHash = obj.textureHash
        user.texture = nil
    end
    if obj.commentHash ~= nil then
        user.commentHash = obj.commentHash
        user.comment = nil
    end

    for k,v in pairs(resolving) do
        resolving[k] = nil
        piepan.internal.runCallback(v)
    end

    if piepan.server.synced then
        piepan.internal.triggerEvent("onUserChange", event)
    end
end

function piepan.internal.events.onUserRemove(obj)
    local event = {}
    setmetatable(event, piepan.onUserChange)
    if piepan.internal.users[obj.session] ~= nil then
        -- TODO:  remove reference from Channel -> User?
        local name = piepan.internal.users[obj.session].name
        if name ~= nil and piepan.users[name] ~= nil then
            piepan.users[name] = nil
        end
        event.user = piepan.internal.users[obj.session]
        piepan.internal.users[obj.session] = nil
    end

    if piepan.server.synced and event.user ~= nil then
        event.isDisconnected = true
        piepan.internal.triggerEvent("onUserChange", event)
    end
end

function piepan.internal.events.onChannelRemove(obj)
    local channel = piepan.channels[obj.channelId]
    local event = {}
    if channel == nil then
        return
    end
    setmetatable(event, piepan.onChannelChange)
    event.channel = channel

    if channel.parent ~= nil then
        channel.parent.children[channel.id] = nil
        if channel.name ~= nil then
            channel.parent.children[channel.name] = nil
        end
    end
    for k in pairs(channel.children) do
        if k ~= nil then
            k.parent = nil
        end
    end
    piepan.channels[channel.id] = nil

    if piepan.server.synced then
        event.isRemoved = true
        piepan.internal.triggerEvent("onChannelChange", event)
    end
end

function piepan.internal.events.onChannelState(obj)
    local channel
    local event = {}
    setmetatable(event, piepan.onChannelChange)
    if piepan.channels[obj.channelId] == nil then
        channel = {
            id = obj.channelId,
            children = {},
            temporary = false,
            users = {}
        }
        piepan.channels[obj.channelId] = channel
        setmetatable(channel, piepan.Channel)
        event.isCreated = true
    else
        channel = piepan.channels[obj.channelId]
    end
    event.channel = channel

    if obj.temporary ~= nil then
        channel.isTemporary = obj.temporary
    end
    if obj.description ~= nil then
        channel.description = obj.description
        channel.descriptionHash = nil
        event.isChangedDescription = true

        local tbl = piepan.internal.resolving.channels[channel.id]
        if tbl then
            for k,v in pairs(tbl) do
                piepan.internal.resolving.channels[channel.id][k] = nil
                piepan.internal.runCallback(v)
            end
        end
        -- TODO:  add flag which states if the blob was requested?
    end
    if obj.parentId ~= nil then
        -- Channel got a new parent
        if channel.parent ~= nil and channel.parent.id ~= obj.parentId then
            channel.parent.children[channel.id] = nil
            if channel.name ~= nil then
                channel.parent.children[channel.name] = nil
            end
        end

        channel.parent = piepan.channels[obj.parentId]

        if channel.parent ~= nil then
            channel.parent.children[channel.id] = channel
            if channel.name ~= nil then
                channel.parent.children[channel.name] = channel
            end
        end
        event.isMoved = true
    end
    if obj.name ~= nil then
        if channel.parent ~= nil then
            if channel.name ~= nil then
                channel.parent.children[channel.name] = channel
            end
            channel.parent.children[obj.name] = channel
        end
        channel.name = obj.name
        event.isChangedName = true
    end
    if obj.descriptionHash ~= nil then
        channel.descriptionHash = obj.descriptionHash
        channel.description = nil
    end

    if piepan.server.synced then
        piepan.internal.triggerEvent("onChannelChange", event)
    end
end

function piepan.internal.events.onDisconnect(obj)
    piepan.internal.triggerEvent("onDisconnect", event)
end

function piepan.internal.events.onPermissionDenied(obj)
    local event = {}
    print ("Permission denied")
    for k,v in pairs(obj) do
        print (">> " .. tostring(k) .. " => " .. tostring(v))
    end
    if obj.type == nil then
        return
    end
    setmetatable(event, piepan.PermissionDenied)
    if obj.type == 1 then
        event.isPermission = true
    elseif obj.type == 3 then
        event.isChannelName = true
    elseif obj.type == 4 then
        event.isTextTooLong = true
    elseif obj.type == 6 then
        event.isTemporaryChannel = true
    elseif obj.type == 7 then
        event.isMissingCertificate = true
    elseif obj.type == 8 then
        event.isUserName = true
    elseif obj.type == 9 then
        event.isChannelFull = true
    else
        event.isOther = true
    end

    if obj.session ~= nil then
        event.user = piepan.internal.users[obj.session]
    end
    if obj.channelId ~= nil then
        event.channel = piepan.channels[obj.channelId]
    end
    if obj.permission ~= nil then
        event.permissions = piepan.Permissions.new(obj.permission)
    end
    if obj.reason ~= nil then
        event.reason = obj.reason
    end
    if obj.name ~= nil then
        event.name = obj.name
    end

    piepan.internal.triggerEvent("onPermissionDenied", event)
end
--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

function piepan.Permissions.new(permissionsMask)
    assert(type(permissionsMask) == "number", "permissionsMask must be a number")

    local permissions = {}

    for permission,mask in pairs(piepan.internal.permissionsMap) do
        if bit32.band(permissionsMask, mask) ~= 0 then
            permissions[permission] = true
        end
    end

    setmetatable(permissions, piepan.Permissions)
    return permissions
end
--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

function piepan.Audio.stop()
    if not piepan.Audio.isPlaying() then
        return
    end

    piepan.internal.api.audioStop(piepan.internal.currentAudio.ptr)
end

function piepan.Audio.isPlaying()
    return piepan.internal.currentAudio ~= nil
end
--[=====================================================================[
Copyright (c) 2010 Scott Vokes <vokes.s@gmail.com>

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
]=====================================================================]



-- TODO:
-- * set up basic typechecking for args,
--    "bad argument to string.format" is not a good error msg...

--Dependencies
local socket = require "socket"
local fmt, concat = string.format, table.concat
local assert, ipairs, print, setmetatable, tostring, type =
   assert, ipairs, print, setmetatable, tostring, type


---A Lua client libary for mpd.
-- module("mpd")

---If set to true, will trace out transmissions.
DEBUG = false

local function bool(t) return t and "1" or "0" end


local MPD = {}




function piepan.MPD.sleep(sec)
    socket.select(nil, nil, sec)
end

---Get an MPD server connection handle.
-- @param reconnect Whether to automatically reconnect. Default is true.
-- @param host Default: "localhost"
-- @param port Default: 6600
function piepan.MPD.mpd_connect(host, port, reconnect)
   if reconnect == nil then reconnect = true end
   local host, port = host or "localhost", port or 6600
   local s = assert(socket.connect(host, port))
   local m = setmetatable({_s=s, _reconnect=reconnect,
                           _host=host, _port=port },
                          {__index=piepan.MPD})
   local ok, err = m:connect()
   if ok then return m else return false, err end
end

---Connect (or reconnect) to the server.
function piepan.MPD:connect()
   local s, err = socket.connect(self._host, self._port)
   if s then
      self._s = s
      return true
   else
      return false, err
   end
end

---Send an arbitrary string.
function piepan.MPD:send(cmd)
   local s = assert(self._s)
   if type(cmd) == "string" then cmd = { cmd } end
   local msg = concat(cmd, " ") .. "\r\n"
   if DEBUG then print("SEND: ", msg) end
   local ok, err = s:send(msg)
   if ok then return ok
   elseif err == "closed" and self._reconnect then
      ok, err = self:connect()
      if ok then
         return self:send(cmd) --retry
      else
         return false, err
      end
   else
      return false, err
   end
end

-- Process a response, either a list, k/v table,
-- or list of tables (e.g. list of info for matching songs).
local function parse_buf(rform, buf)
   if rform == "table" or rform == "list" then
      local t = {}
      for _,line in ipairs(buf) do
         local k, v = line:match("(.-): (.*)")
         if k and v then
            if rform == "table" then t[k] = v else t[#t+1] = v end
         end
      end
      res = t
   elseif rform == "table-list" then
      local ts, t = {}, {}
      for _,line in ipairs(buf) do
         local k, v = line:match("(.-): (.*)")
         if k and v then
            if t[k] then ts[#ts+1] = t; t = {} end
            t[k] = v
         end
      end
      ts[#ts+1] = t
      res = ts
   elseif rform == "line" then
      res = concat(buf, "\n")
   else
      return false, ("match failed: " .. rform)
   end
   return res
end

---Read and process a response.
function piepan.MPD:receive(rform)
   rform = rform or "line"
   local s = assert(self._s)
   local buf = {}

   while true do
      local line, err = s:receive()
      if not line then return false, err end
      if DEBUG then print("GOT: ", line) end
      if line == "OK" then break
      elseif line:match("^ACK") then return false, line end
      buf[#buf+1] = line
   end

   return parse_buf(rform, buf)
end

--Send command, get response.
function piepan.MPD:sendrecv(cmd, response_form)
   local res, err = self:send(cmd)
   if not res then return false, err end
   res, err = self:receive(response_form)
   if res then
      return res
   elseif err == "closed" and self._reconnect then
      local ok, err2 = self:connect()
      if ok then
         return self:sendrecv(cmd, response_form) --retry
      else
         return false, err2
      end
   else
      return false, err
   end
end

---Clear last error.
function piepan.MPD:clearerror() return self:sendrecv("clearerror") end

---Get current song (if any).
function piepan.MPD:currentsong()
   return self:sendrecv("currentsong", "table")
end

---Wait for changes in one or more subsystem(s).
-- Blocking, so polling is not necessary.
-- @param subsystems subsystems can be one or more of:
--     "database", "update", "stored_playlist",
--     "playlist", "player", "mixer", "output_options"
function piepan.MPD:idle(subsystems)
   if type(subsystems) == "string" then subsystems = { subsystems } end
   return self:sendrecv(fmt("idle %s", concat(subsystems, " ")))
end


---Cancel blocking idle command.
function piepan.MPD:noidle()
   return self:sendrecv("noidle")
end

---Get table with status.
function piepan.MPD:status() return self:sendrecv("status", "table") end

---Get table with stats.
function piepan.MPD:stats() return self:sendrecv("stats", "table") end

---Set consume state.
-- When consume is activated, each song played is removed from playlist.
function piepan.MPD:set_consume(state)
   return self:sendrecv("consume " .. bool(state))
end

---Sets crossfading between songs (in seconds).
function piepan.MPD:set_crossfade(seconds)
   seconds = tostring(seconds or 0)
   return self:sendrecv("crossfade " .. seconds)
end

---Sets random state to true/false.
function piepan.MPD:set_random(state)
   return self:sendrecv("random " .. bool(state))
end

--Sets repeat state to true/false.
function piepan.MPD:set_repeat(state)
   return self:sendrecv("repeat " .. bool(state))
end

---Sets volume to VOL, the range of volume is 0-100.
function piepan.MPD:set_vol(vol)
   return self:sendrecv(fmt("setvol %d", vol))
end

---Sets single state to true/false.
-- When single is activated, playback is stopped after current song, or
-- the single song is repeated if the 'repeat' mode is enabled.
function piepan.MPD:set_single(state)
   return self:sendrecv("single " .. bool(state))
end

---Sets the replay gain mode. One of "off", "track", "album".
-- Changing the mode during playback may take several seconds, because
-- the new setting does not affect the buffered data. This command
-- triggers the options idle event.
function piepan.MPD:set_replay_gain_mode(mode)
   assert(mode == "off" or mode == "track" or mode == "album",
          "bad replay_gain_mode: " .. tostring(mode))
   return self:sendrecv("replay_gain_mode " .. mode)
end


---Get replay gain options.
-- Currently, only the variable replay_gain_mode is returned.
function piepan.MPD:replay_gain_status()
   return self:sendrecv("replay_gain_status", "table")
end

---Plays next song in the playlist.
function piepan.MPD:next() return self:sendrecv("next") end

---Set pause to true/false.
-- @param flag Defaults to true.
function piepan.MPD:pause(flag)
   if flag == nil then flag = true end
   return self:sendrecv("pause " .. bool(flag))
end

---Unpause.
function piepan.MPD:unpause() return self:pause(false) end

---Begins playing the playlist at song number SONGPOS.
function piepan.MPD:play(songpos)
   songpos = songpos or 0
   return self:sendrecv(fmt("play %d", songpos))
end


---Begins playing the playlist at song SONGID.
-- @param songid Song ID, which is preserved as playlist is rearranged.
function piepan.MPD:playid(songid)
   songid = songid or 0
   return self:sendrecv(fmt("playid %d", songid))
end

---Plays previous song in the playlist.
function piepan.MPD:previous() return self:sendrecv("previous") end

---Seeks to the position TIME (in seconds) of entry SONGPOS in the playlist.
function piepan.MPD:seek(songpos, time)
   return self:sendrecv(fmt("seek %d %d", songpos, time))
end

---Seeks to the position TIME (in seconds) of song SONGID.
-- @param songid Song ID, which is preserved as playlist is rearranged.
function piepan.MPD:seekid(songid, time)
   return self:sendrecv(fmt("seekid %d %d", songid, time))
end

---Stop playing.
function piepan.MPD:stop() return self:sendrecv("stop") end

---Adds the file URI to the playlist and increments playlist version.
-- URI can also be a single file or a directory (added recursively).
function piepan.MPD:add(uri)
   return self:sendrecv(fmt("add %s", uri))
end

---Adds a song to the playlist (non-recursive) and returns the song id.
--URI is always a single file or URL. For example:
--addid "foo.mp3"
--Id: 999
--OK
function piepan.MPD:addid(uri, position)
   return self:sendrecv(fmt("addid %q %s", uri, (position or "")))
end

---Clears the current playlist.
function piepan.MPD:clear() return self:sendrecv("clear") end

---Deletes a song from the playlist.
-- @param arg Optional POS (relative to current) or START:END.
function piepan.MPD:delete(spec)
   spec = spec or 0
   return self:sendrecv(fmt("deleteid %d", spec))
end

---Deletes the song SONGID from the playlist
function piepan.MPD:deleteid(songid)
   return self:sendrecv(fmt("deleteid %d", songid))
end

---Moves the song at FROM or song range at START:END to TO in the playlist.
-- @param pos Either a position in the playlist (counting from 0)
--      or a colon-separated range of positions (e.g. "10:15").
-- @param to Position in playlist.
function piepan.MPD:move(pos, to)
   return self:sendrecv(fmt("moveid %s %d", pos, to))
end

---Moves the song with FROM (songid) to TO (playlist index) in
-- the playlist. If TO is negative, it is relative to the current
-- song in the playlist (if there is one).
function piepan.MPD:moveid(id, to)
   return self:sendrecv(fmt("moveid %s %d", id, to))
end

---Finds songs in the current playlist with strict matching.
-- @param tag One of the tags known, as returned by MPD:tagtypes().
function piepan.MPD:playlistfind(tag, value)
   return self:sendrecv(fmt("playlistfind %s %s", tag, value))
end

---Displays a list of songs in the playlist.
-- @param songid Optional, specifies a single song to display info for.
function piepan.MPD:playlistid(songid)
   songid = songid or ""
   return self:sendrecv(fmt("playlistid %s", songid), "table-list")
end

---Displays a list of all songs in the playlist, or if the optional
-- argument is given, displays information only for the song SONGPOS or
-- the range of songs START:END
function piepan.MPD:playlistinfo(spec)
   spec = spec or ""
   return self:sendrecv(fmt("playlistinfo %s", spec), "table-list")
end

---Searches case-sensitively for partial matches in the current playlist.
-- @param tag One of the tags known, as returned by MPD:tagtypes().
function piepan.MPD:playlistsearch(tag, value)
   return self:sendrecv(fmt("playlistsearch %s %s", tag, value))
end

---Displays changed songs currently in the playlist since VERSION.
-- To detect songs that were deleted at the end of the playlist, use
-- playlistlength returned by status command.
function piepan.MPD:plchanges(version)
   return self:sendrecv(fmt("plchanges %d", version))
end

---Displays changed songs currently in the playlist since VERSION. This
-- function only returns the position and the id of the changed song,
-- not the complete metadata. This is more bandwidth efficient. To
-- detect songs that were deleted at the end of the playlist, use
-- playlistlength returned by status command.
function piepan.MPD:plchangesposid(version)
   return self:sendrecv(fmt("plchangesposid %d" .. version))
end

---Shuffles the current playlist.
-- @param spec Optional, specifies a range of songs.
function piepan.MPD:shuffle(spec)
   spec = spec or ""
   return self:sendrecv(fmt("shuffle %s", spec))
end

---Swaps the positions of SONG1 and SONG2.
-- @param song1 Index of song in playlist, indexed from 0.
function piepan.MPD:swap(song1, song2)
   return self:sendrecv(fmt("swap %d %d", song1, song2))
end

---Swaps the positions of SONG1 and SONG2 (both song ids).
function piepan.MPD:swapid(song1, song2)
   return self:sendrecv(fmt("swapid %d %d", song1, song2))
end

---Lists the files in the playlist NAME.m3u.
function piepan.MPD:listplaylist(name)
   return self:sendrecv("listplaylist " .. name)
end

---Lists songs in the playlist NAME.m3u.
function piepan.MPD:listplaylistinfo(name)
   return self:sendrecv(fmt("listplaylistinfo %s", name))
end

---Prints a list of the playlist directory.
-- After each playlist name the server sends its last modification time
-- as attribute "Last-Modified" in ISO 8601 format. To avoid problems
-- due to clock differences between clients and the server, clients
-- should not compare this value with their local clock.
function piepan.MPD:listplaylists()
   return self:sendrecv("listplaylists")
end

---Loads the playlist NAME.m3u from the playlist directory.
function piepan.MPD:load(name)
   return self:sendrecv(fmt("load %s", name))
end

---Adds URI to the playlist NAME.m3u.
-- NAME.m3u will be created if it does not exist.
function piepan.MPD:playlistadd(name, uri)
   return self:sendrecv(fmt("playlistadd %q %s", name, uri))
end

---Clears the playlist NAME.m3u.
function piepan.MPD:playlistclear(name)
   return self:sendrecv(fmt("playlistclear %s", name))
end

---Deletes SONGPOS from the playlist NAME.m3u.
function piepan.MPD:playlistdelete(name, songpos)
   return self:sendrecv(fmt("playlistdelete %q %d", name, songpos))
end

--playlistmove {NAME} {SONGID} {SONGPOS}
--Moves SONGID in the playlist NAME.m3u to the position SONGPOS.
function piepan.MPD:playlistmove(name, songid, songpos)
   return self:sendrecv(fmt("playlistmove %q %d %d",
                            name, songid, songpos))
end

---Renames the playlist NAME.m3u to NEW_NAME.m3u.
function piepan.MPD:rename(name, new_name)
   return self:sendrecv(fmt("rename %q %s", name, new_name))
end

---Removes the playlist NAME.m3u from the playlist directory.
function piepan.MPD:rm(name)
   return self:sendrecv(fmt("rm %s", name))
end

---Saves the current playlist to NAME.m3u in the playlist directory.
function piepan.MPD:save(name)
   return self:sendrecv(fmt("save %s", name))
end

---Counts the number of songs and their total playtime in the db matching
-- TAG exactly.
-- @param tag One of the tags known, as returned by MPD:tagtypes().
function piepan.MPD:count(tag, value)
   return self:sendrecv(fmt("count %s %s", tag, value))
end

---Finds songs in the db that are exactly WHAT.
-- @param type "album", "artist", or "title"
-- @param what What to find
function piepan.MPD:find(type, what)
   return self:sendrecv(fmt("find %s %s", type, what), "table-list")
end

---Finds songs in the db that are exactly WHAT and adds them to current
-- playlist. TYPE can be any tag supported by MPD. WHAT is what to find.
function piepan.MPD:findadd(type, what)
-- @param type "album", "artist", or "title"
-- @param what What to find
   return self:sendrecv(fmt("findadd %s %s", type, what))
end

---Lists all tags of the specified type. TYPE should be album or artist.
-- @param type "album" or "artist"
-- @param artist Optionl. If type is "album", just search for albums
--     by a specific artist (e.g. mpd:list("album", "The Mountain Goats")).
function piepan.MPD:list(type, artist)
   if type == "album" then
      artist = fmt("%s", artist or "")
   else
      artist = ""
   end
   return self:sendrecv(fmt("list %s%s", type, artist), "list")
end

---Lists all songs and directories in URI.
function piepan.MPD:listall(uri)
   uri = uri or "/"
   return self:sendrecv(fmt("listall %s", uri), "list")
end

---Same as listall, except it also returns metadata info in the same
-- format as lsinfo.
function piepan.MPD:listallinfo(uri)
   uri = uri or "/"
   return self:sendrecv(fmt("listallinfo %s", uri), "table-list")
end

---Lists the contents of the directory URI.
-- When listing the root directory, this currently returns the list of
-- stored playlists. This behavior is deprecated; use "listplaylists"
-- instead.
function piepan.MPD:lsinfo(uri)
   uri = uri or "/"
   return self:sendrecv(fmt("lsinfo %s", uri), "table-list")
end

---Searches for any song that contains WHAT. TYPE can be title, artist,
-- album or filename. Search is not case sensitive.
function piepan.MPD:search(type, what)
   return self:sendrecv(fmt("search %q %s", type, what), "table-list")
end

---Updates the music database: find new files, remove deleted files,
-- update modified files. URI is a particular directory or song/file to
-- update. If you do not specify it, everything is updated. Prints
-- "updating_db: JOBID" where JOBID is a positive number identifying the
-- update job. You can read the current job id in the status response.
function piepan.MPD:update(uri)
   uri = uri or ""
   return self:sendrecv(fmt("update %s", uri))
end

---Same as update, but also rescans unmodified files.
function piepan.MPD:rescan(uri)
   uri = uri or ""
   return self:sendrecv(fmt("rescan %s", uri))
end



---Reads a sticker value for the specified object.
function piepan.MPD:sticker_get(type, uri, name)
   return self:sendrecv(fmt("sticker get %s %s %s",
                            type, uri, name))
end

---Adds a sticker value to the specified object. If a sticker item with
-- that name already exists, it is replaced.
function piepan.MPD:sticker_set(type, uri, name, value)
   return self:sendrecv(fmt("sticker set %s %s %s %s",
                            type, uri, name, value))
end

---Deletes a sticker value from the specified object. If you do not
-- specify a sticker name, all sticker values are deleted.
function piepan.MPD:sticker_delete(type, uri, name)
   name = name or ""
   return self:sendrecv(fmt("sticker delete %s %q %s",
                            type, uri, name))
end

---Lists the stickers for the specified object.
function piepan.MPD:sticker_list(type, uri)
   return self:sendrecv(fmt("sticker list %s %s", type, uri))
end

---Searches the sticker database for stickers with the specified name,
-- below the specified directory (URI). For each matching song, it
-- prints the URI and that one sticker's value.
function piepan.MPD:sticker_find(type, uri, name)
   return self:sendrecv(fmt("sticker find %s %s %s",
                            type, uri, name))
end

---Closes the connection to MPD.
function piepan.MPD:close() return self:sendrecv("close") end

---Kills MPD.
function piepan.MPD:kill() return self:sendrecv("kill") end

---This is used for authentication with the server.
-- @param password the plaintext password.
function piepan.MPD:password(password)
   return self:sendrecv("password " .. password)
end

---Does nothing but return "OK".
function piepan.MPD:ping() return self:sendrecv("ping") end

---Turns an output off.
function piepan.MPD:disableoutput(arg) return self:sendrecv("disableoutput") end

---Turns an output on.
function piepan.MPD:enableoutput(arg) return self:sendrecv("enableoutput") end

---Shows information about all outputs.
function piepan.MPD:outputs() return self:sendrecv("outputs", "table") end

---Shows which commands the current user has access to.
function piepan.MPD:commands() return self:sendrecv("commands", "list") end

---Shows which commands the current user does not have access to.
function piepan.MPD:notcommands() return self:sendrecv("notcommands", "list") end

---Shows a list of available song metadata.
function piepan.MPD:tagtypes() return self:sendrecv("tagtypes", "list") end

---Gets a list of available URL handlers.
function piepan.MPD:urlhandlers() return self:sendrecv("urlhandlers", "list") end
--
-- piepie - bot framework for Mumble
--
-- Author: Tim Cooper <tim.cooper@layeh.com>
-- License: MIT (see LICENSE)
--

function piepan.disconnect()
    piepan.internal.api.disconnect()
end
