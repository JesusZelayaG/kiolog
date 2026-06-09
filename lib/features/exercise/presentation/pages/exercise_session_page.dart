// lib/features/exercise/presentation/pages/exercise_session_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/exercise_bloc.dart';
import '../bloc/exercise_event.dart';

class ExerciseSessionPage extends StatefulWidget {
  final int sessionId;
  const ExerciseSessionPage({super.key, required this.sessionId});
  @override
  State<ExerciseSessionPage> createState() => _ExerciseSessionPageState();
}

class _ExerciseSessionPageState extends State<ExerciseSessionPage> {
  @override
  void initState() {
    super.initState();
    context.read<ExerciseBloc>().add(ExerciseSessionResumed(sessionId: widget.sessionId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sesión activa')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
