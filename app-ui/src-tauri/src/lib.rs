use std::{
    fs::OpenOptions,
    io::Write,
    net::{SocketAddr, TcpStream},
    process::{Child, Command, Stdio},
    sync::{LazyLock, Mutex},
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
    fs, path::{Path, PathBuf},
};

use serde::Serialize;
use tauri::{Manager, WebviewUrl, WebviewWindowBuilder};

#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

#[cfg(target_os = "windows")]
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

static BACKEND_CHILD: LazyLock<Mutex<Option<Child>>> = LazyLock::new(|| Mutex::new(None));

#[derive(Serialize)]
struct BackendBootstrapResult {
    status: String,
    message: String,
}

#[derive(Serialize)]
struct ExportMonitorArtifactsResult {
    exported: bool,
    directory: Option<String>,
    saved_files: Vec<String>,
}

// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

fn build_bootstrap_result(status: &str, message: impl Into<String>) -> BackendBootstrapResult {
    BackendBootstrapResult {
        status: status.to_string(),
        message: message.into(),
    }
}

fn build_export_result(
    exported: bool,
    directory: Option<String>,
    saved_files: Vec<String>,
) -> ExportMonitorArtifactsResult {
    ExportMonitorArtifactsResult {
        exported,
        directory,
        saved_files,
    }
}

fn sanitize_filename_component(name: &str) -> String {
    let mut sanitized = String::with_capacity(name.len());
    for ch in name.chars() {
        if matches!(ch, '\\' | '/' | ':' | '*' | '?' | '"' | '<' | '>' | '|') {
            sanitized.push('_');
        } else if ch.is_whitespace() {
            sanitized.push('_');
        } else {
            sanitized.push(ch);
        }
    }

    let trimmed = sanitized.trim_matches(|ch| ch == '_' || ch == '.');
    if trimmed.is_empty() {
        "课堂记录".to_string()
    } else {
        trimmed.to_string()
    }
}

fn fallback_export_stem(course_name: Option<&str>) -> String {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or(0);
    format!(
        "{}_{}",
        sanitize_filename_component(course_name.unwrap_or("课堂记录")),
        timestamp
    )
}

#[cfg(debug_assertions)]
fn resolve_backend_data_dir() -> Result<PathBuf, String> {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    manifest_dir
        .parent()
        .and_then(Path::parent)
        .map(|path| path.join("data"))
        .ok_or_else(|| "开发环境下无法解析 data 目录".to_string())
}

#[cfg(not(debug_assertions))]
fn resolve_backend_data_dir() -> Result<PathBuf, String> {
    let app_root = current_app_root()?;
    app_root
        .parent()
        .map(|contents_dir| contents_dir.join("Resources").join("data"))
        .ok_or_else(|| "发布环境下无法解析 Resources/data 目录".to_string())
}

#[cfg(target_os = "macos")]
fn resolve_documents_dir() -> Result<PathBuf, String> {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .map(|home| home.join("Documents"))
        .ok_or_else(|| "无法定位 Documents 目录".to_string())
}

#[cfg(target_os = "macos")]
fn escape_applescript(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}

#[cfg(target_os = "macos")]
fn choose_export_directory(default_dir: &Path) -> Result<Option<PathBuf>, String> {
    let script = format!(
        "set chosenFolder to choose folder with prompt \"请选择录音结束后的保存目录\" default location (POSIX file \"{}\")\nPOSIX path of chosenFolder",
        escape_applescript(&default_dir.display().to_string())
    );

    let output = Command::new("osascript")
        .arg("-e")
        .arg(script)
        .output()
        .map_err(|err| format!("打开目录选择框失败: {err}"))?;

    if output.status.success() {
        let selected = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if selected.is_empty() {
            return Ok(None);
        }
        return Ok(Some(PathBuf::from(selected)));
    }

    let stderr = String::from_utf8_lossy(&output.stderr);
    if stderr.contains("User canceled") || stderr.contains("(-128)") {
        return Ok(None);
    }

    Err(format!("目录选择失败: {}", stderr.trim()))
}

fn copy_file_to_directory(source: &Path, target_dir: &Path, target_name: &str) -> Result<(), String> {
    let target_path = target_dir.join(target_name);
    fs::copy(source, &target_path).map_err(|err| {
        format!(
            "复制文件失败: {} -> {} ({err})",
            source.display(),
            target_path.display()
        )
    })?;
    Ok(())
}

