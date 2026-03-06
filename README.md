# 🐟 上课摸鱼搭子 (ClassAssistant)

> 大学课堂辅助工具 —— 实时语音监控，点名预警，一键救场

一个 Windows 桌面悬浮窗应用，在上课时默默运行在屏幕角落。通过实时语音识别监听课堂内容，当检测到「点名」「随机提问」等关键词时，立刻弹出红色警报并提供 AI 救场答案。课后还能自动生成结构化笔记。

> “Agent老师没做出来，Agent学生倒先做出来了！” — 来自内测群的反馈

## ✨ 核心功能

| 功能 | 说明 |
|------|------|
| 🎙️ 实时语音监控 | 麦克风录音 → ASR 语音识别 → 实时转文字 |
| 🚨 点名预警 | 检测到点名关键词时，窗口闪红光 + 置顶提醒 |
| 🔧 自定义关键词 | 编辑 `data/keywords.txt` 即可自定义监控词，实时生效 |
| 🆘 一键救场 | 调用 LLM 分析课堂上下文，快速给出老师问题的参考答案 |
| 📍 老师讲到哪了 | 一键 AI 总结当前课堂进度，快速回到上下文 |
| 📝 课后总结 | 一键生成 Markdown 格式的课堂笔记 |
| 📄 资料上传 | 支持上传 PPT / PDF / Word 课件，辅助 AI 理解课堂内容 |

## 🏗️ 技术架构

```
┌─────────────────────┐       HTTP / WebSocket       ┌──────────────────────┐
│   Tauri 2.0 桌面端   │ ◄─────────────────────────► │   FastAPI 后端服务     │
│   React 19 + TS     │                              │   Python 3.11        │
│   TailwindCSS 4     │                              │                      │
│   无边框悬浮窗       │                              │   ASR: Local/Seed-ASR│
│                     │                              │   LLM: OpenAI API    │
└─────────────────────┘                              │   Audio: PyAudio     │
                                                     └──────────────────────┘
```

## 📦 环境要求

- **操作系统**: Windows 10/11
- **Python**: 3.11+
- **Node.js**: 18+
- **Rust**: 最新稳定版 (Tauri 2.0 需要)
- **Visual Studio Build Tools**: 2022 (C++ 桌面开发工作负载)

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/ouyangyipeng/ClassAssistant.git
cd ClassAssistant
```

### 2. 配置 Python 环境

```bash
cd api-service
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
```

### 3. 配置环境变量

复制 `api-service/.env.example`（或手动创建 `api-service/.env`）：

```env
# ASR 模式: local | mock | dashscope | seed-asr
ASR_MODE=local

# Seed-ASR (字节跳动) — ASR_MODE=seed-asr 时需要
SEED_ASR_APP_KEY=your_app_key
SEED_ASR_ACCESS_KEY=your_access_key
SEED_ASR_RESOURCE_ID=volc.bigasr.sauc.duration

# LLM (OpenAI 兼容接口)
LLM_BASE_URL=https://api.openai.com/v1
LLM_API_KEY=your_api_key
LLM_MODEL=gpt-4o-mini

