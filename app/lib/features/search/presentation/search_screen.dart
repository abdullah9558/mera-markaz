import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../data/search_repository.dart';
import '../domain/search_result.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final controller = TextEditingController();
  Timer? debounce;
  Future<List<SearchResult>>? results;
  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  void changed(String value) {
    debounce?.cancel();
    debounce = Timer(
      Duration(milliseconds: 250),
      () => setState(
        () => results = ref.read(searchRepositoryProvider).search(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: TextField(
        controller: controller,
        autofocus: true,
        onChanged: changed,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.l10n.phrase('Search expenses, income, people…'),
          prefixIcon: Icon(Icons.search),
          filled: false,
          border: InputBorder.none,
        ),
      ),
    ),
    body: results == null
        ? _SearchPrompt()
        : FutureBuilder<List<SearchResult>>(
            future: results,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              final values = snapshot.data!;
              if (values.isEmpty) {
                return Center(
                  child: Text(
                    context.l10n.phrase('No matching local records.'),
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.all(16),
                itemCount: values.length,
                separatorBuilder: (_, _) => SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = values[index];
                  final icon = switch (item.type) {
                    SearchResultType.transaction => Icons.receipt_long,
                    SearchResultType.person => Icons.person,
                    SearchResultType.ledgerEntry => Icons.handshake,
                    SearchResultType.savingsGoal => Icons.savings_outlined,
                    SearchResultType.vehicle => Icons.directions_car_outlined,
                  };
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(icon)),
                      title: Text(item.title),
                      subtitle: Text(
                        item.date == null
                            ? context.l10n.phrase(item.subtitle)
                            : '${context.l10n.phrase(item.subtitle)} • ${DateFormat.yMMMd().format(item.date!)}',
                      ),
                      trailing: item.amount == null
                          ? Icon(Icons.chevron_right)
                          : Text(
                              'Rs. ${NumberFormat.decimalPattern('en_PK').format(item.amount)}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                      onTap: () => context.go(switch (item.type) {
                        SearchResultType.transaction => '/expenses',
                        SearchResultType.person ||
                        SearchResultType.ledgerEntry => '/udhaar',
                        SearchResultType.savingsGoal => '/savings',
                        SearchResultType.vehicle => '/vehicles',
                      }),
                    ),
                  );
                },
              );
            },
          ),
  );
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_search, size: 64),
          SizedBox(height: 14),
          Text(
            context.l10n.phrase('Search your local records'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            context.l10n.phrase(
              'Find expenses, income, people and Udhaar descriptions without uploading your data.',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
