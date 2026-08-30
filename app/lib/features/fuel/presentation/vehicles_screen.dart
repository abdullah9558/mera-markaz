import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../home/presentation/dashboard_provider.dart';
import '../data/vehicle_repository.dart';

final vehiclesProvider = FutureProvider<List<Vehicle>>(
  (ref) => ref.watch(vehicleRepositoryProvider).vehicles(),
);

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vehiclesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.phrase('My vehicles'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _vehicleDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.phrase('Add vehicle')),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (vehicles) => vehicles.isEmpty
            ? _EmptyVehicles(onAdd: () => _vehicleDialog(context, ref))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(vehiclesProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: vehicles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final vehicle = vehicles[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const CircleAvatar(
                          child: Icon(Icons.directions_car_outlined),
                        ),
                        title: Text(
                          vehicle.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${vehicle.makeModel ?? vehicle.fuelType} • ${_number(vehicle.odometer)} km',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                VehicleDetailScreen(vehicle: vehicle),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _EmptyVehicles extends StatelessWidget {
  const _EmptyVehicles({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_car_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            context.l10n.phrase(
              'Track fuel, mileage and maintenance in one place.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAdd,
            child: Text(context.l10n.phrase('Add your first vehicle')),
          ),
        ],
      ),
    ),
  );
}

class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicle});
  final Vehicle vehicle;
  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  late Future<(List<FuelEntry>, List<MaintenanceEntry>, VehicleAnalytics)>
  future;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<(List<FuelEntry>, List<MaintenanceEntry>, VehicleAnalytics)>
  _load() async {
    final repo = ref.read(vehicleRepositoryProvider);
    return (
      await repo.fuelHistory(widget.vehicle.id),
      await repo.maintenance(widget.vehicle.id),
      await repo.analytics(widget.vehicle.id),
    );
  }

  void refresh() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.vehicle.name)),
    body: FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (fuel, maintenance, analytics) = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(
                  label: context.l10n.phrase('Fuel spent'),
                  value: _money(analytics.totalFuelCost),
                ),
                _Metric(
                  label: context.l10n.phrase('Average mileage'),
                  value:
                      '${analytics.averageKmPerLiter.toStringAsFixed(1)} km/L',
                ),
                _Metric(
                  label: context.l10n.phrase('Cost per km'),
                  value: _money(analytics.costPerKm),
                ),
                _Metric(
                  label: context.l10n.phrase('Maintenance'),
                  value: _money(analytics.maintenanceCost),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (await _fuelDialog(context, ref, widget.vehicle) ==
                          true) {
                        ref.invalidate(homeDashboardProvider);
                        refresh();
                      }
                    },
                    icon: const Icon(Icons.local_gas_station),
                    label: Text(context.l10n.phrase('Add fuel')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (await _maintenanceDialog(
                            context,
                            ref,
                            widget.vehicle,
                          ) ==
                          true) {
                        refresh();
                      }
                    },
                    icon: const Icon(Icons.build_outlined),
                    label: Text(context.l10n.phrase('Add service')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              context.l10n.phrase('Fuel history'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (fuel.isEmpty)
              ListTile(
                title: Text(context.l10n.phrase('No fuel entries yet.')),
              ),
            ...fuel.map(
              (item) => ListTile(
                leading: const Icon(Icons.local_gas_station_outlined),
                title: Text(
                  '${item.liters.toStringAsFixed(1)} L • ${_money(item.cost)}',
                ),
                subtitle: Text(
                  '${DateFormat.yMMMd().format(item.filledAt)} • ${_number(item.odometer)} km',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.phrase('Maintenance history'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (maintenance.isEmpty)
              ListTile(
                title: Text(context.l10n.phrase('No maintenance entries yet.')),
              ),
            ...maintenance.map(
              (item) => ListTile(
                leading: const Icon(Icons.build_outlined),
                title: Text('${item.kind} • ${_money(item.cost)}'),
                subtitle: Text(
                  item.nextDueAt == null
                      ? DateFormat.yMMMd().format(item.servicedAt)
                      : '${DateFormat.yMMMd().format(item.servicedAt)} • ${context.l10n.phrase('Next')}: ${DateFormat.yMMMd().format(item.nextDueAt!)}',
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 50) / 2,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ),
  );
}

Future<void> _vehicleDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final model = TextEditingController();
  final odometer = TextEditingController();
  var saving = false;
  String? error;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(context.l10n.phrase('Add vehicle')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('Vehicle name'),
                  errorText: error,
                ),
              ),
              TextField(
                controller: model,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('Make and model'),
                ),
              ),
              TextField(
                controller: odometer,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('Current odometer'),
                  helperText: context.l10n.phrase(
                    'Enter the current total reading shown on the vehicle.',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving
                ? null
                : () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    final parsedOdometer = double.tryParse(
                      odometer.text.replaceAll(',', '').trim(),
                    );
                    if (name.text.trim().isEmpty ||
                        parsedOdometer == null ||
                        parsedOdometer < 0) {
                      setDialogState(
                        () => error = context.l10n.phrase(
                          'Enter a vehicle name and a valid odometer.',
                        ),
                      );
                      return;
                    }
                    setDialogState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(vehicleRepositoryProvider)
                          .saveVehicle(
                            name: name.text,
                            makeModel: model.text,
                            fuelType: 'petrol',
                            odometer: parsedOdometer,
                          );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (_) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          saving = false;
                          error = context.l10n.phrase(
                            'Vehicle could not be saved. Please try again.',
                          );
                        });
                      }
                    }
                  },
            child: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.phrase('Save')),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 250));
  name.dispose();
  model.dispose();
  odometer.dispose();
  if (saved == true) ref.invalidate(vehiclesProvider);
}

