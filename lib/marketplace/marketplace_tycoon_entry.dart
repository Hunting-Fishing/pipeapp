import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A separate game route keeps virtual company operations independent of the
/// real marketplace, its permissions, and its fixed destination indices.
class MarketplaceTycoonEntry extends StatelessWidget {
  const MarketplaceTycoonEntry({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Material(
          color: const Color(0xFF152D38),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => context.push('/tycoon'),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Icon(Icons.oil_barrel_rounded,
                    size: 38, color: Color(0xFFFFA566)),
                const SizedBox(width: 18),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PLAY OIL & GAS TYCOON',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text('Build a virtual energy company. Produce, trade, '
                          'hire and expand — your game saves on this device.',
                          style: TextStyle(
                              color: Color(0xFFCBDBD7),
                              fontSize: 13,
                              height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFFFFA566)),
              ]),
            ),
          ),
        ),
      );
}
