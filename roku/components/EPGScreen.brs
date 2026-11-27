sub init()
    m.top.playlistId = ""
    m.top.onProgramSelect = invalid
    m.top.onBack = false
    m.channelList = m.top.findNode("channelList")
    m.programGrid = m.top.findNode("programGrid")
    m.programGrid.observeField("itemSelected", "onProgramSelected")
end sub

sub loadEPG(playlistId as string)
    m.top.playlistId = playlistId
    playlists = loadPlaylistsFromRegistry()
    if playlists <> invalid
        channels = []
        programs = []
        for each playlist in playlists
            if playlist.id = playlistId or playlistId = ""
                for each channel in valueOr(playlist.channels, [])
                    channels.push({ title: channel.name, id: channel.id })
                    for each prog in valueOr(channel.programs, [])
                        programs.push({
                            channelId: channel.id,
                            title: prog.title,
                            start: prog.start,
                            stop: prog.stop
                        })
                    end for
                end for
            end if
        end for
        m.channelList.content = buildListContent(channels)
        m.programGrid.content = buildListContent(programs)
    end if
end sub

sub onProgramSelected()
    idx = m.programGrid.itemSelected
    if idx >= 0
        item = m.programGrid.content.getChild(idx)
        m.top.onProgramSelect = { title: item.title, channelId: item.record.channelId }
    end if
end sub

sub onKeyDown(key as Integer)
    if key = 283
        m.top.onBack = true
    end if
end sub
