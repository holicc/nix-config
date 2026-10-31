;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Doom 的个人配置，由 home-manager 链接到 ~/.config/doom/config.el（见 home/emacs/default.nix），
;; 直接编辑本文件，`doom sync` 之后或重启 Emacs 生效（只改 config.el 重启即可，不用 sync）。

;; 自动保存设置
(setq auto-save-visited-interval 5)
(auto-save-visited-mode 1)

;; 字体：英文用 CaskaydiaCove Nerd Font，中文用等宽的 Noto Sans Mono CJK SC（都由系统字体模块安装）。
;; 必须显式指定简体中文(SC)：fontconfig 默认给中文配的是 Noto Sans CJK JP，汉字会是日文字形。
;; 排查：`fc-match 'Noto Sans Mono CJK SC'` 看字体是否存在。
(setq doom-font (font-spec :family "CaskaydiaCove Nerd Font" :size 17))
(add-hook! 'doom-after-init-hook
  (dolist (script '(han cjk-misc kana bopomofo))
    (set-fontset-font t script (font-spec :family "Noto Sans Mono CJK SC"))))

;; 图标字体：Doom 默认找 "Symbols Nerd Font Mono"，本机没装；CaskaydiaCove Nerd Font 自带同样的图标字形，
;; 直接用它，不额外装字体。排查：`fc-list | grep -i "Nerd Font Mono"` 看字体名是否一致。
(setq nerd-icons-font-family "CaskaydiaCove Nerd Font Mono")

;; 光标：关掉 Neomacs 默认开启的彩色循环（cursor-color-cycle），光标回到主题的 cursor 颜色。
;; neomacs--effect-set 是它的内部接口（官方文档里的 neomacs-effect-set 实际不存在），升级后可能改名，
;; 所以先判断是否存在。想恢复：把 nil 改成 t；其他光标动画（拖尾、闪烁）是另外的效果，见 (neomacs-effect-names)。
(when (fboundp 'neomacs--effect-set)
  (neomacs--effect-set 'cursor-color-cycle :enabled nil))

;; 主题和行号
;; Catppuccin Macchiato：和系统配色（home/theme）一致。包在 packages.el 里声明，装了要 `doom sync`。
;; 风味可选 latte、frappe、macchiato、mocha；改风味后用 `M-x catppuccin-reload` 或重启。
(setq catppuccin-flavor 'macchiato)
(setq doom-theme 'catppuccin)
(setq display-line-numbers-type t)

;; org 文件目录（必须在 org 加载之前设置）
(setq org-directory "~/org/")

;; 编辑习惯
(setq-default indent-tabs-mode nil)     ; 缩进用空格
(setq-default fill-column 80)
(setq use-short-answers t)              ; yes/no 简写成 y/n

;; 快捷键：SPC ; 注释当前行（visual 模式下注释选中的行）。
;; 会顶掉 Doom 默认的 SPC ;（我记得是 pp-eval-expression，执行 Elisp 表达式；那个功能仍可用 M-: 或 M-x eval-expression）。
;; 想恢复默认：删掉这段，重启 Emacs。
(map! :leader
      :desc "Comment line" ";" #'comment-line)

;; 切换项目后（SPC p p）自动在左侧打开 dirvish 文件树。
;; dirvish-side 是开关：已显示时再调用会把光标移进侧边栏，所以先判断；
;; save-selected-window 让光标留在编辑窗口。树的根目录取当前文件所在的 git 仓库。
;; 限制：只对"切换项目"触发；直接从命令行 `neomacs 某目录` 启动、或手动 find-file 不会自动打开。
;; 不想要：删掉这段，重启 Emacs；手动开关仍是 SPC o p。
(defun +my/dirvish-side-open-h ()
  "Show the dirvish project sidebar unless it is already visible."
  (when (require 'dirvish-side nil t)
    (unless (dirvish-side-session-visible-p)
      (save-selected-window (dirvish-side)))))
(add-hook 'projectile-after-switch-project-hook #'+my/dirvish-side-open-h)
