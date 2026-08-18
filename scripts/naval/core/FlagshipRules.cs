#nullable enable
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// Task 15：指挥舰（设计 14）。
// 规则要点与简报歧义裁定见 docs/changes/CHG-20260807-surrender.md。
public static class FlagshipRules
{
    // 未指定时自动选择占格最多的舰船；并列时按默认阵列顺序取第一艘（枚举序首艘最大即保留；跳过沉没舰 HP<=0）。
    public static string? DetermineDefault(IEnumerable<ShipState> ships)
    {
        ShipState? best = null;
        foreach (var s in ships)
        {
            if (s.HitPoints <= 0) continue; // 沉没舰不能担任指挥舰
            if (best is null || s.OccupiedCells().Count > best.OccupiedCells().Count) best = s;
        }
        return best?.Id;
    }

    // 指挥舰 id：手动指定（battle.Flagships[faction]）优先；否则按当前在场该阵营舰走默认最大占格。
    public static string? ResolveFlagshipId(BattleState battle, FactionId faction)
    {
        if (battle.Flagships.TryGetValue(faction, out var id) && id is { Length: > 0 }) return id;
        return DetermineDefault(battle.Ships.Values.Where(s => s.Faction == faction));
    }

    // 指挥舰已沉没：不在 battle.Ships、阵营已变更（投降加入对方）、或 HP<=0 → true。
    // 无法寻得指挥舰（该阵营无舰）→ 视作已沉没（配合投降优势条件2、3 的意图，CHG 裁定 8）。
    public static bool FlagshipSunk(BattleState battle, FactionId faction)
    {
        var id = ResolveFlagshipId(battle, faction);
        if (id is null) return true;
        var flagship = battle.ShipOrNull(id);
        return flagship is null || flagship.Faction != faction || flagship.HitPoints <= 0;
    }
}
