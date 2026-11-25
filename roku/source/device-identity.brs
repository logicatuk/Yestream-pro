' device-identity.brs - Deterministic MAC and device identity generation for Roku

' Get deterministic device identity based on hardware
function getDeviceId() as string
    info = CreateObject("roDeviceInfo")
    channelClientId = info.GetChannelClientId()
    if channelClientId = invalid or channelClientId = ""
        channelClientId = info.GetModel() + "_" + info.GetVersion()
    end if

    ba = CreateObject("roByteArray")
    ba.FromAsciiString(channelClientId)
    digest = CreateObject("roEVPDigest")
    digest.Setup("sha256")
    hash = digest.Process(ba)
    return Left(hash, 24)
end function

' Generate deterministic MAC address (formatted as 02:XX:XX:XX:XX:XX)
function getMacAddress() as string
    deviceId = getDeviceId()
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(deviceId)
    digest = CreateObject("roEVPDigest")
    digest.Setup("sha256")
    hash = digest.Process(ba)
    
    ' Format as 02:XX:XX:XX:XX:XX
    mac = "02:" + Mid(hash, 3, 2) + ":" + Mid(hash, 5, 2) + ":" + Mid(hash, 7, 2) + ":" + Mid(hash, 9, 2) + ":" + Mid(hash, 11, 2)
    return UCase(mac)
end function

' Generate 6-digit device key
function getDeviceKey() as string
    mac = getMacAddress()
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(mac)
    digest = CreateObject("roEVPDigest")
    digest.Setup("sha256")
    hash = digest.Process(ba)
    
    ' Extract 6 numeric/hex characters
    key = Mid(hash, 1, 6)
    return UCase(key)
end function

' Load stored identity from registry
function loadStoredIdentity() as object
    sec = CreateObject("roRegistrySection", "yestream")
    stored = {
        mac: "",
        key6: "",
        credential: "",
        entitlement: invalid
    }

    if sec.Exists("mac_address")
        stored.mac = sec.Read("mac_address")
    else
        stored.mac = getMacAddress()
        sec.Write("mac_address", stored.mac)
        sec.Flush()
    end if

    if sec.Exists("key6")
        stored.key6 = sec.Read("key6")
    else
        stored.key6 = getDeviceKey()
        sec.Write("key6", stored.key6)
        sec.Flush()
    end if

    if sec.Exists("credential")
        stored.credential = sec.Read("credential")
    end if

    return stored
end function

' Save identity to registry
sub saveStoredIdentity(stored as object)
    if stored = invalid then return
    sec = CreateObject("roRegistrySection", "yestream")

    if stored.mac <> invalid and stored.mac <> ""
        sec.Write("mac_address", stored.mac)
    end if

    if stored.key6 <> invalid and stored.key6 <> ""
        sec.Write("key6", stored.key6)
    end if

    if stored.credential <> invalid and stored.credential <> ""
        sec.Write("credential", stored.credential)
    end if

    sec.Flush()
end sub

' Check if device is registered
function isRegistered() as boolean
    sec = CreateObject("roRegistrySection", "yestream")
    return sec.Exists("credential") and sec.Read("credential") <> ""
end function
