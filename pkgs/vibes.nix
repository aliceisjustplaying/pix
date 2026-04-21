{ lib, fetchFromGitHub, python3Packages }:

python3Packages.buildPythonApplication rec {
  pname = "vibes";
  version = "0.6.12";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "rcarmo";
    repo = "vibes";
    rev = "v${version}";
    hash = "sha256-D4QhE7xoCoCr3n6ax0Cw5xArhQ4IA+yJhV7QvxXUvjE=";
  };

  postPatch = ''
    python - <<'PY'
from pathlib import Path


def replace_once(path_str: str, old: str, new: str) -> None:
    path = Path(path_str)
    text = path.read_text()
    if old not in text:
        raise SystemExit(f"pattern not found in {path}")
    path.write_text(text.replace(old, new, 1))


replace_once(
    "src/vibes/acp_client.py",
    """        self.pending_requests = {}  # request_id -> asyncio.Future
        self.request_callback = None  # Callback to notify UI of pending requests
        self.whitelist_checker = None  # Callback to check if request is whitelisted
""",
    """        self.pending_requests = {}  # request_id -> asyncio.Future
        self.request_callback = None  # Callback to notify UI of pending requests
        self.whitelist_checker = None  # Callback to check if request is whitelisted
        self.session_modes = None
        self.session_models = None
        self.session_config_options = []
        self.current_model_fallback = None
""",
)

replace_once(
    "src/vibes/acp_client.py",
    """    _state.pending_requests = {}
    _state.request_callback = None
    _state.whitelist_checker = None
""",
    """    _state.pending_requests = {}
    _state.request_callback = None
    _state.whitelist_checker = None
    _state.session_modes = None
    _state.session_models = None
    _state.session_config_options = []
    _state.current_model_fallback = None
""",
)

