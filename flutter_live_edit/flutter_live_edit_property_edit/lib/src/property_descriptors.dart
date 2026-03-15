import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

double? _finiteDimension(final double? value) {
  if (value == null || !value.isFinite) return null;
  return value;
}

Map<String, Object?> _alignmentJson(final AlignmentGeometry geometry) {
  final resolved = geometry.resolve(TextDirection.ltr);
  return <String, Object?>{'x': resolved.x, 'y': resolved.y};
}

Map<String, Object?> _edgeInsetsJson(final EdgeInsetsGeometry geometry) {
  final resolved = geometry.resolve(TextDirection.ltr);
  return <String, Object?>{
    'left': resolved.left,
    'top': resolved.top,
    'right': resolved.right,
    'bottom': resolved.bottom,
  };
}

String _colorHex(final Color color) {
  final value = color.toARGB32();
  return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

LiveEditBounds? _boundsForRenderObject(final RenderObject? renderObject) {
  if (renderObject == null || !renderObject.attached) return null;
  if (renderObject is RenderBox) {
    if (!renderObject.hasSize) return null;
    final origin = renderObject.localToGlobal(ui.Offset.zero);
    final rect = origin & renderObject.size;
    return LiveEditBounds(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      width: rect.width,
      height: rect.height,
    );
  }
  try {
    final rect = MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      renderObject.paintBounds,
    );
    return LiveEditBounds(
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      width: rect.width,
      height: rect.height,
    );
  } on Exception {
    return null;
  }
}

