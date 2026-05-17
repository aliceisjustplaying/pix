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
      tc = "cd /workspace/src/tapering-calculator";
      nm = "cd ~/newmem";
      nfur = "nfu && rebuild";
      h = "hermes";
      ht = "hermes --tui";
      c = "claude --dangerously-skip-permissions";
      c45 = "claude --dangerously-skip-permissions --model claude-opus-4-5";
      c46 = "claude --dangerously-skip-permissions --model 'claude-opus-4-6[1m]'";
      c47 = "claude --dangerously-skip-permissions --model claude-opus-4-7";
      c47m = "claude --dangerously-skip-permissions --model claude-opus-4-7 --effort max";
      cr = "claude --dangerously-skip-permissions --resume";
      c45r = "claude --dangerously-skip-permissions --model claude-opus-4-5 --resume";
      c46r = "claude --dangerously-skip-permissions --model 'claude-opus-4-6[1m]' --resume";
      c47r = "claude --dangerously-skip-permissions --model claude-opus-4-7 --resume";
      y = "codex --dangerously-bypass-approvals-and-sandbox";
      yr = "codex --dangerously-bypass-approvals-and-sandbox resume";
      ta = "tmux attach";
      za = "zellij attach";
    };
  };

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    escapeTime = 0;
    baseIndex = 1;
    extraConfig = builtins.readFile ../../files/tmux/tmux.conf;
  };
}
