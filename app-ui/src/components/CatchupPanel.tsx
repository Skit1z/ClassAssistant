/**
 * 课堂进度面板
 * =============
 * 告诉用户"老师讲到哪了"——调用 LLM 总结课堂进度
 */

import { useEffect, useMemo, useState } from "react";
import { catchup, catchupChat } from "../services/api";

interface CatchupPanelProps {
  visible: boolean;
  onClose: () => void;
}

export default function CatchupPanel({ visible, onClose }: CatchupPanelProps) {
  const [summary, setSummary] = useState<string | null>(null);
  const [question, setQuestion] = useState("");
  const [messages, setMessages] = useState<Array<{ role: "user" | "assistant"; content: string }>>([]);
  const [loading, setLoading] = useState(false);
  const [asking, setAsking] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canAsk = useMemo(() => Boolean(summary && question.trim() && !asking), [summary, question, asking]);

  useEffect(() => {
    if (!visible) return;

    setLoading(true);
    setError(null);
    setSummary(null);
    setQuestion("");
    setMessages([]);

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
          await win.setSize(new LogicalSize(520, 560));
        } else {
          await win.setSize(new LogicalSize(560, 220));
        }
      } catch {
        /* 忽略窗口操作错误 */
      }
    })();
  }, [visible]);

  if (!visible) return null;

  const handleAsk = async () => {
    if (!summary || !question.trim() || asking) return;

    const nextQuestion = question.trim();
    const nextHistory = [...messages, { role: "user" as const, content: nextQuestion }];
    setMessages(nextHistory);
    setQuestion("");
    setAsking(true);
    setError(null);

    try {
      const res = await catchupChat({
        summary,
        question: nextQuestion,
        history: messages,
      });
      setMessages((prev) => [...prev, { role: "assistant", content: res.answer }]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "追问失败");
    } finally {
      setAsking(false);
    }
  };

  return (
    <div className="flex h-full flex-col gap-3 p-3 animate-in fade-in duration-300">
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
        <div className="rounded-xl border border-indigo-500/20 bg-indigo-500/10 p-3">
          <div className="flex items-center gap-1.5 mb-2">
            <span className="text-sm">📍</span>
            <span className="text-xs font-semibold text-indigo-300">老师讲到哪了</span>
          </div>
          <p className="text-xs text-white/85 leading-relaxed whitespace-pre-wrap">{summary}</p>
        </div>
      )}

      {summary && !loading && (
        <div className="min-h-0 flex-1 rounded-2xl border border-white/10 bg-white/5 p-3">
          <div className="mb-2 flex items-center justify-between">
            <span className="text-xs font-semibold text-white/80">继续追问 AI</span>
            <span className="text-[11px] text-white/40">会结合当前课堂上下文回答</span>
          </div>

          <div className="flex h-[250px] flex-col gap-2 overflow-y-auto pr-1">
            {messages.length === 0 ? (
              <div className="rounded-xl border border-dashed border-white/10 bg-black/10 px-3 py-4 text-xs leading-6 text-white/45">
                可以继续问术语、概念、疑难点，或者让它解释老师刚才那段内容。
              </div>
            ) : (
              messages.map((message, index) => (
                <div
                  key={`${message.role}-${index}`}
                  className={`rounded-2xl px-3 py-2 text-xs leading-6 ${
                    message.role === "user"
                      ? "self-end bg-cyan-500/16 text-cyan-50"
                      : "self-start border border-white/10 bg-white/7 text-white/88"
                  }`}
                >
                  {message.content}
                </div>
              ))
            )}
            {asking && (
              <div className="self-start rounded-2xl border border-white/10 bg-white/7 px-3 py-2 text-xs text-white/55">
                正在结合当前上下文回答...
              </div>
            )}
          </div>

          <div className="mt-3 flex gap-2">
            <textarea
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              placeholder="比如：刚才提到的那个概念是什么意思？"
              className="min-h-20 flex-1 resize-none rounded-2xl border border-white/10 bg-black/15 px-3 py-2 text-xs text-white outline-none transition focus:border-cyan-400/50"
            />
            <button
              onClick={handleAsk}
              disabled={!canAsk}
              className="rounded-2xl border border-cyan-400/20 bg-cyan-500/16 px-4 py-3 text-xs font-medium text-cyan-100 transition hover:bg-cyan-500/24 disabled:opacity-50"
            >
              追问
            </button>
          </div>
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
