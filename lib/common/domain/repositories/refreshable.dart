/// A repository whose data lives on a server and can be fetched again, e.g.
/// to pick up changes made from another device.
abstract interface class Refreshable {
  Future<void> refresh();
}
