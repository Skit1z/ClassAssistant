/**
 * 标题栏组件
 * ==========
 * 无边框窗口的自定义拖拽标题栏
 */

interface TitleBarProps {
  /** 是否正在监控中 */
  isMonitoring: boolean;
  /** 是否暂停中 */
  isPaused: boolean;
  /** 当前课程名称 */
  courseName: string;
}

export default function TitleBar({ isMonitoring, isPaused, courseName }: TitleBarProps) {
  /** 关闭窗口 */
  const handleClose = async () => {
    const { getCurrentWindow } = await import("@tauri-apps/api/window");
    getCurrentWindow().close();
  };

  /** 最小化窗口 */
  const handleMinimize = async () => {
    const { getCurrentWindow } = await import("@tauri-apps/api/window");
    getCurrentWindow().minimize();
  };

  return (
    <div
      data-tauri-drag-region
      className="flex h-10 items-center justify-between px-3 select-none"
    >
      <div className="flex items-center gap-3">
        {/* 左侧窗口控制按钮 - macOS 风格并常显 */}
        <div className="flex items-center gap-2" onMouseDown={(event) => event.stopPropagation()}>
          <button
            onClick={handleClose}
            className="grid h-3.5 w-3.5 place-items-center rounded-full border border-black/15 bg-[#ff5f57] text-[8px] font-semibold leading-none text-black/55 transition hover:brightness-105 active:brightness-95"
            title="关闭"
            aria-label="关闭"
          >
            ×
          </button>
          <button
            onClick={handleMinimize}
            className="grid h-3.5 w-3.5 place-items-center rounded-full border border-black/15 bg-[#febc2e] text-[9px] font-semibold leading-none text-black/55 transition hover:brightness-105 active:brightness-95"
            title="最小化"
            aria-label="最小化"
          >
            −
          </button>
        </div>

        {/* 标题信息 */}
        <div data-tauri-drag-region className="flex items-center gap-1.5 text-xs text-white/80">
          <span className="text-sm">🦊</span>
          <span className="font-medium tracking-wide">课狐 ClassFox</span>
          {isMonitoring && (
            <span className={`inline-block h-1.5 w-1.5 rounded-full ${isPaused ? "bg-amber-300" : "bg-green-400 animate-pulse"}`} />
          )}
          {courseName && <span className="max-w-40 truncate text-[11px] text-white/45">{courseName}</span>}
        </div>
      </div>
      <div data-tauri-drag-region className="h-full flex-1 cursor-move" />
    </div>
  );
}
