import 'dart:io';
import 'package:flutter/material.dart';

class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({super.key, this.photo = '', this.radius = 22});
  final String photo;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipOval(child: SizedBox(width: radius * 2, height: radius * 2,
    child: photo.isEmpty ? Icon(Icons.person_outline_rounded, size: radius * 1.4)
      : Image.file(File(photo), fit: BoxFit.cover, cacheWidth: (radius * 6).round(),
          errorBuilder: (_, error, stack) => Icon(Icons.person_outline_rounded, size: radius * 1.4))));
}

