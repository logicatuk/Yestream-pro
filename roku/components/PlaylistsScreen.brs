sub init()
    m.macDisplay = m.top.findNode("macDisplay")
    m.keyDisplay = m.top.findNode("keyDisplay")
    m.qrImage = m.top.findNode("qrImage")
    m.syncButton = m.top.findNode("syncButton")
    m.syncNotice = m.top.findNode("syncNotice")
    m.emptyState = m.top.findNode("emptyState")
    m.playlistList = m.top.findNode("playlistList")

    m.addButton = m.top.findNode("addButton")
    m.addButton.observeField("buttonSelected", "chooseType")
    m.busy = false
    m.syncButton.observeField("buttonSelected", "onSyncSelected")

    m.sync = CreateObject("roSGNode", "DeviceCloudTask")
    m.sync.operation = "sync"
    m.sync.observeField("result", "onSyncResult")
end sub

sub setupIdentity()
    id = loadStoredIdentity()
    m.top.macAddress = id.mac
    m.top.deviceKey = id.key6
    m.macDisplay.text = id.mac
    m.keyDisplay.text = id.key6

    loginUrl = portalLogin(id.mac, id.key6)
    if m.top.portalUrl <> loginUrl
        m.top.portalUrl = loginUrl
        drawPortalQr(m.qrImage, loginUrl, 5)
    end if
end sub

sub onSyncSelected()
    refreshPlaylists()
end sub

sub refreshPlaylists()
    if m.busy then return
    m.busy = true
    m.sync.operation = "sync"
    m.syncNotice.text = "Syncing with Yestream Cloud..."
    id = loadStoredIdentity()
    m.sync.payload = { credential: id.credential }
    m.sync.control = "run"
end sub

sub onSyncResult()
    m.busy = false
    m.sync.payload = {}
    res = m.sync.result

    if res.ok and res.data <> invalid
        m.syncNotice.text = "✓ Playlists synchronized"
        m.top.playlists = res.data.playlists
        m.playlistList.content = buildListContent(res.data.playlists)
        m.emptyState.visible = res.data.playlists.count() = 0
    else if res.saved = true
        m.syncNotice.text = "Saved. Select Sync to refresh the list."
    else if res.code = 401
        m.syncNotice.text = "Device authorization expired. Reopen the app."
    else if m.sync.operation = "add"
        m.syncNotice.text = "Save failed. Check your connection and try again."
    else
        m.syncNotice.text = "Sync failed: check internet or portal"
    end if
end sub

sub openPage()
    setupIdentity()
    cached = loadPlaylistsFromRegistry()
    m.playlistList.content = buildListContent(cached)
    m.emptyState.visible = cached.count() = 0
    m.addButton.setFocus(true)
    refreshPlaylists()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "left" and m.addButton.hasFocus()
        m.syncButton.setFocus(true)
    else if key = "right" and m.syncButton.hasFocus()
        m.addButton.setFocus(true)
    else if key = "back" or key = "up"
        m.top.getScene().findNode("topNav").callFunc("setFocusToTab", 5)
    else
        return false
    end if
    return true
end function

sub chooseType()
    if m.busy then return
    m.dialog = CreateObject("roSGNode", "Dialog")
    m.dialog.title = "Add playlist"
    m.dialog.buttons = ["M3U URL", "Xtream account", "Cancel"]
    m.dialog.observeField("buttonSelected", "onTypeChosen")
    m.top.getScene().dialog = m.dialog
end sub

sub onTypeChosen()
    choice = m.dialog.buttonSelected
    m.dialog.close = true
    if choice = 2 then return
    m.draft = { type: "m3u" }
    m.fields = ["name", "url"]
    m.labels = ["Playlist name", "M3U playlist URL"]
    if choice = 1
        m.draft.type = "xtream"
        m.fields = ["name", "host", "username", "password"]
        m.labels = ["Playlist name", "Xtream server URL", "Username", "Password"]
    end if
    m.step = 0
    editField()
end sub

sub editField()
    m.dialog = CreateObject("roSGNode", "KeyboardDialog")
    m.dialog.title = m.labels[m.step]
    m.dialog.keyboard.textEditBox.secureMode = m.fields[m.step] = "password"
    action = "Next"
    if m.step = m.fields.count() - 1 then action = "Save"
    m.dialog.buttons = [action, "Cancel"]
    m.dialog.observeField("buttonSelected", "onFieldEntered")
    m.top.getScene().dialog = m.dialog
end sub

sub onFieldEntered()
    if m.dialog.buttonSelected = 1
        m.draft = invalid
        m.dialog.close = true
        return
    end if
    field = m.fields[m.step]
    value = m.dialog.text
    if field <> "password" then value = value.trim()
    if value = ""
        m.dialog.title = m.labels[m.step] + " is required"
        return
    end if
    if field = "url" or field = "host"
        validUrl = CreateObject("roRegex", "^https?://[^/?#[:space:]]+[^[:space:]]*$", "i")
        if not validUrl.isMatch(value)
            m.dialog.title = "Enter a full http:// or https:// URL"
            return
        end if
    end if
    m.draft[field] = value
    m.dialog.close = true
    m.step++
    if m.step < m.fields.count()
        editField()
        return
    end if
    if m.draft.type = "xtream"
        trailing = CreateObject("roRegex", "/+$", "")
        m.draft.host = trailing.replaceAll(m.draft.host, "")
        m.draft.url = m.draft.host + "/get.php?username=" + m.draft.username.EncodeUriComponent() + "&password=" + m.draft.password.EncodeUriComponent() + "&type=m3u_plus"
    end if
    id = loadStoredIdentity()
    m.busy = true
    m.syncNotice.text = "Saving playlist..."
    m.sync.operation = "add"
    m.sync.payload = { credential: id.credential, playlist: m.draft }
    m.draft = invalid
    m.sync.control = "run"
end sub
