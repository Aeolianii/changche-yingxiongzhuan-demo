#nullable enable
using Godot;
using NavalCombat.Core;
using System;

namespace NanjiangNaval;

// F-6：天气视觉覆盖层——全屏 Control（挂在 Battle/WeatherFx(CanvasLayer)/Fx 上），
// 按天气 _Draw 叠加水墨基调的天气氛围（设计 6）：
//   晴   = 极淡暖亮（略提亮画面）；
//   阴   = 全屏淡灰蓝叠加（压暗、偏阴）；
//   雨   = 灰蓝叠加 + 程序雨丝（确定性伪随机布局、朝一个方向斜落、时间循环下落，风向决定倾斜方向）；
//   台风 = 更暗墨色叠加 + 四边暗角 + 更密更长更斜的雨丝 + 少量风纹横线 + 整层 ±3px 正弦晃动（CanvasLayer.Offset）。
// 天气/风向来自规则层（BattleController.StartBattle 时 SetWeather，与状态栏同源，UI 不重复实现规则）。
// headless 无害：_Draw 只排队不渲染，_Process 照常推进（时间/晃动）。
public partial class NavalWeatherOverlay : Control
{
    // 各天气屏色叠加（水墨基调：阴=灰蓝、台风=墨暗；雨线=浅青白、风纹=更淡青白）。
    private static readonly Color ClearTint = new(1.00f, 0.97f, 0.88f, 0.05f);
    private static readonly Color CloudyTint = new(0.40f, 0.48f, 0.55f, 0.30f);
    private static readonly Color TyphoonTint = new(0.10f, 0.12f, 0.14f, 0.42f);
    private static readonly Color RainColor = new(0.78f, 0.86f, 0.95f, 0.45f);
    private static readonly Color WindColor = new(0.80f, 0.88f, 0.96f, 0.18f);

    private Weather _weather = Weather.Clear;
    private CardinalDirection? _wind;
    private float _rainTime;                       // 雨丝动画时钟（秒），_Process 推进
    // 雨丝确定性伪随机布局（固定种子，各天气/各帧稳定）：X=起始横坐标、Y=相位、Z=长度、W=下落速度。
    private readonly Vector4[] _drops = new Vector4[140];
    private const int RainCount = 70;              // 雨天雨丝条数
    private const int TyphoonCount = 140;          // 台风更密

    public override void _Ready()
    {
        var rand = new Random(12345);
        for (var i = 0; i < _drops.Length; i++)
            _drops[i] = new Vector4(
                (float)rand.NextDouble() * 1500f,             // 起始横坐标（可略超出屏宽，循环后补）
                (float)rand.NextDouble() * 220f,              // 相位（错开下落，避免整屏同时落）
                (float)rand.NextDouble() * 30f + 24f,         // 长度 24-54（台风再乘 1.5）
                (float)rand.NextDouble() * 200f + 140f);      // 下落速度 140-340 px/s
    }

    // 规则层天气/风向 → 覆盖层（StartBattle 时调用；风向西/东决定雨丝倾斜方向）。
    public void SetWeather(Weather weather, CardinalDirection? wind)
    {
        _weather = weather;
        _wind = wind;
        _rainTime = 0f;
        QueueRedraw();
    }

    public int Kind() => (int)_weather;
    public bool Active() => _weather != Weather.Clear;

    public override void _Process(double delta)
    {
        // 雨/台风才需要动画推进（阴/晴静止，只画一次）。台风晃动持续归零/正弦。
        if (_weather is Weather.Rainy or Weather.Typhoon)
        {
            _rainTime += (float)delta;
            QueueRedraw();
        }
        if (GetParent() is CanvasLayer layer)
        {
            layer.Offset = _weather == Weather.Typhoon
                ? new Vector2(Mathf.Sin(_rainTime * 5.0f) * 3f, Mathf.Cos(_rainTime * 4.3f) * 3f) // ±3px 轻微晃动
                : Vector2.Zero;
        }
    }

    public override void _Draw()
    {
        var size = Size;
        if (size.X <= 1f || size.Y <= 1f) return; // 未布局/headless 零尺寸时跳过
        switch (_weather)
        {
            case Weather.Clear:
                DrawRect(new Rect2(Vector2.Zero, size), ClearTint);
                break;
            case Weather.Cloudy:
                DrawRect(new Rect2(Vector2.Zero, size), CloudyTint);
                break;
            case Weather.Rainy:
                DrawRect(new Rect2(Vector2.Zero, size), CloudyTint);
                DrawRain(size, RainCount, WindSlant(0.45f, 0.35f), 1.0f);
                break;
            case Weather.Typhoon:
                DrawRect(new Rect2(Vector2.Zero, size), TyphoonTint);
                DrawVignette(size);
                DrawRain(size, TyphoonCount, WindSlant(0.70f, 0.45f), 1.5f);
                DrawWindStreaks(size);
                break;
        }
    }

    // 风向决定雨丝统一倾斜方向（东风→右倾 +、西风→左倾 -；南北风无横向风，轻微斜落保持动感）。
    private float WindSlant(float eastWestSlant, float noLateralSlant) => _wind switch
    {
        CardinalDirection.East => eastWestSlant,
        CardinalDirection.West => -eastWestSlant,
        _ => noLateralSlant,
    };

    // 程序雨丝：每条从屏顶上方按速度下落、出屏底循环；沿坡度斜落（雨丝方向与下落一致）。
    private void DrawRain(Vector2 size, int count, float slant, float lengthScale)
    {
        var span = size.Y + 60f; // 屏高 + 余量：雨丝从屏顶上方落进屏底下方再循环
        for (var i = 0; i < count; i++)
        {
            var d = _drops[i];
            var len = d.Z * lengthScale;
            var y = span - ((_rainTime * d.W + d.Y) % span); // y ∈ (0, span)：下落位置（循环）
            var x = d.X + slant * y;                          // 随 y 增大水平漂移 → 斜线朝风向一致
            DrawLine(new Vector2(x - slant * len, y - len), new Vector2(x, y), RainColor, 1.6f);
        }
    }

    // 台风四边暗角：墨色窄边叠加，强化"笼罩/压抑"（中心正常，边缘渐暗）。
    private void DrawVignette(Vector2 size)
    {
        var bar = new Color(0.02f, 0.03f, 0.04f, 0.28f);
        const float edge = 70f;
        DrawRect(new Rect2(0, 0, size.X, edge), bar);                    // 上边
        DrawRect(new Rect2(0, size.Y - edge, size.X, edge), bar);        // 下边
        DrawRect(new Rect2(0, 0, edge, size.Y), bar);                    // 左边
        DrawRect(new Rect2(size.X - edge, 0, edge, size.Y), bar);        // 右边
    }

    // 台风风纹：少量横贯全屏的淡青白长横线（西风向左，其余向右），表达"风在刮"。
    private void DrawWindStreaks(Vector2 size)
    {
        var rand = new Random(777);
        for (var i = 0; i < 8; i++)
        {
            var y = (float)rand.NextDouble() * size.Y;
            var x0 = (float)rand.NextDouble() * size.X;
            var len = (float)rand.NextDouble() * 220f + 80f;
            var dir = _wind == CardinalDirection.West ? -1f : 1f;
            DrawLine(new Vector2(x0, y), new Vector2(x0 + dir * len, y + (float)rand.NextDouble() * 8f - 4f), WindColor, 2f);
        }
    }
}
