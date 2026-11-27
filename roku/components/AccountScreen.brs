sub init()
    m.top.deviceIdentity = invalid
    m.top.entitlement = invalid
    m.top.onRefresh = false
    m.top.onBack = false
    m.macValue = m.top.findNode("macValue")
    m.keyValue = m.top.findNode("keyValue")
    m.planValue = m.top.findNode("planValue")
    m.statusValue = m.top.findNode("statusValue")
    m.expiryValue = m.top.findNode("expiryValue")
    m.playlistCountValue = m.top.findNode("playlistCountValue")
end sub

sub setAccountInfo(identity as object, entitlement as object)
    m.top.deviceIdentity = identity
    m.top.entitlement = entitlement
    m.macValue.text = valueOr(identity.mac, "")
    m.keyValue.text = valueOr(identity.key6, "")
    m.planValue.text = valueOr(entitlement.plan, "TRIAL")
    m.statusValue.text = valueOr(entitlement.status, "trial")
    m.expiryValue.text = formatExpirationDate(valueOr(entitlement.expiresAt, ""))
    m.playlistCountValue.text = valueOr(entitlement.playlistCount, 0).toStr() + " / 5"
end sub

sub onKeyDown(key as Integer)
    if key = 283
        m.top.onBack = true
    end if
end sub
