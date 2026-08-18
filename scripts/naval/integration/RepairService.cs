#nullable enable
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Integration;

// Task 16（设计 17 免费维修）：Demo 战后免费、即时、修满。
// 规则：存活（HP>0）舰生命直接回最大；沉没（HP<=0）永久损失不可修复；自沉舰生命恢复但保留 SelfSunk
// （永久火力点仍属我方舰船，仅失去移动转向）；投降加入我方的敌舰（投降移交）可免费修满。
public static class RepairService
{
    // 核心重载：任一存活舰回满。不关心结果分类——适合 Demo 直接对 battle.Ships.Values 调用。
    public static void RepairAll(IEnumerable<ShipState> fleet)
    {
        foreach (var s in fleet)
        {
            if (s.HitPoints <= 0) continue; // 0 血永久损失，不修复不复活
            s.HitPoints = s.MaxHp;          // 免费即时修满
            s.Repairs.Clear();              // 满血后损管持续恢复无意义，防御性清空（Finalize 清理已先清）
        }
    }

    // 按结果分类维修：只修 存活/自沉永久固定/投降移交 类（沉没/逃脱/被俘 离场或永久损失，一律不修）。
    // 剧情层若持有 BattleResult 与对应舰队，可用本重载精确过滤。
    public static void RepairAll(BattleResult result, IEnumerable<ShipState> fleet)
    {
        var repairable = new HashSet<string>(result.Ships
            .Where(r => r.Kind is ShipLossKind.Survived or ShipLossKind.Permanent or ShipLossKind.Surrendered)
            .Select(r => r.ShipId));
        RepairAll(fleet.Where(s => repairable.Contains(s.Id)));
    }
}