replace_once(
    "src/vibes/acp_client.py",
    """def get_state() -> _ACPState:
    \"\"\"Return the ACP state instance.\"\"\"
    return _state


def prompt_from_action(action_id: str, params: dict | None) -> Optional[str]:
""",
    """def get_state() -> _ACPState:
    \"\"\"Return the ACP state instance.\"\"\"
    return _state


def _cache_session_metadata(payload: dict | None) -> None:
    \"\"\"Capture ACP session metadata used by the model picker.\"\"\"
    if not isinstance(payload, dict):
        return

    modes = payload.get(\"modes\")
    if isinstance(modes, dict):
        _state.session_modes = modes

    models = payload.get(\"models\")
    if isinstance(models, dict):
        _state.session_models = models

    config_options = payload.get(\"configOptions\")
    if isinstance(config_options, list):
        _state.session_config_options = [item for item in config_options if isinstance(item, dict)]


def _get_session_select_option(config_id: str) -> dict | None:
    for option in _state.session_config_options:
        if str(option.get(\"id\") or \"\") == config_id and str(option.get(\"type\") or \"\") == \"select\":
            return option
    return None


def _get_select_values(option: dict | None) -> list[str]:
    values: list[str] = []
    if not isinstance(option, dict):
        return values
    for item in option.get(\"options\", []):
        if not isinstance(item, dict):
            continue
        value = str(item.get(\"value\") or \"\").strip()
        if value and value not in values:
            values.append(value)
    return values


def _get_current_model_value() -> str | None:
    if os.environ.get(\"VIBES_AVAILABLE_MODELS\", \"\").strip():
        return _state.current_model_fallback

    option = _get_session_select_option(\"model\")
    if option:
        value = str(option.get(\"currentValue\") or \"\").strip()
        if value:
            return value

    current_model_id = str(((_state.session_models or {}).get(\"currentModelId\")) or \"\").strip()
    if current_model_id:
        return current_model_id.split(\"/\", 1)[0].strip() or None

    return None


def _get_current_thinking_value() -> str | None:
    option = _get_session_select_option(\"reasoning_effort\")
    if option:
        value = str(option.get(\"currentValue\") or \"\").strip()
        if value:
            return value

    current_model_id = str(((_state.session_models or {}).get(\"currentModelId\")) or \"\").strip()
    if \"/\" in current_model_id:
        return current_model_id.split(\"/\", 1)[1].strip() or None
    return None


def _get_available_model_values() -> list[str]:
    env_list = os.environ.get(\"VIBES_AVAILABLE_MODELS\", \"\").strip()
    if env_list:
        return [m.strip() for m in env_list.split(\",\") if m.strip()]

    values = _get_select_values(_get_session_select_option(\"model\"))
    if values:
        return values

    models: list[str] = []
    for item in ((_state.session_models or {}).get(\"availableModels\") or []):
        if not isinstance(item, dict):
            continue
        model_id = str(item.get(\"modelId\") or \"\").strip()
        if not model_id:
            continue
        base_model = model_id.split(\"/\", 1)[0].strip()
        if base_model and base_model not in models:
            models.append(base_model)
    return models


def _get_available_thinking_values() -> list[str]:
    values = _get_select_values(_get_session_select_option(\"reasoning_effort\"))
    if values:
        return values

    levels: list[str] = []
    for item in ((_state.session_models or {}).get(\"availableModels\") or []):
        if not isinstance(item, dict):
            continue
        model_id = str(item.get(\"modelId\") or \"\").strip()
        if \"/\" not in model_id:
            continue
        level = model_id.split(\"/\", 1)[1].strip()
        if level and level not in levels:
            levels.append(level)
    return levels


def _supports_session_thinking() -> bool:
    return bool(_get_available_thinking_values())


async def get_session_model_state() -> dict:
    \"\"\"Return the current ACP model picker state using cached session metadata.\"\"\"
    if not _state.request_lock.locked() and not (_state.session_models or _state.session_config_options):
        try:
            await _ensure_agent()
        except Exception:
            logger.debug(\"Failed to ensure ACP agent before reading model state\", exc_info=True)

    return {
        \"current\": _get_current_model_value(),
        \"models\": _get_available_model_values(),
        \"thinking_level\": _get_current_thinking_value(),
        \"thinking_levels\": _get_available_thinking_values(),
        \"supports_thinking\": _supports_session_thinking(),
    }


async def set_session_config_option(config_id: str, value: str) -> dict:
    \"\"\"Update a session config option and return the refreshed model state.\"\"\"
    if _state.request_lock.locked():
        raise RuntimeError(\"Agent is busy\")

    async with _state.request_lock:
        await _ensure_agent()

        if not _state.session_id:
            raise RuntimeError(\"No active session\")

        try:
            result = await _send_request(\"session/set_config_option\", {
                \"sessionId\": _state.session_id,
                \"configId\": config_id,
                \"value\": value,
            })
            _cache_session_metadata(result)
        except _AgentError as exc:
            if exc.code == -32601 and config_id == \"model\":
                await _send_request(\"session/set_model\", {
                    \"sessionId\": _state.session_id,
                    \"modelId\": value,
                })
                _state.current_model_fallback = value
            else:
                raise

    return await get_session_model_state()


async def _apply_default_session_mode() -> None:
    mode = os.environ.get(\"VIBES_DEFAULT_MODE\", \"\").strip()
    if not mode or not _state.session_id:
        return
    try:
        await _send_request(\"session/set_mode\", {
            \"sessionId\": _state.session_id,
            \"modeId\": mode,
        })
    except _AgentError:
        logger.warning(\"Failed to apply VIBES_DEFAULT_MODE=%s\", mode, exc_info=True)


def prompt_from_action(action_id: str, params: dict | None) -> Optional[str]:
""",
)

replace_once(
    "src/vibes/acp_client.py",
    """                result = await _send_request(\"session/new\", {
                    \"cwd\": cwd,
                    \"mcpServers\": []
                })
                _state.session_id = result.get(\"sessionId\")
""",
    """                result = await _send_request(\"session/new\", {
                    \"cwd\": cwd,
                    \"mcpServers\": []
                })
                _cache_session_metadata(result)
                _state.session_id = result.get(\"sessionId\")
                await _apply_default_session_mode()
""",
)

