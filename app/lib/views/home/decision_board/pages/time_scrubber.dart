import 'package:flutter/material.dart';
import '../../../../theme.dart';

class TimeScrubber extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double>? onChanged;

  const TimeScrubber({super.key, this.initialValue = 0.5, this.onChanged});

  @override
  State<TimeScrubber> createState() => _TimeScrubberState();
}

class _TimeScrubberState extends State<TimeScrubber> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Text('PAST', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.white54, letterSpacing: 1.0)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2.0,
                activeTrackColor: HelloColors.accent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: HelloColors.accent.withAlpha(50),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                min: 2020.0,
                max: 2030.0,
                value: _value,
                onChanged: (val) {
                  setState(() => _value = val);
                  widget.onChanged?.call(val);
                },
              ),
            ),
          ),
          const Text('FUTURE', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.white54, letterSpacing: 1.0)),
        ],
      ),
    );
  }
}
