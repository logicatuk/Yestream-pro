' access-evaluation.brs - Device access evaluation logic (port of TypeScript version)

'/ Evaluate device access based on entitlement response
' Returns an associative array with: allowed, state, trialDays, remainingDays, expiresAt
function evaluateDeviceAccess(entitlement as object, serverTimeIso as string) as object
    nowMs = dateParse(serverTimeIso)
    if nowMs = invalid or nowMs < 0
        nowMs = dateParse(entitlement.issuedAt)
    end if
    if nowMs = invalid or nowMs < 0
        nowMs = dateNow()
    end if

    status = entitlement.status
    plan = entitlement.plan
    trialDays = 7
    if entitlement.trialDays <> invalid then trialDays = val(entitlement.trialDays.toStr())
    if trialDays = 0
        trialDays = 7
    end if

    ' Check for terminal states
    if status = "decommissioned" or status = "suspended" or status = "expired"
        return {
            allowed: false,
            state: status,
            trialDays: trialDays,
            remainingDays: 0,
            expiresAt: entitlement.expiresAt
        }
    end if

    ' Lifetime/forever plan
    if plan = "FOREVER" and status = "active"
        return {
            allowed: true,
            state: "lifetime",
            trialDays: trialDays,
            remainingDays: 999999,
            expiresAt: ""
        }
    end if

    ' Check expiration
    expiresAt = entitlement.expiresAt
    expMs = dateParse(expiresAt)

    if expMs = invalid or expMs <= nowMs
        return {
            allowed: false,
            state: "expired",
            trialDays: trialDays,
            remainingDays: 0,
            expiresAt: expiresAt
        }
    end if

    ' Calculate remaining days
    remainingMs = expMs - nowMs
    remainingDays = -Int(-remainingMs / 86400000#)
    if remainingDays < 1
        remainingDays = 1
    end if

    state = "trial"
    if status = "active" then state = "active"

    return {
        allowed: true,
        state: state,
        trialDays: trialDays,
        remainingDays: remainingDays,
        expiresAt: expiresAt
    }
end function

function dateNow() as double
    dt = CreateObject("roDateTime")
    return dt.AsSeconds() * 1000#
end function

function dateParse(isoString as dynamic) as double
    if isoString = invalid or isoString = "" then return -1
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(isoString)
    if dt.AsSeconds() <= 0 then return -1
    return dt.AsSeconds() * 1000# + dt.GetMilliseconds()
end function
