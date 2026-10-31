import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/time/addis_time.dart';
import '../core/time/kickoff_status.dart';

/// Asks before dropping a spot and spells out the 25-point penalty inside the
/// three-hour window. Waiting-list places are never penalised.
Future<bool> confirmLeaveMatch(
  BuildContext context, {
  required DateTime startsAt,
  bool waitlisted = false,
}) async {
  final late = !waitlisted && isLateCancelWindow(startsAt);
  final kickoff = DateFormat('HH:mm').format(addisWall(startsAt));

  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: late
          ? Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(dialogContext).colorScheme.error,
            )
          : null,
      title: Text(late ? 'Leave this late?' : 'Leave this match?'),
      content: Text(
        waitlisted
            ? 'You give up your place in line; confirmed players are unaffected.'
            : late
            ? 'Kickoff is at $kickoff $eatLabel, less than 3 hours away. '
                  'Leaving a confirmed spot now costs 25 reliability points. '
                  'Your spot goes to the next player on the waiting list.'
            : 'Your spot goes to the next player on the waiting list.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Stay'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(late ? 'Leave anyway' : 'Leave'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

String leaveDoneMessage({required bool late}) => late
    ? 'You left the match. 25 points came off your reliability score.'
    : 'You left the match.';
