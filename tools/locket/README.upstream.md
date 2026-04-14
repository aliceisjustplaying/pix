# locket

Cooperative locks for shared notes, plans, and other path-shaped resources.

```sh
locket lock ~/notes/today.md -m "editing weekly summary"
# ... read and edit the resource ...
locket unlock /Users/me/notes/today.md 1a2b3c4d
```

`locket` locks canonical path names. The target path does not need to exist yet, so it works for both real files and conceptual resources that your team agrees to represent with a path.

Especially useful in agent workflows where multiple shells or tools need a shared convention for who is actively working on a resource. Think of it as lockout-tagout for shared files: visible, conventional, not a security boundary.

## Commands

| Command | Description |
|---------|-------------|
| `lock` | Acquire a lock (waits until available) |
| `unlock` | Release a lock using its token |
| `status` | Inspect current lock state |
| `with-lock` | Run a command while holding a lock |

## Usage

Acquire a lock and unlock it later:

```sh
locket lock path/to/file
# => Locked, when done run: locket unlock /absolute/path/to/file 1a2b3c4d

locket unlock /absolute/path/to/file 1a2b3c4d
```

Tag the lock with a message:

```sh
locket lock path/to/file -m "updating project notes"
```

Stop waiting after a fixed amount of time:

```sh
locket lock path/to/file -t 30
```

Run a command while holding the lock:

```sh
locket with-lock path/to/file -- make format
```

Inspect lock state:

```sh
locket status path/to/file
# => Locked: /absolute/path/to/file (3s ago, updating project notes, user@host pid=12345)
```

Use a path as a coordination point, even if no file is involved:

```sh
locket lock db-migration
```

The parent directory must exist, because `locket` stores a sibling `<path>.locket/` directory next to the target path.

## Install

Requires Python 3.10+.

```sh
ln -s "$(pwd)/locket.py" /usr/local/bin/locket
```

Or run it directly:

```sh
./locket.py lock path/to/file
```

## How it works

For a target path like `notes.txt`, `locket` uses a sibling directory:

```text
notes.txt.locket/
  token   # opaque unlock secret
  tag     # JSON: timestamp, message, pid, user, host
```

All paths are resolved to their absolute, canonical form (including symlinks) before computing the lock directory. That means `./notes.txt`, `notes.txt`, and `/full/path/to/notes.txt` all refer to the same lock.

Lock acquisition creates the directory atomically via rename. Unlock renames it away before removing it. The intended lifecycle is lock, read, edit, unlock - always lock *before* reading.

`locket lock` prints the unlock command (including the token) to stdout. Errors and status messages go to stderr, so scripts can capture the token cleanly.

## Agents

If you want to teach agents how to use `locket`, see [AGENTS.md](AGENTS.md). It contains a reusable instruction block covering canonical path locks, coordination points, `with-lock`, and the `--absolute-zero` caveat.

## Notes

- Locks are advisory. They only help if every editor or script agrees to use `locket`.
- `locket lock` waits until available unless `-t` / `--timeout` is set.
- If you interrupt while waiting, no lock is taken.
- If you lose the token, you cannot unlock through the normal CLI flow.
- The `.locket` directory is chmodded to `555` by default. Pass `--absolute-zero` for `000` instead. Both are friction, not security.
- A missing `token` file in a `.locket` directory is treated as corruption, not a reclaimable lock. Use `locket status` to inspect.
- This is for coordination, not access control or distributed consensus.
