import 'package:flutter/material.dart';

import 'orgs_directory_screen.dart';
import '../../../data/models/series/series.dart';

/// Legacy entry — Series family directory (Orgs).
class SeriesListScreen extends StatelessWidget {
  const SeriesListScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const OrgsDirectoryScreen(family: OrgFamily.series);
}
