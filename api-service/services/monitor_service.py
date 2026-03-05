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

from services.asr_service import create_asr, BaseASR

logger = logging.getLogger(__name__)

# data 目录路径
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data")


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
        # 已写入转录文件的文本长度
        self._written_len: int = 0

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
        self._written_len = 0

        # 清空/初始化转录文件
        with open(self.transcript_path, "w", encoding="utf-8") as f:
            f.write(f"=== 课堂记录 开始于 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n\n")

        # 创建 ASR 实例并启动
        self._asr = create_asr(on_text=self._on_asr_text)
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

        # 将未写入的剩余文本刷入转录文件
        if self._last_asr_text and self._written_len < len(self._last_asr_text):
            remaining = self._last_asr_text[self._written_len:].strip()
            if remaining:
                timestamp = datetime.now().strftime("%H:%M:%S")
                try:
                    with open(self.transcript_path, "a", encoding="utf-8") as f:
                        f.write(f"[{timestamp}] {remaining}\n")
                except Exception:
                    logger.exception("写入转录文件失败")

        # 写入结束标记
        with open(self.transcript_path, "a", encoding="utf-8") as f:
            f.write(f"\n\n=== 课堂记录 结束于 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n")

        return {"status": "stopped", "message": "监控已停止"}

    def _on_asr_text(self, text: str, is_final: bool):
        """
        ASR 识别回调 (可能从非主线程调用)。

        Seed-ASR 每次返回完整累积文本，因此：
        - 关键词检测只针对新增文本部分，避免重复触发
        - 转录文件只写入完整句子，避免大量中间结果
        """
        if not self.is_monitoring or not text.strip():
            return

        timestamp = datetime.now().strftime("%H:%M:%S")

        # 计算增量文本（新增部分）
        prev = self._last_asr_text
        if len(text) >= len(prev) and text[:len(prev)] == prev:
            delta = text[len(prev):]
        else:
            # 文本被重置或修正，整段视为新文本
            delta = text
            self._written_len = 0
        self._last_asr_text = text

        # 写入转录文件（只写完整句子）
        self._write_transcript(text, timestamp)

        # 关键词检测：只检查增量文本
        if delta.strip():
            matched = self._check_keywords(delta)
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
        """将新完成的句子写入转录文件（忽略中间结果）"""
        if len(full_text) < self._written_len:
            # 文本被重置，重新开始追踪
            self._written_len = 0

        new_text = full_text[self._written_len:]
        if not new_text:
            return

        # 找最后一个句子结束标点的位置
        last_boundary = -1
        for i, ch in enumerate(new_text):
            if ch in "。？！；\n":
                last_boundary = i

        if last_boundary >= 0:
            to_write = new_text[:last_boundary + 1].strip()
            self._written_len += last_boundary + 1
            if to_write:
                try:
                    with open(self.transcript_path, "a", encoding="utf-8") as f:
                        f.write(f"[{timestamp}] {to_write}\n")
                except Exception:
                    logger.exception("写入转录文件失败")
