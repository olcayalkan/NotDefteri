# Development

## Build and test

```bash
swift build          # build
swift test           # run all tests
./calistir.sh -t     # test, then open the app if the tests pass
```

- Tests run in their own temporary note folders and never touch `~/Documents/NotDefteri/`.
- Test targets: `NotDefteriCekirdekTests` (core, both platforms), `NotDefteriMacTests`,
  `NotDefteriLinuxTests` (GTK; run under `xvfb-run` on a headless machine).

## CI

Every pull request and every push to `main` runs the same pipeline on both platforms in parallel:

```
macOS · 1. Build ─► 2. Test ─► 3. Package ─┐
                                          ├─► CI result
Linux · 1. Build ─► 2. Test ─► 3. Package ─┘
```

Code that does not build is not tested, and code that fails tests is not packaged. Compiler
warnings and failing tests are annotated on the run page. Nothing merges until **CI sonucu**
(CI result) is green.

## Workflow

1. **Open an issue** with the bug report or feature request form.
2. **Create a branch** with a short English name and no issue number:
   `feat/home-page-clock`, `fix/dependabot-update`, `docs/project-wiki`.
3. **Commit** with a type prefix and a clear message. Put `Closes #N` in the body to link the issue:

   ```text
   Fix: Kod bloğundan çıkış üç Enter ile

   Closes #N
   ```

   Types: `Feat`, `Fix`, `Docs`, `Test`, `CI`, `Refactor`, `Perf`, `Chore`.
4. **Open a pull request** using the template.
5. **Merge** with “Squash and merge” once CI is green, then delete the branch.

## Code map

`06_Metadata/Kod-Haritasi.md` describes what each file does. Update it when you add or remove files.

## Editing this wiki

The wiki's source is `docs/wiki/` in the repository, so it is reviewed like code.
Publish it with:

```bash
./scripts/wiki-yayinla.sh
```
