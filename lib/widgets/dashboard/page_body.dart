import 'package:flutter/material.dart';

/// Isi halaman yang bisa di-scroll, lebarnya dibatasi supaya tetap rapi di
/// tablet/web.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 960});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: children,
        ),
      ),
    );
  }
}
