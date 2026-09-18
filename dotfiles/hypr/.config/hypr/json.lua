-- Singularity - Hyprland
-- ~/.config/hypr/json.lua
--
-- JSON decoder for hyprland.lua, which reads window-rules.json with it.
-- Hyprland's Lua has no JSON library, hence this. It covers the whole of
-- JSON except null inside arrays, which the Window Rules page never writes.
-- Returns nil for text that doesn't parse rather than raising, so a bad file
-- can never take the rest of the config down with it.
--
-- Its own file so it can be run outside Hyprland:
--   lua -e 'print(dofile("json.lua")(io.read("a"))[1].class)' < window-rules.json

return function(s)
    local i = 1
    local function skip() i = s:find("[^ \t\r\n]", i) or #s + 1 end
    local function str()
        local out, j = {}, i + 1
        while true do
            local c = s:sub(j, j)
            if c == "" then error("unterminated string") end
            if c == '"' then i = j + 1; return table.concat(out) end
            if c == "\\" then
                local e = s:sub(j + 1, j + 1)
                if e == "u" then
                    out[#out + 1] = utf8.char(tonumber(s:sub(j + 2, j + 5), 16))
                    j = j + 6
                else
                    out[#out + 1] = ({ b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" })[e] or e
                    j = j + 2
                end
            else
                out[#out + 1] = c
                j = j + 1
            end
        end
    end
    local value
    local function list(close, item)
        i = i + 1
        skip()
        if s:sub(i, i) == close then i = i + 1; return end
        while true do
            item()
            skip()
            local d = s:sub(i, i)
            i = i + 1
            if d == close then return end
            if d ~= "," then error("expected , or " .. close) end
        end
    end
    function value()
        skip()
        local c = s:sub(i, i)
        if c == "{" then
            local t = {}
            list("}", function()
                skip()
                if s:sub(i, i) ~= '"' then error("expected a key") end
                local k = str()
                skip()
                if s:sub(i, i) ~= ":" then error("expected :") end
                i = i + 1
                t[k] = value()
            end)
            return t
        elseif c == "[" then
            local t = {}
            list("]", function() t[#t + 1] = value() end)
            return t
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == "true" then i = i + 4; return true
        elseif s:sub(i, i + 4) == "false" then i = i + 5; return false
        elseif s:sub(i, i + 3) == "null" then i = i + 4; return nil
        end
        local n = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
        if not n then error("unexpected character at " .. i) end
        i = i + #n
        return tonumber(n)
    end
    local ok, result = pcall(value)
    return ok and result or nil
end
