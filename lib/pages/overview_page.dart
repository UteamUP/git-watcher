import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../state/watcher_controller.dart';
import '../theme.dart';
import '../ui/feedback.dart';
import '../ui/glass.dart';
import '../ui/layout.dart';
import '../ui/system.dart';
import '../version.dart';
import '../widgets/helper_panel.dart';
import '../widgets/menus.dart';
import '../widgets/repo_card.dart';
import '../widgets/repo_icon.dart';
import '../widgets/settings_dialog.dart';
import 'repo_page.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.controller});

  final WatcherController controller;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.keyR, meta: true): controller.refreshAll},
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: ListenableBuilder(
              listenable: Listenable.merge([controller, controller.helper]),
              builder: (context, _) => Column(children: [
                _Header(controller: controller),
                Expanded(child: _Grid(controller: controller)),
              ]),
            ),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final WatcherController controller;

  @override
  Widget build(BuildContext context) {
    final helper = controller.helper;
    final working = controller.scanning || controller.refreshing || controller.fetching;
    return WindowDragArea(
      child: GlassPanel(
        radius: 0,
        rim: false,
        shadow: false,
        tint: const Color(0x57FFFFFF),
        child: Column(children: [
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.only(left: 84, right: 16),
              child: Row(children: [
                const LogoTile(size: 34),
                const SizedBox(width: 10),
                Text('GIT Watcher', style: Txt.title.copyWith(fontSize: 16)),
                const SizedBox(width: 6),
                Text('v$appVersion', style: Txt.muted.copyWith(fontSize: 11.5)),
                const SizedBox(width: 14),
                Flexible(child: FolderButton(controller: controller)),
                const Spacer(),
                if (working) ...[
                  const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: Palette.blue)),
                  const SizedBox(width: 10),
                ],
                GlassButton(onPressed: () => showSettings(context, controller), icon: Icons.tune_rounded, tooltip: 'Stillingar: AI og falin repo'),
                const SizedBox(width: 8),
                GlassButton(onPressed: controller.refreshAll, icon: Icons.refresh_rounded, tooltip: 'Endurhlaða (⌘R)'),
                const SizedBox(width: 8),
                if (controller.ciFailed > 0) ...[
                  GlassButton(
                    onPressed: helper.running
                        ? null
                        : () => startFixCi(
                              context,
                              controller,
                              controller.repos.where((r) => r.ci.state == CiState.failure && r.ci.runId != null).toList(),
                            ),
                    icon: Icons.build_circle_outlined,
                    label: 'Laga allt CI · ${controller.ciFailed}',
                    tone: GlassTone.rose,
                    tooltip: 'AI agent lagar öll biluð CI, eitt repo í einu',
                  ),
                  const SizedBox(width: 8),
                ],
                GlassButton(
                  onPressed: helper.running
                      ? null
                      : () => startAiHelper(context, controller, controller.repos.where((r) => r.shippable).toList()),
                  busy: helper.running,
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI helper',
                  tone: GlassTone.rose,
                  tooltip: 'Skrifa skilaboð, commita og pusha öll repo, og laga vandamál',
                ),
              ]),
            ),
          ),
          Container(height: .8, color: const Color(0x80FFFFFF)),
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                GlassButton(
                  onPressed: controller.dirtyCount > 0 ? () => runWithFeedback(context, controller.writeAllMessages) : null,
                  icon: Icons.edit_note_rounded,
                  label: 'AI skilaboð',
                  tone: GlassTone.rose,
                  tooltip: 'Láta AI skrifa commit skilaboð í öll repo með breytingar',
                ),
                const SizedBox(width: 8),
                GlassButton(
                  onPressed: controller.dirtyCount > 0 ? () => runWithFeedback(context, controller.commitAll) : null,
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Commit allt',
                  tone: GlassTone.green,
                ),
                const SizedBox(width: 8),
                GlassButton(
                  onPressed: controller.aheadCount > 0 ? () => _pushAll(context) : null,
                  icon: Icons.cloud_upload_outlined,
                  label: 'Push allt',
                  tone: GlassTone.blue,
                ),
                const SizedBox(width: 8),
                GlassButton(
                  onPressed: controller.fetching ? null : () => runWithFeedback(context, controller.fetchAll, success: 'Fetch lokið'),
                  busy: controller.fetching,
                  icon: Icons.cloud_download_outlined,
                  label: 'Fetch allt',
                  tone: GlassTone.violet,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(children: [
                      if (controller.dirtyCount > 0)
                        GlassChip(icon: Icons.difference_outlined, label: '${controller.dirtyCount} með breytingar', color: Palette.orange),
                      if (controller.aheadCount > 0) ...[
                        const SizedBox(width: 6),
                        GlassChip(icon: Icons.north_rounded, label: '${controller.aheadCount} bíða push', color: Palette.blue),
                      ],
                      if (controller.ciRunning > 0) ...[
                        const SizedBox(width: 6),
                        GlassChip(icon: Icons.autorenew_rounded, label: '${controller.ciRunning} CI í gangi', color: Palette.blue),
                      ],
                      if (controller.ciFailed > 0) ...[
                        const SizedBox(width: 6),
                        GlassChip(icon: Icons.cancel_outlined, label: '${controller.ciFailed} CI mistókst', color: Palette.red),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          Container(height: .8, color: const Color(0x4DFFFFFF)),
        ]),
      ),
    );
  }

  Future<void> _pushAll(BuildContext context) async {
    final targets = controller.repos.where((r) => r.ahead > 0).toList();
    final go = await confirm(
      context,
      title: 'Push allt',
      icon: Icons.cloud_upload_outlined,
      action: 'Pusha ${targets.length} repo',
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final repo in targets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              RepoIcon(name: repo.name, iconPath: repo.iconPath, size: 26),
              const SizedBox(width: 10),
              Expanded(child: Text(repo.name, style: Txt.strong)),
              Text('↑${repo.ahead}', style: Txt.strong.copyWith(color: Palette.blue)),
            ]),
          ),
      ]),
    );
    if (go && context.mounted) await runWithFeedback(context, controller.pushAll);
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.controller});

  final WatcherController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.repos.isEmpty) {
      return Center(
        child: GlassPanel(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(controller.scanning ? Icons.manage_search_rounded : Icons.folder_off_outlined, size: 44, color: Palette.blue),
            const SizedBox(height: 12),
            Text(controller.scanning ? 'Leita að git repo…' : 'Engin git repo fundust', style: Txt.title),
            const SizedBox(height: 6),
            Text(controller.config.root, style: Txt.muted),
            const SizedBox(height: 16),
            FolderButton(controller: controller),
          ]),
        ),
      );
    }

    final repos = controller.sorted;
    return LayoutBuilder(builder: (context, constraints) {
      final columns = columnsFor(constraints.maxWidth - 40);
      return CustomScrollView(slivers: [
        if (controller.helper.visible)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(child: HelperPanel(helper: controller.helper)),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: cardHeight,
              mainAxisSpacing: cardGap,
              crossAxisSpacing: cardGap,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => RepoCard(
                key: ValueKey(repos[i].path),
                controller: controller,
                repo: repos[i],
                onOpen: () => openRepo(context, controller, repos[i]),
              ),
              childCount: repos.length,
            ),
          ),
        ),
      ]);
    });
  }
}
