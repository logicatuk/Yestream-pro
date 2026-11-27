sub init()
    m.topNav = m.top.findNode("topNav")
    m.homeScreen = m.top.findNode("homeScreen")
    m.liveTvScreen = m.top.findNode("liveTvScreen")
    m.movieScreen = m.top.findNode("movieScreen")
    m.seriesScreen = m.top.findNode("seriesScreen")
    m.epgScreen = m.top.findNode("epgScreen")
    m.playlistsScreen = m.top.findNode("playlistsScreen")
    m.settingsScreen = m.top.findNode("settingsScreen")
    m.expiryLockScreen = m.top.findNode("expiryLockScreen")

    m.topNav.observeField("activeTabIndex", "onTabChanged")
    m.homeScreen.observeField("selectedAction", "onHomeAction")
    m.expiryLockScreen.observeField("selectedAction", "onExpiryAction")

    ' Observe back events from sub-screens
    m.epgScreen.observeField("onBack", "onSubScreenBack")
    m.settingsScreen.observeField("onBack", "onSubScreenBack")

    m.registration = CreateObject("roSGNode", "DeviceCloudTask")
    m.registration.operation = "register"
    m.registration.observeField("result", "onRegistration")
    initializeDevice()
end sub

sub initializeDevice()
    m.topNav.visible = false
    m.top.findNode("screensContainer").visible = false
    m.expiryLockScreen.visible = true
    m.expiryLockScreen.setFocus(true)
    identity = loadStoredIdentity()
    m.top.deviceId = getDeviceId()
    m.top.macAddress = identity.mac
    m.top.deviceKey = identity.key6
    m.expiryLockScreen.macAddress = identity.mac
    m.expiryLockScreen.deviceKey = identity.key6

    ' Set device info on HomeScreen
    m.homeScreen.macAddress = identity.mac
    m.homeScreen.planText = "● ACTIVE • TRIAL • Yestream Cloud"
    m.homeScreen.callFunc("updateDeviceInfo")

    ' Register device with backend
    payload = {
        mac: identity.mac,
        hardwareFingerprint: m.top.deviceId,
        platform: "Roku",
        model: CreateObject("roDeviceInfo").GetModel(),
        appVersion: "0.1.0"
    }

    if identity.credential <> "" then payload.credential = identity.credential
    m.registration.payload = payload
    m.registration.control = "run"
end sub

sub onRegistration()
    identity = loadStoredIdentity()
    regRes = m.registration.result
    if regRes.ok and regRes.data <> invalid
        if regRes.data.credential <> invalid
            if regRes.data.key6 <> invalid then identity.key6 = regRes.data.key6
            m.expiryLockScreen.deviceKey = identity.key6
            identity.credential = regRes.data.credential
            saveStoredIdentity(identity)
        end if

        ' Check if subscription is expired
        status = regRes.data.status
        plan = regRes.data.plan
        if status <> "active" and status <> "trial"
            m.expiryLockScreen.visible = true
            m.expiryLockScreen.setFocus(true)
        else
            m.expiryLockScreen.visible = false
            m.topNav.visible = true
            m.top.findNode("screensContainer").visible = true
            if plan = invalid then plan = ""
            m.homeScreen.planText = UCase(status) + "  " + UCase(plan)
            m.homeScreen.callFunc("updateDeviceInfo")
            m.homeScreen.setFocus(true)
        end if
    end if
end sub

sub onTabChanged()
    for each browser in [m.movieScreen, m.seriesScreen, m.liveTvScreen]
        if browser.visible then browser.callFunc("leavePage")
    end for
    idx = m.topNav.activeTabIndex
    m.homeScreen.visible = (idx = 0)
    m.liveTvScreen.visible = (idx = 1)
    m.movieScreen.visible = (idx = 2)
    m.seriesScreen.visible = (idx = 3)
    m.epgScreen.visible = (idx = 4)
    m.playlistsScreen.visible = (idx = 5)
    m.settingsScreen.visible = (idx = 6)

    if idx = 0
        m.homeScreen.setFocus(true)
    else if idx = 1
        m.liveTvScreen.callFunc("openPage")
    else if idx = 2
        m.movieScreen.callFunc("openPage")
    else if idx = 3
        m.seriesScreen.callFunc("openPage")
    else if idx = 4
        m.epgScreen.setFocus(true)
    else if idx = 5
        m.playlistsScreen.callFunc("openPage")
    else if idx = 6
        m.settingsScreen.setFocus(true)
    end if
end sub

sub onHomeAction()
    action = m.homeScreen.selectedAction
    if action = "liveTV"
        m.topNav.callFunc("setFocusToTab", 1)
        m.topNav.activeTabIndex = 1
    else if action = "movies"
        m.topNav.callFunc("setFocusToTab", 2)
        m.topNav.activeTabIndex = 2
    else if action = "series"
        m.topNav.callFunc("setFocusToTab", 3)
        m.topNav.activeTabIndex = 3
    else if action = "epg"
        m.topNav.callFunc("setFocusToTab", 4)
        m.topNav.activeTabIndex = 4
    else if action = "playlists"
        m.topNav.callFunc("setFocusToTab", 5)
        m.topNav.activeTabIndex = 5
    else if action = "settings"
        m.topNav.callFunc("setFocusToTab", 6)
        m.topNav.activeTabIndex = 6
    else if action = "refresh"
        initializeDevice()
    else if action = "focusNav"
        m.topNav.callFunc("setFocusToTab", 0)
    end if
end sub

sub onSubScreenBack()
    ' Return to Home
    m.topNav.callFunc("setFocusToTab", 0)
    m.topNav.activeTabIndex = 0
end sub

sub onExpiryAction()
    action = m.expiryLockScreen.selectedAction
    if action = "refresh"
        initializeDevice()
    end if
end sub
