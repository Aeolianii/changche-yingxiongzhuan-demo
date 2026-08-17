#nullable enable
using Godot;
using NavalCombat.Core;
using System;
using System.Collections.Generic;
using System.Linq;

namespace NanjiangNaval;

// 网格点击接收器：由控制器实现，接收画布/世界坐标（GetGlobalMousePosition 已含相机变换；headless 直接传画布坐标）。
public interface IGridClickReceiver
{
    void OnGridClicked(Vector2 worldPos);
}

// 网格视图：绘制网格/地形/移动范围水墨高亮/射界弧（分武器弧+盲射空格）/布阵区域/已行动标记/
// 已发现水雷/接舷连线+俘获进度/撞击方向箭头与爆炸瞬态特效/技能与布雷目标格/待定战术目标舰高亮；捕获鼠标点击转发到控制器。
public partial class NavalGridView : Node2D
{
    // UX-1：网格缩到 26px，画布原点 (48,20)。48×26=1248、36×26=936，适配 1344×896 视口（含相机缩放余量）。
    public const int CellSize = 26;
    public static readonly Vector2 Origin = new(48f, 20f);
    private const float CellGap = 3f;
    private const float CameraPanSpeed = 520f;
    private const float CameraScreenMargin = 80f;
    private const float TutorialMapFitThreshold = 2f;
    private const float TutorialCameraZoom = 3f;

    // 整数倍率跟随相机：教学地图 3x、大地图 1x；切换/移动当前舰时平滑居中。
    private Camera2D? _camera;
    private Tween? _cameraTween;
    private Rect2 _backgroundBounds;
    private Texture2D? _seaTexture;
    private Polygon2D? _animatedSeaSurface;
    private readonly List<Texture2D> _reefTextures = new();
    private readonly List<Texture2D> _coralTextures = new();
    private readonly List<Texture2D> _islandTextures = new();
    // U-2a：新地形占位瓦片（海滩/林地/草地/港口/小镇/陆河；缺纹理时回退程序化几何绘制）。
    private readonly List<Texture2D> _beachTextures = new();
    private readonly List<Texture2D> _forestTextures = new();
    private readonly List<Texture2D> _grassTextures = new();
    private readonly List<Texture2D> _portTextures = new();
    private readonly List<Texture2D> _townTextures = new();
    private readonly List<Texture2D> _riverTextures = new();

    private BattleState? _battle;
    private IGridClickReceiver? _clickReceiver;
    private readonly List<GridPos> _moveRange = new();
    private readonly List<AttackArcOption> _attackArcs = new();
    private readonly List<(Rect2I Rect, Color Color)> _zones = new();
    private readonly HashSet<GridPos> _deploymentCells = new();
    private Color _deploymentCellColor = Colors.Transparent;
    // 技能/布雷目标格覆盖（链色等由 ShowXxx 指定）。
    private readonly List<(GridPos Cell, Color Color, bool Solid)> _cellOverlays = new();
    // 待定战术（撞击/接舷）目标舰 id 高亮。
    private readonly HashSet<string> _highlightShipIds = new();
    // 瞬态特效：撞击方向箭头 + 水雷爆炸圈（_Process 按年龄淡出，不随 ClearOverlay 清除）。
    private (Vector2 From, Vector2 To, float Age)? _ramLine;
    private readonly List<(GridPos Cell, float Age)> _explosions = new();
    // F-6：战争迷雾——当前视野内格集合（玩家阵营观测）。null=未初始化（布阵/未开始战斗，不画迷雾）。
    private HashSet<GridPos>? _fogVisible;
    private static readonly Color FogColor = new(0.02f, 0.03f, 0.04f, 0.62f); // 墨色迷雾（半透明黑墨）

    public IGridClickReceiver? ClickReceiver
    {
        get => _clickReceiver;
        set => _clickReceiver = value;
    }

    public override void _Ready()
    {
        SetProcessUnhandledInput(true);
        SetProcess(true);
        // 引用共享相机（NavalDemo 根下 Camera2D，组 naval_camera）；Attach 时按地图选择 1x/3x。
        _camera = GetTree().GetFirstNodeInGroup("naval_camera") as Camera2D;
        _seaTexture = GD.Load<Texture2D>("res://assets/naval/battle/sea_ink_pixel.png");
        CreateAnimatedSeaSurface();
        LoadTerrainTextures("reef", _reefTextures);
        LoadTerrainTextures("coral", _coralTextures);
        LoadTerrainTextures("island", _islandTextures);
        // U-2a：新地形占位瓦片（同名 4 变体，可整体替换为正式美术）。
        LoadTerrainTextures("beach", _beachTextures);
        LoadTerrainTextures("forest", _forestTextures);
        LoadTerrainTextures("grass", _grassTextures);
        LoadTerrainTextures("port", _portTextures);
        LoadTerrainTextures("town", _townTextures);
        LoadTerrainTextures("river", _riverTextures);
    }

    // 瞬态特效推进：撞击箭头/爆炸圈按时间淡出。
    public override void _Process(double delta)
    {
        UpdateCameraPan((float)delta);
        if (_ramLine is { } line)
        {
            var age = line.Age + (float)delta;
            if (age < 1.8f) _ramLine = (line.From, line.To, age);
            else _ramLine = null;
            QueueRedraw();
        }
        if (_explosions.Count > 0)
        {
            var next = new List<(GridPos Cell, float Age)>();
            foreach (var e in _explosions)
            {
                var age = e.Age + (float)delta;
                if (age < 0.9f) next.Add((e.Cell, age));
            }
            _explosions.Clear();
            _explosions.AddRange(next);
            QueueRedraw();
        }
    }

