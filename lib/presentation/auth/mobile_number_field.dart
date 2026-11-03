import 'package:flutter/material.dart';

import '../../domain/models/dial_code.dart';
import '../strings/auth_strings.dart';
import 'auth_validators.dart';

/// "Mobile number": a country-code picker next to the number field.
class MobileNumberField extends StatelessWidget {
  const MobileNumberField({
    super.key,
    required this.controller,
    required this.dialCode,
    required this.onDialCodeChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final DialCode dialCode;
  final ValueChanged<DialCode> onDialCodeChanged;
  final bool enabled;

  static const label = AuthStrings.mobileNumber;
  static const _codeWidth = 132.0;

  @override
  Widget build(BuildContext context) {
    final code = _CodeButton(
      selected: dialCode,
      enabled: enabled,
      width: _codeWidth,
      onSelected: onDialCodeChanged,
    );
    final number = Semantics(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(hintText: AuthStrings.mobileHint),
        validator: AuthValidators.mobile(dialCode),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Same style as LabeledField; each control below gets its own screen reader name.
        const ExcludeSemantics(
          child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        // Side by side on a phone; stacked when large text leaves too little room.
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < _codeWidth * 2.4
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [code, const SizedBox(height: 10), number],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    code,
                    const SizedBox(width: 10),
                    Expanded(child: number),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Looks like a dropdown (code, arrow); opens the country picker.
class _CodeButton extends StatelessWidget {
  const _CodeButton({
    required this.selected,
    required this.enabled,
    required this.width,
    required this.onSelected,
  });

  final DialCode selected;
  final bool enabled;
  final double width;
  final ValueChanged<DialCode> onSelected;

  Future<void> _pick(BuildContext context) async {
    final code = await showModalBottomSheet<DialCode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _CountryPickerSheet(selected: selected),
    );
    if (code != null) onSelected(code);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AuthStrings.countryCode(selected.name, selected.dial),
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: OutlinedButton(
          onPressed: enabled ? () => _pick(context) : null,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
          child: Row(
            children: [
              Expanded(child: Text(selected.dial, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search box and a lazily built list: only the rows on screen exist, so it stays quick on
/// low-end phones. Pops with the chosen code.
class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selected});

  final DialCode selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  List<DialCode> _results = dialCodes;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: AuthStrings.searchCountry,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (q) => setState(() => _results = filterDialCodes(q)),
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text(AuthStrings.noCountry))
                  : ListView.builder(
                      itemCount: _results.length,
                      prototypeItem: _row(dialCodes.first),
                      itemBuilder: (_, i) => _row(_results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(DialCode code) {
    final selected = code == widget.selected;
    return ListTile(
      title: Text(code.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(code.dial),
          // A tick as well as the highlight, so colour is not the only signal.
          SizedBox(width: 32, child: selected ? const Icon(Icons.check) : null),
        ],
      ),
      selected: selected,
      onTap: () => Navigator.of(context).pop(code),
    );
  }
}