replace_once(
    "src/vibes/acp_client.py",
    """        result = await _send_request(\"session/new\", {
            \"cwd\": cwd,
            \"mcpServers\": []
        })
        _state.session_id = result.get(\"sessionId\")
""",
    """        result = await _send_request(\"session/new\", {
            \"cwd\": cwd,
            \"mcpServers\": []
        })
        _cache_session_metadata(result)
        _state.session_id = result.get(\"sessionId\")
        await _apply_default_session_mode()
""",
)

replace_once(
    "src/vibes/acp_client.py",
    """        _state.agent_proc = None
        _state.agent_reader = None
        _state.agent_writer = None
        _state.session_id = None
""",
    """        _state.agent_proc = None
        _state.agent_reader = None
        _state.agent_writer = None
        _state.session_id = None
        _state.session_modes = None
        _state.session_models = None
        _state.session_config_options = []
        _state.current_model_fallback = None
""",
)

replace_once(
    "src/vibes/routes/agents.py",
    """    is_agent_running as is_acp_running,
    set_request_callback as set_acp_request_callback,
    set_whitelist_checker,
    respond_to_request as respond_to_acp_request,
    prompt_from_action,
""",
    """    is_agent_running as is_acp_running,
    set_request_callback as set_acp_request_callback,
    set_whitelist_checker,
    get_session_model_state as get_acp_session_model_state,
    respond_to_request as respond_to_acp_request,
    prompt_from_action,
""",
)

replace_once(
    "src/vibes/routes/agents.py",
    """async def get_agent_models(request: web.Request) -> web.Response:
    \"\"\"GET /agent/models — return available models and current selection.\"\"\"
    empty = {\"current\": None, \"models\": []}
    if not is_pi_running():
        return web.json_response(empty)
    try:
""",
    """async def get_agent_models(request: web.Request) -> web.Response:
    \"\"\"GET /agent/models — return available models and current selection.\"\"\"
    empty = {\"current\": None, \"models\": []}
    config = get_config()

    if config.default_agent.lower() != \"pi\":
        try:
            state = await get_acp_session_model_state()
            return web.json_response({
                \"current\": state.get(\"current\"),
                \"models\": state.get(\"models\", []),
                \"thinking_level\": state.get(\"thinking_level\"),
                \"supports_thinking\": state.get(\"supports_thinking\"),
            })
        except Exception:
            logger.debug(\"Failed to get ACP agent models\", exc_info=True)
            return web.json_response(empty)

    if not is_pi_running():
        return web.json_response(empty)
    try:
""",
)

replace_once(
    "src/vibes/slash_commands.py",
    """    if agent_mode != \"pi\":
        current = config.acp_agent
        if not args:
            return SlashCommandResult(
                status=\"success\",
                message=f\"Current ACP agent: `{current}`.\\n\\n\"
                \"Model selection requires restarting with a different ACP agent binary.\",
            )
        return SlashCommandResult(
            status=\"error\",
            message=\"Model selection is not supported for ACP agents. \"
            \"Set `VIBES_ACP_AGENT` and restart.\",
        )
""",
    """    if agent_mode != \"pi\":
        if not args:
            return await _show_acp_model_info()

        from .acp_client import get_session_model_state, set_session_config_option

        requested = args.strip()
        state = await get_session_model_state()
        models = state.get(\"models\") or []
        if models and requested not in models:
            return SlashCommandResult(
                status=\"error\",
                message=f\"Unknown model: {requested}. Available: {', '.join(models)}\",
            )
        try:
            updated = await set_session_config_option(\"model\", requested)
        except RuntimeError as e:
            return SlashCommandResult(status=\"error\", message=f\"Failed to set model: {e}\")

        resolved = updated.get(\"current\") or requested
        thinking_level = updated.get(\"thinking_level\")
        thinking_note = (
            f\" Thinking level: {thinking_level}.\"
            if updated.get(\"supports_thinking\") and thinking_level
            else \"\"
        )
        return SlashCommandResult(
            status=\"success\",
            message=f\"Model set to `{resolved}`.{thinking_note}\",
            model_label=resolved,
            thinking_level=thinking_level,
            supports_thinking=updated.get(\"supports_thinking\"),
        )
""",
)

