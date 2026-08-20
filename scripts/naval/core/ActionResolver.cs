#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

public sealed record ActionResult(bool Success, string? Reason, IReadOnlyList<BattleEvent> Events)
{
    public static ActionResult Ok(params BattleEvent[] events) => new(true, null, events);
    public static ActionResult Rejected(string reason) => new(false, reason, Array.Empty<BattleEvent>());
}

public static class ActionResolver
{
    public static ActionResult TryExecute(BattleState battle, BattleCommand command)
    {
        // 任一舰沉没/被俘时接舷立即解除，幸存舰恢复独立状态（设计 11.1）：所有命令入口统一刷新失效链接
        BoardingRules.RefreshBrokenLinks(battle);
        var result = command switch
        {
            MoveCommand move => Move(battle, move),
            TurnCommand turn => Turn(battle, turn),
            MarkAttackCommand attack => MarkAttack(battle, attack),
            ArrowRainCommand rain => ArrowRain(battle, rain),
            BombardmentCommand bomb => Bombardment(battle, bomb),
            CannonCommand cannon => Cannon(battle, cannon),
            RamCommand ram => Ram(battle, ram),
            BoardCommand board => Board(battle, board),
            BoardingExchangeCommand exchange => BoardingExchange(battle, exchange),
            DisengageCommand disengage => Disengage(battle, disengage),
            BoardPairMoveCommand pairMove => BoardPairMove(battle, pairMove),
            ChainShotCommand chainShot => ChainShot(battle, chainShot),
            FireOilCommand fireOil => FireOil(battle, fireOil),
            DamageControlCommand damageControl => DamageControl(battle, damageControl),
            PlaceMineCommand placeMine => PlaceMine(battle, placeMine),
            SelfSinkCommand selfSink => SelfSink(battle, selfSink),
            // Task 15：指挥舰/投降（设计 16.2/16.3）。投降命令不走舰船动作，由 SurrenderRules 校验+结算，
            // 结算后的终局判定由下方统一 SettleAfterCommand 处理（敌降 → 敌方无留场舰 → 战斗结束）。
            OfferSurrenderCommand offer => SurrenderRules.ResolveOffer(battle, offer.OfferingFaction),
            AcceptSurrenderCommand accept => SurrenderRules.ResolveAccept(battle, accept),
            RejectSurrenderCommand => SurrenderRules.ResolveReject(battle),
            EndFactionTurnCommand => EndTurn(battle),
            // CHG（海怪 Boss 战）：海怪01 触手与移动命令。
            TentacleStrikeCommand tentacle => Tentacle(battle, tentacle),
            MonsterDeclareMoveCommand monsterDeclare => MonsterDeclare(battle, monsterDeclare),
            MonsterMoveCommand monsterMove => MonsterMove(battle, monsterMove),
            FishChargeCommand fishCharge => FishCharge(battle, fishCharge),
            FishLeapMoveCommand fishLeap => FishLeap(battle, fishLeap),
            _ => ActionResult.Rejected("action.unsupported")
        };
        // Task 14：每条成功命令结算后统一处理 逃跑/残骸/终局（设计 15/16.1）。
        // 挂在 ActionResolver 单一出口：覆盖任意沉没/移除路径（范围攻击/撞击/接舷/烧伤/水雷爆炸/逃脱/俘获）。
        return BattleEndRules.SettleAfterCommand(battle, result);
    }

