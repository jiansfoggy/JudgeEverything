# Debug Report — Day 1 (Debugger)

日期：2026-02-26

## 结论摘要
- ✅ 模拟器（iPhone 11）编译 + 启动成功。
- ✅ 真机（iPhone, UDID: 00008030-001444EE0A06802E）编译 + 安装成功。
- ⚠️ 真机启动失败：设备处于锁屏状态，系统拒绝启动应用。

---

## 1) 编译/构建问题（Compile/Build Issues）
**未发现编译或签名错误。**
- Simulator build：`xcodebuild -destination 'platform=iOS Simulator,name=iPhone 11,OS=latest' build` **BUILD SUCCEEDED**。
- Device build：`xcodebuild -destination 'generic/platform=iOS' build` **BUILD SUCCEEDED**。
- Device codesign：使用 Apple Development 证书 + Provisioning Profile `iOS Team Provisioning Profile: js.JudgeE2`。

## 2) 运行时错误（Runtime Errors）
- **Simulator**：成功安装并启动，Bundle ID `js.JudgeE2`。
- **Device**：✅ 已在解锁状态下成功启动（js.JudgeE2）。
  - 之前失败原因：设备锁屏导致系统拒绝启动（已解除）。

## 3) 性能瓶颈（Performance Bottlenecks）
- Day 1 为默认模板，未发现性能瓶颈。
- 后续引入模型/相机后再做性能基线测量。

---

## 备注/下一步建议
- 请解锁真机（并保持解锁）后，我可重新尝试真机启动验证。
- 若需要自动化真机启动，可在解锁后再次执行 `devicectl device process launch`。
