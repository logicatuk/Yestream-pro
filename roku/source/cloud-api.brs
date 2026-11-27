function deviceRequest(url as string, credential as string, payload as dynamic) as object
    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.SetPort(port)
    transfer.SetUrl(url)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.AddHeader("Content-Type", "application/json")
    if credential <> "" then transfer.AddHeader("Authorization", "Bearer " + credential)
    if payload = invalid
        started = transfer.AsyncGetToString()
    else
        started = transfer.AsyncPostFromString(FormatJson(payload))
    end if
    result = { ok: false, code: 0, data: invalid }
    if not started then return result
    event = wait(30000, port)
    if type(event) <> "roUrlEvent"
        transfer.AsyncCancel()
        return result
    end if
    result.code = event.GetResponseCode()
    if result.code >= 200 and result.code < 300
        result.data = ParseJson(event.GetString())
        result.ok = type(result.data) = "roAssociativeArray"
    end if
    return result
end function

function registerDevice(payload as object) as object
    cfg = getYestreamConfig()
    return deviceRequest(cfg.registerEndpoint, "", payload)
end function

function syncPlaylists(credential as string) as object
    cfg = getYestreamConfig()
    if credential = "" then return { ok: false, code: 401, data: invalid }
    return deviceRequest(cfg.syncEndpoint, credential, invalid)
end function
