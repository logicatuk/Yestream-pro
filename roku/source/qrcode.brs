function portalLogin(mac as string, deviceKey as string) as string
    cfg = getYestreamConfig()
    return cfg.origin + "/customer/login?mac=" + mac.EncodeUriComponent() + "&key=" + deviceKey.EncodeUriComponent() + "&redirect=/me/playlists"
end function

function bitXor(a as integer, b as integer) as integer
    return (a or b) - (a and b)
end function

function qrProduct(a as integer, b as integer) as integer
    product = 0
    while b > 0
        if (b and 1) = 1 then product = bitXor(product, a)
        b = int(b / 2)
        a = a * 2
        if a >= 256 then a = bitXor(a, 285)
    end while
    return product
end function

' Version 8-L byte mode: two 97-byte data blocks with 24 parity bytes each.
function qrBits(url as string, polynomial as object) as string
    count = len(url)
    data = [64 + int(count / 16)]
    carry = (count mod 16) * 16
    for i = 1 to count
        octet = asc(mid(url, i, 1))
        data.push(carry + int(octet / 16))
        carry = (octet mod 16) * 16
    end for
    data.push(carry)
    pad = 236
    while data.count() < 194
        data.push(pad)
        pad = 253 - pad
    end while
    parity = []
    for block = 0 to 1
        remainder = []
        for j = 0 to 23
            remainder.push(0)
        end for
        for i = 0 to 96
            lead = bitXor(data[block * 97 + i], remainder.shift())
            remainder.push(0)
            for j = 0 to 23
                remainder[j] = bitXor(remainder[j], qrProduct(lead, polynomial[j]))
            end for
        end for
        parity.push(remainder)
    end for
    bits = ""
    for i = 0 to 120
        for block = 0 to 1
            if i < 97
                octet = data[block * 97 + i]
            else
                octet = parity[block][i - 97]
            end if
            mask = 128
            while mask >= 1
                if (octet and mask) <> 0 then bits += "1" else bits += "0"
                mask = int(mask / 2)
            end while
        end for
    end for
    return bits
end function

sub drawPortalQr(group as object, url as string, scale as integer)
    group.removeChildrenIndex(group.getChildCount(), 0)
    if len(url) > 192 then return
    layout = ParseJson(ReadAsciiFile("pkg:/source/qr-layout.json"))
    bits = qrBits(url, layout.polynomial)
    matrix = []
    for each line in layout.rows
        row = []
        for i = 1 to 49
            row.push(mid(line, i, 1))
        end for
        matrix.push(row)
    end for
    col = 48
    upward = true
    index = 1
    while col > 0
        if col = 6 then col--
        for i = 0 to 48
            y = i
            if upward then y = 48 - i
            for x = col to col - 1 step -1
                if matrix[y][x] = "."
                    dark = mid(bits, index, 1) = "1"
                    if (x + y) mod 2 = 0 then dark = not dark
                    matrix[y][x] = "0"
                    if dark then matrix[y][x] = "1"
                    index++
                end if
            end for
        end for
        upward = not upward
        col -= 2
    end while
    bg = group.createChild("Rectangle")
    bg.width = 57 * scale
    bg.height = bg.width
    bg.color = "0xFFFFFFFF"
    for y = 0 to 48
        x = 0
        while x < 49
            startX = x
            while x < 49 and matrix[y][x] = "1"
                x++
            end while
            if x > startX
                rect = group.createChild("Rectangle")
                rect.translation = [(4 + startX) * scale, (4 + y) * scale]
                rect.width = (x - startX) * scale
                rect.height = scale
                rect.color = "0x000000FF"
            else
                x++
            end if
        end while
    end for
end sub
