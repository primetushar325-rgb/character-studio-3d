import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'repositories/character_repository.dart';
import 'repositories/project_repository.dart';
import 'services/animation_service.dart';
import 'services/character_service.dart';
import 'services/export_service.dart';
import 'services/glb_parser_service.dart';
import 'services/gltf_converter_service.dart';
import 'services/storage_service.dart';
import 'services/thumbnail_service.dart';
import 'services/viewer_server_service.dart';
import 'state/export_provider.dart';
import 'state/library_provider.dart';
import 'state/projects_provider.dart';
import 'state/settings_provider.dart';
import 'state/shell_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---- local bootstrap (all on-device, no network) ----------------------
  final storage = StorageService();
  await storage.init();

  final appDocs = await getApplicationDocumentsDirectory();

  final characterService = CharacterService(
    parser: GlbParserService(),
    converter: GltfConverterService(),
  )..configure(appDocs);

  final charactersDir = characterService.charactersDir!;

  final thumbnailService = ThumbnailService(charactersDir);

  final characterRepository = CharacterRepository(
    storage: storage,
    service: characterService,
    thumbnails: thumbnailService,
  );
  await characterRepository.initialize();

  // The loopback server that serves the offline 3D engine + models.
  ViewerServerService.instance.configureCharactersDirectory(charactersDir);
  final pendingDir = characterService.pendingDir;
  if (pendingDir != null) {
    ViewerServerService.instance.configurePendingDirectory(pendingDir);
  }
  await ViewerServerService.instance.start();

  final exportService = ExportService();
  final settingsProvider = SettingsProvider(storage);
  final libraryProvider = LibraryProvider(
    repository: characterRepository,
    settings: settingsProvider,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        Provider<CharacterRepository>.value(value: characterRepository),
        Provider<AnimationService>.value(value: const AnimationService()),
        ChangeNotifierProvider.value(value: settingsProvider..load()),
        ChangeNotifierProvider.value(value: libraryProvider..refresh()),
        ChangeNotifierProvider(
          create: (_) => ProjectsProvider(ProjectRepository())..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => ExportProvider(exportService),
        ),
        ChangeNotifierProvider(create: (_) => ShellProvider()),
      ],
      child: const CharacterStudioApp(),
    ),
  );
}
