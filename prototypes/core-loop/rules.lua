local Rules = {}
local bit = require("bit")
local band, bor, bnot = bit.band, bit.bor, bit.bnot
local suits, honors = { "万", "筒", "索" }, { "东", "南", "西", "北", "白", "发", "中" }

function Rules.rank(kind) return (kind - 1) % 9 + 1 end
function Rules.suit(kind) return math.floor((kind - 1) / 9) + 1 end

function Rules.label(kind)
    if kind > 27 then return honors[kind - 27] end
    return Rules.rank(kind) .. suits[Rules.suit(kind)]
end

function Rules.value(tile, build, config)
    local extra = tile.kind <= 27 and Rules.rank(tile.kind) == 5 and (build.fiveBonus or 0) or 0
    return (tile.value or config.tileBase) + extra
end

function Rules.shuffle(tiles, rng)
    for i = #tiles, 2, -1 do
        local j = rng:random(i)
        tiles[i], tiles[j] = tiles[j], tiles[i]
    end
end

function Rules.sort(hand)
    table.sort(hand, function(a, b)
        return a.kind < b.kind or (a.kind == b.kind and a.id < b.id)
    end)
end

-- At most 14 tiles: subset search preserves the identity/value of every physical copy.
function Rules.score(hand, build, config)
    assert(#hand == 14, "Scoring requires exactly 14 tiles")
    local tiles, bits, base, ids = {}, {}, 0, {}
    for _, tile in ipairs(hand) do
        assert(tile.kind >= 1 and tile.kind <= 34 and tile.kind % 1 == 0, "Invalid tile kind")
        assert(tile.id and not ids[tile.id], "Duplicate tile instance")
        ids[tile.id] = true
        tiles[#tiles + 1] = tile
        base = base + Rules.value(tile, build, config)
    end
    Rules.sort(tiles)
    for i = 1, #tiles do bits[i] = 2 ^ (i - 1) end
    local fullMask = 2 ^ #tiles - 1
    local choicesCache = {}

    local function choices(mask)
        if choicesCache[mask] then return choicesCache[mask] end
        local first
        for i = 1, #tiles do
            if band(mask, bits[i]) ~= 0 then first = i; break end
        end
        if not first then return {} end
        local options, kind = {}, tiles[first].kind
        local function add(groupKind, indices)
            local group = { kind = groupKind, tiles = {}, mask = 0, item = 0 }
            for _, index in ipairs(indices) do
                group.tiles[#group.tiles + 1] = tiles[index]
                group.mask = bor(group.mask, bits[index])
                if groupKind == "triplet" and build.repeatTriplets then
                    group.item = group.item + Rules.value(tiles[index], build, config) * build.repeatTriplets
                end
            end
            group.bonus = groupKind == "pair" and config.pairBonus
                or groupKind == "sequence" and config.sequenceBonus or config.tripletBonus
            if groupKind == "sequence" then group.item = build.sequenceBonus or 0 end
            options[#options + 1] = group
        end
        for j = first + 1, #tiles do
            if band(mask, bits[j]) ~= 0 then
                if tiles[j].kind == kind then
                    add("pair", { first, j })
                    for k = j + 1, #tiles do
                        if tiles[k].kind == kind and band(mask, bits[k]) ~= 0 then
                            add("triplet", { first, j, k })
                        end
                    end
                elseif kind <= 27 and Rules.rank(kind) <= 7 and tiles[j].kind == kind + 1 then
                    for k = j + 1, #tiles do
                        if tiles[k].kind == kind + 2 and band(mask, bits[k]) ~= 0 then
                            add("sequence", { first, j, k })
                        end
                    end
                end
            end
        end
        choicesCache[mask] = { first = first, groups = options }
        return choicesCache[mask]
    end

    local memo = { [0] = { bonus = 0, item = 0, groups = {} } }
    local function partial(mask)
        if memo[mask] then return memo[mask] end
        local options = choices(mask)
        local best = partial(band(mask, bnot(bits[options.first])))
        for _, group in ipairs(options.groups) do
            local rest = partial(band(mask, bnot(group.mask)))
            local bonus, item = rest.bonus + group.bonus, rest.item + group.item
            if bonus + item > best.bonus + best.item then
                local groups = { group }
                for _, other in ipairs(rest.groups) do groups[#groups + 1] = other end
                best = { bonus = bonus, item = item, groups = groups }
            end
        end
        memo[mask] = best
        return best
    end

    local ordinary = partial(fullMask)
    local best = { base = base, bonus = ordinary.bonus, item = ordinary.item,
        groups = ordinary.groups, multiplier = 1, yaku = {}, complete = false,
        total = base + ordinary.bonus + ordinary.item }
    local allSimple, pureSuit = true, Rules.suit(tiles[1].kind)
    for _, tile in ipairs(tiles) do
        if tile.kind > 27 or Rules.rank(tile.kind) == 1 or Rules.rank(tile.kind) == 9 then
            allSimple = false
        end
        if tile.kind > 27 or Rules.suit(tile.kind) ~= pureSuit then pureSuit = nil end
    end

    local path = {}
    local function complete(mask, pairs, melds, bonus, item)
        if mask == 0 then
            if pairs ~= 1 or melds ~= 4 then return end
            local yaku, triplets = {}, 0
            if allSimple then yaku[#yaku + 1] = "断幺九" end
            for _, group in ipairs(path) do
                if group.kind == "triplet" then
                    triplets = triplets + 1
                    if group.tiles[1].kind >= 32 then
                        yaku[#yaku + 1] = Rules.label(group.tiles[1].kind) .. "刻"
                    end
                end
            end
            if triplets == 4 then yaku[#yaku + 1] = "对对和" end
            if pureSuit then yaku[#yaku + 1] = "清一色" end
            local multiplier = 1 + #yaku * config.yakuMultiplier
            local total = (base + bonus + item) * multiplier
            if total > best.total or (total == best.total and not best.complete) then
                local groups = {}
                for _, group in ipairs(path) do groups[#groups + 1] = group end
                best = { base = base, bonus = bonus, item = item, groups = groups,
                    yaku = yaku, multiplier = multiplier, complete = true, total = total }
            end
            return
        end
        for _, group in ipairs(choices(mask).groups) do
            local isPair = group.kind == "pair"
            if (isPair and pairs == 0) or (not isPair and melds < 4) then
                path[#path + 1] = group
                complete(band(mask, bnot(group.mask)), pairs + (isPair and 1 or 0),
                    melds + (isPair and 0 or 1), bonus + group.bonus, item + group.item)
                path[#path] = nil
            end
        end
    end
    complete(fullMask, 0, 0, 0, 0)
    best.winning = best.complete and #best.yaku > 0
    return best
end

return Rules
