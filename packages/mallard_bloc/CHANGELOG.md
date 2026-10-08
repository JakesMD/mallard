## 0.1.1 - 08 Oct 2026

- ✨ Supports `mallard` 3.0.0.

## 0.1.0 - 07 Oct 2026

- 💥 **Breaking:** Requires `mallard` 2.0.0.
- 💥 **Breaking:** `TaskCubitMixin` now takes its type arguments in `<S, F>`
  order.
- 💥 **Breaking:** `request` now reports a thrown error with `addError` and
  restores the previous state.
- ✨ Added `ResultStreamCubitMixin`, which drives a `TaskBlocState` from a
  `ResultStream`.
- 🐛 Fixed `request` throwing a `StateError` when the cubit closes before the
  task completes.

## 0.0.1 - 02 Feb 2026

- 🎉 Initial release
