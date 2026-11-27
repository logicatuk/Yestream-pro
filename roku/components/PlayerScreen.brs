sub init()
    m.top.streamUrl = ""
    m.top.streamFormat = "hls"
    m.top.contentTitle = ""
    m.player = m.top.findNode("player")
    m.bufferingLabel = m.top.findNode("bufferingLabel")
end sub

sub playStream()
    if m.top.streamUrl <> ""
        content = CreateObject("roSGNode", "ContentNode")
        content.streamformat = m.top.streamFormat
        content.url = m.top.streamUrl
        m.player.visible = true
        m.bufferingLabel.visible = false
        m.player.content = content
        m.player.control = "play"
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "play"
        if m.player.state = "playing"
            m.player.control = "pause"
        else if m.player.state = "paused"
            m.player.control = "resume"
        end if
        return true
    else if key = "back"
        m.player.control = "stop"
        m.player.visible = false
    end if
    return false
end function
