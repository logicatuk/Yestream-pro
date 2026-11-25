' playlists.brs - M3U/Xtream playlist parsing and local caching

' Parse an M3U playlist from text
function parseM3uPlaylist(m3uText as string) as object
    lines = m3uText.split(chr(10))
    playlist = {
        name: "M3U Playlist",
        type: "m3u",
        channels: []
    }

    currentChannel = invalid

    for each line in lines
        line = line.trim()
        if line = "" or Left(line, 7) = "#EXTM3U"
            ' Skip
        else if Left(line, 7) = "#EXTINF"
            currentChannel = parseExtinf(line)
        else if Left(line, 1) <> "#" and line <> ""
            if currentChannel <> invalid
                currentChannel.url = line
                if currentChannel.name <> "" and currentChannel.url <> ""
                    playlist.channels.push(currentChannel)
                end if
                currentChannel = invalid
            end if
        end if
    end for

    return playlist
end function

function parseExtinf(line as string) as object
    channel = {
        name: "",
        group: "General",
        logo: "",
        url: ""
    }

    commaPos = InStr(1, line, ",")
    if commaPos > 0
        channel.name = Mid(line, commaPos + 1).trim()
        attrs = Left(line, commaPos - 1)
        channel.group = extractAttribute(attrs, "group-title")
        if channel.group = "" then channel.group = "General"
        channel.logo = extractAttribute(attrs, "tvg-logo")
    end if

    return channel
end function

function extractAttribute(attrString as string, attrName as string) as string
    search = attrName + "="""
    pos = InStr(1, attrString, search)
    if pos > 0
        startPos = pos + Len(search)
        endPos = InStr(startPos, attrString, """")
        if endPos > startPos
            return Mid(attrString, startPos, endPos - startPos)
        end if
    end if
    return ""
end function

' Fetch Xtream live categories & channels
function fetchXtreamChannels(serverUrl as string, username as string, password as string) as object
    url = serverUrl + "/player_api.php?username=" + username + "&password=" + password + "&action=get_live_streams"
    transfer = CreateObject("roUrlTransfer")
    transfer.SetUrl(url)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.EnableEncodings(true)
    transfer.SetTimeout(30000)

    response = transfer.GetToString()
    code = transfer.GetResponseCode()

    channels = []
    if code = 200
        parsed = ParseJson(response)
        if parsed <> invalid and Type(parsed) = "roArray"
            for each item in parsed
                channel = {
                    name: item.name,
                    group: item.category_name,
                    logo: item.stream_icon,
                    streamId: item.stream_id,
                    url: serverUrl + "/live/" + username + "/" + password + "/" + item.stream_id.toStr() + ".m3u8"
                }
                channels.push(channel)
            end for
        end if
    end if

    return channels
end function

' Save active playlists to Roku registry
sub savePlaylistsToRegistry(playlists as object)
    if playlists = invalid then return
    sec = CreateObject("roRegistrySection", "yestream_playlists")
    jsonStr = FormatJson(playlists)
    sec.Write("cloud_playlists", jsonStr)
    sec.Flush()
end sub

' Load active playlists from Roku registry
function loadPlaylistsFromRegistry() as object
    sec = CreateObject("roRegistrySection", "yestream_playlists")
    if sec.Exists("cloud_playlists")
        str = sec.Read("cloud_playlists")
        parsed = ParseJson(str)
        if parsed <> invalid then return parsed
    end if
    return []
end function
