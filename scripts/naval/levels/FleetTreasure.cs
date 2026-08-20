#nullable enable
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Godot;

namespace NavalCombat.Levels;

// CHG（海怪 Boss 战）：讨伐专属宝物。
public enum TreasureId { SeaMonsterHorn, SunPiercingSpear, WokouBanner }

// 宝物静态描述：Effect 为表现层展示的增益文案（规则层效果由引用方按 Id 落实）。
public sealed record FleetTreasure(TreasureId Id, string DisplayName, string Description, string Effect);

// CHG-20260819（F-1 讨伐饰品）：宝物 → 经济背包饰品 id 映射（economy_state.accessories.owned 同值）。
public static class FleetTreasureAccessoryIds
{
    public const string SeaMonsterHorn = "sea_monster_horn";
    public const string SunPiercingSpear = "sun_piercing_spear";
    public const string WokouBanner = "wokou_banner";

    public static string? For(TreasureId id) => id switch
    {
        TreasureId.SeaMonsterHorn => SeaMonsterHorn,
        TreasureId.SunPiercingSpear => SunPiercingSpear,
        TreasureId.WokouBanner => WokouBanner,
        _ => null,
    };
}

public static class FleetTreasureRegistry
{
    public static IReadOnlyList<FleetTreasure> All { get; } = new[]
    {
        new FleetTreasure(TreasureId.SeaMonsterHorn, "海怪之角", "取自深海触手怪之角。",
            "旗舰撞角升级至 Lv4（系数 1.8），限装备 1 件。"),
        new FleetTreasure(TreasureId.SunPiercingSpear, "贯日神枪", "倭寇镇国之宝。",
            "旗舰砲击升级至 Lv4（420 伤害）。"),
        new FleetTreasure(TreasureId.WokouBanner, "倭寇军旗", "敌方大本营缴获的战旗。",
            "全舰队射程 +1 格（含箭雨/砲击/火炮/连锁弹/火油）。"),
    };

    public static FleetTreasure GetById(TreasureId id) => All.First(t => t.Id == id);
}

// 舰队宝物库存：讨伐胜利 Collect + Save（user://treasures.json）；表现层据 Has 配置 BattleState.RangeBonus（军旗→+1）。
// 参照 LevelProgress/FleetPresetStore 的 JSON 存档模式（DTO record + System.Text.Json + 目录 Ensure + 异常容忍默认值）。
// 单例 Instance 惰性装配：仅表现层（Godot 运行环境）访问，路径经 ProjectSettings.GlobalizePath 解析 user://；
// 测试用独立 new FleetTreasureInventory(临时路径) 往返，不触碰 Godot/真实 user://。
public sealed class FleetTreasureInventory
{
    private const string SaveFile = "user://treasures.json";
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };

    private readonly HashSet<TreasureId> _owned = new();
    private readonly string _savePath;

    private static FleetTreasureInventory? _instance;
    public static FleetTreasureInventory Instance => _instance ??= Load();

    // savePath：JSON 保存的 OS 路径（应用侧 GlobalizePath("user://treasures.json") 解析后传入；测试传临时路径）。
    public FleetTreasureInventory(string savePath)
    {
        _savePath = savePath ?? throw new ArgumentNullException(nameof(savePath));
    }

    public IReadOnlySet<TreasureId> Owned => _owned;
    public bool Has(TreasureId id) => _owned.Contains(id);
    public void Collect(FleetTreasure treasure) => _owned.Add(treasure.Id);

    // 保存背包：写入 JSON（DTO 存 TreasureId 枚举 → int 列表），自动建目录。
    public void Save()
    {
        var dto = new TreasureInventoryDto(_owned.Select(t => (int)t).OrderBy(x => x).ToList());
        var json = JsonSerializer.Serialize(dto, Options);
        var dir = Path.GetDirectoryName(_savePath);
        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
        File.WriteAllText(_savePath, json);
    }

    // 加载 user:// 默认路径（Godot 运行环境；单例 Instance 使用）。
    public static FleetTreasureInventory Load() => Load(ProjectSettings.GlobalizePath(SaveFile));

    // 加载指定路径：文件缺失/损坏 → 空背包（异常吞噬，不抛错）。
    public static FleetTreasureInventory Load(string savePath)
    {
        var inv = new FleetTreasureInventory(savePath);
        if (!File.Exists(savePath)) return inv;
        try
        {
            var dto = JsonSerializer.Deserialize<TreasureInventoryDto>(File.ReadAllText(savePath), Options);
            if (dto?.Treasures is { } ids)
                foreach (var id in ids)
                    if (Enum.IsDefined(typeof(TreasureId), id))
                        inv._owned.Add((TreasureId)id);
        }
        catch (Exception)
        {
            inv._owned.Clear(); // 损坏 → 空背包（不抛错）
        }
        return inv;
    }

    private sealed record TreasureInventoryDto(List<int>? Treasures);
}
