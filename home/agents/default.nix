# 个人 agent skill：源文件放在 ./skills/<名字>/SKILL.md，和具体工具无关；这里把每个 skill 链接到各工具的读取目录。
# 加一个 skill：新建 ./skills/<名字>/SKILL.md（可带脚本、参考文件）然后 `nx switch`，不用改这个文件。
# 只按单个 skill 链接，不接管整个 skills 目录，避免和工具自己写进去的内容（如 ~/.claude/skills/synced）冲突。
# 目前只用 Claude；以后加别的工具，把它读 skill 的目录加进 skillDirs（先确认该工具当前版本的路径）。
# 链接出来的文件是只读的：改 skill 要改仓库再 switch。
{ lib, ... }:
let
  skillDirs = [ ".claude/skills" ];

  # 只取目录，跳过 .gitkeep 之类的普通文件
  skills = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills));
in
{
  home.file = lib.listToAttrs (
    lib.concatMap (
      dir: map (name: lib.nameValuePair "${dir}/${name}" { source = ./skills/${name}; }) skills
    ) skillDirs
  );
}
