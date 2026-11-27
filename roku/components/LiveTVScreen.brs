sub init()
    m.top.channelList = []
    m.top.categories = []
    m.top.selectedCategory = ""
    m.channelList = m.top.findNode("channelList")
end sub

sub loadChannels(category as string)
    print "Loading channels for category: "; category
    ' Load channels from playlist for the given category
end sub

sub onKeyDown(key as Integer)
    ' Handle remote navigation for channel selection
    if key = 13 ' OK/Enter
        ' Play selected channel
    end if
end sub
