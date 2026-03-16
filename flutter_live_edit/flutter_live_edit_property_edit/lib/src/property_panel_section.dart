import 'package:flutter/material.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';

double _asDouble(final Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

Object? _coerceValueForProperty(
  final LiveEditPropertyDescriptor property,
  final String value,
) {
  switch (property.kind) {
    case LiveEditPropertyKind.integer:
      return int.tryParse(value) ?? property.value;
    case LiveEditPropertyKind.number:
      return double.tryParse(value) ?? property.value;
    case LiveEditPropertyKind.boolean:
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    case LiveEditPropertyKind.string:
    case LiveEditPropertyKind.color:
    case LiveEditPropertyKind.enumValue:
    case LiveEditPropertyKind.edgeInsets:
    case LiveEditPropertyKind.alignment:
    case LiveEditPropertyKind.bounds:
    case LiveEditPropertyKind.object:
      return value;
  }
}

String _persistLabel(
  final LiveEditPropertyDescriptor property,
  final LiveEditContext ctx,
  final LiveEditController controller,
) =>
    property.requiresAgentForPersistence
        ? selectCurrentBackendLabel(
            ctx,
            controller,
            presentationDomain: selectPresentedLayer(ctx),
          )
        : property.persistable
            ? 'Direct'
            : 'Preview only';

Color _previewColor(final LiveEditPropertyDescriptor property) {
  if (property.requiresAgentForPersistence) return const Color(0xFF7C2D12);
  if (property.canPreviewExactly) return const Color(0xFF065F46);
  return const Color(0xFF92400E);
}

String _previewLabel(final LiveEditPropertyDescriptor property) {
  if (property.requiresAgentForPersistence) return 'AI only';
  if (property.canPreviewExactly) return 'Live';
  return 'Preview';
}

String _semanticsId(final String value) =>
    value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

String _propertySubtitle(
  final LiveEditPropertyDescriptor property,
  final Object? value,
) {
  final resolved = '$value'.isEmpty ? 'unset' : '$value';
  final editor = property.preferredEditor.isEmpty
      ? property.kind.wireName
      : property.preferredEditor;
  return '$resolved • $editor';
}

class _PropertyBadge extends StatelessWidget {
  const _PropertyBadge({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.captureSurfaceKey = false,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final bool captureSurfaceKey;

  @override
  Widget build(final BuildContext context) {
    final theme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditStatusBadgeSurfaceId,
    );
    final badge = Container(
      padding: theme.padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(theme.cornerRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
    if (!captureSurfaceKey) return badge;
    return KeyedSubtree(
      key: LiveEditOverlayThemeModel.instance.keyFor(
        kLiveEditStatusBadgeSurfaceId,
      ),
      child: badge,
    );
  }
}

class _PropertyActionColumn extends StatelessWidget {
  const _PropertyActionColumn({
    required this.ctx,
    required this.controller,
    required this.property,
    required this.surface,
  });

  final LiveEditContext ctx;
  final LiveEditController controller;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  Widget build(final BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      if (surface == LiveEditEditSurface.panel) ...<Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          onPressed: () {
            if (property.requiresAgentForPersistence) {
              OpenAiBubbleCommand(
                property: property,
                defaultPrompt: '',
              ).execute(ctx);
            } else {
              FocusPropertyCommand(
                property: property,
                defaultPrompt: '',
              ).execute(ctx);
            }
          },
          icon: Icon(
            property.requiresAgentForPersistence
                ? Icons.smart_toy_outlined
                : Icons.ads_click_outlined,
          ),
        ),
      ],
    ],
  );
}

class _PropertyEditor extends StatelessWidget {
  const _PropertyEditor({
    required this.ctx,
    required this.controller,
    required this.property,
    required this.surface,
  });

  final LiveEditContext ctx;
  final LiveEditController controller;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  Widget build(final BuildContext context) {
    final presentationDomain = selectPresentedLayer(ctx);
    final waiting = selectIsPropertyWaiting(
      ctx,
      controller,
      property,
      presentationDomain: presentationDomain,
    );
    if (!property.editable) {
      return Text(
        '${property.value ?? 'Not editable'}',
        style: const TextStyle(fontSize: 11),
      );
    }
    if (property.requiresAgentForPersistence &&
        surface == LiveEditEditSurface.inline) {
      return Row(
        children: <Widget>[
          const Expanded(
            child: Text('Use Apply', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onPressed: () => OpenAiBubbleCommand(
              property: property,
              defaultPrompt: '',
            ).execute(ctx),
            child: const Text('AI', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }
    final effectiveValue = selectEffectiveValueForProperty(
      ctx,
      controller,
      property,
      presentationDomain: presentationDomain,
    );
    if (property.kind == LiveEditPropertyKind.boolean) {
      final current = effectiveValue == true;
      return Align(
        alignment: Alignment.centerLeft,
        child: Switch(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          value: current,
          onChanged: waiting
              ? null
              : (final value) => UpdateDraftFromUiCommand(
                    property: property,
                    targetValue: value,
                    surface: surface,
                  ).execute(ctx),
        ),
      );
    }
    if (property.options.isNotEmpty ||
        property.kind == LiveEditPropertyKind.enumValue) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[
          for (final option in property.options)
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: const TextStyle(fontSize: 11),
              label: Text(option),
              selected: option == '$effectiveValue',
              onSelected: waiting
                  ? null
                  : (_) => UpdateDraftFromUiCommand(
                        property: property,
                        targetValue: option,
                        surface: surface,
                      ).execute(ctx),
            ),
        ],
      );
    }
    if (property.kind == LiveEditPropertyKind.integer ||
        property.kind == LiveEditPropertyKind.number) {
      return _NumericEditor(
        ctx: ctx,
        controller: controller,
        property: property,
        surface: surface,
      );
    }
    if (property.kind == LiveEditPropertyKind.string) {
      final multiline =
          property.prefersMultiline && surface == LiveEditEditSurface.panel;
      return _TextValueEditor(
        ctx: ctx,
        controller: controller,
        property: property,
        surface: surface,
        multiline: multiline,
      );
    }
    return Text(
      '${property.value ?? 'Unsupported inline editor'}',
      style: const TextStyle(fontSize: 12),
    );
  }
}

class _PropertyEditorCard extends StatelessWidget {
  const _PropertyEditorCard({
    required this.ctx,
    required this.controller,
    required this.property,
    required this.surface,
  });

  final LiveEditContext ctx;
  final LiveEditController controller;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  Widget build(final BuildContext context) {
    final presentationDomain = selectPresentedLayer(ctx);
    final domain = ctx.sessionResource.value.targetDomain;
    final rowTheme = LiveEditOverlayThemeModel.instance.styleFor(
      kLiveEditPropertyEditorRowSurfaceId,
    );
    final isActive = selectActivePropertyId(ctx, domain: domain) == property.id;
    final disabled = !property.editable;
    final effectiveValue = selectEffectiveValueForProperty(
      ctx,
      controller,
      property,
      presentationDomain: presentationDomain,
    );

    final cardChild = Ink(
      padding: rowTheme.padding,
      decoration: BoxDecoration(
        color: isActive ? rowTheme.backgroundColor : Colors.white,
        borderRadius: BorderRadius.circular(rowTheme.cornerRadius),
        border: Border.all(
          color: isActive ? const Color(0xFF0EA5E9) : rowTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: surface == LiveEditEditSurface.panel ? 78 : 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      property.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _propertySubtitle(property, effectiveValue),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF475569),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: rowTheme.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: <Widget>[
                        _PropertyBadge(
                          label: _previewLabel(property),
                          textColor: _previewColor(property),
                          backgroundColor:
                              _previewColor(property).withValues(alpha: 0.12),
                          captureSurfaceKey: isActive,
                        ),
                        _PropertyBadge(
                          label: _persistLabel(property, ctx, controller),
                          textColor: property.requiresAgentForPersistence
                              ? const Color(0xFF7C2D12)
                              : const Color(0xFF1D4ED8),
                          backgroundColor: property.requiresAgentForPersistence
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFDBEAFE),
                        ),
                        if (selectHasDraftForProperty(
                          ctx,
                          controller,
                          property,
                          presentationDomain: presentationDomain,
                        ))
                          _PropertyBadge(
                            label: selectIsPropertyWaiting(
                              ctx,
                              controller,
                              property,
                              presentationDomain: presentationDomain,
                            )
                                ? 'Waiting'
                                : 'Dirty',
                            textColor: selectIsPropertyWaiting(
                              ctx,
                              controller,
                              property,
                              presentationDomain: presentationDomain,
                            )
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF0F766E),
                            backgroundColor: selectIsPropertyWaiting(
                              ctx,
                              controller,
                              property,
                              presentationDomain: presentationDomain,
                            )
                                ? const Color(0xFFDBEAFE)
                                : const Color(0xFFCCFBF1),
                          ),
                      ],
                    ),
                    SizedBox(height: rowTheme.gap),
                    if (surface == LiveEditEditSurface.panel)
                      Semantics(
                        identifier:
                            'live_edit_property_input_${_semanticsId(property.id)}',
                        child: _PropertyEditor(
                          ctx: ctx,
                          controller: controller,
                          property: property,
                          surface: surface,
                        ),
                      )
                    else
                      _PropertyEditor(
                        ctx: ctx,
                        controller: controller,
                        property: property,
                        surface: surface,
                      ),
                  ],
                ),
              ),
              SizedBox(width: rowTheme.gap),
              _PropertyActionColumn(
                ctx: ctx,
                controller: controller,
                property: property,
                surface: surface,
              ),
            ],
          ),
        ],
      ),
    );

    final card = InkWell(
      onTap: disabled
          ? null
          : () {
              if (surface == LiveEditEditSurface.aiBubble ||
                  property.requiresAgentForPersistence) {
                OpenAiBubbleCommand(
                  property: property,
                  defaultPrompt: '',
                ).execute(ctx);
              } else {
                FocusPropertyCommand(
                  property: property,
                  defaultPrompt: '',
                ).execute(ctx);
              }
            },
      borderRadius: BorderRadius.circular(14),
      child: surface == LiveEditEditSurface.panel
          ? Semantics(
              identifier: 'live_edit_property_${_semanticsId(property.id)}',
              child: cardChild,
            )
          : cardChild,
    );
    if (surface == LiveEditEditSurface.panel && isActive) {
      return KeyedSubtree(
        key: LiveEditOverlayThemeModel.instance.keyFor(
          kLiveEditPropertyEditorRowSurfaceId,
        ),
        child: card,
      );
    }
    return card;
  }
}

