import 'dart:async';

import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../state/watcher_controller.dart';
import '../theme.dart';
import '../ui/glass.dart';
import '../ui/system.dart';
import '../version.dart';
import 'repo_icon.dart';

Future<void> showSettings(BuildContext context, WatcherController controller) {
  controller.checkAi();
  return showDialog<void>(context: context, builder: (_) => _SettingsDialog(controller: controller));
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.controller});

  final WatcherController controller;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  final _model = TextEditingController();
  final _baseUrl = TextEditingController();
  final _key = TextEditingController();
  bool _hasKey = false;
  bool _testing = false;
  Object? _testResult;
  bool _testFailed = false;
  int _elapsed = 0;
  Timer? _ticker;

  WatcherController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _load(controller.aiProvider);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _model.dispose();
    _baseUrl.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _load(AiProvider provider) async {
    final settings = controller.config.aiSettings(provider);
    _model.text = settings.model;
    _baseUrl.text = settings.baseUrl;
    _key.clear();
    _testResult = null;
    _hasKey = provider.needsKey && await KeyStore.read(provider) != null;
    if (mounted) setState(() {});
  }

  void _choose(AiProvider provider) {
    controller.setAiProvider(provider);
    _load(provider);
  }

  Future<void> _saveKey(AiProvider provider) async {
    try {
      await KeyStore.write(provider, _key.text);
      _key.clear();
      setState(() => _hasKey = true);
    } on Object catch (error) {
      setState(() {
        _testResult = error;
        _testFailed = true;
      });
    }
  }

  Future<void> _deleteKey(AiProvider provider) async {
    await KeyStore.delete(provider);
    setState(() => _hasKey = false);
  }

  Future<void> _test(AiProvider provider) async {
    if (provider.needsKey) {
      controller
        ..setModel(provider, _model.text)
        ..setBaseUrl(provider, _baseUrl.text);
    }
    setState(() {
      _testing = true;
      _testResult = null;
      _elapsed = 0;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _elapsed++));
    try {
      final message = await controller.ai.commitMessage(
        settings: controller.config.aiSettings(provider),
        repoName: 'test',
        changes: 'diff --git a/README.md b/README.md\n+Add install steps for macOS\n',
        recentSubjects: const ['docs: explain setup'],
        subjectOnly: true,
      );
      setState(() {
        _testResult = message;
        _testFailed = false;
      });
    } on Object catch (error) {
      setState(() {
        _testResult = error;
        _testFailed = true;
      });
    } finally {
      _ticker?.cancel();
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final l = context.l10n;
          final provider = controller.aiProvider;
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660, maxHeight: 760),
              child: GlassPanel(
                radius: 26,
                tint: const Color(0xD9F7F6FB),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.tune_rounded, color: Palette.blue, size: 22),
                    const SizedBox(width: 10),
                    Text(l.settingsTitle, style: Txt.title.copyWith(fontSize: 18)),
                    const Spacer(),
                    Text('GIT Watcher $appVersion · build $appBuild', style: Txt.muted),
                    const SizedBox(width: 12),
                    GlassButton(onPressed: () => Navigator.pop(context), icon: Icons.close_rounded, height: 30, radius: 9, tooltip: l.close),
                  ]),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _Section(
                          icon: Icons.translate_rounded,
                          title: l.settingsLanguage,
                          subtitle: l.settingsLanguageSubtitle,
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final (code, label) in [('en', l.languageEnglish), ('is', l.languageIcelandic)])
                              GlassButton(
                                onPressed: () => controller.setLanguage(code),
                                label: label,
                                tone: code == controller.config.language ? GlassTone.blue : GlassTone.neutral,
                                height: 32,
                              ),
                          ]),
                        ),
                        _Section(
                          icon: Icons.auto_awesome_rounded,
                          title: l.settingsCommitAiTitle,
                          subtitle: l.settingsCommitAiSubtitle,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final p in AiProvider.values)
                                GlassButton(
                                  onPressed: () => _choose(p),
                                  icon: p.cli ? Icons.terminal_rounded : Icons.key_rounded,
                                  label: providerLabel(l, p),
                                  tone: p == provider ? GlassTone.blue : GlassTone.neutral,
                                  height: 32,
                                ),
                            ]),
                            const SizedBox(height: 14),
                            if (provider.cli) _cliStatus(provider) else _apiFields(provider),
                            const SizedBox(height: 12),
                            Row(children: [
                              GlassButton(
                                onPressed: _testing ? null : () => _test(provider),
                                busy: _testing,
                                icon: Icons.play_arrow_rounded,
                                label: l.settingsTest,
                                tone: GlassTone.green,
                              ),
                              const SizedBox(width: 12),
                              if (_testing)
                                Expanded(
                                  child: Text(l.settingsWaiting(_elapsed, providerSpeed(l, provider)), style: Txt.muted),
                                ),
                              if (_testResult != null)
                                Expanded(
                                  child: Text(
                                    _testFailed ? firstLine(l, _testResult!) : l.settingsTestWorks('$_testResult'),
                                    style: Txt.body.copyWith(color: _testFailed ? Palette.red : Palette.addedText),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ]),
                          ]),
                        ),
                        _Section(
                          icon: Icons.smart_toy_outlined,
                          title: l.settingsAgentTitle,
                          subtitle: l.settingsAgentSubtitle,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final a in AgentProvider.values)
                                GlassButton(
                                  onPressed: () => controller.setAgent(a),
                                  icon: a == AgentProvider.off ? Icons.block_rounded : Icons.smart_toy_outlined,
                                  label: agentLabel(l, a),
                                  tone: a == controller.agent ? GlassTone.violet : GlassTone.neutral,
                                  height: 32,
                                ),
                            ]),
                            const SizedBox(height: 10),
                            _signIn('Claude Code', controller.claudeReady, 'claude auth login'),
                            const SizedBox(height: 6),
                            _signIn('Codex', controller.codexReady, 'codex login'),
                          ]),
                        ),
                        _Section(
                          icon: Icons.visibility_off_outlined,
                          title: l.settingsHiddenTitle,
                          subtitle: l.settingsHiddenSubtitle,
                          child: controller.hiddenRepos.isEmpty
                              ? Text(l.settingsNoHidden, style: Txt.muted)
                              : Column(children: [
                                  for (final repo in controller.hiddenRepos)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(children: [
                                        RepoIcon(name: repo.name, iconPath: repo.iconPath, size: 28),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(repo.name, style: Txt.strong)),
                                        GlassButton(
                                          onPressed: () => controller.unhide(repo.path),
                                          icon: Icons.visibility_outlined,
                                          label: l.settingsShowAgain,
                                          height: 30,
                                        ),
                                      ]),
                                    ),
                                ]),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      );

  Widget _cliStatus(AiProvider provider) {
    final l = context.l10n;
    final ready = provider == AiProvider.claudeCode ? controller.claudeReady : controller.codexReady;
    return _signIn(providerLabel(l, provider), ready, provider == AiProvider.claudeCode ? 'claude auth login' : 'codex login',
        note: l.settingsUsesSubscription(providerSpeed(l, provider)));
  }

  Widget _signIn(String name, bool ready, String loginCommand, {String? note}) => Row(children: [
        Icon(ready ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 17, color: ready ? Palette.green : Palette.amber),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${ready ? context.l10n.settingsSignedIn(name) : context.l10n.settingsSignedOut(name)}${note == null ? '' : ' · $note'}',
            style: Txt.body,
          ),
        ),
        if (!ready)
          GlassButton(
            onPressed: () => openTerminalCommand(loginCommand),
            icon: Icons.login_rounded,
            label: context.l10n.settingsSignIn,
            tone: GlassTone.blue,
            height: 30,
            tooltip: context.l10n.settingsSignInTooltip(loginCommand),
          ),
        const SizedBox(width: 6),
        GlassButton(onPressed: controller.checkAi, icon: Icons.refresh_rounded, height: 30, radius: 9, tooltip: context.l10n.settingsCheckAgain),
      ]);

  Widget _apiFields(AiProvider provider) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Labeled(
          label: context.l10n.settingsModel,
          child: GlassField(
            controller: _model,
            hint: provider.defaultModel.isEmpty ? context.l10n.settingsModelExample('anthropic/claude-haiku-5-5') : provider.defaultModel,
            icon: Icons.memory_rounded,
            onChanged: (value) => controller.setModel(provider, value),
          ),
        ),
        if (provider == AiProvider.anthropic)
          Padding(
            padding: const EdgeInsets.only(left: 96, top: 4),
            child: Wrap(spacing: 6, children: [
              for (final model in const ['claude-opus-5-5', 'claude-sonnet-5-5', 'claude-haiku-5-5'])
                GlassButton(
                  onPressed: () {
                    _model.text = model;
                    controller.setModel(provider, model);
                    setState(() {});
                  },
                  label: model,
                  height: 26,
                  radius: 8,
                  tone: _model.text == model ? GlassTone.blue : GlassTone.neutral,
                ),
            ]),
          ),
        const SizedBox(height: 8),
        _Labeled(
          label: context.l10n.settingsBaseUrl,
          child: GlassField(
            controller: _baseUrl,
            hint: provider.defaultBaseUrl,
            icon: Icons.link_rounded,
            onChanged: (value) => controller.setBaseUrl(provider, value),
          ),
        ),
        const SizedBox(height: 8),
        _Labeled(
          label: context.l10n.settingsApiKey,
          child: GlassField(
            controller: _key,
            hint: _hasKey ? context.l10n.settingsKeySavedHint : context.l10n.settingsKeyPasteHint,
            icon: Icons.key_rounded,
            obscure: true,
            onSubmitted: (_) => _saveKey(provider),
            suffix: GlassButton(onPressed: () => _saveKey(provider), label: context.l10n.settingsSave, height: 30, radius: 8, tone: GlassTone.blue),
          ),
        ),
        if (_hasKey)
          Padding(
            padding: const EdgeInsets.only(left: 96, top: 6),
            child: Row(children: [
              const Icon(Icons.lock_rounded, size: 15, color: Palette.green),
              const SizedBox(width: 6),
              Text(context.l10n.settingsKeySaved, style: Txt.muted),
              const Spacer(),
              GlassButton(
                onPressed: () => _deleteKey(provider),
                icon: Icons.delete_outline_rounded,
                label: context.l10n.settingsDelete,
                height: 28,
                radius: 8,
              ),
            ]),
          ),
      ]);
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 96, child: Text(label, style: Txt.muted)),
        Expanded(child: child),
      ]);
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.subtitle, required this.child});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0x0D1F2547), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, size: 18, color: Palette.rose),
            const SizedBox(width: 8),
            Text(title, style: Txt.strong.copyWith(fontSize: 14)),
          ]),
          const SizedBox(height: 4),
          Text(subtitle, style: Txt.muted.copyWith(height: 1.4)),
          const SizedBox(height: 12),
          child,
        ]),
      );
}
