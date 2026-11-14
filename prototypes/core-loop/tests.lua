local Rules, Run, Config = require("rules"), require("run"), require("config")
local Tests = {}

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

local function hand(kinds)
    local result = {}
    for i, kind in ipairs(kinds) do result[i] = { kind = kind, id = i } end
    return result
end

local function equal(actual, expected, message)
    assert(actual == expected, (message or "Mismatch") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local function invariant(run)
    local seen, total, counts = {}, 0, {}
    for _, zone in ipairs({ run.hand, run.wall, run.discards }) do
        for _, tile in ipairs(zone) do
            assert(not seen[tile.id], "Tile in more than one zone")
            seen[tile.id], total = true, total + 1
            counts[tile.kind] = (counts[tile.kind] or 0) + 1
        end
    end
    equal(total, 136, "Conservation")
    for kind = 1, 34 do equal(counts[kind], 4, "Copies") end
    assert(run.draws >= 0 and run.settlements >= 0)
    if run.phase == "ready" then equal(#run.hand, 14) end
    if run.phase == "discard" then equal(#run.hand, 15) end
    if run.phase == "won" or run.phase == "lost" then equal(#run.hand, 0) end
end

local function validGroups(result)
    local seen, bonus, item = {}, 0, 0
    for _, group in ipairs(result.groups) do
        bonus, item = bonus + group.bonus, item + group.item
        for _, tile in ipairs(group.tiles) do
            assert(not seen[tile.id], "Overlapping groups")
            seen[tile.id] = true
        end
        local a, b = group.tiles[1].kind, group.tiles[2].kind
        if group.kind == "sequence" then
            assert(a <= 27 and Rules.rank(a) <= 7)
            equal(b, a + 1); equal(group.tiles[3].kind, a + 2)
        else
            equal(a, b)
            if group.kind == "triplet" then equal(a, group.tiles[3].kind) end
        end
    end
    equal(result.bonus, bonus); equal(result.item, item)
    equal(result.total, (result.base + result.bonus + result.item) * result.multiplier)
    if result.complete then
        local count = 0
        for _ in pairs(seen) do count = count + 1 end
        equal(count, 14)
    end
end

function Tests.run()
    local Tabletop, Feedback = require("tabletop"), require("table_feedback")
    local trapezoid = Tabletop.bounds({ 0,0, 2,0, 3,2, -1,2 })
    assert(Tabletop.hit(trapezoid,1,1) and Tabletop.hit(trapezoid,0,0))
    assert(not Tabletop.hit(trapezoid,-.8,.2), "Picking must follow the polygon, not its bounding box")
    local view = setmetatable({ offsetX = 2, offsetY = -1 }, Tabletop)
    for i = 1, 15 do
        local pose = view:handPose(i)
        local rect = Tabletop.bounds(pose)
        assert(rect.x >= 0 and rect.x+rect.w <= 1280 and rect.y >= 0 and rect.y+rect.h <= 840)
        assert(Tabletop.hit(rect,rect.x+rect.w/2,rect.y+rect.h/2))
        local width=((pose[3]-pose[1])+(pose[5]-pose[7]))/2
        local height=(pose[6]+pose[8]-pose[2]-pose[4])/2
        assert(height/width>=1.2 and height/width<=1.6,"Hand tiles must not look stretched")
        local lean=math.abs((pose[1]+pose[3]-pose[5]-pose[7])/2)
        assert(lean/height<.27,"Outer hand tiles must not lean excessively")
        local raised=Tabletop.bounds(view:handPose(i,9))
        assert(raised.x>=0 and raised.x+raised.w<=1280,"Hovered tiles must remain on screen")
    end
    local wall=Tabletop.bounds(view:wallTilePose(9,2))
    assert(wall.w>=33 and wall.h>=16,"Far wall tiles must remain large enough to read and click")
    local drawRun=Run.new(1126,Config.builds[1],Config)
    view.feedback=Feedback.new(false)
    for _,level in ipairs({2,1}) do
        assert(drawRun:draw())
        view:onAction("draw",{},drawRun)
        local source=view:wallTilePose(61,level)
        local flight=view.feedback.flights[#view.feedback.flights]
        for i=1,8 do equal(flight.from[i],source[i],"Draw from the visible stack layer") end
        assert(drawRun:discard(15))
    end
    local near = Tabletop.project(100,0,50)
    local far = Tabletop.project(100,0,800)
    assert(near > far, "Perspective must make nearby objects larger")
    local feedback = Feedback.new(false)
    local a,b = {0,0,20,0,20,30,0,30}, {50,50,70,50,70,80,50,80}
    feedback:spawn({id=1,kind=1},a,b,.2)
    feedback:update(.05)
    local interrupted = Feedback.pose(feedback.flights[1])
    feedback:spawn({id=1,kind=1},a,b,.3)
    equal(#feedback.flights,1)
    equal(feedback.flights[1].from[1],interrupted[1],"Overlapping feedback starts from the visible position")
    feedback.target = 850
    for _ = 1, 200 do feedback:update(.02) end
    equal(#feedback.flights,0); equal(feedback.score,850)
    feedback:spawn({id=2,kind=2},a,b,.2)
    feedback:reduce(); equal(#feedback.flights,0)
    feedback:spawn({id=3,kind=3},a,b,.2); equal(#feedback.flights,0)
    print("PASS tabletop: perspective, polygon picking, overlapping animation, rest state, reduced motion")
    local plain = { id = "plain" }
    local noYaku = hand({ 1,2,3, 4,5,6, 16,17,18, 20,21,22, 28,28 })
    local score = Rules.score(noYaku, plain, Config)
    assert(score.complete and not score.winning)
    equal(score.multiplier, 1); equal(score.base, 140)
    equal(score.total, 140 + 4 * Config.sequenceBonus + Config.pairBonus)

    local cases = {
        { "断幺九", { 2,3,4, 3,4,5, 12,13,14, 24,24,24, 23,23 } },
        { "白刻", { 1,2,3, 10,11,12, 19,20,21, 32,32,32, 28,28 } },
        { "对对和", { 1,1,1, 11,11,11, 23,23,23, 28,28,28, 31,31 } },
        { "清一色", { 1,2,3, 4,5,6, 7,8,9, 7,8,9, 2,2 } },
    }
    for _, case in ipairs(cases) do
        local result = Rules.score(hand(case[2]), plain, Config)
        assert(result.winning, case[1])
        assert(table.concat(result.yaku, "+"):find(case[1], 1, true), case[1])
        validGroups(result)
    end
    local dragons = Rules.score(hand({ 1,1,1, 10,10,10, 32,32,32, 33,33,33, 28,28 }), plain, Config)
    equal(#dragons.yaku, 3); equal(dragons.multiplier, 4)
    local seven = Rules.score(hand({ 1,1,3,3,5,5,10,10,12,12,19,19,28,28 }), plain, Config)
    assert(not seven.complete and not seven.winning)
    local orphans = Rules.score(hand({ 1,9,10,18,19,27,28,29,30,31,32,33,34,34 }), plain, Config)
    assert(not orphans.complete and not orphans.winning)
    local simpleUnfinished = Rules.score(hand({ 2,2,3,4,6,8,11,12,14,16,20,22,24,26 }), plain, Config)
    assert(not simpleUnfinished.winning); equal(simpleUnfinished.multiplier, 1)

    local ambiguous = hand({ 1,1,1,1,2,2,2,2,3,3,3,3,4,4 })
    local pairConfig = copy(Config)
    pairConfig.pairBonus, pairConfig.sequenceBonus, pairConfig.tripletBonus = 100, 1, 1
    local partial = Rules.score(ambiguous, plain, pairConfig)
    equal(partial.total, 840, "A partial decomposition must not borrow a complete hand's yaku")
    assert(not partial.complete); equal(partial.multiplier, 1)
    validGroups(partial)
    local original = Rules.score(ambiguous, Config.builds[3], Config)
    validGroups(original)
    equal(original.item, 180, "Best complete decomposition uses three triplets")

    local physical = hand({ 32,32,32,32,1,3,5,7,9,11,13,15,17,28 })
    physical[4].value = 99
    local repeatScore = Rules.score(physical, Config.builds[3], Config)
    equal(repeatScore.item, 238, "Repeat the valuable physical copy")
    validGroups(repeatScore)
    local fives = Rules.score(noYaku, Config.builds[1], Config)
    equal(fives.base, score.base + Config.builds[1].fiveBonus)
    local sequences = Rules.score(noYaku, Config.builds[2], Config)
    equal(sequences.item, 4 * Config.builds[2].sequenceBonus)
    local rng = love.math.newRandomGenerator(47)
    for _ = 1, 50 do
        Rules.shuffle(ambiguous, rng)
        local result = Rules.score(ambiguous, Config.builds[3], Config)
        equal(result.total, original.total, "Hand order must not affect score")
        validGroups(result)
    end
    print("PASS scoring: four yaku, no-yaku, unsupported shapes, best splits, physical upgrades, all builds")

    local first = Run.new(1126, Config.builds[1], Config)
    local second = Run.new(1126, Config.builds[2], Config)
    for i, tile in ipairs(first.wall) do equal(tile.id, second.wall[i].id) end
    for i, tile in ipairs(first.hand) do equal(tile.id, second.hand[i].id) end
    local before = #first.wall
    assert(not first:discard(1))
    assert(first:draw()); equal(#first.wall, before - 1)
    assert(not first:draw() and not first:settle() and not first:discard(0) and not first:discard(1.5))
    local drawnId = first.drawnId
    assert(first:discard(15)); equal(first.discards[1].id, drawnId, "Tsumogiri")
    local preview = first.preview.total
    assert(first:settle()); equal(first.lastResult.total, preview)
    equal(first.total, preview); equal(first.draws, Config.draws - 1)
    equal(first.settlements, Config.settlements - 1)
    invariant(first)

    local winConfig = copy(Config)
    winConfig.settlements, winConfig.target = 1, 1
    local win = Run.new(1126, plain, winConfig)
    assert(win:settle()); equal(win.phase, "won", "Win checked before resource exhaustion")
    assert(not win:draw() and not win:settle() and not win:discard(1)); invariant(win)
    local lossConfig = copy(Config)
    lossConfig.settlements, lossConfig.target, lossConfig.draws = 1, 100000, 0
    local loss = Run.new(1126, plain, lossConfig)
    assert(not loss:draw()); assert(loss:settle()); equal(loss.phase, "lost"); invariant(loss)
    local short = Run.new(1126, plain, lossConfig)
    short.settlements = 2
    while #short.wall > 13 do short.discards[#short.discards + 1] = table.remove(short.wall) end
    assert(short:settle()); equal(short.phase, "lost"); equal(#short.wall, 13); invariant(short)
    local empty = Run.new(1126, plain, Config)
    while #empty.wall > 0 do empty.discards[#empty.discards + 1] = table.remove(empty.wall) end
    assert(not empty:draw() and empty:settle()); invariant(empty)

    local replayA, replayB = Run.new(2026, plain, Config), Run.new(2026, plain, Config)
    for _ = 1, 10 do
        assert(replayA:draw()); love.math.random()
        assert(replayB:draw())
        assert(replayA:discard(1) and replayB:discard(1))
    end
    assert(replayA:settle() and replayB:settle())
    equal(replayA.total, replayB.total)
    for i, tile in ipairs(replayA.hand) do equal(tile.id, replayB.hand[i].id) end
    print("PASS states: invalid actions, shared budgets, preview, victory, failure, empty wall, replay")

    local botRng, run = love.math.newRandomGenerator(999), Run.new(999, plain, Config)
    for _ = 1, 10000 do
        if run.phase == "won" or run.phase == "lost" then
            run = Run.new(botRng:random(1000000), Config.builds[botRng:random(3)], Config)
        elseif run.phase == "discard" then
            assert(run:discard(botRng:random(#run.hand)))
        elseif run.draws > 0 and #run.wall > 0 and botRng:random() < 0.9 then
            assert(run:draw())
        else
            assert(run:settle())
        end
        invariant(run)
        if run.preview then validGroups(run.preview) end
    end
    print("PASS 10,000 legal actions: 136 unique instances, four copies per kind, nonnegative budgets")

    local frequencies = {}
    for _ = 1, 24000 do
        local deck = { 1, 2, 3, 4 }
        Rules.shuffle(deck, botRng)
        local key = table.concat(deck)
        frequencies[key] = (frequencies[key] or 0) + 1
    end
    local orders, chi = 0, 0
    for _, count in pairs(frequencies) do
        orders, chi = orders + 1, chi + (count - 1000) ^ 2 / 1000
    end
    equal(orders, 24); assert(chi < 41, "Shuffle distribution")
    print(string.format("PASS shuffle: 24,000 shuffles / 24 orders, chi-square %.2f", chi))
    print("ALL TESTS PASSED")
end

function Tests.benchmark()
    for _, build in ipairs(Config.builds) do
        local sum, hands, wins, runs, actions, baseline, clearances = 0, 0, 0, 0, 0, 0, 0
        local settings = copy(Config)
        settings.target = 1000000
        while actions < 1000 do
            runs = runs + 1
            local run = Run.new(1000 + runs, build, settings)
            local immediate = Run.new(1000 + runs, build, settings)
            for _ = 1, Config.settlements do assert(immediate:settle()) end
            baseline = baseline + immediate.total
            while run.phase == "ready" and actions < 1000 do
                for _ = 1, math.floor(Config.draws / Config.settlements) do
                    if not run:draw() then break end
                    local bestIndex, bestScore = 15, -1
                    for index = 1, 15 do
                        local candidate = {}
                        for i, tile in ipairs(run.hand) do
                            if i ~= index then candidate[#candidate + 1] = tile end
                        end
                        local result = Rules.score(candidate, build, Config)
                        if result.total > bestScore or (result.total == bestScore and index == 15) then
                            bestScore, bestIndex = result.total, index
                        end
                    end
                    assert(run:discard(bestIndex))
                    actions = actions + 1
                end
                local result = run.preview
                sum, hands = sum + result.total, hands + 1
                if result.winning then wins = wins + 1 end
                assert(run:settle())
            end
            if run.total >= Config.target then clearances = clearances + 1 end
        end
        print(string.format("BOT %s: %d draws, %d hands, mean %.1f/hand, %d winning hands, %d/%d clears; immediate mean %.1f/run (myopic score bot)",
            build.id, actions, hands, sum / hands, wins, clearances, runs, baseline / runs))
    end
end

return Tests
