# Hermes Gateway

The gateway is a NixOS-managed systemd service:

```sh
sudo systemctl restart hermes-gateway.service
```

The Home Manager `hermes gateway restart` wrapper runs that same systemd restart. Do not start a second gateway with `hermes gateway run --replace` during normal operations.

After a restart, verify the single live listener:

```sh
hermes-gateway-smoke
```

The unit owns the runtime environment directly:

- `HERMES_HOME=/workspace/.hermes`
- `PYTHONPATH=/workspace/.hermes/overrides`
- `VIRTUAL_ENV=/workspace/.hermes/venv`

Hermes code updates still refresh `/workspace/.hermes/venv`; Nix owns service lifecycle and the startup override path, but Hermes CLI updates and config mutations remain available.