    // —— 海怪01 命令（Task 4，设计 sea-monster-boss）——
    private static ActionResult Tentacle(BattleState battle, TentacleStrikeCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = SeaMonsterRules.ValidateTentacleStrike(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = SeaMonsterRules.ResolveTentacleStrike(battle, cmd);
        ship.HasAttacked = true;
        return ActionResult.Ok(events);
    }
    // 移动预告：免费动作，不置 HasAttacked（海怪回合内可先触手、再预告）。
    private static ActionResult MonsterDeclare(BattleState battle, MonsterDeclareMoveCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = SeaMonsterRules.ValidateDeclareMove(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        return ActionResult.Ok(SeaMonsterRules.ResolveDeclareMove(battle, cmd));
    }
    private static ActionResult MonsterMove(BattleState battle, MonsterMoveCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = SeaMonsterRules.ValidateMonsterMove(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = SeaMonsterRules.ResolveMonsterMove(battle, cmd);
        ship.HasAttacked = true;
        return ActionResult.Ok(events);
    }

    // —— 海怪02 命令（Task 6，设计 sea-monster-boss）——
    private static ActionResult FishCharge(BattleState battle, FishChargeCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = FishSchoolRules.ValidateCharge(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = FishSchoolRules.ResolveCharge(battle, cmd);
        ship.HasAttacked = true;
        return ActionResult.Ok(events);
    }
    private static ActionResult FishLeap(BattleState battle, FishLeapMoveCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = FishSchoolRules.ValidateLeap(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = FishSchoolRules.ResolveLeap(battle, cmd);
        ship.HasAttacked = true;
        return ActionResult.Ok(events);
    }

    private static ActionResult Move(BattleState battle, MoveCommand command)
    {
        var ship = OwnedShip(battle, command.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        if (ship.Boarding is not null) return ActionResult.Rejected("boarding.locked"); // 接舷中组合为一个整体，禁单独平移
        var outcome = MovementRules.TryTranslate(battle, ship, command.Direction);
        if (!outcome.Success) return ActionResult.Rejected(outcome.Reason ?? "action.failed");
        var events = new List<BattleEvent> { new ShipMovedEvent(ship.Id, ship.Bow, ship.RemainingMovement) };
        // Task 12：成功平移后触雷/探测事件并入事件流（设计 13.1；水雷不阻塞移动本身）
        if (outcome.MineEvents is not null) events.AddRange(outcome.MineEvents);
        // 舰船可见性为几何判定，表现层直接查询 AttackRules.VisibleEnemies，无需在移动时发揭示事件。
        return ActionResult.Ok(events.ToArray());
    }

    private static ActionResult Turn(BattleState battle, TurnCommand command)
    {
        var ship = OwnedShip(battle, command.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        if (ship.Boarding is not null) return ActionResult.Rejected("boarding.locked"); // 接舷组合不能转向（设计 11.1）
        var outcome = MovementRules.TryTurn(battle, ship, command.Direction);
        if (!outcome.Success) return ActionResult.Rejected(outcome.Reason ?? "action.failed");
        var events = new List<BattleEvent> { new ShipTurnedEvent(ship.Id, ship.Facing, ship.RemainingMovement) };
        // Task 12 修复：转向后新占格触雷/探测事件并入事件流（与 Move 的 outcome.MineEvents 同语义；水雷不阻塞转向本身）
        if (outcome.MineEvents is not null) events.AddRange(outcome.MineEvents);
        return ActionResult.Ok(events.ToArray());
    }

    // 三种远程攻击：合法即结算（含未命中盲射），结算后本回合不能再移动/攻击
    private static ActionResult ArrowRain(BattleState battle, ArrowRainCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = AttackRules.ValidateArrowRain(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = AttackRules.ResolveArrowRain(battle, cmd);
        ship.HasAttacked = true;
        return ActionResult.Ok(events);
    }

    private static ActionResult Bombardment(BattleState battle, BombardmentCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = AttackRules.ValidateBombardment(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = AttackRules.ResolveBombardment(battle, cmd);
        ship.HasAttacked = true;
        return ActionResult.Ok(events);
    }

    private static ActionResult Cannon(BattleState battle, CannonCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = AttackRules.ValidateCannon(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = AttackRules.ResolveCannon(battle, cmd);
        ship.HasAttacked = true;
        return ActionResult.Ok(events);
    }

    // 撞击（Task 9，设计 10）：玩家主动选择的攻击动作；资格校验后结算，成功后本回合不能再动/再攻击
    private static ActionResult Ram(BattleState battle, RamCommand cmd)
    {
        var reason = RamRules.Validate(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = RamRules.Resolve(battle, cmd);
        battle.ShipOrNull(cmd.ShipId)!.HasAttacked = true;
        return ActionResult.Ok(events);
    }

    // Task 10：接舷/交换/脱离/组合移动（设计 11）。校验拒绝不消耗动作；结算成功按设计消耗动作/预算。
    private static ActionResult Board(BattleState battle, BoardCommand cmd)
    {
        var reason = BoardingRules.ValidateBoard(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        return ActionResult.Ok(BoardingRules.ResolveBoard(battle, cmd));
    }

    private static ActionResult BoardingExchange(BattleState battle, BoardingExchangeCommand cmd)
    {
        var reason = BoardingRules.ValidateExchange(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        return ActionResult.Ok(BoardingRules.ResolveExchange(battle, cmd));
    }

    private static ActionResult Disengage(BattleState battle, DisengageCommand cmd)
    {
        var reason = BoardingRules.ValidateDisengage(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        return ActionResult.Ok(BoardingRules.ResolveDisengage(battle, cmd));
    }

    private static ActionResult BoardPairMove(BattleState battle, BoardPairMoveCommand cmd)
    {
        var reason = BoardingRules.ValidatePairMove(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        return ActionResult.Ok(BoardingRules.ResolvePairMove(battle, cmd));
    }

    // Task 11：技能（设计 12）。合法即结算（连锁弹/火油含盲射落空仍结算消耗，与远程攻击一致），
    // 结算成功消耗本回合动作（HasAttacked = true，损管同样视为消耗动作）。
    private static ActionResult ChainShot(BattleState battle, ChainShotCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = StatusRules.ValidateChainShot(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = StatusRules.ResolveChainShot(battle, cmd);
        ship.HasAttacked = true;
        return ActionResult.Ok(events);
    }

    private static ActionResult FireOil(BattleState battle, FireOilCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = StatusRules.ValidateFireOil(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = StatusRules.ResolveFireOil(battle, cmd);
        ship.HasAttacked = true;
        return ActionResult.Ok(events);
    }

    private static ActionResult DamageControl(BattleState battle, DamageControlCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = StatusRules.ValidateDamageControl(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = StatusRules.ResolveDamageControl(battle, cmd);
        ship.HasAttacked = true;
        return ActionResult.Ok(events);
    }

    // Task 12：布雷（设计 13.1）。校验拒绝不消耗动作/次数；成功消耗 1 次并置 HasAttacked。
    private static ActionResult PlaceMine(BattleState battle, PlaceMineCommand cmd)
    {
        var ship = OwnedShip(battle, cmd.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        var reason = MineRules.ValidatePlace(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        var events = MineRules.ResolvePlace(battle, cmd);
        ship.HasAttacked = true; // 放置消耗本舰攻击动作（设计 13.1）
        return ActionResult.Ok(events);
    }

    // Task 14：主动自沉（设计 15）。校验拒绝不消耗动作；结算后由 TryExecute 统一做残骸/逃跑/终局处理。
    private static ActionResult SelfSink(BattleState battle, SelfSinkCommand cmd)
    {
        var reason = BattleEndRules.ValidateSelfSink(battle, cmd);
        if (reason is not null) return ActionResult.Rejected(reason);
        return ActionResult.Ok(BattleEndRules.ResolveSelfSink(battle, cmd));
    }

    private static ActionResult MarkAttack(BattleState battle, MarkAttackCommand command)
    {
        var ship = OwnedShip(battle, command.ShipId);
        if (ship is null) return ActionResult.Rejected("action.unknown_ship");
        ship.HasAttacked = true;
        return ActionResult.Ok(new ShipMarkedAttackEvent(ship.Id));
    }

    private static ActionResult EndTurn(BattleState battle)
    {
        battle.CurrentFaction = battle.CurrentFaction == FactionId.Player ? FactionId.Enemy : FactionId.Player;
        // 防守方组合平移预算（2 格/防守方回合）在本阵营回合开始时重置（设计 11.1）
        BoardingRules.StartFactionTurn(battle);
        // Task 11：新阵营回合开始结算持续状态（烧伤伤害+熄灭、损管回血、连锁弹计时递减，设计 12）
        var statusEvents = StatusRules.ProcessFactionTurnStart(battle, battle.CurrentFaction);
        if (battle.CurrentFaction == FactionId.Player)
        {
            battle.Round += 1;
            // CHG（海怪 Boss 战）：海怪冷却减 1 + 鱼群回合计数。
            SeaMonsterRules.ProcessTurnStart(battle);
            // 海怪02：敌方回合结束（CurrentFaction 翻转为 Player）触发猎杀循环推进 + 冲撞/飞越标记清零，
            // 与 SeaMonsterRules.ProcessTurnStart 同一边界挂接（评审 Important-3：此前注释声明挂接但未实际接线）。
            FishSchoolRules.ProcessTurnStart(battle);
            // F-1：完整回合边界（双方各行动一轮）→ 台风回合末伤害（设计 6）。晴天/阴/雨为空操作。
            WeatherRules.TyphoonRoundEnd(battle);
            foreach (var s in battle.Ships.Values)
            {
                s.HasAttacked = false;
                s.RemainingMovement = WeatherRules.CurrentMovementPoints(battle, s);
                s.SpentMovement = 0;
                s.TurnStartBow = s.Bow; // F-1：新回合拍风向修正起点快照
                s.LastMoveDirection = null; // 撞击资格为回合内状态，回合刷新清空（设计 10）
            }
            // 完整回合边界：接舷进度晋级/宽限/衰减 + 保留进度衰减 + 沉没解除（设计 11.3、简报 G）。无链接时为空。
            var boardingEvents = BoardingRules.ProcessRoundStart(battle);
            // Task 15：投降层数调整 + 未决投降作废（设计 16.2）——条件仍成立层数+1、失效-1，最低 0 封顶 4。
            var surrenderEvents = SurrenderRules.ProcessRoundEnd(battle);
            // V-3（CHG-20260810-fx-vision-recall）：视野滞留推进——完整回合边界（玩家回合开始）。
            // 当前可见格置新鲜度 0，不在当前视野的滞留格新鲜度 +1，超过 3 移除归为迷雾；重新进入视野重置。
            AttackRules.AdvanceVisionRecall(battle);
            return ActionResult.Ok(
                new BattleEvent[] { new FactionTurnEndedEvent(FactionId.Enemy), new RoundAdvancedEvent(battle.Round) }
                .Concat(boardingEvents).Concat(surrenderEvents).Concat(statusEvents).ToArray());
        }
        // 敌方回合重置（AI 用）
        foreach (var s in battle.Ships.Values.Where(s => s.Faction == FactionId.Enemy))
        {
            s.HasAttacked = false;
            s.RemainingMovement = WeatherRules.CurrentMovementPoints(battle, s);
            s.SpentMovement = 0;
            s.TurnStartBow = s.Bow; // F-1：敌方回合拍风向修正起点快照
            s.LastMoveDirection = null; // 撞击资格为回合内状态，回合刷新清空（设计 10）
        }
        // Task 15 修复（审查 Important-1）：玩家回合结束 → 劝降应答窗口关闭 → 未决投降作废。
        // 敌方在己方回合内劝降成功 → 玩家整回合可接受/拒绝（不再被敌方 EndTurn 完整回合边界立即作废，见 SurrenderRules.ProcessPlayerTurnEnd）。
        SurrenderRules.ProcessPlayerTurnEnd(battle);
        return ActionResult.Ok(
            new BattleEvent[] { new FactionTurnEndedEvent(FactionId.Player) }.Concat(statusEvents).ToArray());
    }

    // 移动范围预览：以船头为锚点，按剩余移动点在四方向做 BFS（逐格最短步数可达）。
    // 每一步复用 MovementRules.FootprintValid 校验完整舰体，障碍地形、残骸与其它舰船不会被染成可移动蓝格。
    public static List<GridPos> QueryMoveRange(BattleState battle, string shipId)
    {
        var ship = battle.ShipOrNull(shipId);
        if (ship is null || ship.HasAttacked || ship.SelfSunk || ship.Boarding is not null) return new List<GridPos>();
        var result = new List<GridPos> { ship.Bow };
        var seen = new HashSet<GridPos> { ship.Bow };
        var queue = new Queue<(GridPos Pos, int Left)>();
        queue.Enqueue((ship.Bow, ship.RemainingMovement));
        while (queue.Count > 0)
        {
            var (pos, left) = queue.Dequeue();
            if (left <= 0) continue;
            foreach (var d in new[] { CardinalDirection.North, CardinalDirection.South, CardinalDirection.East, CardinalDirection.West })
            {
                var next = pos + d.Vector();
                if (!seen.Add(next)) continue;
                var footprint = ShipGeometry.Footprint(ship.Definition, next, ship.Facing);
                if (!MovementRules.FootprintValid(battle, footprint, ship)) continue;
                result.Add(next);
                queue.Enqueue((next, left - 1));
            }
        }
        // 自身占格不显示在移动范围高亮中（舰体本身无需提示；T8 遗留：覆盖含自身占格可排除自身）
        result.RemoveAll(c => ship.OccupiedCells().Contains(c));
        return result;
    }

    // UX-10：区域移动最短路径——从船头到目标格按四方向 BFS（逐格最短步数，设计 5.1 只正交平移）。
    // 返回从船头到目标格的连续格序列（含两端）；不可达返回空列表。
    // 与 QueryMoveRange 同样考虑完整阻挡；本方法额外返回一条实际最短路径，供区域移动逐格执行。
    // 多格舰脚印约束无法被单格 BFS 完全表达 → 每步仍由规则层 TryExecute 复刻校验，被拒即停在最后合法格（双保险）。
    public static List<GridPos> QueryMovePath(BattleState battle, ShipState ship, GridPos target)
    {
        var path = new List<GridPos>();
        if (ship is null || ship.HasAttacked || ship.SelfSunk || ship.Boarding is not null) return path;
        if (!battle.Map.InBounds(target)) return path;
        var start = ship.Bow;
        if (start == target) { path.Add(start); return path; }
        var prev = new Dictionary<GridPos, GridPos>();
        var seen = new HashSet<GridPos> { start };
        var queue = new Queue<GridPos>();
        queue.Enqueue(start);
        while (queue.Count > 0)
        {
            var pos = queue.Dequeue();
            foreach (var d in new[] { CardinalDirection.North, CardinalDirection.South, CardinalDirection.East, CardinalDirection.West })
            {
                var next = pos + d.Vector();
                // 目标格即使被挡也返回路径：由规则层拒绝最后一步 → 停在最后合法格（需求：路径上某格不可走则停）。
                if (next == target)
                {
                    prev[next] = pos;
                    var cells = new List<GridPos>();
                    var cur = target;
                    while (cur != start) { cells.Add(cur); cur = prev[cur]; }
                    cells.Add(start);
                    cells.Reverse();
                    return cells;
                }
                if (!seen.Add(next)) continue;
                if (CellBlocksMove(battle, ship, next)) continue;
                prev[next] = pos;
                queue.Enqueue(next);
            }
        }
        return path;
    }

    // 区域移动 BFS 的单格阻挡判定：越界/残骸/不可通行地形/其它存活舰占格（与 MovementRules.FootprintValid 同口径的单格版）。
    private static bool CellBlocksMove(BattleState battle, ShipState mover, GridPos cell)
    {
        if (!battle.Map.InBounds(cell)) return true;
        if (battle.Map.IsWreck(cell)) return true;
        var t = battle.Map.TerrainAt(cell);
        // U-2a：陆地恒挡；深水限定舰不可进浅水（浅滩/礁石/陆河），经 TerrainRules 统一判定。
        if (TerrainRules.BlocksShip(t, mover.Definition.Passability)) return true;
        foreach (var other in battle.Ships.Values)
            if (other.Id != mover.Id && other.HitPoints > 0 && other.OccupiedCells().Contains(cell))
                return true;
        return false;
    }

    private static ShipState? OwnedShip(BattleState battle, string id)
    {
        var ship = battle.ShipOrNull(id);
        if (ship is null || ship.Faction != battle.CurrentFaction || ship.HitPoints <= 0)
            return null;
        return ship;
    }
}