# 音频参数 (一般无需修改)
AUDIO_SAMPLE_RATE=16000
AUDIO_CHANNELS=1
AUDIO_CHUNK_SIZE=3200
```

### 4. 安装前端依赖

```bash
cd app-ui
npm install
```

### 5. 启动开发模式

**方式一：一键启动（推荐）**

双击项目根目录的 `dev.bat`，自动启动后端+前端。

**方式二：分别启动**

终端 1 - 启动后端：
```bash
cd api-service
.venv\Scripts\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8765 --reload
```

终端 2 - 启动前端：
```bash
cd app-ui
npm run tauri dev
```

## 🔍 验证与调试

### 验证麦克风

后端启动后，访问：
```
GET http://127.0.0.1:8765/api/check_mic
```

返回示例：
```json
{
  "status": "ok",
  "device": "Microphone (Realtek Audio)",
  "sample_rate": 44100,
  "channels": 2,
- 修复打包版数据误写到开发目录：发布包启动前自动清理 8765 端口占用进程，避免前端连到开发后端
}
```

- `build.ps1` 一键打包脚本：自动同步版本号 → PyInstaller → Tauri → 组装 release → 健康检查验证 → zip
- `启动.bat` 智能启动：自动创建 `.env`、清理残留进程、后台运行后端，并使用解压目录下的相对 `data` 目录
后端启动后访问 Swagger UI：
```
http://127.0.0.1:8765/docs
```

### 健康检查

```
GET http://127.0.0.1:8765/api/health
```

## 📁 项目结构

```
ClassAssistant/
├── api-service/                # Python FastAPI 后端
│   ├── main.py                 # 应用入口
│   ├── routers/                # API 路由
│   │   ├── ppt_router.py      # 资料上传 (PPT/PDF/Word)
│   │   ├── monitor_router.py  # 监控启停 + 麦克风检测
│   │   ├── rescue_router.py   # 紧急救场
│   │   └── summary_router.py  # 课后总结
│   ├── services/               # 业务逻辑
│   │   ├── asr_service.py     # ASR 语音识别 (Local/Mock/DashScope/Seed-ASR)
│   │   ├── llm_service.py     # LLM 大模型调用
│   │   ├── monitor_service.py # 核心监控服务
│   │   ├── ppt_service.py     # 课件解析 (PPT/PDF/Word)
│   │   ├── keyword_service.py # 关键词检测服务
│   │   └── transcript_service.py # 转录管理
│   ├── config.py               # 全局配置 (路径兼容开发/打包模式)
│   ├── requirements.txt
│   └── .env                    # 环境变量 (不提交到 Git)
├── app-ui/                     # Tauri + React 前端
│   ├── src/
│   │   ├── App.tsx             # 主组件
│   │   ├── components/         # UI 组件
│   │   │   ├── ToolBar.tsx    # 工具按钮
│   │   │   ├── AlertOverlay.tsx # 点名红色警报
│   │   │   ├── RescuePanel.tsx  # LLM 救场面板
│   │   │   ├── CatchupPanel.tsx # 老师讲到哪了面板
│   │   │   ├── Toast.tsx        # Toast 通知
│   │   │   └── TitleBar.tsx     # 自定义拖拽标题栏
│   │   ├── hooks/              # WebSocket 管理
│   │   └── services/           # API 客户端
│   └── src-tauri/              # Rust Tauri 配置
├── data/                       # 运行时数据 (不提交到 Git)
│   └── keywords.txt            # 监控关键词配置（可编辑）
├── docs/                       # 开发文档
├── build.ps1                   # 一键打包脚本 (PowerShell)
├── build.bat                   # 打包入口 (build.bat v1.0.0)
├── dev.bat                     # 一键启动开发模式
└── README.md
```

## 🎯 使用流程

1. 启动应用后，屏幕角落出现半透明悬浮窗
2. （可选）编辑 `data/keywords.txt` 自定义监控关键词
3. 点击 **📄 上传资料** 上传课件 (PPT/PDF/Word)
4. 点击 **🎣 开始摸鱼** 开启语音监控
5. 老师点名时 → 🚨 红色警报弹出
6. 点击 **🆘 救场** → AI 分析课堂内容并给出参考答案
7. 点击 **📍 老师讲到哪了** → AI 总结课堂进度，快速跟上
8. 下课后点击 **📝** → 自动生成课堂笔记

## 📋 支持的 ASR 服务

| 模式 | 提供商 | 说明 |
|------|--------|------|
| `local` | Google Speech API | 免费语音识别，无需密钥，需联网（默认） |
| `mock` | - | 空实现，用于 UI 开发测试 |
| `dashscope` | 阿里云百炼 | Fun-ASR 实时语音识别 |
| `seed-asr` | 字节跳动 | Seed-ASR 大模型，精度更高 |

## 📋 支持的文件格式

| 格式 | 扩展名 | 解析库 |
|------|--------|--------|
| PowerPoint | `.pptx` | python-pptx |
| PDF | `.pdf` | pypdf |
| Word | `.docx` | python-docx |

## 📥 下载安装（免开发环境）

如果你不想配置开发环境，可以直接使用打包好的 exe 版本。

### 1. 下载发布包

从 [GitHub Releases](https://github.com/ouyangyipeng/ClassAssistant/releases) 下载最新的 `ClassAssistant-vX.X.X-win-x64.zip`。

### 2. 解压

将 zip 解压到任意目录，得到以下结构：

```
ClassAssistant-vX.X.X/
├── 启动.bat                     # 双击启动
├── 上课摸鱼搭子.exe              # 前端桌面窗口
├── backend/                     # 后端服务
│   ├── class-assistant-backend.exe
│   ├── .env.example             # 配置模板
│   └── _internal/               # 运行时依赖（勿删）
└── data/                        # 运行时数据
    ├── keywords.txt             # 监控关键词配置（可编辑）
    └── summaries/
