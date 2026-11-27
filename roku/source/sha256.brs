function sha256(message as string) as string
    bytes = CreateObject("roByteArray")
    bytes.FromAsciiString(message)
    digest = CreateObject("roEVPDigest")
    digest.Setup("sha256")
    return digest.Process(bytes)
end function
