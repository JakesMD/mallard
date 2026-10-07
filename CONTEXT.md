# Mallard

Railway Oriented Programming for Dart: operations report failures as data instead of throwing, so code stays on a success track or a failure track.

## Language

**Result**:
The outcome of an operation: either a Success or a Failure.
_Avoid_: Either, outcome

**Success**:
A Result carrying the value an operation produced.
_Avoid_: Ok, Right

**Failure**:
A Result carrying a typed reason an operation did not succeed, optionally with the original exception and stack trace, which it keeps through every conversion and pass-through.
_Avoid_: Error, Left

**Task**:
A deferred asynchronous operation that, when run, produces a single Result.
_Avoid_: Future, job

**ResultStream**:
A deferred asynchronous source that, when run, emits a sequence of Results, carrying Failures down the stream as data rather than as stream errors.
_Avoid_: TaskStream, result flow, stream of tasks

**Inner run**:
Any run of a Task or ResultStream started while another run is in progress, whether by an operator or by user code, and whether or not its Result is awaited. Only the outermost run reports its Results to the global callbacks; an inner run reports nothing itself. The global callbacks fire outside any run, so a run they start is an outermost run.
_Avoid_: nested run, sub-run, silent run

**Restart**:
Re-running a ResultStream's source after it emits a Failure or closes, while the listener stays subscribed. A listener cancelling is never followed by a Restart.
_Avoid_: retry, repeat, resubscribe
