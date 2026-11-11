local Rules = require("rules")
local Run = {}
Run.__index = Run

function Run:record(action, tile, result)
    self.events[#self.events + 1] = {
        action = action, tile = tile and tile.id or 0,
        score = result and result.total or 0, total = self.total,
        draws = self.draws, settlements = self.settlements,
        phase = self.phase, wall = #self.wall,
        yaku = result and table.concat(result.yaku, "+") or "",
    }
end

function Run:deal()
    for _ = 1, 14 do self.hand[#self.hand + 1] = table.remove(self.wall) end
    Rules.sort(self.hand)
    self.preview = Rules.score(self.hand, self.build, self.config)
end

function Run.new(seed, build, config)
    assert(type(seed) == "number" and seed % 1 == 0, "Seed must be an integer")
    local self = setmetatable({ seed = seed, build = build, config = config,
        wall = {}, hand = {}, discards = {}, events = {}, history = {},
        total = 0, draws = config.draws, settlements = config.settlements,
        phase = "ready" }, Run)
    for kind = 1, 34 do
        for copy = 1, 4 do
            self.wall[#self.wall + 1] = { kind = kind, id = (kind - 1) * 4 + copy }
        end
    end
    Rules.shuffle(self.wall, love.math.newRandomGenerator(seed))
    self:deal()
    self:record("start")
    return self
end

function Run:draw()
    if self.phase ~= "ready" or self.draws <= 0 or #self.wall == 0 then return false end
    local tile = table.remove(self.wall)
    self.hand[#self.hand + 1] = tile
    self.drawnId, self.draws, self.phase, self.preview = tile.id, self.draws - 1, "discard", nil
    self:record("draw", tile)
    return true
end

function Run:discard(index)
    if self.phase ~= "discard" or type(index) ~= "number" or index % 1 ~= 0
        or index < 1 or index > #self.hand then return false end
    local tile = table.remove(self.hand, index)
    self.discards[#self.discards + 1] = tile
    self.phase, self.drawnId = "ready", nil
    Rules.sort(self.hand)
    self.preview = Rules.score(self.hand, self.build, self.config)
    self:record("discard", tile, self.preview)
    return true
end

function Run:settle()
    if self.phase ~= "ready" or self.settlements <= 0 then return false end
    local result = self.preview
    self.lastResult = result
    self.total, self.settlements = self.total + result.total, self.settlements - 1
    self.history[#self.history + 1] = result
    for _, tile in ipairs(self.hand) do self.discards[#self.discards + 1] = tile end
    self.hand, self.preview = {}, nil
    if self.total >= self.config.target then
        self.phase, self.reason = "won", "累计分数已达到本关目标。"
    elseif self.settlements == 0 then
        self.phase, self.reason = "lost", "结算机会已用完，累计分数未达标。"
    elseif #self.wall < 14 then
        self.phase, self.reason = "lost", "牌山不足 14 张，无法发出下一手。"
    else
        self:deal()
    end
    self:record("settle", nil, result)
    return true
end

return Run
