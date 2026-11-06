import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../shell/app_shell.dart';
import '../../widgets/common.dart';
import '../../core/i18n.dart';

/// Profil sengaja dikosongkan dulu; akan didesain nanti.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final z = ZColors.of(context);
    return Scaffold(
      backgroundColor: z.bg,
      body: PageScroll(withDock: false, children: [
        PageTitle(tr('Profil'), onBack: () => Navigator.of(context).pop()),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: z['dashed'], width: 2),
          ),
          child: EmptyState(
            title: tr('Profil belum diatur'),
            message: tr('Halaman ini sengaja dikosongkan dulu dan akan didesain nanti.'),
          ),
        ),
      ]),
    );
  }
}
