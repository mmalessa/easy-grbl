class SvgPathModel {
  final String id;
  final String d;
  bool selected;

  SvgPathModel({
    required this.id,
    required this.d,
    this.selected = false,
  });
}
