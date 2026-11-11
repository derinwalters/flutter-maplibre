import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_native/src/darwin/darwin_plugin.dart';

void main() {
  group('fontFamilyNames', () {
    test('splits a CSS font-family list in order', () {
      expect(fontFamilyNames('Hiragino Sans, sans-serif'), [
        'Hiragino Sans',
        'sans-serif',
      ]);
    });

    test('drops the quotes, and keeps the commas inside them', () {
      expect(fontFamilyNames(''' 'Noto Sans, JP' , "PingFang SC",serif '''), [
        'Noto Sans, JP',
        'PingFang SC',
        'serif',
      ]);
    });

    test('leaves out empty names', () {
      expect(fontFamilyNames(' , sans-serif ,, '), ['sans-serif']);
      expect(fontFamilyNames(''), isEmpty);
    });
  });
}
