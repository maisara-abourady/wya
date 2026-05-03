// favorite_drivers — public surface.
//
// Only symbols re-exported from this file are visible across BC boundaries.
// Anything imported from mobile/favorite_drivers/lib/src/* by code outside
// this BC is a violation of the public-surface rule (see CONVENTIONS.md
// §"Public surface rule").
//
// To add a new export, use the `module-manifest` skill in update mode.

export 'src/driver_id.dart' show DriverId;
