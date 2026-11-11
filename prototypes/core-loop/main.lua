local Config, Rules, Run = require("config"), require("rules"), require("run")
local W, H = 1280, 840
local ui = { screen = "setup", build = 1, seed = 1, buttons = {}, tileRects = {}, discardScroll = 0 }
local fonts, options, frames = {}, {}, 0
local palette = {
    background = { .035, .10, .10 }, panel = { .065, .16, .155 },
    ink = { .91, .92, .84 }, muted = { .56, .70, .65 }, gold = { .94, .73, .36 },
    tile = { .94, .91, .80 }, dark = { .08, .15, .14 },
    red = { .65, .20, .20 }, green = { .12, .42, .32 }, blue = { .16, .32, .52 },
}
local groupColors = { { .85, .55, .30 }, { .38, .70, .56 }, { .45, .65, .84 },
    { .76, .54, .77 }, { .87, .77, .40 }, { .49, .77, .76 }, { .75, .75, .65 } }
local groupNames = { pair = "对子", sequence = "顺子", triplet = "刻子" }

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
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
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
    ui.notice = nil
    flushLog()
end

local function act(method, ...)
    if ui.run[method](ui.run, ...) then
        ui.hoverScore, ui.hoverId = nil, nil
        if method == "settle" then
            ui.notice = "上次结算 +" .. ui.run.lastResult.total
        else ui.notice = nil end
        flushLog()
    end
end

local function tileFace(tile, x, y, w, h, small, tint, label)
    box(x, y + (small and 2 or 5), w, h, { .20, .32, .28 }, small and 3 or 7)
    box(x, y, w, h, tint or palette.tile, small and 3 or 7)
    local kind = tile.kind
    local tileColor = kind <= 27 and ({ palette.red, palette.blue, palette.green })[Rules.suit(kind)]
        or (kind >= 32 and palette.red or palette.dark)
    if small then
        text(Rules.label(kind), x, y + 6, 14, tileColor, w, "center")
    else
        local face = kind <= 27 and tostring(Rules.rank(kind)) or Rules.label(kind)
        text(face, x, y + 12, 32, tileColor, w, "center")
        if kind <= 27 then
            text(({ "万", "筒", "索" })[Rules.suit(kind)], x, y + 49, 20, tileColor, w, "center")
        end
        text(label or (Rules.value(tile, ui.run.build, Config) .. "分"), x, y + h - 24, 14, palette.dark, w, "center")
    end
end

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

