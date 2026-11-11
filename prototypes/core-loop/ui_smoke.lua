local Smoke = {}
local Config = require("config")
local originalTarget, opening

local function click(ui, id)
    for _, rect in ipairs(ui.buttons) do
        if rect.id == id then
            assert(rect.enabled, "Disabled button: " .. id)
            local w, h = love.graphics.getDimensions()
            local scale = math.min(w / 1280, h / 840)
            love.mousepressed((w - 1280 * scale) / 2 + (rect.x + rect.w / 2) * scale,
                (h - 840 * scale) / 2 + (rect.y + rect.h / 2) * scale, 1)
            return
        end
    end
    error("Missing button: " .. id)
end

local function ids(run)
    local values = {}
    for _, tile in ipairs(run.hand) do values[#values + 1] = tile.id end
    return table.concat(values, ",")
end

function Smoke.step(frame, ui)
    if frame == 2 then
        love.graphics.captureScreenshot("smoke-setup.png")
        click(ui, "build2")
    elseif frame == 3 then
        assert(ui.build == 2); click(ui, "seed2")
    elseif frame == 4 then
        assert(ui.seed == 2); click(ui, "start")
        assert(ui.screen == "game" and ui.run.build.id == "sequences")
        opening = ids(ui.run)
    elseif frame == 5 then
        love.graphics.captureScreenshot("smoke-table.png")
    elseif frame == 6 then
        click(ui, "draw")
        assert(ui.run.phase == "discard" and #ui.run.hand == 15)
    elseif frame == 8 then
        local rect = ui.tileRects[15]
        local w, h = love.graphics.getDimensions()
        local scale = math.min(w / 1280, h / 840)
        local x = (w - 1280 * scale) / 2 + (rect.x + rect.w / 2) * scale
        local y = (h - 840 * scale) / 2 + (rect.y + rect.h / 2) * scale
        love.mousemoved(x, y)
        assert(ui.hoverScore and ui.hoverScore.total > 0)
        love.graphics.captureScreenshot("smoke-discard.png")
    elseif frame == 10 then
        local rect = ui.tileRects[15]
        local w, h = love.graphics.getDimensions()
        local scale = math.min(w / 1280, h / 840)
        love.mousepressed((w - 1280 * scale) / 2 + (rect.x + rect.w / 2) * scale,
            (h - 840 * scale) / 2 + (rect.y + rect.h / 2) * scale, 1)
        assert(ui.run.phase == "ready" and #ui.run.discards == 1)
    elseif frame == 12 then
        local preview = ui.run.preview.total
        click(ui, "settle")
        assert(ui.run.lastResult.total == preview and #ui.run.discards == 15)
    elseif frame == 13 then
        click(ui, "draw")
    elseif frame == 14 then
        assert(ui.displayScore == nil, "A pending discard must not display the previous hand's score")
        love.graphics.captureScreenshot("smoke-second-discard.png")
    elseif frame == 15 then
        assert(ui.run:discard(15))
        love.keypressed("return", "return", false)
    elseif frame == 17 then
        click(ui, "settle")
    elseif frame == 18 then
        assert(ui.run.phase == "lost", "Immediate settlements should exercise the failure screen")
        love.graphics.captureScreenshot("smoke-result.png")
    elseif frame == 19 then
        click(ui, "retry")
        assert(ids(ui.run) == opening and ui.run.draws == Config.draws and ui.run.total == 0)
        assert(ui.notice == nil, "Retry must clear the previous settlement's notification")
    elseif frame == 20 then
        click(ui, "menu")
    elseif frame == 22 then
        assert(ui.screen == "setup"); click(ui, "build3")
    elseif frame == 24 then
        originalTarget, Config.target = Config.target, 1
        click(ui, "start")
        assert(ui.run.build.id == "triplets")
    elseif frame == 26 then
        click(ui, "settle"); assert(ui.run.phase == "won")
    elseif frame == 28 then
        love.graphics.captureScreenshot("smoke-victory.png")
    elseif frame == 30 then
        Config.target = originalTarget
        click(ui, "nextseed")
        assert(ui.seed == 3 and ui.run.seed == Config.seeds[3] and ui.run.total == 0)
    elseif frame == 32 then
        love.window.setMode(960, 630, { resizable = true, minwidth = 960, minheight = 630, highdpi = true })
    elseif frame == 34 then
        click(ui, "draw")
        assert(ui.run.phase == "discard")
    elseif frame == 35 then
        love.graphics.captureScreenshot("smoke-small.png")
    elseif frame == 36 then
        love.window.setMode(1280, 840, { resizable = true, minwidth = 960, minheight = 630, highdpi = true })
    elseif frame == 38 then
        love.keypressed("escape", "escape", false)
    elseif frame == 40 then
        click(ui, "build1")
    elseif frame == 42 then
        click(ui, "start")
        assert(ui.run.build.id == "fives" and ui.run.phase == "ready")
    elseif frame == 44 then
        for _ = 1, Config.draws do
            assert(ui.run:draw() and ui.run:discard(15))
        end
        love.keypressed("return", "return", false)
    elseif frame == 46 then
        love.keypressed("return", "return", false)
    elseif frame == 48 then
        love.mouse.setPosition(1000, 600)
        love.wheelmoved(0, -100)
        assert(ui.maxScroll > 0 and ui.discardScroll == ui.maxScroll, "Scroll to final discarded tiles")
    elseif frame == 49 then
        love.graphics.captureScreenshot("smoke-scrolled.png")
    elseif frame == 50 then
        love.wheelmoved(0, 100)
        assert(ui.discardScroll == 0)
    elseif frame == 52 then
        click(ui, "menu")
    elseif frame == 54 then
        click(ui, "start")
        assert(ui.run.draws == Config.draws and #ui.run.discards == 0)
    elseif frame == 58 then
        -- Explicit rendering fixture; normal runs still use the untouched seeded shuffle.
        local wanted = { 1,1,1, 10,10,10, 32,32,32, 33,33,33, 28,28 }
        local pool, chosen = {}, {}
        for _, zone in ipairs({ ui.run.hand, ui.run.wall }) do
            for _, tile in ipairs(zone) do pool[#pool + 1] = tile end
        end
        for _, kind in ipairs(wanted) do
            for index, tile in ipairs(pool) do
                if tile.kind == kind then chosen[#chosen + 1] = table.remove(pool, index); break end
            end
        end
        assert(#chosen == 14 and #pool == 122)
        ui.run.hand, ui.run.wall = chosen, pool
        ui.run.preview = require("rules").score(chosen, ui.run.build, Config)
    elseif frame == 60 then
        assert(ui.displayScore.winning and #ui.displayScore.yaku == 3)
        love.graphics.captureScreenshot("smoke-yaku-fixture.png")
    elseif frame == 62 then
        click(ui, "menu")
    elseif frame == 64 then
        click(ui, "start")
        assert(ui.run.draws == Config.draws and #ui.run.discards == 0)
        print("UI SMOKE PASSED: build/seed selection, draw/discard, preview, settlements, failure/retry, victory, next seed, resize, all-discard scrolling, yaku rendering")
    end
end

return Smoke
