import 'package:material_ui/material_ui.dart';

class CropMultiSelector extends StatefulWidget {
  const CropMultiSelector({
    super.key,
    required this.selectedCrops,
    required this.onCropToggled,
  });

  final List<String> selectedCrops;
  final void Function(String crop, bool isSelected) onCropToggled;

  @override
  State<CropMultiSelector> createState() => _CropMultiSelectorState();
}

class _CropMultiSelectorState extends State<CropMultiSelector> {
  // Hardcoded list — ready to be replaced by an API call later
  static const List<String> _availableCrops = [
    'Corn',
    'Wheat',
    'Soybeans',
    'Barley',
    'Rice',
    'Potatoes',
    'Tomatoes',
  ];

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

  @override
  Widget build(BuildContext context) {
    final count = widget.selectedCrops.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Crops on Plot:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
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
              overlayChildBuilder: (context) => _buildPopup(),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                decoration: InputDecoration(
                  hintText: count == 0
                      ? 'Search crops...'
                      : '$count selected — search crops...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
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

  Widget _buildPopup() {
    final q = _query.trim().toLowerCase();
    final crops =
        _availableCrops.where((c) => c.toLowerCase().contains(q)).toList();

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
                constraints: const BoxConstraints(maxHeight: 240),
                child: crops.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No crops found'),
                      )
                    : ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: crops.map((crop) {
                          return CheckboxListTile(
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(crop),
                            value: widget.selectedCrops.contains(crop),
                            onChanged: (selected) =>
                                widget.onCropToggled(crop, selected ?? false),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
