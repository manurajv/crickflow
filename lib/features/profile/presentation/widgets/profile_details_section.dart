import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/player_profile_labels.dart';
import '../../../../data/models/user_model.dart';
import '../edit_profile_options.dart';

class ProfileDetailsSection extends StatelessWidget {
  const ProfileDetailsSection({
    super.key,
    required this.user,
    required this.isOwnProfile,
  });

  final UserModel user;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final rows = <_DetailRow>[
      _DetailRow('Gender', PlayerProfileLabels.gender(user)),
      _DetailRow('Date of Birth', PlayerProfileLabels.dateOfBirth(user)),
      _DetailRow('Playing Role', PlayerProfileLabels.playingRole(user)),
      _DetailRow('Batting Style', PlayerProfileLabels.battingStyle(user)),
      _DetailRow('Bowling Style', PlayerProfileLabels.bowlingStyle(user)),
      _DetailRow(
        'Dominant Hand',
        user.strongHand != null
            ? EditProfileOptions.dominantHandLabel(user.strongHand!)
            : '—',
      ),
      _DetailRow('Country', PlayerProfileLabels.country(user)),
      if (user.location.district.isNotEmpty)
        _DetailRow('District', user.location.district),
      _DetailRow('City', PlayerProfileLabels.city(user)),
    ];

    if (isOwnProfile) {
      rows.addAll([
        _DetailRow('Email', user.email.isNotEmpty ? user.email : '—'),
        _DetailRow(
          'Phone Number',
          user.effectiveMobile.isNotEmpty ? user.effectiveMobile : '—',
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Profile Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cf.textPrimary,
                    ),
              ),
            ),
            if (isOwnProfile)
              TextButton.icon(
                onPressed: () => context.push('/profile/edit'),
                icon: Icon(Icons.edit_outlined, size: 18, color: cf.accent),
                label: Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: cf.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),
        ...rows.map(
          (row) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm + 2,
            ),
            decoration: cfCardDecoration(context),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    row.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cf.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    row.value,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cf.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
}
