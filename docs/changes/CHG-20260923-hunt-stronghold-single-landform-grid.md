# CHG-20260923：终战只保留中央营地并恢复周围格线

- Status: done
- Type: content
- Date: 2026-09-23

## 目标与范围

- 清除倭寇营地终战的外围单格礁石、浅滩、珊瑚及左侧岸带，只保留中央连续营地岛地形。
- 中央印章的透明海面区域仍按其他海战地图绘制清晰的战术格面和格线。

## 非目标

- 不改变中央岛九乘九范围内的逻辑地形、城寨和炮台、敌我布阵区或其他海战地图。

## 验收与文档影响

- 终战地图仅引用中央 `9×9` 营地印章，岛外逻辑格为深水或既有出口，不出现独立单格地形贴图。
- 印章透明区域显示与周围一致的海水格子；岛体本身保持连续、没有瓷砖图标。
- 更新 `docs/design/art-direction.md` 的终战美术规则。
- 预计修改：`MapScheme.cs`、`NavalGridView.cs`、终战集成检查、移除弃用的左岸 PNG 及导入文件、本记录和美术规范。

## 验证证据

- `dotnet build ChangcheHeroes.csproj --no-restore -v:q`：成功，0 警告、0 错误。
- Godot 4.7.1 .NET 运行 `tests/test_naval_hunt_request.gd`：headless 和 OpenGL 窗口模式均通过；校验仅一张 `9×9` 印章，印章外非深水格为 0。
- 检查 `.godot/hunt_stage3_central_camp_preview.png`：中央岛完整连续，四周和印章透明区域显示清晰海水战术格，未见外围单格地形贴图。