#[cfg(target_os = "macos")]
#[tauri::command]
fn export_monitor_artifacts(
    summary_filename: Option<String>,
    course_name: Option<String>,
) -> Result<ExportMonitorArtifactsResult, String> {
    let default_dir = resolve_documents_dir()?;
    let Some(target_dir) = choose_export_directory(&default_dir)? else {
        return Ok(build_export_result(false, None, Vec::new()));
    };

    fs::create_dir_all(&target_dir)
        .map_err(|err| format!("创建目标目录失败 {}: {err}", target_dir.display()))?;

    let data_dir = resolve_backend_data_dir()?;
    let transcript_path = data_dir.join("class_transcript.txt");
    let summary_path = summary_filename
        .as_ref()
        .map(|name| data_dir.join("summaries").join(name));

    let export_stem = summary_filename
        .as_ref()
        .and_then(|name| Path::new(name).file_stem())
        .and_then(|stem| stem.to_str())
        .map(str::to_string)
        .unwrap_or_else(|| fallback_export_stem(course_name.as_deref()));

    let mut saved_files = Vec::new();

    if transcript_path.exists() {
        let transcript_name = format!("{export_stem}_转录.txt");
        copy_file_to_directory(&transcript_path, &target_dir, &transcript_name)?;
        saved_files.push(transcript_name);
    }

    if let (Some(summary_name), Some(summary_source)) = (summary_filename.as_ref(), summary_path.as_ref()) {
        if summary_source.exists() {
            copy_file_to_directory(summary_source, &target_dir, summary_name)?;
            saved_files.push(summary_name.clone());
        }
    }

    if saved_files.is_empty() {
        return Err("未找到可导出的转录或总结文件".to_string());
    }

    Ok(build_export_result(
        true,
        Some(target_dir.display().to_string()),
        saved_files,
    ))
}

#[cfg(not(target_os = "macos"))]
#[tauri::command]
fn export_monitor_artifacts(
    _summary_filename: Option<String>,
    _course_name: Option<String>,
) -> Result<ExportMonitorArtifactsResult, String> {
    Ok(build_export_result(false, None, Vec::new()))
}

#[cfg(not(debug_assertions))]
fn append_startup_log(app_root: &Path, message: &str) {
    let data_dir = app_root.join("data");
    let _ = std::fs::create_dir_all(&data_dir);
    let log_path = data_dir.join("_startup_rust.log");

    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(log_path) {
        let _ = writeln!(file, "{message}");
    }
}

#[cfg(not(debug_assertions))]
fn current_app_root() -> Result<PathBuf, String> {
    std::env::current_exe()
        .map_err(|err| format!("无法定位当前程序路径: {err}"))?
        .parent()
        .map(Path::to_path_buf)
        .ok_or_else(|| "无法解析程序所在目录".to_string())
}

#[cfg(not(debug_assertions))]
fn ensure_backend_env(backend_dir: &Path) -> Result<bool, String> {
    let env_path = backend_dir.join(".env");
    if env_path.exists() {
        return Ok(false);
    }

    let example_path = backend_dir.join(".env.example");
    if !example_path.exists() {
        return Err("缺少 backend/.env.example，无法初始化配置".to_string());
    }

    fs::copy(&example_path, &env_path).map_err(|err| format!("初始化 .env 失败: {err}"))?;
    Ok(true)
}

#[cfg(not(debug_assertions))]
fn read_backend_port(backend_dir: &Path) -> u16 {
    let env_path = backend_dir.join(".env");
    let content = fs::read_to_string(env_path).unwrap_or_default();

    content
        .lines()
        .find_map(|line| {
            let trimmed = line.trim();
            if trimmed.starts_with("API_PORT=") {
                trimmed
                    .split_once('=')
                    .and_then(|(_, value)| value.trim().parse::<u16>().ok())
            } else {
                None
            }
        })
        .unwrap_or(8765)
}

#[cfg(not(debug_assertions))]
fn wait_for_backend_port(port: u16, timeout: Duration) -> Result<(), String> {
    let deadline = Instant::now() + timeout;

    while Instant::now() < deadline {
        let address = SocketAddr::from(([127, 0, 0, 1], port));
        if TcpStream::connect_timeout(&address, Duration::from_millis(350)).is_ok() {
            return Ok(());
        }

        std::thread::sleep(Duration::from_millis(300));
    }

    Err(format!("后端端口 {port} 在规定时间内未就绪"))
}

#[cfg(all(not(debug_assertions), target_os = "windows"))]
fn spawn_hidden_backend(backend_dir: &Path) -> Result<Child, String> {
    let backend_exe = backend_dir.join("class-assistant-backend.exe");
    if !backend_exe.exists() {
        return Err("未找到 backend/class-assistant-backend.exe".to_string());
    }

    let mut command = Command::new(backend_exe);
    command
        .current_dir(backend_dir)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .creation_flags(CREATE_NO_WINDOW);

    command
        .spawn()
        .map_err(|err| format!("启动后端失败: {err}"))
}

