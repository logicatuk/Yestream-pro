' epg.brs - EPG grid data and XMLTV parsing for Roku

'/ Parse XMLTV data into EPG programs
function parseXmltv(xmlText as string) as object
    epg = {
        channels: [],
        programs: []
    }

    ' BrightScript has limited XML parsing; use roXMLElement if available
    ' For now, return empty structure - in production use roXMLElement

    return epg
end function

'/ Parse a single programme element from XMLTV
function parseProgramme(programmeNode as object) as object
    programme = {
        channel: "",
        start: "",
        stop: "",
        title: "",
        description: "",
        category: ""
    }

    ' Extract attributes
    ' channel attribute
    ' start/stop attributes (ISO format)
    ' title, desc, category child nodes

    return programme
end function

'/ Build EPG grid for display
function buildEpgGrid(epgData as object, channelIds as array, timeRange as object) as object
    grid = {
        channels: [],
        programs: []
    }

    ' Filter programs by channel and time range
    ' Organize into time slots for grid display

    return grid
end function

'/ Get current/next programme for a channel
function getCurrentNextProgramme(channelId as string, epgData as object) as object
    now = dateNow()
    current = invalid
    nextProgramme = invalid

    for each programme in epgData.programs
        if programme.channel = channelId
            startMs = dateParse(programme.start)
            stopMs = dateParse(programme.stop)

            if startMs <= now and stopMs > now
                current = programme
            else if startMs > now and (nextProgramme = invalid or startMs < dateParse(nextProgramme.start))
                nextProgramme = programme
            end if
        end if
    end for

    return {
        current: current,
        next: nextProgramme
    }
end function

'/ Get programmes for a time window
function getProgrammesForWindow(channelId as string, startTime as integer, endTime as integer, epgData as object) as array
    result = []

    for each programme in epgData.programs
        if programme.channel = channelId
            startMs = dateParse(programme.start)
            stopMs = dateParse(programme.stop)

            ' Check if programme overlaps with time window
            if startMs < endTime and stopMs > startTime
                result.push(programme)
            end if
        end if
    end for

    return result
end function