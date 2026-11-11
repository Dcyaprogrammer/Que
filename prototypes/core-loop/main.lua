local Config, Rules, Run = require("config"), require("rules"), require("run")
local Tabletop = require("tabletop")
local scene
local W, H = 1280, 840
local ui = { screen = "setup", build = 1, seed = 1, buttons = {}, tileRects = {}, discardScroll = 0 }
local fonts, options, frames = {}, {}, 0
local palette = {
    background = { .035, .10, .10 }, panel = { .065, .16, .155 },
    ink = { .91, .92, .84 }, muted = { .56, .70, .65 }, gold = { .94, .73, .36 },
    dark = { .08, .15, .14 },
}

local function color(value) love.graphics.setColor(value) end
local function text(value, x, y, size, tint, width, align)
    love.graphics.setFont(fonts[size or 20])
    color(tint or palette.ink)
    if width then love.graphics.printf(tostring(value), x, y, width, align or "left")
    else love.graphics.print(tostring(value), x, y) end
end

local function box(x, y, w, h, tint, radius)
    color(tint or palette.panel)
    love.graphics.rectangle("fill", x, y, w, h, radius or 12, radius or 12)
end

local function coordinates(x, y)
    local width, height = love.graphics.getDimensions()
    local scale = math.min(width / W, height / H)
    return (x - (width - W * scale) / 2) / scale, (y - (height - H * scale) / 2) / scale
end

local function contains(rect, x, y)
    return Tabletop.hit(rect, x, y)
end

