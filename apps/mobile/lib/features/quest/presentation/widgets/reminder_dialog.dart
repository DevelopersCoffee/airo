import 'package:flutter/material.dart';

/// Dialog to create a reminder from AI response
class ReminderDialog extends StatefulWidget {
  final String questId;
  final String suggestedTitle;
  final String suggestedDescription;
  final Function(
    String title,
    String description,
    DateTime time,
    bool recurring,
  )
  onCreateReminder;

  const ReminderDialog({
    super.key,
    required this.questId,
    required this.suggestedTitle,
    required this.suggestedDescription,
    required this.onCreateReminder,
  });

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime _selectedTime = DateTime.now().add(const Duration(days: 1));
  bool _isRecurring = false;
  String _recurringPattern = 'daily';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.suggestedTitle);
    _descriptionController = TextEditingController(
      text: widget.suggestedDescription,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedTime),
      );

      if (time != null) {
        setState(() {
          _selectedTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Reminder Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Date/Time picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Scheduled Time'),
              subtitle: Text(
                '${_selectedTime.day}/${_selectedTime.month}/${_selectedTime.year} '
                '${_selectedTime.hour.toString().padLeft(2, '0')}:'
                '${_selectedTime.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDateTime,
            ),
            const SizedBox(height: 16),

            // Recurring toggle
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recurring Reminder'),
              value: _isRecurring,
              onChanged: (value) {
                setState(() => _isRecurring = value ?? false);
              },
            ),

            // Recurring pattern dropdown
            if (_isRecurring)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<String>(
                  initialValue: _recurringPattern,
                  decoration: InputDecoration(
                    labelText: 'Repeat',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    setState(() => _recurringPattern = value ?? 'daily');
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onCreateReminder(
              _titleController.text,
              _descriptionController.text,
              _selectedTime,
              _isRecurring,
            );
            Navigator.pop(context);
          },
          child: const Text('Create Reminder'),
        ),
      ],
    );
  }
}
