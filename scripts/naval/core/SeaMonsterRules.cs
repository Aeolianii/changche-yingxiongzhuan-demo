#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// 海怪移动预告：Path 计划路径（含终点），SurfaceMove=true 水面移动（仅二阶段）。
public sealed record MonsterMovePreview(GridPos[] Path, bool SurfaceMove);

// 海怪01（触手怪）规则：两阶段触手攻击 + 水下/水面移动（预告→执行）。
// 裁定（CHG 海怪 Boss 战）：伤害基准 = 质量×20；系数见常量；伤害经目标护甲减免。
public static class SeaMonsterRules
{
    public const double BaseDamagePerMass = 20.0;   // 伤害基准 = 质量×20（海怪01 质量10 → 200）
    public const double MultiThreeCoeff = 0.3;      // 一阶段触手：线内每目标 0.3
    public const double SingleFiveCoeff = 0.5;      // 单体触手：单目标 0.5（一阶段/二阶段皆可用）
    public const double SurfaceMoveCoeff = 0.9;     // 二阶段水面路径格伤害系数
    public const double SubmergedMoveCoeff = 1.2;   // 二阶段水下落点格伤害系数
    public const int Phase1MoveRange = 8;           // 一阶段水下移动 8 格
    public const int Phase2SurfaceRange = 6;        // 二阶段水面移动 6 格
    public const int Phase2SubmergedRange = 4;      // 二阶段水下移动 ≤4 格
    public const int Phase1MoveInterval = 2;        // 一阶段每 2 回合移动一次
    public const int Phase2SubmergedCooldown = 2;   // 二阶段水下移动后冷却 2 回合
    public const int TentacleRange = 2;             // 触手线首格距海怪 ≤2
    public const int PushDistance = 1;              // 水下落点相邻舰推开 1 格

    public static bool IsMonster(ShipState ship) => ship.HitPoints > 0 && ship.Definition.IsSeaMonster;

    // 阶段：> 半血 = 1；≤ 半血 = 2。
    public static int PhaseOf(ShipState monster) => monster.HitPoints > monster.MaxHp / 2 ? 1 : 2;

    // —— 触手 ——

    public static string? ValidateTentacleStrike(BattleState battle, TentacleStrikeCommand cmd)
    {
        if (!battle.Ships.TryGetValue(cmd.ShipId, out var m) || !IsMonster(m) || m.SelfSunk)
            return "sea_monster.unknown_or_inactive";
        if (m.HasAttacked) return "sea_monster.already_acted";
        var phase = PhaseOf(m);
        if (cmd.Kind == TentacleKind.MultiThree && phase != 1) return "sea_monster.multi_three_phase1_only";
        // 用户裁决：SingleFive 一阶段/二阶段皆可用（一阶段目标=1 时作单体远程触手）；不再锁定仅二阶段。
        var cells = LineCells(battle, m, cmd.Target, LineLength(cmd.Kind));
        if (cells is null) return "sea_monster.tentacle_line_invalid";
        // 按舰去重：多格舰（长2朝东/西）占两个相邻线格时 ShipAt 会命中同一舰两次，只计一次（保留更近实例）。
        var targets = cells.Select(c => ShipAt(battle, c)).Where(s => s is not null).Distinct().ToList();
        if (cmd.Kind == TentacleKind.MultiThree && targets.Count < 2) return "sea_monster.multi_three_needs_two";
        if (cmd.Kind == TentacleKind.SingleFive && targets.Count < 1) return "sea_monster.single_five_needs_target";
        return null;
    }

    public static BattleEvent[] ResolveTentacleStrike(BattleState battle, TentacleStrikeCommand cmd)
    {
        var err = ValidateTentacleStrike(battle, cmd);
        if (err is not null) return Array.Empty<BattleEvent>();
        var m = battle.Ships[cmd.ShipId];
        var coeff = cmd.Kind == TentacleKind.MultiThree ? MultiThreeCoeff : SingleFiveCoeff;
        var cells = LineCells(battle, m, cmd.Target, LineLength(cmd.Kind))!;
        // 同校验：按舰去重，多格舰只受一次伤害。
        var targets = cells.Select(c => ShipAt(battle, c)).Where(s => s is not null).Distinct().ToList();
        if (cmd.Kind == TentacleKind.SingleFive)
            targets = new List<ShipState?> { targets.OrderByDescending(s => s!.HitPoints).ThenBy(s => s!.Id).First() };
        m.HasAttacked = true;
        m.LastMoveDirection = null;
        var evs = new List<BattleEvent>();
        foreach (var t in targets)
        {
            var dmg = DamageRules.Calculate(new DamagePacket(m.Definition.Mass * BaseDamagePerMass * coeff, t!.ArmorLevel, IgnoresArmor: false)).FinalDamage;
            t.HitPoints -= dmg;
            evs.Add(new TentacleStrikeEvent(t.Id, cmd.Target, cmd.Kind, dmg, t.HitPoints));
            if (t.HitPoints <= 0) evs.Add(new ShipSunkEvent(t.Id));
        }
        return evs.ToArray();
    }

