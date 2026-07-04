{ ... }:
{
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 3098;
    openFirewall = false;

    environment = {
      WEBUI_URL = "https://openwebui.mosphere.at";
      RAG_EMBEDDING_MODEL = "";
    };
  };

  # Public ingress is managed by the Cloudflare tunnel remote config:
  # openwebui.mosphere.at -> http://127.0.0.1:3098.
}
