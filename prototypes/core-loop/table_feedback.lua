local Feedback = {}
Feedback.__index = Feedback

local function clip(duration, frequency, gain, rng)
    local rate = 44100
    local data = love.sound.newSoundData(math.floor(rate * duration), rate, 16, 1)
    for i = 0, data:getSampleCount() - 1 do
        local t = i / rate
        local ring = math.sin(t * frequency * math.pi * 2) * math.exp(-t * 65)
            + .35 * math.sin(t * frequency * 2.7 * math.pi * 2) * math.exp(-t * 110)
        local noise = (rng:random() * 2 - 1) * math.exp(-t * 180)
        data:setSample(i, (ring * .55 + noise * .3) * gain)
    end
    return data
end

function Feedback.new(withAudio)
    local self = setmetatable({ flights = {}, score = 0, target = 0, muted = false,
        reduced = false, stampTime = 0, pools = {}, soundIndex = {} }, Feedback)
    if withAudio and love.audio and love.sound then
        local rng = love.math.newRandomGenerator(89)
        for name, spec in pairs({ tile = { .09, 1450, .20 }, button = { .12, 330, .28 },
            score = { .25, 780, .16 } }) do
            local data = clip(spec[1], spec[2], spec[3], rng)
            local ok, source = pcall(love.audio.newSource, data, "static")
            if ok then self.pools[name] = { source, source:clone(), source:clone(), source:clone() } end
        end
    end
    return self
end

function Feedback:play(name)
    if self.muted or not self.pools[name] then return end
    local index = (self.soundIndex[name] or 0) % #self.pools[name] + 1
    self.soundIndex[name] = index
    local source = self.pools[name][index]
    source:stop(); source:play()
end

function Feedback:mute()
    self.muted = not self.muted
    if self.muted then
        for _, pool in pairs(self.pools) do for _, source in ipairs(pool) do source:stop() end end
    end
end

function Feedback:reduce()
    self.reduced = not self.reduced
    if self.reduced then
        self.flights, self.score, self.stampTime = {}, self.target, 0
    end
end

function Feedback.pose(flight)
    local t = math.min(1, flight.time / flight.duration)
    local ease, result = 1 - (1 - t) ^ 3, {}
    for i = 1, 8 do
        result[i] = flight.from[i] + (flight.to[i] - flight.from[i]) * ease
        if i % 2 == 0 then result[i] = result[i] - math.sin(t * math.pi) * 45 end
    end
    return result, t
end

function Feedback:spawn(tile, from, to, duration, fade, flip)
    if self.reduced then return end
    for i = #self.flights, 1, -1 do
        if self.flights[i].tile.id == tile.id then
            from = Feedback.pose(self.flights[i])
            table.remove(self.flights, i)
        end
    end
    self.flights[#self.flights + 1] = { tile = tile, from = from, to = to,
        duration = duration, time = 0, fade = fade, flip = flip }
end

function Feedback:update(dt)
    dt = math.min(dt, .1)
    self.stampTime = math.max(0, self.stampTime - dt)
    self.score = self.score + (self.target - self.score) * math.min(1, dt * 10)
    if math.abs(self.target - self.score) < .5 then self.score = self.target end
    for i = #self.flights, 1, -1 do
        local flight = self.flights[i]
        flight.time = flight.time + dt
        if flight.time >= flight.duration then
            table.remove(self.flights, i)
            if not flight.fade then self:play("tile") end
        end
    end
end

function Feedback:reset()
    self.flights, self.score, self.target, self.stampTime = {}, 0, 0, 0
end

return Feedback