local function button(id, label, x, y, w, h, enabled, action, selected)
    local rect = { id = id, x = x, y = y, w = w, h = h, action = action, enabled = enabled }
    ui.buttons[#ui.buttons + 1] = rect
    local mx, my = coordinates(love.mouse.getPosition())
    local hover = enabled and contains(rect, mx, my)
    box(x, y, w, h, enabled and ((selected or hover) and palette.gold or palette.panel) or { .09, .14, .14 }, 8)
    text(label, x, y + (h - fonts[20]:getHeight()) / 2, 20,
        enabled and ((selected or hover) and palette.dark or palette.ink) or palette.muted, w, "center")
end

local function flushLog()
    local run = ui.run
    if not run then return end
    local path = options.smoke and "smoke.tsv" or "playtests.tsv"
    if not love.filesystem.getInfo(path) then
        local ok = love.filesystem.write(path,
            "time\tseed\tbuild\taction\ttile_id\tscore\ttotal\tdraws\tsettlements\tphase\twall\tyaku\tbase\tpair\tsequence\ttriplet\tyaku_mult\tfive_extra\tsequence_extra\trepeat_triplets\ttarget\tinitial_draws\tinitial_settlements\n")
        if not ok then ui.logError = true; return end
    end
    for i = (run.logged or 0) + 1, #run.events do
        local event, c, b = run.events[i], run.config, run.build
        local line = table.concat({ os.date("!%Y-%m-%dT%H:%M:%SZ"), run.seed, b.id,
            event.action, event.tile, event.score, event.total, event.draws,
            event.settlements, event.phase, event.wall, event.yaku,
            c.tileBase, c.pairBonus, c.sequenceBonus, c.tripletBonus, c.yakuMultiplier,
            b.fiveBonus or 0, b.sequenceBonus or 0, b.repeatTriplets or 0,
            c.target, c.draws, c.settlements }, "\t") .. "\n"
        local ok = love.filesystem.append(path, line)
        if not ok then ui.logError = true; return end
        run.logged = i
    end
end

local function start()
    ui.run = Run.new(Config.seeds[ui.seed], Config.builds[ui.build], Config)
    ui.screen, ui.discardScroll, ui.hoverScore, ui.hoverId = "game", 0, nil, nil
    ui.notice, ui.hoverIndex = nil, nil
    if scene then scene:reset() end
    flushLog()
end

local function act(method, ...)
    local before = {}
    for i, tile in ipairs(ui.run.hand) do before[i] = tile end
    if ui.run[method](ui.run, ...) then
        scene:onAction(method, before, ui.run, ...)
        ui.hoverScore, ui.hoverId, ui.hoverIndex = nil, nil, nil
        if method == "settle" then
            ui.notice = "上次结算 +" .. ui.run.lastResult.total
        else ui.notice = nil end
        flushLog()
    end
end

local actions = {
    draw = function() act("draw") end,
    settle = function() act("settle") end,
    menu = function() ui.screen = "setup"; scene.drag = nil end,
    retry = start,
    nextseed = function() ui.seed = ui.seed % #Config.seeds + 1; start() end,
}

local function drawSetup()
    text("QUE", 48, 36, 48, palette.gold)
    text("麻将 · 单关构筑实验", 208, 55, 24)
    text("留下什么牌，什么时候收手？", 48, 129, 32)
    text("普通手牌也能得分。胡牌须四面子一雀头，并有至少一个役。", 48, 179, 20, palette.muted)
    for i, build in ipairs(Config.builds) do
        local x, selected = 48 + (i - 1) * 404, ui.build == i
        box(x, 238, 376, 236, selected and { .13, .25, .21 } or palette.panel)
        if selected then
            color(palette.gold); love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, 238, 376, 236, 12, 12)
        end
        text(string.format("0%d", i), x + 24, 260, 16, palette.gold)
        text(build.name, x + 24, 293, 32)
        text(build.description, x + 24, 351, 20, palette.muted, 328)
        button("build" .. i, selected and "已选择" or "选择构筑", x + 24, 420, 328, 36, true,
            function() ui.build = i end, selected)
    end
    text("固定种子 / 相同顺序，对比不同构筑", 48, 514, 20)
    for i, seed in ipairs(Config.seeds) do
        button("seed" .. i, tostring(seed), 48 + (i - 1) * 150, 557, 132, 44, true,
            function() ui.seed = i end, ui.seed == i)
    end
    text(string.format("目标 %d 分   ·   %d 次换牌   ·   %d 次结算   ·   136 张牌，不回洗",
        Config.target, Config.draws, Config.settlements), 48, 637, 20, palette.muted)
    button("start", "开始这一关  →", 48, 691, 320, 58, true, start, true)
    text("点击摸牌 → 点击一张牌弃掉 → 随时结算整手牌", 403, 707, 20, palette.muted)
    text("原型参数可调 · 四种役：断幺九 / 三元牌刻子 / 对对和 / 清一色", 48, 790, 16, palette.muted)
end

local function loadFonts()
    local data
    -- shortcut: use an installed CJK font for this macOS prototype; bundle an OFL font before distribution.
    for _, path in ipairs({ "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc" }) do
        local file = io.open(path, "rb")
        if file then
            local bytes = file:read("*a"); file:close()
            local candidate = love.filesystem.newFileData(bytes, "cjk.ttc")
            local ok, font = pcall(love.graphics.newFont, candidate, 20)
            if ok and font:hasGlyphs("麻将") then data = candidate; break end
        end
    end
    assert(data, "No Chinese font found. Install a CJK font at a path listed in main.lua.")
    for _, size in ipairs({ 14, 16, 20, 24, 32, 48 }) do fonts[size] = love.graphics.newFont(data, size) end
end

function love.load(args)
    for i, value in ipairs(args) do
        if value == "--test" then options.test = true end
        if value == "--benchmark" then options.benchmark = true end
        if value == "--smoke" then options.smoke = true end
        if value == "--play" then options.play = true end
        if value == "--frames" then options.frames = assert(tonumber(args[i + 1]), "--frames requires a number") end
        if value == "--shot" then options.shot = args[i + 1] end
    end
    if options.test then
        require("tests").run()
        if options.benchmark then require("tests").benchmark() end
        love.event.quit(0)
        return
    end
    loadFonts()
    scene = Tabletop.new(fonts)
    ui.tableScene = scene
    if options.play then start() end
    print("QUE READY | save=" .. love.filesystem.getSaveDirectory())
