sub init()
    m.top.onAdd = false
    m.top.onDelete = ""
    m.top.onSync = false
    m.top.onBack = false
    m.playlistList = m.top.findNode("playlistList")
    m.qrCanvas = m.top.findNode("qrCanvas")
    m.macLabel = m.top.findNode("macLabel")
    m.keyLabel = m.top.findNode("keyLabel")
end sub

sub setCloud(cloud as object)
    m.top.cloud = cloud
    m.macLabel.text = "MAC: " + valueOr(cloud.mac, "")
    m.keyLabel.text = "KEY: " + valueOr(cloud.key6, "")
    drawPortalQr(m.qrCanvas, portalLogin(cloud.mac, cloud.key6), 5)
    loadPlaylists()
end sub

sub loadPlaylists()
    playlists = loadPlaylistsFromRegistry()
    if playlists <> invalid
        m.top.cloud = { playlists: playlists }
        items = []
        for each pl in playlists
            permission = "Editable"
            if pl.lockedByReseller = true then permission = "Reseller managed"
            items.push({
                title: pl.name,
                subtitle: pl.type + " · " + permission
            })
        end for
        m.playlistList.content = buildListContent(items)
    end if
end sub
