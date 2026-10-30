;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Doom 的个人配置，由 home-manager 链接到 ~/.config/doom/config.el（见 home/emacs/default.nix），
;; 直接编辑本文件，`doom sync` 之后或重启 Emacs 生效（只改 config.el 重启即可，不用 sync）。

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
(setq doom-theme 'doom-one)
(setq display-line-numbers-type t)

;; org 文件目录（必须在 org 加载之前设置）
(setq org-directory "~/org/")

;; 编辑习惯
(setq-default indent-tabs-mode nil)     ; 缩进用空格
(setq-default fill-column 80)
(setq use-short-answers t)              ; yes/no 简写成 y/n
