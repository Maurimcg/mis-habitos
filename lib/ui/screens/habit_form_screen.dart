import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/habit_icons.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/habit_repository.dart';
import '../app_scope.dart';
import '../widgets/habit_widgets.dart';

/// Pantalla 3: crear o editar un hábito.
class HabitFormScreen extends StatefulWidget {
  const HabitFormScreen({super.key, this.habit});

  /// Hábito a editar; `null` para crear uno nuevo.
  final Habit? habit;

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.habit?.name ?? '');
  late final TextEditingController _goal = TextEditingController(
    text: '${widget.habit?.weeklyGoal ?? 3}',
  );
  late int _colorIndex = widget.habit?.colorIndex ?? 0;
  late String _icon = widget.habit?.icon ?? 'spa';
  String? _duplicateError;
  bool _saving = false;

  bool get _isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    // Redibuja la vista previa mientras se escribe.
    _name.addListener(_onChanged);
    _goal.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _duplicateError = null);

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    super.dispose();
  }

  /// Reglas de validación de la meta semanal (requisito del diseño original).
  static String? validateGoal(String? value) {
    final goal = int.tryParse(value?.trim() ?? '');
    if (goal == null || goal < 1 || goal > 7) return 'Debe estar entre 1 y 7';
    return null;
  }

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Escribe un nombre';
    if (name.length > 40) return 'Máximo 40 caracteres';
    return null;
  }

  void _stepGoal(int delta) {
    final current = int.tryParse(_goal.text) ?? 0;
    final next = (current + delta).clamp(1, 7);
    _goal.text = '$next';
    _goal.selection = TextSelection.collapsed(offset: _goal.text.length);
    HapticFeedback.selectionClick();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = AppScope.of(context).habits;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final name = _name.text;
      final goal = int.parse(_goal.text);
      if (_isEditing) {
        await repo.update(
          id: widget.habit!.id,
          name: name,
          weeklyGoal: goal,
          colorIndex: _colorIndex,
          icon: _icon,
        );
      } else {
        await repo.create(name: name, weeklyGoal: goal, colorIndex: _colorIndex, icon: _icon);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Cambios guardados' : '«${HabitRepository.cleanName(name)}» agregado',
          ),
        ),
      );
    } on DuplicateHabitNameException {
      setState(() => _duplicateError = 'Ya tienes un hábito con ese nombre');
      _formKey.currentState!.validate();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = HabitColors.of(context);
    final color = colors.color(_colorIndex);
    final goal = int.tryParse(_goal.text);
    final validGoal = validateGoal(_goal.text) == null ? goal! : null;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 20),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar hábito' : 'Nuevo hábito')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            // Vista previa en vivo.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    HabitAvatar(icon: habitIcon(_icon), color: color, progress: 0),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name.text.trim().isEmpty ? 'Tu hábito' : _name.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            validGoal == null ? 'Meta semanal por definir' : '0/$validGoal días',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            label('Nombre'),
            TextFormField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              maxLength: 40,
              decoration: const InputDecoration(hintText: 'Ej. Meditar', counterText: ''),
              validator: (value) => validateName(value) ?? _duplicateError,
            ),

            label('Meta semanal (1 a 7)'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Menos días',
                  onPressed: () => _stepGoal(-1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    key: const Key('goalField'),
                    controller: _goal,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(suffixText: 'días'),
                    validator: validateGoal,
                    onFieldSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 10),
                _StepButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Más días',
                  onPressed: () => _stepGoal(1),
                ),
              ],
            ),

            label('Color'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < colors.palette.length; i++)
                  _ColorChoice(
                    color: colors.palette[i],
                    onColor: colors.onPalette[i],
                    name: HabitColors.names[i],
                    selected: i == _colorIndex,
                    onTap: () => setState(() => _colorIndex = i),
                  ),
              ],
            ),

            label('Ícono'),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final entry in habitIcons.entries)
                  _IconChoice(
                    icon: entry.value,
                    color: color,
                    selected: entry.key == _icon,
                    onTap: () => setState(() => _icon = entry.key),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Guardar'),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 58,
      height: 58,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.onColor,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final Color onColor;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color $name',
      excludeSemantics: true,
      child: Tooltip(
        message: name,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? scheme.onSurface : Colors.transparent, width: 2),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: selected ? Icon(Icons.check_rounded, size: 20, color: onColor) : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? color.withValues(alpha: 0.16) : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? color : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(child: Icon(icon, color: selected ? color : scheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}
