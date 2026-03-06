/**
 * 课堂进度面板
 * =============
 * 告诉用户"老师讲到哪了"——调用 LLM 总结课堂进度
 */

import { useEffect, useState } from "react";
import { catchup } from "../services/api";

interface CatchupPanelProps {
  visible: boolean;
  onClose: () => void;
}

export default function CatchupPanel({ visible, onClose }: CatchupPanelProps) {
  const [summary, setSummary] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!visible) return;

    setLoading(true);
    setError(null);
    setSummary(null);

    catchup()
      .then((res) => setSummary(res.summary))
      .catch((err) => setError(err.message || "请求失败"))
      .finally(() => setLoading(false));
  }, [visible]);

  // 面板打开时调大窗口
  useEffect(() => {
    (async () => {
      try {
        const { getCurrentWindow } = await import("@tauri-apps/api/window");
        const { LogicalSize } = await import("@tauri-apps/api/dpi");
        const win = getCurrentWindow();
        if (visible) {
          await win.setSize(new LogicalSize(400, 400));
        } else {
          await win.setSize(new LogicalSize(320, 80));
        }
      } catch {
        /* 忽略窗口操作错误 */
      }
    })();
  }, [visible]);

  if (!visible) return null;

  return (
    <div className="flex flex-col gap-2 p-3 animate-in fade-in duration-300">
      {loading && (
        <div className="flex items-center justify-center py-8 text-white/60">
          <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2" />
          <span className="text-sm">正在分析课堂进度...</span>
        </div>
      )}

      {error && (
        <div className="p-3 rounded-xl bg-red-500/20 border border-red-500/30 text-red-300 text-xs">
          ⚠️ {error}
        </div>
      )}

      {summary && !loading && (
        <div className="p-3 rounded-xl bg-indigo-500/10 border border-indigo-500/20">
          <div className="flex items-center gap-1.5 mb-2">
            <span className="text-sm">📍</span>
            <span className="text-xs font-semibold text-indigo-300">老师讲到哪了</span>
          </div>
          <p className="text-xs text-white/85 leading-relaxed whitespace-pre-wrap">{summary}</p>
        </div>
      )}

      <button
        onClick={onClose}
        className="mt-1 px-4 py-1.5 text-xs rounded-lg
                   bg-white/10 text-white/60
                   hover:bg-white/20 hover:text-white
                   transition-all duration-150 self-center"
      >
        收起面板
      </button>
    </div>
  );
}
