{ lib, tmpl, proxyApiKey, proxyBaseUrl, proxyOpenAIBaseUrl }:

let
  titleEffort = effort:
    if effort == "xhigh" then "XHigh"
    else lib.toUpper (lib.substring 0 1 effort) + lib.substring 1 (-1) effort;

  openAIModels =
    let
      models = [ "gpt-5.4" "gpt-5.5" ];
      efforts = [ "none" "low" "medium" "high" "xhigh" ];
      speeds = [ "standard" "fast" ];
      modelFor = model: effort:
        if effort == "none" then model else "${model}(${effort})";
      mkModel = model: effort: speed: {
        model = modelFor model effort;
        id = "custom:${lib.replaceStrings [ "." ] [ "-" ] (lib.toUpper model)}-${titleEffort effort}-${lib.toUpper speed}-ChatGPT-Pro";
        baseUrl = proxyOpenAIBaseUrl;
        apiKey = proxyApiKey;
        displayName = "${lib.toUpper model} ${titleEffort effort} ${lib.toUpper speed} [ChatGPT Pro OAuth]";
        noImageSupport = false;
        provider = "openai";
      } // lib.optionalAttrs (speed == "fast") {
        extraArgs = {
          service_tier = "priority";
        };
      };
    in
    lib.concatLists (map
      (model: lib.concatLists (map
        (effort: map (speed: mkModel model effort speed) speeds)
        efforts))
      models);

  claudeModels =
    let
      models = [
        {
          id = "claude-opus-4-5-20251101";
          name = "Claude Opus 4.5";
        }
        {
          id = "claude-opus-4-6";
          name = "Claude Opus 4.6";
        }
        {
          id = "claude-opus-4-7";
          name = "Claude Opus 4.7";
        }
      ];
      efforts = [ "low" "medium" "high" "xhigh" "max" "auto" ];
      mkModel = model: effort: {
        model = model.id;
        id = "custom:${model.id}-${effort}-OAuth";
        baseUrl = proxyBaseUrl;
        apiKey = proxyApiKey;
        displayName = "${model.name} ${titleEffort effort} [OAuth]";
        noImageSupport = false;
        provider = "anthropic";
      } // {
        extraArgs = {
          thinking = {
            type = "adaptive";
          };
          output_config = {
            inherit effort;
          };
          max_tokens = 64000;
        };
      };
    in
    lib.concatLists (map
      (model: map (effort: mkModel model effort) efforts)
      models);

  customModels = lib.imap0 (index: model: model // { inherit index; }) (openAIModels ++ claudeModels);
in
{
  factorySettings = tmpl ../../files/factory/settings.json {
    customModels = builtins.toJSON customModels;
  };

  ampSettings = tmpl ../../files/amp/settings.json {
    inherit proxyBaseUrl;
  };

  cliProxyApiConfig = tmpl ../../files/cli-proxy-api/config.yaml {
    inherit proxyApiKey;
  };
}