    // 捕获点击：相机由当前舰自动跟随，并允许 WASD 在背景边界内查看战场；不再使用滚轮缩放。
    public override void _UnhandledInput(InputEvent @event)
    {
        if (_battle is null) return;
        if (@event is InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Left })
        {
            _clickReceiver?.OnGridClicked(GetGlobalMousePosition());
            GetViewport().SetInputAsHandled();
        }
    }

    private void UpdateCameraPan(float delta)
    {
        if (_battle is null || _camera is null) return;
        var direction = Vector2.Zero;
        if (Input.IsPhysicalKeyPressed(Key.W)) direction.Y -= 1f;
        if (Input.IsPhysicalKeyPressed(Key.S)) direction.Y += 1f;
        if (Input.IsPhysicalKeyPressed(Key.A)) direction.X -= 1f;
        if (Input.IsPhysicalKeyPressed(Key.D)) direction.X += 1f;
        if (direction == Vector2.Zero) return;
        PanCamera(direction, delta);
    }

    public void PanCamera(Vector2 direction, float delta)
    {
        if (_camera is null || direction == Vector2.Zero || delta <= 0f) return;
        _cameraTween?.Kill();
        _cameraTween = null;
        if (direction.LengthSquared() > 1f) direction = direction.Normalized();
        // Keep the WASD pan speed stable in screen pixels at every integer zoom.
        var zoom = Mathf.Max(0.001f, _camera.Zoom.X);
        _camera.Position = ClampCameraPosition(
            _camera.Position + direction * (CameraPanSpeed / zoom) * delta);
    }

    private Vector2 ClampCameraPosition(Vector2 position)
    {
        if (_camera is null || _backgroundBounds.Size == Vector2.Zero) return position;
        var zoom = new Vector2(Mathf.Max(0.001f, _camera.Zoom.X), Mathf.Max(0.001f, _camera.Zoom.Y));
        var halfView = GetViewport().GetVisibleRect().Size / zoom * 0.5f;
        var min = _backgroundBounds.Position + halfView;
        var max = _backgroundBounds.End - halfView;
        if (min.X > max.X) min.X = max.X = _backgroundBounds.GetCenter().X;
        if (min.Y > max.Y) min.Y = max.Y = _backgroundBounds.GetCenter().Y;
        return new Vector2(
            Mathf.Clamp(position.X, min.X, max.X),
            Mathf.Clamp(position.Y, min.Y, max.Y));
    }

    public void Attach(BattleState battle)
    {
        _battle = battle;
        _fogVisible = null; // F-6：新战斗重算迷雾（StartBattle 后由 RefreshVisibility 填入可见格）
        ConfigureFixedCamera(battle);
        ResizeAnimatedSeaSurface(battle.Map.Width, battle.Map.Height);
        QueueRedraw();
    }

    private Rect2 BackgroundRect(int width, int height)
    {
        var viewport = GetViewport().GetVisibleRect().Size;
        var mapSize = new Vector2(width * CellSize, height * CellSize);
        var zoom = _camera?.Zoom ?? Vector2.One;
        var safeZoom = new Vector2(Mathf.Max(0.001f, zoom.X), Mathf.Max(0.001f, zoom.Y));
        // 视口外再留两格海面，使边缘舰船可居中且镜头不会露出背景。
        var padding = viewport / safeZoom * 0.5f + Vector2.One * (CellSize * 2f);
        return new Rect2(Origin - padding, mapSize + padding * 2f);
    }

    private float CameraZoomForMap(int width, int height)
    {
        var viewport = GetViewport().GetVisibleRect().Size;
        var available = new Vector2(
            Mathf.Max(CellSize, viewport.X - CameraScreenMargin * 2f),
            Mathf.Max(CellSize, viewport.Y - CameraScreenMargin * 2f));
        var mapSize = new Vector2(width * CellSize, height * CellSize);
        var fitZoom = Mathf.Min(available.X / mapSize.X, available.Y / mapSize.Y);

        // 能以 2x 完整适配的教学棋盘进一步放大到 3x；48x36 等大地图保持 1x。
        return fitZoom >= TutorialMapFitThreshold ? TutorialCameraZoom : 1f;
    }

    private void ConfigureFixedCamera(BattleState battle)
    {
        if (_camera is null) return;
        _cameraTween?.Kill();
        var zoom = CameraZoomForMap(battle.Map.Width, battle.Map.Height);
        _camera.Zoom = Vector2.One * zoom;
        _backgroundBounds = BackgroundRect(battle.Map.Width, battle.Map.Height);
        _camera.PositionSmoothingEnabled = false;
        _camera.LimitLeft = Mathf.FloorToInt(_backgroundBounds.Position.X);
        _camera.LimitTop = Mathf.FloorToInt(_backgroundBounds.Position.Y);
        _camera.LimitRight = Mathf.CeilToInt(_backgroundBounds.End.X);
        _camera.LimitBottom = Mathf.CeilToInt(_backgroundBounds.End.Y);
        _camera.Position = ClampCameraPosition(
            Origin + new Vector2(battle.Map.Width * CellSize, battle.Map.Height * CellSize) * 0.5f);
    }

    public void FocusCameraOnShip(ShipState ship)
    {
        if (_camera is null) return;
        var target = ClampCameraPosition(ShipCenterToWorld(ship.Bow, ship.Length, ship.Facing));
        _cameraTween?.Kill();
        if (DisplayServer.GetName() == "headless")
        {
            _camera.Position = target;
            return;
        }
        _cameraTween = CreateTween()
            .SetTrans(Tween.TransitionType.Cubic)
            .SetEase(Tween.EaseType.Out);
        _cameraTween.TweenProperty(_camera, "position", target, 0.28f);
    }

    private void CreateAnimatedSeaSurface()
    {
        if (_seaTexture is null) return;
        var shader = new Shader
        {
            Code = """
                shader_type canvas_item;
                render_mode unshaded;

                uniform float flow_speed = 0.014;
                uniform float warp_strength = 0.052;
                uniform float caustic_strength = 0.14;

                float sea_luma(vec3 color) {
                    return dot(color, vec3(0.24, 0.67, 0.09));
                }

                // 镜像循环在每个周期边界连续折返，不再把原图不匹配的左右/上下边缘硬拼到一起。
                vec2 mirror_repeat(vec2 coord) {
                    vec2 period = mod(coord, vec2(2.0));
                    return vec2(1.0) - abs(period - vec2(1.0));
                }

                void fragment() {
                    vec2 uv = UV;
                    float time = TIME * flow_speed;

                    // 两层低频水色反向流动，形成大块缓慢变化的明暗水团。
                    float broad_a = sea_luma(texture(TEXTURE, mirror_repeat(
                        uv * 0.58 + vec2(time * 0.34, time * 0.09))).rgb);
                    float broad_b = sea_luma(texture(TEXTURE, mirror_repeat(
                        uv * 0.82 + vec2(-time * 0.22, time * 0.13))).rgb);
                    float broad = broad_a * 0.62 + broad_b * 0.38;

                    // 低频明暗同时充当流场，轻微弯曲后续纹理，避免整张贴图机械平移。
                    vec2 warp = (vec2(broad_a, broad_b) - vec2(0.5)) * warp_strength;
                    vec2 flow_a = uv * 1.10 + warp
                        + vec2(time * 0.72, time * 0.18);
                    vec2 flow_b = uv * 1.43 - warp.yx
                        + vec2(-time * 0.48, time * 0.27);
                    vec2 flow_c = uv * 0.91 + warp * 0.55
                        + vec2(time * 0.20, -time * 0.36);

                    float light_a = sea_luma(texture(TEXTURE, mirror_repeat(flow_a)).rgb);
                    float light_b = sea_luma(texture(TEXTURE, mirror_repeat(flow_b)).rgb);
                    float light_c = sea_luma(texture(TEXTURE, mirror_repeat(flow_c)).rgb);

                    // 两股水流亮度相近处提取细带，再以第三层打断，得到聚散的折射光纹。
                    float ridge_a = 1.0 - smoothstep(0.020, 0.095, abs(light_a - light_b));
                    float ridge_b = 1.0 - smoothstep(0.026, 0.120, abs(light_b - light_c));
                    float caustic = ridge_a * 0.72 + ridge_b * 0.28;
                    caustic *= smoothstep(0.40, 0.68, max(light_a, light_c));
                    caustic *= 0.86 + 0.14 * sin(TIME * 0.72 + broad * 6.28318);

                    // 底纹只做很轻的漂移和扭曲；墨青暗部与米青亮带保持水墨像素配色。
                    vec4 base_texel = texture(TEXTURE, mirror_repeat(uv + warp * 0.34
                        + vec2(time * 0.08, time * 0.025)));
                    vec3 base = base_texel.rgb;
                    float shade = mix(0.84, 1.10, smoothstep(0.34, 0.70, broad));
                    vec3 ink_tint = vec3(0.88, 0.95, 0.94);
                    vec3 paper_blue = vec3(0.77, 0.88, 0.86);
                    vec3 color = base * ink_tint * shade
                        + paper_blue * caustic * caustic_strength;
                    COLOR = vec4(color, base_texel.a);
                }
                """
        };
        _animatedSeaSurface = new Polygon2D
        {
            Name = "AnimatedSeaSurface",
            Texture = _seaTexture,
            Material = new ShaderMaterial { Shader = shader },
            ZIndex = -100,
            ShowBehindParent = true,
        };
        AddChild(_animatedSeaSurface);
    }

    private void ResizeAnimatedSeaSurface(int width, int height)
    {
        if (_animatedSeaSurface is null || _seaTexture is null) return;
        _backgroundBounds = BackgroundRect(width, height);
        var topLeft = _backgroundBounds.Position;
        var size = _backgroundBounds.Size;
        _animatedSeaSurface.Polygon = new[]
        {
            topLeft,
            topLeft + new Vector2(size.X, 0f),
            topLeft + size,
            topLeft + new Vector2(0f, size.Y),
        };
        // Polygon2D UV 使用纹理像素坐标；按世界像素展开后由 shader 镜像循环，保持水墨纹理密度且消除硬接缝。
        _animatedSeaSurface.UV = new[]
        {
            Vector2.Zero,
            new Vector2(size.X, 0f),
            size,
            new Vector2(0f, size.Y),
        };
    }

    // UX-1 坐标空间裁定：WorldToGrid/GridToWorldCenter/ShipCenterToWorld 均返回/接受"画布/世界坐标"（Origin 起算），
    // 与相机解耦（去 ToLocal/ToGlobal——节点无变换时二者本就恒等）。真实鼠标点击经 GetGlobalMousePosition() 已含相机变换；
    // HUD 伤害数字经 WorldToScreen 换算屏幕坐标。这样 headless 的 CellToWorld→OnGridClicked→WorldToGrid 往返在任何相机状态下精确成立。
    public GridPos WorldToGrid(Vector2 world)
        => new GridPos(
            Mathf.FloorToInt((world.X - Origin.X) / CellSize),
            Mathf.FloorToInt((world.Y - Origin.Y) / CellSize));

    public Vector2 GridToWorldCenter(GridPos cell)
        => Origin + new Vector2(cell.X * CellSize, cell.Y * CellSize) + new Vector2(CellSize / 2f, CellSize / 2f);

    // 舰船几何中心：船头沿反朝向偏移 (length-1)/2 格（画布/世界坐标）。
    public Vector2 ShipCenterToWorld(GridPos bow, int length, CardinalDirection facing)
    {
        var d = facing.Vector();
        var cx = bow.X - d.X * (length - 1) / 2f;
        var cy = bow.Y - d.Y * (length - 1) / 2f;
        return Origin + new Vector2((cx + 0.5f) * CellSize, (cy + 0.5f) * CellSize);
    }

    // 世界/画布坐标 → 屏幕（视口）坐标：经当前画布变换（含相机平移/缩放）换算，供 HUD 伤害数字等屏幕定位。
    public Vector2 WorldToScreen(Vector2 world) => GetViewport().GetCanvasTransform() * world;
    public Vector2 GridToScreenCenter(GridPos cell) => WorldToScreen(GridToWorldCenter(cell));
    public Vector2 ShipCenterToScreen(GridPos bow, int length, CardinalDirection facing)
        => WorldToScreen(ShipCenterToWorld(bow, length, facing));

    public bool RangeOverlayContains(GridPos cell) => _moveRange.Contains(cell);
    public bool AttackTargetOverlayContains(GridPos cell) => _attackArcs.Any(a => a.Cell == cell);
    public bool CellOverlayContains(GridPos cell) => _cellOverlays.Any(o => o.Cell == cell);

    // UX-3：覆盖层计数（headless 交互断言"移动/攻击范围分离"用）——反映当前实际渲染的高亮，
    // 与规则查询（MoveRangeCount 等）区分开：断言"此刻画面上画了什么"而非"理论上能走到哪"。
    public int MoveRangeOverlayCount() => _moveRange.Count;
    public int AttackArcsOverlayCount() => _attackArcs.Count;
    public int CellOverlayCount() => _cellOverlays.Count;
    public int HighlightShipCount() => _highlightShipIds.Count;
    public float CameraZoomValue() => _camera?.Zoom.X ?? 1f;
    public bool AnimatedSeaUsesSeamlessMirrorSampling()
    {
        var code = ((_animatedSeaSurface?.Material as ShaderMaterial)?.Shader?.Code) ?? string.Empty;
        return code.Contains("vec2 mirror_repeat") && code.Contains("texture(TEXTURE, mirror_repeat")
            && !code.Contains("texture(TEXTURE, fract");
    }
    public bool AnimatedSeaCausticsReduced()
    {
        var code = ((_animatedSeaSurface?.Material as ShaderMaterial)?.Shader?.Code) ?? string.Empty;
        return code.Contains("caustic_strength = 0.14");
    }
    public Vector2 CameraPositionValue() => _camera?.Position ?? Vector2.Zero;
    public Rect2 CameraBackgroundBounds() => _backgroundBounds;
    public bool CameraViewInsideBackground()
    {
        if (_camera is null) return true;
        var zoom = new Vector2(Mathf.Max(0.001f, _camera.Zoom.X), Mathf.Max(0.001f, _camera.Zoom.Y));
        var halfView = GetViewport().GetVisibleRect().Size / zoom * 0.5f;
        return _backgroundBounds.Encloses(new Rect2(_camera.Position - halfView, halfView * 2f));
    }

    public void ShowMoveRange(IEnumerable<GridPos> cells)
    {
        _moveRange.Clear();
        _moveRange.AddRange(cells);
        QueueRedraw();
    }

    // 射界弧（T13）：直接显示规则层 AttackRules.QueryAttackArcs 结果（分武器弧 + 实弹/盲射格），不重复实现规则。
    public void ShowAttackArcs(IEnumerable<AttackArcOption> arcs)
    {
        _attackArcs.Clear();
        _attackArcs.AddRange(arcs);
        QueueRedraw();
    }

    // 技能/布雷目标格覆盖：Solid=true 实心色块，false 空心描边。
    public void ShowCellOverlay(IEnumerable<GridPos> cells, Color color, bool solid)
    {
        _cellOverlays.Clear();
        foreach (var c in cells) _cellOverlays.Add((c, color, solid));
        QueueRedraw();
    }

    // 逐格覆盖（T13 连锁弹/火油实弹格 vs 盲射格分色）：每格独立 (格, 色, 实心/空心)。
    public void ShowCellOverlays(IEnumerable<(GridPos Cell, Color Color, bool Solid)> overlays)
    {
        _cellOverlays.Clear();
        _cellOverlays.AddRange(overlays);
        QueueRedraw();
    }

    // 待定战术（撞击/接舷）目标舰高亮：以舰船占格画亮环。
    public void ShowShipTargets(IEnumerable<string> shipIds)
    {
        _highlightShipIds.Clear();
        foreach (var id in shipIds) _highlightShipIds.Add(id);
        QueueRedraw();
    }

    // 撞击方向箭头（瞬态，_Process 淡出）。
    public void ShowRamArrow(Vector2 fromWorld, Vector2 toWorld)
    {
        _ramLine = (fromWorld, toWorld, 0f);
        QueueRedraw();
    }

    // 水雷爆炸圈（瞬态，_Process 淡出）。
    public void ShowExplosion(GridPos cell)
    {
        _explosions.Add((cell, 0f));
        QueueRedraw();
    }

    // 布阵区域底色（玩家/敌方区域，T8）。
    public void ShowDeploymentZones(IEnumerable<(Rect2I Rect, Color Color)> zones)
    {
        _zones.Clear();
        _zones.AddRange(zones);
        QueueRedraw();
    }

    public int DeploymentZoneCount() => _zones.Count;
    public Color DeploymentZoneColor(int index)
        => index >= 0 && index < _zones.Count ? _zones[index].Color : Colors.Transparent;

    public void ShowDeploymentCells(IEnumerable<GridPos> cells, Color color)
    {
        _deploymentCells.Clear();
        _deploymentCells.UnionWith(cells);
        _deploymentCellColor = color;
        QueueRedraw();
    }

    public int DeploymentCellCount() => _deploymentCells.Count;
    public bool DeploymentCellContains(GridPos cell) => _deploymentCells.Contains(cell);

    // F-6：战争迷雾——视野内可见格集合（玩家阵营观测）。由控制器经规则层 AttackRules.VisibleCells 算好传入，
    // 迷雾随回合/行动刷新（RefreshVisibility）；视野外格子 _Draw 画墨色覆盖。
    public void ShowFog(IEnumerable<GridPos> visibleCells)
    {
        _fogVisible = visibleCells.ToHashSet();
        QueueRedraw();
    }

    // F-6：格当前是否在视野内（headless 冒烟断言用；无迷雾数据=未初始化，默认全部可见）。
    public bool FogCellVisible(int x, int y) => _fogVisible is null || _fogVisible.Contains(new GridPos(x, y));

    public void ClearOverlay()
    {
        _moveRange.Clear();
        _attackArcs.Clear();
        _cellOverlays.Clear();
        _highlightShipIds.Clear();
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (_battle is null) return;
        var map = _battle.Map;
        var w = map.Width;
        var h = map.Height;
        // 海面使用低对比度水墨像素底纹；格子地形只作半透明着色，避免再次盖成纯色方块。
        var mapRect = new Rect2(Origin, new Vector2(w * CellSize, h * CellSize));
        if (_animatedSeaSurface is null && _seaTexture is not null)
            DrawTextureRect(_seaTexture, mapRect, false, new Color(0.92f, 0.96f, 0.94f, 1f));
        else if (_animatedSeaSurface is null)
            DrawRect(mapRect, new Color(0.50f, 0.64f, 0.66f));
        // UX-5 伪 3D 海面：格面只保留低对比度地形色，亮纹统一交给动态海面 shader。
        for (var x = 0; x < w; x++)
        {
            for (var y = 0; y < h; y++)
            {
                var cell = new GridPos(x, y);
                var rect = CellFaceRect(cell);
                DrawCellFace(rect, map.TerrainAt(cell), Hash01(x, y, 19));
                switch (map.TerrainAt(cell))
                {
                    case TerrainType.DeepWater:
                    case TerrainType.Shallow:
                        break;
                    case TerrainType.Reef:
                        break;
                    case TerrainType.Mountain:
                        break;
                }
                if (map.IsWreck(cell))
                    DrawRect(rect, new Color(0.25f, 0.22f, 0.18f, 0.9f));
            }
        }
        DrawGridJunctions(w, h);
        // 障碍物为透明抠图，绘制在海面与网格之上；迷雾、提示与舰船仍可在其上正常叠加。
        DrawTerrainObstacles(map, w, h);
        // F-6：战争迷雾——视野外格子覆盖墨色半透明迷雾（玩家阵营观测）。画在网格线之后、出口/射界/水雷等提示之前：
        // 出口标记（地图边界提示）与已揭示水雷（规则层揭示机制）保留叠在迷雾之上；舰船视图在独立 Node2D 上，
        // 己方舰与可见敌舰在视野内无迷雾，隐藏敌舰视图不可见自然被迷雾盖住。
        DrawFog();
        // F-2：地图出口边界标记（设计 16.1）——出口格暖沙底色 + 边框 + 指向外侧的方向箭头。
        DrawExitCells(map);
        // 2.5D 舰船阴影由 NavalShipView 按素材实际水线绘制；这里不再使用占格矩形代替船影。
        // 移动范围水墨半透明高亮
        foreach (var cell in _moveRange)
            DrawRect(CellFaceRect(cell).Grow(-1f), new Color(0.18f, 0.58f, 0.55f, 0.42f));
        // 射界弧（T13）：分武器弧着色；实弹格实心，盲射空格空心描边（避免把空箭雨格当成可命中格）。
        foreach (var arc in _attackArcs)
        {
            var (fill, liveBorder) = ArcColors(arc.Kind);
            var rect = CellFaceRect(arc.Cell).Grow(-1f);
            if (arc.HasTarget)
                DrawRect(rect, fill);
            else
                DrawRect(rect, liveBorder, false, 2.5f); // 空心 = 盲射（无目标，点击消耗动作）
        }
        // 技能/布雷目标格覆盖
        foreach (var (cell, color, solid) in _cellOverlays)
        {
            var rect = CellFaceRect(cell).Grow(-1.5f);
            if (solid) DrawRect(rect, color);
            else DrawRect(rect, color, false, 2.5f);
        }
        // 布阵区域底色
        foreach (var (zone, color) in _zones)
            for (var x = zone.Position.X; x < zone.Position.X + zone.Size.X; x++)
                for (var y = zone.Position.Y; y < zone.Position.Y + zone.Size.Y; y++)
                    DrawRect(CellFaceRect(new GridPos(x, y)), color);
        // 蓝格直接来自布阵控制器的实际 ValidatePlacement 结果，而非矩形范围近似。
        foreach (var cell in _deploymentCells)
            DrawRect(CellFaceRect(cell).Grow(-1f), _deploymentCellColor);
        // 已发现水雷（T12 结转 T13）：只画 Revealed 的雷（深色菱形 + 生命文字）。
        DrawRevealedMines(map);
        // 接舷连线 + 俘获进度/控制方（T13）。
        DrawBoardingLinks();
        // 撞击方向箭头（瞬态）。
        if (_ramLine is { } line)
            DrawRamArrow(line.From, line.To, line.Age);
        // 水雷爆炸圈（瞬态）。
        foreach (var (cell, age) in _explosions)
            DrawExplosionRing(cell, age);
        // 本回合已行动舰船标记（船头上方小点）
        foreach (var ship in _battle.Ships.Values)
        {
            if (ship.Faction == _battle.CurrentFaction && ship.HitPoints > 0 && ship.HasAttacked)
                DrawCircle(GridToWorldCenter(ship.Bow) + new Vector2(0, -CellSize * 0.4f), 6f, new Color(0.15f, 0.2f, 0.15f, 0.8f));
        }
        // 待定战术目标舰高亮环（撞击/接舷）
        foreach (var id in _highlightShipIds)
        {
            var ship = _battle.ShipOrNull(id);
            if (ship is null || ship.HitPoints <= 0) continue;
            foreach (var c in ship.OccupiedCells())
                DrawRect(CellFaceRect(c).Grow(-2f), new Color(0.95f, 0.55f, 0.15f, 0.85f), false, 3f);
        }
    }

    // F-6：战争迷雾覆盖绘制——遍历地图，视野外格盖墨色迷雾（逐格半透明，网格线透过迷雾仍可辨）。
    private void DrawFog()
    {
        if (_battle is null || _fogVisible is null) return;
        var map = _battle.Map;
        for (var x = 0; x < map.Width; x++)
            for (var y = 0; y < map.Height; y++)
            {
                if (_fogVisible.Contains(new GridPos(x, y))) continue;
                DrawRect(CellFaceRect(new GridPos(x, y)), FogColor);
            }
    }

    // F-2：地图出口边界标记（设计 16.1）——出口格：暖沙底色 + 边框高亮 + 指向地图外侧的方向箭头；
    // 每列中部一格加「出口」文字标签。提示"开到边缘即逃"。
    private void DrawExitCells(BattleMap map)
    {
        if (map.ExitCells.Count == 0) return;
        var midY = map.Height / 2;
        foreach (var c in map.ExitCells)
        {
            var rect = CellFaceRect(c);
            DrawRect(rect, new Color(0.82f, 0.70f, 0.42f, 0.20f));
            DrawRect(rect, new Color(0.62f, 0.48f, 0.22f, 0.55f), false, 2f);
            // 箭头指向地图外侧：x=0 列朝左、其余（右边缘）朝右。
            var dir = c.X <= 0 ? new Vector2(-1, 0) : new Vector2(1, 0);
            var center = rect.GetCenter();
            var head = center + dir * CellSize * 0.28f;
            var tail = center - dir * CellSize * 0.18f;
            var perp = new Vector2(-dir.Y, dir.X);
            var ink = new Color(0.55f, 0.42f, 0.18f, 0.85f);
            DrawLine(tail, head, ink, 3f);
            DrawColoredPolygon(new[]
            {
                head,
                head - dir * 8f + perp * 6f,
                head - dir * 8f - perp * 6f,
            }, ink);
            if (c.Y == midY)
                DrawTextAt(center + new Vector2(-8, -CellSize * 0.42f), "出口", new Color(0.50f, 0.36f, 0.12f, 0.95f), 13);
        }
    }

    // 射界弧配色：实弹格实心色、盲射格空心描边色。
    private static (Color Fill, Color HollowBorder) ArcColors(WeaponKind kind) => kind switch
    {
        WeaponKind.ArrowRain => (new Color(0.85f, 0.20f, 0.16f, 0.32f), new Color(0.62f, 0.14f, 0.10f, 0.55f)),
        WeaponKind.Bombardment => (new Color(0.90f, 0.45f, 0.10f, 0.28f), new Color(0.62f, 0.32f, 0.08f, 0.55f)),
        _ => (new Color(0.62f, 0.10f, 0.12f, 0.34f), new Color(0.45f, 0.08f, 0.10f, 0.60f)),
    };

    private void DrawRevealedMines(BattleMap map)
    {
        foreach (var mine in map.Mines.Values)
        {
            if (!mine.Revealed) continue;
            var center = GridToWorldCenter(mine.Cell);
            var half = CellSize * 0.32f;
            DrawColoredPolygon(new[]
            {
                center + new Vector2(0, -half),
                center + new Vector2(half, 0),
                center + new Vector2(0, half),
                center + new Vector2(-half, 0),
            }, new Color(0.12f, 0.14f, 0.22f, 0.95f));
            DrawColoredPolygon(new[]
            {
                center + new Vector2(0, -half * 0.55f),
                center + new Vector2(half * 0.55f, 0),
                center + new Vector2(0, half * 0.55f),
                center + new Vector2(-half * 0.55f, 0),
            }, new Color(0.55f, 0.62f, 0.72f, 0.9f));
            DrawTextAt(center + new Vector2(-8, -6), "雷", new Color(1f, 1f, 1f, 0.95f), 13);
            DrawTextAt(center + new Vector2(8, 10), $"{mine.HitPoints}", new Color(0.95f, 0.30f, 0.25f, 0.9f), 11);
        }
    }

    // 接舷连线：两舰中心连线 + 中点「俘获 X% · 组合控制=防守方(被接舷舰)」。
    private void DrawBoardingLinks()
    {
        var links = _battle!.Ships.Values.Where(s => s.Boarding is not null).Select(s => s.Boarding!).Distinct();
        foreach (var link in links)
        {
            var initiator = _battle!.ShipOrNull(link.InitiatorId);
            var defender = _battle!.ShipOrNull(link.DefenderId);
            if (initiator is null || defender is null || initiator.HitPoints <= 0 || defender.HitPoints <= 0) continue;
            var a = ShipCenterToWorld(initiator.Bow, initiator.Length, initiator.Facing);
            var b = ShipCenterToWorld(defender.Bow, defender.Length, defender.Facing);
            var color = initiator.Faction == FactionId.Player
                ? new Color(0.20f, 0.75f, 0.55f, 0.9f)
                : new Color(0.80f, 0.45f, 0.20f, 0.9f);
            DrawLine(a, b, color, 3f);
            DrawCircle(a, 5f, color);
            DrawCircle(b, 5f, color);
            var mid = (a + b) / 2f;
            DrawTextAt(mid + new Vector2(-52, -26), $"俘获 {link.CaptureProgress}%", new Color(0.95f, 0.90f, 0.55f, 1f), 14);
            DrawTextAt(mid + new Vector2(-52, -10), $"组合控制：{link.DefenderId}(防守方)", new Color(0.88f, 0.94f, 0.98f, 0.9f), 12);
        }
    }

    // 撞击方向箭头：自撞击舰船头指向目标，末段箭头 + 「撞击」标注；随年龄淡出。
    private void DrawRamArrow(Vector2 from, Vector2 to, float age)
    {
        var alpha = Mathf.Clamp(1f - age / 1.8f, 0f, 1f);
        var color = new Color(0.95f, 0.25f, 0.15f, alpha);
        var dir = to - from;
        if (dir.Length() < 1f) return;
        var head = dir.Normalized();
        var perp = new Vector2(-head.Y, head.X);
        var arrowLen = 14f;
        var tip = to;
        var basePos = tip - head * arrowLen;
        DrawLine(from, basePos, color, 4f);
        DrawColoredPolygon(new[]
        {
            tip,
            basePos + perp * 8f,
            basePos - perp * 8f,
        }, color);
        DrawTextAt(tip + new Vector2(-18, -20), "撞击!", new Color(1f, 0.35f, 0.2f, alpha), 15);
    }

    // 水雷爆炸圈：半径随时间扩大、透明度降低。
    private void DrawExplosionRing(GridPos cell, float age)
    {
        var t = age / 0.9f;
        var center = GridToWorldCenter(cell);
        var radius = CellSize * (0.4f + t * 1.3f);
        var color = new Color(0.98f, 0.55f, 0.15f, Mathf.Clamp(1f - t, 0f, 1f));
        DrawArc(center, radius, 0f, Mathf.Tau, 40, color, 4f);
    }

    // 文本绘制助手：ThemeDB 回退字体（headless 可用）。DrawString 为 CanvasItem 实例方法，故非 static。
    private void DrawTextAt(Vector2 pos, string text, Color color, int size)
    {
        var font = ThemeDB.FallbackFont;
        if (font is null) return;
        DrawString(font, pos, text, HorizontalAlignment.Left, -1, size, color);
    }

    private Rect2 CellRect(GridPos cell)
        => new(Origin + new Vector2(cell.X * CellSize, cell.Y * CellSize), new Vector2(CellSize, CellSize));

    // 可见格面比逻辑格内缩 1.5px；相邻格之间形成稳定 3px 海面间隙，点击/规则坐标仍沿用完整逻辑格。
    private Rect2 CellFaceRect(GridPos cell) => CellRect(cell).Grow(-CellGap * 0.5f);

    private void DrawCellFace(Rect2 rect, TerrainType terrain, int seed)
    {
        var tint = terrain switch
        {
            TerrainType.Shallow => new Color(0.75f, 0.69f, 0.48f, 0.15f),
            TerrainType.Reef => new Color(0.43f, 0.48f, 0.38f, 0.16f),
            TerrainType.Mountain => new Color(0.35f, 0.40f, 0.31f, 0.18f),
            // U-2a 新地形底色（低于瓦片；瓦片缺纹理时色面仍可见）。
            TerrainType.Beach => new Color(0.83f, 0.78f, 0.58f, 0.20f),
            TerrainType.Forest => new Color(0.30f, 0.43f, 0.25f, 0.22f),
            TerrainType.Grass => new Color(0.55f, 0.66f, 0.38f, 0.22f),
            TerrainType.Port => new Color(0.60f, 0.50f, 0.36f, 0.22f),
            TerrainType.Town => new Color(0.58f, 0.58f, 0.55f, 0.22f),
            TerrainType.River => new Color(0.55f, 0.70f, 0.76f, 0.16f),
            _ => new Color(0.74f, 0.84f, 0.82f, 0.08f),
        };
        // 每格轻微明暗差避免机械复制，但保持低对比，不盖住水墨海面。
        var variation = ((seed % 7) - 3) * 0.006f;
        DrawRect(rect, tint.Lightened(variation));
        DrawRect(rect, new Color(0.13f, 0.25f, 0.23f, 0.34f), false, 1.25f);
        DrawLine(rect.Position + new Vector2(2f, 2f), new Vector2(rect.End.X - 2f, rect.Position.Y + 2f),
            new Color(0.88f, 0.90f, 0.78f, 0.13f), 1f);
    }

    // 参考战棋格在间隙交点放置小墨结，强调“独立格面”而不是四条连续直线。
    private void DrawGridJunctions(int width, int height)
    {
        var color = new Color(0.18f, 0.30f, 0.27f, 0.46f);
        for (var x = 1; x < width; x++)
            for (var y = 1; y < height; y++)
            {
                var center = Origin + new Vector2(x * CellSize, y * CellSize);
                DrawRect(new Rect2(center - new Vector2(1.5f, 1.5f), new Vector2(3f, 3f)), color);
            }
    }

    // ---- UX-5 伪 3D 海面/舰船阴影辅助 ----

    // 确定性格哈希：取非负小整数，供格面明暗和地形素材稳定选型。
    private static int Hash01(int x, int y, int salt)
        => ((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7fffffff;

    private void DrawTerrainObstacles(BattleMap map, int width, int height)
    {
        for (var x = 0; x < width; x++)
        {
            for (var y = 0; y < height; y++)
            {
                var cell = new GridPos(x, y);
                var rect = CellFaceRect(cell);
                switch (map.TerrainAt(cell))
                {
                    case TerrainType.Shallow:
                        var shallowSeed = Hash01(x, y, 2);
                        // 浅滩只稀疏出现珊瑚，避免每格都有大物件造成视觉拥堵。
                        if (shallowSeed % 3 == 0)
                            DrawTerrainSprite(_coralTextures, rect, shallowSeed);
                        break;
                    case TerrainType.Reef:
                        var reefSeed = Hash01(x, y, 3);
                        if (!DrawTerrainSprite(_reefTextures, rect, reefSeed))
                            DrawReefRock(rect, reefSeed);
                        break;
                    case TerrainType.Mountain:
                        var islandSeed = Hash01(x, y, 4);
                        if (!DrawTerrainSprite(_islandTextures, rect, islandSeed))
                            DrawIsland(rect, islandSeed);
                        break;
                    // U-2a：新地形瓦片（占位；缺纹理回退程序化几何绘制，不崩溃）。
                    case TerrainType.Beach:
                        var beachSeed = Hash01(x, y, 10);
                        if (!DrawTerrainSprite(_beachTextures, rect, beachSeed))
                            DrawLandPatch(rect, beachSeed, new Color(0.88f, 0.82f, 0.58f), new Color(0.76f, 0.66f, 0.40f), 2);
                        break;
                    case TerrainType.Forest:
                        var forestSeed = Hash01(x, y, 11);
                        if (!DrawTerrainSprite(_forestTextures, rect, forestSeed))
                            DrawLandPatch(rect, forestSeed, new Color(0.32f, 0.46f, 0.26f), new Color(0.20f, 0.32f, 0.17f), 3);
                        break;
                    case TerrainType.Grass:
                        var grassSeed = Hash01(x, y, 12);
                        if (!DrawTerrainSprite(_grassTextures, rect, grassSeed))
                            DrawLandPatch(rect, grassSeed, new Color(0.60f, 0.72f, 0.40f), new Color(0.44f, 0.56f, 0.28f), 1);
                        break;
                    case TerrainType.Port:
                        var portSeed = Hash01(x, y, 13);
                        if (!DrawTerrainSprite(_portTextures, rect, portSeed))
                            DrawLandPatch(rect, portSeed, new Color(0.62f, 0.52f, 0.36f), new Color(0.48f, 0.38f, 0.24f), 2);
                        break;
                    case TerrainType.Town:
                        var townSeed = Hash01(x, y, 14);
                        if (!DrawTerrainSprite(_townTextures, rect, townSeed))
                            DrawLandPatch(rect, townSeed, new Color(0.64f, 0.63f, 0.60f), new Color(0.50f, 0.49f, 0.46f), 2);
                        break;
                    case TerrainType.River:
                        var riverSeed = Hash01(x, y, 15);
                        if (!DrawTerrainSprite(_riverTextures, rect, riverSeed))
                            DrawRiver(rect, riverSeed);
                        break;
                }
            }
        }
    }

    private static void LoadTerrainTextures(string kind, List<Texture2D> target)
    {
        target.Clear();
        for (var index = 0; index < 4; index++)
        {
            var path = $"res://assets/naval/battle/terrain/{kind}_{index}.png";
            if (ResourceLoader.Exists(path) && GD.Load<Texture2D>(path) is { } texture)
                target.Add(texture);
        }
    }

    // 按格坐标哈希稳定选取变体：位置随机但不会随重绘闪烁。素材严格收在单格内并留 2px 水面边距。
    private bool DrawTerrainSprite(IReadOnlyList<Texture2D> textures, Rect2 cellRect, int seed)
    {
        if (textures.Count == 0) return false;
        var texture = textures[seed % textures.Count];
        var textureWidth = Mathf.Max(1f, texture.GetWidth());
        var textureHeight = Mathf.Max(1f, texture.GetHeight());
        var maxSize = CellSize - 4f;
        var scale = maxSize / Mathf.Max(textureWidth, textureHeight);
        var size = new Vector2(textureWidth * scale, textureHeight * scale);
        var target = new Rect2(
            new Vector2(cellRect.GetCenter().X - size.X * 0.5f, cellRect.End.Y - size.Y - 2f),
            size);
        DrawTextureRect(texture, target, false, new Color(0.92f, 0.95f, 0.91f, 1f));
        return true;
    }

    // 礁石：不规则多边形暗底 + 偏移亮顶面 → 露出水面的立体礁石。
    private void DrawReefRock(Rect2 rect, int seed)
    {
        var center = rect.GetCenter();
        var s = rect.Size.X;
        var basePoly = JaggedPoly(center, s * 0.42f, 7, seed, 0.72f, 1.28f);
        DrawColoredPolygon(basePoly, new Color(0.40f, 0.29f, 0.20f, 0.98f));
        var top = JaggedPoly(center + new Vector2(-s * 0.06f, -s * 0.10f), s * 0.29f, 7, seed + 3, 0.72f, 1.22f);
        DrawColoredPolygon(top, new Color(0.60f, 0.47f, 0.32f, 0.98f));
        DrawPolyline(basePoly, new Color(0.05f, 0.08f, 0.06f, 0.6f), 1.5f);
    }

    // 岛屿/山地：凸起岛形（沙滩底 + 植被顶 + 高光），轮廓略超格子 → 伪 3D 隆起。
    private void DrawIsland(Rect2 rect, int seed)
    {
        var center = rect.GetCenter();
        var s = rect.Size.X;
        var basePoly = JaggedPoly(center, s * 0.56f, 8, seed, 0.80f, 1.26f);
        DrawColoredPolygon(basePoly, new Color(0.62f, 0.54f, 0.36f, 1f));
        var topPoly = JaggedPoly(center + new Vector2(-s * 0.08f, -s * 0.12f), s * 0.40f, 7, seed + 5, 0.80f, 1.20f);
        DrawColoredPolygon(topPoly, new Color(0.40f, 0.50f, 0.30f, 1f));
        DrawPolyline(topPoly, new Color(0.08f, 0.12f, 0.08f, 0.70f), 2f);
        DrawPolyline(basePoly, new Color(0.08f, 0.12f, 0.08f, 0.50f), 1.5f);
        DrawCircle(center + new Vector2(-s * 0.10f, -s * 0.16f), s * 0.05f, new Color(0.85f, 0.85f, 0.60f, 0.55f));
    }

    // U-2a 新地形占位回退：陆地色块（海滩/林地/草地/港口/小镇）——收在单格内的圆角墨色陆块 + 植被小点。
    // 缺瓦片纹理时使用；纹理导入后自动被 DrawTerrainSprite 替换。
    private void DrawLandPatch(Rect2 rect, int seed, Color baseColor, Color accent, int dotCount)
    {
        var center = rect.GetCenter();
        var s = rect.Size.X;
        var basePoly = JaggedPoly(center, s * 0.40f, 8, seed, 0.78f, 1.20f);
        DrawColoredPolygon(basePoly, baseColor);
        DrawPolyline(basePoly, new Color(0.06f, 0.10f, 0.08f, 0.45f), 1.2f);
        for (var i = 0; i < dotCount; i++)
        {
            var h = Hash01(seed, i, 21);
            var ang = Mathf.Tau * (h % 1000) / 1000f;
            var r = (s * 0.16f) * (1f + (h / 7 % 3) * 0.25f);
            DrawCircle(center + new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)) * r, s * (0.05f + (h % 5) * 0.008f), accent);
        }
    }

    // U-2a 陆河占位回退：格内蜿蜒水道（两端缩进留岸缘），浅水色带 + 中缝深色流线。
    private void DrawRiver(Rect2 rect, int seed)
    {
        var left = new Vector2(rect.Position.X + rect.Size.X * 0.16f, rect.Position.Y + rect.Size.Y * 0.5f);
        var right = new Vector2(rect.End.X - rect.Size.X * 0.16f, rect.Position.Y + rect.Size.Y * 0.5f);
        // 依据种子轻微上下偏移，避免整条河完全笔直。
        var wave = (Hash01(seed, 1, 31) % 5) - 2;
        var mid = left + new Vector2(rect.Size.X * 0.5f, wave);
        var points = new Vector2[] { left, mid, right };
        DrawPolyline(points, new Color(0.58f, 0.74f, 0.80f, 0.85f), Mathf.Max(2f, rect.Size.X * 0.18f), true);
        DrawPolyline(points, new Color(0.34f, 0.52f, 0.60f, 0.55f), 1.4f, true);
    }

    // 确定性抖动多边形（岩石/岛屿轮廓）。
    private static Vector2[] JaggedPoly(Vector2 center, float radius, int count, int seed, float minScale, float maxScale)
    {
        var pts = new Vector2[count];
        for (var i = 0; i < count; i++)
        {
            var angle = Mathf.Tau * i / count;
            var h = Hash01(seed, i, 11);
            var scale = minScale + (h % 1000) / 1000f * (maxScale - minScale);
            pts[i] = center + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius * scale;
        }
        return pts;
    }

    // 舰船底阴影：占格包围盒 + 固定右下偏移（不随朝向旋转），两层叠出柔和影缘 → 「浮起感」。
    private void DrawShipShadows(BattleState battle)
    {
        var visible = AttackRules.VisibleEnemies(battle, FactionId.Player);
        foreach (var ship in battle.Ships.Values)
        {
            if (ship.HitPoints <= 0) continue;
            if (ship.Faction != FactionId.Player && !visible.Contains(ship)) continue;
            var rect = ShadowRectFor(ship);
            if (rect is null) continue;
            DrawRect(rect.Value, new Color(0.06f, 0.10f, 0.09f, 0.32f));
            DrawRect(rect.Value.Grow(-3f), new Color(0.06f, 0.10f, 0.09f, 0.18f));
        }
    }

    // UX-11：舰船底阴影当前世界矩形（占格包围盒 + 右下偏移 (5,6) → 浮起感；不随朝向旋转）。
    // 由 ship 当前占格（Bow/Facing）实时推导——布阵/战斗移动、转向后只要网格重绘，阴影即随船。
    // 供 headless 冒烟断言"布阵移动后阴影位置与船一致"（阴影在世界空间由本网格按 ship 状态绘制，非独立节点）。
    public Rect2 ShipShadowRect(string shipId)
    {
        if (_battle is null) return new Rect2();
        var ship = _battle.ShipOrNull(shipId);
        return ship is null ? new Rect2() : ShadowRectFor(ship) ?? new Rect2();
    }

    private static Rect2? ShadowRectFor(ShipState ship)
    {
        var cells = ship.OccupiedCells();
        if (cells.Count == 0) return null;
        var minX = cells[0].X; var maxX = cells[0].X;
        var minY = cells[0].Y; var maxY = cells[0].Y;
        foreach (var c in cells)
        {
            if (c.X < minX) minX = c.X;
            if (c.X > maxX) maxX = c.X;
            if (c.Y < minY) minY = c.Y;
            if (c.Y > maxY) maxY = c.Y;
        }
        var rect = new Rect2(
            Origin + new Vector2(minX * CellSize, minY * CellSize),
            new Vector2((maxX - minX + 1) * CellSize, (maxY - minY + 1) * CellSize));
        rect.Position += new Vector2(5f, 6f); // 右下偏移（浮起感）
        return rect;
    }
}
