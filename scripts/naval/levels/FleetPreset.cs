#nullable enable
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// V-7 舰队预设（可保存/加载）：预设名 + 舰队列表（每艘 = 舰型 id + 武器/技能/护甲装备）。
// 单舰 = FleetPresetShip（装备复用 LevelEquipmentSpec，与关卡/遭遇舰队同一套装备表示）。
public sealed record FleetPresetShip(string ShipTypeId, LevelEquipmentSpec? Equipment = null);

public sealed record FleetPreset(string Name, IReadOnlyList<FleetPresetShip> Ships);

// 舰队预设存取（参照 LevelProgress）：纯 C# System.Text.Json，存 user://（路径应用侧 GlobalizePath 解析传入，测试传临时路径）。
// 保存格式：{ "Presets": [{ "Name": "…", "Ships": [{ "ShipTypeId": "flagship", "Equipment": { "Weapons": …, "Skills": …, "ArmorLevel": … } }] }] }
// 同名保存 = 覆盖；文件缺失/损坏 → 视为空集合（预设为尽力而为，不抛错）。
public sealed class FleetPresetStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };

    private readonly string _savePath;
    private readonly Dictionary<string, FleetPreset> _presets = new(StringComparer.Ordinal);

    public FleetPresetStore(string savePath)
    {
        _savePath = savePath ?? throw new ArgumentNullException(nameof(savePath));
    }

    public IReadOnlyCollection<FleetPreset> All => _presets.Values;
    public int Count => _presets.Count;
    public bool Has(string name) => _presets.ContainsKey(name);
    public FleetPreset? Get(string name) => _presets.TryGetValue(name, out var preset) ? preset : null;

    // 保存预设（同名覆盖）+ 立即落盘。
    public void Save(FleetPreset preset)
    {
        if (preset is null) throw new ArgumentNullException(nameof(preset));
        _presets[preset.Name] = preset;
        Persist();
    }

    // 删除预设；不存在返回 false（不落盘）。
    public bool Delete(string name)
    {
        if (!_presets.Remove(name)) return false;
        Persist();
        return true;
    }

    public void Save()
    {
        Persist();
    }

    public void Load()
    {
        _presets.Clear();
        if (!File.Exists(_savePath)) return;
        try
        {
            var dto = JsonSerializer.Deserialize<FleetPresetStoreDto>(File.ReadAllText(_savePath), Options);
            if (dto?.Presets is not { } presets) return;
            foreach (var d in presets)
            {
                if (string.IsNullOrWhiteSpace(d.Name) || d.Ships is null || d.Ships.Count == 0) continue;
                _presets[d.Name] = new FleetPreset(d.Name, d.Ships.Select(FromDto).ToList());
            }
        }
        catch (Exception)
        {
            _presets.Clear(); // 损坏 → 重置为空（不抛错）
        }
    }

    private static FleetPresetShip FromDto(FleetPresetShipDto d)
    {
        var eq = d.Equipment is null ? null : new LevelEquipmentSpec(
            d.Equipment.Weapons is { Count: > 0 } w ? new Dictionary<string, int>(w) : null,
            d.Equipment.Skills is { Count: > 0 } s ? new Dictionary<string, int>(s) : null,
            d.Equipment.ArmorLevel);
        return new FleetPresetShip(d.ShipTypeId ?? "", eq);
    }

    private void Persist()
    {
        var dto = new FleetPresetStoreDto(_presets.Values
            .Select(p => new FleetPresetDto(p.Name, p.Ships.Select(ToDto).ToList()))
            .ToList());
        var json = JsonSerializer.Serialize(dto, Options);
        var dir = Path.GetDirectoryName(_savePath);
        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
        File.WriteAllText(_savePath, json);
    }

    private static FleetPresetShipDto ToDto(FleetPresetShip ship)
    {
        LevelEquipmentSpecDto? eq = null;
        if (ship.Equipment is { } e)
        {
            eq = new LevelEquipmentSpecDto(
                e.Weapons is { Count: > 0 } ? new Dictionary<string, int>(e.Weapons) : null,
                e.Skills is { Count: > 0 } ? new Dictionary<string, int>(e.Skills) : null,
                e.ArmorLevel);
        }
        return new FleetPresetShipDto(ship.ShipTypeId, eq);
    }

    private sealed record FleetPresetStoreDto(List<FleetPresetDto>? Presets);
    private sealed record FleetPresetDto(string? Name, List<FleetPresetShipDto>? Ships);
    private sealed record FleetPresetShipDto(string? ShipTypeId, LevelEquipmentSpecDto? Equipment);
    private sealed record LevelEquipmentSpecDto(
        Dictionary<string, int>? Weapons = null,
        Dictionary<string, int>? Skills = null,
        int? ArmorLevel = null);
}

