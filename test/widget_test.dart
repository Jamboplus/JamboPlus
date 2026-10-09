import 'package:flutter_test/flutter_test.dart';
import 'package:jamboplus/core/constants/app_constants.dart';
import 'package:jamboplus/core/constants/app_strings.dart';

void main() {
  test('App constants are configured', () {
    expect(AppConstants.appName, 'JamboPlus');
    expect(AppStrings.nyumbani, 'Nyumbani');
    expect(AppStrings.categories, contains(AppStrings.mpira));
  });
}
