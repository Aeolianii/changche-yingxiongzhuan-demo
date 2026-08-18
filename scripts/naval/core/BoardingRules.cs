#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// Task 10：接舷、脱离与俘获（设计文档第 11 节 + 简报 Task 10）。
// 接舷发起：平行 + 间隔 0（最近占格距离 1）；双方立即受各自舰型固定接舷伤（无视护甲）。
// 组合：防守方在其阵营回合控制，预算 2 格/防守方回合，整体平移、不转向；接舷中双方禁单独移动/转向；
//       通过性2 舰随组合入礁损失最大生命15%（设计 5.3，与 MovementRules/RamRules 同式）。
// 脱离：发起方必定；防守方 50% ± 每档速度 15%，钳制 20-80%，走 battle.Random；任一方尝试都消耗动作并结束本舰回合。
// 俘获：优势（目标被发起方阵营双向邻接 / 发起方血比目标高 >50pp）；进度 0/25/50/100（递增按档位跳、衰减逐级 25）；
//       仅原发起方主动交换触发判定（双方仍在接舷且进度 >0）；完整回合边界有优势晋级 / 无优势宽限+衰减；
//       脱离后保留进度逐回合衰减、重新接舷继承。
// 断链：沉没/被俘/消失立即解除；被撞击推离等外部事件拉开（不再平行相邻）同样断链，俘获进度转入发起方保留逐回合衰减。
// 裁定说明见 docs/changes/CHG-20260807-boarding.md 的"简报与设计歧义裁定"。
public static class BoardingRules
{
    public const int PairMoveBudget = 2;
    public const double DefenderDisengageBaseRate = 0.50;
    public const double DisengageSpeedTierModifier = 0.15;
    public const double MinDisengageRate = 0.20;
    public const double MaxDisengageRate = 0.80;
    public const double HpAdvantageMargin = 0.50;
    public const int ProgressStep = 25;

    // —— 校验（ActionResolver 用；null = 合法，否则为拒绝原因 key）——

    public static string? ValidateBoard(BattleState battle, BoardCommand cmd)
    {
        var initiator = battle.ShipOrNull(cmd.ShipId);
        if (initiator is null || initiator.HitPoints <= 0) return "action.unknown_ship";
        if (initiator.Faction != battle.CurrentFaction) return "action.unknown_ship";
        if (initiator.Boarding is not null) return "boarding.already_boarding";
        if (initiator.HasAttacked) return "action.attack_ended_movement";
        var defender = battle.ShipOrNull(cmd.TargetId);
        if (defender is null || defender.HitPoints <= 0) return "boarding.target_not_found";
        if (defender.Faction == initiator.Faction) return "boarding.target_is_friendly";
        if (defender.Boarding is not null) return "boarding.target_already_boarding";
        if (!IsParallelAdjacent(initiator, defender)) return "boarding.not_parallel_adjacent";
        return null;
    }

    // 只读查询（T13）：当前舰合法接舷目标舰集合（UI 接舷按钮可用性与目标高亮复用，不重复实现规则）。
    public static List<string> QueryBoardTargets(BattleState battle, string shipId)
    {
        var ship = battle.ShipOrNull(shipId);
        if (ship is null || ship.HitPoints <= 0) return new List<string>();
        var result = new List<string>();
        foreach (var other in battle.Ships.Values)
        {
            if (other.Id == shipId || other.HitPoints <= 0) continue;
            if (ValidateBoard(battle, new BoardCommand(shipId, other.Id)) is null)
                result.Add(other.Id);
        }
        return result;
    }

    public static string? ValidateExchange(BattleState battle, BoardingExchangeCommand cmd)
    {
        var ship = battle.ShipOrNull(cmd.ShipId);
        if (ship is null || ship.HitPoints <= 0) return "action.unknown_ship";
        if (ship.Faction != battle.CurrentFaction) return "action.unknown_ship";
        if (ship.Boarding is null) return "boarding.not_boarding";
        if (ship.HasAttacked) return "action.attack_ended_movement";
        return null;
    }