    // —— 移动预告（免费）——

    public static string? ValidateDeclareMove(BattleState battle, MonsterDeclareMoveCommand cmd)
    {
        if (!battle.Ships.TryGetValue(cmd.ShipId, out var m) || !IsMonster(m) || m.SelfSunk)
            return "sea_monster.unknown_or_inactive";
        if (m.PendingMonsterMovePreview is not null) return "sea_monster.already_previewed";
        if (m.MonsterNoMoveRoundsLeft > 0) return "sea_monster.on_cooldown";
        if (cmd.Path is not { Length: >= 1 }) return "sea_monster.empty_path";
        var range = PhaseOf(m) == 1 ? Phase1MoveRange : cmd.SurfaceMove ? Phase2SurfaceRange : Phase2SubmergedRange;
        if (cmd.Path[^1].SquaredDistance(m.Bow) > range * range) return "sea_monster.move_out_of_range";
        if (!ValidWaterCells(battle, cmd.Path, cmd.SurfaceMove)) return "sea_monster.path_not_water";
        return null;
    }

    public static BattleEvent[] ResolveDeclareMove(BattleState battle, MonsterDeclareMoveCommand cmd)
    {
        var err = ValidateDeclareMove(battle, cmd);
        if (err is not null) return Array.Empty<BattleEvent>();
        var m = battle.Ships[cmd.ShipId];
        m.PendingMonsterMovePreview = new MonsterMovePreview(cmd.Path, cmd.SurfaceMove);
        m.MonsterDeclaredPreview = true; // 本回合已预告：AI 不得同回合执行，下回合才执行
        return new BattleEvent[] { new MonsterMovePreviewedEvent(cmd.ShipId, cmd.Path, cmd.SurfaceMove) };
    }

    // —— 移动执行（占动作）——

    public static string? ValidateMonsterMove(BattleState battle, MonsterMoveCommand cmd)
    {
        if (!battle.Ships.TryGetValue(cmd.ShipId, out var m) || !IsMonster(m) || m.SelfSunk)
            return "sea_monster.unknown_or_inactive";
        if (m.PendingMonsterMovePreview is not { } pv) return "sea_monster.no_preview";
        if (pv.Path[^1] != cmd.Destination) return "sea_monster.preview_mismatch";
        // 终点须为合法水域（水面=可礁行；水下=深水）。预告在上回合已过水域校验，此处对落点复核（防直达落点越界/落点被改）。
        var t = battle.Map.TerrainAt(cmd.Destination);
        if (TerrainRules.BlocksShip(t, pv.SurfaceMove ? Passability.ReefDamaging : Passability.DeepWaterOnly))
            return "sea_monster.path_not_water";
        return null;
    }

    public static BattleEvent[] ResolveMonsterMove(BattleState battle, MonsterMoveCommand cmd)
    {
        var err = ValidateMonsterMove(battle, cmd);
        if (err is not null) return Array.Empty<BattleEvent>();
        var m = battle.Ships[cmd.ShipId];
        var pv = m.PendingMonsterMovePreview!;
        m.PendingMonsterMovePreview = null;
        m.MonsterDeclaredPreview = false; // 已执行
        m.HasAttacked = true;
        m.LastMoveDirection = null;
        var damages = new List<int>();
        var evs = new List<BattleEvent>();
        var phase = PhaseOf(m);
        // 二阶段水面：路径格伤害 base×0.9（一阶段移动纯位移，不攻击舰船）。
        if (pv.SurfaceMove && phase == 2)
            foreach (var cell in pv.Path)
                if (ShipAt(battle, cell) is { } s && s.Faction != m.Faction && s.HitPoints > 0)
                    damages.Add(DamageShip(battle, evs, m, s, SurfaceMoveCoeff, cell));
        // 二阶段水下：落点格 base×1.2 + 相邻舰推开 1 格。
        if (!pv.SurfaceMove && phase == 2)
        {
            if (ShipAt(battle, cmd.Destination) is { } d && d.Faction != m.Faction && d.HitPoints > 0)
                damages.Add(DamageShip(battle, evs, m, d, SubmergedMoveCoeff, cmd.Destination));
            foreach (var s in battle.Ships.Values.Where(s => s.Faction != m.Faction && s.HitPoints > 0))
                foreach (var cell in s.OccupiedCells())
                    if (cell.SquaredDistance(cmd.Destination) == 1 && !s.Definition.Immovable)
                    { TryPushAway(battle, evs, m, s, cmd.Destination); break; }
        }
        // 一阶段水下：纯位移。
        m.Bow = cmd.Destination;
        m.Facing = CardinalDirection.North; // 水下移动后朝向北（无朝向语义）
        m.MonsterNoMoveRoundsLeft = phase == 1 ? Phase1MoveInterval - 1 : pv.SurfaceMove ? 0 : Phase2SubmergedCooldown;
        evs.Add(new MonsterMovedEvent(m.Id, cmd.Destination, pv.SurfaceMove, damages.ToArray()));
        return evs.ToArray();
    }

