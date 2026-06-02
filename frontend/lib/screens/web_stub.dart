// Stub classes to allow compilation on mobile/desktop platforms where dart:html is unavailable.

class FileUploadInputElement {
  String? accept;
  void click() {}
  Stream<dynamic> get onChange => const Stream.empty();
  List<dynamic>? files;
}

class FileReader {
  void readAsArrayBuffer(dynamic file) {}
  Stream<dynamic> get onLoadEnd => const Stream.empty();
  dynamic result;
}
