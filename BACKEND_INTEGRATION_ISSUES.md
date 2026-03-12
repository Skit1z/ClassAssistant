# ClassFox macOS 后端集成问题记录

## 📋 问题描述

当前状态：已成功将 Python 后端打包到 Tauri 应用中，但在 macOS 上运行时存在路径解析问题。

## 🎯 已完成的工作

1. **后端打包**
   - ✅ 使用 PyInstaller 成功打包 Python 后端到 `api-service/dist/class-assistant-backend/`
   - ✅ 生成的包含：可执行文件 `class-assistant-backend` 和 `_internal/` 依赖目录
   - ✅ 使用 `console=sys.platform == 'darwin'` 配置（macOS：单文件模式）

2. **前端配置**
   - ✅ Tauri 配置文件 (`tauri.conf.json`) 已更新以包含后端
   - ✅ Rust 代码已添加 macOS 特定的后端启动逻辑
   - ✅ 创建了 `build-with-backend.sh` 自动化构建脚本
   - ✅ 后端文件已成功复制到 `Contents/Resources/backend/` 目录

3. **构建脚本**
   - ✅ 创建了 `/app-ui/build-with-backend.sh` 脚本
   - 脚本功能：
     - 自动构建 Python 后端
     - 构建 Tauri 前端
     - 将后端文件复制到 app bundle 的 Resources 目录
     - 设置可执行权限

## ⚠️ 当前问题

### 1. PyInstaller 模式问题

**问题描述：**
PyInstaller 在 macOS 上使用 `console=False` 创建了一个复杂的 .app 结构（类似 Windows 的打包方式），这导致：
- 后端可执行文件被嵌入在 macOS 应用包内部
- 依赖库路径解析失败（尝试从 `Frameworks/` 查找 `_internal/` 目录）
- 从其他 app 的 MacOS 目录运行时，无法正确找到依赖文件

**错误表现：**
- 运行打包后的 app 时，后端进程崩溃（exit code 144）
- 启动日志：`No such file or directory` - 后端找不到 `_internal/` 目录

**根本原因：**
PyInstaller 的 `console=False` 参数在 macOS 上不应该使用，因为它：
1. 创建了一个完整的 macOS 应用结构
2. 将 Python 解释器、依赖库等打包在应用内部
3. 从其他 app 运行时，当前 app 的 `Frameworks/` 目录可能干扰路径解析

**验证：**
```bash
# PyInstaller 打包的目录结构
ls -la dist/class-assistant-backend/
# 输出包含：
# - class-assistant-backend (主可执行文件)
# - _internal/ (依赖目录)
```

## 🛠️ 下一步建议

### 方案 1：使用一文件模式（推荐）⭐

修改 `api-service/backend.spec`：

```python
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,  # 不创建可执行文件
    name='class-assistant-backend',    # 直接使用可执行文件名
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,  # macOS 上保持 False 以隐藏控制台
    icon=None,
)
```

不使用 COLLECT，创建单个可执行文件：

```python
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='class-assistant-backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    icon=None,
)
```

**优点：**
- ✅ 简单的目录结构，直接可执行文件
- ✅ 适合作为后台服务打包
- ✅ PyInstaller 自动处理依赖库路径
- ✅ Tauri 可以轻松找到和运行可执行文件

**缺点：**
- ❌ 需要重构 Rust 端的路径查找逻辑（从 MacOS/backend 改为 Resources/backend）

---

### 方案 2：使用独立进程模式

保持当前 PyInstaller 配置，但修改 Rust 启动逻辑：

```rust
// 修改启动逻辑
fn start_embedded_backend() -> Result<BackendBootstrapResult, String> {
    cleanup_backend_processes(false);

    // 使用单独的 backend 目录，不依赖 app bundle 内部结构
    let backend_dir = std::path::PathBuf::from(format!(
        "{}/backend",
        std::env::var("HOME").unwrap_or_else(|| ".".to_string())
    ));

    // 直接启动 backend 可执行文件
    let backend_exe = backend_dir.join("class-assistant-backend");
    if !backend_exe.exists() {
        return Err("未找到后端可执行文件".to_string());
    }

    let child = Command::new(&backend_exe)
        .current_dir(&backend_dir.parent().unwrap())
        .spawn()
        .map_err(|err| format!("启动后端失败: {err}"))?;

    // 后端作为独立后台服务运行，前端通过 HTTP API 与之通信
    // 启动后等待 5 秒确保就绪
    std::thread::sleep(Duration::from_secs(5));

    Ok(build_bootstrap_result(
        "ready",
        "后端服务已启动，正在等待就绪...",
    ))
}
```

