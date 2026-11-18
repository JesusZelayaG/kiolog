import 'package:flutter_test/flutter_test.dart';
import 'package:kiolog/shared/widgets/exercise_reference.dart';

void main() {
  group('normalizeReferenceUrl', () {
    test('agrega https si falta y deja pasar enlaces válidos', () {
      expect(normalizeReferenceUrl('  youtu.be/abc123XYZ  '), 'https://youtu.be/abc123XYZ');
      expect(normalizeReferenceUrl('https://www.instagram.com/p/xyz/'), 'https://www.instagram.com/p/xyz/');
    });

    test('vacío o texto que no es enlace queda en null', () {
      expect(normalizeReferenceUrl(''), isNull);
      expect(normalizeReferenceUrl('press de banca'), isNull);
      expect(normalizeReferenceUrl('ftp://archivo.com/x'), isNull);
    });
  });

  test('reconoce videos de YouTube en sus formas', () {
    expect(youtubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    expect(youtubeId('https://youtu.be/dQw4w9WgXcQ?si=abc'), 'dQw4w9WgXcQ');
    expect(youtubeId('https://youtube.com/shorts/AbC_123-xyz'), 'AbC_123-xyz');
    expect(youtubeId('https://m.youtube.com/watch?v=dQw4w9WgXcQ&t=30'), 'dQw4w9WgXcQ');
    expect(youtubeId('https://vimeo.com/123456'), isNull);
  });

  test('reconoce enlaces directos a imágenes y GIF', () {
    expect(isImageUrl('https://ejemplo.com/press.GIF'), isTrue);
    expect(isImageUrl('https://ejemplo.com/sentadilla.jpg?w=600'), isTrue);
    expect(isImageUrl('https://www.instagram.com/p/xyz/'), isFalse);
  });

  test('reconoce Vimeo y videos directos', () {
    expect(vimeoId('https://vimeo.com/123456789'), '123456789');
    expect(vimeoId('https://player.vimeo.com/video/76979871'), '76979871');
    expect(vimeoId('https://youtu.be/dQw4w9WgXcQ'), isNull);
    expect(isVideoUrl('https://cdn.ejemplo.com/clip.MP4'), isTrue);
    expect(isVideoUrl('https://ejemplo.com/press.gif'), isFalse);
  });
}
