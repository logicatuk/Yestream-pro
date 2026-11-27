sub init()
    m.macDisplay = m.top.findNode("macDisplay")
    m.keyDisplay = m.top.findNode("keyDisplay")
    m.noticeText = m.top.findNode("noticeText")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if LCase(key) = "ok"
        m.noticeText.text = "Checking activation with Yestream Cloud..."
        m.top.selectedAction = "refresh"
        return true
    end if
    return key <> "back"
end function
