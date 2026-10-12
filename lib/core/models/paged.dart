class Paged<T> {
  final List<T> items;
  final int page;
  final int pages;
  final int total;

  const Paged({
    required this.items,
    required this.page,
    required this.pages,
    required this.total,
  });

  bool get hasMore => page < pages;
}
