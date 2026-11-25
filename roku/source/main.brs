' main.brs - Yestream Roku Channel entry point
' Handles channel initialization, screen routing, and lifecycle

sub Main()
    print "Yestream Channel starting..."

    ' Initialize device identity
    deviceIdentity = createObject("roSGNode", "DeviceIdentity")

    ' Show launch screen first
    screen = createObject("roSGNode", "Screen")
    screen.show()

    ' Initialize channel state
    deviceIdentity.loadStoredIdentity()

    ' Route based on entitlement state
    routeChannel(screen, deviceIdentity)
end sub

sub routeChannel(screen as Object, deviceIdentity as Object)
    ' Check if device is registered
    registered = deviceIdentity.isRegistered()

    if not registered
        ' Register device on first launch
        deviceIdentity.registerDevice()
    end if

    ' Check entitlement status
    entitlement = deviceIdentity.getEntitlement()

    if entitlement = "expired" or entitlement = "suspended"
        ' Show lock screen
        showLockScreen(screen, deviceIdentity)
    else
        ' Show home screen
        showHomeScreen(screen, deviceIdentity)
    end if
end sub

sub showHomeScreen(screen as Object, deviceIdentity as Object)
    print "Showing home screen"
    ' Will load YestreamScene component
end sub

sub showLockScreen(screen as Object, deviceIdentity as Object)
    print "Showing lock screen"
    ' Will load ExpiryLockScreen component
end sub