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
    trialDays = val(entitlement.trialDays)
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
    remainingDays = ceil(remainingMs / (1000 * 60 * 60 * 24))
    if remainingDays < 1
        remainingDays = 1
    end if

    state = iif(status = "active", "active", "trial")

    return {
        allowed: true,
        state: state,
        trialDays: trialDays,
        remainingDays: remainingDays,
        expiresAt: expiresAt
    }
end function

'/ Get current time in milliseconds (approximate)
function dateNow() as integer
    ' roTimespan.TotalMilliseconds() gives milliseconds since epoch
    ts = createObject("roTimespan")
    return ts.TotalMilliseconds()
end function

'/ Parse ISO 8601 date string to milliseconds
function dateParse(isoString as string) as integer
    if isoString = invalid or isoString = ""
        return invalid
    end if

    ' Parse ISO 8601: "2026-11-21T19:42:00.000Z"
    ' BrightScript has no built-in ISO parser; using roDateTime
    dt = createObject("roDateTime")
    dt.fromISO8601String(isoString)
    if dt.isValid()
        return dt.totalMilliseconds()
    end if
    return invalid
end function