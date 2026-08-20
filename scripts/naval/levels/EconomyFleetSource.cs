#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Levels;

// CHG-20260818：economy 舰型 → 海战舰型映射 + 经济舰队预设的合法性校验（纯 C#，headless 测试可直连）。
// 映射来源：整合版 economy 舰型 → 海战 ShipDefinition 舰型（显示名称按海战模块，如 patrol_boat → 护卫舰）。
public static class EconomyFleetMapper
{
    // economy type id → 海战舰型 id。
    public static readonly IReadOnlyDictionary<string, string> ToNaval = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        { "patrol_boat", "frigate" },
        { "cannon_warship", "flagship" },
        { "escort_junk", "merchant" },
    };

    // 海战舰型 id → economy type id（反向；多对一取第一个，供显示/校验）。
    public static readonly IReadOnlyDictionary<string, string> ToEconomy = ToNaval
        .GroupBy(kv => kv.Value)
        .ToDictionary(g => g.Key, g => g.First().Key, StringComparer.Ordinal);

    // 未知/空 → 空串（调用方跳过并告警）。
    public static string NavalTypeFor(string economyTypeId)
        => !string.IsNullOrEmpty(economyTypeId) && ToNaval.TryGetValue(economyTypeId, out var naval) ? naval : "";

    public static string EconomyTypeFor(string navalTypeId)
        => !string.IsNullOrEmpty(navalTypeId) && ToEconomy.TryGetValue(navalTypeId, out var economy) ? economy : "";

    public static bool KnowsEconomyType(string economyTypeId)
        => !string.IsNullOrEmpty(economyTypeId) && ToNaval.ContainsKey(economyTypeId);
}

// 经济舰队预设校验：名称/舰队非空 + 每舰型出战数量 ≤ 拥有数量 + 舰型可映射。
// 返回错误 key 列表；空 = 合法。ownedByType：economy type id → 拥有数量（null/缺 → 视为 0）。
public static class EconomyFleetValidator
{
    public static IReadOnlyList<string> Validate(FleetPreset preset, IReadOnlyDictionary<string, int>? ownedByType)
    {
        var errors = new List<string>();
        if (preset is null) { errors.Add("fleet.empty_fleet"); return errors; }
        if (string.IsNullOrWhiteSpace(preset.Name)) errors.Add("fleet.empty_name");
        if (preset.Ships is null || preset.Ships.Count == 0) { errors.Add("fleet.empty_fleet"); return errors; }
        var counts = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var ship in preset.Ships)
        {
            var type = ship.ShipTypeId ?? "";
            if (!EconomyFleetMapper.KnowsEconomyType(type)) { errors.Add("fleet.unknown_ship"); continue; }
            counts[type] = counts.GetValueOrDefault(type) + 1;
        }
        foreach (var (type, used) in counts)
        {
            var owned = ownedByType is not null && ownedByType.TryGetValue(type, out var o) ? o : 0;
            if (used > owned) { errors.Add("fleet.over_owned"); break; }
        }
        return errors;
    }
}
