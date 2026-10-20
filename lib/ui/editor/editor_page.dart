import 'dart:math' as math;

import 'package:sodalite_configurator/codec/module_codec.dart';
import 'package:sodalite_configurator/integrations/consul_read.dart';
import 'package:sodalite_configurator/integrations/consul_upload.dart';
import 'package:sodalite_configurator/integrations/integration_controller.dart';
import 'package:sodalite_configurator/integrations/integration_exception.dart';
import 'package:sodalite_configurator/ui/integrations/integrations_panel.dart';
import 'package:sodalite_configurator/ui/integrations/integrations_scope.dart';
import 'package:sodalite_configurator/ui/sodalite_buttons.dart';
import 'package:flutter/material.dart';
import 'package:sodalite_configurator/ui/sodalite_help.dart';
import 'package:sodalite_configurator/ui/sodalite_tooltip.dart';
import 'package:sodalite_configurator/ui/design_system.dart';
import 'package:sodalite_configurator/ui/editor/editor_navigation.dart';
import 'package:sodalite_configurator/codec/download.dart';
import 'package:sodalite_configurator/document/document_controller.dart';
import 'package:sodalite_configurator/schema/ids.dart';
import 'package:sodalite_configurator/schema/issue.dart';
import 'package:sodalite_configurator/schema/node.dart';
import 'package:sodalite_configurator/ui/editor/block_card.dart';
import 'package:sodalite_configurator/ui/editor/completeness_panel.dart';
import 'package:sodalite_configurator/ui/editor/editor_section.dart';
import 'package:sodalite_configurator/ui/editor/field_controls.dart';
import 'package:sodalite_configurator/ui/editor/json_preview.dart';
import 'package:sodalite_configurator/ui/editor/panel_divider.dart';
import 'package:sodalite_configurator/ui/editor/slot_add_button.dart';
import 'package:sodalite_configurator/ui/strings.dart';
import 'package:sodalite_configurator/ui/sodalite_dialog.dart';
import 'package:sodalite_configurator/ui/sodalite_toast.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.controller, required this.download, this.ownsController = false});

  final DocumentController controller;
  final DownloadFn download;
  final bool ownsController;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  EditorSection _section = EditorSection.app;
  var _seenUndoEpoch = 0;
  Node? _undoRoot;
  VoidCallback? _dismissUndo;
  bool _showJson = true;
  double _navigationWidth = 256;
  double _inspectorWidth = 340;
  final Map<String, int> _layerTabs = {};
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _seenUndoEpoch = widget.controller.undoEpoch;
    widget.controller.addListener(_onDocument);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Integrations.read(context)?.refreshXsdsIfSignedIn();
    });
  }

  @override
  void dispose() {
    final dismissUndo = _dismissUndo;
    WidgetsBinding.instance.addPostFrameCallback((_) => dismissUndo?.call());
    _scroll.dispose();
    widget.controller.removeListener(_onDocument);
    if (widget.ownsController) {
      widget.controller.dispose();
    }
    super.dispose();
  }

  void _onDocument() {
    if (_undoRoot != null && !identical(_undoRoot, widget.controller.root)) {
      _dismissUndo?.call();
      _dismissUndo = null;
      _undoRoot = null;
    }
    final epoch = widget.controller.undoEpoch;
    if (epoch > _seenUndoEpoch && mounted) {
      final deletedRoot = widget.controller.root;
      _undoRoot = deletedRoot;
      _dismissUndo = SodaliteToast.show(
        context,
        message: UiStrings.removed,
        kind: SodaliteToastKind.info,
        actionLabel: UiStrings.undo,
        onAction: () {
          // Undo restores a document snapshot; never discard subsequent edits.
          if (mounted && identical(widget.controller.root, deletedRoot)) widget.controller.undo();
        },
      );
    }
    _seenUndoEpoch = epoch;
  }

  void _onIssueTap(Issue issue) {
    _focusNode(issue.nodeId);
  }

  void _focusNode(String nodeId) {
    setState(() {
      _section = editorSectionOf(widget.controller.root, nodeId);
      _revealLayerTab(nodeId);
    });
    widget.controller.select(nodeId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _ensureNodeVisible(context, nodeId);
    });
  }

  void _revealLayerTab(String nodeId) {
    final root = widget.controller.root;
    final layers = <Node>[...?root.childrenBySlot['baseLayer'], ...?root.childrenBySlot['additionalLayers']];
    for (final layer in layers) {
      if (layer.find(nodeId) == null) continue;
      final info = layer.childrenBySlot['info']?.firstOrNull;
      final geo = layer.childrenBySlot['geo']?.firstOrNull;
      final style = geo?.childrenBySlot['style']?.firstOrNull;
      _layerTabs[layer.id] = info?.find(nodeId) != null
          ? 2
          : style?.find(nodeId) != null
          ? 1
          : 0;
      return;
    }
  }

  void _selectSection(EditorSection section) {
    setState(() => _section = section);
    widget.controller.select(null);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _selectLayerTab(Node layer, int index) {
    final geo = layer.childrenBySlot['geo']?.firstOrNull;
    final target = switch (index) {
      1 => geo?.childrenBySlot['style']?.firstOrNull,
      2 => layer.childrenBySlot['info']?.firstOrNull,
      _ => geo,
    };
    setState(() => _layerTabs[layer.id] = index);
    // Clear an old descendant selection even when the destination has no block yet.
    widget.controller.select(target?.id ?? layer.id);
  }

  void _openJson() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final section = visibleEditorSections(widget.controller.root).contains(_section)
                ? _section
                : EditorSection.app;
            return JsonPreview(
              filename: editorSectionFileName(section),
              text: editorSectionPreviewText(widget.controller.root, section),
              selectedPath: editorSectionPreviewPath(widget.controller.root, section, widget.controller.selectedId),
              onClose: () => Navigator.pop(context),
            );
          },
        ),
      ),
    );
  }

  Future<void> _export() async {
    if (!widget.controller.canExport) {
      final downloadAnyway = await showSodaliteDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Конфигурация незакончена'),
          content: SizedBox(
            width: 440,
            child: Text(
              'В модуле ещё есть замечания: ${widget.controller.issues.length}. '
              'Такой ZIP нельзя загрузить в Sodalite, пока они не будут исправлены. '
              'Файл можно скачать, чтобы доработать его на другом компьютере.',
            ),
          ),
          actions: [
            SodaliteButton.secondary(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Скачать всё равно'),
            ),
            SodaliteButton.primary(onPressed: () => Navigator.pop(context, false), child: const Text('Доработать')),
          ],
        ),
      );
      if (!mounted) return;
      if (downloadAnyway == true) {
        _downloadZip(allowIncomplete: true);
        return;
      }
      if (downloadAnyway == false) _openIssues();
      return;
    }
    _downloadZip();
  }

  void _downloadZip({bool allowIncomplete = false}) {
    try {
      final bytes = widget.controller.exportZip(allowIncomplete: allowIncomplete);
      final slug = widget.controller.root.fields['slug'] as String? ?? 'module';
      widget.download(filename: '$slug-sodalite-module.zip', bytes: bytes);
    } catch (_) {
      SodaliteToast.show(context, kind: SodaliteToastKind.error, message: 'Не удалось скачать ZIP. Попробуйте ещё раз');
    }
  }

  Future<void> _openIntegrations() {
    return showIntegrationsDialog(context, onUpload: () => _uploadConsul(fromDialog: true));
  }

  Future<void> _uploadConsul({bool fromDialog = false}) async {
    final integrations = Integrations.read(context);
    if (integrations == null) return;
    if (!integrations.settings.consulReady) {
      integrations.explain('Чтобы загрузить модуль, укажите URL и Token Consul.');
      if (!fromDialog && mounted) await _openIntegrations();
      return;
    }
    if (!widget.controller.canExport) {
      final fix = await showSodaliteDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('В Consul только готовый модуль'),
          content: SizedBox(
            width: 440,
            child: Text(
              'В модуле ещё есть замечания: ${widget.controller.issues.length}. '
              'Исправьте их и повторите загрузку. ZIP по-прежнему можно скачать.',
            ),
          ),
          actions: [
            SodaliteButton.secondary(onPressed: () => Navigator.pop(context, false), child: const Text('Закрыть')),
            SodaliteButton.primary(onPressed: () => Navigator.pop(context, true), child: const Text('Доработать')),
          ],
        ),
      );
      if (fix == true && mounted) _openIssues();
      return;
    }
    final files = encodeModule(widget.controller.root);
    final confirmed = await showSodaliteDialog<bool>(
      context: context,
      builder: (context) => _ConsulUploadDialog(integrations: integrations, files: files),
    );
    if (confirmed != true || !mounted) return;
    try {
      await integrations.uploadToConsul(files);
      if (!mounted) return;
      SodaliteToast.show(context, message: 'Модуль записан в Consul');
    } on IntegrationException catch (error) {
      if (!mounted) return;
      SodaliteToast.show(context, kind: SodaliteToastKind.error, message: error.message);
    }
  }

  void _openIssues() {
    widget.controller.revealIssues();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => CompletenessPanel(
              issues: widget.controller.issues,
              catalog: widget.controller.catalog,
              root: widget.controller.root,
              onClose: () => Navigator.of(context).pop(),
              onIssueTap: (issue) {
                Navigator.of(context).pop();
                _onIssueTap(issue);
              },
            ),
          ),
        );
      },
    );
  }

  void _addSection(EditorSection section) {
    switch (section) {
      case EditorSection.objectCreation:
        widget.controller.enableObjectCreation();
      case EditorSection.search:
        widget.controller.enableSearch();
      case EditorSection.app:
      case EditorSection.baseLayer:
      case EditorSection.additionalLayers:
        break;
    }
    _selectSection(section);
  }

  Future<void> _disableSection(EditorSection section) async {
    await confirmDisableFeature(
      context,
      onConfirm: () {
        if (_section == section) {
          setState(() => _section = EditorSection.app);
        }
        switch (section) {
          case EditorSection.objectCreation:
            widget.controller.disableObjectCreation();
          case EditorSection.search:
            widget.controller.disableSearch();
          case EditorSection.app:
          case EditorSection.baseLayer:
          case EditorSection.additionalLayers:
            break;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final width = MediaQuery.sizeOf(context).width;
        final compactBar = width < 700;
        final wide = width >= 1100;
        final inlineJson = width >= 1250;
        final integrations = Integrations.read(context);
        const minWorkspaceWidth = 400.0;
        final sideSpacing =
            (wide ? 16.0 : 0.0) +
            (inlineJson && _showJson ? 40.0 : 0.0); // Visible dividers and the right outer padding.
        final navigationMax = math.max(
          224.0,
          math.min(560.0, width - minWorkspaceWidth - (inlineJson && _showJson ? 300.0 + sideSpacing : 16.0)),
        );
        final navigationWidth = wide ? _navigationWidth.clamp(224.0, navigationMax) : 0.0;
        final inspectorMax = inlineJson
            ? math.max(300.0, math.min(800.0, width - navigationWidth - sideSpacing - minWorkspaceWidth))
            : 300.0;
        final inspectorWidth = _inspectorWidth.clamp(300.0, inspectorMax);
        final visible = visibleEditorSections(controller.root);
        final section = visible.contains(_section) ? _section : EditorSection.app;
        final app = controller.root.childrenBySlot['app']?.firstOrNull;
        final title = app?.fields['title'];
        final slug = controller.root.fields['slug'] as String? ?? '';
        final selectionPath = editorSelectionPath(controller.root, section, controller.selectedId, controller.catalog);
        Widget navigation({bool drawer = false}) => EditorNavigation(
          controller: controller,
          selected: section,
          onSelect: (value) {
            if (drawer) Navigator.pop(context);
            _selectSection(value);
          },
          onAdd: (value) {
            if (drawer) Navigator.pop(context);
            _addSection(value);
          },
          onNodeTap: (id) {
            if (drawer) Navigator.pop(context);
            _focusNode(id);
          },
        );
        final workspace = Scaffold(
          drawer: wide
              ? null
              : Drawer(
                  semanticLabel: 'Разделы модуля',
                  width: 288,
                  child: SafeArea(child: navigation(drawer: true)),
                ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: wide
                ? null
                : Builder(
                    builder: (context) => SodaliteIconButton(
                      tooltip: 'Разделы модуля',
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
            titleSpacing: wide ? 24 : 0,
            title: Row(
              children: [
                if (Navigator.of(context).canPop()) ...[
                  SodaliteIconButton(
                    tooltip: 'К модулям',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title is String && title.trim().isNotEmpty ? title : 'Новый модуль',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (!compactBar)
                        Text(
                          slug,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (compactBar)
                SodaliteIconButton(
                  key: const Key('issuesMenu'),
                  tooltip: controller.visibleIssues.isEmpty
                      ? 'Проверить модуль'
                      : UiStrings.issuesCount(controller.visibleIssues.length),
                  onPressed: _openIssues,
                  icon: Badge(
                    isLabelVisible: controller.visibleIssues.isNotEmpty,
                    label: Text('${controller.visibleIssues.length}'),
                    child: const Icon(Icons.checklist),
                  ),
                )
              else
                SodaliteButton.ghost(
                  key: const Key('issuesMenu'),
                  onPressed: _openIssues,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        controller.canExport ? Icons.check_circle_outline : Icons.checklist_rounded,
                        size: 18,
                        color: controller.canExport ? SodaliteColors.success : SodaliteColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        controller.canExport
                            ? 'Готов к экспорту'
                            : controller.visibleIssues.isEmpty
                            ? 'Проверить'
                            : UiStrings.issuesCount(controller.visibleIssues.length),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              SodaliteIconButton(
                key: const Key('toggleJson'),
                tooltip: inlineJson ? (_showJson ? 'Скрыть JSON' : 'Показать JSON') : 'Показать JSON',
                isSelected: inlineJson && _showJson,
                style: IconButton.styleFrom(foregroundColor: inlineJson && _showJson ? SodaliteColors.accent : null),
                onPressed: inlineJson ? () => setState(() => _showJson = !_showJson) : _openJson,
                icon: Icon(inlineJson ? Icons.view_sidebar_outlined : Icons.data_object),
              ),
              if (integrations != null)
                ListenableBuilder(
                  listenable: integrations,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SodaliteIconButton(
                        key: const Key('openIntegrations'),
                        tooltip: 'Интеграции',
                        onPressed: _openIntegrations,
                        icon: const Icon(Icons.cable_outlined),
                      ),
                      if (wide)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: SodaliteButton.secondary(
                            key: const Key('uploadConsulToolbar'),
                            onPressed: integrations.busyUpload ? null : () => _uploadConsul(),
                            child: const Text('В Consul'),
                          ),
                        ),
                    ],
                  ),
                ),
              if (controller.draftSaveState != DraftSaveState.unavailable)
                _DraftSaveStatus(controller: controller, compact: compactBar),
              Padding(
                padding: EdgeInsets.only(left: 8, right: compactBar ? 12 : 24),
                child: SodaliteTooltip(
                  message: 'Проверить и скачать конфигурацию модуля',
                  child: SodaliteButton.primary(
                    key: const Key('exportZip'),
                    style: compactBar
                        ? FilledButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.all(12))
                        : null,
                    onPressed: _export,
                    child: compactBar
                        ? const Icon(Icons.download, size: 20, semanticLabel: UiStrings.downloadZip)
                        : const Text(UiStrings.downloadZip),
                  ),
                ),
              ),
            ],
          ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    if (selectionPath != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(compactBar ? 16 : 32, 18, compactBar ? 16 : 32, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SodaliteTooltip(
                            message: selectionPath,
                            child: Text(
                              selectionPath,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      key: const ValueKey('editor-form'),
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(
                          compactBar ? 16 : 32,
                          selectionPath == null ? (compactBar ? 16 : 32) : 16,
                          compactBar ? 16 : 32,
                          compactBar ? 16 : 32,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (controller.draftSaveState == DraftSaveState.failed) ...[
                                  _DraftSaveFailure(onRetry: controller.retryDraftSave),
                                  const SizedBox(height: 24),
                                ],
                                if (controller.hasImportNotes) ...[
                                  _ImportNotesBanner(controller: controller),
                                  const SizedBox(height: 24),
                                ],
                                Text(editorSectionLabel(section), style: Theme.of(context).textTheme.headlineMedium),
                                const SizedBox(height: 8),
                                Text(
                                  sectionDescription(section),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(color: SodaliteColors.secondary),
                                ),
                                const SizedBox(height: 28),
                                _sectionCanvas(controller, section),
                                const SizedBox(height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: SodaliteColors.icon),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Поля со\u00a0звёздочкой обязательны',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (inlineJson && _showJson) ...[
                PanelDivider(
                  label: 'Ширина правой панели',
                  onDelta: (delta) =>
                      setState(() => _inspectorWidth = (inspectorWidth - delta).clamp(300.0, inspectorMax)),
                  onReset: () => setState(() => _inspectorWidth = 340),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                  child: SizedBox(
                    width: inspectorWidth,
                    child: JsonPreview(
                      text: editorSectionPreviewText(controller.root, section),
                      filename: editorSectionFileName(section),
                      selectedPath: editorSectionPreviewPath(controller.root, section, controller.selectedId),
                      embedded: true,
                      onClose: () => setState(() => _showJson = false),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
        return HelpScope(
          child: Row(
            children: [
              if (wide) ...[
                SizedBox(width: navigationWidth, child: navigation()),
                PanelDivider(
                  label: 'Ширина дерева модуля',
                  headerHeight: 80,
                  onDelta: (delta) => setState(
                    () => _navigationWidth = (navigationWidth + delta).clamp(
                      224.0,
                      math.min(
                        navigationMax,
                        width - minWorkspaceWidth - (inlineJson && _showJson ? inspectorWidth + sideSpacing : 16.0),
                      ),
                    ),
                  ),
                  onReset: () => setState(() => _navigationWidth = 256),
                ),
              ],
              Expanded(child: workspace),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionCanvas(DocumentController controller, EditorSection section) {
    final root = controller.root;
    return switch (section) {
      EditorSection.app => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            key: Key('node-${root.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FieldControls(
                    node: root,
                    fields: controller.catalog.type(root.typeId).fields,
                    controller: controller,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          BlockCard(node: root.childrenBySlot['app']!.single, controller: controller),
        ],
      ),
      EditorSection.baseLayer => _layerCard(root.childrenBySlot['baseLayer']!.single),
      EditorSection.additionalLayers => _AdditionalLayersCanvas(controller: controller, buildLayerCard: _layerCard),
      EditorSection.objectCreation => BlockCard(
        node: root.childrenBySlot['objectCreation']!.single,
        controller: controller,
        onRemove: () => _disableSection(EditorSection.objectCreation),
      ),
      EditorSection.search => BlockCard(
        node: root.childrenBySlot['search']!.single,
        controller: controller,
        onRemove: () => _disableSection(EditorSection.search),
      ),
    };
  }

  Widget _layerCard(Node layer, {VoidCallback? onRemove, VoidCallback? onMoveUp, VoidCallback? onMoveDown}) {
    final isBase = widget.controller.root.childrenBySlot['baseLayer']?.firstOrNull?.id == layer.id;
    final tabs = _LayerTabs(
      layer: layer,
      controller: widget.controller,
      selected: _layerTabs[layer.id] ?? 0,
      onSelect: (index) => _selectLayerTab(layer, index),
      trailing: isBase
          ? SodaliteIconButton(
              tooltip: UiStrings.duplicateLayer,
              onPressed: () => widget.controller.duplicateLayer(layer.id),
              icon: const Icon(Icons.copy_outlined, size: 20),
            )
          : null,
    );
    if (isBase) {
      return Card(
        key: Key('node-${layer.id}'),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), child: tabs),
      );
    }
    return BlockCard(
      node: layer,
      controller: widget.controller,
      visibleSlots: const <String>{},
      onRemove: onRemove,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      footer: tabs,
    );
  }
}

class _AdditionalLayersCanvas extends StatelessWidget {
  const _AdditionalLayersCanvas({required this.controller, required this.buildLayerCard});

  final DocumentController controller;
  final Widget Function(Node, {VoidCallback? onRemove, VoidCallback? onMoveUp, VoidCallback? onMoveDown})
  buildLayerCard;

  @override
  Widget build(BuildContext context) {
    final root = controller.root;
    final children = root.childrenBySlot['additionalLayers'] ?? const <Node>[];
    final slot = controller.catalog
        .type(TypeIds.moduleBundle)
        .slots
        .firstWhere((item) => item.key == 'additionalLayers');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.layers_outlined, size: 40, color: SodaliteColors.icon),
                    const SizedBox(height: 16),
                    Text(
                      'Пока только базовый слой',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Добавьте ещё один слой, если нужно показать другие объекты на\u00a0карте',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        for (var index = 0; index < children.length; index++)
          Padding(
            key: ValueKey(children[index].id),
            padding: const EdgeInsets.only(bottom: 16),
            child: buildLayerCard(
              children[index],
              onRemove: () => controller.removeNode(children[index].id),
              onMoveUp: index > 0 ? () => controller.moveChild(children[index].id, offset: -1) : null,
              onMoveDown: index < children.length - 1
                  ? () => controller.moveChild(children[index].id, offset: 1)
                  : null,
            ),
          ),
        SlotAddButton(parentId: root.id, slot: slot, catalog: controller.catalog, controller: controller),
      ],
    );
  }
}

class _LayerTabs extends StatefulWidget {
  const _LayerTabs({
    required this.layer,
    required this.controller,
    required this.selected,
    required this.onSelect,
    this.trailing,
  });

  final Node layer;
  final DocumentController controller;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget? trailing;

  @override
  State<_LayerTabs> createState() => _LayerTabsState();
}

class _LayerTabsState extends State<_LayerTabs> {
  final _tabFocus = List.generate(3, (_) => FocusNode());
  Node get layer => widget.layer;
  DocumentController get controller => widget.controller;
  int get selected => widget.selected;
  Widget? get trailing => widget.trailing;

  @override
  void dispose() {
    for (final focus in _tabFocus) {
      focus.dispose();
    }
    super.dispose();
  }

  void _select(int index) {
    widget.onSelect(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tabFocus[index].requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final geo = layer.childrenBySlot['geo']?.firstOrNull;
    final style = geo?.childrenBySlot['style']?.firstOrNull;
    final info = layer.childrenBySlot['info']?.firstOrNull;
    final issues = controller.visibleIssues;
    final counts = [
      issues.where((issue) => geo?.find(issue.nodeId) != null && style?.find(issue.nodeId) == null).length,
      issues.where((issue) => style?.find(issue.nodeId) != null).length,
      issues.where((issue) => info?.find(issue.nodeId) != null).length,
    ];
    final labels = [UiStrings.pathLabel('geo'), UiStrings.pathLabel('style'), UiStrings.pathLabel('info')];
    final content = switch (selected) {
      1 =>
        style != null
            ? BlockCard(node: style, controller: controller, depth: 1)
            : geo == null
            ? const Text('Сначала добавьте геоданные')
            : SlotAddButton(
                parentId: geo.id,
                slot: controller.catalog.type(geo.typeId).slots.firstWhere((slot) => slot.key == 'style'),
                catalog: controller.catalog,
                controller: controller,
              ),
      2 =>
        info != null
            ? BlockCard(node: info, controller: controller, depth: 1)
            : SlotAddButton(
                parentId: layer.id,
                slot: controller.catalog.type(layer.typeId).slots.firstWhere((slot) => slot.key == 'info'),
                catalog: controller.catalog,
                controller: controller,
              ),
      _ =>
        geo == null
            ? const Text('Геоданные не найдены')
            : BlockCard(node: geo, controller: controller, depth: 1, visibleSlots: const {'sources'}),
    };
    final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    final tabDuration = reduceMotion ? Duration.zero : const Duration(milliseconds: 250);
    const tabEase = Cubic(0.22, 1, 0.36, 1);
    final labelStyle = Theme.of(context).textTheme.bodyMedium!;
    final countStyle = Theme.of(context).textTheme.bodySmall!;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: textScaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final tabWidths = [
      for (var index = 0; index < labels.length; index++)
        (textWidth(labels[index], labelStyle.copyWith(fontWeight: FontWeight.w600)) +
                (counts[index] > 0 ? textWidth('${counts[index]}', countStyle) + 6 : 0) +
                28)
            .clamp(72.0, double.infinity),
    ];
    final indicatorLeft = 4 + tabWidths.take(selected).fold<double>(0, (sum, width) => sum + width);
    final groupWidth = 8 + tabWidths.fold<double>(0, (sum, width) => sum + width);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: groupWidth,
                      height: 40,
                      decoration: BoxDecoration(color: SodaliteColors.canvas, borderRadius: BorderRadius.circular(14)),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: tabDuration,
                            curve: tabEase,
                            left: indicatorLeft,
                            top: 4,
                            bottom: 4,
                            width: tabWidths[selected],
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: SodaliteColors.surface,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned.fill(
                            left: 4,
                            right: 4,
                            child: Row(
                              children: [
                                for (var index = 0; index < labels.length; index++)
                                  SizedBox(
                                    width: tabWidths[index],
                                    child: Semantics(
                                      selected: selected == index,
                                      child: TextButton(
                                        focusNode: _tabFocus[index],
                                        onPressed: () => _select(index),
                                        style:
                                            TextButton.styleFrom(
                                              minimumSize: const Size(0, 40),
                                              padding: const EdgeInsets.symmetric(horizontal: 14),
                                              foregroundColor: SodaliteColors.secondary,
                                              textStyle: labelStyle,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                                            ).copyWith(
                                              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                                              side: WidgetStateProperty.resolveWith(
                                                (states) => BorderSide(
                                                  color: states.contains(WidgetState.focused)
                                                      ? SodaliteColors.accentStrong
                                                      : Colors.transparent,
                                                  width: 1.5,
                                                ),
                                              ),
                                            ),
                                        child: AnimatedDefaultTextStyle(
                                          duration: tabDuration,
                                          curve: tabEase,
                                          style: labelStyle.copyWith(
                                            color: selected == index ? SodaliteColors.text : SodaliteColors.secondary,
                                            fontWeight: selected == index ? FontWeight.w600 : FontWeight.w400,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(labels[index], maxLines: 1),
                                              if (counts[index] > 0) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${counts[index]}',
                                                  style: countStyle.copyWith(color: SodaliteColors.errorText),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }
}

class _DraftSaveFailure extends StatelessWidget {
  const _DraftSaveFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SodaliteColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: SodaliteColors.errorText),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 20, color: SodaliteColors.errorText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Черновик не записался в этот браузер. Данные есть на экране, но после обновления страницы могут пропасть.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            SodaliteButton.secondary(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

class _DraftSaveStatus extends StatelessWidget {
  const _DraftSaveStatus({required this.controller, required this.compact});

  final DocumentController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = controller.draftSaveState;
    if (state == DraftSaveState.failed) {
      return SodaliteTooltip(
        message: 'Не удалось сохранить черновик в этом браузере. Повторить',
        child: SodaliteButton.ghost(
          onPressed: controller.retryDraftSave,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh, size: 18, color: SodaliteColors.errorText),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  'Не удалось сохранить',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.errorText),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final saving = state == DraftSaveState.pending || state == DraftSaveState.saving;
    return Semantics(
      liveRegion: true,
      label: saving ? 'Черновик сохраняется' : 'Черновик сохранён',
      child: SodaliteTooltip(
        message: saving ? 'Сохраняется в этом браузере' : 'Сохранено в этом браузере',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (saving)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.check_circle_outline, size: 18, color: SodaliteColors.success),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  saving ? 'Сохраняется…' : 'Сохранено',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SodaliteColors.secondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportNotesBanner extends StatelessWidget {
  const _ImportNotesBanner({required this.controller});

  final DocumentController controller;

  @override
  Widget build(BuildContext context) {
    final lines = [
      ...controller.importErrors,
      for (final warning in controller.importWarnings) '${warning.file}: ${warning.message}',
    ];
    return Material(
      key: const Key('importWarningsBanner'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(UiStrings.importNotesHeading, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final line in lines) Text(line),
          ],
        ),
      ),
    );
  }
}

void _ensureNodeVisible(BuildContext context, String nodeId) {
  final targetKey = Key('node-$nodeId');
  Element? match;
  void visit(Element element) {
    if (match != null) {
      return;
    }
    if (element.widget.key == targetKey) {
      match = element;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildElements(visit);
  final found = match;
  if (found != null) {
    Scrollable.ensureVisible(found, alignment: 0.1, duration: const Duration(milliseconds: 200));
  }
}

class _ConsulUploadDialog extends StatefulWidget {
  const _ConsulUploadDialog({required this.integrations, required this.files});

  final IntegrationController integrations;
  final ModuleFiles files;

  @override
  State<_ConsulUploadDialog> createState() => _ConsulUploadDialogState();
}

class _ConsulUploadDialogState extends State<_ConsulUploadDialog> {
  ConsulFolderSnapshot? _current;
  String? _readError;
  var _checking = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final current = await widget.integrations.inspectConsulModule(widget.files.slug);
      if (!mounted) return;
      setState(() {
        _current = current;
        _checking = false;
      });
    } on IntegrationException catch (error) {
      if (!mounted) return;
      setState(() {
        _readError = error.message;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _readError = 'Не удалось прочитать текущую папку.';
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.files;
    final removed = removedConsulFiles(files);
    final removal = removed.isEmpty ? '' : ' Если ${removed.join(' и ')} уже есть в Consul, они будут удалены.';
    final contour = widget.integrations.activeContourName;
    final where = contour == null
        ? widget.integrations.settings.consulUrl.trim()
        : 'контур «$contour», ${widget.integrations.settings.consulUrl.trim()}';
    final current = _current;
    final existing = _checking
        ? 'Смотрим, что уже лежит в apps/${files.slug}/…'
        : _readError != null
        ? 'Текущую папку прочитать не удалось. $_readError Запись всё равно заменит файлы по этому пути.'
        : current == null
        ? 'Папки apps/${files.slug}/ в Consul пока нет.'
        : 'Сейчас там${current.title == null ? '' : ' «${current.title}»'}. Файлы: ${current.files.join(', ')}. Запись заменит их.';
    return AlertDialog(
      title: const Text('Загрузить в Consul'),
      content: SizedBox(
        width: 440,
        child: Text(
          'Модуль ${files.slug} будет записан в $where по пути apps/${files.slug}/. '
          'Файлы: ${writtenConsulFiles(files).join(', ')}.$removal '
          'Запись идёт одним сохранением. $existing',
        ),
      ),
      actions: [
        SodaliteButton.secondary(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        SodaliteButton.primary(
          onPressed: _checking ? null : () => Navigator.pop(context, true),
          child: const Text('Загрузить'),
        ),
      ],
    );
  }
}
