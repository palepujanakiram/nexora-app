import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_style.dart';

/// Six boxes for the SMS code. One invisible text field sits on top, so
/// typing, pasting, deleting and iOS's "From Messages" autofill all work as
/// in a normal field; the boxes just show its digits.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({
    super.key,
    required this.controller,
    required this.style,
    required this.onChanged,
    required this.onSubmitted,
    this.length = 6,
    this.fieldKey,
  });

  final TextEditingController controller;
  final LoginStyle style;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final int length;

  /// Key for the hidden text field, so tests can type into it.
  final Key? fieldKey;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([widget.controller, _focus]),
            builder: (context, _) {
              final digits = widget.controller.text;
              return Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: style.box(
                          // The box the next digit goes into, or the last one when full.
                          focused: _focus.hasFocus && i == digits.length.clamp(0, widget.length - 1),
                        ),
                        child: Center(
                          child: Text(
                            i < digits.length ? digits[i] : '',
                            style: style.input.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: widget.fieldKey,
                controller: widget.controller,
                focusNode: _focus,
                autofocus: true,
                showCursor: false,
                enableInteractiveSelection: false,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
