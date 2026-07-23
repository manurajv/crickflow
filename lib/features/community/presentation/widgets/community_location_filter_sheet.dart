import 'package:flutter/material.dart';

import '../../../../data/models/location_filter_selection.dart';
import '../../../../shared/widgets/location_filter_sheet.dart';

/// Community feed location filter — shared sheet with community-specific copy.
Future<List<LocationFilterSelection>?> showCommunityLocationFilterSheet(
  BuildContext context, {
  required List<LocationFilterSelection> initial,
}) {
  return showLocationFilterSheet(
    context,
    initial: initial,
    subtitle:
        'Search or use GPS, then add locations. Posts matching any selection '
        'are shown. Clear city/province fields to broaden a filter.',
  );
}
