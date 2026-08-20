using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace NavalCombat.Core;

// 配置加载器：从 data/naval/*.json 反序列化并校验 NavalRulesConfig（spec 4.5）。
// 命名空间与 NavalRulesConfig 保持一致（NavalCombat.Core），使测试经 using NavalCombat.Core 直接引用。
public static class NavalConfigLoader
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
    };

    // 从四个 JSON 文本反序列化并校验；任一校验失败抛 InvalidDataException（附来源文件名）。
    public static NavalRulesConfig LoadFromJson(string shipsJson, string weaponsJson, string skillsJson, string weatherJson)
    {
        var ships = DeserializeShips(shipsJson);
        var weapons = Deserialize<List<WeaponDefinition>>(weaponsJson, "weapons.json");
        var skills = Deserialize<List<SkillDefinition>>(skillsJson, "skills.json");
        var weather = Deserialize<List<WeatherDefinition>>(weatherJson, "weather.json");
        Validate(ships, weapons, skills);
        return new NavalRulesConfig { Ships = ships, Weapons = weapons, Skills = skills, Weather = weather };
    }

    // 从目录加载四文件（缺文件/目录抛明确异常）。
    public static NavalRulesConfig LoadFromDirectory(string directory)
    {
        if (!Directory.Exists(directory))
            throw new InvalidDataException($"naval config directory not found: {directory}");
        return LoadFromJson(
            ReadRequired(Path.Combine(directory, "ships.json")),
            ReadRequired(Path.Combine(directory, "weapons.json")),
            ReadRequired(Path.Combine(directory, "skills.json")),
            ReadRequired(Path.Combine(directory, "weather.json")));
    }

    public static NavalRulesConfig LoadDefault()
        => NavalRulesConfig.Default();

    // ships.json 用中间 DTO：SpeedCap 是字符串枚举、Passability 是数字枚举，映射回领域记录。
    private static List<ShipDefinition> DeserializeShips(string json)
    {
        var dtos = Deserialize<List<ShipDto>>(json, "ships.json");
        return dtos.Select(d => new ShipDefinition(
            d.Id,
            d.DisplayName,
            new ShipCost(d.Cost.Iron, d.Cost.Wood, d.Cost.Hemp, d.Cost.Gold),
            d.MaxHp,
            d.BaseArmor,
            Enum.Parse<SpeedTier>(d.SpeedCap, ignoreCase: true),
            d.LoadCapacity,
            d.Length,
            (Passability)d.Passability,
            d.WeaponSlots,
            d.SkillSlots,
            d.ArmorSlots,
            d.BoardingDamage,
            d.ArrowRainDamage,
            d.Width,
            d.Mass,
            d.MineDamagePercent,
            d.MineImmune,
            d.ImmuneChainShot,
            d.BurnRoundsModifier,
            d.Immovable,
            d.CannotEscape,
            d.CannotSurrender,
            d.IsVictoryTarget,
            d.CannotTurn,
            d.CanLeap)).ToList();
    }

    private static void Validate(
        List<ShipDefinition> ships, List<WeaponDefinition> weapons, List<SkillDefinition> skills)
    {
        EnsureUniqueIds(ships.Select(s => s.Id), "ships.json");
        EnsureUniqueIds(weapons.Select(w => w.Id), "weapons.json");
        EnsureUniqueIds(skills.Select(s => s.Id), "skills.json");
        foreach (var s in ships)
        {
            if (s.MaxHp <= 0)
                throw new InvalidDataException($"ships.json: '{s.Id}' 非正最大生命 {s.MaxHp}");
            if (s.Length < 1 || s.Length > 4)
                throw new InvalidDataException($"ships.json: '{s.Id}' 非法占格长度 {s.Length}（允许 1-4）");
            if (s.Width < 1 || s.Width > 2)
                throw new InvalidDataException($"ships.json: '{s.Id}' 非法占格宽度 {s.Width}（允许 1-2）");
            if (s.BaseArmor * DamageRules.ArmorReductionPerLevel > DamageRules.ArmorMaxReduction)
                throw new InvalidDataException($"ships.json: '{s.Id}' 基础护甲 {s.BaseArmor} 减免超过全局上限 {DamageRules.ArmorMaxReduction}");
        }
        foreach (var sk in skills)
        {
            if (sk.UsesPerSlot < 0)
                throw new InvalidDataException($"skills.json: '{sk.Id}' 负使用次数 {sk.UsesPerSlot}");
        }
    }

    private static void EnsureUniqueIds(IEnumerable<string> ids, string source)
    {
        var seen = new HashSet<string>();
        foreach (var id in ids)
        {
            if (!seen.Add(id))
                throw new InvalidDataException($"{source}: 重复 ID '{id}'");
        }
    }

    private static T Deserialize<T>(string json, string source) where T : class
    {
        try
        {
            return JsonSerializer.Deserialize<T>(json, Options)
                ?? throw new InvalidDataException($"{source}: JSON 内容为空");
        }
        catch (JsonException ex)
        {
            throw new InvalidDataException($"{source}: JSON 解析失败——{ex.Message}");
        }
    }

    private static string ReadRequired(string path)
    {
        if (!File.Exists(path))
            throw new InvalidDataException($"naval config file not found: {path}");
        return File.ReadAllText(path);
    }

    private sealed record ShipDto(
        string Id, string DisplayName, ShipCostDto Cost, int MaxHp, int BaseArmor,
        string SpeedCap, int LoadCapacity, int Length, int Passability,
        int WeaponSlots, int SkillSlots, int ArmorSlots, int BoardingDamage, int ArrowRainDamage,
        int Width = 1,
        int Mass = 0,
        double MineDamagePercent = 0.30,
        bool MineImmune = false,
        bool ImmuneChainShot = false,
        int BurnRoundsModifier = 0,
        bool Immovable = false,
        bool CannotEscape = false,
        bool CannotSurrender = false,
        bool IsVictoryTarget = false,
        bool CannotTurn = false,
        bool CanLeap = false);
    private sealed record ShipCostDto(int Iron, int Wood, int Hemp, int Gold);
}
