{ buildGo126Module, fetchFromGitHub }:

buildGo126Module rec {
  pname = "vibes-go";
  version = "0.0.0-unstable-2026-04-08";

  src = fetchFromGitHub {
    owner = "rcarmo";
    repo = "vibes";
    rev = "3437f1a59088ac7a4660ec2ca9890d98279420f6";
    hash = "sha256-bLYguwZnLpqEpep+QkkddYNq/FjwpOxUKkbKIBjBk/k=";
  };

  vendorHash = "sha256-n+W3fhKjc3dIPnSNSs4KXLJ6/VSxB1G6PgwuGKpu13Y=";
  subPackages = [ "cmd/vibes" ];

  postPatch = ''
    old_import=$(cat <<'EOF'
import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
EOF
)
    new_import=$(cat <<'EOF'
import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
EOF
)
    substituteInPlace internal/app/app.go --replace-fail "$old_import" "$new_import"

    old_routes=$(cat <<'EOF'
	// TODO: mount route groups
	// r.Route("/timeline", routes.Timeline(app))
	// r.Route("/media", routes.Media(app))
	// r.Route("/workspace", routes.Workspace(app))
	// r.Route("/agent", routes.Agents(app))
	// r.Get("/sse/stream", sse.Handler(app))
EOF
)
    new_routes=$(cat <<'EOF'
	apiProxyURL, err := url.Parse("http://127.0.0.1:8081")
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
EOF
)
    substituteInPlace internal/app/app.go --replace-fail "$old_routes" "$new_routes"
  '';

  ldflags = [
    "-s"
    "-w"
  ];
}
