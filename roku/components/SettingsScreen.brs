sub init()
    m.top.onBack = false
    m.settingsList = m.top.findNode("settingsList")
    settings = []
    settings.push({ title: "Connectivity", desc: "Network settings" })
    settings.push({ title: "Parental Lock", desc: "Content restrictions" })
    settings.push({ title: "About", desc: "Version and support" })
    settings.push({ title: "Logout", desc: "Sign out" })
    m.settingsList.content = buildListContent(settings)
    m.settingsList.observeField("itemSelected", "onSettingSelected")
end sub

sub onSettingSelected()
    idx = m.settingsList.itemSelected
    if idx >= 0
        item = m.settingsList.content.getChild(idx)
        title = item.title
        if title = "About"
            m.top.onBack = true
        end if
    end if
end sub

sub onKeyDown(key as Integer)
    if key = 283
        m.top.onBack = true
    end if
end sub