replace_once(
    "src/vibes/slash_commands.py",
    """    if agent_mode != \"pi\":
        return SlashCommandResult(
            status=\"error\",
            message=\"Model cycling is not supported for ACP agents.\",
        )
""",
    """    if agent_mode != \"pi\":
        from .acp_client import get_session_model_state

        state = await get_session_model_state()
        models = state.get(\"models\") or []
        if len(models) < 2:
            return SlashCommandResult(
                status=\"error\",
                message=\"No models available to cycle through.\",
            )
        current = state.get(\"current\") or \"\"
        backwards = args.strip().lower() in {\"back\", \"prev\", \"previous\"}
        try:
            idx = models.index(current)
            next_model = models[(idx - 1 if backwards else idx + 1) % len(models)]
        except ValueError:
            next_model = models[-1] if backwards else models[0]
        return await _handle_model(next_model, agent_mode)
""",
)

replace_once(
    "src/vibes/slash_commands.py",
    """    # Delegate to the normal model setter
    return await _handle_model(next_model, agent_mode)


async def _show_pi_model_info(config) -> SlashCommandResult:
""",
    """    # Delegate to the normal model setter
    return await _handle_model(next_model, agent_mode)


async def _show_acp_model_info() -> SlashCommandResult:
    \"\"\"Show current ACP model and available choices.\"\"\"
    from .acp_client import get_session_model_state

    state = await get_session_model_state()
    current = state.get(\"current\") or \"(default)\"
    thinking_level = state.get(\"thinking_level\")
    models = state.get(\"models\") or []
    supports_thinking = bool(state.get(\"supports_thinking\"))

    lines = [f\"Current model: {current}\"]
    if supports_thinking:
        lines.append(f\"Thinking level: {thinking_level or 'default'}\")
    if models:
        lines.extend([\"\", \"Available models:\", \"\"])
        for name in models:
            if name == current:
                lines.append(f\"- `{name}` *(current)*\")
            else:
                lines.append(f\"- `{name}`\")
    lines.extend([\"\", \"Set with: `/model <model>`\"])
    return SlashCommandResult(status=\"success\", message=\"\\n\".join(lines))


async def _show_pi_model_info(config) -> SlashCommandResult:
""",
)

replace_once(
    "src/vibes/slash_commands.py",
    """    if agent_mode != \"pi\":
        return SlashCommandResult(
            status=\"error\",
            message=\"Thinking level configuration is not supported for ACP agents.\",
        )
""",
    """    if agent_mode != \"pi\":
        from .acp_client import get_session_model_state, set_session_config_option

        state = await get_session_model_state()
        levels = state.get(\"thinking_levels\") or []
        if not state.get(\"supports_thinking\") or not levels:
            return SlashCommandResult(
                status=\"error\",
                message=\"Thinking level configuration is not supported for this ACP agent.\",
            )

        if not args:
            current = state.get(\"thinking_level\") or levels[0]
            model = state.get(\"current\") or \"(default)\"
            return SlashCommandResult(
                status=\"success\",
                message=f\"Current model: {model}\\n\"
                f\"Current thinking level: {current}\\n\"
                f\"Available levels: {', '.join(levels)}\",
                model_label=state.get(\"current\"),
                thinking_level=current,
                supports_thinking=True,
            )

        level = args.strip().lower()
        if level not in levels:
            return SlashCommandResult(
                status=\"error\",
                message=f\"Unknown thinking level: {args}. Available: {', '.join(levels)}\",
            )
        try:
            updated = await set_session_config_option(\"reasoning_effort\", level)
        except RuntimeError as e:
            return SlashCommandResult(status=\"error\", message=f\"Failed to set thinking level: {e}\")
        return SlashCommandResult(
            status=\"success\",
            message=f\"Thinking level set to `{updated.get('thinking_level') or level}`.\",
            model_label=updated.get(\"current\"),
            thinking_level=updated.get(\"thinking_level\") or level,
            supports_thinking=True,
        )
""",
)

