#nullable enable
using Godot;
using NavalCombat.Core;
using System.Collections.Generic;

namespace NanjiangNaval;

// 舰船视图（UX-5 伪 3D）：优先使用按四向重绘的像素舰艇素材，避免直接旋转 2.5D 图造成透视失真；
// 素材缺失时回退到代码绘制。船体只做轻微随浪浮动，移动仍由原战斗表现层 Tween 驱动，不改变规则。
public partial class NavalShipView : Node2D
{
    private const float SelectionInset = 1.5f;
    private const float MaxBobDown = 1.2f;
    private ShipState? _ship;
    private bool _selected;
    private bool _waitingForOrders;
    private bool _actedThisTurn;
    private Color _hullColor = Colors.Gray;
    private Color _bowColor = Colors.DarkRed;
    private HullProfile _profile;
    private Texture2D? _spriteTexture;
    private CardinalDirection _renderedFacing;
    private float _bobClock;
    private float _bobPhase;
    private float _bobOffset;
    private float _wakeClock;
    private float _wakeStrength;
    private Tween? _animTween; // UX-9：位置/朝向动画（移动/转向可视化）

    // F-2：舰船显示名（船已移出战场后无法经 battle.Ships 取名——逃跑消息用）。
    public string DisplayName => _ship?.Definition.DisplayName ?? "";
    // F-3：当前阵营底色（headless 冒烟断言"投降加入后视图重设阵营色"——Setup 重设后应为我方暖黄）。
    public string HullColorHex() => _hullColor.ToHtml();
    public bool WaitingForOrders() => _waitingForOrders;
    public bool ActedThisTurn() => _actedThisTurn;

    public void Setup(ShipState ship, NavalGridView grid)
    {
        _ship = ship;
        // 阵营底色：我方暖黄褐、敌方冷灰，保持水墨暖调黄绿褐基调。
        _hullColor = ship.Faction == FactionId.Player
            ? new Color(0.66f, 0.54f, 0.27f)
            : new Color(0.42f, 0.44f, 0.48f);
        _bowColor = ship.Faction == FactionId.Player
            ? new Color(0.92f, 0.80f, 0.55f) // 船头翘起高光（亮暖）
            : new Color(0.72f, 0.74f, 0.80f);
        _profile = ProfileFor(ship.Definition.Id);
        _spriteTexture = LoadSpriteFor(ship);
        _renderedFacing = ship.Facing;
        _bobPhase = WavePhaseFor(ship.Id);
        Position = grid.ShipCenterToWorld(ship.Bow, ship.Length, ship.Facing);
        Rotation = _spriteTexture is null ? FacingAngle(ship.Facing) : 0f;
        QueueRedraw();
    }

    public void SyncToShip(NavalGridView grid)
    {
        if (_ship is null) return;
        Position = grid.ShipCenterToWorld(_ship.Bow, _ship.Length, _ship.Facing);
        UpdateDirectionalSprite();
        QueueRedraw();
    }

    // UX-9：本视图从当前（动画前）位置/朝向到舰船当前状态所需动画时长（秒）。
    // 与 AnimateToShip 同口径（同一套 distCells/angle 折算），供控制器用「固定时长等待」代替
    // 「await tween Finished」——tween 可能被 Kill/零时长/已结束，其 finished 信号已发出后订阅将永不返回
    // → 卡死；固定时长等待只依赖 SceneTreeTimer.Timeout（恒可靠）。
    public float AnimSecondsFor(NavalGridView grid, float moveSecondsPerCell, float turnSeconds)
    {
        if (_ship is null) return 0f;
        var targetPos = grid.ShipCenterToWorld(_ship.Bow, _ship.Length, _ship.Facing);
        var distCells = Position.DistanceTo(targetPos) / NavalGridView.CellSize;
        if (_spriteTexture is not null)
        {
            var facingChanged = _renderedFacing != _ship.Facing;
            return Mathf.Max(distCells * moveSecondsPerCell, facingChanged ? turnSeconds : 0f);
        }

        var targetRot = FacingAngle(_ship.Facing);
        var angle = Mathf.Abs(Mathf.Wrap(Rotation - targetRot, -Mathf.Pi, Mathf.Pi)) / Mathf.Pi;
        return Mathf.Max(distCells * moveSecondsPerCell, angle * turnSeconds);
    }

