import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../state/watcher_controller.dart';
import '../theme.dart';
import '../ui/feedback.dart';
import '../ui/glass.dart';
import 'repo_icon.dart';

Future<void> showRepoSettings(BuildContext context, WatcherController controller, RepoState repo) {
  controller.checkAi();
  return showDialog<void>(
    context: context,
    builder: (_) => _RepoSettingsDialog(controller: controller, repo: repo),
  );
}

class _RepoSettingsDialog extends StatefulWidget {
  const _RepoSettingsDialog({required this.controller, required this.repo});

  final WatcherController controller;
  final RepoState repo;

  @override
  State<_RepoSettingsDialog> createState() => _RepoSettingsDialogState();
}

class _RepoSettingsDialogState extends State<_RepoSettingsDialog> {
  static const _syncPresets = [5, 10, 15, 30, 60];
  static const _skillPresets = [5, 15, 30, 60, 120];

  late final TextEditingController _syncMinutes;
  late final TextEditingController _pushMinutes;
  late final TextEditingController _skillMinutes;
  final _newSkill = TextEditingController();
  final _newSkillModel = TextEditingController(text: 'sonnet');
  final _rowModelControllers = <int, TextEditingController>{};

  AgentProvider _newSkillAgent = AgentProvider.claudeCode;
  late final List<String> _installedSkills;
  bool _syncingNow = false;

  WatcherController get controller => widget.controller;
  RepoState get repo => widget.repo;

  @override
  void initState() {
    super.initState();
    final auto = controller.repoAutomation(repo);
    _syncMinutes = TextEditingController(text: '${auto?.syncIntervalMinutes ?? 15}');
    _pushMinutes = TextEditingController(text: '${auto?.pushIntervalMinutes ?? auto?.syncIntervalMinutes ?? 15}');
    _skillMinutes = TextEditingController(text: '${auto?.skillIntervalMinutes ?? 15}');
    if (!controller.claudeReady && controller.codexReady) {
      _newSkillAgent = AgentProvider.codex;
      _newSkillModel.text = '';
    }
    _installedSkills = controller.discoverSkillsFor(repo);
  }

