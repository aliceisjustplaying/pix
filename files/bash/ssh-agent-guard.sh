# Drop an unreachable/hung ssh-agent socket so git's SSH commit-signing
# (gpg.format=ssh -> ssh-keygen -Y sign) doesn't block forever on it.
#
# tsshd injects SSH_AUTH_SOCK per session and forwards the client's agent.
# When that forwarded connection dies the socket file lingers but hangs on
# every query, which is what made `git commit` appear to freeze. ssh-add -l
# exits 0/1 when the agent is reachable (keys / no keys) and 2 — or 124 via
# timeout — when it is dead, so anything >=2 means "drop it".
if [ -n "$SSH_AUTH_SOCK" ]; then
  timeout 1 ssh-add -l >/dev/null 2>&1
  [ $? -ge 2 ] && unset SSH_AUTH_SOCK
fi
