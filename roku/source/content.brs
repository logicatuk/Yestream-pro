function valueOr(value as dynamic, fallback as dynamic) as dynamic
    if value = invalid then return fallback
    return value
end function

function buildListContent(items as object) as object
    root = CreateObject("roSGNode", "ContentNode")
    for each item in items
        child = root.createChild("ContentNode")
        child.title = valueOr(item.title, valueOr(item.name, ""))
        child.description = valueOr(item.description, valueOr(item.subtitle, ""))
        child.hdPosterUrl = valueOr(item.poster, "")
        child.addFields({ record: item })
    end for
    return root
end function
