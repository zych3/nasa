import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/crop.dart';
import '../../../repositories/crop_repository.dart';

/// Searchable multi-select of crops from the catalogue (`GET /api/crops`).
/// [selectedCrops] holds crop ids (e.g. "wheat"); names are shown in the
/// current language.
class CropMultiSelector extends StatefulWidget {
  const CropMultiSelector({
    super.key,
    required this.selectedCrops,
    required this.onCropToggled,
    this.repository,
    this.label,
    this.onlyRotationCrops = false,
  });

  final String? label;

  final bool onlyRotationCrops;

  final List<String> selectedCrops;
  final void Function(String cropId, bool isSelected) onCropToggled;

  /// Injectable for tests; defaults to the backend with saved fallback.
  final CropRepository? repository;

  @override
  State<CropMultiSelector> createState() => _CropMultiSelectorState();
}

class _CropMultiSelectorState extends State<CropMultiSelector> {
  late final CropRepository _repository = widget.repository ?? CropRepository();
  late Future<List<Crop>> _crops = _repository.getCrops();

  final _overlay = OverlayPortalController();
  final _link = LayerLink();
  final _focus = FocusNode();
  final _controller = TextEditingController();
  String _query = '';
  double _fieldWidth = 300;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) _overlay.show();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    _overlay.hide();
    _focus.unfocus();
  }

  void _retry() => setState(() => _crops = _repository.getCrops());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = widget.selectedCrops.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label ?? l10n.selectCropsLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TapRegion(
          groupId: this,
          onTapOutside: (_) => _close(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              _fieldWidth = constraints.maxWidth;
              return CompositedTransformTarget(
                link: _link,
                child: OverlayPortal(
                  controller: _overlay,
                  overlayChildBuilder: (context) => _buildPopup(context),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    decoration: InputDecoration(
                      hintText: count == 0
                          ? l10n.searchCropsHint
                          : l10n.searchCropsSelectedHint(count),
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onTap: _overlay.show,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final q = _query.trim().toLowerCase();

    Widget message(String text, {VoidCallback? onRetry}) => Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
        ],
      ),
    );

    return CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 4),
      child: Align(
        alignment: Alignment.topLeft,
        child: TapRegion(
          groupId: this,
          child: SizedBox(
            width: _fieldWidth,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: FutureBuilder<List<Crop>>(
                  future: _crops,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return message(l10n.cropListLoadError, onRetry: _retry);
                    }

                    final crops = [
                      for (final crop in snapshot.data ?? const <Crop>[])
                        if (!widget.onlyRotationCrops || crop.supportsRotation)
                          if (crop
                              .nameFor(languageCode)
                              .toLowerCase()
                              .contains(q))
                            crop,
                    ];
                    if (crops.isEmpty) return message(l10n.noCropsFound);

                    return ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final crop in crops)
                          CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(crop.nameFor(languageCode)),
                            value: widget.selectedCrops.contains(crop.id),
                            onChanged: (selected) => widget.onCropToggled(
                              crop.id,
                              selected ?? false,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