// V-7 预设合法性校验（纯 C#，测试可直连；UI 复用错误 key 文案）：
// 舰型存在 + 装备不超槽位（武器位 / 撞角 MaxCount / 技能位 / 护甲上限）+ 名称/舰队非空。
public static class FleetPresetValidator
{
    public static IReadOnlyList<string> Validate(NavalRulesConfig config, FleetPreset preset)
    {
        var errors = new List<string>();
        if (preset is null) { errors.Add("fleet.empty_fleet"); return errors; }
        if (string.IsNullOrWhiteSpace(preset.Name)) errors.Add("fleet.empty_name");
        if (preset.Ships is null || preset.Ships.Count == 0) { errors.Add("fleet.empty_fleet"); return errors; }
        if (config is null) { errors.Add("fleet.unknown_ship"); return errors; }
        foreach (var ship in preset.Ships)
        {
            var def = config.Ships.FirstOrDefault(s => s.Id == ship.ShipTypeId);
            if (def is null) { errors.Add("fleet.unknown_ship"); continue; }
            if (ship.Equipment is not { } eq) continue;
            if (eq.Weapons is { } weapons)
            {
                var total = 0;
                foreach (var (wid, count) in weapons)
                {
                    if (count <= 0) continue;
                    var w = config.Weapons.FirstOrDefault(x => x.Id == wid);
                    if (w is null) { errors.Add("fleet.unknown_weapon"); continue; }
                    if (w.MaxCount is { } max && count > max) { errors.Add("fleet.weapon_over_max"); continue; }
                    total += count;
                }
                if (total > def.WeaponSlots) errors.Add("fleet.weapon_over_slots");
            }
            if (eq.Skills is { } skills)
            {
                var total = 0;
                foreach (var (sid, count) in skills)
                {
                    if (count <= 0) continue;
                    if (config.Skills.FirstOrDefault(x => x.Id == sid) is null) { errors.Add("fleet.unknown_skill"); continue; }
                    total += count;
                }
                if (total > def.SkillSlots) errors.Add("fleet.skill_over_slots");
            }
            if (eq.ArmorLevel is { } armor)
            {
                if (armor < 0 || armor > def.BaseArmor + def.ArmorSlots) errors.Add("fleet.armor_over_cap");
            }
        }
        return errors;
    }
}

// V-7 跨场景会话：活动预设（应用后在布阵/再来一局沿用；返回主菜单时 Clear）。
public static class FleetPresetSession
{
    public static string? ActiveName { get; private set; }
    public static bool Active => ActiveName is not null;
    public static void Begin(string name) => ActiveName = name;
    public static void Clear() => ActiveName = null;
}

// V-7 预设 → LevelShipSpec 映射（Bow 用占位；布阵侧按自动摆位重排，纯数据测试用此断言映射与强度口径）。
public static class FleetPresetFactory
{
    public static IReadOnlyList<LevelShipSpec> ToLevelSpecs(FleetPreset preset)
        => preset.Ships
            .Select(s => new LevelShipSpec(s.ShipTypeId, new GridPos(0, 0), CardinalDirection.East, s.Equipment))
            .ToList();
}
