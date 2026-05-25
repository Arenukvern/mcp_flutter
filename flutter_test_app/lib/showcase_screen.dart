// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:test_app/agent_state.dart';
import 'package:test_app/platform_view_showcase.dart';

/// Showcase page for MCP Flutter — a single-page demonstration of every
/// built-in interaction tool.
///
/// The design is deliberately restrained: type and whitespace do the work,
/// sections are flat, and every interactive widget has a Semantics
/// identifier named after the agent-facing action it supports.
class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      AgentState.instance.greeting = _textController.text;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AnimatedBuilder(
              animation: AgentState.instance,
              builder: (final context, final _) => ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 48,
                ),
                children: const <Widget>[
                  _Header(),
                  SizedBox(height: 56),
                  _CaptureSection(),
                  SizedBox(height: 64),
                  _TapSection(),
                  SizedBox(height: 56),
                  _TypeSection(),
                  SizedBox(height: 56),
                  _ToggleSection(),
                  SizedBox(height: 56),
                  _SlideSection(),
                  SizedBox(height: 56),
                  _ScrollSection(),
                  SizedBox(height: 56),
                  _IterateSection(),
                  SizedBox(height: 56),
                  _DebugSection(),
                  SizedBox(height: 96),
                  _Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Design tokens
// -----------------------------------------------------------------------------

const Color _kBackground = Color(0xFFFAFAFA);
const Color _kInk = Color(0xFF1C1C1E);
const Color _kMuted = Color(0xFF6B6B70);
const Color _kFaint = Color(0xFFE5E5EA);
const Color _kAccent = Color(0xFF007AFF);

const TextStyle _kDisplay = TextStyle(
  color: _kInk,
  fontSize: 34,
  fontWeight: FontWeight.w300,
  letterSpacing: -0.6,
  height: 1.15,
);

const TextStyle _kHeading = TextStyle(
  color: _kInk,
  fontSize: 20,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.2,
);

const TextStyle _kBody = TextStyle(
  color: _kInk,
  fontSize: 15,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

const TextStyle _kLabel = TextStyle(
  color: _kMuted,
  fontSize: 11,
  fontWeight: FontWeight.w500,
  letterSpacing: 1.4,
);

const TextStyle _kHint = TextStyle(
  color: _kMuted,
  fontSize: 13,
  fontWeight: FontWeight.w400,
  fontFamily: 'Menlo',
  height: 1.5,
);

const TextStyle _kValue = TextStyle(
  color: _kInk,
  fontSize: 28,
  fontWeight: FontWeight.w300,
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);

// -----------------------------------------------------------------------------
// Shared section chrome
// -----------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.heading,
    required this.headingSemanticsId,
    required this.hint,
    required this.child,
  });

  final String label;
  final String heading;
  final String headingSemanticsId;
  final String hint;
  final Widget child;

  @override
  Widget build(final BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: _kLabel),
        const SizedBox(height: 8),
        Semantics(
          identifier: headingSemanticsId,
          header: true,
          // Make the heading its own semantic container so the next-sibling
          // body widget (toggle row, slider, list, ...) can't fold its
          // interactive node into the heading. Without this, the toggle in
          // _ToggleSection would surface as role:"header" + actions:["tap"]
          // instead of role:"switch".
          container: true,
          child: Text(heading, style: _kHeading),
        ),
        const SizedBox(height: 20),
        child,
        const SizedBox(height: 16),
        Text(hint, style: _kHint),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Sections
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(final BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          identifier: 'app_title_text',
          child: const Text('MCP Flutter', style: _kDisplay),
        ),
        const SizedBox(height: 12),
        Semantics(
          identifier: 'about_demo_heading',
          header: true,
          child: const Text(
            'A Flutter app an AI agent can see and operate.',
            style: TextStyle(
              color: _kMuted,
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Every element on this page has a Semantics identifier. Call '
          'semantic_snapshot to list them, then operate on them with '
          'tap_widget, enter_text, scroll, and the other interaction tools.',
          style: _kBody,
        ),
      ],
    );
  }
}

