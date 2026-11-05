# UI notes

One design, no theme switcher: deep-navy surfaces, glass panels, a single
teal accent. Phone and desktop render the same screens from `lib/ui/`.

- The home screen is the whole product: link field, scan controls, ranked
  results, copy and config actions.
- Keep motion cheap — lists scroll at full frame rate on modest hardware.
- Any wording change on the home screen has a matching expectation in
  `test/ui/home_page_test.dart`; update both together.

## Android identity

The application id is fixed and must not change between releases,
otherwise existing installs stop updating in place.
