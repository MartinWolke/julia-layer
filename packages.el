;;
;; Copyright (c) 2012-2017 Sylvain Benner & Contributors
;;
;; Author: Martin Wolke
;; URL: https://github.com/syl20bnr/spacemacs
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3

;;; Commentary:

;; See the Spacemacs documentation and FAQs for instructions on how to implement
;; a new layer:
;;
;;   SPC h SPC layers RET
;;
;;
;; Briefly, each package to be installed or configured by this layer should be
;; added to `julia-packages'. Then, for each package PACKAGE:
;;
;; - If PACKAGE is not referenced by any other Spacemacs layer, define a
;;   function `julia/init-PACKAGE' to load and initialize the package.

;; - Otherwise, PACKAGE is already referenced by another Spacemacs layer, so
;;   define the functions `julia/pre-init-PACKAGE' and/or
;;   `julia/post-init-PACKAGE' to customize the package as it is loaded.

;;; Code:

(defconst julia-packages
  '(ess
    outshine
    (lsp-mode :location (recipe
                         :fetcher github
                         :repo "emacs-lsp/lsp-mode"
                         :commit "ccf05dcae175302ab86cb264fb53125b3979df6f"))
    (lsp-julia :location local)
    (helm-xref :location elpa)
    flycheck)
  "The list of Lisp packages required by the julia layer.

Each entry is either:

1. A symbol, which is interpreted as a package to be installed, or

2. A list of the form (PACKAGE KEYS...), where PACKAGE is the
    name of the package to be installed or loaded, and KEYS are
    any number of keyword-value-pairs.

    The following keys are accepted:

    - :excluded (t or nil): Prevent the package from being loaded
      if value is non-nil

    - :location: Specify a custom installation location.
      The following values are legal:

      - The symbol `elpa' (default) means PACKAGE will be
        installed using the Emacs package manager.

      - The symbol `local' directs Spacemacs to load the file at
        `./local/PACKAGE/PACKAGE.el'

      - A list beginning with the symbol `recipe' is a melpa
        recipe.  See: https://github.com/milkypostman/melpa#recipe-format")


(defun julia/init-outshine ()
  (use-package outshine
    :defer t
    :init
    (progn
      (add-hook 'outline-minor-mode-hook 'outshine-hook-function))))

(defun julia/init-lsp-mode ()
  (use-package lsp-mode
    :init (advice-add #'lsp--text-document-hover-string :filter-return #'julia--hover-format)
    :config
    (progn
      (require 'lsp-flycheck))))

(defun julia/init-lsp-julia ()
  (use-package lsp-julia
    :after lsp-mode))

(defun julia/post-init-ess ()
  (use-package ess-site
    :init
    (progn
      (add-hook 'ess-julia-mode-hook 'auto-complete-mode)
      (add-hook 'ess-julia-mode-hook #'lsp-julia-enable))))

(defun julia/init-helm-xref ()
  (use-package helm-xref))

(defun julia/post-init-flycheck ()
  (add-hook 'ess-julia-mode-hook #'flycheck-mode))

;; (defun julia/pre-init-org ()
;;   (spacemacs|use-package-add-hook org
;;     :post-config (add-to-list 'org-babel-load-languages '(julia . t))))

(defun julia--line-at-location (file line)
  (with-temp-buffer
    (find-file file)
    (goto-char (point-min))
    (forward-line line)
    (substring (thing-at-point 'line t) 0 -2)))

(defun julia--location-to-xref (location)
  "Convert Location object LOCATION to an xref-item.
interface Location {
    uri: string;
    range: Range;
}"
  (lsp--send-changes lsp--cur-workspace)
  (let ((uri (string-remove-prefix "file://" (gethash "uri" location)))
        (ref-pos (gethash "start" (gethash "range" location))))
    (xref-make (julia--line-at-location uri (gethash "line" ref-pos))
               (xref-make-file-location uri
                                        (1+ (gethash "line" ref-pos))
                                        (gethash "character" ref-pos)))))


(defun julia--hover-format-flatten (message)
  (if eldoc-echo-area-use-multiline-p
      message
    (replace-regexp-in-string "\n" " " message)))


(defun julia--hover-format (message)
  (if eldoc-echo-area-use-multiline-p
    message
    (car (split-string message "\n"))))

(with-eval-after-load 'ess-site
  (add-hook 'ess-julia-mode-hook
          (lambda()
            (push '("function" . ?ƒ) prettify-symbols-alist)
            (prettify-symbols-mode))))

(with-eval-after-load 'lsp-julia
  ;; increase response timeout to 10 seconds
  (setq lsp-response-timeout 10)

  ;; only display first line of the docstring
  (setq eldoc-echo-area-use-multiline-p nil)
  (setq lsp-enable-eldoc t)

  ;; use helm-xref
  (require 'helm-xref)
  (setq xref-show-xrefs-function 'helm-xref-show-xrefs)

  ;; replace xref message
  (defun lsp--location-to-xref (location)
    (julia--location-to-xref location))

  (spacemacs/declare-prefix-for-mode 'ess-julia-mode "mg" "julia/goto")
  (spacemacs/declare-prefix-for-mode 'ess-julia-mode "mh" "julia/docs")
  (spacemacs/declare-prefix-for-mode 'ess-julia-mode "ms" "julia/repl")
  (spacemacs/declare-prefix-for-mode 'ess-julia-mode "ml" "julia/LanguageServer")
  (spacemacs/declare-prefix-for-mode 'ess-julia-mode "ml" "julia/tests")
  (spacemacs/set-leader-keys-for-major-mode 'ess-julia-mode
    "gd" 'xref-find-definitions))



;;; packages.el ends here