local function drawScore(result, x, y)
    if not result then
        text("先弃掉一张牌", x, y + 15, 32)
        text("将鼠标移到牌上，预览弃掉它之后的得分。", x, y + 72, 20, palette.muted)
        return
    end
    text("(" .. result.base .. " 单牌 + " .. result.bonus .. " 组合 + " .. result.item .. " 道具) × " .. result.multiplier,
        x, y, 20, palette.muted)
    text(result.total, x, y + 31, 48, palette.gold)
    local status = result.winning and table.concat(result.yaku, " / ")
        or (result.complete and "结构完整 · 无役，按普通手牌计分" or "普通手牌 · 不必胡牌也能结算")
    text(status, x + 184, y + 51, 20, palette.ink, 540)
    local labels = {}
    for i, group in ipairs(result.groups) do
        local names = {}
        for _, tile in ipairs(group.tiles) do names[#names + 1] = Rules.label(tile.kind) end
        labels[#labels + 1] = { text = i .. "  " .. table.concat(names, " ") .. "  " .. groupNames[group.kind]
            .. "  +" .. group.bonus .. (group.item > 0 and (" / 道具 +" .. group.item) or ""), color = groupColors[i] }
    end
    for i, label in ipairs(labels) do text(label.text, x, y + 103 + (i - 1) * 25, 16, label.color) end
end

local function drawDiscards(run)
    local x, y, w, h = 860, 430, 372, 350
    box(x, y, w, h)
    text("弃牌区  /  " .. #run.discards .. " 张", x + 20, y + 16, 20)
    local columns, rowHeight, visibleHeight = 10, 38, 260
    local rows = math.ceil(#run.discards / columns)
    ui.maxScroll = math.max(0, rows * rowHeight - visibleHeight)
    ui.discardScroll = math.max(0, math.min(ui.maxScroll, ui.discardScroll))
    local width, height = love.graphics.getDimensions()
    local scale = math.min(width / W, height / H)
    love.graphics.setScissor((width - W * scale) / 2 + (x + 16) * scale,
        (height - H * scale) / 2 + (y + 56) * scale, (w - 32) * scale, visibleHeight * scale)
    for i, tile in ipairs(run.discards) do
        local row, col = math.floor((i - 1) / columns), (i - 1) % columns
        tileFace(tile, x + 20 + col * 33, y + 56 + row * rowHeight - ui.discardScroll, 29, 31, true)
    end
    love.graphics.setScissor()
    if #run.discards == 0 then text("本关弃牌都会保留在这里", x + 20, y + 75, 16, palette.muted) end
    text(ui.maxScroll > 0 and "在此滚动，查看全部弃牌 ↑↓" or "换牌与结算弃牌 · 本关不再抽回",
        x + 20, y + h - 26, 14, palette.muted)
end

local function drawGame()
    local run, active = ui.run, ui.run.phase == "ready" or ui.run.phase == "discard"
    text("QUE", 48, 27, 32, palette.gold)
    text(run.build.name .. "  /  SEED " .. run.seed, 156, 36, 20, palette.muted)
    button("menu", "返回构筑选择", 1022, 24, 210, 40, true, function() ui.screen = "setup" end)
    box(48, 93, 1184, 99)
    text("累计 / 目标", 70, 108, 16, palette.muted)
    text(run.total .. " / " .. Config.target, 70, 136, 32)
    text("剩余换牌", 493, 109, 16, palette.muted); text(run.draws, 493, 138, 24)
    text("剩余结算", 711, 109, 16, palette.muted); text(run.settlements, 711, 138, 24)
    text("牌山", 938, 109, 16, palette.muted); text(#run.wall .. " 张", 938, 138, 24)
    local fraction = math.min(1, run.total / Config.target)
    box(70, 182, 1138 * fraction, 3, palette.gold, 0)

    local handTitle = run.phase == "discard" and "摸牌后 · 点击一张牌弃掉"
        or (active and "当前手牌 · 彩色标记对应下方计分组合" or "整手牌已移入弃牌区")
    text(handTitle, 48, 211, 20)
    local preview = run.preview
    if run.phase == "discard" and ui.hoverScore then preview = ui.hoverScore end
    local membership = {}
    if preview then
        for i, group in ipairs(preview.groups) do
            for _, tile in ipairs(group.tiles) do membership[tile.id] = i end
        end
    end
    local mx, my = coordinates(love.mouse.getPosition())
    for i, tile in ipairs(run.hand) do
        local rect = { x = 48 + (i - 1) * 78, y = 254, w = 68, h = 98, index = i }
        ui.tileRects[#ui.tileRects + 1] = rect
        local hovered = run.phase == "discard" and contains(rect, mx, my)
        local y = rect.y - (hovered and 8 or 0)
        tileFace(tile, rect.x, y, rect.w, rect.h, false, hovered and palette.gold or nil)
        local groupIndex = membership[tile.id]
        if groupIndex then
            box(rect.x, y, rect.w, 5, groupColors[groupIndex], 0)
            text(groupIndex, rect.x + 5, y + 4, 14, palette.dark)
        end
        if tile.id == run.drawnId then text("新摸", rect.x, y - 24, 14, palette.gold, rect.w, "center") end
    end
    if active then
        button("draw", "摸一张  [空格]", 48, 375, 210, 44,
            run.phase == "ready" and run.draws > 0 and #run.wall > 0, function() act("draw") end)
        button("settle", "结算整手  [回车]", 278, 375, 245, 44,
            run.phase == "ready", function() act("settle") end, run.phase == "ready")
        local hint = run.phase == "discard" and "先弃牌，再结算。摸切也可以。"
            or (ui.notice or "换牌与结算次数在三手之间共享。")
        text(hint, 555, 387, 20, palette.muted)
    else
        text(run.phase == "won" and "本关达成" or "本关结束", 48, 257, 48,
            run.phase == "won" and palette.gold or palette.ink)
        text(run.reason, 365, 278, 20, palette.muted)
        button("retry", "同配置再试  [R]", 48, 375, 250, 44, true, start, true)
        button("nextseed", "下一个种子", 318, 375, 210, 44, true, function()
            ui.seed = ui.seed % #Config.seeds + 1; start()
        end)
    end
    box(48, 430, 788, 350)
    text(active and (ui.hoverScore and "弃掉这张后的预览" or "当前得分预览") or "最后一次结算", 70, 447, 20)
    ui.displayScore = preview
    if not active then ui.displayScore = run.lastResult end
    drawScore(ui.displayScore, 70, 482)
    drawDiscards(run)
    text("单牌 " .. Config.tileBase .. "  ·  对子 +" .. Config.pairBonus .. "  ·  顺子 +" .. Config.sequenceBonus
        .. "  ·  刻子 +" .. Config.tripletBonus .. "  ·  胡牌倍率 1 + 役项数", 48, 799, 14, palette.muted)
    if ui.logError then text("试玩日志写入失败", 1020, 799, 14, palette.gold) end
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
    if ui.screen == "setup" then drawSetup() else drawGame() end
    love.graphics.pop()
end

function love.mousepressed(x, y, mouseButton)
    if mouseButton ~= 1 then return end
    x, y = coordinates(x, y)
    for _, rect in ipairs(ui.buttons) do
        if rect.enabled and contains(rect, x, y) then rect.action(); return end
    end
    if ui.screen == "game" and ui.run.phase == "discard" then
        for _, rect in ipairs(ui.tileRects) do
            if contains(rect, x, y) then act("discard", rect.index); return end
        end
    end
end

function love.mousemoved(x, y)
    if ui.screen ~= "game" or ui.run.phase ~= "discard" then return end
    x, y = coordinates(x, y)
    local index
    for _, rect in ipairs(ui.tileRects) do if contains(rect, x, y) then index = rect.index; break end end
    local id = index and ui.run.hand[index].id
    if id == ui.hoverId then return end
    ui.hoverId, ui.hoverScore = id, nil
    if index then
        local hand = {}
        for i, tile in ipairs(ui.run.hand) do if i ~= index then hand[#hand + 1] = tile end end
        ui.hoverScore = Rules.score(hand, ui.run.build, Config)
    end
end

function love.wheelmoved(_, y)
    if ui.screen ~= "game" then return end
    local mx, my = coordinates(love.mouse.getPosition())
    if mx >= 860 and mx <= 1232 and my >= 430 and my <= 780 then
        ui.discardScroll = math.max(0, math.min(ui.maxScroll or 0, ui.discardScroll - y * 38))
    end
end

function love.keypressed(key, _, isRepeat)
    if isRepeat then return end
    if key == "escape" then ui.screen = "setup"
    elseif ui.screen == "setup" then
        if key == "return" then start() end
    elseif key == "space" then act("draw")
    elseif key == "return" then act("settle")
    elseif key == "r" and (ui.run.phase == "won" or ui.run.phase == "lost") then start() end
end

function love.update()
    if options.test then return end
    frames = frames + 1
    if options.smoke then require("ui_smoke").step(frames, ui, start) end
    if options.frames and frames == options.frames and options.shot then
        love.graphics.captureScreenshot(options.shot)
    elseif options.frames and frames > options.frames then
        print("RUN OK frames=" .. options.frames .. " save=" .. love.filesystem.getSaveDirectory())
        love.event.quit(0)
    end
end
