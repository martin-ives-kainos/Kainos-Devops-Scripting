# Kainos-Devops-Scripting

This is a set of PowerShell utility functions, ultimately to packaged and published for future use

## Build

I intend to use [GitHub Actions](https://docs.github.com/en/actions) and Github CoPilot

### CoPilot Responses

Part 1

```:text
Read

Read

Read

Read , lines 1 to 60

Ran terminal command:  git -C d:\src\gh\kainos\Kainos-Devops-Scripting remote -v
Completed with input:  git -C d:\src\gh\kainos\Kainos-Devops-Scripting remote -v

Read , lines 60 to 130

Read , lines 1 to 60

Ran terminal command:  git remote -v; git branch --show-current

Ran terminal command:  git log --oneline -5; echo ---; git tag; echo ---; git for-each-ref --format="%(refname:short)" refs/heads

Read , lines 1 to 30

Searched for regex `Windows|RequireAdmin|Skip|-Skip:|OS ma">Windows` (`**/PowerShell/UtilsModule/tests/Invoke-AzCli.tests.ps1`), 1 result

Read , lines 1 to 40

Read

Created

Created .github/workflows/utilsmodule-ci-cd.yml:

- **`validate`** — installs `PSScriptAnalyzer`, lints `UtilsModule`, fails on `Error` severity, validates the manifest with `Test-ModuleManifest`.
- **`test`** — installs Pester 5, runs the `tests/` suite with NUnit XML output, publishes results via `dorny/test-reporter` and uploads the raw results as an artifact.
- **`publish`** — runs only on manual `workflow_dispatch` (with a `release_type` choice of patch/minor/major) against `main`. It bumps `ModuleVersion` in the `.psd1`, commits + tags (`vX.Y.Z`), pushes both, zips the module, creates a GitHub Release with the zip attached, and publishes to the PowerShell Gallery via `Publish-Module`.

Triggers: push/PR on changes under `PowerShell/UtilsModule/**` run validate+test only; a manual dispatch on `main` runs the full pipeline including release/publish.

**Required secrets:** `PSGALLERY_API_KEY` (add to repo secrets). `GITHUB_TOKEN` is provided automatically but the `publish` job needs `contents: write` permission, which is already set.

One thing to confirm: do you want releases to also fire automatically on push to `main` (e.g. tagged commit messages), or is manual `workflow_dispatch`-only release control what you want?

Made changes.

```

Part 2

```:text
Replacing 8 lines with 8 lines in

Updated:

- `publish` job now runs whenever `main` is updated (push or manual dispatch) — `if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'`. Every merge to `main` bumps the patch version (unless dispatched with `minor`/`major`), tags, releases, and publishes to the Gallery.
- The bump commit message includes `[skip ci]`, which GitHub Actions natively honors to skip triggering a new workflow run — preventing an infinite push→release→push loop.

Made changes.
```

## Documentation

* [Markdown](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github)
