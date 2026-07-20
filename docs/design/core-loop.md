# Core loop

- Status: approved
- Last updated: 2026-07-18

## Loop

`阅读急报 -> 等待太监传召 -> 点击对话 -> 主动入殿 -> 点击觐见 -> 阅读君臣对白与圣旨 -> 领旨南下 -> 自动进入南疆水师`

## Player inputs and feedback

| Step | Player action | Game response | Reward/cost |
|---|---|---|---|
| 1 | 点击继续 | 依次显示岭南急报 | 了解危机 |
| 2 | 接近太监并点击“对话” | 太监与主帅自动入殿 | 推进召见 |
| 3 | 接近皇帝并点击“觐见” | 播放正式对白和圣旨 | 完成场景 |
| 4 | 阅读场景一完成旁白 | 2.5 秒后淡出；也可点击“立即启程”跳过等待 | 进入场景二 |

## Failure and recovery

首版没有失败状态；角色被场景边界限制在庭院中。

## First playable slice

从急报旁白开始，完成太监引路、入殿觐见和圣旨收尾。