/// Builds property descriptors for the given element. Used as the
/// [LiveEditController.propertyDescriptorProvider] when the plugin is installed.
List<LiveEditPropertyDescriptor> buildPropertyDescriptors(
  final Element element,
  final LiveEditTargetDomain targetDomain,
) {
  final widget = element.widget;
  final renderObject = element.renderObject;
  final descriptors = <LiveEditPropertyDescriptor>[];

  void add(final LiveEditPropertyDescriptor descriptor) {
    final normalizedMeta = <String, Object?>{
      ...descriptor.meta,
      if (!descriptor.meta.containsKey('editSurface'))
        'editSurface': descriptor.requiresAgentForPersistence
            ? LiveEditEditSurface.aiBubble.wireName
            : descriptor.options.isNotEmpty ||
                  descriptor.kind == LiveEditPropertyKind.boolean ||
                  descriptor.kind == LiveEditPropertyKind.enumValue
            ? LiveEditEditSurface.inline.wireName
            : LiveEditEditSurface.panel.wireName,
      if (!descriptor.meta.containsKey('editor'))
        'editor': switch (descriptor.kind) {
          LiveEditPropertyKind.boolean => 'toggle',
          LiveEditPropertyKind.integer ||
          LiveEditPropertyKind.number => 'number',
          LiveEditPropertyKind.string => 'text',
          LiveEditPropertyKind.enumValue => 'options',
          _ when descriptor.options.isNotEmpty => 'options',
          _ => 'readonly',
        },
      if (!descriptor.meta.containsKey('selectionUi') &&
          descriptor.options.isNotEmpty)
        'selectionUi': 'chips',
      if (!descriptor.meta.containsKey('step') &&
          (descriptor.kind == LiveEditPropertyKind.integer ||
              descriptor.kind == LiveEditPropertyKind.number))
        'step': descriptor.kind == LiveEditPropertyKind.integer ? 1 : 1.0,
    };
    descriptors.add(
      LiveEditPropertyDescriptor(
        id: descriptor.id,
        label: descriptor.label,
        group: descriptor.group,
        kind: descriptor.kind,
        value: descriptor.value,
        options: descriptor.options,
        editable: descriptor.editable,
        previewMode: descriptor.previewMode,
        persistable: descriptor.persistable,
        canPreviewExactly:
            descriptor.canPreviewExactly ||
            descriptor.previewMode == LiveEditPreviewMode.exact,
        requiresAgentForPersistence:
            descriptor.requiresAgentForPersistence ||
            (descriptor.persistable &&
                descriptor.previewMode != LiveEditPreviewMode.exact),
        safeToAutoGroupInApply:
            descriptor.safeToAutoGroupInApply || descriptor.editable,
        meta: normalizedMeta,
      ),
    );
  }

  if (widget is SizedBox) {
    add(LiveEditPropertyDescriptor(
      id: 'width',
      label: 'Width',
      group: LiveEditPropertyGroup.layout,
      kind: LiveEditPropertyKind.number,
      value: widget.width,
      editable: true,
      previewMode: LiveEditPreviewMode.ghost,
      persistable: true,
    ));
    add(LiveEditPropertyDescriptor(
      id: 'height',
      label: 'Height',
      group: LiveEditPropertyGroup.layout,
      kind: LiveEditPropertyKind.number,
      value: widget.height,
      editable: true,
      previewMode: LiveEditPreviewMode.ghost,
      persistable: true,
    ));
  }

  if (widget is Container) {
    final width = _finiteDimension(widget.constraints?.maxWidth);
    final height = _finiteDimension(widget.constraints?.maxHeight);
    add(LiveEditPropertyDescriptor(
      id: 'width',
      label: 'Width',
      group: LiveEditPropertyGroup.layout,
      kind: LiveEditPropertyKind.number,
      value: width,
      editable: true,
      previewMode: LiveEditPreviewMode.ghost,
      persistable: true,
    ));
    add(LiveEditPropertyDescriptor(
      id: 'height',
      label: 'Height',
      group: LiveEditPropertyGroup.layout,
      kind: LiveEditPropertyKind.number,
      value: height,
      editable: true,
      previewMode: LiveEditPreviewMode.ghost,
      persistable: true,
    ));
    if (widget.padding != null) {
      add(LiveEditPropertyDescriptor(
        id: 'padding',
        label: 'Padding',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.edgeInsets,
        value: _edgeInsetsJson(widget.padding!),
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ));
    }
    if (widget.alignment != null) {
      add(LiveEditPropertyDescriptor(
        id: 'alignment',
        label: 'Alignment',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.alignment,
        value: _alignmentJson(widget.alignment!),
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ));
    }
    if (widget.color != null) {
      add(LiveEditPropertyDescriptor(
        id: 'color',
        label: 'Color',
        group: LiveEditPropertyGroup.style,
        kind: LiveEditPropertyKind.color,
        value: _colorHex(widget.color!),
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ));
    }
  }

  if (widget is Padding) {
    add(LiveEditPropertyDescriptor(
      id: 'padding',
      label: 'Padding',
      group: LiveEditPropertyGroup.layout,
      kind: LiveEditPropertyKind.edgeInsets,
      value: _edgeInsetsJson(widget.padding),
      editable: true,
      previewMode: LiveEditPreviewMode.ghost,
      persistable: true,
    ));
  }

  if (widget is Align) {
    add(LiveEditPropertyDescriptor(
      id: 'alignment',
      label: 'Alignment',
      group: LiveEditPropertyGroup.layout,
      kind: LiveEditPropertyKind.alignment,
      value: _alignmentJson(widget.alignment),
      editable: true,
      previewMode: LiveEditPreviewMode.ghost,
      persistable: true,
    ));
  }

  if (widget is ColoredBox) {
    add(LiveEditPropertyDescriptor(
      id: 'color',
      label: 'Color',
      group: LiveEditPropertyGroup.style,
      kind: LiveEditPropertyKind.color,
      value: _colorHex(widget.color),
      editable: true,
      previewMode: LiveEditPreviewMode.ghost,
      persistable: true,
    ));
  }

  if (widget is Text) {
    add(LiveEditPropertyDescriptor(
      id: 'text',
      label: 'Text',
      group: LiveEditPropertyGroup.content,
      kind: LiveEditPropertyKind.string,
      value: widget.data ?? widget.textSpan?.toPlainText(),
      editable: true,
      previewMode: LiveEditPreviewMode.exact,
      persistable: true,
      meta: <String, Object?>{
        'editor': 'text',
        'editSurface': LiveEditEditSurface.inline.wireName,
        'multiline': ((widget.data ?? widget.textSpan?.toPlainText()) ?? '')
            .contains('\n'),
      },
    ));
    if (widget.style?.fontSize != null) {
      add(LiveEditPropertyDescriptor(
        id: 'fontSize',
        label: 'Font Size',
        group: LiveEditPropertyGroup.style,
        kind: LiveEditPropertyKind.number,
        value: widget.style?.fontSize,
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ));
    }
    if (widget.style?.color != null) {
      add(LiveEditPropertyDescriptor(
        id: 'textColor',
        label: 'Text Color',
        group: LiveEditPropertyGroup.style,
        kind: LiveEditPropertyKind.color,
        value: _colorHex(widget.style!.color!),
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ));
    }
  }

  if (widget is RichText) {
    final plainText = widget.text.toPlainText();
    add(LiveEditPropertyDescriptor(
      id: 'text',
      label: 'Text',
      group: LiveEditPropertyGroup.content,
      kind: LiveEditPropertyKind.string,
      value: plainText,
      editable: true,
      previewMode: LiveEditPreviewMode.exact,
      persistable: true,
      meta: <String, Object?>{
        'editor': 'text',
        'editSurface': LiveEditEditSurface.inline.wireName,
        'multiline': plainText.contains('\n'),
      },
    ));
    final textStyle = widget.text.style;
    if (textStyle?.fontSize != null) {
      add(LiveEditPropertyDescriptor(
        id: 'fontSize',
        label: 'Font Size',
        group: LiveEditPropertyGroup.style,
        kind: LiveEditPropertyKind.number,
        value: textStyle?.fontSize,
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ));
    }
    if (textStyle?.color != null) {
      add(LiveEditPropertyDescriptor(
        id: 'textColor',
        label: 'Text Color',
        group: LiveEditPropertyGroup.style,
        kind: LiveEditPropertyKind.color,
        value: _colorHex(textStyle!.color!),
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ));
    }
  }

  final parentData = renderObject?.parentData;
  if (parentData is FlexParentData) {
    add(LiveEditPropertyDescriptor(
      id: 'flexFactor',
      label: 'Flex',
      group: LiveEditPropertyGroup.layout,
      kind: LiveEditPropertyKind.integer,
      value: parentData.flex,
      editable: true,
      previewMode: LiveEditPreviewMode.exact,
      persistable: true,
    ));
    add(LiveEditPropertyDescriptor(
      id: 'flexFit',
      label: 'Flex Fit',
      group: LiveEditPropertyGroup.layout,
      kind: LiveEditPropertyKind.enumValue,
      value: parentData.fit?.name ?? 'tight',
      options: const <String>['tight', 'loose'],
      editable: true,
      previewMode: LiveEditPreviewMode.exact,
      persistable: true,
    ));
  }

  if (renderObject is RenderFlex) {
    add(LiveEditPropertyDescriptor(
      id: 'mainAxisAlignment',
      label: 'Main Axis',
      group: LiveEditPropertyGroup.layout,
      kind: LiveEditPropertyKind.enumValue,
      value: renderObject.mainAxisAlignment.name,
      options: MainAxisAlignment.values
          .map((final value) => value.name)
          .toList(growable: false),
      editable: true,
      previewMode: LiveEditPreviewMode.exact,
      persistable: true,
    ));
    add(LiveEditPropertyDescriptor(
      id: 'crossAxisAlignment',
      label: 'Cross Axis',
      group: LiveEditPropertyGroup.layout,
      kind: LiveEditPropertyKind.enumValue,
      value: renderObject.crossAxisAlignment.name,
      options: CrossAxisAlignment.values
          .map((final value) => value.name)
          .toList(growable: false),
      editable: true,
      previewMode: LiveEditPreviewMode.exact,
      persistable: true,
    ));
  }

  final bounds = _boundsForRenderObject(renderObject);
  if (bounds != null) {
    add(LiveEditPropertyDescriptor(
      id: 'bounds',
      label: 'Bounds',
      group: LiveEditPropertyGroup.diagnostics,
      kind: LiveEditPropertyKind.bounds,
      value: bounds.toJson(),
    ));
  }

  return descriptors;
}