  @override
  void dispose() {
    _syncMinutes.dispose();
    _pushMinutes.dispose();
    _skillMinutes.dispose();
    _newSkill.dispose();
    _newSkillModel.dispose();
    for (final c in _rowModelControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _modelControllerFor(int index, String value) {
    final existing = _rowModelControllers[index];
    if (existing != null) {
      if (existing.text != value) existing.text = value;
      return existing;
    }
    return _rowModelControllers[index] = TextEditingController(text: value);
  }

  void _rebuildRowControllers(List<SkillStepConfig> skills) {
    for (final c in _rowModelControllers.values) {
      c.dispose();
    }
    _rowModelControllers.clear();
    for (var i = 0; i < skills.length; i++) {
      _rowModelControllers[i] = TextEditingController(text: skills[i].model);
    }
  }

  void _setSyncInterval(int minutes) {
    final clamped = minutes.clamp(1, 1440);
    if (_syncMinutes.text != '$clamped') _syncMinutes.text = '$clamped';
    controller.updateRepoAutomation(
      repo,
      (auto) {
        auto.syncIntervalMinutes = clamped;
        if (!auto.autoPush) {
          auto.pushIntervalMinutes = clamped;
          if (_pushMinutes.text != '$clamped') _pushMinutes.text = '$clamped';
        }
      },
      resetCommitTimer: true,
    );
  }

  void _setPushInterval(int minutes) {
    final clamped = minutes.clamp(1, 1440);
    if (_pushMinutes.text != '$clamped') _pushMinutes.text = '$clamped';
    controller.updateRepoAutomation(
      repo,
      (auto) => auto.pushIntervalMinutes = clamped,
      resetPushTimer: true,
    );
  }

  void _setSkillInterval(int minutes) {
    final clamped = minutes.clamp(1, 1440);
    if (_skillMinutes.text != '$clamped') _skillMinutes.text = '$clamped';
    controller.updateRepoAutomation(repo, (auto) => auto.skillIntervalMinutes = clamped, resetSkillTimer: true);
  }

  void _addSkill([String? pickedName]) {
    final name = (pickedName ?? _newSkill.text).trim().replaceFirst(RegExp(r'^/+'), '');
    if (name.isEmpty) return;
    controller.updateRepoAutomation(repo, (auto) {
      auto.skills.add(SkillStepConfig(
        skill: name,
        agent: _newSkillAgent,
        model: _newSkillModel.text.trim(),
      ));
      if (auto.skills.length == 1 && !auto.watchCommitsForSkills) {
        auto.watchCommitsForSkills = true;
      }
      _rebuildRowControllers(auto.skills);
    }, resetSkillTimer: true);
    _newSkill.clear();
    setState(() {});
  }

  Future<void> _runSyncNow() async {
    setState(() => _syncingNow = true);
    try {
      await runWithFeedback(
        context,
        () => controller.runRepoAutoSync(repo),
      );
    } finally {
      if (mounted) setState(() => _syncingNow = false);
    }
  }

  Future<void> _runSkillsNow() async {
    Navigator.of(context).pop();
    await controller.runRepoSkillsNow(repo);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([controller, controller.helper]),
        builder: (context, _) {
          final l = context.l10n;
          final auto = controller.repoAutomation(repo);
          final autoCommit = auto?.autoCommit ?? false;
          final autoPush = auto?.autoPush ?? false;
          final syncInterval = auto?.syncIntervalMinutes ?? 15;
          final pushInterval = auto?.pushIntervalMinutes ?? syncInterval;
          final watchSkills = auto?.watchCommitsForSkills ?? false;
          final skillInterval = auto?.skillIntervalMinutes ?? 15;
          final skills = auto?.skills ?? const <SkillStepConfig>[];
          final baseline = auto?.lastSkillCommit ?? repo.status?.headHash;
          final shortBaseline = baseline != null && baseline.length > 7 ? baseline.substring(0, 7) : baseline;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 780),
              child: GlassPanel(
                radius: 26,
                tint: const Color(0xDDF7F6FB),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    RepoIcon(name: repo.name, iconPath: repo.iconPath, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.repoSettingsTitle(repo.name), style: Txt.title.copyWith(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(homePath(repo.path, controller.home), style: Txt.muted.copyWith(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    GlassButton(onPressed: () => Navigator.pop(context), icon: Icons.close_rounded, height: 30, radius: 9, tooltip: l.close),
                  ]),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        _SectionCard(
                          icon: Icons.sync_rounded,
                          iconColor: Palette.blue,
                          title: l.repoAutoSyncTitle,
                          subtitle: l.repoAutoSyncSubtitle,
                          trailing: (autoCommit || autoPush)
                              ? GlassButton(
                                  onPressed: _syncingNow || repo.busy != null ? null : _runSyncNow,
                                  busy: _syncingNow,
                                  icon: Icons.play_arrow_rounded,
                                  label: l.repoRunSyncNow,
                                  tone: GlassTone.blue,
                                  height: 30,
                                )
                              : null,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              Expanded(
                                child: _ToggleTile(
                                  active: autoCommit,
                                  tone: GlassTone.green,
                                  icon: Icons.auto_awesome_rounded,
                                  title: l.repoAutoCommit,
                                  subtitle: l.repoAutoCommitHint,
                                  onTap: () => controller.updateRepoAutomation(
                                    repo,
                                    (a) => a.autoCommit = !a.autoCommit,
                                    resetCommitTimer: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ToggleTile(
                                  active: autoPush,
                                  tone: GlassTone.blue,
                                  icon: Icons.north_rounded,
                                  title: l.repoAutoPush,
                                  subtitle: l.repoAutoPushHint,
                                  onTap: () => controller.updateRepoAutomation(
                                    repo,
                                    (a) => a.autoPush = !a.autoPush,
                                    resetPushTimer: true,
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            if (autoCommit || !autoPush)
                              _IntervalRow(
                                label: autoCommit && autoPush ? l.repoCommitIntervalMinutes : l.repoIntervalMinutes,
                                suffix: l.repoMinutesSuffix,
                                presets: _syncPresets,
                                current: syncInterval,
                                controller: _syncMinutes,
                                onSelect: _setSyncInterval,
                              ),
                            if (autoCommit && autoPush) const SizedBox(height: 8),
                            if (autoPush)
                              _IntervalRow(
                                label: autoCommit ? l.repoPushIntervalMinutes : l.repoIntervalMinutes,
                                suffix: l.repoMinutesSuffix,
                                presets: _syncPresets,
                                current: pushInterval,
                                controller: _pushMinutes,
                                onSelect: _setPushInterval,
                              ),
                          ]),
                        ),
                        _SectionCard(
                          icon: Icons.bolt_rounded,
                          iconColor: Palette.violet,
                          title: l.repoSkillsTitle,
                          subtitle: l.repoSkillsSubtitle,
                          trailing: skills.any((s) => s.enabled && s.skill.trim().isNotEmpty)
                              ? GlassButton(
                                  onPressed: controller.helper.running || repo.busy != null ? null : _runSkillsNow,
                                  icon: Icons.play_arrow_rounded,
                                  label: l.repoSkillsRunNow,
                                  tone: GlassTone.rose,
                                  height: 30,
                                )
                              : null,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              GlassButton(
                                onPressed: () => controller.updateRepoAutomation(
                                  repo,
                                  (a) => a.watchCommitsForSkills = !a.watchCommitsForSkills,
                                  resetSkillTimer: true,
                                ),
                                icon: watchSkills ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                label: l.repoSkillsWatchToggle,
                                tone: watchSkills ? GlassTone.violet : GlassTone.neutral,
                                height: 34,
                              ),
                              const Spacer(),
                              if (shortBaseline != null && shortBaseline.isNotEmpty)
                                Text(l.repoLastCheckedCommit(shortBaseline), style: Txt.muted.copyWith(fontSize: 11.5)),
                            ]),
                            const SizedBox(height: 12),
                            _IntervalRow(
                              label: l.repoSkillsCheckInterval,
                              suffix: l.repoMinutesSuffix,
                              presets: _skillPresets,
                              current: skillInterval,
                              controller: _skillMinutes,
                              onSelect: _setSkillInterval,
                            ),
                            const SizedBox(height: 14),
                            if (skills.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(l.repoSkillsEmpty, style: Txt.muted),
                              )
                            else
                              Column(children: [
                                for (var i = 0; i < skills.length; i++)
                                  _SkillRow(
                                    index: i,
                                    total: skills.length,
                                    step: skills[i],
                                    modelController: _modelControllerFor(i, skills[i].model),
                                    onToggle: () => controller.updateRepoAutomation(repo, (a) => a.skills[i].enabled = !a.skills[i].enabled),
                                    onAgentChanged: (agent) => controller.updateRepoAutomation(repo, (a) {
                                      a.skills[i].agent = agent;
                                      final defaultModel = agent.defaultSkillModel;
                                      a.skills[i].model = defaultModel;
                                      _modelControllerFor(i, defaultModel).text = defaultModel;
                                    }),
                                    onModelChanged: (model) => controller.updateRepoAutomation(repo, (a) => a.skills[i].model = model.trim()),
                                    onMoveUp: i > 0
                                        ? () => controller.updateRepoAutomation(repo, (a) {
                                              final item = a.skills.removeAt(i);
                                              a.skills.insert(i - 1, item);
                                              _rebuildRowControllers(a.skills);
                                            })
                                        : null,
                                    onMoveDown: i < skills.length - 1
                                        ? () => controller.updateRepoAutomation(repo, (a) {
                                              final item = a.skills.removeAt(i);
                                              a.skills.insert(i + 1, item);
                                              _rebuildRowControllers(a.skills);
                                            })
                                        : null,
                                    onRemove: () => controller.updateRepoAutomation(repo, (a) {
                                      a.skills.removeAt(i);
                                      if (a.skills.isEmpty) a.watchCommitsForSkills = false;
                                      _rebuildRowControllers(a.skills);
                                    }),
                                  ),
                              ]),
                            const SizedBox(height: 10),
                            _AddSkillBar(
                              skillController: _newSkill,
                              modelController: _newSkillModel,
                              agent: _newSkillAgent,
                              installedSkills: _installedSkills,
                              onAgentChanged: (agent) => setState(() {
                                _newSkillAgent = agent;
                                _newSkillModel.text = agent.defaultSkillModel;
                              }),
                              onAdd: _addSkill,
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
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0x0D1F2547), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, size: 19, color: iconColor),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: Txt.strong.copyWith(fontSize: 14))),
            ?trailing,
          ]),
          const SizedBox(height: 4),
          Text(subtitle, style: Txt.muted.copyWith(height: 1.4)),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.active,
    required this.tone,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool active;
  final GlassTone tone;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: active ? tone.top.withValues(alpha: 0.34) : const Color(0x66FFFFFF),
              border: Border.all(color: active ? tone.rim : const Color(0x1F1F2547), width: active ? 1.1 : 0.8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                active ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: active ? tone.foreground : Palette.inkFaint,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(icon, size: 14, color: active ? tone.foreground : Palette.inkSoft),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        title,
                        style: Txt.strong.copyWith(fontSize: 13, color: active ? tone.foreground : Palette.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Txt.muted.copyWith(fontSize: 11.5, height: 1.3)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _IntervalRow extends StatelessWidget {
  const _IntervalRow({
    required this.label,
    required this.suffix,
    required this.presets,
    required this.current,
    required this.controller,
    required this.onSelect,
  });

  final String label;
  final String suffix;
  final List<int> presets;
  final int current;
  final TextEditingController controller;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 128, child: Text(label, style: Txt.muted)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final mins in presets)
            GlassButton(
              onPressed: () => onSelect(mins),
              label: '$mins $suffix',
              height: 29,
              radius: 8.5,
              tone: current == mins ? GlassTone.blue : GlassTone.neutral,
            ),
        ]),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: GlassField(
            controller: controller,
            hint: '15',
            icon: Icons.schedule_rounded,
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed > 0) onSelect(parsed);
            },
            onSubmitted: (value) {
              final parsed = int.tryParse(value.trim());
              onSelect(parsed != null && parsed > 0 ? parsed : 15);
            },
          ),
        ),
      ]);
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.index,
    required this.total,
    required this.step,
    required this.modelController,
    required this.onToggle,
    required this.onAgentChanged,
    required this.onModelChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final int total;
  final SkillStepConfig step;
  final TextEditingController modelController;
  final VoidCallback onToggle;
  final ValueChanged<AgentProvider> onAgentChanged;
  final ValueChanged<String> onModelChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x88FFFFFF),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0x1A1F2547), width: 0.8),
      ),
      child: Row(children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: step.enabled,
            onChanged: (_) => onToggle(),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 6),
        Text('${index + 1}.', style: Txt.muted.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Expanded(
          flex: 4,
          child: Text(
            step.skill,
            style: (step.enabled ? Txt.strong : Txt.muted).copyWith(
              fontSize: 12.5,
              decoration: step.enabled ? null : TextDecoration.lineThrough,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _AgentMenuButton(agent: step.agent, onChanged: onAgentChanged),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: _ModelInput(
            agent: step.agent,
            controller: modelController,
            onChanged: onModelChanged,
          ),
        ),
        if (total > 1) ...[
          const SizedBox(width: 4),
          GlassButton(
            onPressed: onMoveUp,
            icon: Icons.keyboard_arrow_up_rounded,
            height: 28,
            radius: 8,
            tooltip: l.repoSkillMoveUp,
          ),
          const SizedBox(width: 3),
          GlassButton(
            onPressed: onMoveDown,
            icon: Icons.keyboard_arrow_down_rounded,
            height: 28,
            radius: 8,
            tooltip: l.repoSkillMoveDown,
          ),
        ],
        const SizedBox(width: 4),
        GlassButton(
          onPressed: onRemove,
          icon: Icons.delete_outline_rounded,
          iconColor: Palette.red,
          height: 28,
          radius: 8,
          tooltip: l.repoSkillRemove,
        ),
      ]),
    );
  }
}

