## 3.0.0 - 08 Oct 2026

- 💥 **Breaking:** `restartWhen` callbacks now return `bool`.
- ✨ Added `delay` to `restartWhen`.

## 2.1.0 - 07 Oct 2026

- ✨ Added `Mallard.onStreamRestart`.

## 2.0.0 - 07 Oct 2026

- 💥 **Breaking:** `Result` is now `sealed`, and `Success` and `Failure` are
  `final`.
- 💥 **Breaking:** Only the outermost task or result stream run fires the global
  callbacks.
- ✨ Added `ResultStream`, a stream of `Result`s where failures never end the
  stream.
- ✨ Added `Task.chainStream` and `Task.thenAttemptStream` to start a result
  stream from a task's success.
- ✨ Added `Mallard.onStreamSuccess` and `Mallard.onStreamFailure`.

## 1.0.0 - 02 Feb 2026

- 🎉 Initial release