class _NumericEditor extends StatefulWidget {
  const _NumericEditor({
    required this.ctx,
    required this.controller,
    required this.property,
    required this.surface,
  });

  final LiveEditContext ctx;
  final LiveEditController controller;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;

  @override
  State<_NumericEditor> createState() => _NumericEditorState();
}

class _NumericEditorState extends State<_NumericEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: '${widget.property.value ?? ''}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyDelta(final double delta) {
    final presentationDomain = selectPresentedLayer(widget.ctx);
    final base = _asDouble(
      selectEffectiveValueForProperty(
        widget.ctx,
        widget.controller,
        widget.property,
        presentationDomain: presentationDomain,
      ),
    );
    final next = base + delta;
    final targetValue = widget.property.kind == LiveEditPropertyKind.integer
        ? next.round()
        : next;
    UpdateDraftFromUiCommand(
      property: widget.property,
      targetValue: targetValue,
      surface: widget.surface,
    ).execute(widget.ctx);
  }

  void _submit(final String value) {
    UpdateDraftFromUiCommand(
      property: widget.property,
      targetValue: _coerceValueForProperty(widget.property, value.trim()),
      surface: widget.surface,
    ).execute(widget.ctx);
  }

  @override
  Widget build(final BuildContext context) {
    final presentationDomain = selectPresentedLayer(widget.ctx);
    final text =
        '${selectEffectiveValueForProperty(
          widget.ctx,
          widget.controller,
          widget.property,
          presentationDomain: presentationDomain,
        ) ?? ''}';
    final waiting = selectIsPropertyWaiting(
      widget.ctx,
      widget.controller,
      widget.property,
      presentationDomain: presentationDomain,
    );
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return Row(
      children: <Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 14,
          onPressed: waiting ? null : () => _applyDelta(-widget.property.numericStep),
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: widget.surface == LiveEditEditSurface.inline,
            enableInteractiveSelection: true,
            enabled: !waiting,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onSubmitted: _submit,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 14,
          onPressed: waiting ? null : () => _applyDelta(widget.property.numericStep),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _TextValueEditor extends StatefulWidget {
  const _TextValueEditor({
    required this.ctx,
    required this.controller,
    required this.property,
    required this.surface,
    required this.multiline,
  });

  final LiveEditContext ctx;
  final LiveEditController controller;
  final LiveEditPropertyDescriptor property;
  final LiveEditEditSurface surface;
  final bool multiline;

  @override
  State<_TextValueEditor> createState() => _TextValueEditorState();
}

class _TextValueEditorState extends State<_TextValueEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: '${widget.property.value ?? ''}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(final String value) {
    UpdateDraftFromUiCommand(
      property: widget.property,
      targetValue: _coerceValueForProperty(widget.property, value.trim()),
      surface: widget.surface,
    ).execute(widget.ctx);
  }

  @override
  Widget build(final BuildContext context) {
    final presentationDomain = selectPresentedLayer(widget.ctx);
    final text =
        '${selectEffectiveValueForProperty(
          widget.ctx,
          widget.controller,
          widget.property,
          presentationDomain: presentationDomain,
        ) ?? ''}';
    final waiting = selectIsPropertyWaiting(
      widget.ctx,
      widget.controller,
      widget.property,
      presentationDomain: presentationDomain,
    );
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    return TextField(
      controller: _controller,
      autofocus: widget.surface == LiveEditEditSurface.inline,
      enableInteractiveSelection: true,
      enabled: !waiting,
      maxLines: widget.multiline ? 4 : 1,
      minLines: widget.multiline ? 3 : 1,
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        hintText: widget.multiline
            ? 'Edit value here without leaving the panel'
            : 'Edit inline',
      ),
      onChanged: (final value) {
        UpdateDraftFromUiCommand(
          property: widget.property,
          targetValue: _coerceValueForProperty(widget.property, value.trim()),
          surface: widget.surface,
        ).execute(widget.ctx);
      },
      onSubmitted: _submit,
      onEditingComplete: () => _submit(_controller.text),
    );
  }
}

/// Builds the Properties panel section widget. Use as
/// [FlutterLiveEditHost.buildPropertyPanelSection] when the plugin is installed.
Widget buildPropertyPanelSection(
  final LiveEditContext context,
  final LiveEditController controller,
) {
  final presentationDomain = selectPresentedLayer(context);
  final properties = selectEffectiveProperties(
    context,
    controller,
    domain: presentationDomain,
  );
  return Column(
    children: <Widget>[
      if (selectHasMultiSelection(
        context,
        controller,
        presentationDomain: presentationDomain,
      ) && properties.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'No shared editable properties for this selection.',
            style: TextStyle(fontSize: 11),
          ),
        ),
      for (final property in properties)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _PropertyEditorCard(
            ctx: context,
            controller: controller,
            property: property,
            surface: LiveEditEditSurface.panel,
          ),
        ),
    ],
  );
}
