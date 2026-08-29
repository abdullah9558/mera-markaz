import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});
  static const tools = [
    ('tax', Icons.account_balance),
    ('electricity', Icons.bolt),
    ('solar', Icons.solar_power),
    ('property', Icons.square_foot),
    ('fuel', Icons.local_gas_station),
    ('zakat', Icons.volunteer_activism),
    ('smartFinance', Icons.auto_awesome_outlined),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.text('tools'))),
    body: ListView.separated(
      padding: EdgeInsets.all(20),
      itemCount: tools.length,
      separatorBuilder: (_, _) => SizedBox(height: 10),
      itemBuilder: (context, index) {
        final tool = tools[index];
        return Card(
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            leading: CircleAvatar(child: Icon(tool.$2)),
            title: Text(
              context.l10n.text(tool.$1),
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: Icon(Icons.chevron_right),
            onTap: () => context.push(
              tool.$1 == 'fuel'
                  ? '/vehicles'
                  : tool.$1 == 'smartFinance'
                  ? '/advanced'
                  : '/tool/${tool.$1}',
            ),
          ),
        );
      },
    ),
  );
}
