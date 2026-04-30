{ buildGo126Module, fetchFromGitHub }:

buildGo126Module rec {
  pname = "vibes-go";
  version = "0.0.0-unstable-2026-04-30";

  src = fetchFromGitHub {
    owner = "rcarmo";
    repo = "vibes";
    rev = "3a9fbeabac13f1698e2e75173dc3634d0db74e16";
    hash = "sha256-YdoR9UuqicQ8mb0paAYcMKll6jfwH/OEN7UPKcp4IpM=";
  };

  vendorHash = "sha256-ESPc5SANLNPDvE8C6rMTdG5qFokW43wOJ/A1RXZlfuM=";
  subPackages = [ "cmd/vibes" ];

  postPatch = ''
    old_import=$(cat <<'EOF'
import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
EOF
)
    new_import=$(cat <<'EOF'
import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
EOF
)
    substituteInPlace internal/app/app.go --replace-fail "$old_import" "$new_import"

    old_routes=$(cat <<'EOF'
	app.Router = r
	return app, nil
EOF
)
    new_routes=$(cat <<'EOF'
	apiProxyURL, err := url.Parse("http://100.74.251.100:8081")
	if err != nil {
		return nil, fmt.Errorf("parse legacy API proxy URL: %w", err)
	}
	apiProxy := httputil.NewSingleHostReverseProxy(apiProxyURL)
	proxyHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		r.Host = apiProxyURL.Host
		apiProxy.ServeHTTP(w, r)
	})
	r.NotFound(proxyHandler.ServeHTTP)
	r.MethodNotAllowed(proxyHandler.ServeHTTP)

	app.Router = r
	return app, nil
EOF
)
    substituteInPlace internal/app/app.go --replace-fail "$old_routes" "$new_routes"
  '';

  ldflags = [
    "-s"
    "-w"
  ];
}
