import 'package:flutter/material.dart';
import 'package:max_gym/l10n/app_localizations.dart';

class AvatarWidget extends StatelessWidget {
  final String? gender;
  final String? name;

  const AvatarWidget({super.key, this.gender, this.name});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isMale = gender?.toLowerCase() == 'male';
    final isFemale = gender?.toLowerCase() == 'female';

    String imagePath;
    String semanticsLabel;

    if (isMale) {
      imagePath = 'assets/images/men.png';
      semanticsLabel = l10n.translate('male_athlete_avatar');
    } else if (isFemale) {
      imagePath = 'assets/images/women.png';
      semanticsLabel = l10n.translate('female_athlete_avatar');
    } else {
      imagePath = 'assets/images/men.png'; // Assumes a default halter image
      semanticsLabel = l10n.translate('default_athlete_avatar');
    }

    return Semantics(
      label: semanticsLabel,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isMale
                // ignore: deprecated_member_use
                ? [Colors.blue, Colors.blue.withOpacity(0.5)]
                : isFemale
                    // ignore: deprecated_member_use
                    ? [Colors.pink, Colors.pink.withOpacity(0.5)]
                    // ignore: deprecated_member_use
                    : [Colors.grey, Colors.grey.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
