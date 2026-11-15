import 'parcel.dart';

/// One entry of the user's "My parcels" list as the phone keeps it: the parcel
/// and when the user last changed it. A removed parcel stays as a marker
/// ([deleted]) until the sync has told the account, so other devices remove it
/// too.
class MyParcel {
  const MyParcel({
    required this.id,
    required this.updatedAt,
    this.parcel,
    this.deleted = false,
  });

  final String id;

  /// Set by the app when the user adds or removes the parcel; the newer
  /// change wins when the phone and the account differ.
  final DateTime updatedAt;

  /// Null only for a removal that came from the account.
  final Parcel? parcel;

  final bool deleted;

  /// Distance belongs to one search, not to the parcel: it is not kept.
  static Parcel _kept(Parcel p) =>
      Parcel(id: p.id, center: p.center, ring: p.ring, address: p.address);

  factory MyParcel.added(Parcel parcel, DateTime at) =>
      MyParcel(id: parcel.id, updatedAt: at, parcel: _kept(parcel));

  MyParcel removed(DateTime at) =>
      MyParcel(id: id, updatedAt: at, parcel: parcel, deleted: true);

  /// The same entry as the account's sync endpoint sends and returns it.
  factory MyParcel.fromJson(Map<String, dynamic> json) {
    final deleted = json['deleted'] as bool? ?? false;
    final raw = json['parcel'];
    return MyParcel(
      id: json['parcelId'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      parcel: raw is Map<String, dynamic> && raw.isNotEmpty
          ? Parcel.fromJson(raw)
          : null,
      deleted: deleted,
    );
  }

  Map<String, dynamic> toJson() => {
    'parcelId': id,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deleted': deleted,
    if (parcel != null && !deleted) 'parcel': parcel!.toJson(),
  };

  /// What the phone writes to its own storage (keeps the parcel of a removal).
  Map<String, dynamic> toStored() => {
    ...toJson(),
    if (parcel != null) 'parcel': parcel!.toJson(),
  };
}