    public static string? ValidateDisengage(BattleState battle, DisengageCommand cmd)
    {
        var ship = battle.ShipOrNull(cmd.ShipId);
        if (ship is null || ship.HitPoints <= 0) return "action.unknown_ship";
        if (ship.Faction != battle.CurrentFaction) return "action.unknown_ship";
        if (ship.Boarding is null) return "boarding.not_boarding";
        if (ship.HasAttacked) return "action.attack_ended_movement";
        return null;
    }

    public static string? ValidatePairMove(BattleState battle, BoardPairMoveCommand cmd)
    {
        var defender = battle.ShipOrNull(cmd.ShipId);
        if (defender is null || defender.HitPoints <= 0) return "action.unknown_ship";
        if (defender.Faction != battle.CurrentFaction) return "action.unknown_ship";
        if (defender.Boarding is null) return "boarding.not_boarding";
        // 仅原被接舷方（防守方）可在其阵营回合控制组合平移（设计 11.1）
        if (defender.Id != defender.Boarding.DefenderId) return "boarding.only_defender_controls";
        if (defender.HasAttacked) return "action.attack_ended_movement";
        if (defender.Boarding.PairMovesUsed >= PairMoveBudget) return "boarding.pair_budget_exhausted";
        var initiator = battle.ShipOrNull(defender.Boarding.InitiatorId);
        if (initiator is null || initiator.HitPoints <= 0) return "boarding.link_broken";
        // 组合目标位置：两舰同时整体平移（相对位置锁定），逐舰按各自通过性校验界内/地形/残骸；
        // 再与"组合两舰之外"的舰船做冲突判定（组合滑动经过对方旧占格是合法整体平移，不算阻挡）
        var dir = cmd.Direction.Vector();
        var initiatorCells = initiator.OccupiedCells().Select(c => c + dir).ToList();
        var defenderCells = defender.OccupiedCells().Select(c => c + dir).ToList();
        foreach (var (cells, ship) in new[] { (initiatorCells, initiator), (defenderCells, defender) })
        {
            foreach (var c in cells)
            {
                if (!battle.Map.InBounds(c)) return "movement.blocked";
                if (battle.Map.IsWreck(c)) return "movement.blocked";
                var t = battle.Map.TerrainAt(c);
                // U-2a：陆地恒不可通行；深水限定舰不可进浅水（浅滩/礁石/陆河），经 TerrainRules 统一判定。
                if (TerrainRules.BlocksShip(t, ship.Definition.Passability)) return "movement.blocked";
            }
        }
        var pairCells = initiatorCells.Concat(defenderCells).ToHashSet();
        var blockedByOther = battle.Ships.Values.Any(other =>
            other.Id != initiator.Id && other.Id != defender.Id && other.HitPoints > 0
            && other.OccupiedCells().Any(pairCells.Contains));
        return blockedByOther ? "movement.blocked" : null;
    }

    // —— 结算（输出 BattleEvent[]）——

