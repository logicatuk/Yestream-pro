# Roku Channel — Complete UI/Logic Specification

## Table of Contents
1. [Architecture Overview](#architecture)
2. [Project Structure](#project-structure)
3. [Navigation Flow](#navigation-flow)
4. [Page 1: Splash Screen](#page-1-splash-screen)
5. [Page 2: Home Dashboard](#page-2-home-dashboard)
6. [Page 3: Live TV Screen](#page-3-live-tv-screen)
7. [Page 4: Player Screen](#page-4-player-screen)
8. [Page 5: Movie/VOD Screen](#page-5-movievod-screen)
9. [Page 6: Series Screen](#page-6-series-screen)
10. [Page 7: EPG Grid Screen](#page-7-epg-grid-screen)
11. [Page 8: Playlist Manager](#page-8-playlist-manager)
12. [Page 9: Account/Device Screen](#page-9-account-device-screen)
13. [Page 10: Expiry Lock Screen](#page-10-expiry-lock-screen)
14. [Page 11: QR Code Activation Screen](#page-11-qr-code-activation-screen)
15. [Page 12: Settings Screen](#page-12-settings-screen)
16. [Data Models](#data-models)
17. [API Integration Details](#api-integration-details)
18. [Remote Control Mapping](#remote-control-mapping)
19. [Styling & Theme](#styling--theme)
20. [Screen Transition Flow](#screen-transition-flow)

---

## Architecture Overview

The Roku channel is a native BrightScript/SceneGraph application that communicates with the Yestream backend at `https://yestream.ai.studio/api/v1`. All data flows through REST API calls with Bearer token authentication.

### Tech Stack
- **Language**: BrightScript
- **UI Framework**: SceneGraph (XML + BrightScript)
- **Video Playback**: `roVideoScreen` (native Roku video player)
- **Storage**: `roRegistrySection` (local device storage)
- **HTTP**: `roUrlTransfer` (REST API calls)
- **Network**: TLS 1.2+ with certificate validation

### Architectural Layers
```
┌─────────────────────────────────────┐
│         SceneGraph UI Layer         │
│  (Screens: Home, Player, EPG, etc.) │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│       Business Logic Layer          │
│  (Licensing, Sync, Playlist, EPG)   │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│       Network Layer (roUrlTransfer) │
│  (REST API / Bearer Auth)           │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│    Yestream Backend API             │
│  https://yestream.ai.studio/api/v1  │
└─────────────────────────────────────┘
```

---

## Project Structure

```
roku/
├── manifest.manifest               # Channel manifest
├── source/
│   ├── main.brs                    # Entry point + screen routing
│   ├── config.brs                  # API endpoints + constants
│   ├── device-identity.brs         # MAC + 6-digit key generation
│   ├── cloud-api.brs               # HTTP client (roUrlTransfer)
│   ├── json.brs                    # JSON parser/serializer
│   ├── sha256.brs                  # SHA-256 implementation
│   ├── qrcode.brs                  # QR code rendering
│   ├── access-evaluation.brs       # Trial/active/expired logic
│   ├── playlists.brs               # M3U/Xtream/Stalker parsers
│   ├── epg.brs                     # EPG grid + XMLTV parsing
│   └── licensing.brs               # Expiry guard state machine
├── components/
│   ├── YestreamScene.xml           # Root scene container
│   ├── HomeScreen.xml              # Dashboard with rails
│   ├── LiveTVScreen.xml            # Channel list + categories
│   ├── PlayerScreen.xml            # roVideoScreen wrapper
│   ├── MovieScreen.xml             # VOD catalog
│   ├── SeriesScreen.xml            # Seasons/episodes
│   ├── EPGScreen.xml               # EPG grid
│   ├── PlaylistManager.xml         # Playlist CRUD
│   ├── AccountScreen.xml           # Device info + key
│   ├── ExpiryLockScreen.xml        # Full-screen activation lock
│   ├── SettingsScreen.xml          # Settings panel
│   └── SearchScreen.xml            # Search across content
├── images/
│   ├── icon.png                    # Channel icon (290x218)
│   └── splash.png                  # Splash screen (1920x1080)
├── locale/en_US/
│   └── strings.txt                 # Localized strings
└── test/                           # Unit tests
```

---

## Navigation Flow

```
Splash Screen
    ↓ (auto)
Home Dashboard ←─────────────────────┐
   │                                  │
   ├──→ Live TV Screen               │
   ├──→ Movie Screen                 │
   ├──→ Series Screen                │
   ├──→ EPG Grid Screen              │
   ├──→ Playlist Manager             │
   ├──→ Account/Device Screen        │
   ├──→ Settings Screen              │
   ├──→ Search Screen                │
   │                                  ↓
   └──→ Player Screen ←──────────────┘
             │
             ↓
    Expiry Lock Screen (if expired)
```

---

## Page 1: Splash Screen

### Purpose
Show Yestream branding while initializing device identity and checking entitlement status.

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="SplashScreen" extends="Group">
    <interface>
        <field id="onComplete" type="boolean" value="false" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        <Image id="splashImage" uri="pkg:/images/splash.png" translation="[360, 180]" width="1200" height="720" />
        <Label id="statusLabel" text="Initializing..." font="font:MediumSystemFont" color="#FFFFFF" translation="[860, 950]" />
        <Spinner id="spinner" translation="[900, 850]" />
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.onComplete = false
        ' Auto-initialize device identity
        void initDevice()
    end sub

    sub initDevice()
        ' Load stored identity from registry
        identity = loadStoredIdentity()
        
        ' If no identity, generate new one
        if identity.mac = ""
            newIdentity = generateDeviceIdentity()
            saveStoredIdentity(newIdentity)
        end if
        
        ' Check entitlement with backend
        entitlement = checkEntitlement(identity.credential)
        
        if entitlement.ok
            ' Proceed to home or lock screen
            m.top.onComplete = true
        else
            ' Show lock screen
            showLockScreen()
        end if
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **init()**: Called when screen loads, starts async initialization
- **initDevice()**: Loads stored MAC/key from `roRegistrySection`, calls `/api/v1/devices/register`
- **checkEntitlement()**: Calls `/api/v1/device/entitlement` with Bearer token
- **onComplete**: Signals parent to route to Home or Lock screen

### Data Flow
```
Splash → loadStoredIdentity() → registerDevice() → checkEntitlement() → onComplete
```

---

## Page 2: Home Dashboard

### Purpose
Main navigation hub showing content rails (Live TV, Movies, Series, EPG, Playlists).

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="HomeScreen" extends="Group">
    <interface>
        <field id="entitlement" type="assocarray" value="" />
        <field id="deviceIdentity" type="assocarray" value="" />
        <field id="onNavigate" type="string" value="" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        
        <!-- Header -->
        <Label id="headerTitle" text="Yestream Home" font="font:LargeBoldSystemFont" color="#FFFFFF" translation="[40, 40]" />
        <Label id="trialBadge" text="Trial · 7 days" font="font:MediumSystemFont" color="#38BDF8" translation="[1400, 40]" />
        
        <!-- Rail 1: Live TV -->
        <Group id="liveTvGroup" translation="[40, 120]" width="1840" height="300">
            <Label text="Live TV" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[0, 0]" />
            <RowList id="liveTvList" translation="[0, 40]" numrows="1" colwidth="240" rowwidth="1840" colheight="180" />
        </Group>
        
        <!-- Rail 2: Movies -->
        <Group id="movieGroup" translation="[40, 450]" width="1840" height="300">
            <Label text="Movies" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[0, 0]" />
            <RowList id="movieList" translation="[0, 40]" numrows="1" colwidth="240" rowwidth="1840" colheight="180" />
        </Group>
        
        <!-- Rail 3: Series -->
        <Group id="seriesGroup" translation="[40, 780]" width="1840" height="300">
            <Label text="Series" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[0, 0]" />
            <RowList id="seriesList" translation="[0, 40]" numrows="1" colwidth="240" rowwidth="1840" colheight="180" />
        </Group>
        
        <!-- Rail 4: Playlists -->
        <Group id="playlistGroup" translation="[40, 1110]" width="1840" height="300">
            <Label text="My Playlists" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[0, 0]" />
            <RowList id="playlistList" translation="[0, 40]" numrows="1" colwidth="240" rowwidth="1840" colheight="180" />
        </Group>
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.entitlement = invalid
        m.top.deviceIdentity = invalid
        m.top.onNavigate = ""
        m.liveTvList = m.top.findNode("liveTvList")
        m.movieList = m.top.findNode("movieList")
        m.seriesList = m.top.findNode("seriesList")
        m.playlistList = m.top.findNode("playlistList")
    end sub

    sub setContent(entitlement as object, identity as object)
        m.top.entitlement = entitlement
        m.top.deviceIdentity = identity
        void loadRails()
    end sub

    sub loadRails()
        ' Load live TV channels
        liveChannels = getLiveChannels()
        m.liveTvList.content = createObject("roSGNode", "ContentNode")
        m.liveTvList.content.append(liveChannels)
        
        ' Load movies
        movies = getMovies()
        m.movieList.content = createObject("roSGNode", "ContentNode")
        m.movieList.content.append(movies)
        
        ' Load series
        series = getSeries()
        m.seriesList.content = createObject("roSGNode", "ContentNode")
        m.seriesList.content.append(series)
        
        ' Load playlists
        playlists = getPlaylists()
        m.playlistList.content = createObject("roSGNode", "ContentNode")
        m.playlistList.content.append(playlists)
    end sub

    sub onKeyDown(key as Integer)
        select case key
            case 13 ' OK/Enter
                focused = m.top.findNode("focusedNode")
                if focused <> invalid
                    m.top.onNavigate = focused.contentId
                end if
            case 283 ' Back
                m.top.onNavigate = "exit"
        end select
    end sub

    sub loadLiveChannels() as object
        channels = []
        ' Fetch from cloud API
        result = cloudApi.getSync()
        if result.ok
            for each playlist in result.data.playlists
                if playlist.type = "xtream"
                    for each channel in playlist.channels
                        channels.append({
                            title: channel.name,
                            streamUrl: channel.url,
                            thumbnail: channel.logo,
                            contentId: channel.id
                        })
                    end for
                end if
            end for
        end if
        return channels
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **init()**: Initialize UI fields and find nodes
- **setContent()**: Receive entitlement and device identity from parent
- **loadRails()**: Load all content rails (Live TV, Movies, Series, Playlists)
- **onKeyDown()**: Handle remote navigation (OK/Enter = select, Back = exit)

---

## Page 3: Live TV Screen

### Purpose
Display live TV channels organized by category with EPG info.

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="LiveTVScreen" extends="Group">
    <interface>
        <field id="playlistId" type="string" value="" />
        <field id="onChannelSelect" type="string" value="" />
        <field id="onBack" type="string" value="" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        
        <!-- Sidebar: Categories -->
        <Group id="sidebarGroup" translation="[0, 0]" width="400" height="1080">
            <Rectangle width="400" height="1080" color="#1A1A2E" />
            <Label id="categoryHeader" text="Categories" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[20, 40]" />
            <List id="categoryList" translation="[20, 80]" width="360" height="900" itemSize="[360, 60]" />
        </Group>
        
        <!-- Main: Channel Grid -->
        <Group id="mainGroup" translation="[400, 0]" width="1520" height="1080">
            <Label id="channelHeader" text="Live Channels" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[0, 40]" />
            <Grid id="channelGrid" translation="[0, 80]" width="1520" height="900" numcolumns="4" colwidth="360" colheight="280" />
        </Group>
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.playlistId = ""
        m.top.onChannelSelect = ""
        m.top.onBack = ""
        m.categoryList = m.top.findNode("categoryList")
        m.channelGrid = m.top.findNode("channelGrid")
    end sub

    sub loadChannels(playlistId as string)
        m.top.playlistId = playlistId
        result = cloudApi.getSync()
        if result.ok
            channels = []
            for each playlist in result.data.playlists
                if playlist.id = playlistId
                    for each channel in playlist.channels
                        channels.append({
                            title: channel.name,
                            url: channel.url,
                            thumbnail: channel.logo,
                            contentId: channel.id
                        })
                    end for
                end if
            end for
            m.channelGrid.content = createObject("roSGNode", "ContentNode")
            m.channelGrid.content.append(channels)
        end if
    end sub

    sub onChannelSelected(channelId as string)
        m.top.onChannelSelect = channelId
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **init()**: Initialize category list and channel grid
- **loadChannels()**: Fetch channels from cloud API for selected playlist
- **onChannelSelected()**: Emit channel selection event to parent

---

## Page 4: Player Screen

### Purpose
Video playback with full controls (play/pause, volume, seek, etc.).

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="PlayerScreen" extends="Group">
    <interface>
        <field id="streamUrl" type="string" value="" />
        <field id="streamFormat" type="string" value="hls" />
        <field id="contentTitle" type="string" value="" />
        <field id="onPlaybackComplete" type="string" value="" />
        <field id="onBack" type="string" value="" />
    </interface>

    <children>
        <Video id="player" translation="[0, 0]" width="1920" height="1080" visible="false" />
        <Rectangle width="1920" height="1080" color="#000000" />
        
        <!-- Overlay Controls -->
        <Group id="controlsOverlay" translation="[0, 0]" width="1920" height="1080" visible="false">
            <Rectangle width="1920" height="1080" color="#000000" opacity="0.7" />
            
            <!-- Title -->
            <Label id="titleLabel" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[40, 40]" />
            
            <!-- Progress Bar -->
            <Rectangle id="progressBar" translation="[40, 920]" width="1840" height="4" color="#333333" />
            <Rectangle id="progressFill" translation="[40, 920]" width="0" height="4" color="#38BDF8" />
            
            <!-- Time -->
            <Label id="currentTime" text="0:00" font="font:SmallSystemFont" color="#FFFFFF" translation="[40, 930]" />
            <Label id="totalTime" text="0:00" font="font:SmallSystemFont" color="#FFFFFF" translation="[right, 930]" />
            
            <!-- Controls Row -->
            <Group id="controlsRow" translation="[860, 800]" width="200" height="80">
                <Button id="playPauseBtn" translation="[0, 0]" width="80" height="80">
                    <Icon source="pause" />
                </Button>
                <Button id="stopBtn" translation="[100, 0]" width="80" height="80">
                    <Icon source="stop" />
                </Button>
            </Group>
        </Group>
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.streamUrl = ""
        m.top.streamFormat = "hls"
        m.top.contentTitle = ""
        m.top.onPlaybackComplete = ""
        m.top.onBack = ""
        m.player = m.top.findNode("player")
        m.controlsOverlay = m.top.findNode("controlsOverlay")
        m.titleLabel = m.top.findNode("titleLabel")
        m.progressBar = m.top.findNode("progressBar")
        m.progressFill = m.top.findNode("progressFill")
        m.currentTime = m.top.findNode("currentTime")
        m.totalTime = m.top.findNode("totalTime")
    end sub

    sub playStream()
        if m.top.streamUrl <> ""
            m.player.content.streamformat = m.top.streamFormat
            m.player.content.url = m.top.streamUrl
            m.player.visible = true
            m.titleLabel.text = m.top.contentTitle
            m.controlsOverlay.visible = true
            m.player.play()
        end if
    end sub

    sub onKeyDown(key as Integer)
        select case key
            case 13 ' Play/Pause
                if m.player.state = "playing"
                    m.player.pause()
                else
                    m.player.resume()
                end if
            case 283 ' Back
                m.player.stop()
                m.top.onBack = true
            case 285 ' Play/Pause button on remote
                if m.player.state = "playing"
                    m.player.pause()
                else
                    m.player.resume()
                end if
        end select
    end sub

    sub onPlaybackStateChanged(state as string)
        if state = "eos" ' End of stream
            m.top.onPlaybackComplete = true
        end if
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **playStream()**: Initialize video player with stream URL and format
- **onKeyDown()**: Handle remote controls (Play/Pause, Back)
- **onPlaybackStateChanged()**: Detect end of stream (EOS)

---

## Page 5: Movie/VOD Screen

### Purpose
Movie catalog with poster grid and category filtering.

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="MovieScreen" extends="Group">
    <interface>
        <field id="playlistId" type="string" value="" />
        <field id="onMovieSelect" type="string" value="" />
        <field id="onBack" type="string" value="" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        
        <Label id="headerTitle" text="Movies" font="font:LargeBoldSystemFont" color="#FFFFFF" translation="[40, 40]" />
        
        <Grid id="movieGrid" translation="[40, 100]" width="1840" height="900" numcolumns="4" colwidth="440" colheight="320" />
        
        <Button id="backBtn" translation="[1700, 40]" width="180" height="50">
            <Label text="Back" font="font:MediumSystemFont" />
        </Button>
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.playlistId = ""
        m.top.onMovieSelect = ""
        m.top.onBack = ""
        m.movieGrid = m.top.findNode("movieGrid")
    end sub

    sub loadMovies(playlistId as string)
        m.top.playlistId = playlistId
        result = cloudApi.getSync()
        if result.ok
            movies = []
            for each playlist in result.data.playlists
                if playlist.id = playlistId
                    for each movie in playlist.movies
                        movies.append({
                            title: movie.title,
                            poster: movie.posterUrl,
                            description: movie.description,
                            streamUrl: movie.streamUrl,
                            contentId: movie.id
                        })
                    end for
                end if
            end for
            m.movieGrid.content = createObject("roSGNode", "ContentNode")
            m.movieGrid.content.append(movies)
        end if
    end sub

    sub onMovieSelected(movieId as string)
        m.top.onMovieSelect = movieId
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **init()**: Initialize grid and back button
- **loadMovies()**: Fetch movies from cloud API for selected playlist
- **onMovieSelected()**: Emit movie selection to parent for playback

---

## Page 6: Series Screen

### Purpose
Series catalog with seasons and episodes.

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="SeriesScreen" extends="Group">
    <interface>
        <field id="playlistId" type="string" value="" />
        <field id="onSeriesSelect" type="string" value="" />
        <field id="onBack" type="string" value="" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        
        <Label id="headerTitle" text="Series" font="font:LargeBoldSystemFont" color="#FFFFFF" translation="[40, 40]" />
        
        <Grid id="seriesGrid" translation="[40, 100]" width="1840" height="900" numcolumns="4" colwidth="440" colheight="320" />
        
        <Button id="backBtn" translation="[1700, 40]" width="180" height="50">
            <Label text="Back" font="font:MediumSystemFont" />
        </Button>
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.playlistId = ""
        m.top.onSeriesSelect = ""
        m.top.onBack = ""
        m.seriesGrid = m.top.findNode("seriesGrid")
    end sub

    sub loadSeries(playlistId as string)
        m.top.playlistId = playlistId
        result = cloudApi.getSync()
        if result.ok
            seriesList = []
            for each playlist in result.data.playlists
                if playlist.id = playlistId
                    for each series in playlist.series
                        seriesList.append({
                            title: series.title,
                            poster: series.posterUrl,
                            description: series.description,
                            seasons: series.seasons,
                            contentId: series.id
                        })
                    end for
                end if
            end for
            m.seriesGrid.content = createObject("roSGNode", "ContentNode")
            m.seriesGrid.content.append(seriesList)
        end if
    end sub

    sub onSeriesSelected(seriesId as string)
        m.top.onSeriesSelect = seriesId
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **loadSeries()**: Fetch series from cloud API
- **onSeriesSelected()**: Emit series selection to parent

---

## Page 7: EPG Grid Screen

### Purpose
Electronic Program Guide showing channels vs time slots with current program highlighting.

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="EPGScreen" extends="Group">
    <interface>
        <field id="playlistId" type="string" value="" />
        <field id="onChannelSelect" type="string" value="" />
        <field id="onBack" type="string" value="" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        
        <Label id="headerTitle" text="EPG Guide" font="font:LargeBoldSystemFont" color="#FFFFFF" translation="[40, 40]" />
        
        <!-- Channel column -->
        <Group id="channelColumn" translation="[40, 100]" width="300" height="900">
            <Rectangle width="300" height="900" color="#1A1A2E" />
            <List id="channelList" translation="[20, 20]" width="260" height="860" itemSize="[260, 60]" />
        </Group>
        
        <!-- Program grid -->
        <Group id="programGridGroup" translation="[340, 100]" width="1540" height="900">
            <Grid id="programGrid" translation="[0, 0]" width="1540" height="900" numcolumns="7" colwidth="200" colheight="120" />
        </Group>
        
        <!-- Time header -->
        <Group id="timeHeader" translation="[340, 80]" width="1540" height="40">
            <Label id="timeLabel1" text="12:00" font="font:SmallSystemFont" color="#94A3B8" translation="[0, 0]" />
            <Label id="timeLabel2" text="13:00" font="font:SmallSystemFont" color="#94A3B8" translation="[200, 0]" />
            <Label id="timeLabel3" text="14:00" font="font:SmallSystemFont" color="#94A3B8" translation="[400, 0]" />
            <Label id="timeLabel4" text="15:00" font="font:SmallSystemFont" color="#94A3B8" translation="[600, 0]" />
            <Label id="timeLabel5" text="16:00" font="font:SmallSystemFont" color="#94A3B8" translation="[800, 0]" />
            <Label id="timeLabel6" text="17:00" font="font:SmallSystemFont" color="#94A3B8" translation="[1000, 0]" />
            <Label id="timeLabel7" text="18:00" font="font:SmallSystemFont" color="#94A3B8" translation="[1200, 0]" />
        </Group>
        
        <Button id="backBtn" translation="[1700, 40]" width="180" height="50">
            <Label text="Back" font="font:MediumSystemFont" />
        </Button>
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.playlistId = ""
        m.top.onChannelSelect = ""
        m.top.onBack = ""
        m.channelList = m.top.findNode("channelList")
        m.programGrid = m.top.findNode("programGrid")
    end sub

    sub loadEPG(playlistId as string)
        m.top.playlistId = playlistId
        result = cloudApi.getSync()
        if result.ok
            channels = []
            programs = []
            for each playlist in result.data.playlists
                if playlist.id = playlistId
                    for each channel in playlist.channels
                        channels.append({
                            title: channel.name,
                            thumbnail: channel.logo,
                            contentId: channel.id
                        })
                        for each program in channel.programs
                            programs.append({
                                channelId: channel.id,
                                title: program.title,
                                start: program.start,
                                stop: program.stop,
                                description: program.description,
                                contentId: program.id
                            })
                        end for
                    end for
                end if
            end for
            m.channelList.content = createObject("roSGNode", "ContentNode")
            m.channelList.content.append(channels)
            m.programGrid.content = createObject("roSGNode", "ContentNode")
            m.programGrid.content.append(programs)
        end if
    end sub

    sub onProgramSelected(programId as string)
        m.top.onChannelSelect = programId
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **loadEPG()**: Fetch EPG data with channels and programs
- **onProgramSelected()**: Emit program selection for playback

---

## Page 8: Playlist Manager

### Purpose
Add, edit, and delete M3U/Xtream playlists with two-way sync.

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="PlaylistManager" extends="Group">
    <interface>
        <field id="onPlaylistChange" type="string" value="" />
        <field id="onBack" type="string" value="" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        
        <Label id="headerTitle" text="Manage Playlists" font="font:LargeBoldSystemFont" color="#FFFFFF" translation="[40, 40]" />
        
        <Grid id="playlistGrid" translation="[40, 100]" width="1840" height="600" numcolumns="3" colwidth="580" colheight="280" />
        
        <Button id="addBtn" translation="[40, 720]" width="200" height="60">
            <Label text="Add Playlist" font="font:MediumSystemFont" />
        </Button>
        
        <Button id="refreshBtn" translation="[260, 720]" width="200" height="60">
            <Label text="Sync" font="font:MediumSystemFont" />
        </Button>
        
        <Button id="backBtn" translation="[1700, 40]" width="180" height="50">
            <Label text="Back" font="font:MediumSystemFont" />
        </Button>
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.onPlaylistChange = ""
        m.top.onBack = ""
        m.playlistGrid = m.top.findNode("playlistGrid")
    end sub

    sub loadPlaylists()
        result = cloudApi.getSync()
        if result.ok
            playlists = []
            for each playlist in result.data.playlists
                playlists.append({
                    title: playlist.name,
                    subtitle: playlist.type + " - " + playlist.url,
                    thumbnail: playlist.thumbnail,
                    contentId: playlist.id,
                    locked: playlist.lockedByReseller
                })
            end for
            m.playlistGrid.content = createObject("roSGNode", "ContentNode")
            m.playlistGrid.content.append(playlists)
        end if
    end sub

    sub onPlaylistSelected(playlistId as string)
        m.top.onPlaylistChange = playlistId
    end sub

    sub addPlaylist()
        ' Show add playlist dialog
        m.top.onPlaylistChange = "add"
    end sub

    sub refreshPlaylists()
        void loadPlaylists()
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **loadPlaylists()**: Fetch playlists from cloud API
- **addPlaylist()**: Trigger add playlist dialog
- **refreshPlaylists()**: Sync with cloud

---

## Page 9: Account/Device Screen

### Purpose
Display device identity (MAC, key), plan status, expiry date, and playlist count.

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="AccountScreen" extends="Group">
    <interface>
        <field id="deviceIdentity" type="assocarray" value="" />
        <field id="entitlement" type="assocarray" value="" />
        <field id="onRefresh" type="string" value="" />
        <field id="onBack" type="string" value="" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        
        <Label id="headerTitle" text="Account & Device" font="font:LargeBoldSystemFont" color="#FFFFFF" translation="[40, 40]" />
        
        <!-- Device Info Card -->
        <Group id="deviceCard" translation="[40, 120]" width="1840" height="200">
            <Rectangle width="1840" height="200" color="#1A1A2E" />
            
            <Label id="macLabel" text="MAC Address:" font="font:MediumSystemFont" color="#94A3B8" translation="[40, 20]" />
            <Label id="macValue" text="02:XX:XX:XX:XX:XX" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[40, 50]" />
            
            <Label id="keyLabel" text="Device Key:" font="font:MediumSystemFont" color="#94A3B8" translation="[40, 90]" />
            <Label id="keyValue" text="XXXXXX" font="font:MediumBoldSystemFont" color="#38BDF8" translation="[40, 120]" />
            
            <Label id="platformLabel" text="Platform:" font="font:MediumSystemFont" color="#94A3B8" translation="[600, 20]" />
            <Label id="platformValue" text="Roku" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[600, 50]" />
            
            <Button id="copyMacBtn" translation="[1400, 20]" width="200" height="50">
                <Label text="Copy MAC" font="font:SmallSystemFont" />
            </Button>
            
            <Button id="copyKeyBtn" translation="[1400, 90]" width="200" height="50">
                <Label text="Copy Key" font="font:SmallSystemFont" />
            </Button>
        </Group>
        
        <!-- License Info Card -->
        <Group id="licenseCard" translation="[40, 340]" width="1840" height="200">
            <Rectangle width="1840" height="200" color="#1A1A2E" />
            
            <Label id="planLabel" text="Plan:" font="font:MediumSystemFont" color="#94A3B8" translation="[40, 20]" />
            <Label id="planValue" text="TRIAL" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[40, 50]" />
            
            <Label id="statusLabel" text="Status:" font="font:MediumSystemFont" color="#94A3B8" translation="[40, 90]" />
            <Label id="statusValue" text="Active" font="font:MediumBoldSystemFont" color="#22C55E" translation="[40, 120]" />
            
            <Label id="expiryLabel" text="Expires:" font="font:MediumSystemFont" color="#94A3B8" translation="[600, 20]" />
            <Label id="expiryValue" text="Nov 28, 2026" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[600, 50]" />
            
            <Label id="playlistCountLabel" text="Playlists:" font="font:MediumSystemFont" color="#94A3B8" translation="[600, 90]" />
            <Label id="playlistCountValue" text="0 / 5" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[600, 120]" />
        </Group>
        
        <!-- Actions -->
        <Button id="refreshBtn" translation="[40, 560]" width="200" height="60">
            <Label text="Refresh" font="font:MediumSystemFont" />
        </Button>
        
        <Button id="activateBtn" translation="[260, 560]" width="200" height="60">
            <Label text="Activate" font="font:MediumSystemFont" />
        </Button>
        
        <Button id="backBtn" translation="[1700, 40]" width="180" height="50">
            <Label text="Back" font="font:MediumSystemFont" />
        </Button>
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.deviceIdentity = invalid
        m.top.entitlement = invalid
        m.top.onRefresh = ""
        m.top.onBack = ""
        m.macValue = m.top.findNode("macValue")
        m.keyValue = m.top.findNode("keyValue")
        m.platformValue = m.top.findNode("platformValue")
        m.planValue = m.top.findNode("planValue")
        m.statusValue = m.top.findNode("statusValue")
        m.expiryValue = m.top.findNode("expiryValue")
        m.playlistCountValue = m.top.findNode("playlistCountValue")
    end sub

    sub setDeviceInfo(identity as object, entitlement as object)
        m.top.deviceIdentity = identity
        m.top.entitlement = entitlement
        
        ' Update UI
        m.macValue.text = identity.mac ? identity.mac : "Generating..."
        m.keyValue.text = identity.key6 ? identity.key6 : "Generating..."
        m.platformValue.text = "Roku"
        m.planValue.text = entitlement.plan ? entitlement.plan : "TRIAL"
        m.statusValue.text = entitlement.status ? entitlement.status : "trial"
        m.expiryValue.text = formatExpirationDate(entitlement.expiresAt ? entitlement.expiresAt : "")
        m.playlistCountValue.text = (entitlement.playlistCount ? entitlement.playlistCount : 0) + " / 5"
    end sub

    sub refresh()
        m.top.onRefresh = true
    end sub

    sub formatExpirationDate(expiresAt as string) as string
        if expiresAt = ""
            return "Never"
        end if
        
        dt = createObject("roDateTime")
        dt.fromISO8601String(expiresAt)
        
        if dt.isValid()
            monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            month = monthNames[dt.getMonth() - 1]
            day = dt.getDayOfMonth().toStr()
            year = dt.getYear().toStr()
            return month + " " + day + ", " + year
        end if
        
        return expiresAt
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **init()**: Initialize UI fields
- **setDeviceInfo()**: Receive device identity and entitlement from parent, update UI
- **refresh()**: Trigger entitlement refresh
- **formatExpirationDate()**: Format ISO date for display

---

## Page 10: Expiry Lock Screen

### Purpose
Full-screen activation lock shown when trial/license expired. Displays MAC, key, QR code, and support info.

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="ExpiryLockScreen" extends="Group">
    <interface>
        <field id="entitlement" type="assocarray" value="" />
        <field id="isLoading" type="boolean" value="false" />
        <field id="onRefresh" type="string" value="" />
        <field id="onActivate" type="string" value="" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        
        <Group id="lockCard" translation="[480, 180]" width="960" height="720">
            <Rectangle width="960" height="720" color="#1A1A2E" />
            
            <!-- Badge -->
            <Rectangle id="badge" translation="[360, 40]" width="240" height="40" color="#EF4444" opacity="0.15" />
            <Label id="badgeText" text="SUBSCRIPTION EXPIRED" font="font:SmallBoldSystemFont" color="#F87171" translation="[380, 48]" />
            
            <!-- Title -->
            <Label id="titleLabel" text="Your 7-day free trial has expired" width="800" font="font:LargeBoldSystemFont" color="#FFFFFF" translation="[80, 120]" wrap="true" />
            
            <Label id="descLabel" text="Please activate your device to continue" width="800" font="font:MediumSystemFont" color="#94A3B8" translation="[80, 170]" wrap="true" />
            
            <!-- MAC + Key -->
            <Group id="credGroup" translation="[80, 220]" width="800" height="200">
                <Group id="macGroup" translation="[0, 0]" width="380" height="100">
                    <Label text="MAC Address" font="font:SmallBoldSystemFont" color="#94A3B8" translation="[0, 0]" />
                    <Rectangle width="380" height="50" color="#0F172A" translation="[0, 30]" />
                    <Label id="macDisplay" font="font:MediumBoldSystemFont" color="#E2E8F0" translation="[20, 38]" />
                    <Button id="copyMacBtn" translation="[330, 35]" width="40" height="40">
                        <Icon source="content_copy" />
                    </Button>
                </Group>
                
                <Group id="keyGroup" translation="[420, 0]" width="380" height="100">
                    <Label text="Device Key" font="font:SmallBoldSystemFont" color="#94A3B8" translation="[0, 0]" />
                    <Rectangle width="380" height="50" color="#0F172A" translation="[0, 30]" />
                    <Label id="keyDisplay" font="font:MediumBoldSystemFont" color="#38BDF8" translation="[20, 38]" />
                    <Button id="copyKeyBtn" translation="[330, 35]" width="40" height="40">
                        <Icon source="content_copy" />
                    </Button>
                </Group>
            </Group>
            
            <!-- QR Code -->
            <ImageCanvas id="qrCanvas" translation="[340, 340]" width="280" height="280" />
            
            <!-- Portal Link -->
            <Label id="portalLink" text="Or visit: yestream.ai.studio" font="font:SmallSystemFont" color="#38BDF8" translation="[280, 640]" wrap="true" />
            
            <!-- Actions -->
            <Button id="refreshBtn" translation="[360, 680]" width="240" height="48">
                <Label text="Refresh Status" font="font:MediumBoldSystemFont" />
            </Button>
            
            <!-- Notice -->
            <Group id="noticeGroup" translation="[80, 580]" width="800" height="60" visible="false">
                <Rectangle width="800" height="50" color="#F59E0B" opacity="0.15" />
                <Label id="noticeText" font="font:SmallSystemFont" color="#FBBF24" translation="[10, 10]" />
            </Group>
        </Group>
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.entitlement = invalid
        m.top.isLoading = false
        m.top.onRefresh = ""
        m.top.onActivate = ""
        m.qrCanvas = m.top.findNode("qrCanvas")
        m.noticeGroup = m.top.findNode("noticeGroup")
        m.noticeText = m.top.findNode("noticeText")
        m.macDisplay = m.top.findNode("macDisplay")
        m.keyDisplay = m.top.findNode("keyDisplay")
    end sub

    sub onKeyDown(key as Integer)
        if key = 13 ' OK/Enter
            refreshStatus()
        end if
    end sub

    sub setEntitlement(entitlement as object)
        m.top.entitlement = entitlement
        m.macDisplay.text = entitlement.mac ? entitlement.mac : "Generating..."
        m.keyDisplay.text = entitlement.key6 ? entitlement.key6 : "Generating..."
        
        if entitlement.mac and entitlement.key6
            url = "https://yestream.ai.studio/activate?mac=" + urlEncode(entitlement.mac) + "&key=" + urlEncode(entitlement.key6)
            renderQrCode(m.qrCanvas, url, 340, 340, 280, 280)
        end if
    end sub

    sub refreshStatus()
        m.top.isLoading = true
        m.top.onRefresh = true
    end sub

    sub renderQrCode(canvas as object, url as string, x as integer, y as integer, width as integer, height as integer)
        ' Draw QR code matrix on canvas
        matrix = generateQrMatrix(url)
        size = matrix[0].count()
        moduleSize = width / size
        
        canvas.clear()
        
        for row = 0 to size - 1
            for col = 0 to size - 1
                if matrix[row][col]
                    canvas.fillRect(col * moduleSize, row * moduleSize, moduleSize, moduleSize, "#000000")
                else
                    canvas.fillRect(col * moduleSize, row * moduleSize, moduleSize, moduleSize, "#FFFFFF")
                end if
            end for
        end for
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **init()**: Initialize UI fields and QR canvas
- **setEntitlement()**: Display MAC, key, and generate QR code
- **refreshStatus()**: Trigger entitlement refresh
- **renderQrCode()**: Draw QR code matrix on ImageCanvas

---

## Page 11: QR Code Activation Screen

### Purpose
Dedicated QR code screen for phone activation with copy buttons.

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="QRCodeScreen" extends="Group">
    <interface>
        <field id="macAddress" type="string" value="" />
        <field id="deviceKey" type="string" value="" />
        <field id="portalUrl" type="string" value="" />
        <field id="activationUrl" type="string" value="" />
        <field id="onCopyMac" type="string" value="" />
        <field id="onCopyKey" type="string" value="" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        
        <Label id="titleLabel" text="Device Activation" font="font:LargeBoldSystemFont" color="#FFFFFF" translation="[40, 40]" />
        
        <Group id="infoGroup" translation="[40, 100]" width="1840" height="200">
            <Rectangle width="1840" height="200" color="#1A1A2E" />
            
            <Label text="MAC Address:" font="font:MediumSystemFont" color="#94A3B8" translation="[40, 20]" />
            <Label id="macValue" font="font:MediumBoldSystemFont" color="#FFFFFF" translation="[40, 50]" />
            <Button id="copyMacBtn" translation="[1400, 20]" width="200" height="50">
                <Label text="Copy" font="font:SmallSystemFont" />
            </Button>
            
            <Label text="Device Key:" font="font:MediumSystemFont" color="#94A3B8" translation="[40, 90]" />
            <Label id="keyValue" font="font:MediumBoldSystemFont" color="#38BDF8" translation="[40, 120]" />
            <Button id="copyKeyBtn" translation="[1400, 90]" width="200" height="50">
                <Label text="Copy" font="font:SmallSystemFont" />
            </Button>
        </Group>
        
        <ImageCanvas id="qrCanvas" translation="[760, 340]" width="400" height="400" />
        
        <Label id="portalLabel" text="Visit: yestream.ai.studio/activate" font="font:MediumSystemFont" color="#FFFFFF" translation="[760, 760]" />
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.macAddress = ""
        m.top.deviceKey = ""
        m.top.portalUrl = ""
        m.top.onCopyMac = ""
        m.top.onCopyKey = ""
        m.qrCanvas = m.top.findNode("qrCanvas")
        m.macValue = m.top.findNode("macValue")
        m.keyValue = m.top.findNode("keyValue")
    end sub

    sub setActivationInfo(mac as string, key as string)
        m.top.macAddress = mac
        m.top.deviceKey = key
        m.macValue.text = mac
        m.keyValue.text = key
        
        url = "https://yestream.ai.studio/activate?mac=" + urlEncode(mac) + "&key=" + urlEncode(key)
        renderQrCode(m.qrCanvas, url, 760, 340, 400, 400)
    end sub

    sub onKeyDown(key as Integer)
        if key = 283 ' Back
            m.top.onBack = true
        end if
    end sub

    sub renderQrCode(canvas as object, url as string, x as integer, y as integer, width as integer, height as integer)
        matrix = generateQrMatrix(url)
        size = matrix[0].count()
        moduleSize = width / size
        
        canvas.clear()
        
        for row = 0 to size - 1
            for col = 0 to size - 1
                if matrix[row][col]
                    canvas.fillRect(col * moduleSize, row * moduleSize, moduleSize, moduleSize, "#000000")
                else
                    canvas.fillRect(col * moduleSize, row * moduleSize, moduleSize, moduleSize, "#FFFFFF")
                end if
            end for
        end for
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **init()**: Initialize UI fields
- **setActivationInfo()**: Set MAC/key and render QR code
- **renderQrCode()**: Draw QR code matrix

---

## Page 12: Settings Screen

### Purpose
Application settings including connectivity, parental lock, and about.

### UI Layout (XML)
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<component name="SettingsScreen" extends="Group">
    <interface>
        <field id="onBack" type="string" value="" />
    </interface>

    <children>
        <Rectangle width="1920" height="1080" color="#0A0A0A" />
        
        <Label id="headerTitle" text="Settings" font="font:LargeBoldSystemFont" color="#FFFFFF" translation="[40, 40]" />
        
        <List id="settingsList" translation="[40, 120]" width="1840" height="800" itemSize="[1840, 80]" />
        
        <Button id="backBtn" translation="[1700, 40]" width="180" height="50">
            <Label text="Back" font="font:MediumSystemFont" />
        </Button>
    </children>

    <script type="text/brightscript">
    <![CDATA[
    sub init()
        m.top.onBack = ""
        m.settingsList = m.top.findNode("settingsList")
        
        settings = []
        settings.append({title: "Connectivity", description: "Network settings"})
        settings.append({title: "Parental Lock", description: "Set PIN for content restrictions"})
        settings.append({title: "About", description: "Version info and support"})
        settings.append({title: "Logout", description: "Sign out of account"})
        
        m.settingsList.content = createObject("roSGNode", "ContentNode")
        m.settingsList.content.append(settings)
    end sub

    sub onSettingsSelected(settingTitle as string)
        select case settingTitle
            case "Connectivity"
                m.top.onBack = "connectivity"
            case "Parental Lock"
                m.top.onBack = "parentalLock"
            case "About"
                m.top.onBack = "about"
            case "Logout"
                m.top.onBack = "logout"
        end select
    end sub
    ]]>
    </script>
</component>
```

### BrightScript Logic
- **init()**: Populate settings list
- **onSettingsSelected()**: Handle settings menu selection

---

## Data Models

### Device Identity
```typescript
{
    deviceId: string,        // Unique device identifier
    mac: string,             // MAC address (02:XX:XX:XX:XX:XX format)
    key6: string,            // 6-digit activation key
    credential: string,      // Bearer token from backend
    hardwareFingerprint: string,  // SHA-256 hash of hardware ID
    platform: string,        // "Roku"
    model: string,           // Roku model name
    os: string,              // Roku OS version
    appVersion: string       // App version (0.1.0)
}
```

### Entitlement
```typescript
{
    deviceId: string,
    mac: string,
    status: string,          // "trial", "active", "expired", "suspended", "decommissioned"
    plan: string,            // "TRIAL", "ACTIVE", "FOREVER", "LIFETIME"
    trialDays: number,       // Trial days remaining
    trialEndsAt: string | null,  // ISO 8601 datetime
    expiresAt: string | null,    // ISO 8601 datetime
    licenseEpoch: number,
    issuedAt: string,
    offlineLeaseSignature: string,
    serverTime: string
}
```

### Playlist
```typescript
{
    id: string,              // Server playlist ID
    localId: string,         // Local playlist ID
    name: string,
    type: "m3u" | "xtream",  // Playlist type
    url?: string,            // M3U URL
    host?: string,           // Xtream host
    username?: string,       // Xtream username
    password?: string,       // Xtream password
    ownerType: string,       // "customer" | "reseller"
    lockedByReseller: boolean,
    version: number
}
```

### Channel
```typescript
{
    id: string,
    name: string,
    streamUrl: string,
    thumbnail?: string,
    category?: string,
    epgChannelId?: string
}
```

### Program (EPG)
```typescript
{
    id: string,
    channelId: string,
    title: string,
    description: string,
    start: string,           // ISO 8601 datetime
    stop: string,            // ISO 8601 datetime
    category: string
}
```

---

## API Integration Details

### Endpoints Used

| Endpoint | Method | Purpose | Auth Required |
|----------|--------|---------|---------------|
| `/api/v1/devices/register` | POST | Device registration | No (first time) / Yes (re-register) |
| `/api/v1/device/entitlement` | GET | Check license status | Yes (Bearer token) |
| `/api/v1/device/sync` | GET | Sync playlists | Yes (Bearer token) |
| `/api/v1/device/configuration` | GET | Get configuration | Yes (Bearer token) |
| `/api/v1/device/playlists` | POST | Create/update playlist | Yes (Bearer token) |
| `/api/v1/device/playlists/:id` | DELETE | Delete playlist | Yes (Bearer token) |
| `/api/v1/device/events` | GET | SSE stream (not implemented) | Yes (Bearer token) |
| `/api/v1/device/heartbeat` | POST | Heartbeat | Yes (Bearer token) |

### Authentication Flow
1. App launches → `registerDevice()` called
2. Backend returns `credential` (devsec_...)
3. Credential stored in `roRegistrySection`
4. All subsequent API calls include `Authorization: Bearer <credential>`
5. On 401, re-register device

### Example Registration Payload
```json
{
    "mac": "02:A4:3F:91:C0:18",
    "hardwareFingerprint": "8f91c0...64hex",
    "credential": null,
    "platform": "Roku",
    "model": "Roku Ultra 4800",
    "os": "Roku OS 12.0",
    "appVersion": "0.1.0"
}
```

---

## Remote Control Mapping

| Key | Key Code | Action |
|-----|----------|--------|
| OK/Enter | 13 | Select item / Play/Pause |
| Back | 283 | Go back / Exit |
| Play/Pause | 285 | Toggle playback |
| Rewind | 286 | Rewind |
| Fast Forward | 287 | Fast forward |
| Up | 1 | Navigate up |
| Down | 2 | Navigate down |
| Left | 3 | Navigate left |
| Right | 4 | Navigate right |
| Home | 28 | Go to home |
| Info | 290 | Show info |
| Replay | 289 | Replay |
| Skip | 288 | Skip |

---

## Styling & Theme

### Color Palette
| Color | Hex | Usage |
|-------|-----|-------|
| Background | `#0A0A0A` | Main background |
| Surface | `#1A1A2E` | Cards/panels |
| Text Primary | `#FFFFFF` | Main text |
| Text Secondary | `#94A3B8` | Secondary text |
| Accent | `#38BDF8` | Links/keys |
| Success | `#22C55E` | Active status |
| Error | `#F87171` | Expired/error |
| Warning | `#FBBF24` | Trial/expiring |

### Typography
- **LargeBold**: 48px, Bold (headers)
- **MediumBold**: 36px, Bold (subheaders)
- **Medium**: 28px, Medium (body)
- **Small**: 24px, Regular (labels)
- **SmallBold**: 24px, Bold (badges)

### Layout Constants
- **Screen Width**: 1920px
- **Screen Height**: 1080px
- **Sidebar Width**: 400px
- **Card Corner Radius**: 12px
- **Button Height**: 48-80px
- **Grid Item Size**: 240x180 (channels), 440x320 (movies)

---

## Screen Transition Flow

```
Splash Screen
    ↓ (auto, ~2s)
Home Dashboard
    ├──→ Live TV Screen → Player Screen
    ├──→ Movie Screen → Player Screen
    ├──→ Series Screen → Player Screen
    ├──→ EPG Grid Screen → Player Screen
    ├──→ Playlist Manager → (add/edit/delete)
    ├──→ Account Screen (read-only)
    ├──→ Settings Screen
    └──→ Search Screen
    ↓ (if expired)
Expiry Lock Screen ←→ Home Dashboard (after activation)
```

---

## Implementation Notes

### BrightScript Limitations
- No native JSON support → Custom JSON parser included (`json.brs`)
- No native SHA-256 → Pure BrightScript implementation (`sha256.brs`)
- No QR code library → Custom matrix rendering on `roImageCanvas` (`qrcode.brs`)
- Single-threaded → All HTTP calls use `roUrlTransfer` with message ports

### Performance Considerations
- Cache device identity in `roRegistrySection` to avoid re-registration
- Cache playlist data locally, sync on boot and focus
- Use pagination for large channel lists (>50 channels)
- Preload poster images asynchronously

### Testing Checklist
- [ ] Device registration creates MAC + 6-digit key
- [ ] Trial starts automatically (7 days)
- [ ] Expired state shows lock screen
- [ ] QR code renders correctly
- [ ] Play/Pause/Back remote controls work
- [ ] Live TV playback starts
- [ ] Playlist add/edit/delete syncs with backend
- [ ] Offline mode shows cached data

---

## Next Steps for Roku Development

1. **Place channel icon**: Copy `roku/images/icon.png` (290x218)
2. **Test on device**: Sideload via `curl` to Roku IP
3. **Roku Developer Account**: $25 one-time fee at developer.roku.com
4. **Submit for review**: Upload through Roku Developer Dashboard
5. **Address review feedback**: 3-10 business days review time

---

## Files Created

| File | Purpose |
|------|---------|
| `roku/manifest.manifest` | Channel manifest |
| `roku/source/main.brs` | Entry point + routing |
| `roku/source/config.brs` | API constants |
| `roku/source/device-identity.brs` | MAC + key generation |
| `roku/source/cloud-api.brs` | HTTP client |
| `roku/source/json.brs` | JSON parser/serializer |
| `roku/source/sha256.brs` | SHA-256 implementation |
| `roku/source/qrcode.brs` | QR code rendering |
| `roku/source/access-evaluation.brs` | Access evaluation logic |
| `roku/source/playlists.brs` | Playlist parsers |
| `roku/source/epg.brs` | EPG parsing |
| `roku/source/licensing.brs` | Expiry guard logic |
| `roku/components/YestreamScene.xml` | Root scene |
| `roku/components/HomeScreen.xml` | Home dashboard |
| `roku/components/LiveTVScreen.xml` | Live TV screen |
| `roku/components/PlayerScreen.xml` | Video player |
| `roku/components/MovieScreen.xml` | Movie catalog |
| `roku/components/SeriesScreen.xml` | Series catalog |
| `roku/components/EPGScreen.xml` | EPG grid |
| `roku/components/PlaylistManager.xml` | Playlist management |
| `roku/components/AccountScreen.xml` | Account info |
| `roku/components/ExpiryLockScreen.xml` | Activation lock |
| `roku/components/SearchScreen.xml` | Search screen |
| `roku/README.md` | Documentation |
| `.github/workflows/build-roku.yml` | CI/CD workflow |
| `store/roku/metadata/en-US/*.txt` | Store listing metadata |
| `roku/images/icon.png` | Channel icon (place your logo here) |