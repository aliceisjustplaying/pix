{ buildGo126Module, brotli, fetchFromGitHub, gzip, python3 }:

buildGo126Module rec {
  pname = "vibes";
  version = "0.0.0-unstable-2026-05-03";

  src = fetchFromGitHub {
    owner = "rcarmo";
    repo = "vibes";
    rev = "dfa6a09433775caa3661aae3a3562f6903462e68";
    hash = "sha256-tpCzIzQzAUxW6JvG00JJJrm+VRDHHl1y3WI5v3k1HuE=";
  };

  vendorHash = "sha256-nCTrtI+bzfTJtGtP/6sBG3ci9/5V4sHacc3IWFtWOlc=";
  subPackages = [ "cmd/vibes" ];
  nativeBuildInputs = [ brotli gzip python3 ];

  postConfigure = ''
    chmod u+w vendor/github.com/keepmind9/acp-sdk-go/schema/types.go
    python - <<'PY'
from pathlib import Path

path = Path("vendor/github.com/keepmind9/acp-sdk-go/schema/types.go")
text = path.read_text()
old = """func (u *AuthMethod) UnmarshalJSON(data []byte) error {
\tvar raw map[string]json.RawMessage
\tif err := json.Unmarshal(data, &raw); err != nil {
\t\treturn err
\t}
\tdiscrim, ok := raw["type"]
\tif !ok {
\t\treturn fmt.Errorf("missing type field")
\t}
\tvar dv string
"""
new = """func (u *AuthMethod) UnmarshalJSON(data []byte) error {
\tvar raw map[string]json.RawMessage
\tif err := json.Unmarshal(data, &raw); err != nil {
\t\treturn err
\t}
\tdiscrim, ok := raw["type"]
\tif !ok {
\t\tu.Type = TypeAuthMethodKindAuthMethodAgent
\t\tu.AuthMethodAgent = &AuthMethodAgent{}
\t\treturn json.Unmarshal(data, u.AuthMethodAgent)
\t}
\tvar dv string
"""
if old not in text:
    raise SystemExit("AuthMethod missing-type block not found")
path.write_text(text.replace(old, new, 1))
PY

    find static -type f \( -name '*.js' -o -name '*.css' -o -name '*.html' -o -name '*.json' -o -name '*.svg' \) -print0 |
      while IFS= read -r -d "" file; do
        gzip -k -n -9 "$file"
        brotli -k -f -q 11 "$file"
      done

    python - <<'PY'
from pathlib import Path

path = Path("internal/app/app.go")
text = path.read_text()
text = text.replace(
    '"fmt"\n\t"log/slog"\n\t"net/http"\n\t"os"\n',
    '"fmt"\n\t"io"\n\t"log/slog"\n\t"mime"\n\t"net/http"\n\t"os"\n\t"path"\n\t"strings"\n',
    1,
)
text = text.replace(
    'fileServer := http.FileServer(staticFS)\n\tr.Handle("/static/*", http.StripPrefix("/static/", fileServer))',
    'r.Handle("/static/*", http.StripPrefix("/static/", compressedFileServer(staticFS)))',
    1,
)
marker = '// serveStaticFile returns a handler that serves a single file from the embedded FS.\n'
insert = r"""func compressedFileServer(fs http.FileSystem) http.Handler {
	fileServer := http.FileServer(fs)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			fileServer.ServeHTTP(w, r)
			return
		}

		name := strings.TrimPrefix(path.Clean("/"+r.URL.Path), "/")
		for _, candidate := range []struct {
			token string
			ext   string
		}{
			{token: "br", ext: ".br"},
			{token: "gzip", ext: ".gz"},
		} {
			if !acceptsEncoding(r.Header.Get("Accept-Encoding"), candidate.token) {
				continue
			}
			f, err := fs.Open(name + candidate.ext)
			if err != nil {
				continue
			}
			defer f.Close()
			stat, err := f.Stat()
			if err != nil {
				continue
			}

			if contentType := mime.TypeByExtension(path.Ext(name)); contentType != "" {
				w.Header().Set("Content-Type", contentType)
			}
			w.Header().Set("Content-Encoding", candidate.token)
			w.Header().Set("Vary", "Accept-Encoding")
			w.Header().Set("Content-Length", fmt.Sprint(stat.Size()))
			if r.Method == http.MethodHead {
				return
			}
			io.Copy(w, f)
			return
		}

		fileServer.ServeHTTP(w, r)
	})
}

func acceptsEncoding(header, token string) bool {
	for part := range strings.SplitSeq(header, ",") {
		value := strings.TrimSpace(strings.SplitN(part, ";", 2)[0])
		if strings.EqualFold(value, token) {
			return true
		}
	}
	return false
}

"""
if marker not in text:
    raise SystemExit("static file marker not found")
path.write_text(text.replace(marker, insert + marker, 1))
PY

    python - <<'PY'
from pathlib import Path

path = Path("internal/agent/acp/client.go")
text = path.read_text()
text = text.replace(
    """\t// Per-turn state for tool call tracking and content classification.
\tturnMu    sync.Mutex
\ttoolCalls map[string]*schema.ToolCall
""",
    """\t// Per-turn state for tool call tracking and content classification.
\tturnMu         sync.Mutex
\ttoolCalls      map[string]*schema.ToolCall
\tresponseBuffer strings.Builder
""",
    1,
)
text = text.replace(
    """func (p *Provider) Events() <-chan agent.Event { return p.events }

func (p *Provider) Status() agent.ProviderStatus {
""",
    """func (p *Provider) Events() <-chan agent.Event { return p.events }

func (p *Provider) LastResponseContent() string {
\tp.turnMu.Lock()
\tdefer p.turnMu.Unlock()
\treturn p.responseBuffer.String()
}

func (p *Provider) Status() agent.ProviderStatus {
""",
    1,
)
text = text.replace(
    """\t// Reset per-turn tool call state
\tp.turnMu.Lock()
\tp.toolCalls = make(map[string]*schema.ToolCall)
\tp.turnMu.Unlock()
""",
    """\t// Reset per-turn state.
\tp.turnMu.Lock()
\tp.toolCalls = make(map[string]*schema.ToolCall)
\tp.responseBuffer.Reset()
\tp.turnMu.Unlock()
""",
    1,
)
text = text.replace(
    """\tresp, err := p.conn.Prompt(&schema.PromptRequest{
\t\tSessionId: &sessID,
\t\tPrompt:    []*schema.ContentBlock{&block},
\t})
""",
    """\t_, err := p.conn.Prompt(&schema.PromptRequest{
\t\tSessionId: &sessID,
\t\tPrompt:    []*schema.ContentBlock{&block},
\t})
""",
    1,
)
text = text.replace(
    """\tp.events <- agent.Event{Type: "response", Data: resp}
""",
    """\tp.events <- agent.Event{Type: "status", Data: map[string]string{"type": "done"}}
""",
    1,
)
text = text.replace(
    """\tcase schema.SessionUpdateKindAgentMessageChunk:
\t\tc.provider.events <- agent.Event{Type: "draft", Data: notif.Update.AgentMessageChunk}
""",
    """\tcase schema.SessionUpdateKindAgentMessageChunk:
\t\tchunk := notif.Update.AgentMessageChunk
\t\tif chunk != nil && chunk.Content != nil && chunk.Content.Text != nil {
\t\t\ttext := chunk.Content.Text.Text
\t\t\tc.provider.turnMu.Lock()
\t\t\tc.provider.responseBuffer.WriteString(text)
\t\t\tc.provider.turnMu.Unlock()
\t\t\tc.provider.events <- agent.Event{Type: "draft", Data: map[string]interface{}{
\t\t\t\t"text":    text,
\t\t\t\t"content": chunk.Content,
\t\t\t}}
\t\t} else {
\t\t\tc.provider.events <- agent.Event{Type: "draft", Data: chunk}
\t\t}
""",
    1,
)
path.write_text(text)

path = Path("internal/routes/agents.go")
text = path.read_text()
text = text.replace(
    """\t\"net/http\"\n\t\"strings\"\n\t\"time\"\n""",
    """\t\"net/http\"\n\t\"time\"\n""",
    1,
)
text = text.replace(
    """		// Broadcast user message via SSE
		broker.Broadcast(sse.Event{Type: "new_post", Data: map[string]interface{}{
			"id":      postID,
			"content": req.Content,
			"type":    "user_message",
		}})
""",
    """		// Broadcast the same post shape returned by /timeline.
		if post, err := database.GetInteraction(postID); err == nil {
			broker.Broadcast(sse.Event{Type: "new_post", Data: post})
		} else {
			broker.Broadcast(sse.Event{Type: "new_post", Data: map[string]interface{}{
				"id":   postID,
				"data": interaction,
				"type": interaction.Type,
			}})
		}
""",
    1,
)
text = text.replace(
    """		// Launch agent prompt in background, collect streamed content
		promptCtx := context.Background()
		go func() {
			// Collect streamed draft text during the turn (fixes #1)
			var collectedContent strings.Builder
			collectDone := make(chan struct{})

			go func() {
				defer close(collectDone)
				for event := range provider.Events() {
					// Accumulate draft text
					if event.Type == "draft" {
						if m, ok := event.Data.(map[string]string); ok {
							if text, exists := m["text"]; exists {
								collectedContent.WriteString(text)
							}
						}
					}
					// All events still forwarded via central event loop in app.go
				}
			}()

			err := provider.Prompt(promptCtx, req.Content, threadID)
			<-collectDone
""",
    """		// Launch agent prompt in background.
		promptCtx := context.Background()
		go func() {
			err := provider.Prompt(promptCtx, req.Content, threadID)
""",
    1,
)
text = text.replace(
    """			// Store final agent response with collected content
			finalContent := collectedContent.String()
			if finalContent == "" {
				finalContent = "(no content)"
			}
""",
    """			// Store final agent response with collected content
			finalContent := ""
			if contentProvider, ok := provider.(interface{ LastResponseContent() string }); ok {
				finalContent = contentProvider.LastResponseContent()
			}
			if finalContent == "" {
				finalContent = "(no content)"
			}
""",
    1,
)
text = text.replace(
    """			respData, _ := db.MarshalInteraction(agentData)
			respID, _ := database.InsertInteraction(respData)

			broker.Broadcast(sse.Event{Type: "agent_response", Data: map[string]interface{}{
				"id":        respID,
				"thread_id": threadID,
				"agent_id":  provider.ID(),
				"content":   finalContent,
			}})
""",
    """			respData, _ := db.MarshalInteraction(agentData)
			respID, err := database.InsertInteraction(respData)
			if err != nil {
				broker.Broadcast(sse.Event{Type: "agent_error", Data: map[string]string{"error": err.Error()}})
				return
			}

			if post, err := database.GetInteraction(respID); err == nil {
				broker.Broadcast(sse.Event{Type: "agent_response", Data: post})
			} else {
				broker.Broadcast(sse.Event{Type: "agent_response", Data: map[string]interface{}{
					"id":        respID,
					"thread_id": threadID,
					"agent_id":  provider.ID(),
					"data":      agentData,
					"type":      agentData.Type,
				}})
			}
""",
    1,
)
path.write_text(text)
PY
  '';

  ldflags = [
    "-s"
    "-w"
  ];
}
