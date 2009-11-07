(defpackage #:squirl-demo
  (:use :cl :uid :squirl :sheeple))
(in-package :squirl-demo)

(defproto =squirl-demo= (=engine=)
  ((title "Demo for SquirL")
   (window-width 500)
   (window-height 500)
   (world nil)
   (accumulator 0)
   (physics-timestep 1/100)
   (shape-dimension 30)
   (shape-dimension-increment 10)))

(defun draw-a-circle (circle)
  (let* ((position (body-position circle))
         (x (vec-x position))
         (y (vec-y position)))
    (draw-circle (make-point x y) 15 :resolution 30)))

(defun draw-body (body)
  (let* ((position (body-position body))
         (x (vec-x position))
         (y (vec-y position)))
    (with-color *green*
     (map nil #'draw-shape (body-shapes body)))
    (draw-circle (make-point x y) 2 :resolution 30 :color *red*)))

(defreply init ((demo =squirl-demo=))
  (setf (world demo) (make-world :gravity (vec 0 -100)))
  (let ((body (make-body :position (vec 250 60)))
        (floor (make-segment (vec -200 0) (vec 200 0) :elasticity 1 :friction 1))
        (left-wall (make-segment (vec -200 0) (vec -200 200) :elasticity 1 :friction 1))
        (right-wall (make-segment (vec 200 0) (vec 200 200) :elasticity 1 :friction 1)))
    (mapc (lambda (_) (attach-shape _ body))
          (list floor left-wall right-wall))
    (world-add-body (world demo) body)))

(defgeneric draw-shape (shape)
  (:method ((circle circle))
    (let* ((circle-center (circle-transformed-center circle))
           (edge (vec* (body-rotation (shape-body circle))
                       (circle-radius circle)))
           (edge-t (vec+ edge circle-center))
           (edge-neg-t (vec- circle-center edge)))
      (draw-circle (make-point (vec-x circle-center) (vec-y circle-center))
                   (round (circle-radius circle)) :filledp nil)
      (draw-line (make-point (vec-x edge-t) (vec-y edge-t))
                 (make-point (vec-x edge-neg-t) (vec-y edge-neg-t)))))
  (:method ((seg segment))
    (let ((a (segment-trans-a seg))
          (b (segment-trans-b seg)))
      (draw-line (make-point (vec-x a) (vec-y a))
                 (make-point (vec-x b) (vec-y b)))))
  (:method ((poly poly))
    (let ((vertices (poly-transformed-vertices poly)))
      (loop for i below (length vertices)
         for a = (elt vertices i)
         for b = (elt vertices (mod (1+ i) (length vertices)))
         do (draw-line (make-point (vec-x a) (vec-y a))
                       (make-point (vec-x b) (vec-y b)))))))

(defun draw-scale (length x y)
  (let ((left (make-point (- x (/ length 2)) y))
        (right (make-point (+ x (/ length 2)) y))
        (half-edge-height 2))
    (draw-line left right :color *red*)
    (draw-line (make-point (point-x left)
                           (- (point-y left) half-edge-height))
               (make-point (point-x left)
                           (+ (point-y left) half-edge-height))
               :color *blue*)
    (draw-line (make-point (point-x right)
                           (- (point-y left) half-edge-height))
               (make-point (point-x right)
                           (+ (point-y left) half-edge-height))
               :color *blue*)))

(defreply draw ((demo =squirl-demo=) &key)
  (map nil #'draw-body (world-bodies (world demo)))
  (draw-scale (shape-dimension demo) (mouse-x demo) (mouse-y demo)))

;; This allows us to fix the physics timestep without fixing the framerate.
;; This means the physics -should- run at the same perceived speed no matter
;; how fast your computer's calculating :)
(defreply update ((demo =squirl-demo=) dt &key)
  (update-world-state demo dt)
  (empty-out-bottomless-pit (world demo)))

(defun update-world-state (demo dt)
  (incf (accumulator demo) (if (> dt 0.5) 0.5 dt))
  (loop while (>= (accumulator demo) (physics-timestep demo))
     do (world-step (world demo) (physics-timestep demo))
     (decf (accumulator demo) (physics-timestep demo)))
  (when (key-down-p #\s)
    (add-circle demo (mouse-x demo) (mouse-y demo))))

(defun empty-out-bottomless-pit (world)
  "Get rid of any bodies that have fallen into the bottomless pit."
  (map nil (lambda (c) (world-remove-body world c))
       (remove-if (lambda (c) (> (vec-y (body-position c)) -100))
                  (world-bodies world))))

(defun add-circle (demo x y)
  (let* ((mass (shape-dimension demo))
         (radius (/ (shape-dimension demo) 2))
         (inertia (moment-for-circle mass 0 radius (vec 0 0)))
         (body (make-body :mass mass :inertia inertia :position (vec x y))))
    (attach-shape (make-circle radius :elasticity 0.5 :friction 1) body)
    (world-add-body (world demo) body)))

(defun add-poly (demo x y)
  (let* ((mass (shape-dimension demo))
         (size (/ (shape-dimension demo) 2))
         (verts (list (vec (- size) (- size))
                      (vec (- size) size)
                      (vec size size)
                      (vec size (- size))))
         (body (make-body :mass mass :inertia (squirl:moment-for-poly mass 4 verts)
                          :position (vec x y))))
    (attach-shape (make-poly verts) body)
    (world-add-body (world demo) body)))

(defreply mouse-down ((engine =squirl-demo=) button)
  (case button
    (0 (add-circle engine (mouse-x engine) (mouse-y engine)))
    (1 (add-poly engine (mouse-x engine) (mouse-y engine)))
    (3 (incf (shape-dimension engine) (shape-dimension-increment engine)))
    (4 (decf (shape-dimension engine) (shape-dimension-increment engine)))))

(defreply key-down ((engine =squirl-demo=) key)
  (case key
    (#\] (incf (shape-dimension engine) (shape-dimension-increment engine)))
    (#\[ (unless (<= (shape-dimension engine)
                     (shape-dimension-increment engine))
           (decf (shape-dimension engine)
                 (shape-dimension-increment engine)))))
  (call-next-reply))

(defun run-demo ()
  (run =squirl-demo=))