class _AddSkillBar extends StatelessWidget {
  const _AddSkillBar({
    required this.skillController,
    required this.modelController,
    required this.agent,
    required this.installedSkills,
    required this.onAgentChanged,
    required this.onAdd,
  });

  final TextEditingController skillController;
  final TextEditingController modelController;
  final AgentProvider agent;
  final List<String> installedSkills;
  final ValueChanged<AgentProvider> onAgentChanged;
  final void Function([String? pickedName]) onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.enter): onAdd},
      child: Row(children: [
        Expanded(
          flex: 4,
          child: GlassField(
            controller: skillController,
            hint: l.repoSkillNameHint,
            icon: Icons.extension_outlined,
            onSubmitted: (_) => onAdd(),
            suffix: installedSkills.isEmpty
                ? null
                : MenuAnchor(
                    style: glassMenuStyle.copyWith(
                      maximumSize: const WidgetStatePropertyAll(Size(360, 320)),
                    ),
                    alignmentOffset: const Offset(-200, 6),
                    menuChildren: [
                      for (final name in installedSkills)
                        MenuItemButton(
                          style: menuItemStyle,
                          leadingIcon: const Icon(Icons.bolt_rounded, size: 16, color: Palette.violet),
                          onPressed: () {
                            skillController.text = name;
                          },
                          child: Text(name, style: Txt.body.copyWith(fontSize: 12.5)),
                        ),
                    ],
                    builder: (context, menu, _) => GlassButton(
                      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                      icon: Icons.expand_more_rounded,
                      height: 28,
                      radius: 8,
                      tooltip: l.repoSkillPickInstalled,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        _AgentMenuButton(agent: agent, onChanged: onAgentChanged),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: _ModelInput(
            agent: agent,
            controller: modelController,
            onChanged: (_) {},
          ),
        ),
        const SizedBox(width: 8),
        GlassButton(
          onPressed: onAdd,
          icon: Icons.add_rounded,
          label: l.repoSkillAdd,
          tone: GlassTone.blue,
          height: 36,
        ),
      ]),
    );
  }
}