#[cfg(all(not(debug_assertions), target_os = "macos"))]
fn spawn_hidden_backend(backend_dir: &Path) -> Result<Child, String> {
    append_startup_log(backend_dir, &format!("spawn_hidden_backend called with dir: {:?}", backend_dir));

    // For macOS, we prioritize the Resources/backend folder in the app bundle
    let mut final_exe = backend_dir.join("class-assistant-backend");
    let mut working_dir = backend_dir.to_path_buf();

    if !final_exe.exists() {
        // Try to find Resources/backend
        // backend_dir is Contents/MacOS/backend
        // Contents/MacOS/backend -> Contents/MacOS/ -> Contents/ -> Contents/Resources/backend
        if let Some(contents_dir) = backend_dir.parent().and_then(|p| p.parent()) {
            let resources_backend = contents_dir.join("Resources").join("backend");
            let resources_exe = resources_backend.join("class-assistant-backend");
            
            append_startup_log(backend_dir, &format!("Trying Resources path: {:?}", resources_exe));
            
            if resources_exe.exists() {
                append_startup_log(backend_dir, "Backend found in Resources/backend");
                final_exe = resources_exe;
                working_dir = resources_backend;
            }
        }
    }

    if !final_exe.exists() {
        return Err(format!("未找到 backend/class-assistant-backend，搜索路径: {:?}", final_exe));
    }

    append_startup_log(backend_dir, &format!("Final backend exe: {:?}", final_exe));
    append_startup_log(backend_dir, &format!("Working dir: {:?}", working_dir));

    // Ensure .env exists in the working directory (it should have been copied or created)
    let env_path = working_dir.join(".env");
    if !env_path.exists() {
        let example_path = working_dir.join(".env.example");
        if example_path.exists() {
            let _ = fs::copy(&example_path, &env_path);
        }
    }

    // Make sure the backend executable has execute permission
    use std::os::unix::fs::PermissionsExt;
    if let Ok(metadata) = fs::metadata(&final_exe) {
        let mut perms = metadata.permissions();
        perms.set_mode(0o755);
        let _ = fs::set_permissions(&final_exe, perms);
    }

    let mut command = Command::new(&final_exe);
    command
        .current_dir(&working_dir)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    command
        .spawn()
        .map_err(|err| format!("启动后端失败: {err}"))
}

#[cfg(all(not(debug_assertions), target_os = "windows"))]
fn run_hidden_command(program: &str, args: &[&str]) {
    let mut command = Command::new(program);
    command
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .creation_flags(CREATE_NO_WINDOW);

    let _ = command.status();
}

#[cfg(all(not(debug_assertions), target_os = "windows"))]
fn run_hidden_powershell(script: &str) {
    run_hidden_command("powershell", &["-NoProfile", "-Command", script]);
}

#[cfg(all(not(debug_assertions), target_os = "macos"))]
fn run_hidden_command(program: &str, args: &[&str]) {
    let mut command = Command::new(program);
    command
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    let _ = command.status();
}

#[cfg(all(not(debug_assertions), any(target_os = "windows", target_os = "macos")))]
fn start_embedded_backend() -> Result<BackendBootstrapResult, String> {
    cleanup_backend_processes(false);

    let app_root = current_app_root()?;
    append_startup_log(&app_root, "start_embedded_backend invoked");

    // macOS path resolution: try MacOS/backend first, then Resources/backend
    let mut backend_dir = app_root.join("backend");
    
    #[cfg(target_os = "macos")]
    if !backend_dir.exists() {
        // app_root is Contents/MacOS/
        if let Some(contents_dir) = app_root.parent() {
            let resources_backend = contents_dir.join("Resources").join("backend");
            if resources_backend.exists() {
                backend_dir = resources_backend;
            }
        }
    }

    if !backend_dir.exists() {
        append_startup_log(&app_root, &format!("backend directory missing at {:?}", backend_dir));
        return Ok(build_bootstrap_result(
            "error",
            "发布目录缺少 backend 文件夹，请重新解压完整安装包。",
        ));
    }

    let env_created = ensure_backend_env(&backend_dir)?;
    if env_created {
        append_startup_log(&app_root, "backend .env created from template");
    }

    let port = read_backend_port(&backend_dir);
    append_startup_log(&app_root, &format!("starting backend on port {port} from {:?}", backend_dir));
    let child = spawn_hidden_backend(&backend_dir)?;
    let mut guard = BACKEND_CHILD.lock().expect("backend child mutex poisoned");
    *guard = Some(child);

    match wait_for_backend_port(port, Duration::from_secs(15)) {
        Ok(()) => {
            append_startup_log(&app_root, "backend port became reachable");
            Ok(build_bootstrap_result(
                "ready",
                if env_created {
                    "首次启动已自动生成 backend/.env，当前已直接进入主界面；如需填写 API Key，可稍后在设置中补充。"
                } else {
                    "本地服务启动中，正在连接课堂守候链路。"
                },
            ))
        }
        Err(err) => {
            append_startup_log(&app_root, &format!("backend readiness failed: {err}"));
            Err(format!("后端已启动但未就绪：{err}"))
        }
    }
}

