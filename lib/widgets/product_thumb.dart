import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/inventory.dart';
import '../state/app_state.dart';
import '../utils/product_image.dart';

/// صورة مصغّرة للصنف. عند تمرير [onTap] تظهر علامة رفع/تغيير الصورة.
class ProductThumb extends StatelessWidget {
  final Product? product;
  final double size;
  final VoidCallback? onTap;
  const ProductThumb({super.key, this.product, this.size = 48, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final image = product?.image;
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: cs.surfaceContainerHighest,
        child: image != null
            ? Image.memory(
                productImageBytes(image),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            : Icon(
                onTap == null
                    ? Icons.inventory_2_outlined
                    : Icons.add_a_photo_outlined,
                size: size * 0.45,
                color: cs.onSurfaceVariant,
              ),
      ),
    );
    if (onTap == null) return box;
    return Tooltip(
      message: image == null ? 'رفع صورة الصنف' : 'تغيير صورة الصنف',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            box,
            if (image != null)
              PositionedDirectional(
                end: -4,
                bottom: -4,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: cs.primary,
                  child: Icon(Icons.edit, size: 12, color: cs.onPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// يختار صورة من الجهاز ويحفظها مع الصنف، ويعرض رسالة بالنتيجة.
Future<void> uploadProductImage(BuildContext context, Product product) async {
  final s = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final image = await pickProductImage();
    if (image == null) return;
    await s.saveProduct(product.withImage(image));
    messenger.showSnackBar(
      SnackBar(content: Text('تم حفظ صورة "${product.name}"')),
    );
  } on FormatException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
