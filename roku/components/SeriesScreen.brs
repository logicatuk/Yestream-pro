sub init()
    m.top.playlistId = ""
    m.top.onSeriesSelect = invalid
    m.top.onBack = false
    m.seriesGrid = m.top.findNode("seriesGrid")
    m.seriesGrid.observeField("itemSelected", "onGridItemSelected")
end sub

sub loadSeries(playlistId as string)
    m.top.playlistId = playlistId
    playlists = loadPlaylistsFromRegistry()
    if playlists <> invalid
        items = []
        for each playlist in playlists
            if playlist.id = playlistId or playlistId = ""
                for each series in valueOr(playlist.series, [])
                    items.push({
                        id: series.id,
                        title: series.title,
                        poster: series.posterUrl,
                        description: series.description,
                        seasons: series.seasons
                    })
                end for
            end if
        end for
        m.seriesGrid.content = buildListContent(items)
    end if
end sub

sub onGridItemSelected()
    idx = m.seriesGrid.itemSelected
    if idx >= 0
        item = m.seriesGrid.content.getChild(idx)
        m.top.onSeriesSelect = {
            title: item.title,
            seasons: item.record.seasons
        }
    end if
end sub

sub onKeyDown(key as Integer)
    if key = 283
        m.top.onBack = true
    end if
end sub
