#nullable enable
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;

namespace NavalCombat.Levels;

// L-1 通关进度（纯 C#，无 Godot 依赖）：记录已通关关卡 id 集合 + 解锁规则 + JSON 保存/加载。
// 构造参数：
//   levelOrder  解锁线性序（传 LevelRegistry.AllLevelIds：1-1..3-2）；只有序列内关卡参与进度门禁。
//   savePath    JSON 保存的 OS 路径（应用侧用 ProjectSettings.GlobalizePath("user://progress.json") 解析后传入；
//               测试可传临时路径）。
// 保存格式：{ "Completed": ["1-1", ...] }，System.Text.Json，写入前自动建目录。
public sealed class LevelProgress
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
    };

    private readonly string _savePath;
    private readonly IReadOnlyList<string> _levelOrder;
    private readonly HashSet<string> _completed = new();

    public LevelProgress(IReadOnlyList<string> levelOrder, string savePath)
    {
        _levelOrder = levelOrder ?? throw new ArgumentNullException(nameof(levelOrder));
        _savePath = savePath ?? throw new ArgumentNullException(nameof(savePath));
    }

    public IReadOnlyCollection<string> Completed => _completed;

    public bool IsCompleted(string id) => _completed.Contains(id);

    // 解锁规则：
    //   1. 不在 levelOrder 内的 id（如自由模式 "free"）→ 恒解锁（只有关卡线性序列参与门禁）。
    //   2. 序列第 1 关（1-1）→ 恒解锁。
    //   3. 其余 → 前一关完成（跨章连续：2-1 前一关 = 1-3，3-1 前一关 = 2-3）。
    public bool IsUnlocked(string id)
    {
        var idx = IndexOf(_levelOrder, id);
        if (idx < 0) return true;   // 自由模式等非序列关卡恒解锁
        if (idx == 0) return true;  // 第1章第1关恒解锁
        return _completed.Contains(_levelOrder[idx - 1]);
    }

    // 标记通关：更新集合 + 立即持久化落盘（关卡胜利后调用即保存）。
    public void MarkCompleted(string id)
    {
        _completed.Add(id);
        Save();
    }

    public void Save()
    {
        var dto = new LevelProgressDto(_completed.OrderBy(x => x, StringComparer.Ordinal).ToList());
        var json = JsonSerializer.Serialize(dto, Options);
        var dir = Path.GetDirectoryName(_savePath);
        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
        File.WriteAllText(_savePath, json);
    }

    // 加载：文件缺失/损坏 → 视为空集合（进度为尽力而为，不抛错）。
    public void Load()
    {
        _completed.Clear();
        if (!File.Exists(_savePath)) return;
        try
        {
            var dto = JsonSerializer.Deserialize<LevelProgressDto>(File.ReadAllText(_savePath), Options);
            if (dto?.Completed is { } ids)
                foreach (var id in ids) _completed.Add(id);
        }
        catch (Exception)
        {
            _completed.Clear(); // 损坏 → 重置为空（不抛错）
        }
    }

    private static int IndexOf(IReadOnlyList<string> list, string id)
    {
        for (var i = 0; i < list.Count; i++)
            if (list[i] == id) return i;
        return -1;
    }

    private sealed record LevelProgressDto(List<string>? Completed);
}
