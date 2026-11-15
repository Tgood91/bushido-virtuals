# ACP notes (parked)

Kept on hand while the orchestrator is developed on its own. Not part of the current scope.

## Plugging the handler into an ACP runtime

Copy the handler together with `lib/` into the offering folder. The handlers are plain JavaScript and no longer
import `../../../runtime/offeringTypes.js` (it was type-only); if the runtime only loads `handlers.ts`, rename the file
or re-export from one.

A reasonable first offering is **signals only** (`dry_run: true`): it sells the alignment analysis without holding keys.

