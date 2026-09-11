// lib/widgets/badge_updater.dart

import 'package:flutter/material.dart';
import '../models/demande_aide_model.dart';
import '../services/demande_aide_service.dart';
import '../utils/badge_helper.dart';

class BadgeUpdater extends StatefulWidget {
  final String userId;
  final Widget child;

  const BadgeUpdater({
    super.key,
    required this.userId,
    required this.child,
  });

  @override
  State<BadgeUpdater> createState() => _BadgeUpdaterState();
}

class _BadgeUpdaterState extends State<BadgeUpdater> {
  final _service = DemandeAideService();

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _service.getAllDemandes().listen((demandes) {
      final count =
          demandes.where((d) => !d.luPar.contains(widget.userId)).length;
      BadgeHelper.updateBadge(count);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}