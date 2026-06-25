import 'package:flutter/material.dart';
import 'package:elefit_app/theme/app_theme.dart';

class AdminParticipantDetailScreen extends StatelessWidget {
  final String participantId;
  const AdminParticipantDetailScreen({Key? key, required this.participantId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Participant Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Text('Admin Participant Detail: $participantId', style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
