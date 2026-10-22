import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sodalite_configurator/integrations/integration_controller.dart';
import 'package:sodalite_configurator/metadata/metadata_controller.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/codec/download.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/persistence/draft_store.dart';
import 'package:sodalite_configurator/ui/editor/editor_page.dart';
import 'package:sodalite_configurator/ui/home/home_page.dart';
import 'package:sodalite_configurator/ui/integrations/integrations_scope.dart';
import 'package:sodalite_configurator/ui/metadata/metadata_scope.dart';

class ConfiguratorApp extends StatefulWidget {
  const ConfiguratorApp({
    super.key,
    this.controller,
    this.download,
    this.pickZipBytes,
    this.pickJsonFiles,
    this.drafts,
  });

  final DocumentController? controller;
  final DownloadFn? download;
  final PickZipBytesFn? pickZipBytes;
  final PickJsonFilesFn? pickJsonFiles;
  final DraftStore? drafts;

  @override
  State<ConfiguratorApp> createState() => _ConfiguratorAppState();
}

class _ConfiguratorAppState extends State<ConfiguratorApp> {
  late final IntegrationController _integrations = IntegrationController();
  late final MetadataController _metadata = MetadataController();

  @override
  void initState() {
    super.initState();
    unawaited(_metadata.restore());
  }

  @override
  void dispose() {
    _integrations.dispose();
    _metadata.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadFn = widget.download ?? downloadBytes;
    return MaterialApp(
      title: 'Sodalite Configurator',
      debugShowCheckedModeBanner: false,
      theme: sodaliteTheme(),
      builder: (context, child) => Integrations(
        controller: _integrations,
        child: MetadataScope(controller: _metadata, child: child ?? const SizedBox.shrink()),
      ),
      home: widget.controller == null
          ? HomePage(
              download: downloadFn,
              pickZipBytes: widget.pickZipBytes,
              pickJsonFiles: widget.pickJsonFiles,
              drafts: widget.drafts,
            )
          : EditorPage(controller: widget.controller!, download: downloadFn),
    );
  }
}