```

### 3. 配置 API 密钥

首次运行会自动从 `.env.example` 创建 `backend/.env` 并用记事本打开，填入你的密钥：

```env
# 必填：ASR 语音识别（任选一种）
ASR_MODE=local

# 必填：LLM 大模型（救场 + 总结功能需要）
LLM_BASE_URL=https://api.deepseek.com
LLM_API_KEY=你的Key
LLM_MODEL=deepseek-chat
```

> 若只想测试 UI 不需要真实识别，将 `ASR_MODE` 设为 `mock` 即可，无需其他密钥。

### 4. 启动

双击 **`启动.bat`**，它会：
1. 自动启动后端服务（无窗口，后台运行）
2. 等待 3 秒后启动前端桌面悬浮窗
3. 启动脚本自身自动退出，不留多余窗口

### 5. 使用

- 📄 **上传资料** → 选择课件文件（PPT/PDF/Word）
- 🎣 **开始摸鱼** → 开启麦克风监听
- 🚨 检测到点名 → 红色警报弹出
- 🆘 **救场** → AI 给出参考答案
- 📝 下课后点击 → 生成课堂笔记

### 常见问题

| 问题 | 解决方案 |
|------|----------|
| 后端异常退出 | 在 `backend/` 目录手动运行 `class-assistant-backend.exe` 查看错误信息 |
| 无法录音 | Windows 设置 → 隐私 → 麦克风 → 允许应用访问 |
| 前端窗口不出现 | 检查后端是否已启动（浏览器访问 http://127.0.0.1:8765/docs） |
| 杀毒软件拦截 | exe 是 PyInstaller/Tauri 打包产物，添加信任即可 |
| libfribidi-0.DLL 错误 | 系统安装了 tesseract 且 DLL 损坏；启动脚本已自动处理，手动运行时可临时移除 tesseract 的 PATH |

## ⚠️ 注意事项

- `.env` 文件包含 API 密钥，**请勿提交到 Git**
- 仅供学习用途，请合理使用课堂工具
- 需要网络连接才能使用 ASR 和 LLM 服务
- 麦克风权限需要在系统设置中开启

## � 更新日志

### v1.0.0 (2026-03-06)

**新增功能**
- 🎙️ **本地免费 ASR**：新增 `local` 模式，使用 Google Speech API，无需密钥即可使用语音识别（默认模式）
- 📍 **"老师讲到哪了"**：摸鱼模式下新增进度查询按钮，AI 总结当前课堂进度
- 🔑 **关键词检测优化**：仅检查转录文件最近两行，避免历史文本反复触发警报
- 📝 **本地 ASR 逐句记录**：每识别一句话追加新行，不再覆盖式更新
- 🏗️ **全局路径配置**：新增 `config.py`，统一管理 `DATA_DIR`，兼容开发模式和 PyInstaller 打包模式

**Bug 修复**
- 修复 SeedASR 在线识别无文字输出：拆分收发为独立线程，解决 send/recv 阻塞问题
- 修复打包版 `.env` 加载到开发目录：`load_dotenv()` 改为显式指定路径
- 修复打包版启动脚本端口冲突：启动前自动清理残留后端进程
- 修复 `dev.bat` 关闭后后端窗口不消失：改用 `cmd /c` + 退出时自动 `taskkill`

**打包优化**
- `build.ps1` 一键打包脚本：自动同步版本号 → PyInstaller → Tauri → 组装 release → 验证 → zip
- `启动.bat` 智能启动：自动创建 `.env`、清理残留进程、后台运行后端

## �📄 License

MIT
