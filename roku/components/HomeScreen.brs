sub init()
    m.playlistLabel = m.top.findNode("playlistLabel")
    m.statusBadgeText = m.top.findNode("statusBadgeText")
    m.macFooter = m.top.findNode("macFooter")

    ' Card nodes
    m.cardGlows = [
        m.top.findNode("card0Glow"),
        m.top.findNode("card1Glow"),
        m.top.findNode("card2Glow"),
        m.top.findNode("card3Glow")
    ]
    m.cardBgs = [
        m.top.findNode("card0Bg"),
        m.top.findNode("card1Bg"),
        m.top.findNode("card2Bg"),
        m.top.findNode("card3Bg")
    ]
    m.cardActions = [
        m.top.findNode("card0Action"),
        m.top.findNode("card1Action"),
        m.top.findNode("card2Action"),
        m.top.findNode("card3Action")
    ]

    ' Button nodes
    m.btnBgs = [
        m.top.findNode("btn0Bg"),
        m.top.findNode("btn1Bg"),
        m.top.findNode("btn2Bg")
    ]
    m.btnTexts = [
        m.top.findNode("btn0Text"),
        m.top.findNode("btn1Text"),
        m.top.findNode("btn2Text")
    ]

    ' Navigation focus state: "cards" or "buttons"
    m.focusSection = "cards"
    m.focusedCard = 0
    m.focusedBtn = 0

    updateFocusVisuals()
end sub

sub updateDeviceInfo()
    if m.top.macAddress <> invalid and m.top.macAddress <> ""
        m.macFooter.text = "MAC ADDRESS : " + m.top.macAddress
    end if

    if m.top.activePlaylistName <> invalid and m.top.activePlaylistName <> ""
        m.playlistLabel.text = "Active Playlist : " + m.top.activePlaylistName
    else
        m.playlistLabel.text = "Active Playlist : None"
    end if

    if m.top.planText <> invalid and m.top.planText <> ""
        m.statusBadgeText.text = m.top.planText
    end if
end sub

sub updateFocusVisuals()
    ' Update 4 Cards
    for i = 0 to 3
        isCardFocused = (m.focusSection = "cards" and m.focusedCard = i)
        m.cardGlows[i].visible = isCardFocused
        if isCardFocused
            m.cardBgs[i].color = "#1E293B"
            m.cardActions[i].visible = true
        else
            m.cardBgs[i].color = "#0F172A"
            m.cardActions[i].visible = false
        end if
    end for

    ' Update 3 Buttons
    for b = 0 to 2
        isBtnFocused = (m.focusSection = "buttons" and m.focusedBtn = b)
        if isBtnFocused
            m.btnBgs[b].color = "#38BDF8"
            m.btnTexts[b].color = "#020617"
        else
            m.btnBgs[b].color = "#1E293B"
            m.btnTexts[b].color = "#FFFFFF"
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    handled = false
    if not press then return handled

    if m.focusSection = "cards"
        if key = "left"
            if m.focusedCard > 0
                m.focusedCard = m.focusedCard - 1
                updateFocusVisuals()
                handled = true
            end if
        else if key = "right"
            if m.focusedCard < 3
                m.focusedCard = m.focusedCard + 1
                updateFocusVisuals()
                handled = true
            end if
        else if key = "down"
            m.focusSection = "buttons"
            if m.focusedCard = 0 or m.focusedCard = 1
                m.focusedBtn = 0
            else if m.focusedCard = 2
                m.focusedBtn = 1
            else
                m.focusedBtn = 2
            end if
            updateFocusVisuals()
            handled = true
        else if key = "up"
            ' Allow parent scene to move focus up to TopNavigationBar
            m.top.selectedAction = "focusNav"
            handled = true
        else if key = "OK"
            if m.focusedCard = 0
                m.top.selectedAction = "liveTV"
            else if m.focusedCard = 1
                m.top.selectedAction = "movies"
            else if m.focusedCard = 2
                m.top.selectedAction = "series"
            else if m.focusedCard = 3
                m.top.selectedAction = "epg"
            end if
            handled = true
        end if

    else if m.focusSection = "buttons"
        if key = "left"
            if m.focusedBtn > 0
                m.focusedBtn = m.focusedBtn - 1
                updateFocusVisuals()
                handled = true
            end if
        else if key = "right"
            if m.focusedBtn < 2
                m.focusedBtn = m.focusedBtn + 1
                updateFocusVisuals()
                handled = true
            end if
        else if key = "up"
            m.focusSection = "cards"
            if m.focusedBtn = 0
                m.focusedCard = 1
            else if m.focusedBtn = 1
                m.focusedCard = 2
            else
                m.focusedCard = 3
            end if
            updateFocusVisuals()
            handled = true
        else if key = "OK"
            if m.focusedBtn = 0
                m.top.selectedAction = "refresh"
            else if m.focusedBtn = 1
                m.top.selectedAction = "playlists"
            else if m.focusedBtn = 2
                m.top.selectedAction = "settings"
            end if
            handled = true
        end if
    end if

    return handled
end function
