local Rules = require("rules")
local Art = {}
local ivory, red, blue, green = { .95, .91, .79 }, { .65, .12, .10 }, { .11, .24, .38 }, { .08, .34, .22 }
local patterns = {
    [2] = { {42,32}, {42,83} },
    [3] = { {23,29}, {42,57}, {61,85} },
    [4] = { {24,32}, {60,32}, {24,83}, {60,83} },
    [5] = { {24,30}, {60,30}, {42,57}, {24,85}, {60,85} },
    [6] = { {25,29}, {59,29}, {25,57}, {59,57}, {25,85}, {59,85} },
    [7] = { {24,25}, {42,38}, {60,25}, {24,66}, {60,66}, {24,91}, {60,91} },
    [8] = { {25,23}, {59,23}, {25,46}, {59,46}, {25,69}, {59,69}, {25,92}, {59,92} },
    [9] = { {22,28}, {42,28}, {62,28}, {22,58}, {42,58}, {62,58}, {22,88}, {42,88}, {62,88} },
}

local function ink(tint) love.graphics.setColor(tint) end
local function centered(font, value, y, tint)
    love.graphics.setFont(font); ink(tint)
    love.graphics.printf(value, 0, y, 84, "center")
end

local function canvas(w, h, draw)
    local target = love.graphics.newCanvas(w, h, { dpiscale = 1 })
    love.graphics.push("all")
    love.graphics.setCanvas(target); love.graphics.clear(0, 0, 0, 0)
    draw()
    love.graphics.setCanvas(); love.graphics.pop()
    -- Static images survive a graphics-context reset; Canvas contents do not.
    local image = love.graphics.newImage(target:newImageData())
    image:setFilter("linear", "linear")
    target:release()
    return image
end

local function face(kind, fonts)
    return canvas(84, 116, function()
        ink(ivory); love.graphics.rectangle("fill", 0, 0, 84, 116)
        for y = 0, 115 do
            love.graphics.setColor(1, 1, 1, .10 * (1 - y / 116))
            love.graphics.line(0, y, 84, y)
        end
        love.graphics.setColor(.62, .53, .35, .22)
        love.graphics.setLineWidth(1); love.graphics.rectangle("line", 3, 3, 78, 110, 4, 4)
        if kind > 27 then
            if kind == 32 then
                ink(blue); love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", 18, 23, 48, 69, 3, 3)
                love.graphics.setLineWidth(1); love.graphics.rectangle("line", 23, 28, 38, 59)
            else
                centered(fonts[48], kind == 33 and "發" or Rules.label(kind), 29,
                    kind == 34 and red or kind == 33 and green or blue)
            end
            return
        end
        local rank, suit = Rules.rank(kind), Rules.suit(kind)
        if suit == 1 then
            centered(fonts[48], ({ "一", "二", "三", "四", "五", "六", "七", "八", "九" })[rank], 7, blue)
            centered(fonts[32], "萬", 65, red)
        elseif suit == 2 then
            if rank == 1 then
                for radius = 25, 4, -5 do
                    ink(radius % 2 == 0 and red or blue)
                    love.graphics.setLineWidth(3); love.graphics.circle("line", 42, 58, radius)
                end
                ink(red); love.graphics.circle("fill", 42, 58, 4)
            else
                for i, point in ipairs(patterns[rank]) do
                    local tint = rank == 5 and i == 3 and red or (i % 3 == 0 and green or blue)
                    ink(tint); love.graphics.circle("fill", point[1], point[2], rank >= 8 and 7 or 9)
                    ink(ivory); love.graphics.circle("fill", point[1], point[2], rank >= 8 and 4 or 5)
                    ink(tint); love.graphics.circle("fill", point[1], point[2], 2)
                end
            end
        elseif rank == 1 then
            ink(green)
            love.graphics.ellipse("fill", 42, 61, 16, 23)
            love.graphics.circle("fill", 48, 32, 10)
            love.graphics.polygon("fill", 29,72, 18,100, 44,81)
            ink(red); love.graphics.polygon("fill", 56,30, 69,36, 56,38)
            love.graphics.setLineWidth(3); love.graphics.line(34,80, 30,96); love.graphics.line(46,81, 49,99)
            ink(ivory); love.graphics.ellipse("fill", 39, 60, 7, 13)
            ink(blue); love.graphics.circle("fill", 50, 30, 2)
        else
            for i, point in ipairs(patterns[rank]) do
                local tint = rank == 5 and i == 3 and red or green
                ink(tint); love.graphics.rectangle("fill", point[1] - 3, point[2] - 10, 6, 20, 2, 2)
                love.graphics.rectangle("fill", point[1] - 5, point[2] - 7, 10, 3, 1, 1)
                love.graphics.rectangle("fill", point[1] - 5, point[2] + 5, 10, 3, 1, 1)
                ink(ivory); love.graphics.line(point[1], point[2] - 4, point[1], point[2] + 4)
            end
        end
    end)
end

function Art.new(fonts)
    local art, rng = { faces = {} }, love.math.newRandomGenerator(7291)
    for kind = 1, 34 do art.faces[kind] = face(kind, fonts) end
    art.back = canvas(84, 116, function()
        love.graphics.clear(.08, .27, .22, 1)
        love.graphics.setColor(.30, .52, .39, .6)
        love.graphics.setLineWidth(2); love.graphics.rectangle("line", 7, 7, 70, 102, 6, 6)
        for i = -116, 84, 9 do love.graphics.line(i, 0, i + 116, 116) end
        for i = 0, 200, 9 do love.graphics.line(i, 0, i - 116, 116) end
        love.graphics.setColor(.09, .31, .24, 1); love.graphics.circle("fill", 42, 58, 19)
        centered(fonts[24], "雀", 43, { .67, .71, .47 })
    end)
    art.felt = canvas(512, 512, function()
        love.graphics.clear(.14, .30, .24, 1)
        for _ = 1, 24000 do
            love.graphics.setColor(.38, .52, .36, rng:random() * .12)
            local x, y = rng:random(512), rng:random(512)
            love.graphics.line(x, y, x + 1, y + 2)
        end
        love.graphics.setColor(.03, .09, .06, .14)
        for y = 1, 512, 3 do love.graphics.line(0, y, 512, y) end
    end)
    art.wood = canvas(512, 128, function()
        love.graphics.clear(.28, .15, .08, 1)
        for i = 1, 500 do
            local y = rng:random(128)
            love.graphics.setColor(.57, .34, .17, rng:random() * .3)
            love.graphics.line(0, y, 180, y + math.sin(i) * 2, 350, y - 1, 512, y + 2)
        end
    end)
    art.light = canvas(1280, 840, function()
        for radius = 760, 10, -10 do
            love.graphics.setColor(1, .75, .35, .0025)
            love.graphics.ellipse("fill", 650, 375, radius, radius * .65)
        end
    end)
    art.vignette = canvas(1280, 840, function()
        for i = 1, 30 do
            local alpha = .015
            love.graphics.setColor(0, 0, 0, alpha)
            love.graphics.setLineWidth(15)
            love.graphics.rectangle("line", i * 6 - 100, i * 4 - 70,
                1480 - i * 12, 980 - i * 8, 200, 200)
        end
    end)
    return art
end

return Art
