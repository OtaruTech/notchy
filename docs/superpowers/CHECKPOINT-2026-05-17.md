# Notchy Debug Session Checkpoint

**Date:** 2026-05-17 ~10:30 (paused for ghostty restart to grant Screen Recording perm)

## Current state

- ✅ App installed at `/Applications/Notchy.app` (Release build, ad-hoc signed)
- ✅ Process running (PID was 1822 — may change after restart)
- ❌ User-reported bug: 只看到 gauge pill 两个百分比图标，没有刘海交互
- ✅ Settings 已修复 (commit `e1d56e5`) — NSHostingController + NSWindow，绕开 SwiftUI Settings scene 在 LSUIElement app 下的不可靠行为

## Diagnostic findings (from Console.app logs PID 1822)

### Root cause #1 — MediaRemote 私有 API 被 macOS 15.4+ TCC 阻挡
```
Notchy: (MediaRemote) Response: ... returned with error
  Domain=kMRMediaRemoteFrameworkErrorDomain Code=3 "Operation not permitted"
```
- 后果：`MRMediaRemoteGetNowPlayingInfo` 永远返回 nil → `MediaFeature.current` 永远为 nil → state machine 中 `mediaAvailable` 永远 false → hover 不展开
- **真原因**：macOS 15.4 (Sequoia) 起 Apple 在 `mediaremoted` 加了 entitlement 校验，要求 `kTCCServiceMediaRemote`。第三方拿不到（连付费 Developer ID 也不行）

### Root cause #2 — 设计缺陷
- 我们的 v1 设计是 "hover 仅当 media 可用才展开"
- 但 NotchNook 实际行为是 **hover 永远展开**（无 media 时显示 calendar / shortcuts / 空 media slot 等）
- 我们应该改成无条件 hover-expand，让用户至少看到 panel 出现

### Root cause #3 — EventKit 拒绝
- 用户首次启动时点了"不允许"
- 需要 reset：`tccutil reset Calendars tech.otaru.Notchy`，下次启动会再问

### Root cause #4 — Accessibility 状态不明
- log 显示 `NSAccessibility Request Received` 但未确认 grant
- 没有这个权限的话 global hover 监听完全不工作（local 监听也基本不行因为 LSUIElement app 不会"active"）

## 参考：NotchNook 实际行为
- **Idle**：什么都不显示，刘海保持原样
- **Hover**：始终展开 panel（不需要有 media）。默认 widget = Media slot (empty) + Calendar + Shortcuts + Mirror + File Tray
- **媒体播放时**：刘海两侧显示专辑封面 + 波形 (live activity 风格)
- **拖文件靠近刘海**：直接展开 File Tray + AirDrop drop zone

## 关键 workaround：`ungive/mediaremote-adapter`
- BSD 3-Clause 开源（GitHub: ungive/mediaremote-adapter）
- 原理：利用 `/usr/bin/perl` 的 bundle id `com.apple.perl5` 是 Apple-signed → 拿到 entitlement → spawn perl 子进程 → 在它里面动态加载 MediaRemoteAdapter.framework → JSON 流回主进程
- **不需要付费 Developer ID**，不需要关 SIP
- `brew install media-control` 可直接装一个 CLI 验证用
- BetterTouchTool 社区认为 Apple 可能哪天会补这个口子，但目前是唯一可行方案

## 接下来要做的（按优先级）

### Phase H1：修通基本交互（必须先做完才能继续 visual debug）
- [ ] 改 `NotchStateMachine.reduce`：让 hover 无条件展开（不再要求 `mediaAvailable`）
- [ ] 设计一个 idle hover 时展开的 default content（calendar 优先 + 当前时间 + 空 media slot）
- [ ] 调整 NotchExpandedView 让无 media 时展开仍有内容
- [ ] 重置 Calendar TCC：`tccutil reset Calendars tech.otaru.Notchy`
- [ ] 确认 Accessibility 已 grant：System Settings → Privacy & Security → Accessibility → Notchy 打勾

### Phase H2：媒体回归（用 mediaremote-adapter）
- [ ] 把 mediaremote-adapter 集成进项目（fork 或 git submodule）
- [ ] 改 `MediaRemoteBridge`：spawn perl 进程，从 stdout 读 JSON，parse 成 `NowPlayingInfo`
- [ ] 保留 dlopen 路径作为 fallback（万一 perl 通道哪天也挂）
- [ ] 加单元测试 cover JSON parser

### Phase H3：visual verify 循环（需要截屏权限）
- [ ] 用 `screencapture` 截图（需 Screen Recording 权限）
- [ ] 用 `cliclick` 模拟鼠标 hover 到刘海位置
- [ ] 验证 panel 展开 → 截图比对
- [ ] 拖文件 → 验证 drop tray
- [ ] 这一阶段需要 ghostty 重启后获得权限

### Phase H4：清理 + 验收
- [ ] 全量 test pass
- [ ] Archive + 装 /Applications
- [ ] 走 manual checklist

## 仓库状态

- main branch, 42 commits 本地，未 push 到 origin
- tag `v0.2.0` 本地存在，未 push
- 最新 commit: `e1d56e5 fix(settings): host SettingsView in NSWindow`

## 调试中产生的临时文件

- `/tmp/notchy-debug/` (空，screencapture 失败那次)
- `/Users/zhangjie/workspace/notchy/build/` (Release build 缓存)

---

**Resume instructions for new ghostty:**
1. `cd /Users/zhangjie/workspace/everything-claude-code`
2. `claude --continue` (恢复最近会话)
3. 告诉 Claude: "从 CHECKPOINT-2026-05-17.md 继续，先做 Phase H1"