replace_once(
    "src/vibes/slash_commands.py",
    """async def _handle_cycle_thinking(agent_mode: str) -> SlashCommandResult:
    \"\"\"Cycle to the next thinking level.\"\"\"
    from .config import get_config

    config = get_config()
""",
    """async def _handle_cycle_thinking(agent_mode: str) -> SlashCommandResult:
    \"\"\"Cycle to the next thinking level.\"\"\"
    from .config import get_config

    if agent_mode != \"pi\":
        from .acp_client import get_session_model_state

        state = await get_session_model_state()
        levels = state.get(\"thinking_levels\") or []
        if not state.get(\"supports_thinking\") or not levels:
            return SlashCommandResult(
                status=\"error\",
                message=\"Thinking level configuration is not supported for this ACP agent.\",
            )
        current = (state.get(\"thinking_level\") or levels[0]).lower()
        try:
            idx = levels.index(current)
        except ValueError:
            idx = -1
        next_level = levels[(idx + 1) % len(levels)]
        return await _handle_thinking(next_level, agent_mode)

    config = get_config()
""",
)

replace_once(
    "src/vibes/slash_commands.py",
    """    else:
        lines.append(f\"ACP agent: `{config.acp_agent}`\")
""",
    """    else:
        from .acp_client import get_session_model_state

        state = await get_session_model_state()
        lines.append(f\"ACP agent: `{config.acp_agent}`\")
        if state.get(\"current\"):
            lines.append(f\"Model: `{state['current']}`\")
        if state.get(\"supports_thinking\"):
            lines.append(f\"Thinking level: `{state.get('thinking_level') or 'default'}`\")
""",
)

# Ensure os is importable so the env-var model-list fallback works.
replace_once(
    "src/vibes/acp_client.py",
    """import asyncio
import base64
""",
    """import asyncio
import base64
import os
""",
)

# Carry structured JSON-RPC error details through to callers so we can
# detect method-not-found and fall back to standard ACP methods.
replace_once(
    "src/vibes/acp_client.py",
    """class _ACPState:
    \"\"\"Encapsulated ACP client state.\"\"\"
""",
    """class _AgentError(RuntimeError):
    \"\"\"Raised when the ACP agent returns a JSON-RPC error response.\"\"\"

    def __init__(self, err) -> None:
        super().__init__(f\"Agent error: {err}\")
        self.code = err.get(\"code\") if isinstance(err, dict) else None


class _ACPState:
    \"\"\"Encapsulated ACP client state.\"\"\"
""",
)

replace_once(
    "src/vibes/acp_client.py",
    """                if \"error\" in response:
                    raise RuntimeError(f\"Agent error: {response['error']}\")
""",
    """                if \"error\" in response:
                    raise _AgentError(response['error'])
""",
)
PY
  '';

  build-system = with python3Packages; [
    setuptools
    wheel
  ];

  nativeBuildInputs = with python3Packages; [
    pythonRelaxDepsHook
  ];

  dependencies = with python3Packages; [
    aiohttp
    aiosqlite
    pillow
    python-dotenv
    watchfiles
  ];

  pythonRelaxDeps = [
    "aiosqlite"
    "pillow"
    "python-dotenv"
    "watchfiles"
  ];

  pythonImportsCheck = [ "vibes" ];

  meta = with lib; {
    description = "Mobile-friendly web UI for coding agents via ACP";
    homepage = "https://github.com/rcarmo/vibes";
    license = licenses.mit;
    mainProgram = "vibes";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
