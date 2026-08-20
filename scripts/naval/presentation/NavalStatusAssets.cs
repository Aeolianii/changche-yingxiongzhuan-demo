#nullable enable
using Godot;
using System.Collections.Generic;

namespace NanjiangNaval;

// 舰船持续状态美术资源：生图原图保持透明底，通过 AtlasTexture 只取有效颗粒/图标区域。
// 同一原图可裁出多种火焰与水流颗粒，战场表现层再用时间相位生成动态粒子群。
public static class NavalStatusAssets
{
    public const string BurnParticlesPath = "res://assets/naval/battle/status_fx/burn_particles_v1.png";
    public const string SlowParticlesPath = "res://assets/naval/battle/status_fx/slow_particles_v1.png";
    public const string RepairParticlePath = "res://assets/naval/battle/status_fx/repair_cross_particle_v1.png";
    public const string BurnIconPath = "res://assets/naval/ui/ship_status/status_icons/burn_icon_v1.png";
    public const string SlowIconPath = "res://assets/naval/ui/ship_status/status_icons/slow_icon_v1.png";
    public const string RepairIconPath = "res://assets/naval/ui/ship_status/status_icons/repair_icon_v1.png";
    public const string SelfSinkIconPath = "res://assets/naval/ui/ship_status/status_icons/self_sink_icon_v1.png";

    private static readonly Rect2[] BurnRegions =
    {
        new(165, 135, 420, 410),
        new(545, 55, 440, 520),
        new(1040, 135, 385, 430),
        new(175, 575, 520, 390),
        new(880, 535, 505, 445),
    };

    private static readonly Rect2[] SlowRegions =
    {
        new(120, 95, 1230, 275),
        new(45, 300, 1435, 370),
        new(230, 610, 1165, 315),
    };

    private static readonly Rect2 RepairParticleRegion = new(300, 225, 660, 795);
    private static readonly Rect2 BurnIconRegion = new(260, 55, 760, 1105);
    private static readonly Rect2 SlowIconRegion = new(160, 40, 920, 1170);
    private static readonly Rect2 RepairIconRegion = new(180, 130, 940, 970);
    private static readonly Rect2 SelfSinkIconRegion = new(120, 70, 1035, 1100);

    public static IReadOnlyList<Texture2D> BurnParticles() => Crops(BurnParticlesPath, BurnRegions);
    public static IReadOnlyList<Texture2D> SlowParticles() => Crops(SlowParticlesPath, SlowRegions);
    public static Texture2D? RepairParticle() => Crop(RepairParticlePath, RepairParticleRegion);
    public static Texture2D? BurnIcon() => Crop(BurnIconPath, BurnIconRegion);
    public static Texture2D? SlowIcon() => Crop(SlowIconPath, SlowIconRegion);
    public static Texture2D? RepairIcon() => Crop(RepairIconPath, RepairIconRegion);
    public static Texture2D? SelfSinkIcon() => Crop(SelfSinkIconPath, SelfSinkIconRegion);

    public static bool AllTexturesLoaded()
        => ResourceLoader.Exists(BurnParticlesPath)
           && ResourceLoader.Exists(SlowParticlesPath)
           && ResourceLoader.Exists(RepairParticlePath)
           && ResourceLoader.Exists(BurnIconPath)
           && ResourceLoader.Exists(SlowIconPath)
           && ResourceLoader.Exists(RepairIconPath)
           && ResourceLoader.Exists(SelfSinkIconPath);

    private static IReadOnlyList<Texture2D> Crops(string path, IEnumerable<Rect2> regions)
    {
        var result = new List<Texture2D>();
        var source = Load(path);
        if (source is null) return result;
        foreach (var region in regions)
            result.Add(new AtlasTexture { Atlas = source, Region = region });
        return result;
    }

    private static Texture2D? Crop(string path, Rect2 region)
    {
        var source = Load(path);
        return source is null ? null : new AtlasTexture { Atlas = source, Region = region };
    }

    private static Texture2D? Load(string path)
        => ResourceLoader.Exists(path) ? GD.Load<Texture2D>(path) : null;
}
