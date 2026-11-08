# bushido-virtuals

Handlers for Bushido agents on the Virtuals ACP marketplace (soul handlers, trackers, the swap orchestrator).

- [Swap orchestrator](docs/ORCHESTRATOR.md): alignment of two signals into a capped swap plan. **Live execution is not wired**; dry run only.
- `lib/`: orchestrator config and safety policy (pure functions, unit-tested).
- `examples/`: integration examples that are not handlers.

```bash
npm test   # Node 22.18+
```