    public static BattleEvent[] ResolveBoard(BattleState battle, BoardCommand cmd)
    {
        if (ValidateBoard(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var initiator = battle.ShipOrNull(cmd.ShipId)!;
        var defender = battle.ShipOrNull(cmd.TargetId)!;
        initiator.HasAttacked = true; // 发起接舷消耗发起方攻击动作（设计 11.1）

        // 重新接舷继承未衰减完的保留进度（设计 11.3）
        var progress = 0;
        if (initiator.RetainedCaptureProgress.TryGetValue(defender.Id, out var retained))
        {
            progress = retained;
            initiator.RetainedCaptureProgress.Remove(defender.Id);
        }
        var link = new BoardingLink { InitiatorId = initiator.Id, DefenderId = defender.Id, CaptureProgress = progress };
        initiator.Boarding = link;
        defender.Boarding = link;

        // 发起时双方立即承受各自舰型规定的固定接舷伤害，无视护甲（设计 11.1/8）
        var initDmg = BoardingDamage(battle, initiator);
        var defDmg = BoardingDamage(battle, defender);
        initiator.HitPoints -= initDmg;
        defender.HitPoints -= defDmg;

        var events = new List<BattleEvent>
        {
            new BoardingLinkedEvent(initiator.Id, defender.Id, initDmg, initiator.HitPoints, defDmg, defender.HitPoints)
        };
        // Task 11：敌方接舷伤害打断双方损管（设计 12.3，裁定 8）
        if (StatusRules.InterruptRepairs(initiator)) events.Add(new RepairsInterruptedEvent(initiator.Id));
        if (StatusRules.InterruptRepairs(defender)) events.Add(new RepairsInterruptedEvent(defender.Id));
        // 任一舰沉没：接舷立即解除（设计 11.1）
        if (initiator.HitPoints <= 0 || defender.HitPoints <= 0)
        {
            initiator.Boarding = null;
            defender.Boarding = null;
            if (initiator.HitPoints <= 0) events.Add(new ShipSunkEvent(initiator.Id));
            if (defender.HitPoints <= 0) events.Add(new ShipSunkEvent(defender.Id));
        }
        return events.ToArray();
    }

    public static BattleEvent[] ResolveExchange(BattleState battle, BoardingExchangeCommand cmd)
    {
        if (ValidateExchange(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var actor = battle.ShipOrNull(cmd.ShipId)!;
        var link = actor.Boarding!;
        var initiator = battle.ShipOrNull(link.InitiatorId)!;
        var defender = battle.ShipOrNull(link.DefenderId)!;
        actor.HasAttacked = true; // 交换消耗触发方动作（设计 11.1 任一方可触发）

        // 双方同时受各自舰型固定接舷伤害，无视护甲（设计 11.1）
        var initDmg = BoardingDamage(battle, initiator);
        var defDmg = BoardingDamage(battle, defender);
        initiator.HitPoints -= initDmg;
        defender.HitPoints -= defDmg;

        // Task 11：敌方接舷伤害打断双方损管（设计 12.3，裁定 8）
        var initRepairBroken = StatusRules.InterruptRepairs(initiator);
        var defRepairBroken = StatusRules.InterruptRepairs(defender);

        // 任一舰沉没：接舷立即解除，不触发俘获判定
        if (initiator.HitPoints <= 0 || defender.HitPoints <= 0)
        {
            initiator.Boarding = null;
            defender.Boarding = null;
            var events = new List<BattleEvent>
            {
                new BoardingDamageEvent(actor.Id, initDmg, initiator.HitPoints, defDmg, defender.HitPoints, Captured: null)
            };
            if (initRepairBroken) events.Add(new RepairsInterruptedEvent(initiator.Id));
            if (defRepairBroken) events.Add(new RepairsInterruptedEvent(defender.Id));
            if (initiator.HitPoints <= 0) events.Add(new ShipSunkEvent(initiator.Id));
            if (defender.HitPoints <= 0) events.Add(new ShipSunkEvent(defender.Id));
            return events.ToArray();
        }

        // 只有原发起方主动消耗动作触发接舷伤害，且双方仍在接舷、进度 > 0，才进行俘获概率判定（设计 11.3）。
        // 防守方触发、进度 0 均不判定；无优势但仍在接舷且保有进度时仍可判定。
        bool? captured = null;
        if (actor.Id == link.InitiatorId && link.CaptureProgress > 0)
        {
            captured = battle.Random.NextDouble() < link.CaptureProgress / 100.0;
            if (captured == true)
            {
                // 俘获成功：目标立即移出战场，不能本场转友军（设计 11.3）
                defender.Captured = true;
                // Task 16：离场前登记，供 BattleResult 分类"被俘"。
                battle.RemovedShips[defender.Id] = new RemovedShipRecord(defender.Definition.Id, defender.Faction, defender.HitPoints, defender.MaxHp, defender.SelfSunk, ShipRemovalReason.Captured);
                // 修复（评审 Important）：移除前登记被俘方阵营"已部署/开战舰数"（与自沉/投降交付移出前登记同模式）。
                // 此前靠 SettleAfterCommand 从 ShipCapturedEvent.CaptorId 反推对侧阵营，未来新增俘获路径需同步；
                // 改在移除点直接登记最简：被俘方唯一舰时否则其阵营从未登记 → 终局永不结束，且 16.2 条件1 分母会偏小。
                BattleEndRules.EnsureDeployedCounts(battle);
                battle.Ships.Remove(defender.Id);
                initiator.Boarding = null;
            }
        }
        var result = new List<BattleEvent>
        {
            new BoardingDamageEvent(actor.Id, initDmg, initiator.HitPoints, defDmg, defender.HitPoints, captured)
        };
        if (initRepairBroken) result.Add(new RepairsInterruptedEvent(initiator.Id));
        if (defRepairBroken) result.Add(new RepairsInterruptedEvent(defender.Id));
        if (captured == true) result.Add(new ShipCapturedEvent(defender.Id, initiator.Id));
        return result.ToArray();
    }

    public static BattleEvent[] ResolveDisengage(BattleState battle, DisengageCommand cmd)
    {
        if (ValidateDisengage(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var ship = battle.ShipOrNull(cmd.ShipId)!;
        var link = ship.Boarding!;
        // 任一方尝试脱离都消耗动作并立即结束该舰本回合（失败同样消耗，设计 11.2）
        ship.HasAttacked = true;
        // 原接舷发起方可必定脱离（无需判定）；防守方按成功率掷随机（设计 11.2）
        var isInitiator = ship.Id == link.InitiatorId;
        var rate = DisengageSuccessRate(battle, ship);
        var success = isInitiator || battle.Random.NextDouble() < rate;
        if (success)
        {
            // 脱离不立即清空俘获进度：转入发起方保留，此后每完整回合降一级（设计 11.2/11.3）
            var initiator = battle.ShipOrNull(link.InitiatorId);
            if (initiator is not null && link.CaptureProgress > 0)
                initiator.RetainedCaptureProgress[link.DefenderId] = link.CaptureProgress;
            var defender = battle.ShipOrNull(link.DefenderId);
            if (initiator is not null) initiator.Boarding = null;
            if (defender is not null) defender.Boarding = null;
        }
        return new BattleEvent[] { new BoardingDisengagedEvent(ship.Id, success, rate) };
    }

    public static BattleEvent[] ResolvePairMove(BattleState battle, BoardPairMoveCommand cmd)
    {
        if (ValidatePairMove(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var defender = battle.ShipOrNull(cmd.ShipId)!;
        var link = defender.Boarding!;
        var initiator = battle.ShipOrNull(link.InitiatorId)!;
        var dir = cmd.Direction.Vector();
        // 组合作为一个整体移动（两舰相对位置锁定），不能转向（设计 11.1）。目标格先算，用于入礁伤害。
        var initiatorCells = initiator.OccupiedCells().Select(c => c + dir).ToList();
        var defenderCells = defender.OccupiedCells().Select(c => c + dir).ToList();
        initiator.Bow = initiatorCells[0];
        defender.Bow = defenderCells[0];
        link.PairMovesUsed += 1;
        // 设计 5.3：通过性2 舰进入礁石"可通行，但损失最大生命15%"（与 MovementRules.TryTranslate / RamRules 同式，无视护甲）
        foreach (var (ship, cells) in new[] { (initiator, initiatorCells), (defender, defenderCells) })
        {
            if (ship.Definition.Passability == Passability.ReefDamaging
                && cells.Any(c => battle.Map.TerrainAt(c) == TerrainType.Reef))
                ship.HitPoints -= (int)Math.Round(ship.MaxHp * 0.15, MidpointRounding.AwayFromZero); // .5 向上（Task 18 B5）
        }
        var events = new List<BattleEvent>
        {
            new BoardingPairMovedEvent(defender.Id, initiator.Bow, defender.Bow, link.PairMovesUsed)
        };
        // Task 12 修复：组合整体平移后，任一舰新占格可能压上/靠近水雷 → 统一刷新探测 + 正常触发（设计 13.1）。
        // 事件并入组合平移命令结果（与 MoveOutcome.MineEvents 同语义）；不阻塞组合平移本身。
        events.AddRange(MineRules.RefreshMines(battle));
        return events.ToArray();
    }

    // —— 回合状态处理（设计 11.3、简报 G）——

    // 任一方舰沉没/被俘/消失时接舷立即解除，幸存舰恢复独立状态（设计 11.1）；被撞击推离等外部事件拉开后
    // 两舰不再相邻（平行+间隔0）同样断链——否则会隔空交换/隔空俘获（评审 Important-1）。所有命令入口统一刷新。
    public static void RefreshBrokenLinks(BattleState battle)
    {
        var links = battle.Ships.Values.Where(s => s.Boarding is not null).Select(s => s.Boarding!).Distinct().ToList();
        foreach (var link in links)
        {
            var initiator = battle.ShipOrNull(link.InitiatorId);
            var defender = battle.ShipOrNull(link.DefenderId);
            if (initiator is null || defender is null
                || initiator.HitPoints <= 0 || defender.HitPoints <= 0
                || initiator.Captured || defender.Captured)
            {
                if (initiator is not null) initiator.Boarding = null;
                if (defender is not null) defender.Boarding = null;
                continue;
            }
            // 两舰不再平行相邻（被推离/其他原因拉开）→ 接舷解除。与脱离一致：俘获进度转入发起方保留，
            // 此后每完整回合降一级（设计 11.2/11.3），重新接舷可继承未衰减完的进度。
            if (IsParallelAdjacent(initiator, defender)) continue;
            if (link.CaptureProgress > 0)
                initiator.RetainedCaptureProgress[link.DefenderId] = link.CaptureProgress;
            initiator.Boarding = null;
            defender.Boarding = null;
        }
    }

    // 防守方组合平移预算（2 格/防守方回合）在本阵营回合开始时重置
    public static void StartFactionTurn(BattleState battle)
    {
        foreach (var ship in battle.Ships.Values)
        {
            var link = ship.Boarding;
            if (link is null || ship.Id != link.DefenderId || ship.Faction != battle.CurrentFaction) continue;
            link.PairMovesUsed = 0;
        }
    }

    // 完整回合边界（Round 递增）：有优势晋级 / 无优势宽限+衰减；脱离后的保留进度逐回合衰减。
    // 返回进度变化事件（无链接时为空，不影响既有 EndTurn 事件流）。
    public static BattleEvent[] ProcessRoundStart(BattleState battle)
    {
        RefreshBrokenLinks(battle);
        var events = new List<BattleEvent>();
        foreach (var link in battle.Ships.Values.Where(s => s.Boarding is not null).Select(s => s.Boarding!).Distinct())
        {
            var initiator = battle.ShipOrNull(link.InitiatorId);
            var defender = battle.ShipOrNull(link.DefenderId);
            if (initiator is null || defender is null || initiator.HitPoints <= 0 || defender.HitPoints <= 0) continue;
            if (HasCaptureAdvantage(battle, link))
            {
                link.NoAdvantageRounds = 0;
                var next = NextTierUp(link.CaptureProgress);
                if (next != link.CaptureProgress)
                {
                    link.CaptureProgress = next;
                    events.Add(new CaptureProgressChangedEvent(link.InitiatorId, link.DefenderId, link.CaptureProgress, "advantage"));
                }
            }
            else
            {
                // 首个无优势完整回合为宽限期（进度不变）；自下一个仍无优势的完整回合起每回合降一级（最低 0）
                link.NoAdvantageRounds += 1;
                if (link.NoAdvantageRounds > 1 && link.CaptureProgress > 0)
                {
                    link.CaptureProgress = Decay(link.CaptureProgress);
                    events.Add(new CaptureProgressChangedEvent(link.InitiatorId, link.DefenderId, link.CaptureProgress, "decay"));
                }
            }
        }
        // 脱离后保留进度：从脱离后的下一个完整回合起每回合降一级，归零移除
        foreach (var ship in battle.Ships.Values)
        {
            if (ship.RetainedCaptureProgress.Count == 0) continue;
            var toRemove = new List<string>();
            foreach (var (targetId, progress) in ship.RetainedCaptureProgress)
            {
                var next = Decay(progress);
                if (next <= 0) toRemove.Add(targetId);
                else ship.RetainedCaptureProgress[targetId] = next;
            }
            foreach (var id in toRemove) ship.RetainedCaptureProgress.Remove(id);
        }
        return events.ToArray();
    }

    // —— 俘获优势与概率（设计 11.3）——

    // 有优势 = 目标被发起方阵营舰船从任意两个不同方向邻接包围，或发起方剩余生命百分比比目标高 >50 个百分点。
    public static bool HasCaptureAdvantage(BattleState battle, BoardingLink link)
    {
        var initiator = battle.ShipOrNull(link.InitiatorId);
        var defender = battle.ShipOrNull(link.DefenderId);
        if (initiator is null || defender is null || initiator.HitPoints <= 0 || defender.HitPoints <= 0) return false;
        if (DirectionalAdjacencyCount(battle, link) >= 2) return true;
        var initiatorPct = (double)initiator.HitPoints / initiator.MaxHp;
        var defenderPct = (double)defender.HitPoints / defender.MaxHp;
        return initiatorPct - defenderPct > HpAdvantageMargin; // 高出 50 个百分点以上（严格大于，简报原文"血差>50"）
    }

    // 防守方脱离成功率 = 50% + (脱离方有效速度档 − 接舷方有效速度档) × 15%，钳制 20%–80%（设计 11.2）
    public static double DisengageSuccessRate(BattleState battle, ShipState disengager)
    {
        var link = disengager.Boarding;
        if (link is null) return DefenderDisengageBaseRate;
        var otherId = disengager.Id == link.InitiatorId ? link.DefenderId : link.InitiatorId;
        var other = battle.ShipOrNull(otherId);
        if (other is null) return DefenderDisengageBaseRate;
        var diff = (int)WeatherRules.EffectiveSpeedTier(battle, disengager) - (int)WeatherRules.EffectiveSpeedTier(battle, other);
        var rate = DefenderDisengageBaseRate + diff * DisengageSpeedTierModifier;
        return Math.Clamp(rate, MinDisengageRate, MaxDisengageRate);
    }

    // 发起资格：两舰平行（朝向相同或相反）且间隔 0（最近占格距离 1，即贴在一起）
    public static bool IsParallelAdjacent(ShipState a, ShipState b)
    {
        if (a.Facing != b.Facing && a.Facing != b.Facing.Opposite()) return false;
        return GeometryRules.NearestSquaredDistance(a.OccupiedCells(), b.OccupiedCells()) == 1;
    }

    // —— 内部辅助 ——

    // 固定接舷伤害：各自舰型规定的 BoardingDamage，无视护甲（设计 11.1/8）
    private static int BoardingDamage(BattleState battle, ShipState ship)
        => DamageRules.Calculate(new DamagePacket(ship.Definition.BoardingDamage, ship.ArmorLevel, IgnoresArmor: true)).FinalDamage;

    // 正交邻接计数：目标占格被发起方阵营舰船从几个不同方向邻接（各方向一舰即计 1）
    private static int DirectionalAdjacencyCount(BattleState battle, BoardingLink link)
    {
        var initiator = battle.ShipOrNull(link.InitiatorId)!;
        var defender = battle.ShipOrNull(link.DefenderId)!;
        var defenderCells = defender.OccupiedCells().ToHashSet();
        var count = 0;
        foreach (var d in new[] { CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West })
        {
            var v = d.Vector();
            var adjacent = battle.Ships.Values.Any(s =>
                s.HitPoints > 0 && s.Faction == initiator.Faction
                && s.OccupiedCells().Any(c => defenderCells.Contains(c + v)));
            if (adjacent) count++;
        }
        return count;
    }

    // 递增按档位跳（0→25→50→100，跳过 75）；衰减逐级 25（100→75→50→25→0）
    private static int NextTierUp(int progress) => progress switch
    {
        < 25 => 25,
        < 50 => 50,
        _ => 100
    };

    private static int Decay(int progress) => Math.Max(0, progress - ProgressStep);
}
