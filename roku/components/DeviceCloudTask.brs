sub init()
    m.top.functionName = "requestDevice"
end sub

sub requestDevice()
    payload = m.top.payload
    if m.top.operation = "register"
        result = registerDevice(payload)
    else
        saved = false
        if m.top.operation = "add"
            cfg = getYestreamConfig()
            if payload.credential = ""
                m.top.result = { ok: false, code: 401 }
                return
            end if
            result = deviceRequest(cfg.playlistsEndpoint, payload.credential, payload.playlist)
            if not result.ok
                m.top.result = result
                return
            end if
            saved = true
        end if
        result = syncPlaylists(payload.credential)
        result.saved = saved
        if result.ok
            if type(result.data.playlists) = "roArray"
                savePlaylistsToRegistry(result.data.playlists)
            else
                result.ok = false
            end if
        end if
    end if
    m.top.result = result
end sub
