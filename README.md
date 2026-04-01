# env-doctor

Bash **environment discovery** and **progressive init** for [dev-master](https://github.com/k-dot-greyz/dev-master) / zenOS dex checkouts. Zero extra deps for the read-only discovery pass.

## Consume from dev-master

This repository is vendored as a git submodule:

- Submodule path: `dex/09-repos/env-doctor`
- Stable entrypoints (symlink): `./env-doctor.sh` and `bash dex/04-scripts/env-doctor.sh`

## Run

From the **dev-master repository root**:

```bash
bash dex/09-repos/env-doctor/env-doctor.sh
# or (after submodule init)
./env-doctor.sh
```

## Develop upstream

Edit `env-doctor.sh` here, tag releases as needed, then bump the submodule pointer in dev-master (see `dex/03-docs/guides/SUBMODULE_BUMP.md`).
