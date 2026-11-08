import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:git_watcher_core/git_watcher_core.dart';

import '../format.dart';
import '../state/watcher_controller.dart';
import '../theme.dart';
import '../ui/feedback.dart';
import '../ui/glass.dart';
import '../ui/system.dart';
import 'helper_panel.dart';

MenuItemButton _item(IconData icon, String label, VoidCallback? onPressed, {Color? color}) => MenuItemButton(
      style: menuItemStyle,
      leadingIcon: Icon(icon, color: onPressed == null ? Palette.inkFaint : color),
      onPressed: onPressed,
      child: Text(label),
    );

Widget _label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 3),
      child: Text(text, style: Txt.muted.copyWith(fontSize: 11, fontWeight: FontWeight.w400)),
    );

const _divider = Divider(height: 9, thickness: .6, color: Color(0x1A1F2547));

/// "⋯" on a card or repo page: the AI agent first, then every other git action.
class RepoMenu extends StatelessWidget {
  const RepoMenu({super.key, required this.controller, required this.repo, this.size = 30});

  final WatcherController controller;
  final RepoState repo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final idle = repo.busy == null;
    final operation = repo.operation;
    VoidCallback? run(bool allowed, Future<Object?> Function() action) =>
        allowed && idle ? () => runWithFeedback(context, action) : null;

    return MenuAnchor(
      style: glassMenuStyle,
      alignmentOffset: const Offset(-200, 6),
      menuChildren: [
        MenuItemButton(
          style: menuItemStyle,
          leadingIcon: const Icon(Icons.auto_awesome_rounded, color: Palette.rose),
          onPressed: idle && repo.shippable ? () => startAiHelper(context, controller, [repo]) : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Nota AI agent', style: Txt.strong.copyWith(fontSize: 13)),
            Text('Skrifar, commitar og pushar', style: Txt.muted.copyWith(fontSize: 11)),
          ]),
        ),
        _divider,
        _item(Icons.cloud_download_rounded, 'Fetch', run(true, () => controller.fetch(repo))),
        _item(Icons.south_rounded, 'Pull með rebase', run(true, () => controller.pullRebase(repo))),
        _item(Icons.call_split_rounded, 'Rebase á origin/main', run(true, () => controller.rebaseOnDefault(repo))),
        _item(Icons.sync_rounded, 'Sync (pull og push)', run(true, () => controller.sync(repo))),
        _item(Icons.inventory_2_outlined, 'Stash breytingar', run(repo.dirty, () => controller.stash(repo))),
        _item(Icons.unarchive_outlined, 'Sækja stash', run(true, () => controller.stashPop(repo))),
        if (operation != RepoOperation.none) ...[
          _divider,
          _item(Icons.play_arrow_rounded, 'Halda áfram með ${operationLabel(operation)}',
              run(true, () => controller.continueOperation(repo)), color: Palette.green),
          _item(Icons.close_rounded, 'Hætta við ${operationLabel(operation)}', run(true, () => controller.abortOperation(repo)),
              color: Palette.red),
        ],
        _divider,
        if (repo.ci.state == CiState.failure && repo.ci.runId != null)
          _item(Icons.build_circle_outlined, 'Laga CI með AI', idle ? () => startFixCi(context, controller, [repo]) : null,
              color: Palette.rose),
        if (repo.ci.url != null) _item(Icons.open_in_new_rounded, 'Opna CI keyrslu', () => openUrl(repo.ci.url!)),
        _item(Icons.code_rounded, 'Opna í VS Code', () => openInVsCode(repo.path)),
        _item(Icons.folder_open_rounded, 'Opna í Finder', () => openInFinder(repo.path)),
        _item(Icons.terminal_rounded, 'Opna í Terminal', () => openInTerminal(repo.path)),
        _item(Icons.image_outlined, 'Breyta icon…', _pickIcon),
        if (controller.config.icons.containsKey(repo.path))
          _item(Icons.restart_alt_rounded, 'Nota sjálfgefið icon', () => controller.setIcon(repo, null)),
        _divider,
        _item(Icons.visibility_off_outlined, 'Fela repo', () {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          controller.hide(repo);
        }),
      ],
      builder: (context, menu, _) => GlassButton(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: Icons.more_horiz_rounded,
        height: size,
        radius: size * .3,
        tooltip: 'Fleiri aðgerðir',
      ),
    );
  }

  Future<void> _pickIcon() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Myndir', extensions: ['png', 'jpg', 'jpeg', 'svg']),
      ],
      initialDirectory: repo.path,
      confirmButtonText: 'Velja',
    );
    if (file != null) controller.setIcon(repo, file.path);
  }
}

/// Shows the watched folder and lets the user pick another one, recent or new.
class FolderButton extends StatelessWidget {
  const FolderButton({super.key, required this.controller});

  final WatcherController controller;

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    final recent = config.recentRoots.where((p) => p != config.root && Directory(p).existsSync()).toList();

    MenuItemButton folder(String path, {String? trailing, bool current = false}) => MenuItemButton(
          style: menuItemStyle,
          leadingIcon: Icon(current ? Icons.folder_special_rounded : Icons.folder_rounded, color: current ? Palette.blue : null),
          trailingIcon: trailing == null ? null : Text(trailing, style: Txt.muted.copyWith(fontSize: 11)),
          onPressed: current ? controller.rescan : () => controller.chooseRoot(path),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(repoFolderName(path), style: current ? Txt.strong.copyWith(fontSize: 13) : null),
              Text(homePath(path, controller.home), style: Txt.muted.copyWith(fontSize: 11)),
            ]),
          ),
        );

    return MenuAnchor(
      style: glassMenuStyle,
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        _label('Fylgst með'),
        folder(config.root, trailing: '${controller.repos.length} repo', current: true),
        if (recent.isNotEmpty) ...[_label('Nýlegar möppur'), for (final path in recent) folder(path)],
        if (controller.hiddenRepos.isNotEmpty) ...[
          _label('Falin repo · smelltu til að birta aftur'),
          for (final repo in controller.hiddenRepos)
            _item(Icons.visibility_outlined, repo.name, () => controller.unhide(repo.path)),
        ],
        _divider,
        CheckboxMenuButton(
          style: menuItemStyle,
          value: config.recursive,
          onChanged: (value) => controller.setRecursive(value ?? true),
          child: const Text('Leita í öllum undirmöppum'),
        ),
        _divider,
        MenuItemButton(
          style: menuItemStyle,
          leadingIcon: const Icon(Icons.create_new_folder_rounded, color: Palette.blue),
          onPressed: _pick,
          child: Text('Velja möppu…', style: Txt.strong.copyWith(fontSize: 13)),
        ),
      ],
      builder: (context, menu, _) => GlassButton(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: Icons.folder_open_rounded,
        iconColor: Palette.blue,
        label: '${repoFolderName(config.root)} · ${controller.repos.length} repo',
        trailing: Icons.expand_more_rounded,
        tooltip: homePath(config.root, controller.home),
      ),
    );
  }

  Future<void> _pick() async {
    final path = await getDirectoryPath(initialDirectory: controller.config.root, confirmButtonText: 'Velja');
    if (path != null) await controller.chooseRoot(path);
  }
}
