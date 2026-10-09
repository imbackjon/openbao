# Flaky-test exploit harness

Reusable triggers for the timing-dependent and environment-dependent test
defects hunted in this repository. Each script targets one defect and tries to
trigger it deterministically or under worst-case scheduling conditions.

## Defect inventory

| # | Defect | Target | Trigger |
|---|--------|--------|---------|
| 1 | KV upgrade test workload + unbounded wait loop | `internal/builtin/logical/kv/upgrade_test.go` (`TestVersionedKV_Upgrade`) | `trigger_kv_upgrade.sh` |
| 2 | Root bypasses `chmod 0000`, breaking the permission assertion | `internal/helper/logging/logger_test.go` (`TestLogger_SetupLoggerWithInValidLogPathPermission`) | `trigger_root_bypass.sh` |
| 3 | Rollback manager ticker starvation (sleep-then-assert) | `internal/vault` (`TestRollbackManager`) | `stress.sh` |
| 4 | kube auth TLS config updater starvation (sleep-then-assert) | `internal/builtin/credential/kubernetes` (`Test_kubeAuthBackend_runTLSConfigUpdater`) | `stress.sh` |

## Usage

```sh
# 1. KV upgrade timing under load (reproduces CI-timeout exposure)
./scripts/flaky-test-harness/trigger_kv_upgrade.sh [loaders]

# 2. Root permission bypass (deterministic, requires euid 0)
./scripts/flaky-test-harness/trigger_root_bypass.sh

# 3/4. Race/starvation stress of any test
./scripts/flaky-test-harness/stress.sh <package> <test-regex> <count> [loaders]
./scripts/flaky-test-harness/stress.sh ./internal/vault '^TestRollbackManager$' 200 6
```

`PATH` must include the Go toolchain; `GOTOOLCHAIN` defaults to `local`.

## Evidence

- Defect 1: pre-fix package run measured ~105s plain / ~7m26s with `-race`
  (1,048,576 keys, unbounded wait loop). Post-fix (100k keys, 5-minute wait
  deadline): package passes with `-race` in ~79s.
- Defect 2: pre-fix test fails deterministically as root
  (`An error is expected but got nil`); post-fix it skips as root.
  `trigger_root_bypass.sh` demonstrates the underlying bypass.
- Defect 3: 200x `-race` under 6 `yes` loaders passed (~32s) — found-not-fixed.
- Defect 4: 20x `-race` passed (prior run); 100x `-race` passed (251s, this run)
  — found-not-fixed.

## Notes

- The `yes` loader count should stay below the number of available cores so the
  test binary still gets scheduled and the flake mechanism remains starvation
  of specific timers rather than total CPU starvation.
- `stress.sh` is generic: it can target any package/test combination, making it
  useful for future flaky-test hunts beyond the four defects above.
