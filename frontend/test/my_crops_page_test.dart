import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'package:hopito_field_shift/l10n/app_localizations.dart';
import 'package:hopito_field_shift/models/crop.dart';
import 'package:hopito_field_shift/models/user_crop.dart';
import 'package:hopito_field_shift/pages/my_crops_page.dart';
import 'package:hopito_field_shift/pages/user_crop_form_page.dart';
import 'package:hopito_field_shift/repositories/auth_store.dart';
import 'package:hopito_field_shift/repositories/crop_repository.dart';
import 'package:hopito_field_shift/repositories/selected_plot_store.dart';
import 'package:hopito_field_shift/repositories/user_crop_repository.dart';

UserCrop _entry({bool active = true, String? label = 'Pole przy rzece'}) =>
    UserCrop(
      id: 'a1',
      cropId: 'wheat',
      point: const LatLng(50.0, 20.0),
      label: label,
      isActive: active,
      updatedAt: DateTime.utc(2026, 11, 15),
    );

class _FakeRepo implements UserCropRepository {
  _FakeRepo(this.items);

  List<UserCrop> items;
  final updates = <bool?>[];

  @override
  AuthStore get auth => throw UnimplementedError();

  @override
  Future<List<UserCrop>> list() async => items;

  @override
  Future<UserCrop> create({
    required String cropId,
    required LatLng point,
    String? parcelId,
    String? label,
    bool isActive = true,
  }) => throw UnimplementedError();

  @override
  Future<UserCrop> update(
    String id, {
    String? cropId,
    LatLng? point,
    String? parcelId,
    String? label,
    bool? isActive,
  }) async {
    updates.add(isActive);
    return _entry(active: isActive ?? true);
  }
}

class _FakeCrops implements CropRepository {
  @override
  bool get useMock => true;

  @override
  Future<List<Crop>> getCrops() async => [
    Crop.fromJson({
      'id': 'wheat',
      'name': {'pl': 'Pszenica', 'en': 'Wheat'},
      'scientificName': 'Triticum aestivum',
      'wikipediaUrl': <String, dynamic>{},
      'hasPrices': false,
    }),
  ];

  @override
  Future<Crop?> getCrop(String id) async => null;
}

Widget _app(_FakeRepo repo) => MaterialApp(
  locale: const Locale('pl'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  home: MyCropsPage(
    auth: AuthStore(),
    plotStore: SelectedPlotStore(),
    repository: repo,
    cropRepository: _FakeCrops(),
  ),
);

void main() {
  final pl = lookupAppLocalizations(const Locale('pl'));

  testWidgets('shows saved crops and switches one off', (tester) async {
    final repo = _FakeRepo([_entry()]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Pszenica'), findsOneWidget);
    expect(find.text('Pole przy rzece'), findsOneWidget);
    expect(find.text(pl.myCropsActiveOn), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(repo.updates, [false]);
    expect(find.text(pl.myCropsActiveOff), findsOneWidget);
  });

  testWidgets('says when there is nothing saved yet', (tester) async {
    await tester.pumpWidget(_app(_FakeRepo([])));
    await tester.pumpAndSettle();

    expect(find.text(pl.myCropsEmpty), findsOneWidget);
    expect(find.text(pl.myCropsAdd), findsOneWidget);
  });

  testWidgets('a new crop needs a place and a crop before saving', (
    tester,
  ) async {
    final repo = _FakeRepo([]);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pl'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: UserCropFormPage(
          repository: repo,
          crops: await _FakeCrops().getCrops(),
        ),
      ),
    );

    expect(find.text(pl.myCropsNoPlace), findsOneWidget);
    expect(find.text(pl.myCropsPickOnMap), findsOneWidget);

    final save = find.text(pl.myCropsSave);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text(pl.myCropsPlaceFirst), findsOneWidget);
    expect(find.text(pl.myCropsChooseCropFirst), findsOneWidget);
  });
}
