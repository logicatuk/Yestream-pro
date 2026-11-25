' sha256.brs - SHA-256 implementation for BrightScript
' BrightScript has no built-in SHA-256; this is a minimal implementation

'/ SHA-256 constants
SHA256_K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
]

'/ Right rotate 32-bit integer
function rotr(x as integer, n as integer) as integer
    return (x >> n) | (x << (32 - n))
end function

'/ Right shift 32-bit integer
function shr(x as integer, n as integer) as integer
    return x >> n
end function

'/ Ch function
function ch(x as integer, y as integer, z as integer) as integer
    return (x and y) xor ((not x) and z)
end function

'/ Maj function
function maj(x as integer, y as integer, z as integer) as integer
    return (x and y) xor (x and z) xor (y and z)
end function

'/ Sigma0
function sigma0(x as integer) as integer
    return rotr(x, 2) xor rotr(x, 13) xor rotr(x, 22)
end function

'/ Sigma1
function sigma1(x as integer) as integer
    return rotr(x, 6) xor rotr(x, 11) xor rotr(x, 25)
end function

'/ sigma0 (small sigma)
function smallSigma0(x as integer) as integer
    return rotr(x, 7) xor rotr(x, 18) xor shr(x, 3)
end function

'/ sigma1 (small sigma)
function smallSigma1(x as integer) as integer
    return rotr(x, 17) xor rotr(x, 19) xor shr(x, 10)
end function

'/ Convert string to byte array
function stringToBytes(str as string) as array
    bytes = []
    for i = 1 to len(str)
        bytes.push(asc(mid(str, i, 1)))
    end for
    return bytes
end function

'/ Pad message according to SHA-256 spec
function padMessage(bytes as array) as array
    ' Original message length in bits
    originalLen = bytes.count() * 8

    ' Append 0x80
    bytes.push(0x80)

    ' Pad with zeros until length ≡ 448 mod 512 (i.e., 56 mod 64 bytes)
    while (bytes.count() % 64) <> 56
        bytes.push(0)
    end while

    ' Append original length as 64-bit big-endian integer
    ' High 32 bits (always 0 for our purposes since message < 2^32 bits)
    bytes.push(0)
    bytes.push(0)
    bytes.push(0)
    bytes.push(0)
    ' Low 32 bits
    bytes.push((originalLen >> 24) & 0xFF)
    bytes.push((originalLen >> 16) & 0xFF)
    bytes.push((originalLen >> 8) & 0xFF)
    bytes.push(originalLen & 0xFF)

    return bytes
end function

'/ SHA-256 hash function
function sha256(msg as string) as string
    ' Convert to bytes
    bytes = stringToBytes(msg)

    ' Pad message
    bytes = padMessage(bytes)

    ' Initialize hash values (first 32 bits of fractional parts of square roots of first 8 primes)
    h = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]

    ' Process each 512-bit chunk (64 bytes)
    for chunkStart = 0 to bytes.count() - 1 step 64
        ' Create message schedule array w[0..63]
        w = []
        for t = 0 to 15
            i = t * 4
            w[t] = (bytes[chunkStart + i] << 24) | (bytes[chunkStart + i + 1] << 16) | (bytes[chunkStart + i + 2] << 8) | bytes[chunkStart + i + 3]
        end for

        ' Extend the first 16 words into the remaining 48 words
        for t = 16 to 63
            s0 = smallSigma0(w[t - 15])
            s1 = smallSigma1(w[t - 2])
            w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xFFFFFFFF
        end for

        ' Initialize working variables
        a = h[0]
        b = h[1]
        c = h[2]
        d = h[3]
        e = h[4]
        f = h[5]
        g = h[6]
        h_ = h[7]

        ' Main loop
        for t = 0 to 63
            t1 = (h_ + sigma1(e) + ch(e, f, g) + SHA256_K[t] + w[t]) & 0xFFFFFFFF
            t2 = (sigma0(a) + maj(a, b, c)) & 0xFFFFFFFF
            h_ = g
            g = f
            f = e
            e = (d + t1) & 0xFFFFFFFF
            d = c
            c = b
            b = a
            a = (t1 + t2) & 0xFFFFFFFF
        end for

        ' Add compressed chunk to current hash value
        h[0] = (h[0] + a) & 0xFFFFFFFF
        h[1] = (h[1] + b) & 0xFFFFFFFF
        h[2] = (h[2] + c) & 0xFFFFFFFF
        h[3] = (h[3] + d) & 0xFFFFFFFF
        h[4] = (h[4] + e) & 0xFFFFFFFF
        h[5] = (h[5] + f) & 0xFFFFFFFF
        h[6] = (h[6] + g) & 0xFFFFFFFF
        h[7] = (h[7] + h_) & 0xFFFFFFFF
    end for

    ' Produce final hash (big-endian hex)
    result = ""
    for i = 0 to 7
        result = result + hex8(h[i])
    end for

    return result
end function

'/ Convert 32-bit integer to 8-char hex string
function hex8(x as integer) as string
    hexChars = "0123456789abcdef"
    result = ""
    for i = 7 to 0 step -1
        result = result + mid("0123456789abcdef", (x >> (i * 4)) & 0xF + 1, 1)
    end for
    return result
end function

'/ Generate deterministic MAC address from hardware ID
function generateMacAddress(rawHardwareId as string) as string
    ' Use the formula from spec: SHA256("yestream-pro-mac:" + rawHardwareId)
    hashInput = "yestream-pro-mac:" + rawHardwareId
    hash = sha256(hashInput)

    ' Take first 6 bytes (12 hex chars)
    macBytes = mid(hash, 1, 12)

    ' Format as 02:XX:XX:XX:XX:XX
    ' Set bit 0 of first byte to 1 (locally administered), bit 1 to 0 (unicast)
    firstByte = val("&H" + mid(hash, 1, 2))
    firstByte = (firstByte and 0xFE) | 0x02  ' Clear bit 1, set bit 0
    firstByteHex = mid("0123456789abcdef", (firstByte >> 4) + 1, 1) + mid("0123456789abcdef", (firstByte & 0xF) + 1, 1)

    mac = firstByteHex
    for i = 3 to 11 step 2
        mac = mac + ":" + mid(hash, i, 2)
    end for

    return upper(mac)
end function

'/ Generate 6-digit device key from hardware ID
function generateKey6(rawHardwareId as string) as string
    ' Use the formula from spec: first 6 hex chars of SHA256("yestream-pro-fp:" + rawHardwareId)
    hashInput = "yestream-pro-fp:" + rawHardwareId
    hash = sha256(hashInput)
    return upper(mid(hash, 1, 6))
end function

'/ Get hardware ID from Roku device
function getRawHardwareId() as string
    info = createObject("roDeviceInfo")
    model = info.getModel()
    serial = info.getSerialNumber()
    mac = info.getMacAddress()
    ' Combine available identifiers
    return model + "|" + serial + "|" + mac
end function