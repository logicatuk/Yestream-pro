sub init()
    m.top.functionName = "loadCatalog"
end sub

function fetchText(url as string) as string
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.SetUrl(url)
    if transfer.AsyncGetToString()
        event = wait(20000, port)
        if type(event) = "roUrlEvent"
            if event.GetResponseCode() = 200 then return event.GetString()
        end if
        transfer.AsyncCancel()
    end if
    return ""
end function

sub loadCatalog()
    req = m.top.request
    source = req.source
    kind = req.kind
    result = { rows: [], description: "", poster: "", error: "" }
    if source.type = "m3u"
        if req.stage = "categories"
            raw = fetchText(source.url)
            if raw = "" then result.error = "Could not load playlist."
            groups = {}
            for each channel in parseM3uPlaylist(raw).channels
                media = "live"
                if instr(1,channel.url,"/movie/") > 0 then media = "movie"
                if instr(1,channel.url,"/series/") > 0 then media = "series"
                if media = kind
                    if not groups.DoesExist(channel.group) then groups[channel.group] = []
                    groups[channel.group].push({title:channel.name, url:channel.url, poster:channel.logo})
                end if
            end for
            for each groupName in groups
                result.rows.push({title:groupName, children:groups[groupName]})
            end for
        end if
    else if source.type = "xtream"
        result = xtreamPage(req, result)
    else
        result.error = "Choose an M3U or Xtream playlist."
    end if
    m.top.result = result
end sub

function xtreamPage(req as object, result as object) as object
    source = req.source
    host = CreateObject("roRegex", "/+$", "").replaceAll(source.host, "")
    user = source.username.EncodeUriComponent()
    password = source.password.EncodeUriComponent()
    api = host + "/player_api.php?username=" + user + "&password=" + password + "&action="
    base = host + "/" + req.kind + "/" + user + "/" + password + "/"
    actions = {live:"get_live_categories",movie:"get_vod_categories",series:"get_series_categories"}
    action = actions[req.kind]
    if req.stage = "items"
        actions = {live:"get_live_streams",movie:"get_vod_streams",series:"get_series"}
        action = actions[req.kind] + "&category_id=" + req.item.id.toStr().EncodeUriComponent()
    else if req.stage = "details"
        if req.kind = "movie"
            action = "get_vod_info&vod_id=" + req.item.id.toStr()
        else
            action = "get_series_info&series_id=" + req.item.id.toStr()
        end if
    end if
    data = ParseJson(fetchText(api + action))
    if req.stage = "details"
        if req.kind = "movie" then result.rows.push({title:"Play movie",url:req.item.url})
        if type(data) <> "roAssociativeArray"
            result.error = "Provider details unavailable."
            return result
        end if
        info = valueOr(data.info,{})
        result.description = valueOr(info.plot,valueOr(info.description,""))
        result.poster = valueOr(info.cover,valueOr(info.movie_image,""))
        if req.kind = "series" and type(data.episodes) = "roAssociativeArray"
            seasons = []
            for each season in data.episodes
                seasons.push(season.toInt())
            end for
            seasons.sort()
            for each number in seasons
                for each ep in data.episodes[number.toStr()]
                    result.rows.push({title:"S" + number.toStr() + " · " + valueOr(ep.title,"Episode"),url:base + ep.id.toStr() + "." + valueOr(ep.container_extension,"mp4")})
                end for
            end for
        end if
    else if type(data) = "roArray"
        for each record in data
            if req.stage = "categories"
                result.rows.push({title:record.category_name,id:record.category_id})
            else
                id = valueOr(record.series_id,record.stream_id)
                item = {title:record.name,id:id,poster:valueOr(record.cover,valueOr(record.stream_icon,""))}
                if req.kind <> "series"
                    ext = valueOr(record.container_extension,"mp4")
                    if req.kind = "live" then ext = "m3u8"
                    item.url = base + id.toStr() + "." + ext
                end if
                result.rows.push(item)
            end if
        end for
    else
        result.error = "Could not load this category. Press Back to try again."
    end if
    return result
end function
