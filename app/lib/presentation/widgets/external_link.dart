import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openExternalUrl(BuildContext context, String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link inválido.')),
      );
    }
    return;
  }
  final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o link.')),
    );
  }
}