class _TapSection extends StatelessWidget {
  const _TapSection();

  @override
  Widget build(final BuildContext context) {
    final state = AgentState.instance;
    return _Section(
      label: 'Tap',
      heading: 'A button an agent can press',
      headingSemanticsId: 'counter_demo_heading',
      hint:
          'Try: semantic_snapshot → tap_widget(ref). '
          'The tap dispatches through SemanticsAction.tap.',
      child: Semantics(
        explicitChildNodes: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Semantics(
              identifier: 'counter_demo_icon',
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.add_circle_outline,
                  color: _kAccent,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Semantics(
              identifier: 'stateful_counter_increment_button',
              button: true,
              onTap: state.increment,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: state.increment,
                  customBorder: const StadiumBorder(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: _kAccent),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'Increment',
                      style: TextStyle(
                        color: _kAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Semantics(
              identifier: 'counter_value_display',
              label: 'Counter value',
              value: '${state.counter}',
              child: Text('${state.counter}', style: _kValue),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSection extends StatelessWidget {
  const _TypeSection();

  @override
  Widget build(final BuildContext context) {
    final state = AgentState.instance;
    return _Section(
      label: 'Type',
      heading: 'A field an agent can fill',
      headingSemanticsId: 'type_section_heading',
      hint:
          'Try: enter_text(ref, "hello"). Uses '
          'EditableTextState.userUpdateTextEditingValue, so formatters and '
          'onChanged fire normally.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            identifier: 'greeting_input_field',
            textField: true,
            child: TextField(
              controller: context
                  .findAncestorStateOfType<_ShowcaseScreenState>()!
                  ._textController,
              style: _kBody,
              cursorColor: _kAccent,
              decoration: const InputDecoration(
                hintText: 'Type a greeting…',
                hintStyle: TextStyle(color: _kMuted),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: _kFaint),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _kAccent, width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            identifier: 'greeting_echo',
            label: 'Current greeting',
            child: Text(
              state.greeting.isEmpty ? '—' : state.greeting,
              style: TextStyle(
                color: state.greeting.isEmpty ? _kMuted : _kInk,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSection extends StatelessWidget {
  const _ToggleSection();

  @override
  Widget build(final BuildContext context) {
    final state = AgentState.instance;
    return _Section(
      label: 'Toggle',
      heading: 'A switch with an on/off semantic',
      headingSemanticsId: 'toggle_section_heading',
      hint:
          'Try: tap_widget(ref). A Switch exposes SemanticsAction.tap '
          'that flips its state.',
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              state.toggle ? 'On' : 'Off',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: _kInk,
              ),
            ),
          ),
          Semantics(
            identifier: 'feature_toggle_switch',
            onTap: () => state.toggle = !state.toggle,
            child: Switch.adaptive(
              value: state.toggle,
              activeTrackColor: _kAccent,
              onChanged: (final value) => state.toggle = value,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideSection extends StatelessWidget {
  const _SlideSection();

  @override
  Widget build(final BuildContext context) {
    final state = AgentState.instance;
    return _Section(
      label: 'Slide',
      heading: 'A slider with increase / decrease semantics',
      headingSemanticsId: 'slide_section_heading',
      hint:
          'Try: semantic actions SemanticsAction.increase / .decrease — '
          'the interaction layer maps these automatically from scroll '
          'direction if the target is a slider ref.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('0', style: TextStyle(color: _kMuted, fontSize: 13)),
              Expanded(
                child: Semantics(
                  identifier: 'brightness_slider',
                  slider: true,
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: _kAccent,
                      inactiveTrackColor: _kFaint,
                      thumbColor: _kAccent,
                      overlayColor: _kAccent.withValues(alpha: 0.1),
                      trackHeight: 2,
                    ),
                    child: Slider(
                      value: state.slider,
                      min: 0,
                      max: 100,
                      onChanged: (final value) => state.slider = value,
                    ),
                  ),
                ),
              ),
              const Text('100', style: TextStyle(color: _kMuted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.slider.round().toString(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollSection extends StatelessWidget {
  const _ScrollSection();

  @override
  Widget build(final BuildContext context) {
    return _Section(
      label: 'Scroll',
      heading: 'A list an agent can scroll and swipe',
      headingSemanticsId: 'scroll_section_heading',
      hint:
          'Try: scroll(direction: "down") or swipe(direction: "up"). '
          'Without a ref these target the visible scroll view.',
      child: Container(
        height: 200,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: _kFaint),
            bottom: BorderSide(color: _kFaint),
          ),
        ),
        child: Semantics(
          identifier: 'scroll_demo_list',
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: 30,
            separatorBuilder: (final _, final _) =>
                const Divider(height: 1, color: _kFaint),
            itemBuilder: (final context, final index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
              child: Text(
                'Item ${index + 1}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IterateSection extends StatelessWidget {
  const _IterateSection();

  @override
  Widget build(final BuildContext context) {
    return _Section(
      label: 'Iterate',
      heading: 'A tight edit → see loop',
      headingSemanticsId: 'iterate_section_heading',
      hint:
          'Edit the marker below, then call hot_reload_and_capture to get a '
          'screenshot, semantic snapshot, and recent errors in one response.',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kFaint),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Semantics(
          identifier: 'hot_reload_marker',
          child: const Text(
            // @ai-edit-me: change this string to see hot_reload_and_capture work
            'Hot reload marker — edit me.',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
          ),
        ),
      ),
    );
  }
}

class _CaptureSection extends StatelessWidget {
  const _CaptureSection();

  @override
  Widget build(final BuildContext context) {
    return const _Section(
      label: 'Capture',
      heading: 'Native view for screenshot routing',
      headingSemanticsId: 'capture_section_heading',
      hint:
          'get_view_details → captureHints; get_screenshots mode:auto → '
          'desktop_window (macOS Screen Recording or web CDP tab capture).',
      child: ShowcasePlatformViewPanel(),
    );
  }
}

class _DebugSection extends StatelessWidget {
  const _DebugSection();

  @override
  Widget build(final BuildContext context) {
    final state = AgentState.instance;
    return _Section(
      label: 'Inspect',
      heading: 'Runtime state, logs, errors',
      headingSemanticsId: 'inspect_section_heading',
      hint:
          'Try: evaluate_dart_expression("AgentState.instance.counter"), '
          'get_recent_logs, get_app_errors.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _debugRow('AgentState.instance.counter', '${state.counter}'),
          _debugRow(
            'AgentState.instance.greeting',
            state.greeting.isEmpty ? '""' : '"${state.greeting}"',
          ),
          _debugRow('AgentState.instance.toggle', '${state.toggle}'),
          _debugRow(
            'AgentState.instance.slider',
            state.slider.round().toString(),
          ),
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Semantics(
                identifier: 'emit_log_button',
                button: true,
                child: TextButton(
                  onPressed: () =>
                      state.logMessage('agent hook: log at ${DateTime.now()}'),
                  style: TextButton.styleFrom(foregroundColor: _kAccent),
                  child: const Text('Emit log'),
                ),
              ),
              const SizedBox(width: 16),
              Semantics(
                identifier: 'trigger_error_button',
                button: true,
                child: TextButton(
                  onPressed: _triggerCaughtError,
                  style: TextButton.styleFrom(foregroundColor: _kAccent),
                  child: const Text('Trigger caught error'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            identifier: 'last_log_display',
            child: Text(
              state.lastLog.isEmpty ? 'No logs yet.' : state.lastLog,
              style: _kHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _debugRow(final String expr, final String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(child: Text(expr, style: _kHint)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );

  void _triggerCaughtError() {
    try {
      throw StateError('agent-triggered sample error');
    } on StateError catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'mcp_flutter_showcase',
          context: ErrorDescription('User pressed "Trigger caught error"'),
        ),
      );
    }
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(final BuildContext context) {
    final entries = MCPToolkitBinding.instance.allEntries.length;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        identifier: 'live_edit_test_target',
        child: Text('$entries MCP entries registered.', style: _kHint),
      ),
    );
  }
}