    // UX-9：动画同步到舰船当前状态（位置平移到新格 + 朝向旋转）。返回已创建的 Tween（供调用方 await）；
    // duration 由调用方折算（移动按每格时长×距离，转向按转向时长）；duration<=0 或目标未变 → 直接落位返回 null。
    // 与 SyncToShip（瞬时）区别：本方法保留旧位置/朝向，经 Tween 过渡到新位置，敌方回合逐动作可视化。
    public Tween? AnimateToShip(NavalGridView grid, float moveSecondsPerCell, float turnSeconds)
    {
        if (_ship is null) return null;
        var targetPos = grid.ShipCenterToWorld(_ship.Bow, _ship.Length, _ship.Facing);
        var duration = AnimSecondsFor(grid, moveSecondsPerCell, turnSeconds);
        UpdateDirectionalSprite();
        var targetRot = _spriteTexture is null ? FacingAngle(_ship.Facing) : 0f;
        if (duration <= 0.0005f)
        {
            _animTween?.Kill();
            _animTween = null;
            Position = targetPos;
            Rotation = targetRot;
            QueueRedraw();
            return null;
        }
        if (Position.DistanceTo(targetPos) > 0.5f)
            _wakeStrength = 1f;
        // 位置/朝向并行过渡；新动画开始前杀掉旧动画（防并发写位置冲突）。
        _animTween?.Kill();
        _animTween = CreateTween();
        _animTween.SetParallel(true);
        _animTween.TweenProperty(this, "position", targetPos, duration)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        if (_spriteTexture is null)
        {
            _animTween.TweenProperty(this, "rotation", targetRot, duration)
                .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.InOut);
        }
        _animTween.Finished += () => { _animTween = null; };
        QueueRedraw();
        return _animTween;
    }

    public void SetSelected(bool selected)
    {
        _selected = selected;
        QueueRedraw();
    }

    // 仅控制战场表现，不改变舰船点击、剩余移动力或行动规则。
    public void SetTurnReadiness(bool waitingForOrders, bool actedThisTurn)
    {
        if (_waitingForOrders == waitingForOrders && _actedThisTurn == actedThisTurn) return;
        _waitingForOrders = waitingForOrders;
        _actedThisTurn = actedThisTurn;
        QueueRedraw();
    }

    public override void _Process(double delta)
    {
        if (_spriteTexture is null || _ship is null) return;
        var step = (float)delta;
        _bobClock += step;
        _wakeClock += step * (0.72f + _wakeStrength * 1.65f);
        var previousWakeStrength = _wakeStrength;
        _wakeStrength = Mathf.MoveToward(_wakeStrength, 0f, step * 0.52f);
        var nextOffset = Mathf.Sin(_bobClock * 1.65f + _bobPhase) * 0.90f
            + Mathf.Sin(_bobClock * 0.73f + _bobPhase * 0.6f) * 0.25f;
        if (Mathf.Abs(nextOffset - _bobOffset) < 0.04f
            && Mathf.Abs(previousWakeStrength - _wakeStrength) < 0.008f) return;
        _bobOffset = nextOffset;
        QueueRedraw();
    }

    private static float FacingAngle(CardinalDirection facing) => facing switch
    {
        CardinalDirection.East => 0f,
        CardinalDirection.South => Mathf.Pi / 2f,
        CardinalDirection.West => Mathf.Pi,
        CardinalDirection.North => -Mathf.Pi / 2f,
        _ => 0f,
    };

    private Color ActivityTint(Color color)
        => _actedThisTurn ? new Color(color.Darkened(0.42f), color.A * 0.78f) : color;

    public override void _Draw()
    {
        if (_ship is null) return;
        var c = NavalGridView.CellSize;
        var halfLen = _ship.Length * c / 2f;       // 船中心到船头/船尾距离
        var beam = _profile.Beam * c;              // 半宽（船舷到中线的距离）
        var ink = new Color(0.08f, 0.13f, 0.10f, 0.55f); // 墨线描边

        // F-4：自沉舰墨色加深（下沉感——船壳/甲板整体变暗）。
        var sunk = _ship.SelfSunk;
        var spriteRect = SpriteRect(c, halfLen);
        if (_spriteTexture is not null)
        {
            DrawSpriteShadow(spriteRect, c);
            DrawSternWake(spriteRect, c);
            DrawSetTransform(new Vector2(0f, _bobOffset));
            var modulate = sunk ? new Color(0.50f, 0.54f, 0.50f, 0.78f) : Colors.White;
            if (_actedThisTurn)
                modulate = new Color(modulate.Darkened(0.42f), modulate.A * 0.78f);
            DrawTextureRect(_spriteTexture, spriteRect, false, modulate);
            DrawSetTransform(Vector2.Zero);
        }
        else
        {
            DrawSternWake(spriteRect, c);
            DrawProceduralShip(halfLen, beam, c, ink, sunk);
        }
        // 未行动舰以青蓝描边提示“待命”；发生过移动/转向/攻击后改为暗色，但仍可点击。
        if (_waitingForOrders)
            DrawRect(LogicalFootprintRect(c).Grow(-SelectionInset), new Color(0.30f, 0.78f, 0.90f, 0.82f), false, 3f);
        // 选中高亮描边（占格范围）
        if (_selected)
        {
            var outline = _spriteTexture is not null
                ? LogicalFootprintRect(c).Grow(-SelectionInset)
                : new Rect2(-halfLen, -beam, _ship.Length * c, beam * 2f);
            DrawRect(outline, new Color(0.95f, 0.85f, 0.35f, 0.55f), false, 4f);
        }
        // F-4：自沉标记（设计 15）——浸水暗带 + 船尾「沉」字徽章（锚定浅滩的下沉感）。
        if (sunk)
            DrawSelfSunkMarker(halfLen, beam, c);
        // 状态图标（T13）：烧伤（火）/连锁弹减速（慢）/损管持续恢复（+）徽章挂船头侧上方
        DrawStatusBadges(c);
    }

    private Rect2 SpriteRect(float cell, float halfLen)
    {
        if (_spriteTexture is null) return new Rect2(-halfLen, -cell * 0.5f, halfLen * 2f, cell);
        var horizontal = _ship?.Facing is CardinalDirection.East or CardinalDirection.West;
        var logicalLength = (_ship?.Length ?? 1) * cell;
        var maxWidth = horizontal ? logicalLength * 0.96f : cell * 1.72f;
        var maxHeight = horizontal ? cell * 1.72f : logicalLength * 0.96f;
        var textureWidth = Mathf.Max(1f, _spriteTexture.GetWidth());
        var textureHeight = Mathf.Max(1f, _spriteTexture.GetHeight());
        var scale = Mathf.Min(maxWidth / textureWidth, maxHeight / textureHeight);
        var width = textureWidth * scale;
        var height = textureHeight * scale;
        // 以下边界为锚点：波浪下沉到最大值时刚好踩住黄色占格框，不进入下一格。
        var footprintBottom = LogicalFootprintRect(cell).Grow(-SelectionInset).End.Y;
        return new Rect2(-width * 0.5f, footprintBottom - MaxBobDown - height, width, height);
    }

    private Rect2 LogicalFootprintRect(float cell)
    {
        if (_ship is null) return new Rect2(-cell * 0.5f, -cell * 0.5f, cell, cell);
        var length = _ship.Length * cell;
        var horizontal = _ship.Facing is CardinalDirection.East or CardinalDirection.West;
        return horizontal
            ? new Rect2(-length * 0.5f, -cell * 0.5f, length, cell)
            : new Rect2(-cell * 0.5f, -length * 0.5f, cell, length);
    }

    private void UpdateDirectionalSprite()
    {
        if (_ship is null) return;
        _spriteTexture = LoadSpriteFor(_ship);
        _renderedFacing = _ship.Facing;
        Rotation = _spriteTexture is null ? FacingAngle(_ship.Facing) : 0f;
    }

    private static Texture2D? LoadSpriteFor(ShipState ship)
    {
        var path = SpritePathFor(ship);
        return ResourceLoader.Exists(path) ? GD.Load<Texture2D>(path) : null;
    }

    // HUD 舰况卡复用与战场一致的按阵营/舰型/朝向船只素材。
    public static Texture2D? HudTextureFor(ShipState ship) => LoadSpriteFor(ship);

    private static string SpritePathFor(ShipState ship)
    {
        var faction = ship.Faction == FactionId.Player ? "player" : "enemy";
        var shipType = ship.Definition.Id switch
        {
            "flagship" => "flagship",
            "frigate" => "frigate",
            "merchant" => "transport",
            "transport" => "transport",
            "sea_monster" => "sea_monster",
            "sea_fish" => "sea_fish",
            "wokou_citadel" => "citadel",
            "fort_turret" => "turret",
            _ => "frigate",
        };
        // 海怪与固定设施只提供单张贴图，不拼接朝向后缀。
        var directionless = shipType is "sea_monster" or "sea_fish" or "citadel" or "turret";
        if (directionless)
            return $"res://assets/naval/battle/ships/{faction}_{shipType}.png";
        var direction = ship.Facing switch
        {
            CardinalDirection.East => "e",
            CardinalDirection.South => "s",
            CardinalDirection.West => "w",
            CardinalDirection.North => "n",
            _ => "e",
        };
        return $"res://assets/naval/battle/ships/{faction}_{shipType}_{direction}.png";
    }

    private static float WavePhaseFor(string shipId)
    {
        var hash = 17;
        foreach (var c in shipId)
            hash = unchecked(hash * 31 + c);
        return (hash & 1023) / 1023f * Mathf.Tau;
    }

    // 船尾碎浪：沿航向反方向形成两股断续、外扩的水沫；移动时增强，停船后缓慢淡回。
    private void DrawSternWake(Rect2 spriteRect, float cell)
    {
        if (_ship is null || _ship.SelfSunk || _wakeStrength <= 0.02f) return;
        var (center, radiusX, radiusY) = SpriteFootprint(spriteRect, cell);
        var forward = LocalForward();
        var backward = -forward;
        var lateral = new Vector2(-backward.Y, backward.X);
        var alongRadius = Mathf.Abs(forward.X) > 0.5f ? radiusX : radiusY;
        var stern = center + backward * alongRadius * 0.76f;
        var wakeLength = cell * Mathf.Lerp(1.05f, 2.55f, _wakeStrength);
        var wakeSpread = cell * Mathf.Lerp(0.24f, 0.68f, _wakeStrength);
        var baseAlpha = Mathf.Lerp(0.10f, 0.58f, _wakeStrength);

        for (var sideIndex = 0; sideIndex < 2; sideIndex++)
        {
            var side = sideIndex == 0 ? -1f : 1f;
            for (var i = 0; i < 5; i++)
            {
                var t0 = 0.08f + i * 0.18f;
                var t1 = Mathf.Min(0.98f, t0 + 0.10f + (i % 2) * 0.025f);
                var phase = _wakeClock * 2.4f + _bobPhase + i * 1.73f + sideIndex * 0.91f;
                var jitter0 = Mathf.Sin(phase) * cell * 0.055f;
                var jitter1 = Mathf.Sin(phase + 1.17f) * cell * 0.065f;
                var width0 = cell * 0.08f + wakeSpread * t0;
                var width1 = cell * 0.08f + wakeSpread * t1;
                var start = stern + backward * wakeLength * t0
                    + lateral * side * (width0 + jitter0);
                var end = stern + backward * wakeLength * t1
                    + lateral * side * (width1 + jitter1);
                var middle = (start + end) * 0.5f
                    + lateral * side * Mathf.Sin(phase + 0.54f) * cell * 0.05f;
                var alpha = baseAlpha * (1f - t0)
                    * (0.78f + 0.22f * Mathf.Sin(phase + 2.1f));
                var points = new[] { start, middle, end };
                var lineWidth = Mathf.Lerp(0.80f, 1.65f, _wakeStrength);
                DrawPolyline(points, new Color(0.10f, 0.23f, 0.22f, alpha * 0.38f), lineWidth + 0.85f);
                DrawPolyline(points, new Color(0.86f, 0.94f, 0.89f, alpha), lineWidth);
            }
        }

        // 中轴零散短沫打破规则 V 形，避免再次形成完整弧线。
        for (var i = 0; i < 4; i++)
        {
            var t = 0.20f + i * 0.19f;
            var phase = _wakeClock * 2.1f + _bobPhase + i * 2.07f;
            var point = stern + backward * wakeLength * t
                + lateral * Mathf.Sin(phase) * cell * 0.11f;
            var halfWidth = cell * (0.035f + 0.025f * (1f - t));
            var alpha = baseAlpha * 0.58f * (1f - t);
            DrawLine(point - lateral * halfWidth, point + lateral * halfWidth,
                new Color(0.86f, 0.93f, 0.88f, alpha), 0.85f);
        }
    }

    private Vector2 LocalForward()
    {
        if (_spriteTexture is null) return Vector2.Right;
        return _ship?.Facing switch
        {
            CardinalDirection.North => Vector2.Up,
            CardinalDirection.East => Vector2.Right,
            CardinalDirection.South => Vector2.Down,
            CardinalDirection.West => Vector2.Left,
            _ => Vector2.Right,
        };
    }

    private void DrawSpriteShadow(Rect2 spriteRect, float cell)
    {
        var (center, radiusX, radiusY) = SpriteFootprint(spriteRect, cell);
        center += new Vector2(2.5f, 3.5f);
        DrawColoredPolygon(EllipsePoints(center, radiusX, radiusY, 24), new Color(0.04f, 0.08f, 0.07f, 0.24f));
        DrawColoredPolygon(EllipsePoints(center, radiusX * 0.78f, radiusY * 0.72f, 24), new Color(0.03f, 0.06f, 0.05f, 0.17f));
    }

    private (Vector2 Center, float RadiusX, float RadiusY) SpriteFootprint(Rect2 rect, float cell)
    {
        if (_ship is null) return (rect.GetCenter(), cell * 0.4f, cell * 0.18f);
        var horizontal = _ship.Facing is CardinalDirection.East or CardinalDirection.West;
        var length = _ship.Length * cell;
        return horizontal
            ? (Vector2.Zero, length * 0.44f, cell * 0.29f)
            : (Vector2.Zero, cell * 0.29f, length * 0.44f);
    }

    private static Vector2[] EllipsePoints(Vector2 center, float radiusX, float radiusY, int count)
    {
        var points = new Vector2[count];
        for (var i = 0; i < count; i++)
        {
            var angle = Mathf.Tau * i / count;
            points[i] = center + new Vector2(Mathf.Cos(angle) * radiusX, Mathf.Sin(angle) * radiusY);
        }
        return points;
    }

    private void DrawProceduralShip(float halfLen, float beam, float c, Color ink, bool sunk)
    {
        var hull = HullOutline(halfLen, beam);
        var deck = DeckOutline(halfLen, beam, c);
        DrawColoredPolygon(hull, ActivityTint(new Color(_hullColor.Darkened(sunk ? 0.48f : 0.30f), 0.95f)));
        DrawPolyline(hull, ink, 2f);
        DrawColoredPolygon(deck, ActivityTint(new Color(sunk ? _hullColor.Darkened(0.22f) : _hullColor, 0.96f)));
        DrawPolyline(deck, new Color(ink, 0.65f), 1.5f);
        DrawDeckPlanks(halfLen, beam);
        DrawSideShading(halfLen, beam, c);
        DrawProw(halfLen, beam, c);
        DrawSternCastle(halfLen, beam, c);
        DrawMast(halfLen, beam, c);
    }

    // F-4：自沉舰视觉标记——横贯船体中线的浸水暗带（船已半沉入水）+ 船尾上方深墨圆徽「沉」字。
    private void DrawSelfSunkMarker(float halfLen, float beam, float cell)
    {
        if (_ship is null) return;
        // 浸水暗带：船体中段暗色横带（下沉到吃水线之下）。
        DrawRect(new Rect2(-halfLen, -beam * 0.18f, _ship.Length * cell, beam * 0.36f), new Color(0.04f, 0.06f, 0.05f, 0.28f));
        // 沉锚徽章：船尾上方深墨圆徽 + 「沉」字（与状态徽章风格统一）。
        var center = new Vector2(-halfLen + cell * 0.10f, -beam - cell * 0.30f);
        DrawCircle(center, 8f, new Color(0.10f, 0.12f, 0.10f, 0.92f));
        DrawArc(center, 8f, 0f, Mathf.Tau, 20, new Color(0.30f, 0.36f, 0.30f, 0.9f), 1.5f);
        var font = ThemeDB.FallbackFont;
        if (font is not null)
            DrawString(font, center + new Vector2(-4f, 5f), "沉", HorizontalAlignment.Left, -1, 11, new Color(0.88f, 0.88f, 0.84f, 1f));
    }

    // ---- 伪 3D 船体各部件 ----

    // 船壳轮廓：从船尾到船头收尖（+X 为船头），前伸 prow 形成船首；末点=首点以闭合墨线描边。
    private Vector2[] HullOutline(float halfLen, float beam)
    {
        var prow = _profile.ProwLen * NavalGridView.CellSize;
        var tip = halfLen + prow;
        var pts = new[]
        {
            new Vector2(-halfLen, -beam),
            new Vector2(tip - prow * 1.4f, -beam),   // 肩部
            new Vector2(tip, 0f),                    // 船头尖端
            new Vector2(tip - prow * 1.4f, beam),
            new Vector2(-halfLen, beam),
        };
        return new[] { pts[0], pts[1], pts[2], pts[3], pts[4], pts[0] };
    }

    // 甲板轮廓：内缩、船头略圆；末点=首点闭合描边。
    private Vector2[] DeckOutline(float halfLen, float beam, float c)
    {
        var inset = Mathf.Min(0.12f * c, beam * 0.25f);
        var prow = _profile.ProwLen * c;
        var deckTip = halfLen + prow * 0.55f;
        var pts = new[]
        {
            new Vector2(-halfLen + inset, -beam + inset),
            new Vector2(deckTip - prow * 1.2f, -beam + inset),
            new Vector2(deckTip, 0f),
            new Vector2(deckTip - prow * 1.2f, beam - inset),
            new Vector2(-halfLen + inset, beam - inset),
        };
        return new[] { pts[0], pts[1], pts[2], pts[3], pts[4], pts[0] };
    }

    // 甲板木板缝：横贯中段 2~3 条短缝。
    private void DrawDeckPlanks(float halfLen, float beam)
    {
        var ink = new Color(0.08f, 0.13f, 0.10f, 0.30f);
        var yFrom = -beam * 0.45f;
        var yTo = beam * 0.45f;
        var xStart = -halfLen * 0.55f;
        var xEnd = halfLen * 0.60f;
        DrawLine(new Vector2(xStart, yFrom), new Vector2(xEnd, yFrom), ink, 1f);
        DrawLine(new Vector2(xStart, yTo), new Vector2(xEnd, yTo), ink, 1f);
        // 中线龙骨缝（略亮）
        DrawLine(new Vector2(-halfLen * 0.5f, 0f), new Vector2(halfLen * 0.55f, 0f), new Color(0.10f, 0.16f, 0.12f, 0.20f), 1f);
    }

    // 侧舷明暗：受光上缘亮线 + 背光下缘暗线 → 船体圆柱体积感。
    private void DrawSideShading(float halfLen, float beam, float c)
    {
        var lit = new Color(1f, 1f, 1f, 0.35f);
        var dark = new Color(0.05f, 0.08f, 0.06f, 0.45f);
        var prow = _profile.ProwLen * c;
        var tip = halfLen + prow;
        // 上缘（亮）
        DrawLine(new Vector2(-halfLen, -beam + 1.5f), new Vector2(tip - prow * 1.4f, -beam + 1.5f), lit, 2f);
        // 下缘（暗）
        DrawLine(new Vector2(-halfLen, beam - 1.5f), new Vector2(tip - prow * 1.4f, beam - 1.5f), dark, 2f);
    }

    // 船头翘起：前伸楔形高光顶面 + 暗面下缘（船首楼/船头尖一眼可辨）。
    private void DrawProw(float halfLen, float beam, float c)
    {
        var prow = _profile.ProwLen * c;
        var tip = halfLen + prow;
        var shoulder = tip - prow * 1.4f;
        // 翘起顶面（亮暖色）
        DrawColoredPolygon(new[]
        {
            new Vector2(tip, 0f),
            new Vector2(shoulder, -beam * 0.42f),
            new Vector2(shoulder, beam * 0.42f),
        }, ActivityTint(new Color(_bowColor, 0.98f)));
        // 暗面下缘：前伸三角下沿（强调翘起高度）
        DrawColoredPolygon(new[]
        {
            new Vector2(tip, 0f),
            new Vector2(shoulder, beam * 0.42f),
            new Vector2(shoulder, beam * 0.62f),
        }, ActivityTint(new Color(_bowColor.Darkened(0.45f), 0.9f)));
        DrawPolyline(new[]
        {
            new Vector2(shoulder, -beam * 0.42f),
            new Vector2(tip, 0f),
            new Vector2(shoulder, beam * 0.42f),
        }, new Color(0.08f, 0.13f, 0.10f, 0.60f), 1.5f);
    }

    // 船尾楼（上层建筑）：尾端主舱块 + 更亮的小上舱。
    private void DrawSternCastle(float halfLen, float beam, float c)
    {
        var castleLen = _profile.CastleLen * c;
        var castleBeam = _profile.CastleBeam * c;
        var x0 = -halfLen;
        var x1 = x0 + castleLen;
        var ink = new Color(0.08f, 0.13f, 0.10f, 0.55f);
        // 主舱（比甲板略亮、赭石倾向）
        var cabinColor = ActivityTint(_hullColor.Lightened(0.10f));
        DrawRect(new Rect2(x0, -castleBeam, castleLen, castleBeam * 2f), new Color(cabinColor, 0.98f));
        DrawRect(new Rect2(x0, -castleBeam, castleLen, castleBeam * 2f), ink, false, 1.5f);
        // 上舱（更亮小舱）
        var innerLen = castleLen * 0.6f;
        var innerBeam = castleBeam * 0.55f;
        DrawRect(new Rect2(x0 + castleLen * 0.2f, -innerBeam, innerLen, innerBeam * 2f), new Color(cabinColor.Lightened(0.12f), 0.98f));
        DrawRect(new Rect2(x0 + castleLen * 0.2f, -innerBeam, innerLen, innerBeam * 2f), ink, false, 1.2f);
        // 舱门点
        DrawCircle(new Vector2(x1 - castleLen * 0.18f, 0f), Mathf.Max(1.6f, c * 0.05f), new Color(0.12f, 0.16f, 0.12f, 0.6f));
    }

    // 桅杆偏尾 + 小旗：竖线 + 尾向三角旗（水墨点缀）。
    private void DrawMast(float halfLen, float beam, float c)
    {
        var mastX = -halfLen + _profile.CastleLen * c * 0.75f;
        var mastH = _profile.MastH * c;
        var ink = new Color(0.08f, 0.13f, 0.10f, 0.65f);
        DrawLine(new Vector2(mastX, -beam * 0.7f), new Vector2(mastX, -beam * 0.7f - mastH), ink, 2f);
        // 尾向三角旗（朝船尾飘）
        var flagTop = -beam * 0.7f - mastH * 0.55f;
        var flagEndX = mastX - c * 0.28f;
        DrawColoredPolygon(new[]
        {
            new Vector2(mastX, flagTop),
            new Vector2(flagEndX, flagTop + c * 0.14f),
            new Vector2(mastX, flagTop + c * 0.30f),
        }, new Color(0.72f, 0.30f, 0.20f, 0.95f));
        // 主桅横杆（挂帆示意）
        var yard = -beam * 0.7f - mastH * 0.75f;
        DrawLine(new Vector2(mastX - c * 0.30f, yard), new Vector2(mastX + c * 0.30f, yard), new Color(ink, 0.7f), 1.5f);
    }

    // 状态徽章：按 ship.Burns/SpeedPenalties/Repairs 实时读取绘制；事件播放后由控制器 QueueRedraw 本视图。
    // 说明（报告注明）：徽章画在本舰局部坐标（随朝向旋转），Demo 阶段占位图标，非屏幕恒定朝上。
    private void DrawStatusBadges(int cell)
    {
        if (_ship is null) return;
        var badges = new List<(string Text, Color Color)>();
        if (_ship.Burns.Count > 0)
            badges.Add(("火", new Color(0.95f, 0.35f, 0.10f, 0.95f)));
        if (_ship.SpeedPenalties.Count > 0)
            badges.Add(("慢", new Color(0.35f, 0.70f, 0.95f, 0.95f)));
        if (_ship.Repairs.Count > 0)
            badges.Add(("+", new Color(0.35f, 0.85f, 0.45f, 0.95f)));
        if (badges.Count == 0) return;
        const float radius = 10f;
        var n = badges.Count;
        for (var i = 0; i < n; i++)
        {
            var cx = (i - (n - 1) / 2f) * radius * 2.1f;
            var cy = -cell * 0.72f;
            var center = new Vector2(cx, cy);
            DrawCircle(center, radius, badges[i].Color);
            DrawArc(center, radius, 0f, Mathf.Tau, 20, new Color(0.05f, 0.08f, 0.05f, 0.6f), 1.5f);
            var font = ThemeDB.FallbackFont;
            if (font is not null)
                DrawString(font, center + new Vector2(-radius * 0.42f, radius * 0.42f), badges[i].Text,
                    HorizontalAlignment.Left, -1, 12, Colors.White);
        }
    }

    // ---- 舰型剪影参数（旗舰/护卫舰/商船/运输船不同剪影与尺寸）----

    private readonly record struct HullProfile(float Beam, float ProwLen, float CastleLen, float CastleBeam, float MastH);

    private static HullProfile ProfileFor(string shipType) => shipType switch
    {
        // 旗舰：长 3、宽幅、大船尾楼（旗舰剪影）
        "flagship" => new HullProfile(Beam: 0.44f, ProwLen: 0.34f, CastleLen: 0.58f, CastleBeam: 0.34f, MastH: 0.85f),
        // 护卫舰：长 2、修长、中小船尾楼
        "frigate" => new HullProfile(Beam: 0.37f, ProwLen: 0.30f, CastleLen: 0.48f, CastleBeam: 0.30f, MastH: 0.70f),
        // 商船：长 1、肥圆宽舷、大圆船尾楼（货运船剪影）
        "merchant" => new HullProfile(Beam: 0.46f, ProwLen: 0.22f, CastleLen: 0.60f, CastleBeam: 0.42f, MastH: 0.60f),
        // 运输船：长 1、纤细、小舱
        "transport" => new HullProfile(Beam: 0.31f, ProwLen: 0.24f, CastleLen: 0.34f, CastleBeam: 0.26f, MastH: 0.55f),
        _ => new HullProfile(Beam: 0.37f, ProwLen: 0.28f, CastleLen: 0.45f, CastleBeam: 0.30f, MastH: 0.65f),
    };
}
