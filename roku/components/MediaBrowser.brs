sub init()
    m.list = m.top.findNode("list")
    m.list.observeField("itemSelected","selectRow")
    m.list.observeField("itemFocused","showPoster")
    m.video = m.top.findNode("video")
    m.video.observeField("state","videoChanged")
    m.history = []
end sub

sub openPage()
    leavePage()
    m.history = []
    sources = loadPlaylistsFromRegistry()
    titles = {live:"Live TV", movie:"Movies", series:"Series"}
    page = {stage:"sources", title:titles[m.top.kind], rows:sources, hint:"Select a playlist", index:0}
    if sources.count() = 0 then page.hint = "Add or sync a playlist in Playlists."
    render(page)
    if sources.count() = 1 then openSource(sources[0])
end sub

sub leavePage()
    if m.task <> invalid
        m.task.unobserveField("result")
        m.task.control = "stop"
        m.task = invalid
    end if
    if m.video.visible then closeVideo()
end sub

sub render(page as object)
    m.page = page
    m.top.findNode("heading").text = page.title
    m.top.findNode("notice").text = page.hint
    m.top.findNode("summary").text = valueOr(page.description,"")
    m.list.content = buildListContent(page.rows)
    m.list.jumpToItem = page.index
    showPoster()
    if page.rows.count() > 0 then m.list.setFocus(true) else m.top.setFocus(true)
end sub

sub showPoster()
    if m.page = invalid then return
    uri = valueOr(m.page.poster,"")
    idx = m.list.itemFocused
    if idx >= 0 and idx < m.page.rows.count()
        uri = valueOr(m.page.rows[idx].poster,uri)
    end if
    m.top.findNode("art").uri = uri
end sub

sub remember()
    m.page.index = m.list.itemFocused
    m.history.push(m.page)
end sub

sub openSource(source as object)
    m.source = source
    requestPage("categories",source.name,{})
end sub

sub requestPage(stage as string, title as string, item as object)
    remember()
    render({stage:stage,title:title,rows:[],index:0,hint:"Loading...",poster:valueOr(item.poster,"")})
    m.task = CreateObject("roSGNode","CatalogTask")
    m.task.observeField("result","pageLoaded")
    m.task.request = {source:m.source,kind:m.top.kind,stage:stage,item:item}
    m.task.control = "run"
end sub

sub pageLoaded()
    result = m.task.result
    m.task = invalid
    m.page.rows = result.rows
    m.page.description = result.description
    if result.poster <> "" then m.page.poster = result.poster
    hints = {categories:"Choose a category",items:"Choose a title",details:"Choose playback"}
    m.page.hint = hints[m.page.stage]
    if result.rows.count() = 0 then m.page.hint = "No titles available"
    if result.error <> "" then m.page.hint = result.error
    render(m.page)
end sub

sub selectRow()
    row = m.page.rows[m.list.itemSelected]
    if m.page.stage = "sources"
        openSource(row)
    else if m.page.stage = "categories"
        if row.children <> invalid
            remember()
            render({stage:"items",title:row.title,rows:row.children,index:0,hint:"Choose a title"})
        else
            requestPage("items",row.title,row)
        end if
    else if m.page.stage = "items" and m.top.kind <> "live"
        if m.source.type = "m3u"
            remember()
            render({stage:"details",title:row.title,poster:row.poster,rows:[{title:"Play",url:row.url}],index:0,hint:"From your playlist"})
        else
            requestPage("details",row.title,row)
        end if
    else
        content = CreateObject("roSGNode","ContentNode")
        content.url = row.url
        content.title = row.title
        if instr(1,lcase(row.url),".m3u8") > 0 then content.streamFormat = "hls"
        m.video.content = content
        m.video.visible = true
        m.video.setFocus(true)
        m.video.control = "play"
    end if
end sub

sub closeVideo()
    m.video.control = "stop"
    m.video.visible = false
    m.list.setFocus(true)
end sub

sub videoChanged()
    if not m.video.visible then return
    if m.video.state = "error" or m.video.state = "finished"
        if m.video.state = "error" then m.top.findNode("notice").text = "This stream could not be played."
        closeVideo()
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or key <> "back" then return false
    if m.video.visible
        closeVideo()
    else
        leavePage()
        if m.history.count() > 0
            render(m.history.pop())
        else
            m.top.getScene().findNode("topNav").callFunc("setFocusToTab",0)
        end if
    end if
    return true
end function