class _AgentMenuButton extends StatelessWidget {
  const _AgentMenuButton({required this.agent, required this.onChanged});

  final AgentProvider agent;
  final ValueChanged<AgentProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const choices = [AgentProvider.claudeCode, AgentProvider.codex];
    return MenuAnchor(
      style: glassMenuStyle,
      menuChildren: [
        for (final choice in choices)
          MenuItemButton(
            style: menuItemStyle,
            leadingIcon: Icon(
              choice == agent ? Icons.check_rounded : Icons.smart_toy_outlined,
              color: choice == agent ? Palette.violet : Palette.inkSoft,
            ),
            onPressed: () => onChanged(choice),
            child: Text(agentLabel(l, choice)),
          ),
      ],
      builder: (context, menu, _) => GlassButton(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: Icons.smart_toy_outlined,
        label: agentLabel(l, agent),
        trailing: Icons.expand_more_rounded,
        tone: GlassTone.violet,
        height: 32,
        radius: 9,
      ),
    );
  }
}

class _ModelInput extends StatelessWidget {
  const _ModelInput({
    required this.agent,
    required this.controller,
    required this.onChanged,
  });

  final AgentProvider agent;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final suggestions = agent.suggestedSkillModels;
    return GlassField(
      controller: controller,
      hint: agent.defaultSkillModel.isEmpty ? l.repoSkillModelDefault : agent.defaultSkillModel,
      icon: Icons.memory_rounded,
      onChanged: onChanged,
      suffix: suggestions.isEmpty
          ? null
          : MenuAnchor(
              style: glassMenuStyle,
              alignmentOffset: const Offset(-120, 6),
              menuChildren: [
                if (agent.defaultSkillModel.isEmpty)
                  MenuItemButton(
                    style: menuItemStyle,
                    leadingIcon: const Icon(Icons.auto_awesome_outlined, size: 16),
                    onPressed: () {
                      controller.text = '';
                      onChanged('');
                    },
                    child: Text(l.repoSkillModelDefault),
                  ),
                for (final m in suggestions)
                  MenuItemButton(
                    style: menuItemStyle,
                    leadingIcon: Icon(
                      controller.text.trim() == m ? Icons.check_rounded : Icons.memory_rounded,
                      size: 16,
                      color: controller.text.trim() == m ? Palette.blue : Palette.inkSoft,
                    ),
                    onPressed: () {
                      controller.text = m;
                      onChanged(m);
                    },
                    child: Text(m),
                  ),
              ],
              builder: (context, menu, _) => GlassButton(
                onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                icon: Icons.expand_more_rounded,
                height: 26,
                radius: 7,
                tooltip: l.settingsChooseModel,
              ),
            ),
    );
  }
}
