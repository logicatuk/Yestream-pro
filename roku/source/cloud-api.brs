' cloud-api.brs - HTTP client for Yestream backend

function makeTransfer(url as string, contentType as string) as object
    transfer = CreateObject("roUrlTransfer")
    transfer.SetUrl(url)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.EnableEncodings(true)
    transfer.SetTimeout(30000)
    transfer.AddHeader("Content-Type", contentType)
    return transfer
end function

' Register device with backend
function registerDevice(payload as object) as object
    cfg = getYestreamConfig()
    transfer = makeTransfer(cfg.registerEndpoint, "application/json")
    
    body = FormatJson(payload)
    response = transfer.PostFromString(body)
    code = transfer.GetResponseCode()

    result = { ok: false, code: code, data: invalid, error: "" }
    if code >= 200 and code < 300
        parsed = ParseJson(response)
        if parsed <> invalid
            result.ok = true
            result.data = parsed
        else
            result.error = "Failed to parse JSON response"
        end if
    else
        result.error = "HTTP error: " + code.toStr()
    end if
    return result
end function

' Sync playlists from cloud
function syncPlaylists(credential as string) as object
    cfg = getYestreamConfig()
    transfer = makeTransfer(cfg.syncEndpoint, "application/json")
    if credential <> ""
        transfer.AddHeader("Authorization", "Bearer " + credential)
    end if

    response = transfer.GetToString()
    code = transfer.GetResponseCode()

    result = { ok: false, code: code, data: invalid, error: "" }
    if code >= 200 and code < 300
        parsed = ParseJson(response)
        if parsed <> invalid
            result.ok = true
            result.data = parsed
        else
            result.error = "Failed to parse JSON response"
        end if
    else
        result.error = "HTTP error: " + code.toStr()
    end if
    return result
end function

' Get entitlement status
function getEntitlement(credential as string) as object
    cfg = getYestreamConfig()
    transfer = makeTransfer(cfg.entitlementEndpoint, "application/json")
    if credential <> ""
        transfer.AddHeader("Authorization", "Bearer " + credential)
    end if

    response = transfer.GetToString()
    code = transfer.GetResponseCode()

    result = { ok: false, code: code, data: invalid, error: "" }
    if code >= 200 and code < 300
        parsed = ParseJson(response)
        if parsed <> invalid
            result.ok = true
            result.data = parsed
        else
            result.error = "Failed to parse JSON response"
        end if
    else
        result.error = "HTTP error: " + code.toStr()
    end if
    return result
end function