Future<bool?> _fuelDialog(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
) {
  final liters = TextEditingController();
  final cost = TextEditingController();
  final odo = TextEditingController(text: vehicle.odometer.toStringAsFixed(0));
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.phrase('Add fuel')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: liters,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Liters'),
            ),
          ),
          TextField(
            controller: cost,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Total cost'),
            ),
          ),
          TextField(
            controller: odo,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Odometer'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.phrase('Cancel')),
        ),
        FilledButton(
          onPressed: () async {
            await ref
                .read(vehicleRepositoryProvider)
                .addFuel(
                  vehicleId: vehicle.id,
                  liters: double.tryParse(liters.text) ?? 0,
                  cost: double.tryParse(cost.text) ?? 0,
                  odometer: double.tryParse(odo.text) ?? 0,
                  filledAt: DateTime.now(),
                );
            if (context.mounted) Navigator.pop(context, true);
          },
          child: Text(context.l10n.phrase('Save and add expense')),
        ),
      ],
    ),
  );
}

Future<bool?> _maintenanceDialog(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
) {
  final kind = TextEditingController();
  final cost = TextEditingController();
  final days = TextEditingController();
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.phrase('Add maintenance')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: kind,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Service type'),
            ),
          ),
          TextField(
            controller: cost,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.phrase('Cost')),
          ),
          TextField(
            controller: days,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Remind me after days (optional)'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.l10n.phrase('Cancel')),
        ),
        FilledButton(
          onPressed: () async {
            final reminderDays = int.tryParse(days.text);
            await ref
                .read(vehicleRepositoryProvider)
                .addMaintenance(
                  vehicleId: vehicle.id,
                  kind: kind.text,
                  cost: double.tryParse(cost.text) ?? 0,
                  odometer: vehicle.odometer,
                  nextDueAt: reminderDays == null
                      ? null
                      : DateTime.now().add(Duration(days: reminderDays)),
                );
            if (context.mounted) Navigator.pop(context, true);
          },
          child: Text(context.l10n.phrase('Save')),
        ),
      ],
    ),
  );
}

String _number(num value) => NumberFormat.decimalPattern('en_PK').format(value);
String _money(num value) => 'Rs. ${_number(value)}';
