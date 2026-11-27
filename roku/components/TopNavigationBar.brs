sub init()
    m.tabButtons = m.top.findNode("tabButtons")
    m.tabButtons.observeField("buttonSelected", "onTabSelected")
    m.tabButtons.observeField("buttonFocused", "onTabFocused")
end sub

sub onTabSelected()
    m.top.activeTabIndex = m.tabButtons.buttonSelected
end sub

sub onTabFocused()
    ' Can update indicator if needed
end sub

sub setFocusToTab(index as Integer)
    if index >= 0 and index < 7
        m.tabButtons.jumpToItem = index
        m.tabButtons.setFocus(true)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "down"
        ' Return focus to current screen below
        m.top.activeTabIndex = m.tabButtons.buttonSelected
        return false
    end if

    return false
end function
