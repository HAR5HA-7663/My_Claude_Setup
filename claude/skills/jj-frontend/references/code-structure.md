# Code structure

A consistent layout is the cheapest documentation. If a file does not fit anywhere cleanly, fix the structure; do not invent a new corner.

## Feature-based layout

```
src/features/<feature>/
  pages/        route components
  components/   feature-scoped components (one per file)
  hooks/        feature-scoped hooks
  lib/          utilities, API clients, query-key factories
  types/        <name>.types.ts
  config/       registries, copy and static dictionaries
src/shared/     auth (permissions, useCan, Can), components (+ ui primitives), hooks, lib, types
```

- Used by exactly one feature: that feature's folder. Shared by two or more: hoist to `shared/` (confirm genuine reuse first). **Never import another feature's internals.**
- Copy and option lists live in the feature's config module, not at call sites.
- Where does a new file go? Route → `pages/` plus the router entry. Single-feature component/hook/type → that feature. Cross-feature → `shared/`. API client or key factory → the feature's `lib/`. Primitive → `shared/components/ui/`. Ephemeral plans and scratch output → a git-ignored `.scratch/` at the repo root (never `/tmp`, never imported by `src/`). Specs, plans and runbooks → `docs/`. None fit? Stop and ask: a new top-level directory is an architectural decision.

## Naming

| Kind | Convention |
|---|---|
| Components | `PascalCase.tsx` (or the project's kebab-case, consistently) |
| Hooks | `useCamelCase.ts` |
| Libs, clients | `kebab-case.ts` |
| Types | `<domain>.types.ts` |
| Feature folders | `kebab-case` |

Named exports over default. Barrels only at the shared component and hook roots, never per feature. Cross-area imports use an alias (`@/shared/...`); same-feature imports are relative. Writing `../../../../shared` means switch to the alias.

## Routing

- All routes in one router file (or the framework's file routing), with layout wrappers for each shell and a permission gate per route (`<RequirePermission perm="...">`). Do not re-implement gating inside pages.
- **Every page route is lazy**, through one helper that recovers from stale chunks after a deploy: on a chunk-load error, reload from a small per-tab budget (for example 0 s, 3 s, 9 s within a minute, counted in sessionStorage) behind a never-settling promise so Suspense holds; once spent, show "a newer version is available" when the build id changed. A bare `React.lazy` caches the rejection for the life of the tab and crashes tabs open across a deploy. Make the SPA rewrite exclude `/assets/` so a missing chunk 404s instead of answering HTML.
- Preload a route's chunk on nav hover and focus.

## TypeScript and lint

- `strict`, `noUnusedLocals`, `noUnusedParameters`, `noFallthroughCasesInSwitch` stay on. No `any` (use `unknown` and narrow); no TS `enum` (const objects or unions); `interface` for object shapes, `type` for unions.
- With composite project references, `tsc --noEmit` can miss errors the real build catches: verify with the real build.
- Never silence a type error or a lint rule to get green.
- React Compiler / hooks lint rules are errors: no `ref.current = v` during render (use a latest-ref helper written in an insertion effect), no `Date.now()` in render (a `useNow(interval)` hook), no mutated accumulators inside a render `.map()`, no early return above later hooks.
- One formatter or none: do not run a formatter with no project config over source; hand-edit to the file's style.

## Component rules

- Functional components; hooks own data fetching; components under ~200 lines; `React.memo` only with profiler evidence; prop drilling past two levels means context or a small store.
- User-facing errors go through toasts or inline error states, never `alert()` or a swallowed `console.error`.
- Keys are stable ids, never indexes.

## Tests

- Unit tests next to source or in a feature `__tests__`; browser specs in one e2e folder.
- Vitest 4: reset mocks in `afterEach`, not `beforeEach` (a reset ahead of a throwing mock mis-reports the test), and never mock-reject with an error named `AbortError`.
- Guard tests for copy and wiring are mutation-checked: break the guarded thing once and confirm the test fails.
