from __future__ import annotations

import json
import os
import threading
import time
import urllib.error
import urllib.request
from typing import Any

from agent.memory_provider import MemoryProvider


class AgentMemoryProvider(MemoryProvider):
    def __init__(self) -> None:
        self._base_url = os.environ.get("AGENTMEMORY_URL", "http://127.0.0.1:3111").rstrip("/")
        self._secret = os.environ.get("AGENTMEMORY_SECRET", "")
        self._session_id = ""
        self._project = "/workspace"
        self._cwd = "/workspace"
        self._prefetch_result = ""
        self._prefetch_lock = threading.Lock()
        self._prefetch_thread: threading.Thread | None = None

    @property
    def name(self) -> str:
        return "agentmemory"

    def is_available(self) -> bool:
        return bool(self._base_url)

    def initialize(self, session_id: str, **kwargs: Any) -> None:
        self._session_id = session_id
        self._cwd = os.getcwd()
        self._project = self._cwd
        self._post_async(
            "/agentmemory/session/start",
            {"sessionId": self._session_id, "project": self._project, "cwd": self._cwd},
        )

    def system_prompt_block(self) -> str:
        return (
            "# AgentMemory\n"
            "Persistent cross-session memory is active. Relevant memories are injected "
            "automatically when available. Use agentmemory_recall to search prior "
            "sessions and agentmemory_save to store durable facts or decisions."
        )

    def prefetch(self, query: str, *, session_id: str = "") -> str:
        thread = self._prefetch_thread
        if thread and thread.is_alive():
            thread.join(timeout=2.0)
        with self._prefetch_lock:
            result = self._prefetch_result
            self._prefetch_result = ""
        if not result:
            return ""
        return (
            "# AgentMemory recalled context\n"
            "Use this as persistent reference context, not as new user input.\n\n"
            f"{result}"
        )

    def queue_prefetch(self, query: str, *, session_id: str = "") -> None:
        if not query.strip():
            return

        def run() -> None:
            try:
                data = self._post(
                    "/agentmemory/smart-search",
                    {
                        "query": query[:800],
                        "limit": 8,
                        "cwd": self._cwd,
                        "project": self._project,
                        "format": "narrative",
                        "token_budget": 1800,
                    },
                    timeout=4.0,
                )
                text = self._extract_text(data)
                if text:
                    with self._prefetch_lock:
                        self._prefetch_result = text
            except Exception:
                return

        self._prefetch_thread = threading.Thread(target=run, daemon=True, name="agentmemory-prefetch")
        self._prefetch_thread.start()

    def sync_turn(self, user_content: str, assistant_content: str, *, session_id: str = "") -> None:
        sid = session_id or self._session_id
        self._post_async(
            "/agentmemory/observe",
            {
                "hookType": "turn",
                "sessionId": sid,
                "project": self._project,
                "cwd": self._cwd,
                "timestamp": self._now(),
                "data": {
                    "user": user_content,
                    "assistant": assistant_content,
                },
            },
        )

    def get_tool_schemas(self) -> list[dict[str, Any]]:
        return [
            {
                "name": "agentmemory_save",
                "description": "Save an important durable fact, decision, or workflow note to AgentMemory.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "content": {"type": "string", "description": "Memory content to save"},
                    },
                    "required": ["content"],
                },
            },
            {
                "name": "agentmemory_recall",
                "description": "Search AgentMemory for relevant prior sessions, decisions, and observations.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "query": {"type": "string", "description": "Search query"},
                        "limit": {"type": "integer", "description": "Maximum result count"},
                    },
                    "required": ["query"],
                },
            },
        ]

    def handle_tool_call(self, tool_name: str, args: dict[str, Any], **kwargs: Any) -> str:
        try:
            if tool_name == "agentmemory_save":
                content = str(args.get("content", "")).strip()
                if not content:
                    return json.dumps({"error": "content is required"})
                data = self._post(
                    "/agentmemory/remember",
                    {"content": content, "project": self._project, "cwd": self._cwd},
                    timeout=8.0,
                )
                return json.dumps({"result": "saved", "response": data})

            if tool_name == "agentmemory_recall":
                query = str(args.get("query", "")).strip()
                if not query:
                    return json.dumps({"error": "query is required"})
                limit = args.get("limit", 10)
                if not isinstance(limit, int) or limit < 1:
                    limit = 10
                data = self._post(
                    "/agentmemory/smart-search",
                    {"query": query, "limit": limit, "cwd": self._cwd, "project": self._project},
                    timeout=8.0,
                )
                return json.dumps({"result": self._extract_text(data), "response": data})
        except Exception as exc:
            return json.dumps({"error": str(exc)})
        return json.dumps({"error": f"unknown tool: {tool_name}"})

    def on_session_end(self, messages: list[dict[str, Any]]) -> None:
        self._post_async("/agentmemory/session/end", {"sessionId": self._session_id})

    def shutdown(self) -> None:
        thread = self._prefetch_thread
        if thread and thread.is_alive():
            thread.join(timeout=2.0)

    def _headers(self) -> dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if self._secret:
            headers["Authorization"] = f"Bearer {self._secret}"
        return headers

    def _post(self, path: str, payload: dict[str, Any], *, timeout: float = 3.0) -> Any:
        req = urllib.request.Request(
            f"{self._base_url}{path}",
            data=json.dumps(payload).encode("utf-8"),
            headers=self._headers(),
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"AgentMemory HTTP {exc.code}: {detail}") from exc
        return json.loads(raw) if raw else {}

    def _post_async(self, path: str, payload: dict[str, Any]) -> None:
        def run() -> None:
            try:
                self._post(path, payload)
            except Exception:
                return

        threading.Thread(target=run, daemon=True, name="agentmemory-write").start()

    @staticmethod
    def _extract_text(data: Any) -> str:
        if isinstance(data, str):
            return data
        if not isinstance(data, dict):
            return ""
        for key in ("text", "context", "result", "narrative", "summary"):
            value = data.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
        results = data.get("results") or data.get("memories") or data.get("observations")
        if isinstance(results, list):
            lines = []
            for item in results:
                if isinstance(item, str):
                    lines.append(item)
                elif isinstance(item, dict):
                    text = item.get("text") or item.get("narrative") or item.get("content") or item.get("title")
                    if isinstance(text, str) and text.strip():
                        lines.append(text.strip())
            return "\n".join(lines)
        return json.dumps(data)[:4000]

    @staticmethod
    def _now() -> str:
        return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def register(ctx: Any) -> None:
    ctx.register_memory_provider(AgentMemoryProvider())
