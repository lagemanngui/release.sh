# Contributing

Thanks for helping improve **release.sh**. This project stays intentionally small; contributions should match that scope.

## Getting started

1. Fork [lagemanngui/release.sh](https://github.com/lagemanngui/release.sh) on GitHub.
2. Clone your fork and create a branch from `main`.
3. Make your changes and test locally in a throwaway Git repository:

   ```bash
   mkdir /tmp/release-test && cd /tmp/release-test
   git init && git commit --allow-empty -m "init"
   git remote add origin <your-test-remote-or-skip-push>
   cp /path/to/release.sh .
   ./release.sh patch   # dry-run push only if you have a safe remote
   ```

4. Open a pull request with a clear description of the problem and solution.

## Guidelines

- **Keep the script portable**: Bash 4+, no extra dependencies beyond Git and common Unix utilities.
- **Preserve behavior** unless the PR explicitly changes documented semantics (version format, remotes, file names).
- **Update docs** when behavior changes: `README.md`, and `CHANGELOG.md` for user-visible changes.
- **One concern per PR** when possible (easier review for a ~70-line tool).

## Reporting issues

Include:

- OS and Bash version (`bash --version`)
- Git version (`git --version`)
- Exact command run and full terminal output
- Whether `.release-tag` exists and relevant `git tag -l 'v*'`

## Code of conduct

Be respectful and constructive. Maintainers may close issues or PRs that are off-topic, abusive, or out of scope.
