' qrcode.brs - QR code rendering for Roku using roImageCanvas

'/ Generate QR code matrix from a URL string
' Returns a 2D array of booleans (true = dark module)
function generateQrMatrix(text as string) as array
    ' Simplified QR generation - in production use a full QR encoder
    ' This creates a placeholder pattern that resembles a QR code

    size = 25 ' QR version 2 size (25x25 modules)
    matrix = []

    ' Initialize matrix with false
    for row = 0 to size - 1
        matrix[row] = []
        for col = 0 to size - 1
            matrix[row][col] = false
        end for
    end for

    ' Add finder patterns (top-left, top-right, bottom-left)
    ' Top-left
    for row = 0 to 6
        for col = 0 to 6
            if (row = 0 or row = 6 or col = 0 or col = 6) or (row >= 2 and row <= 4 and col >= 2 and col <= 4)
                matrix[row][col] = true
            end if
        end for
    end for

    ' Top-right
    for row = 0 to 6
        for col = size - 7 to size - 1
            localRow = row
            localCol = col - (size - 7)
            if (localRow = 0 or localRow = 6 or localCol = 0 or localCol = 6) or (localRow >= 2 and localRow <= 4 and localCol >= 2 and localCol <= 4)
                matrix[row][col] = true
            end if
        end for
    end for

    ' Bottom-left
    for row = size - 7 to size - 1
        for col = 0 to 6
            localRow = row - (size - 7)
            localCol = col
            if (localRow = 0 or localRow = 6 or localCol = 0 or localCol = 6) or (localRow >= 2 and localRow <= 4 and localCol >= 2 and localCol <= 4)
                matrix[row][col] = true
            end if
        end for
    end for

    ' Add timing patterns
    for i = 8 to size - 9
        matrix[6][i] = (i mod 2 = 0)
        matrix[i][6] = (i mod 2 = 0)
    end for

    ' Fill data area with pseudo-random pattern based on text
    seed = 0
    for i = 1 to len(text)
        seed = (seed * 31 + asc(mid(text, i, 1))) & 0xFFFFFFFF
    end for

    for row = 9 to size - 9
        for col = 9 to size - 9
            ' Skip timing pattern areas
            if row <> 6 and col <> 6
                seed = (seed * 1103515245 + 12345) & 0xFFFFFFFF
                matrix[row][col] = (seed & 0x10000) <> 0
            end if
        end for
    end for

    return matrix
end function

'/ Render QR code to an roImageCanvas
function renderQrCode(canvas as object, text as string, x as integer, y as integer, moduleSize as integer, darkColor as string, lightColor as string)
    if canvas = invalid or text = ""
        return
    end if

    matrix = generateQrMatrix(text)
    size = matrix[0].count()

    ' Calculate total dimensions
    totalSize = size * moduleSize

    ' Clear the canvas area first
    canvas.clear()

    ' Draw each module
    for row = 0 to size - 1
        for col = 0 to size - 1
            if matrix[row][col]
                ' Draw dark module
                canvas.fillRect(col * moduleSize, row * moduleSize, moduleSize, moduleSize, darkColor)
            else
                ' Draw light module
                canvas.fillRect(col * moduleSize, row * moduleSize, moduleSize, moduleSize, lightColor)
            end if
        end for
    end for
end function

'/ Create a QR code image canvas node
function createQrCodeCanvas(width as integer, height as integer) as object
    canvas = createObject("roSGNode", "ImageCanvas")
    canvas.width = width
    canvas.height = height
    canvas.translation = [0, 0]

    ' Set background
    canvas.setBackgroundColor("#FFFFFF")

    return canvas
end function

'/ Generate activation URL for QR code
function buildActivationUrl(mac as string, key6 as string) as string
    ' URL format: https://yestream.ai.studio/activate?mac=<MAC>&key=<KEY6>
    return "https://yestream.ai.studio/activate?mac=" + urlEncode(mac) + "&key=" + urlEncode(key6)
end function

'/ Generate portal login URL for QR code
function buildPortalLoginUrl(mac as string, key6 as string) as string
    ' URL format: https://yestream.ai.studio/customer/login?mac=<MAC>&key=<KEY6>&redirect=/me/playlists
    return "https://yestream.ai.studio/customer/login?mac=" + urlEncode(mac) + "&key=" + urlEncode(key6) + "&redirect=/me/playlists"
end function

'/ URL encode a string
function urlEncode(str as string) as string
    result = ""
    hexChars = "0123456789ABCDEF"

    for i = 1 to len(str)
        char = mid(str, i, 1)
        code = asc(char)

        ' Unreserved characters: A-Z a-z 0-9 - _ . ~
        if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or char = "-" or char = "_" or char = "." or char = "~"
            result = result + char
        else
            ' Percent-encode
            result = result + "%"
            result = result + mid(hexChars, ((code >> 4) & 0xF) + 1, 1)
            result = result + mid(hexChars, (code & 0xF) + 1, 1)
        end if
    end for

    return result
end function