// Bu dosya, dart:html kütüphanesinin mobil platformlarda derlenebilmesi için
// gerekli olan ancak mobil'de hiçbir işlevi olmayan sahte (stub) sınıfları içerir.
// Bu sayede, kIsWeb kontrolü ile korunan web'e özel kodlar derleme hatası vermez.

class Blob {
  Blob(List<dynamic> parts, [String? type, String? endings]);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) {
    // Mobil'de bu fonksiyonun çağrılması beklenmez, o yüzden boş bırakılabilir
    // veya bir hata fırlatılabilir.
    throw UnimplementedError('createObjectUrlFromBlob is not available on this platform.');
  }

  static void revokeObjectUrl(String url) {
    // Mobil'de bu fonksiyonun çağrılması beklenmez.
  }
}

class AnchorElement {
  String? href;

  AnchorElement({this.href});

  void setAttribute(String name, String value) {}

  void click() {}
}