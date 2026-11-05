# Engine notes

The Dart engine mirrors the reference behaviour fixture-for-fixture; the
golden files under `test/` are the contract.

Things worth knowing before touching it:

- Dart strings are UTF-16. Indexing, lower-casing and trimming were matched
  against the fixtures character by character, including names with emoji.
- A probe only counts when the full handshake finishes and the tunneled
  request returns 204. Timeouts and half-open sockets are discards, never
  results.
- Results are ranked by the average of three successful rounds; arrival
  order breaks ties so the list never shuffles between frames.
- Cancelling a scan keeps whatever had already been verified at that
  moment — nothing more is promised.

Regenerate fixtures with `tool/gen_golden.py` and run `flutter test`
before and after any engine change.
