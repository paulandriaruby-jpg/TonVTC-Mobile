import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

// selfie : appareil photo de face (photo du chauffeur montrée aux clients).
enum PickSource { camera, selfie, gallery, file }

class PickedDocument {
  const PickedDocument({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
}

// Choix d'un fichier sur le téléphone : appareil photo, galerie ou PDF. Remplaçable dans les tests.
abstract class DocumentPicker {
  Future<PickedDocument?> pick(PickSource source);
}

class DevicePicker implements DocumentPicker {
  final _images = ImagePicker();

  @override
  Future<PickedDocument?> pick(PickSource source) async {
    if (source == PickSource.file) {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
      return file == null ? null : PickedDocument(bytes: await file.readAsBytes(), filename: file.name);
    }
    // Réduite à 2200 px : lisible et bien en dessous des 8 Mo acceptés par le serveur (1200 px pour un portrait).
    final portrait = source == PickSource.selfie;
    final image = await _images.pickImage(
      source: source == PickSource.gallery ? ImageSource.gallery : ImageSource.camera,
      preferredCameraDevice: portrait ? CameraDevice.front : CameraDevice.rear,
      maxWidth: portrait ? 1200 : 2200,
      maxHeight: portrait ? 1200 : 2200,
      imageQuality: 85,
    );
    return image == null ? null : PickedDocument(bytes: await image.readAsBytes(), filename: image.name);
  }
}
