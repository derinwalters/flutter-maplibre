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
      expect(fontFamilyNames(" '', \"  \" "), isEmpty);
      expect(fontFamilyNames('   '), isEmpty);
      expect(fontFamilyNames(''), isEmpty);
    });

    test('collapses the whitespace of unquoted names', () {
      expect(fontFamilyNames(' Hiragino \t  Sans\n,PingFang  SC'), [
        'Hiragino Sans',
        'PingFang SC',
      ]);
    });

    test('unescapes quoted names', () {
      expect(fontFamilyNames(r''' 'Foo\'s Sans', "A\\B" '''), [
        "Foo's Sans",
        r'A\B',
      ]);
    });

    test('keeps every name on a line of its own', () {
      expect(fontFamilyNames("'Noto\nSans'"), ['Noto Sans']);
    });

    test('ends an unterminated quote at the end of the list', () {
      expect(fontFamilyNames("sans-serif, 'Hiragino Sans"), [
        'sans-serif',
        'Hiragino Sans',
      ]);
    });
  });
}
