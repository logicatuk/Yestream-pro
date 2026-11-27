' config.brs - Yestream API configuration

function getYestreamConfig() as object
    return {
        origin: "https://yestream-405211835468.europe-west2.run.app",
        portalOrigin: "https://yestream.ai.studio",
        apiBase: "https://yestream-405211835468.europe-west2.run.app/api/v1",
        registerEndpoint: "https://yestream-405211835468.europe-west2.run.app/api/v1/devices/register",
        syncEndpoint: "https://yestream-405211835468.europe-west2.run.app/api/v1/device/sync",
        entitlementEndpoint: "https://yestream-405211835468.europe-west2.run.app/api/v1/device/entitlement",
        playlistsEndpoint: "https://yestream-405211835468.europe-west2.run.app/api/v1/device/playlists",
        version: "0.1.0",
        platform: "Roku",
        trialDays: 7
    }
end function
