/// [items] with the item at [from] moved to [to], where [to] is its index in the result.
/// Out-of-range indexes leave the list as it is.
List<T> moveItem<T>(List<T> items, int from, int to) {
  if (from < 0 || from >= items.length || to < 0 || to >= items.length || from == to) {
    return List.of(items);
  }
  final moved = List.of(items);
  final item = moved.removeAt(from);
  moved.insert(to, item);
  return moved;
}