**优点：**
- ✅ 不需要修改 PyInstaller 配置
- ✅ 后端独立运行，进程隔离清晰
- ✅ 可以在终端直接测试后端

**缺点：**
- ❌ 用户需要手动启动后端
- ❌ 两个进程同时运行

---

### 方案 3：使用 macOS 服务/Agent 模式（最专业）

参考 Electron 应用的架构，将后端打包为 macOS Agent：

```rust
use std::process::Command;

fn launch_backend_agent() {
    let agent_path = app_resources_dir().join("backend/agent");
    Command::new(&agent_path)
        .spawn()
        .expect("Failed to launch backend agent");
}

fn stop_backend_agent() {
    Command::new("pkill", &["-TERM", "backend-agent"])
        .status()
        .expect("Failed to stop backend agent");
}
```

**优点：**
- ✅ 专业的 macOS 架构
- ✅ 后端完全独立，不受 app 进程影响
- ✅ 可以使用 macOS 服务框架

---

## 📁 技术细节

### 当前实现

1. **Rust 路径查找逻辑** (`lib.rs:137-171`)
   - 尝试查找 `MacOS/backend/class-assistant-backend`（失败，因为 PyInstaller 放在 `Contents/`）
   - 备选尝试查找 `Resources/backend/class-assistant-backend`（当前实现）
   - 使用 `backend_dir = app_root.join("backend")` 解析路径

2. **Tauri 配置**
   - 使用 `externalBin` 指定后端文件
   - 但 Tauri v2 的 `externalBin` 在 macOS 上可能存在兼容性问题

3. **PyInstaller 配置**
   ```python
   console=sys.platform == 'darwin'
   exclude_binaries=True
   ```
   这是 macOS 上单文件模式的标准配置

### 🔍 调试信息

如果需要调试，可以检查以下内容：

```bash
# 1. 检查 app bundle 结构
ls -la /app-ui/src-tauri/target/release/bundle/macos/课狐ClassFox.app/Contents/

# 2. 查找后端可执行文件
find /app-ui/src-tauri/target/release/bundle/macos/课狐ClassFox.app -name "class-assistant-backend" -type f

# 3. 检查 Rust 编译输出
# 重新运行构建会显示 Rust 路径调试日志
```

## 📝 待解决问题

1. **【高优先级】实现方案 1（一文件模式）**
   - [ ] 修改 `api-service/backend.spec` 使用一文件模式
   - [ ] 更新 Rust 路径查找逻辑简化为 Resources/backend
   - [ ] 测试打包后的 app 是否能正常运行

2. **【中优先级】更新构建脚本**
   - [ ] 将后端构建步骤集成到 `build-with-backend.sh` 中
   - [ ] 添加构建后的验证步骤
   - [ ] 添加更多调试输出以便排查问题

3. **【可选】考虑方案 2 或 3**
   - [ ] 独立进程模式：让后端完全独立运行
   - [ ] 服务/Agent 模式：参考 Electron 应用架构

## 🤝 现有资源

- ✅ 完整的后端代码（`api-service/`）
- ✅ 完整的 Rust 代码（`app-ui/src-tauri/src/lib.rs`）
- ✅ 自动化构建脚本（`app-ui/build-with-backend.sh`）
- ✅ PyInstaller 配置文件（`api-service/backend.spec`）
- ✅ Tauri 配置文件（`app-ui/src-tauri/tauri.conf.json`）

## 📞 参考文档

- Tauri v2 文档：<https://tauri.app/>
- PyInstaller 文档：<https://pyinstaller.org/>
- macOS 打包最佳实践：<https://developer.apple.com/documentation/bundler/>

---

**文档创建时间：** 2026-03-12
**问题状态：** 🔴 打包结构问题导致后端无法正确启动
