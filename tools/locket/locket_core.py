from __future__ import annotations

import errno
import getpass
import json
import os
import secrets
import shutil
import socket
import stat
import time
from collections.abc import Callable
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path


EXIT_USAGE = 1
EXIT_TIMEOUT = 2
EXIT_BAD_LOCK = 3
EXIT_IO = 4

TOKENFILE_NAME = "token"
TAGFILE_NAME = "tag"
POLL_SECONDS = 0.1
PRIVATE_LOCK_DIR_MODE = 0o700
DEFAULT_PUBLIC_LOCK_DIR_MODE = 0o555
ABSOLUTE_ZERO_LOCK_DIR_MODE = 0o000


class StatusKind(str, Enum):
    UNLOCKED = "unlocked"
    LOCKED = "locked"
    CORRUPT = "corrupt"


@dataclass(frozen=True)
class LockMetadata:
    locked_at: str
    message: str | None = None
    pid: int | None = None
    user: str | None = None
    host: str | None = None


@dataclass(frozen=True)
class LockHandle:
    path: Path
    token: str
    metadata: LockMetadata


@dataclass(frozen=True)
class LockStatus:
    kind: StatusKind
    path: Path
    metadata: LockMetadata | None = None
    detail: str | None = None


class LockError(Exception):
    def __init__(self, message: str, exit_code: int) -> None:
        super().__init__(message)
        self.message = message
        self.exit_code = exit_code


def resolve_path(raw: str) -> Path:
    try:
        return Path(raw).expanduser().resolve()
    except (RuntimeError, KeyError):
        raise LockError(
            f"Error: could not resolve home directory in path: {raw}",
            EXIT_USAGE,
        )


def locket_dir_for(path: Path) -> Path:
    return path.parent / f"{path.name}.locket"


def token_file_for(locket_dir: Path) -> Path:
    return locket_dir / TOKENFILE_NAME


def tag_file_for(locket_dir: Path) -> Path:
    return locket_dir / TAGFILE_NAME


def write_text(path: Path, text: str) -> None:
    with path.open("w", encoding="utf-8") as fh:
        fh.write(text)
        fh.flush()
        os.fsync(fh.fileno())


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _check_lock_integrity(locket_dir: Path, path: Path, *, check_contents: bool = False) -> None:
    """Raise LockError if the lock directory structure looks tampered with.

    When check_contents is True, also inspect files inside the lock directory.
    This requires the directory to be readable (call after opening permissions).
    """
    if locket_dir.is_symlink() or (locket_dir.exists() and not locket_dir.is_dir()):
        raise LockError(f"Error: corrupt lock directory for {path}", EXIT_BAD_LOCK)
    if check_contents:
        for child in (token_file_for(locket_dir), tag_file_for(locket_dir)):
            if child.is_symlink() or (child.exists() and not child.is_file()):
                raise LockError(f"Error: corrupt lock directory for {path}", EXIT_BAD_LOCK)


def read_token(path: Path) -> str | None:
    try:
        value = read_text(path).strip()
        return value or None
    except (FileNotFoundError, IsADirectoryError, PermissionError, UnicodeDecodeError):
        return None


