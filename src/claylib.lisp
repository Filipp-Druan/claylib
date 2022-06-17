;;;; claylib.lisp

(in-package #:claylib)

(defparameter +claylib-directory+ (asdf:system-source-directory :claylib))

(defvar *garbage* ())

(defun free-later (thing)
  (pushnew thing *garbage*))

(defun collect-garbage ()
  (mapcar #'free *garbage*)
  (setf *garbage* ()))

(defmacro with-2d-mode (camera &body body)
  `(progn
     (begin-mode2d (c-struct ,camera))
     ,@body
     (end-mode2d)))

(defmacro with-3d-mode (camera &body body)
  `(progn
     (begin-mode3d (c-struct ,camera))
     ,@body
     (end-mode3d)))

(defun clear-background (&key (color *claylib-background*))
  "Set background to COLOR or *CLAYLIB-BACKGROUND* by default."
  (claylib/ll:clear-background (c-struct color)))

(defmacro with-texture-mode ((render-texture &key (clear *claylib-background*)) &body body)
  "Execute BODY while drawing to the given RENDER-TEXTURE. CLEAR is the RL-COLOR to set the initial
background of the render texture, or NIL to skip clearing."
  `(progn
     (begin-texture-mode (c-struct ,render-texture))
     ,(when clear
       `(clear-background :color ,clear))
     ,@body
     (end-texture-mode)))

;; FIXME Problem with this approach: entering a nested do-game-loop will overwrite *SCENE*
(defmacro do-game-loop ((&key
                           (scene nil)
                           (livesupport nil)
                           (vars ())
                           (end ())
                           (result ()))
                        &body body)
  "Execute a game loop.

When given, this will load SCENE, enable LIVESUPPORT during execution of the loop, expose the
bindings in VARS to the loop BODY, stop the loop when END is non-nil, and return RESULT.

To switch scenes in the loop body, use (SWITCH-SCENE MY-NEW-SCENE). SWITCH-SCENE loads the new scene
and unloads the previous scene automatically. The current scene is accesible via *SCENE*."
  `(progn
     ;; Setup the initial *SCENE* as given by SCENE
     (when ,scene
       (setf *scene* ,scene)
       (setup-scene *scene*))
     (do ,vars ((or (window-should-close-p) ,end)
                (tear-down-scene *scene*) ; Tear-down and reset *SCENE*
                (setf *scene* nil)        ; at the end of the loop
                ,result)
       ,@(when livesupport `((declare (notinline))))
       ;; Execute the loop body with optional livesupport
       ,(if livesupport
            `(livesupport:continuable
               ,@body
               (livesupport:update-repl-link))
            `(progn ,@body)))))

(defmacro with-window ((&key
                          (width *screen-width*)
                          (height *screen-height*)
                          (title "")
                          (fps *target-fps*)
                          (flags ())
                          (min-size ()))
                       &body body)
  `(progn
     (claylib/ll:init-window ,width ,height ,title)
     (claylib/ll:set-target-fps ,fps)
     (setf +default-font+ (load-font-default))
     ,(when flags
        `(claylib/ll:set-config-flags (reduce #'+ ,flags)))
     ,(when min-size
        `(claylib/ll:set-window-min-size ,(car min-size) ,(cadr min-size)))
     ,@body
     (free +default-font+)
     (collect-garbage)
     (when (is-window-ready-p)
       (close-window))))

(defmethod draw-object ((obj list))
  (mapc #'draw-object obj))

(defmethod free ((obj list))
  (mapc #'free obj))
