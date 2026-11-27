sub init()
    m.top.onResultSelect = invalid
    m.top.onBack = false
    m.searchResultsList = m.top.findNode("searchResultsList")
    m.searchField = m.top.findNode("searchField")
end sub

sub performSearch(query as string)
    playlists = loadPlaylistsFromRegistry()
    if playlists <> invalid
        results = []
        for each playlist in playlists
            for each channel in valueOr(playlist.channels, [])
                if instr(1, lcase(channel.name), lcase(query)) > 0
                    results.push({ title: channel.name, streamUrl: channel.url })
                end if
            end for
        end for
        m.searchResultsList.content = buildListContent(results)
        m.searchResultsList.observeField("itemSelected", "onResultSelected")
    end if
end sub

sub onResultSelected()
    idx = m.searchResultsList.itemSelected
    if idx >= 0
        item = m.searchResultsList.content.getChild(idx)
        m.top.onResultSelect = { title: item.title, streamUrl: item.record.streamUrl }
    end if
end sub

sub onKeyDown(key as Integer)
    if key = 283
        m.top.onBack = true
    end if
end sub
