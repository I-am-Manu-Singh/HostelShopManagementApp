import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatar extends StatelessWidget {
   final String? imageUrl;
   final String? name;
   final double radius;
   final bool verified;
 
   const UserAvatar({
     super.key,
     this.imageUrl,
     this.name,
     this.radius = 20,
     this.verified = false,
   });

  String get _initials {
    if (name == null || name!.trim().isEmpty) return 'T';
    final trimmed = name!.trim();
    final parts = trimmed.split(' ');
    if (parts.length > 1 && parts[0].isNotEmpty && parts[parts.length - 1].isNotEmpty) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && 
                          imageUrl!.isNotEmpty && 
                          imageUrl != 'null' && 
                          imageUrl!.startsWith('http');
    
     return Stack(
       children: [
         if (hasImage) 
           ClipOval(
             child: CachedNetworkImage(
               imageUrl: imageUrl!,
               width: radius * 2,
               height: radius * 2,
               fit: BoxFit.cover,
               errorWidget: (context, url, error) => _initialsWidget(context),
               placeholder: (context, url) => _initialsWidget(context),
             ),
           )
         else
           _initialsWidget(context),
         if (verified)
           Positioned(
             right: 0,
             bottom: 0,
             child: Container(
               padding: const EdgeInsets.all(2),
               decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
               child: Icon(Icons.check, size: radius * 0.4, color: Colors.white),
             ),
           ),
       ],
     );
  }

  Widget _initialsWidget(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Text(
        _initials,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
