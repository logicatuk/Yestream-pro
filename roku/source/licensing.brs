' licensing.brs - Expiry guard state machine for Roku

'/ Check if playback is allowed based on entitlement
function canPlay(entitlement as object, serverTime as string) as boolean
    access = evaluateDeviceAccess(entitlement, serverTime)
    return access.allowed
end function

'/ Check if trial is still active
function isTrialActive(entitlement as object, serverTime as string) as boolean
    access = evaluateDeviceAccess(entitlement, serverTime)
    return access.state = "trial" and access.allowed
end function

'/ Get remaining trial days
function getTrialDaysRemaining(entitlement as object, serverTime as string) as integer
    access = evaluateDeviceAccess(entitlement, serverTime)
    if access.state = "trial"
        return access.remainingDays
    end if
    return 0
end function

'/ Check if license is expired
function isLicenseExpired(entitlement as object, serverTime as string) as boolean
    access = evaluateDeviceAccess(entitlement, serverTime)
    return not access.allowed and access.state = "expired"
end function

'/ Check if device is suspended
function isSuspended(entitlement as object, serverTime as string) as boolean
    access = evaluateDeviceAccess(entitlement, serverTime)
    return access.state = "suspended"
end function

'/ Check if device is decommissioned
function isDecommissioned(entitlement as object, serverTime as string) as boolean
    access = evaluateDeviceAccess(entitlement, serverTime)
    return access.state = "decommissioned"
end function

'/ Determine the access state for display
function getAccessStateLabel(entitlement as object, serverTime as string) as string
    access = evaluateDeviceAccess(entitlement, serverTime)

    select case access.state
        case "trial"
            return "Trial - " + access.remainingDays.toStr() + " days remaining"
        case "active"
            return "Active"
        case "lifetime"
            return "Lifetime"
        case "expired"
            return "Expired"
        case "suspended"
            return "Suspended"
        case "decommissioned"
            return "Decommissioned"
        case else
            return "Unknown"
    end select
end function

'/ Format expiration date for display
function formatExpirationDate(expiresAt as string) as string
    if expiresAt = ""
        return "Never"
    end if

    ' Parse ISO date and format as human-readable
    dt = createObject("roDateTime")
    dt.fromISO8601String(expiresAt)

    if dt.isValid()
        ' Format as "Nov 28, 2026"
        monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        month = monthNames[dt.getMonth() - 1]
        day = dt.getDayOfMonth().toStr()
        year = dt.getYear().toStr()
        return month + " " + day + ", " + year
    end if

    return expiresAt
end function