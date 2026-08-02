import 'package:flutter_test/flutter_test.dart';
import 'package:sokaplus/core/constants/app_constants.dart';
import 'package:sokaplus/core/constants/app_strings.dart';

void main() {
  test('App constants are configured', () {
    expect(AppConstants.appName, 'SokaPlus');
    expect(AppStrings.nyumbani, 'Nyumbani');
    expect(AppStrings.categories, contains(AppStrings.mpira));
  });
}
