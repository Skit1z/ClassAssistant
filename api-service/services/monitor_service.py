"""
监控服务
========
负责麦克风录音、ASR 转文字、关键词匹配与 WebSocket 警报推送
"""

import asyncio
import json
import logging
import os
import re
import threading
from datetime import datetime
from typing import List, Set

from fastapi import WebSocket

from config import DATA_DIR
from services.asr_service import create_asr, BaseASR, LocalASR

logger = logging.getLogger(__name__)


class MonitorService:
    """课堂监控服务 - 核心后台服务"""

    def __init__(self):
        # 关键词文件路径
        self.keywords_path = os.path.join(DATA_DIR, "keywords.txt")
        # 从文件加载关键词
        self._load_keywords()
        # 用户自定义关键词（如自己的名字，通过 API 传入）
        self.custom_keywords: List[str] = []

        # 录音状态
        self.is_monitoring: bool = False

        # ASR 实例
        self._asr: BaseASR | None = None

        # 用于从 ASR 回调线程安全地广播到 WebSocket 的事件循环
        self._loop: asyncio.AbstractEventLoop | None = None

        # WebSocket 连接池
        self._websockets: Set[WebSocket] = set()

        # 转录文件路径
        self.transcript_path = os.path.join(DATA_DIR, "class_transcript.txt")

        # ASR 增量文本追踪（避免关键词重复触发）
        self._last_asr_text: str = ""
        # 转录文件中"已固定"的字节位置（活动行起始处）
        self._live_line_pos: int = 0

    def get_all_keywords(self) -> List[str]:
        """获取所有关键词（内置 + 自定义）"""
        return self.builtin_keywords + self.custom_keywords

    def update_custom_keywords(self, keywords: List[str]):
        """更新用户自定义关键词"""
        self.custom_keywords = keywords

    def _load_keywords(self):
        """从 data/keywords.txt 加载关键词列表"""
        if os.path.exists(self.keywords_path):
            with open(self.keywords_path, "r", encoding="utf-8") as f:
                self.builtin_keywords = [
                    line.strip() for line in f
                    if line.strip() and not line.startswith("#")
                ]
        else:
            # 文件不存在，使用默认关键词并创建文件
            self.builtin_keywords = [
                "点名", "随机", "抽查", "叫人", "回答", "签到",
                "哪位同学", "谁来", "站起来", "请回答",
            ]
            self._save_default_keywords()

    def _save_default_keywords(self):
        """创建默认关键词文件"""
        os.makedirs(DATA_DIR, exist_ok=True)
        with open(self.keywords_path, "w", encoding="utf-8") as f:
            f.write("# 监控关键词列表（每行一个，# 开头为注释）\n")
            f.write("# 编辑后重启监控或调用 reload_keywords 即可生效\n")
            for kw in self.builtin_keywords:
                f.write(kw + "\n")

    def reload_keywords(self):
        """重新加载关键词文件"""
        self._load_keywords()
        return self.get_all_keywords()

    def register_websocket(self, ws: WebSocket):
        """注册 WebSocket 连接"""
        self._websockets.add(ws)

    def unregister_websocket(self, ws: WebSocket):
        """注销 WebSocket 连接"""
        self._websockets.discard(ws)

    async def _broadcast_alert(self, message: dict):
        """向所有已连接的 WebSocket 客户端广播警报"""
        dead_connections = set()
        for ws in self._websockets:
            try:
                await ws.send_text(json.dumps(message, ensure_ascii=False))
            except Exception:
                dead_connections.add(ws)
        # 清理断开的连接
        self._websockets -= dead_connections

    def _check_keywords(self, text: str) -> List[str]:
        """
        检查文本中是否包含监控关键词

        Args:
            text: ASR 识别出的文本

        Returns:
            匹配到的关键词列表
        """
        matched = []
        all_keywords = self.get_all_keywords()
        for keyword in all_keywords:
            # 使用正则匹配，支持模糊匹配
            if re.search(re.escape(keyword), text):
                matched.append(keyword)
        return matched

    async def start(self) -> dict:
        """启动监控服务"""
        if self.is_monitoring:
            return {"status": "already_running", "message": "监控服务已在运行中"}

        self.is_monitoring = True

        # 保存当前事件循环引用，供 ASR 回调使用
        self._loop = asyncio.get_running_loop()

        # 重新加载关键词文件
        self._load_keywords()
        # 重置增量追踪状态
        self._last_asr_text = ""
        self._live_line_pos = 0
        # 已固定到转录文件的 ASR 文本长度
        self._finalized_len: int = 0

        # 清空/初始化转录文件，记录活动行起始位置
        with open(self.transcript_path, "w", encoding="utf-8") as f:
            f.write(f"=== 课堂记录 开始于 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n\n")
            self._live_line_pos = f.tell()

        # 创建 ASR 实例并启动
        # 本地 ASR 使用独立的回调（每句新建一行），线上 ASR 使用流式回调
        self._asr = create_asr(on_text=self._on_asr_text)
        if isinstance(self._asr, LocalASR):
            self._asr.on_text = self._on_local_asr_text
        self._asr.start()

        return {"status": "started", "message": "开始摸鱼模式 🎣 录音和监控已启动"}

    async def stop(self) -> dict:
        """停止监控服务"""
        if not self.is_monitoring:
            return {"status": "not_running", "message": "监控服务未在运行"}

        self.is_monitoring = False

        # 停止 ASR
        if self._asr:
            self._asr.stop()
            self._asr = None

        # 固定最后的活动行（如果有未固定的内容）
        remaining = self._last_asr_text[self._finalized_len:].strip()
        if remaining:
            timestamp = datetime.now().strftime("%H:%M:%S")
            try:
                with open(self.transcript_path, "r+", encoding="utf-8") as f:
                    f.seek(self._live_line_pos)
                    f.truncate()
                    f.write(f"[{timestamp}] {remaining}\n")
            except Exception:
                logger.exception("写入转录文件失败")

        # 写入结束标记
        with open(self.transcript_path, "a", encoding="utf-8") as f:
            f.write(f"\n\n=== 课堂记录 结束于 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n")

        return {"status": "stopped", "message": "监控已停止"}

    def _check_last_lines_keywords(self) -> List[str]:
        """
        只检查转录文件最近两行的关键词，避免历史文本反复触发。
        """
        try:
            with open(self.transcript_path, "r", encoding="utf-8") as f:
                lines = f.readlines()
            # 取最后两行有效内容
            recent = [l.strip() for l in lines[-2:] if l.strip() and not l.startswith("===")]
            text = " ".join(recent)
            return self._check_keywords(text) if text else []
        except Exception:
            return []

    def _on_local_asr_text(self, text: str, is_final: bool):
        """
        本地 ASR 识别回调 - 每识别一句话就追加一行到转录文件。
        不使用流式覆盖逻辑，因为本地 ASR 是分段式识别。
        """
        if not self.is_monitoring or not text.strip():
            return

        timestamp = datetime.now().strftime("%H:%M:%S")

        # 追加新行
        try:
            with open(self.transcript_path, "a", encoding="utf-8") as f:
                f.write(f"[{timestamp}] {text.strip()}\n")
        except Exception:
            logger.exception("写入转录文件失败")

        # 关键词检测：只检查最近两行
        matched = self._check_last_lines_keywords()
        if matched and self._loop:
            alert = {
                "type": "keyword_alert",
                "keywords": matched,
                "text": text,
                "timestamp": timestamp,
            }
            asyncio.run_coroutine_threadsafe(
                self._broadcast_alert(alert), self._loop
            )

    def _on_asr_text(self, text: str, is_final: bool):
        """
        ASR 识别回调 (可能从非主线程调用) —— 用于线上流式 ASR。

        实时更新转录文件：
        - 每次回调都更新当前活动行（原地覆盖）
        - 遇到句末标点时固定该行，开始新的活动行
        - 关键词检测只检查转录文件最近两行，避免重复触发
        """
        if not self.is_monitoring or not text.strip():
            return

        timestamp = datetime.now().strftime("%H:%M:%S")
        logger.info("[ASR] on_text (len=%d): %s", len(text), text[:60])

        # 计算增量文本（新增部分）
        prev = self._last_asr_text
        if len(text) >= len(prev) and text[:len(prev)] == prev:
            delta = text[len(prev):]
        else:
            delta = text
            self._finalized_len = 0
        self._last_asr_text = text

        # 实时更新转录文件
        self._write_transcript(text, timestamp)

        # 关键词检测：只检查转录文件最近两行
        if delta.strip():
            matched = self._check_last_lines_keywords()
            if matched and self._loop:
                alert = {
                    "type": "keyword_alert",
                    "keywords": matched,
                    "text": text,
                    "timestamp": timestamp,
                }
                asyncio.run_coroutine_threadsafe(
                    self._broadcast_alert(alert), self._loop
                )

    def _write_transcript(self, full_text: str, timestamp: str):
        """
        实时更新转录文件。

        策略：
        - 从 full_text[_finalized_len:] 中检查是否有新的句子结束标点
        - 有则固定这些句子为永久行，更新 _live_line_pos
        - 剩余未完成的部分作为活动行，原地覆盖（seek + truncate）
        """
        pending = full_text[self._finalized_len:]
        if not pending:
            return

        try:
            with open(self.transcript_path, "r+", encoding="utf-8") as f:
                # 定位到活动行起始位置，截断后面的内容
                f.seek(self._live_line_pos)
                f.truncate()

                # 在 pending 中找所有句子边界
                last_boundary = -1
                for i, ch in enumerate(pending):
                    if ch in "。？！；\n":
                        last_boundary = i

                if last_boundary >= 0:
                    # 固定已完成的句子
                    finalized = pending[:last_boundary + 1].strip()
                    if finalized:
                        f.write(f"[{timestamp}] {finalized}\n")
                    self._finalized_len += last_boundary + 1
                    # 更新活动行起始位置
                    self._live_line_pos = f.tell()
                    # 剩余未完成部分
                    remainder = pending[last_boundary + 1:]
                else:
                    remainder = pending

                # 写入活动行（未完成的部分，下次会被覆盖）
                if remainder.strip():
                    f.write(f"[{timestamp}] {remainder.strip()}")
        except Exception:
            logger.exception("写入转录文件失败")
