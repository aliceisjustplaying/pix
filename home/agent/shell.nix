{ ... }:

{
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      sync-nix = "rebuild";
      update-force = "update --force";
      rollback-force = "rollback --force";
      pix = "cd /workspace/src/pix";
      pclaw = "cd /workspace/src/piclaw-customizations";
      nm = "cd ~/newmem";
      nfur = "nfu && rebuild";
      c = "claude --dangerously-skip-permissions";
      c45 = "claude --dangerously-skip-permissions --model claude-opus-4-5";
      c46 = "claude --dangerously-skip-permissions --model 'claude-opus-4-6[1m]'";
      c47 = "claude --dangerously-skip-permissions --model claude-opus-4-7";
      cr = "claude --dangerously-skip-permissions --resume";
      c45r = "claude --dangerously-skip-permissions --model claude-opus-4-5 --resume";
      c46r = "claude --dangerously-skip-permissions --model 'claude-opus-4-6[1m]' --resume";
      c47r = "claude --dangerously-skip-permissions --model claude-opus-4-7 --resume";
      y = "codex --dangerously-bypass-approvals-and-sandbox";
      yr = "codex --dangerously-bypass-approvals-and-sandbox resume";
      ta = "tmux attach";
    };
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    escapeTime = 0;
    baseIndex = 1;
    extraConfig = builtins.readFile ../../files/tmux/tmux.conf;
  };
}
