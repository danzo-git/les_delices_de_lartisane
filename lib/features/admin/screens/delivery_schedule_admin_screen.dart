import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/delivery_schedule.dart';
import '../../../services/delivery_schedule_service.dart';
import '../../../theme/app_colors.dart';

class DeliveryScheduleAdminScreen extends StatefulWidget {
  const DeliveryScheduleAdminScreen({super.key});

  @override
  State<DeliveryScheduleAdminScreen> createState() =>
      _DeliveryScheduleAdminScreenState();
}

class _DeliveryScheduleAdminScreenState
    extends State<DeliveryScheduleAdminScreen> {
  final _service = DeliveryScheduleService();
  final _noticeController = TextEditingController();
  DeliveryScheduleSettings _settings = const DeliveryScheduleSettings();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  static const _weekdays = <int, String>{
    1: 'Lundi',
    2: 'Mardi',
    3: 'Mercredi',
    4: 'Jeudi',
    5: 'Vendredi',
    6: 'Samedi',
    7: 'Dimanche',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _noticeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final settings = await _service.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _noticeController.text = '${settings.minimumNoticeHours}';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final noticeHours = int.tryParse(_noticeController.text.trim());
    if (noticeHours == null || noticeHours < 0 || noticeHours > 720) {
      _showMessage('Le délai doit être compris entre 0 et 720 heures.');
      return;
    }
    if (_settings.enabled && _settings.slots.isEmpty) {
      _showMessage('Ajoute au moins un créneau avant d’activer le planning.');
      return;
    }
    for (var firstIndex = 0;
        firstIndex < _settings.slots.length;
        firstIndex++) {
      final first = _settings.slots[firstIndex];
      for (var secondIndex = firstIndex + 1;
          secondIndex < _settings.slots.length;
          secondIndex++) {
        final second = _settings.slots[secondIndex];
        if (first.weekday == second.weekday &&
            first.startMinute < second.endMinute &&
            second.startMinute < first.endMinute) {
          _showMessage('Deux créneaux se chevauchent le même jour.');
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final updated = DeliveryScheduleSettings(
        enabled: _settings.enabled,
        minimumNoticeHours: noticeHours,
        slots: _settings.slots,
        closedDates: _settings.closedDates,
      );
      await _service.saveSettings(updated);
      if (!mounted) return;
      setState(() => _settings = updated);
      _showMessage('Planning enregistré.');
    } catch (error) {
      _showMessage('Impossible d’enregistrer le planning : $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editSlot([WeeklyDeliverySlot? existing]) async {
    final edited = await showDialog<WeeklyDeliverySlot>(
      context: context,
      builder: (context) =>
          _DeliverySlotDialog(weekdays: _weekdays, existing: existing),
    );
    if (edited == null) return;

    setState(() {
      final slots = [..._settings.slots];
      final index = slots.indexWhere((slot) => slot.id == edited.id);
      if (index == -1) {
        slots.add(edited);
      } else {
        slots[index] = edited;
      }
      _settings = DeliveryScheduleSettings(
        enabled: _settings.enabled,
        minimumNoticeHours: _settings.minimumNoticeHours,
        slots: _sortSlots(slots),
        closedDates: _settings.closedDates,
      );
    });
  }

  Future<void> _addClosedDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Choisir un jour de fermeture',
    );
    if (date == null) return;

    final key = deliveryDateKey(date);
    setState(() {
      _settings = DeliveryScheduleSettings(
        enabled: _settings.enabled,
        minimumNoticeHours: _settings.minimumNoticeHours,
        slots: _settings.slots,
        closedDates: [..._settings.closedDates, key]..sort(),
      );
    });
  }

  List<WeeklyDeliverySlot> _sortSlots(List<WeeklyDeliverySlot> slots) {
    slots.sort((a, b) {
      final dayOrder = a.weekday.compareTo(b.weekday);
      return dayOrder != 0 ? dayOrder : a.startMinute.compareTo(b.startMinute);
    });
    return slots;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Créneaux de préparation'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.texte,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 40),
                    const SizedBox(height: 12),
                    Text('Impossible de charger le planning.\n$_loadError'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loadSettings,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile.adaptive(
                    value: _settings.enabled,
                    activeColor: AppColors.primaire,
                    title: const Text('Activer les créneaux disponibles'),
                    subtitle: Text(
                      _settings.enabled
                          ? 'Les clients ne pourront choisir que les créneaux configurés.'
                          : 'Le choix actuel de date et d’heure reste utilisé.',
                    ),
                    onChanged: (enabled) {
                      setState(() {
                        _settings = DeliveryScheduleSettings(
                          enabled: enabled,
                          minimumNoticeHours: _settings.minimumNoticeHours,
                          slots: _settings.slots,
                          closedDates: _settings.closedDates,
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Délai de préparation',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noticeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Heures minimum avant le créneau',
                            helperText:
                                'Exemple : 24 heures pour une commande passée la veille.',
                            suffixText: 'h',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Créneaux hebdomadaires',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Ajouter un créneau',
                              onPressed: _editSlot,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_settings.slots.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Aucun créneau configuré. Ajoute les jours et horaires où tu peux préparer des commandes.',
                              style: TextStyle(color: AppColors.secondaire),
                            ),
                          )
                        else
                          for (final slot in _sortSlots([..._settings.slots]))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFEEF3),
                                child: Icon(
                                  Icons.schedule,
                                  color: AppColors.primaire,
                                ),
                              ),
                              title: Text(
                                '${_weekdays[slot.weekday] ?? 'Jour'} · ${slot.timeLabel}',
                              ),
                              subtitle: Text(
                                'Maximum ${slot.capacity} commande${slot.capacity > 1 ? 's' : ''}',
                              ),
                              trailing: Wrap(
                                spacing: 0,
                                children: [
                                  IconButton(
                                    tooltip: 'Modifier',
                                    onPressed: () => _editSlot(slot),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    onPressed: () => setState(() {
                                      _settings = DeliveryScheduleSettings(
                                        enabled: _settings.enabled,
                                        minimumNoticeHours:
                                            _settings.minimumNoticeHours,
                                        slots: _settings.slots
                                            .where((item) => item.id != slot.id)
                                            .toList(),
                                        closedDates: _settings.closedDates,
                                      );
                                    }),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Fermetures exceptionnelles',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Ajouter une fermeture',
                              onPressed: _addClosedDate,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        if (_settings.closedDates.isEmpty)
                          const Text(
                            'Aucune fermeture ponctuelle.',
                            style: TextStyle(color: AppColors.secondaire),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _settings.closedDates.map((dateKey) {
                              final date = DateTime.parse(
                                '${dateKey}T00:00:00',
                              );
                              return InputChip(
                                label: Text(
                                  DateFormat(
                                    'd MMM yyyy',
                                    'fr_FR',
                                  ).format(date),
                                ),
                                onDeleted: () => setState(() {
                                  _settings = DeliveryScheduleSettings(
                                    enabled: _settings.enabled,
                                    minimumNoticeHours:
                                        _settings.minimumNoticeHours,
                                    slots: _settings.slots,
                                    closedDates: _settings.closedDates
                                        .where((item) => item != dateKey)
                                        .toList(),
                                  );
                                }),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'La capacité compte le nombre de commandes, tous modes confondus. Une place reste réservée tant que la commande est en attente ou acceptée ; elle est libérée si la commande est annulée ou refusée.',
                    style: TextStyle(color: AppColors.secondaire, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _saveSettings,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving ? 'Enregistrement…' : 'Enregistrer le planning',
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _DeliverySlotDialog extends StatefulWidget {
  const _DeliverySlotDialog({required this.weekdays, this.existing});

  final Map<int, String> weekdays;
  final WeeklyDeliverySlot? existing;

  @override
  State<_DeliverySlotDialog> createState() => _DeliverySlotDialogState();
}

class _DeliverySlotDialogState extends State<_DeliverySlotDialog> {
  late int _weekday;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late final TextEditingController _capacityController;
  String? _error;

  int _toMinute(TimeOfDay time) => time.hour * 60 + time.minute;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _weekday = existing?.weekday ?? 1;
    _start = existing == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : TimeOfDay(
            hour: existing.startMinute ~/ 60,
            minute: existing.startMinute % 60,
          );
    _end = existing == null
        ? const TimeOfDay(hour: 12, minute: 0)
        : TimeOfDay(
            hour: existing.endMinute ~/ 60,
            minute: existing.endMinute % 60,
          );
    _capacityController = TextEditingController(
      text: '${existing?.capacity ?? 4}',
    );
  }

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _chooseTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      helpText: start ? 'Début du créneau' : 'Fin du créneau',
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  void _submit() {
    final capacity = int.tryParse(_capacityController.text.trim());
    if (_toMinute(_end) <= _toMinute(_start)) {
      setState(
        () => _error = 'L’heure de fin doit être après l’heure de début.',
      );
      return;
    }
    if (capacity == null || capacity < 1 || capacity > 100) {
      setState(
        () =>
            _error = 'La capacité doit être comprise entre 1 et 100 commandes.',
      );
      return;
    }

    Navigator.of(context).pop(
      WeeklyDeliverySlot(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        weekday: _weekday,
        startMinute: _toMinute(_start),
        endMinute: _toMinute(_end),
        capacity: capacity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Nouveau créneau' : 'Modifier le créneau',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              value: _weekday,
              decoration: const InputDecoration(labelText: 'Jour'),
              items: widget.weekdays.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _weekday = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimePickerButton(
                    label: 'Début',
                    time: _start,
                    onTap: () => _chooseTime(start: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimePickerButton(
                    label: 'Fin',
                    time: _end,
                    onTap: () => _chooseTime(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Commandes maximum'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            time.format(context),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