end

function love.draw()
    if options.test then return end
    local width, height = love.graphics.getDimensions()
    local scale = math.min(width / W, height / H)
    love.graphics.clear(palette.background)
    love.graphics.push()
    love.graphics.translate((width - W * scale) / 2, (height - H * scale) / 2)
    love.graphics.scale(scale)
    ui.buttons, ui.tileRects = {}, {}
    if ui.screen == "setup" then drawSetup() else scene:draw(ui, actions) end
    love.graphics.pop()
end

function love.mousepressed(x, y, mouseButton)
    if mouseButton ~= 1 then return end
    x, y = coordinates(x, y)
    if ui.screen == "game" and scene:press(ui, x, y) then return end
    for i = #ui.buttons, 1, -1 do
        local rect = ui.buttons[i]
        if rect.enabled and contains(rect, x, y) then rect.action(); return end
    end
end

function love.mousereleased(x, y, mouseButton)
    if ui.screen ~= "game" then return end
    x, y = coordinates(x, y)
    if mouseButton == 1 then
        scene:release(ui, x, y, function(index) act("discard", index) end)
    elseif mouseButton == 2 then scene:escape() end
end

function love.mousemoved(x, y)
    if ui.screen ~= "game" then return end
    x, y = coordinates(x, y)
    scene:move(x, y)
    if scene.detail or scene.archive then return end
    local index
    if scene.drag then index = scene.drag.index
    else
        for i = #ui.tileRects, 1, -1 do
            if contains(ui.tileRects[i], x, y) then index = ui.tileRects[i].index; break end
        end
    end
    ui.hoverIndex = index
    local id = index and ui.run.hand[index].id
    if id == ui.hoverId and (ui.run.phase ~= "discard" or ui.hoverScore ~= nil) then return end
    ui.hoverId, ui.hoverScore = id, nil
    if index and ui.run.phase == "discard" then
        local hand = {}
        for i, tile in ipairs(ui.run.hand) do if i ~= index then hand[#hand + 1] = tile end end
        ui.hoverScore = Rules.score(hand, ui.run.build, Config)
    end
end

function love.wheelmoved(_, y)
    if ui.screen ~= "game" then return end
    local mx, my = coordinates(love.mouse.getPosition())
    if scene.archive and mx >= 823 and mx <= 1233 and my >= 230 and my <= 684 then
        ui.discardScroll = math.max(0, math.min(ui.maxScroll or 0, ui.discardScroll - y * 38))
    end
end

function love.keypressed(key, _, isRepeat)
    if isRepeat then return end
    if key == "m" and scene then scene.feedback:mute(); return end
    if key == "v" and scene then scene.feedback:reduce(); return end
    if key == "escape" then
        if ui.screen == "game" and scene:escape() then return end
        ui.screen = "setup"
    elseif ui.screen == "game" and (scene.detail or scene.archive) then return
    elseif ui.screen == "setup" then
        if key == "return" then start() end
    elseif key == "space" then act("draw")
    elseif key == "return" then act("settle")
    elseif key == "r" and (ui.run.phase == "won" or ui.run.phase == "lost") then start() end
end

function love.update(dt)
    if options.test then return end
    frames = frames + 1
    if ui.screen == "game" then
        local mx, my = coordinates(love.mouse.getPosition())
        scene:update(dt, mx, my)
    end
    if options.smoke then require("ui_smoke").step(frames, ui, start) end
    if options.frames and frames == options.frames and options.shot then
        love.graphics.captureScreenshot(options.shot)
    elseif options.frames and frames > options.frames then
        print("RUN OK frames=" .. options.frames .. " save=" .. love.filesystem.getSaveDirectory())
        love.event.quit(0)
    end
end
