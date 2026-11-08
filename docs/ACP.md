# ACP notes (parked)

Kept on hand while the orchestrator is developed on its own. Not part of the current scope.

## Plugging the handler into an ACP runtime

Copy the handler together with `lib/` into the offering folder. The `../../../runtime/offeringTypes.js` import is type-only
and is erased at run time. Node 22.18+ runs the `.ts` file directly.

A reasonable first offering is **signals only** (`dry_run: true`): it sells the alignment analysis without holding keys.

