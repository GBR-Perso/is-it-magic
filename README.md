# is-it-magic

Personal catalogue of Claude plugins. Each plugin lives in `plugins/<name>/`.

## Plugins

| Plugin        | Location               | Purpose                                                                                  |
| ------------- | ---------------------- | ---------------------------------------------------------------------------------------- |
| `is-it-magic` | `plugins/is-it-magic`  | General AI development workflow — agents, orchestration skills, language rules, and machine setup |

The Rise organisation catalogue (`it--claude-plugins`) also lists `is-it-magic`, pointing at `plugins/is-it-magic` in this repo.

## Adding a plugin

1. Add it under `plugins/<name>/` and list it in `.claude-plugin/marketplace.json` with `"source": "./plugins/<name>"`.
2. Run `claude plugin validate .` and push.

## Installing

```powershell
claude plugin marketplace add GBR-Perso/is-it-magic
claude plugin install is-it-magic@gbr-perso --scope user
```

## Local development

```powershell
claude --plugin-dir "C:/Workspace/Dev/Perso.Applications/is-it-magic/plugins/is-it-magic"
```
