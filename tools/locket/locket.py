#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shlex
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from locket_core import (
    ABSOLUTE_ZERO_LOCK_DIR_MODE,
    DEFAULT_PUBLIC_LOCK_DIR_MODE,
    EXIT_BAD_LOCK,
    EXIT_IO,
    LockError,
    StatusKind,
    acquire,
    format_metadata,
    release,
    resolve_path,
    status,
)


def err(message: str) -> None:
    print(message, file=sys.stderr)


def format_unlock_command(path: str, token: str) -> str:
    return f"locket unlock {shlex.quote(path)} {shlex.quote(token)}"


def selected_public_lock_mode(args: argparse.Namespace) -> int:
    if getattr(args, "absolute_zero", False):
        return ABSOLUTE_ZERO_LOCK_DIR_MODE
    return DEFAULT_PUBLIC_LOCK_DIR_MODE


def cmd_lock(args: argparse.Namespace) -> int:
    path = resolve_path(args.path)
    try:
        handle = acquire(
            path,
            timeout=args.timeout,
            message=getattr(args, "message", None),
            on_wait=lambda: err(f"Waiting for lock: {path}"),
            public_lock_dir_mode=selected_public_lock_mode(args),
        )
    except KeyboardInterrupt:
        err(f"Interrupted while waiting for lock: {path}")
        return 130
    except LockError as exc:
        err(exc.message)
        return exc.exit_code

    print(f"Locked, when done run: {format_unlock_command(str(handle.path), handle.token)}")
    return 0


def cmd_unlock(args: argparse.Namespace) -> int:
    path = resolve_path(args.path)
    try:
        release(path, args.token)
    except LockError as exc:
        err(exc.message)
        return exc.exit_code
    err(f"Unlocked: {path}")
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    path = resolve_path(args.path)
    try:
        result = status(path)
    except LockError as exc:
        err(exc.message)
        return exc.exit_code

    if result.kind is StatusKind.UNLOCKED:
        print(f"Unlocked: {path}")
        return 0
    if result.kind is StatusKind.CORRUPT:
        detail = result.detail or "invalid lock contents"
        print(f"Corrupt lock directory ({detail}): {path}")
        return EXIT_BAD_LOCK
    if result.metadata and result.metadata.locked_at:
        print(f"Locked: {path} ({format_metadata(result.metadata)})")
    else:
        print(f"Locked: {path}")
    return 0


def cmd_with_lock(args: argparse.Namespace) -> int:
    path = resolve_path(args.path)
    command = list(args.exec_argv)
    if command and command[0] == "--":
        command = command[1:]
    try:
        handle = acquire(
            path,
            timeout=args.timeout,
            message=args.message,
            on_wait=lambda: err(f"Waiting for lock: {path}"),
            public_lock_dir_mode=selected_public_lock_mode(args),
        )
    except KeyboardInterrupt:
        err(f"Interrupted while waiting for lock: {path}")
        return 130
    except LockError as exc:
        err(exc.message)
        return exc.exit_code

    exit_code = 0
    try:
        completed = subprocess.run(command)
        exit_code = completed.returncode
        if exit_code < 0:
            exit_code = 128 + abs(exit_code)
    except FileNotFoundError:
        err(f"Error: command not found: {command[0]}")
        exit_code = EXIT_IO
    except PermissionError:
        err(f"Error: permission denied: {command[0]}")
        exit_code = EXIT_IO
    except NotADirectoryError:
        err(f"Error: not a directory in command path: {command[0]}")
        exit_code = EXIT_IO
    except OSError as exc:
        err(f"Error: could not execute {command[0]}: {exc}")
        exit_code = EXIT_IO
    finally:
        try:
            release(path, handle.token)
        except LockError as exc:
            err(exc.message)
            exit_code = exc.exit_code
    return exit_code


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="locket",
        description="Block until a file lock is available, then unlock it later with the matching token.",
        epilog=(
            "Examples:\n"
            "  locket lock notes.txt\n"
            '  locket lock notes.txt -m "editing weekly summary"\n'
            "  locket lock notes.txt --timeout 30\n"
            "  locket unlock notes.txt <token>\n"
            "  locket status notes.txt\n"
            "  locket with-lock notes.txt -- make format\n\n"
            "After 'locket lock', read and edit the original file directly."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    lock_parser = subparsers.add_parser(
        "lock",
        help="wait until a file lock is available, then acquire it",
        description="Block until PATH can be locked. Prints the unlock command and lock token.",
    )
    lock_parser.add_argument("path", help="file to lock before editing")
    lock_parser.add_argument("-m", "--message", help="tag the lock with a message")
    lock_parser.add_argument(
        "-t",
        "--timeout",
        type=float,
        help="stop waiting after SECONDS instead of blocking forever",
    )
    lock_parser.add_argument(
        "--absolute-zero",
        action="store_true",
        help="chmod the public lock directory to 000 instead of the default 555",
    )
    lock_parser.set_defaults(func=cmd_lock)

    unlock_parser = subparsers.add_parser(
        "unlock",
        help="release a file lock using its token",
        description="Release the lock for PATH if TOKEN matches the current lock.",
    )
    unlock_parser.add_argument("path", help="file to unlock")
    unlock_parser.add_argument("token", help="token returned by 'locket lock'")
    unlock_parser.set_defaults(func=cmd_unlock)

    status_parser = subparsers.add_parser(
        "status",
        help="check whether a file is locked",
        description="Report whether PATH is currently locked, unlocked, or corrupt.",
    )
    status_parser.add_argument("path", help="file to check")
    status_parser.set_defaults(func=cmd_status)

    with_lock_parser = subparsers.add_parser(
        "with-lock",
        help="run a command while holding the lock",
        description="Acquire the lock for PATH, run COMMAND, then release the lock.",
    )
    with_lock_parser.add_argument("path", help="file to lock before running the command")
    with_lock_parser.add_argument("-m", "--message", help="tag the lock with a message")
    with_lock_parser.add_argument(
        "-t",
        "--timeout",
        type=float,
        help="stop waiting after SECONDS instead of blocking forever",
    )
    with_lock_parser.add_argument(
        "--absolute-zero",
        action="store_true",
        help="chmod the public lock directory to 000 instead of the default 555",
    )
    with_lock_parser.add_argument(
        "exec_argv",
        nargs=argparse.REMAINDER,
        metavar="COMMAND",
        help="command to run after --",
    )
    with_lock_parser.set_defaults(func=cmd_with_lock)

    return parser


def main() -> int:
    parser = build_parser()
    if len(sys.argv) == 1:
        parser.print_help()
        return 0
    args = parser.parse_args()
    if args.subcommand == "with-lock":
        command = list(args.exec_argv)
        if command and command[0] == "--":
            command = command[1:]
        if not command:
            if "--" in sys.argv[2:]:
                parser.error("with-lock requires a path before -- and a command after it")
            parser.error("with-lock requires a command after --")
        args.exec_argv = command
    if getattr(args, "exec_argv", None) == []:
        parser.error("with-lock requires a command after --")
    try:
        return args.func(args)
    except LockError as exc:
        err(exc.message)
        return exc.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
