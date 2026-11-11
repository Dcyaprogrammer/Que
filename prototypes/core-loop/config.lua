return {
    tileBase = 10,
    pairBonus = 12,
    sequenceBonus = 32,
    tripletBonus = 36,
    yakuMultiplier = 1,
    draws = 48,
    settlements = 3,
    target = 850,
    seeds = { 1126, 2026, 31415, 86420, 13579 },
    builds = {
        { id = "fives", name = "重五", fiveBonus = 20,
          description = "万、筒、索的五，每张基础分 +20。\n高分孤张也值得留下。" },
        { id = "sequences", name = "顺子", sequenceBonus = 32,
          description = "每组顺子额外 +32 分。\n保留连接牌，让组合持续增值。" },
        { id = "triplets", name = "刻子", repeatTriplets = 2,
          description = "刻子内的牌额外计两次单牌分值。\n高分牌与刻子奖励可以联动。" },
    },
}
