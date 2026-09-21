import 'package:flutter/material.dart';
import 'package:sodalite_configurator/codec/download.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/ui/editor/editor_page.dart';
import 'package:sodalite_configurator/ui/home/home_page.dart';

class ConfiguratorApp extends StatelessWidget {
  const ConfiguratorApp({super.key, this.controller, this.download, this.pickZipBytes});

  final DocumentController? controller;
  final DownloadFn? download;
  final PickZipBytesFn? pickZipBytes;

  @override
  Widget build(BuildContext context) {
    final downloadFn = download ?? downloadBytes;
    return MaterialApp(
      title: 'Sodalite Configurator',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B4C7E))),
      home: controller == null
          ? HomePage(download: downloadFn, pickZipBytes: pickZipBytes)
          : EditorPage(controller: controller!, download: downloadFn),
    );
  }
}
