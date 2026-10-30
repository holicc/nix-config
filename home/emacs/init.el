;;; init.el --- Emacs 配置  -*- lexical-binding: t; -*-

;; 由 home-manager 链接到 ~/.config/emacs/init.el（见 home/emacs/default.nix），
;; 直接编辑本文件，重启 Emacs 生效。

;; 界面：去掉启动页、工具栏、菜单栏、滚动条
(setq inhibit-startup-screen t)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

;; 字体：英文用 CaskaydiaCove Nerd Font，中文回退到 Noto Sans CJK SC（都由系统字体模块安装）
(set-face-attribute 'default nil :family "CaskaydiaCove Nerd Font" :height 130)
(set-fontset-font t 'han (font-spec :family "Noto Sans CJK SC"))

;; 编辑习惯
(setq-default indent-tabs-mode nil)     ; 缩进用空格
(setq-default fill-column 80)
(global-display-line-numbers-mode 1)    ; 行号
(column-number-mode 1)                  ; mode-line 显示列号
(electric-pair-mode 1)                  ; 括号自动配对
(save-place-mode 1)                     ; 记住上次光标位置
(recentf-mode 1)                        ; 最近打开的文件
(setq use-short-answers t)              ; yes/no 简写成 y/n

;; 备份和自动保存文件集中放到一处，不污染项目目录
(let ((dir (expand-file-name "backups/" user-emacs-directory)))
  (make-directory dir t)
  (setq backup-directory-alist `(("." . ,dir))
        auto-save-file-name-transforms `((".*" ,dir t))))

;; Custom 界面写入的设置放到单独文件，避免弄脏本文件
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file))

;;; init.el ends here
