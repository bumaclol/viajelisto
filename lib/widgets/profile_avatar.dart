import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.photo,
    this.radius = 48,
  });

  final String? name;
  final String? photo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = decodeProfilePhoto(photo);
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE7F0FF),
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes == null
          ? Text(
              profileInitial(name),
              style: TextStyle(
                color: blue,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.72,
              ),
            )
          : null,
    );
  }
}

Uint8List? decodeProfilePhoto(String? photo) {
  if (photo == null || photo.isEmpty) return null;
  try {
    return base64Decode(photo);
  } catch (_) {
    return null;
  }
}

String profileInitial(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}
