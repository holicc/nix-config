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

;; 切换项目后（SPC p p）自动在左侧打开 treemacs 文件树。
;; +treemacs/toggle 是开关：已显示时再调用会把它关掉，所以先判断可见性；
;; save-selected-window 让光标留在编辑窗口。树里只显示当前项目。
;; 限制：只对"切换项目"触发；直接从命令行 `neomacs 某目录` 启动、或手动 find-file 不会自动打开。
;; 不想要：删掉这段，重启 Emacs；手动开关仍是 SPC o p。
(defun +my/treemacs-open-h ()
  "Show the treemacs project sidebar unless it is already visible."
  (when (require 'treemacs nil t)
    (unless (eq (treemacs-current-visibility) 'visible)
      (save-selected-window (+treemacs/toggle)))))
(add-hook 'projectile-after-switch-project-hook #'+my/treemacs-open-h)

;; 侧边栏宽度（treemacs 默认 35 列）；名字放不下可以再加大。
(setq treemacs-width 40)

;; tree-sitter 语法库：由 home-manager 预编译放在这个目录（见 home/emacs/default.nix），
;; 让 Emacs 直接加载，不用联网下载再现场编译。
(after! treesit
  (add-to-list 'treesit-extra-load-path (expand-file-name "~/.local/share/tree-sitter-grammars")))

;; Python 保存时格式化：apheleia 默认用 black，本机没装；改用已有的 ruff（ruff format，风格和 black 兼容），
;; 不额外装包。想换回 black：装 pkgs.black，并删掉这段。
(after! apheleia
  (setf (alist-get 'python-mode apheleia-mode-alist) 'ruff
        (alist-get 'python-ts-mode apheleia-mode-alist) 'ruff))

;; 复制到系统剪贴板：Neomacs 自己设置 Wayland 剪贴板时，需要一个"近期的输入事件序号"，
;; 拿不到就静默失败（粘贴到浏览器、终端没东西）。这里改成调用 wl-copy（wl-clipboard，已由 home/dev/system.nix 安装），
;; 它不依赖这个序号。已实测：没有焦点的窗口里 kill-new 也能让 wl-paste 读到，中文正常。
;; 反方向（从外部复制再粘贴进 Emacs）Neomacs 自己就能读，不用处理。
;; 没有 wl-copy 或不在 Wayland 下时，回退到原来的方式。想撤销：删掉这段，重启 Emacs。
(defun +my/wl-copy (text)
  "Put TEXT on the system clipboard through wl-copy."
  (let ((proc (make-process :name "wl-copy" :buffer nil :noquery t
                            :command '("wl-copy" "--type" "text/plain;charset=utf-8")
                            :connection-type 'pipe)))
    (process-send-string proc text)
    (process-send-eof proc)))
(when (and (getenv "WAYLAND_DISPLAY") (executable-find "wl-copy"))
  (setq interprogram-cut-function #'+my/wl-copy))

;; 终端：用 Doom 的 term 模块（SPC o t 开关底部弹出终端，SPC o T 在当前窗口打开），不用 Neomacs 自带的 neo-term
;; （它的配色在 Rust 里写死、不跟主题走，也不能指定启动目录）。term 的颜色走 Emacs 主题，从当前目录启动。
;; shell：multi-term 默认取 $SHELL，本机是 bash；Alacritty 是在配置里显式指定了 nu，这里同样指定 nu，和平时的终端一致。
;; 已在 Emacs 的 term 里实测 nu 能正常运行（Starship 提示符、中文输出都对）。找不到 nu 时是 nil，回退到默认。
(after! multi-term
  (setq multi-term-program (executable-find "nu")))
