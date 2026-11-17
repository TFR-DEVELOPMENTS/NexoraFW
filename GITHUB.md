# Putting Nexoro on GitHub

The project is already a git repository with one commit. From the project folder:

```
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/nexoro-framework.git
git push -u origin main
```

Create the empty repository first at github.com/new (no README, no .gitignore, no licence, because those are already here).

Or, with the GitHub CLI installed and logged in:

```
gh repo create YOUR_GITHUB_USERNAME/nexoro-framework --private --source . --push
```

Use `--private` while the framework is in testing and make it public when you are ready.

Before the first push, check:
- `server.cfg` is in `.gitignore`. It holds your licence key. Only `dev/server.cfg.template` (placeholders only) is committed.
- `recipe.yaml` has `YOUR_GITHUB_USERNAME/nexoro-framework` in the `download_github` task. Change it to your repository. Anyone who installs from the recipe downloads the resources from there.
- Nothing you do not want public is in `resources/`.

To release a version, tag it (`git tag v1.13.0-beta && git push --tags`). Point the recipe's `ref` at the tag if you want installs pinned to a version.
