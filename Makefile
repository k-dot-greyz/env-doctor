.PHONY: help smoke test lint ci release test-pw

help:
	@printf '%s\n' "env-doctor targets:" \
	  "  make smoke    - run fast CLI smoke checks" \
	  "  make lint     - run shellcheck" \
	  "  make test     - run the Bash test suite" \
	  "  make test-pw  - run Playwright UX/security specs (requires npm install)" \
	  "  make ci       - run lint + test" \
	  "  make release  - build the release bundle"

smoke:
	bash env-doctor.sh --help >/dev/null
	bash env-doctor.sh --json --quiet >/dev/null

test:
	bash tests/run.sh

test-pw:
	npx playwright test

lint:
	shellcheck env-doctor.sh release.sh scripts/generate-examples.sh tests/*.sh

ci: lint test

release:
	bash scripts/generate-examples.sh
	bash release.sh