def sync_dir(path: Path) -> None:
    fd = os.open(path, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def private_locket_dir(locket_dir: Path, phase: str) -> Path:
    return locket_dir.parent / f".{locket_dir.name}.{phase}.{secrets.token_hex(8)}"


def current_mode(path: Path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


def set_dir_mode(path: Path, mode: int) -> None:
    os.chmod(path, mode)


@contextmanager
def temporarily_open_public_lock(locket_dir: Path):
    try:
        original_mode = current_mode(locket_dir)
    except FileNotFoundError:
        yield False
        return
    except PermissionError as exc:
        raise LockError(
            f"Error: cannot read lock directory {locket_dir}: {exc}", EXIT_IO
        ) from exc

    changed = original_mode != PRIVATE_LOCK_DIR_MODE
    if changed:
        try:
            set_dir_mode(locket_dir, PRIVATE_LOCK_DIR_MODE)
        except PermissionError as exc:
            raise LockError(
                f"Error: cannot open lock directory {locket_dir}: {exc}", EXIT_IO
            ) from exc
    try:
        yield True
    finally:
        if changed:
            try:
                set_dir_mode(locket_dir, original_mode)
            except (FileNotFoundError, PermissionError):
                pass


def _session_leader_pid() -> int:
    """Return the session leader PID (typically the login shell).

    This gives a stable, meaningful PID that survives subshells and child
    processes.  Falls back to the current PID if getsid is unavailable.
    """
    try:
        return os.getsid(0)
    except OSError:
        return os.getpid()


def build_metadata(message: str | None) -> LockMetadata:
    try:
        user = getpass.getuser()
    except OSError:
        user = None
    try:
        host = socket.gethostname()
    except OSError:
        host = None
    return LockMetadata(
        locked_at=datetime.now(timezone.utc).isoformat(),
        message=message,
        pid=_session_leader_pid(),
        user=user,
        host=host,
    )


def write_metadata(locket_dir: Path, metadata: LockMetadata) -> None:
    payload = {"locked_at": metadata.locked_at}
    if metadata.message:
        payload["message"] = metadata.message
    if metadata.pid is not None:
        payload["pid"] = metadata.pid
    if metadata.user:
        payload["user"] = metadata.user
    if metadata.host:
        payload["host"] = metadata.host
    write_text(tag_file_for(locket_dir), json.dumps(payload, indent=2) + "\n")


def read_metadata(locket_dir: Path) -> LockMetadata | None:
    tag_path = tag_file_for(locket_dir)
    if not tag_path.exists():
        return None
    try:
        data = json.loads(read_text(tag_path))
    except (OSError, json.JSONDecodeError, UnicodeDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    locked_at = data.get("locked_at")
    if not isinstance(locked_at, str):
        return None
    message = data.get("message")
    pid = data.get("pid")
    user = data.get("user")
    host = data.get("host")
    return LockMetadata(
        locked_at=locked_at,
        message=message if isinstance(message, str) else None,
        pid=pid if isinstance(pid, int) else None,
        user=user if isinstance(user, str) else None,
        host=host if isinstance(host, str) else None,
    )


def format_metadata(metadata: LockMetadata) -> str:
    parts: list[str] = []
    try:
        dt = datetime.fromisoformat(metadata.locked_at)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        delta = datetime.now(timezone.utc) - dt
        seconds = max(0, int(delta.total_seconds()))
        if seconds < 60:
            parts.append(f"{seconds}s ago")
        elif seconds < 3600:
            parts.append(f"{seconds // 60}m ago")
        else:
            hours = seconds // 3600
            parts.append(f"{hours}h {(seconds % 3600) // 60}m ago")
    except (ValueError, TypeError):
        parts.append(metadata.locked_at)
    if metadata.message:
        parts.append(metadata.message)
    owner_parts = [part for part in (metadata.user, metadata.host) if part]
    if owner_parts:
        owner = "@".join(owner_parts)
        if metadata.pid is not None:
            owner = f"{owner} pid={metadata.pid}"
        parts.append(owner)
    elif metadata.pid is not None:
        parts.append(f"pid={metadata.pid}")
    return ", ".join(parts)


def _read_public_lock(path: Path) -> LockHandle | None:
    locket_dir = locket_dir_for(path)
    _check_lock_integrity(locket_dir, path)
    with temporarily_open_public_lock(locket_dir) as present:
        if not present:
            return None
        _check_lock_integrity(locket_dir, path, check_contents=True)
        token_path = token_file_for(locket_dir)
        try:
            token = read_token(token_path)
        except OSError as exc:
            raise LockError(f"Error: could not read lock for {path}: {exc}", EXIT_IO) from exc
        if token is None:
            if locket_dir.exists():
                raise LockError(f"Error: corrupt lock directory for {path}", EXIT_BAD_LOCK)
            return None
        metadata = read_metadata(locket_dir)
        if metadata is None:
            metadata = LockMetadata(locked_at="")
        return LockHandle(path=path, token=token, metadata=metadata)


def acquire(
    path: Path,
    timeout: float | None = None,
    message: str | None = None,
    on_wait: Callable[[], None] | None = None,
    public_lock_dir_mode: int = DEFAULT_PUBLIC_LOCK_DIR_MODE,
) -> LockHandle:
    if path.suffix.lower() == ".locket" or any(
        p.suffix.lower() == ".locket" for p in path.parents
    ):
        raise LockError(
            f"Error: refusing to lock {path} (.locket is a reserved suffix)",
            EXIT_USAGE,
        )
    if not path.parent.is_dir():
        if path.parent.exists():
            raise LockError(
                f"Error: parent path is not a directory: {path.parent}",
                EXIT_USAGE,
            )
        raise LockError(
            f"Error: parent directory does not exist: {path.parent}",
            EXIT_USAGE,
        )
    if timeout is not None and timeout < 0:
        raise LockError("Error: --timeout must be non-negative", EXIT_USAGE)

    locket_dir = locket_dir_for(path)
    _check_lock_integrity(locket_dir, path)
    token = secrets.token_hex(4)
    metadata = build_metadata(message)
    deadline = None if timeout is None else time.monotonic() + timeout
    reported_wait = False

    while True:
        staging_dir = private_locket_dir(locket_dir, "staging")
        try:
            staging_dir.mkdir(mode=PRIVATE_LOCK_DIR_MODE)
            sync_dir(staging_dir.parent)
            write_text(token_file_for(staging_dir), token + "\n")
            write_metadata(staging_dir, metadata)
            sync_dir(staging_dir)
            try:
                staging_dir.rename(locket_dir)
            except OSError as exc:
                lock_collision = exc.errno in (
                    errno.EEXIST,
                    errno.ENOTEMPTY,
                    errno.EACCES,
                    errno.EPERM,
                )
                if not lock_collision:
                    raise
                shutil.rmtree(staging_dir, ignore_errors=True)
                try:
                    current = _read_public_lock(path)
                except LockError as read_exc:
                    if read_exc.exit_code != EXIT_BAD_LOCK:
                        raise
                    if not locket_dir.exists() and not locket_dir.is_symlink():
                        continue
                    raise
                if current is None:
                    continue
                if on_wait is not None and not reported_wait:
                    on_wait()
                    reported_wait = True
                if deadline is not None and time.monotonic() >= deadline:
                    raise LockError(f"Timed out waiting for lock: {path}", EXIT_TIMEOUT)
                sleep_seconds = POLL_SECONDS
                if deadline is not None:
                    sleep_seconds = min(
                        sleep_seconds,
                        max(0.0, deadline - time.monotonic()),
                    )
                    if sleep_seconds <= 0:
                        raise LockError(f"Timed out waiting for lock: {path}", EXIT_TIMEOUT)
                time.sleep(sleep_seconds)
                continue
            try:
                set_dir_mode(locket_dir, public_lock_dir_mode)
                sync_dir(locket_dir.parent)
            except OSError:
                shutil.rmtree(locket_dir, ignore_errors=True)
                raise
            return LockHandle(path=path, token=token, metadata=metadata)
        except OSError as exc:
            shutil.rmtree(staging_dir, ignore_errors=True)
            raise LockError(f"Error: failed to lock {path}: {exc}", EXIT_IO) from exc


def release(path: Path, token: str) -> None:
    lock = _read_public_lock(path)
    if lock is None:
        raise LockError(f"Error: no active lock for {path}", EXIT_BAD_LOCK)
    if lock.token != token:
        raise LockError(f"Error: invalid lock token for {path}", EXIT_BAD_LOCK)

    locket_dir = locket_dir_for(path)
    retiring_dir = private_locket_dir(locket_dir, "retiring")
    try:
        with temporarily_open_public_lock(locket_dir) as present:
            if not present:
                raise LockError(f"Error: no active lock for {path}", EXIT_BAD_LOCK)
            locket_dir.rename(retiring_dir)
        sync_dir(retiring_dir.parent)
        shutil.rmtree(retiring_dir)
        sync_dir(retiring_dir.parent)
    except FileNotFoundError as exc:
        raise LockError(f"Error: no active lock for {path}", EXIT_BAD_LOCK) from exc
    except OSError as exc:
        raise LockError(f"Error: failed to unlock {path}: {exc}", EXIT_IO) from exc


def status(path: Path) -> LockStatus:
    locket_dir = locket_dir_for(path)
    if not locket_dir.exists() and not locket_dir.is_symlink():
        return LockStatus(kind=StatusKind.UNLOCKED, path=path)
    if locket_dir.is_symlink() or not locket_dir.is_dir():
        return LockStatus(
            kind=StatusKind.CORRUPT,
            path=path,
            detail="lock path is not a directory",
        )
    try:
        lock = _read_public_lock(path)
    except LockError as exc:
        if exc.exit_code == EXIT_BAD_LOCK and not locket_dir.exists():
            return LockStatus(kind=StatusKind.UNLOCKED, path=path)
        if exc.exit_code == EXIT_BAD_LOCK:
            return LockStatus(
                kind=StatusKind.CORRUPT,
                path=path,
                detail="corrupt lock contents",
            )
        raise
    if lock is None:
        return LockStatus(kind=StatusKind.UNLOCKED, path=path)
    return LockStatus(kind=StatusKind.LOCKED, path=path, metadata=lock.metadata)
