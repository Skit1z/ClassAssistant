/**
 * 工具栏组件
 * ==========
 * 包含「上传资料」和「开始摸鱼」两个核心按钮
 */

import { useEffect, useRef, useState } from "react";

interface ToolBarProps {
  /** 是否正在监控 */
  isMonitoring: boolean;
  /** 是否暂停中 */
  isPaused: boolean;
  /** 是否正在加载中 */
  isLoading: boolean;
  /** 当前课程名 */
  courseName: string;
  /** 点击上传资料 */
  onUpload: (file: File) => void;
  /** 点击开始摸鱼 */
  onStartMonitor: () => void;
  /** 点击停止摸鱼 */
  onStopMonitor: () => void;
  /** 点击暂停/继续 */
  onPauseResume: () => void;
  /** 点击"老师讲到哪了" */
  onCatchup: () => void;
  /** 点击设置 */
  onSettings: () => void;
}

export default function ToolBar({
  isMonitoring,
  isPaused,
  isLoading,
  courseName,
  onUpload,
  onStartMonitor,
  onStopMonitor,
  onPauseResume,
  onCatchup,
  onSettings,
}: ToolBarProps) {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [showMore, setShowMore] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const { getCurrentWindow } = await import("@tauri-apps/api/window");
        const { LogicalSize } = await import("@tauri-apps/api/dpi");
        const win = getCurrentWindow();
        const height = isMonitoring
          ? (showMore ? 300 : 210)
          : (showMore ? 300 : 200);
        await win.setSize(new LogicalSize(520, height));
      } catch {
        /* 忽略窗口操作错误 */
      }
    })();
  }, [isMonitoring, showMore]);

  /** 触发文件选择 */
  const handleUploadClick = () => {
    fileInputRef.current?.click();
  };

  /** 文件选中后回调 */
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      onUpload(file);
      // 清空 input 以允许重复上传同一文件
      e.target.value = "";
    }
  };

  return (
    <div className="relative flex flex-col gap-3 px-3 pb-3">
      {/* 隐藏的文件选择器 */}
      <input
        ref={fileInputRef}
        type="file"
        accept=".pptx,.ppt,.pdf,.docx,.doc"
        className="hidden"
        onChange={handleFileChange}
        aria-label="上传课程资料文件"
      />

      {!isMonitoring ? (
        <>
          <div className="grid grid-cols-5 gap-2">
            <button
              onClick={onStartMonitor}
              disabled={isLoading}
              className="theme-primary-button col-span-4 min-h-20 rounded-[calc(var(--window-radius)+8px)] px-5 py-4 text-xl font-semibold tracking-wide transition hover:brightness-110 disabled:opacity-50"
              title="开始录音与监控"
            >
              🎣 开始摸鱼
            </button>

            <button
              onClick={() => setShowMore((prev) => !prev)}
              className="theme-secondary-button col-span-1 min-h-20 rounded-[calc(var(--window-radius)+4px)] px-2 py-3 text-sm font-medium transition hover:brightness-110"
            >
              {showMore ? "收起" : "更多"}
            </button>
          </div>

          <div className="theme-muted-text text-[12px] leading-6">上传资料、设置和其他入口都收在更多功能里。</div>
        </>
      ) : (
        <>
          <div className="theme-panel flex items-center justify-between rounded-[calc(var(--window-radius)+8px)] px-3 py-3 text-xs text-white/78">
            <span>{courseName ? `当前课程：${courseName}` : "当前课程：未命名课程"}</span>
            <span>{isPaused ? "已暂停" : "监控中"}</span>
          </div>

          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={onPauseResume}
              disabled={isLoading}
              className={`rounded-[calc(var(--window-radius)+6px)] px-4 py-3 text-sm font-medium transition disabled:opacity-50 ${
                isPaused ? "theme-primary-button hover:brightness-110" : "theme-secondary-button hover:brightness-110"
              }`}
            >
              {isPaused ? "▶ 继续监听" : "⏸ 暂停监听"}
            </button>

            <button
              onClick={onStopMonitor}
              disabled={isLoading}
              className="rounded-[calc(var(--window-radius)+6px)] border border-red-400/25 bg-red-500/16 px-4 py-3 text-sm font-medium text-red-100 transition hover:bg-red-500/26 disabled:opacity-50"
            >
              ⏹ 结束摸鱼
            </button>
          </div>

          <div className="flex items-center justify-end">
            <button
              onClick={() => setShowMore((prev) => !prev)}
              className="theme-secondary-button rounded-[calc(var(--window-radius)+4px)] px-3 py-2 text-xs transition hover:brightness-110"
            >
              {showMore ? "收起功能" : "更多功能"}
            </button>
          </div>
        </>
      )}

      {showMore && (
        <div className="theme-panel grid gap-2 rounded-[calc(var(--window-radius)+8px)] p-2 backdrop-blur-md">
          <button
            onClick={handleUploadClick}
            disabled={isLoading}
            className="theme-feature-button rounded-[calc(var(--window-radius)+4px)] px-3 py-3 text-left text-sm font-medium transition hover:brightness-110 disabled:opacity-50"
            title="上传课程 PPT 资料"
          >
            📄 上传资料进行分析
          </button>

          {isMonitoring && (
            <button
              onClick={onCatchup}
              disabled={isLoading}
              className="theme-feature-button rounded-[calc(var(--window-radius)+4px)] px-3 py-3 text-left text-sm font-medium transition hover:brightness-110 disabled:opacity-50"
            >
              📍 老师讲到哪儿了
            </button>
          )}

          <button
            onClick={onSettings}
            disabled={isLoading}
            className="theme-secondary-button rounded-[calc(var(--window-radius)+4px)] px-3 py-3 text-left text-sm font-medium transition hover:brightness-110 disabled:opacity-50"
          >
            ⚙️ 设置
          </button>
        </div>
      )}
    </div>
  );
}