    // —— 回合边界 ——

    // 冷却减 1（每完整回合一次；回合边界挂 EndTurn 玩家回合分支）。
    public static void ProcessTurnStart(BattleState battle)
    {
        foreach (var s in battle.Ships.Values.Where(IsMonster))
        {
            if (s.MonsterNoMoveRoundsLeft > 0) s.MonsterNoMoveRoundsLeft -= 1;
            s.MonsterDeclaredPreview = false; // 新回合开始：预告视为"上回合声明"，本回合可执行
        }
    }

    // —— 辅助 ——

    private static int LineLength(TentacleKind kind) => kind == TentacleKind.MultiThree ? 3 : 5;

    // 触手线：以 Target 为线首，沿"海怪→Target"反方向延伸 len 格；线首距海怪 ≤ TentacleRange。
    // 返回 null = 线不合法（越界/陆地/线首过远）。
    private static List<GridPos>? LineCells(BattleState battle, ShipState m, GridPos target, int len)
    {
        var monsterCells = m.OccupiedCells();
        if (monsterCells.Min(c => c.SquaredDistance(target)) > TentacleRange * TentacleRange) return null;
        var dir = (target - NearestMonsterCell(monsterCells, target)).ToDir();
        if (dir is null) return null;
        var cells = new List<GridPos>();
        for (var i = 0; i < len; i++)
        {
            var cell = target + dir.Value.Vector() * i;
            if (!battle.Map.InBounds(cell)) return null;
            if (TerrainRules.BlocksShip(battle.Map.TerrainAt(cell), Passability.FreeAll)) return null;
            cells.Add(cell);
        }
        return cells;
    }

    private static GridPos NearestMonsterCell(List<GridPos> monsterCells, GridPos target)
        => monsterCells.OrderBy(c => c.SquaredDistance(target)).First();

    private static ShipState? ShipAt(BattleState battle, GridPos cell)
        => battle.Ships.Values.FirstOrDefault(s => s.HitPoints > 0 && s.OccupiedCells().Contains(cell));

    private static bool ValidWaterCells(BattleState battle, IReadOnlyList<GridPos> cells, bool surface)
    {
        foreach (var cell in cells)
        {
            if (!battle.Map.InBounds(cell)) return false;
            // 水面：深水/浅滩；水下：深水。
            var t = battle.Map.TerrainAt(cell);
            if (TerrainRules.BlocksShip(t, surface ? Passability.ReefDamaging : Passability.DeepWaterOnly)) return false;
        }
        return true;
    }

    private static int DamageShip(BattleState battle, List<BattleEvent> evs, ShipState attacker, ShipState target, double coeff, GridPos at)
    {
        var dmg = DamageRules.Calculate(new DamagePacket(attacker.Definition.Mass * BaseDamagePerMass * coeff, target.ArmorLevel, IgnoresArmor: false)).FinalDamage;
        target.HitPoints -= dmg;
        evs.Add(new AreaDamageEvent(at, target.Id, dmg, target.HitPoints));
        if (target.HitPoints <= 0) evs.Add(new ShipSunkEvent(target.Id));
        return dmg;
    }

    // 推开：目标沿"落点→目标"方向移 1 格；目标格合法才推。
    private static void TryPushAway(BattleState battle, List<BattleEvent> evs, ShipState attacker, ShipState target, GridPos from)
    {
        var away = target.Bow + (target.Bow - from).ToDir()?.Vector() ?? target.Bow;
        var newCells = ShipGeometry.Footprint(target.Definition, away, target.Facing);
        if (!MovementRules.FootprintValid(battle, newCells, target)) return;
        target.Bow = away;
    }
}
