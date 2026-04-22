"""
Hermes Claude OAuth compatibility shim.

For non-Nix installs:

1. Pick your Hermes home, usually ``~/.hermes``.
2. Create an overrides dir at ``$HERMES_HOME/overrides``.
3. Copy this file to ``$HERMES_HOME/overrides/sitecustomize.py``.
4. Make sure Python imports that dir on Hermes startup, either by:
   - exporting ``PYTHONPATH="$HERMES_HOME/overrides:$PYTHONPATH"``, or
   - dropping a ``.pth`` file into the Hermes venv's site-packages that
     contains the single line ``$HERMES_HOME/overrides``.
5. Start Hermes normally. This module auto-runs on interpreter startup.

This file exists because Anthropic's Claude-Code-style OAuth path rejects a
few Hermes-native prompt and tool literals with the misleading HTTP 400
"You're out of extra usage" error. The shim rewrites only the literals that
were reproduced on the live OAuth path and maps Anthropic-facing aliases back
to Hermes's real local tool names.
"""

from __future__ import annotations


_TOOL_ALIASES = {
    "session_search": "history_search",
    "skills_list": "skills_catalog",
}

_REVERSE_TOOL_ALIASES = {value: key for key, value in _TOOL_ALIASES.items()}


def _rewrite_prompt_text(text: str) -> str:
    replacements = (
        (
            "use session_search to recall those from past transcripts.",
            "use session_search to look up past transcripts.",
        ),
        (
            "use session_search to recall it before asking them to repeat themselves.",
            "use session_search to look it up before asking them to repeat themselves.",
        ),
        (
            "skill with skill_manage so you can reuse it next time.",
            "skill with skill_manage.",
        ),
        (
            "skill_manage(action='patch')",
            "skill_manage",
        ),
        (
            "If a skill has issues, fix it with skill_manage(action='patch').",
            "If a skill has issues, fix it with skill_manage.",
        ),
    )

    for old, new in replacements:
        text = text.replace(old, new)

    for old, new in _TOOL_ALIASES.items():
        text = text.replace(old, new)
    return text


def _alias_tool_name(name: str) -> str:
    return _TOOL_ALIASES.get(name, name)


def _unalias_tool_name(name: str) -> str:
    return _REVERSE_TOOL_ALIASES.get(name, name)


def _apply() -> None:
    try:
        import agent.prompt_builder as prompt_builder
        import agent.anthropic_adapter as anthropic_adapter
    except Exception:
        return

    if getattr(prompt_builder, "_pix_claude_oauth_prompt_patch_applied", False):
        return

    prompt_builder.MEMORY_GUIDANCE = _rewrite_prompt_text(prompt_builder.MEMORY_GUIDANCE)
    prompt_builder.SESSION_SEARCH_GUIDANCE = _rewrite_prompt_text(prompt_builder.SESSION_SEARCH_GUIDANCE)
    prompt_builder.SKILLS_GUIDANCE = _rewrite_prompt_text(prompt_builder.SKILLS_GUIDANCE)

    original_build_skills_system_prompt = prompt_builder.build_skills_system_prompt

    def wrapped_build_skills_system_prompt(*args, **kwargs):
        result = original_build_skills_system_prompt(*args, **kwargs)
        if isinstance(result, str):
            return _rewrite_prompt_text(result)
        return result

    original_build_anthropic_kwargs = anthropic_adapter.build_anthropic_kwargs

    def wrapped_build_anthropic_kwargs(*args, **kwargs):
        result = original_build_anthropic_kwargs(*args, **kwargs)
        if not kwargs.get("is_oauth", False):
            return result

        system = result.get("system")
        if isinstance(system, list):
            for block in system:
                if isinstance(block, dict) and block.get("type") == "text":
                    text = block.get("text")
                    if isinstance(text, str):
                        block["text"] = _rewrite_prompt_text(text)
        elif isinstance(system, str):
            result["system"] = _rewrite_prompt_text(system)

        for tool in result.get("tools", []):
            name = tool.get("name")
            if isinstance(name, str):
                tool["name"] = _alias_tool_name(name)

        tool_choice = result.get("tool_choice")
        if (
            isinstance(tool_choice, dict)
            and tool_choice.get("type") == "tool"
            and isinstance(tool_choice.get("name"), str)
        ):
            tool_choice["name"] = _alias_tool_name(tool_choice["name"])

        for message in result.get("messages", []):
            content = message.get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                if block.get("type") != "tool_use":
                    continue
                name = block.get("name")
                if isinstance(name, str):
                    block["name"] = _alias_tool_name(name)

        return result

    original_normalize_anthropic_response_v2 = anthropic_adapter.normalize_anthropic_response_v2

    def wrapped_normalize_anthropic_response_v2(*args, **kwargs):
        result = original_normalize_anthropic_response_v2(*args, **kwargs)
        tool_calls = getattr(result, "tool_calls", None)
        if tool_calls:
            for tool_call in tool_calls:
                name = getattr(tool_call, "name", None)
                if isinstance(name, str):
                    tool_call.name = _unalias_tool_name(name)
        return result

    prompt_builder.build_skills_system_prompt = wrapped_build_skills_system_prompt
    anthropic_adapter.build_anthropic_kwargs = wrapped_build_anthropic_kwargs
    anthropic_adapter.normalize_anthropic_response_v2 = wrapped_normalize_anthropic_response_v2
    prompt_builder._pix_claude_oauth_prompt_patch_applied = True
    anthropic_adapter._MCP_TOOL_PREFIX = ""


_apply()
