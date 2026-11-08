import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import '../state/ai_helper.dart';
import '../state/watcher_controller.dart';
import '../theme.dart';
import '../ui/feedback.dart';
import '../ui/glass.dart';
import 'repo_icon.dart';

/// Asks once, listing what will be committed and pushed, then lets the AI helper ship [targets].
Future<void> startAiHelper(BuildContext context, WatcherController controller, List<RepoState> targets) async {
  if (targets.isEmpty) {
    toast(context, 'Ekkert til að commita eða pusha');
    return;
  }
  final provider = controller.aiProvider;
  if ((provider == AiProvider.claudeCode && !controller.claudeReady) || (provider == AiProvider.codex && !controller.codexReady)) {
    await showErrorDialog(context, '${providerLabel(provider)} er ekki innskráð. Opnaðu Stillingar (⚙︎) og skráðu þig inn eða veldu API lykil.');
    return;
  }
  final go = await confirm(
    context,
    title: targets.length == 1 ? 'AI agent fyrir ${targets.first.name}' : 'AI helper',
    icon: Icons.auto_awesome_rounded,
    tone: GlassTone.rose,
    action: 'Byrja',
    body: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'AI skrifar commit skilaboð, commitar allar breytingar, sækir og rebase-ar ef þarf og pushar. '
        'Ef eitthvað stendur á tekur AI agent (Claude Code) við og lagar það.',
        style: Txt.body.copyWith(fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 14),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: SingleChildScrollView(
          child: Column(children: [
            for (final repo in targets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  RepoIcon(name: repo.name, iconPath: repo.iconPath, size: 26),
                  const SizedBox(width: 10),
                  Expanded(child: Text(repo.name, style: Txt.strong)),
                  Text(
                    [
                      if (repo.dirty) fileCount(repo.files.length),
                      if (repo.ahead > 0) '↑${repo.ahead}',
                      if (repo.behind > 0) '↓${repo.behind}',
                    ].join(' · '),
                    style: Txt.muted,
                  ),
                ]),
              ),
          ]),
        ),
      ),
    ]),
  );
  if (go) await controller.helper.run(targets);
}

/// Asks before an agent changes code to make failed CI runs pass, one repo after another.
Future<void> startFixCi(BuildContext context, WatcherController controller, List<RepoState> repos) async {
  final agent = controller.agent;
  final ready = agent == AgentProvider.claudeCode ? controller.claudeReady : agent == AgentProvider.codex && controller.codexReady;
  if (!ready) {
    await showErrorDialog(context, 'Enginn AI agent er tilbúinn. Opnaðu Stillingar (⚙︎) og veldu Claude Code eða Codex og skráðu þig inn.');
    return;
  }
  final go = await confirm(
    context,
    title: repos.length == 1 ? 'Laga CI í ${repos.first.name}' : 'Laga allt CI · ${repos.length} repo',
    icon: Icons.build_circle_outlined,
    tone: GlassTone.rose,
    action: repos.length == 1 ? 'Laga CI' : 'Laga ${repos.length} repo',
    body: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        '${agentLabel(agent)} les villuna úr hverri CI keyrslu, lagar kóðann, commitar og pushar, eitt repo í einu. '
        'Hann notar hvorki --force né --no-verify og slekkur ekki á prófunum. '
        'Ef villan er ekki í kóðanum (t.d. vantar secret) breytir hann engu og útskýrir ástæðuna.',
        style: Txt.body.copyWith(fontSize: 13, height: 1.5),
      ),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: Column(children: [
            for (final repo in repos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  RepoIcon(name: repo.name, iconPath: repo.iconPath, size: 26),
                  const SizedBox(width: 10),
                  Expanded(child: Text(repo.name, style: Txt.strong)),
                  const Icon(Icons.cancel_rounded, size: 15, color: Palette.red),
                  const SizedBox(width: 5),
                  Text(repo.ci.failedJob ?? 'Mistókst', style: Txt.muted),
                ]),
              ),
          ]),
        ),
      ),
    ]),
  );
  if (go) await controller.helper.fixCi(repos);
}

class HelperPanel extends StatelessWidget {
  const HelperPanel({super.key, required this.helper});

  final AiHelper helper;

  @override
  Widget build(BuildContext context) {
    final steps = helper.steps.reversed.toList();
    return GlassPanel(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: Palette.rose, size: 18),
          const SizedBox(width: 8),
          Text('AI helper', style: Txt.strong.copyWith(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(child: Text(helper.summary, style: Txt.muted)),
          if (!helper.running) GlassButton(onPressed: helper.hide, icon: Icons.close_rounded, height: 28, radius: 8, tooltip: 'Loka'),
        ]),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 210),
          child: ListView.builder(
            shrinkWrap: true,
            reverse: true,
            itemCount: steps.length,
            itemBuilder: (context, i) => _StepRow(steps[i]),
          ),
        ),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.step);

  final HelperStep step;

  @override
  Widget build(BuildContext context) {
    final state = switch (step.state) {
      HelperStepState.running => const SizedBox.square(
          dimension: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: Palette.blue)),
      HelperStepState.done => const Icon(Icons.check_circle_rounded, size: 16, color: Palette.green),
      HelperStepState.failed => const Icon(Icons.cancel_rounded, size: 16, color: Palette.red),
      HelperStepState.warning => const Icon(Icons.warning_amber_rounded, size: 16, color: Palette.amber),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 18, child: Center(child: state)),
        const SizedBox(width: 8),
        Icon(step.icon, size: 15, color: Palette.inkSoft),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: Text(step.repo, style: Txt.strong, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Expanded(child: Text(step.text, style: Txt.muted, maxLines: 3, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
