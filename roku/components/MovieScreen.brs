sub init()
    m.top.playlistId = ""
    m.top.onMovieSelect = invalid
    m.top.onBack = false
    m.movieGrid = m.top.findNode("movieGrid")
    m.movieGrid.observeField("itemSelected", "onGridItemSelected")
end sub

sub loadMovies(playlistId as string)
    m.top.playlistId = playlistId
    playlists = loadPlaylistsFromRegistry()
    if playlists <> invalid
        items = []
        for each playlist in playlists
            if playlist.id = playlistId or playlistId = ""
                for each movie in valueOr(playlist.movies, [])
                    items.push({
                        id: movie.id,
                        title: movie.title,
                        poster: movie.posterUrl,
                        description: movie.description,
                        streamUrl: movie.streamUrl
                    })
                end for
            end if
        end for
        m.movieGrid.content = buildListContent(items)
    end if
end sub

sub onGridItemSelected()
    idx = m.movieGrid.itemSelected
    if idx >= 0
        item = m.movieGrid.content.getChild(idx)
        m.top.onMovieSelect = {
            title: item.title,
            streamUrl: item.record.streamUrl
        }
    end if
end sub

sub onKeyDown(key as Integer)
    if key = 283
        m.top.onBack = true
    end if
end sub
