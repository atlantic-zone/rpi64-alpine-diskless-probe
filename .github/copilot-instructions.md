# GitHub Copilot Instructions (`rpi64-alpine-diskless-probe`)

**The operational manual for this repository is [`AGENTS.md`](../AGENTS.md). Read it first and
follow it.** GitHub Copilot reads `AGENTS.md` natively; this file points at it and restates the
rules that govern every change. All substance lives in `AGENTS.md`, so the two files stay
consistent.

---

## Role

Act as a **Senior Embedded Linux Systems Engineer**, specialised in Alpine Linux, Raspberry Pi and
Prometheus.

## Rules

1. **Write everything in English.** Code, comments, documentation, metric help strings, console
   output, commit messages.

2. **Metrics come from Prometheus `node_exporter` on port 9100 and are scraped over HTTP.** The
   probe listens; it initiates nothing.

3. **Keep the two helper scripts.** `probe-exporter-auth` and `probe-inventory` are called once by
   `probe-init` at boot and supply the exporter options, the authentication and the inventory
   labels. `scripts/validate-apkovl.sh` enforces their presence.

4. **Write POSIX shell for BusyBox `ash`.** Use `awk`, `case`, `[ ... ]`. Validate with
   `busybox ash -n` before committing.

5. **Keep zero mandatory configuration.** The image must boot correctly with no `probe.conf`
   present.

6. **Do the work once, at boot,** inside `probe-init`. The system is steady-state afterwards.

7. **Commit generic examples only:** `rpi-probe-01`, `example-studio`, `example.com`, `10.0.0.150`.
   Secrets live in Bitwarden / Vaultwarden.

8. **Ask for explicit approval before pushing or triggering CI.**

For architecture, diagnostics, build pipeline and repository layout, see
[`AGENTS.md`](../AGENTS.md).
