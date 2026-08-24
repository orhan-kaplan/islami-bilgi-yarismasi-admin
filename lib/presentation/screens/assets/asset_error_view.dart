import 'package:flutter/material.dart';

import '../../../data/services/asset_server_client.dart';

/// Bir asset server hatasını kullanıcıya gösterilecek metne çevirir.
///
/// Sunucu kapalıyken `AssetServerClient` [AssetServerException] değil,
/// `ClientException` / `TimeoutException` atıyor. Sekmeler yalnız ilkini
/// yakaladığı için bağlantı hataları hiçbir yere yazılmıyor, buton ölü
/// görünüyordu.
String assetErrorMessage(Object error) {
  if (error is AssetServerException) {
    return error.message;
  }
  return 'Could not reach the asset server. Make sure it is running, '
      'then try again.';
}

/// Bağlantı yokken devre dışı kalan bir kontrole nedenini söyleyen sarmalayıcı.
class OfflineTooltip extends StatelessWidget {
  const OfflineTooltip({
    super.key,
    required this.isConnected,
    required this.child,
  });

  final bool isConnected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isConnected) return child;
    return Tooltip(
      message: 'Asset server is not connected',
      child: child,
    );
  }
}

/// Yüklenemeyen bir küçük görselin yerini tutan etiketli placeholder.
///
/// Çıplak bir `broken_image` ikonu hem bozuk dosyayı hem ulaşılamayan
/// sunucuyu aynı şekilde gösteriyor, kullanıcıya hiçbir şey söylemiyordu.
class AssetThumbnailError extends StatelessWidget {
  const AssetThumbnailError({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 4),
              Text(
                'Failed to load',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir dizin listelenemediğinde gösterilen hata durumu.
///
/// Ham `ClientException: Failed to fetch, uri=...` dökümü bir hata durumu
/// sayılmaz; ne olduğunu söylemesi ve yeniden denemeye izin vermesi gerekir.
class AssetErrorView extends StatelessWidget {
  const AssetErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              assetErrorMessage(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
