#nullable enable
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// V-7 舰队预设（可保存/加载）：预设名 + 舰队列表（每艘 = 舰型 id + 武器/技能/护甲装备）。
// 单舰 = FleetPresetShip（装备复用 LevelEquipmentSpec，与关卡/遭遇舰队同一套装备表示）。
public sealed record FleetPresetShip(string ShipTypeId, LevelEquipmentSpec? Equipment = null);

// CHG-20260818：阵型条目（初始阵型）——Slot = Ships 数组下标（出战序列槽位，布阵 p{i+1}）；
// X/Y = 海战布阵坐标（小地图编辑器以玩家布阵区缩小网格记录并持久化海战坐标）；Facing ∈ east/west/north/south。
public sealed record FleetPresetFormation(int Slot, int X, int Y, string Facing);

public sealed record FleetPreset(
    string Name,
    IReadOnlyList<FleetPresetShip> Ships,
    IReadOnlyList<FleetPresetFormation>? Formation = null)
{
    // 取指定槽位的阵型；无/越界 → null。
    public FleetPresetFormation? FormationFor(int slot)
        => Formation is null ? null : Formation.FirstOrDefault(f => f.Slot == slot);
}

// 舰队预设存取（参照 LevelProgress）：纯 C# System.Text.Json，存 user://（路径应用侧 GlobalizePath 解析传入，测试传临时路径）。
// 保存格式：{ "ActivePreset": "…", "Presets": [{ "Name": "…", "Ships": [{ "ShipTypeId": "flagship", "Equipment": { "Weapons": …, "Skills": …, "ArmorLevel": … } }] }] }
// ShipTypeId 既可为海战舰型（flagship/frigate/…）也可为经济舰型（patrol_boat/cannon_warship/escort_junk）——
// 本库是类型无关的容器，由调用方解释。同名保存 = 覆盖；文件缺失/损坏 → 视为空集合（预设为尽力而为，不抛错）。
// ActivePreset：持久化的「下次出战舰队」预设名（旧文件缺省 → null，向后兼容）。CHG-20260818。
public sealed class FleetPresetStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        Converters = { new LenientIntConverter(), new LenientNullableIntConverter() },
    };

    // CHG-20260818：GDScript JSON.parse_string 会把 JSON 数字一律解析为浮点（1 → 1.0），
    // ship_screen 经「读回再写」的预设文件数值可能为浮点（如 "ArmorLevel": 1.0、"Slot": 0.0）。
    // C# 读侧（FleetPresetStore.Load）必须容忍，否则 Dictionary<string,int>/int? 反序列化抛异常
    // → Load 清空 → 布阵回落默认（跨语言共享 schema 闭环的必要兼容）。
    private sealed class LenientIntConverter : JsonConverter<int>
    {
        public override int Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.Number)
                return reader.TryGetInt32(out var i) ? i : (int)reader.GetDouble();
            if (reader.TokenType == JsonTokenType.String && int.TryParse(reader.GetString(), out var s)) return s;
            throw new JsonException($"无法将 {reader.TokenType} 转换为 int");
        }

        public override void Write(Utf8JsonWriter writer, int value, JsonSerializerOptions options)
            => writer.WriteNumberValue(value);
    }

    private sealed class LenientNullableIntConverter : JsonConverter<int?>
    {
        public override int? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.Null) return null;
            if (reader.TokenType == JsonTokenType.Number)
                return reader.TryGetInt32(out var i) ? i : (int)reader.GetDouble();
            if (reader.TokenType == JsonTokenType.String && int.TryParse(reader.GetString(), out var s)) return s;
            throw new JsonException($"无法将 {reader.TokenType} 转换为 int?");
        }

        public override void Write(Utf8JsonWriter writer, int? value, JsonSerializerOptions options)
        {
            if (value is null) writer.WriteNullValue();
            else writer.WriteNumberValue(value.Value);
        }
    }

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

    // 活动（下次出战）预设名；不要求该预设必须存在（不存在时布阵侧回退默认）。
    public string? ActiveName { get; private set; }

    // 设置/清除活动预设并落盘（空串/空白 → 清除）。
    public void SetActive(string? name)
    {
        ActiveName = string.IsNullOrWhiteSpace(name) ? null : name;
        Persist();
    }

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
        ActiveName = null;
        if (!File.Exists(_savePath)) return;
        try
        {
            var dto = JsonSerializer.Deserialize<FleetPresetStoreDto>(File.ReadAllText(_savePath), Options);
            if (dto is null) return;
            if (!string.IsNullOrWhiteSpace(dto.ActivePreset)) ActiveName = dto.ActivePreset.Trim();
            if (dto.Presets is not { } presets) return;
            foreach (var d in presets)
            {
                if (string.IsNullOrWhiteSpace(d.Name) || d.Ships is null || d.Ships.Count == 0) continue;
                _presets[d.Name] = new FleetPreset(d.Name, d.Ships.Select(FromDto).ToList(), FromDto(d.Formation));
            }
        }
        catch (Exception)
        {
            _presets.Clear(); // 损坏 → 重置为空（不抛错）
            ActiveName = null;
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

    // CHG-20260818：阵型 DTO → 记录（跳过非法条目：槽位缺失/负数、朝向非法；X/Y 原样，布阵侧校验）。
    private static IReadOnlyList<FleetPresetFormation>? FromDto(List<FleetPresetFormationDto>? formation)
    {
        if (formation is null || formation.Count == 0) return null;
        var list = new List<FleetPresetFormation>();
        foreach (var f in formation)
        {
            if (f.Slot is not { } slot || slot < 0) continue;
            if (string.IsNullOrWhiteSpace(f.Facing)) continue;
            var facing = f.Facing.Trim().ToLowerInvariant();
            if (facing is not ("east" or "west" or "north" or "south")) continue;
            list.Add(new FleetPresetFormation(slot, Math.Max(0, f.X ?? 0), Math.Max(0, f.Y ?? 0), facing));
        }
        return list.Count == 0 ? null : list;
    }

    private void Persist()
    {
        var dto = new FleetPresetStoreDto(ActiveName, _presets.Values
            .Select(p => new FleetPresetDto(p.Name, p.Ships.Select(ToDto).ToList(),
                p.Formation is { Count: > 0 } ? p.Formation.Select(ToDto).ToList() : null))
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

    private static FleetPresetFormationDto ToDto(FleetPresetFormation f)
        => new(f.Slot, f.X, f.Y, f.Facing);

    private sealed record FleetPresetStoreDto(string? ActivePreset, List<FleetPresetDto>? Presets);
    private sealed record FleetPresetDto(string? Name, List<FleetPresetShipDto>? Ships, List<FleetPresetFormationDto>? Formation = null);
    private sealed record FleetPresetShipDto(string? ShipTypeId, LevelEquipmentSpecDto? Equipment);
    private sealed record FleetPresetFormationDto(int? Slot, int? X, int? Y, string? Facing);
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

// V-7 预设 → LevelShipSpec 映射（CHG-20260818：有阵型时按阵型给 Bow/Facing，否则占位 (0,0) 朝东；
// 布阵侧按阵型/自动摆位重排，纯数据测试用此断言映射与强度口径）。
public static class FleetPresetFactory
{
    public static IReadOnlyList<LevelShipSpec> ToLevelSpecs(FleetPreset preset)
        => preset.Ships
            .Select((s, i) =>
            {
                var formation = preset.FormationFor(i);
                var facing = CardinalDirection.East;
                if (formation is not null && TryParseFacing(formation.Facing, out var parsed)) facing = parsed;
                var bow = formation is not null ? new GridPos(formation.X, formation.Y) : new GridPos(0, 0);
                return new LevelShipSpec(s.ShipTypeId, bow, facing, s.Equipment);
            })
            .ToList();

    private static bool TryParseFacing(string name, out CardinalDirection facing)
    {
        facing = name.Trim().ToLowerInvariant() switch
        {
            "north" => CardinalDirection.North,
            "south" => CardinalDirection.South,
            "east" => CardinalDirection.East,
            "west" => CardinalDirection.West,
            _ => CardinalDirection.East,
        };
        return name.Trim().ToLowerInvariant() is "north" or "south" or "east" or "west";
    }
}