#[cfg(any(debug_assertions, not(any(target_os = "windows", target_os = "macos"))))]
fn start_embedded_backend() -> Result<BackendBootstrapResult, String> {
    Ok(build_bootstrap_result(
        "ready",
        "开发模式不拦截主窗口启动。",
    ))
}

fn finish_startup(app_handle: &tauri::AppHandle) {
    if let Some(splash_window) = app_handle.get_webview_window("splash") {
        let _ = splash_window.close();
    }

    if let Some(main_window) = app_handle.get_webview_window("main") {
        let _ = main_window.show();
        let _ = main_window.set_focus();
    }
}

#[cfg(all(not(debug_assertions), target_os = "windows"))]
fn cleanup_backend_processes(graceful_stop: bool) {
    if let Ok(mut guard) = BACKEND_CHILD.lock() {
        if let Some(mut child) = guard.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }

    if graceful_stop {
        run_hidden_powershell("try { Invoke-WebRequest -Uri 'http://127.0.0.1:8765/api/stop_monitor' -Method Post -UseBasicParsing -TimeoutSec 2 | Out-Null } catch {}");
    }

    run_hidden_command("taskkill", &["/IM", "class-assistant-backend.exe", "/F"]);
    run_hidden_command("taskkill", &["/FI", "WINDOWTITLE eq ClassAssistant-Backend", "/F"]);
    run_hidden_powershell("$portPids = Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique; foreach ($portPid in $portPids) { Stop-Process -Id $portPid -Force -ErrorAction SilentlyContinue }");
}

#[cfg(all(not(debug_assertions), target_os = "macos"))]
fn cleanup_backend_processes(graceful_stop: bool) {
    if let Ok(mut guard) = BACKEND_CHILD.lock() {
        if let Some(mut child) = guard.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }

    if graceful_stop {
        // Gracefully stop backend via API
        run_hidden_command("curl", &["-s", "-X", "POST", "http://127.0.0.1:8765/api/stop_monitor"]);
    }

    // Kill backend process by name
    run_hidden_command("pkill", &["-f", "class-assistant-backend"]);

    // Kill any process listening on port 8765 using shell
    let _ = Command::new("sh")
        .args(&["-c", "lsof -ti:8765 -s TCP:LISTEN | xargs kill -9 2>/dev/null"])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

#[cfg(any(debug_assertions, not(any(target_os = "windows", target_os = "macos"))))]
fn cleanup_backend_processes(_graceful_stop: bool) {}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![greet, export_monitor_artifacts])
        .setup(|app| {
            let app_handle = app.handle().clone();

            #[cfg(debug_assertions)]
            {
                finish_startup(&app_handle);
            }

            #[cfg(all(not(debug_assertions), any(target_os = "windows", target_os = "macos")))]
            {
                if let Some(main_window) = app_handle.get_webview_window("main") {
                    let _ = main_window.hide();
                }

                let _ = WebviewWindowBuilder::new(
                    app,
                    "splash",
                    WebviewUrl::App("index.html".into()),
                )
                .title("ClassFox Splash")
                .inner_size(240.0, 220.0)
                .resizable(false)
                .decorations(false)
                .always_on_top(true)
                .skip_taskbar(true)
                .center()
                .build()?;

                std::thread::spawn(move || {
                    let startup_result = start_embedded_backend();

                    #[cfg(not(debug_assertions))]
                    if let Ok(app_root) = current_app_root() {
                        match &startup_result {
                            Ok(result) => append_startup_log(&app_root, &format!("startup result: {}", result.message)),
                            Err(error) => append_startup_log(&app_root, &format!("startup error: {error}")),
                        }
                    }

                    finish_startup(&app_handle);
                });
            }

            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(|_app_handle, event| {
            if let tauri::RunEvent::Exit = event {
                cleanup_backend_processes(true);
            }
        });
}
