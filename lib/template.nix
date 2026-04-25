# tmpl ./file.conf { foo = "bar"; }  →  file content with @foo@ → "bar".
# Keys must match Nix identifier syntax (letters, digits, underscores).
file: vars:
  builtins.replaceStrings
    (map (k: "@${k}@") (builtins.attrNames vars))
    (builtins.attrValues vars)
    (builtins.readFile file)
