(in-package :gui)

;;; Contains NO direct dependencies on OpenGL or TK.

#|
This file implements commands on images and objects invoked by various GUI callbacks.
|#


;;; ******************  BASIC MOUSE DRAGGING INFRASTRUCTURE  ******************


;;; This is directly called from tkglwin widget
(defmethod glwin-drag-callback (panel widget window-pos)
  (let* ((interactor *interactor*))
    (with-class-slots interactor
	  (current-window popup-drag drag-op drag-object-type
			  current-window-pos window-motion)
	interactor
      (let* ((image-op (image-drag-p interactor))
	     (window (widget-window widget))
	     (current-view (current-view interactor))
	     (*current-view* current-view)
	     )
	;; (format t "drag-callback ~a~%"(list  widget popup-drag drag-op image-op))
	(when (and popup-drag drag-op)
	  (set-state interactor window window-pos)
	  (bind-vector-elements (dx dy) window-motion
	    (unless (and (zerop dx) (zerop dy))
	      (unless (select-drag-p interactor)
		(warp-pointer-to-center interactor))
	      (when current-view
		(catch 'bypass-redisplay
		  (let ((object (selected-object interactor)))
		    ;;(format t "glwin-drag-callback ~a ~a~%" dx dy)
		    (funcall drag-op object interactor)
		    (if image-op
			(redisplay current-view)
			(when object
			  (update-object-after object)
			  (redisplay-all-world-views
			   interactor (world object)
			   :drag-redisplay t)))))))))
	(update-selection-panel)
	))))



;;; FIXME: Lots of calls into tk to get window-width window-height window-rootx
;;; window-rooty screen-width screen-height.  These should be cached
;;; somewhere.  The problem is knowing when to update the cache.
;;; glwin-configure-callback occurs whenever the window is resized.
;;; glwin-expose-callback occurs whenever window window is moved.

;;;(defun warp-pointer-to-center (interactor)
;;;  (with-class-slots interactor
;;;        (current-window current-window-pos root-position dimensions) interactor
;;;    (let* ((widget (widget current-window))
;;;           (wid (window-width widget))
;;;           (hi (window-height widget))
;;;           (rootx (window-rootx widget))
;;;           (rooty (window-rooty widget))
;;;           (screen-left (max 0 rootx))
;;;           (screen-right (min (screen-width widget) (+ rootx wid)))
;;;           (screen-top (max 0 rooty))
;;;           (screen-bottom (min (screen-height widget) (+ rooty hi)))
;;;           (screen-center-x (ash (+ screen-left screen-right) -1))
;;;           (screen-center-y (ash (+ screen-top screen-bottom) -1))
;;;           (center-x (- screen-center-x rootx))
;;;           (center-y (- screen-center-y rooty)))
;;;      (declare (fixnum wid hi rootx rooty screen-left screen-right
;;;                       screen-top screen-bottom screen-center-x screen-center-y
;;;                       center-x center-y))
;;;      ;; warp pointer to center of window
;;;      (warp-pointer current-window center-x center-y)
;;;      ;; remember pointer position
;;;      (setf current-window-pos (cv (dfloat center-x) (dfloat center-y) 0.0))
;;;      )))


;;; Warp the mouse pointer to the center of the window.  If the center of the
;;; window off the edge of the screen, the x-server warps it to the edge of the
;;; screen, getting spurious mouse motions.  We really need to warp it to the
;;; center of the visible area on the screen.

;;; Make sure that a call is made to UPDATE-WINDOW-PARAMETERS
;;; before calling this.  Best done in start-grab.
(defun warp-pointer-to-center (interactor)
  (with-class-slot-values interactor (current-window) interactor
    (with-slot-values (dimensions root-position screen-dimensions) current-window
      (destructuring-bind (wid hi) dimensions
	(destructuring-bind (screen-width screen-height) screen-dimensions
	  (destructuring-bind (rootx rooty) root-position
	    (let* ((screen-left (max 0 rootx))
		   (screen-right (min screen-width (+ rootx wid)))
		   (screen-top (max 0 rooty))
		   (screen-bottom (min screen-height (+ rooty hi)))
		   (screen-center-x (ash (+ screen-left screen-right) -1))
		   (screen-center-y (ash (+ screen-top screen-bottom) -1))
		   (center-x (- screen-center-x rootx))
		   (center-y (- screen-center-y rooty)))
	      (declare (fixnum wid hi rootx rooty screen-left screen-right
			       screen-top screen-bottom screen-center-x screen-center-y
			       center-x center-y))
	      ;; warp pointer to center of window
	      (warp-pointer current-window center-x center-y)
	      ;; remember pointer position
	      (setf (current-window-pos interactor)
		    (cv (dfloat center-x) (dfloat center-y) 0.0))
	      )))))))

(defmethod set-cursor ((window t) cursor-name)
  (tk::set-mouse-cursor (widget window) cursor-name))

;;; Warping the pointer in Mac OS X incurs a LOT of overhead, for some
;;; reason.  This is a mod that only warps if we have moved more than
;;; 80 pixels manhattan distance away from the center.

#+(or agl cocoa)
(defun warp-pointer-to-center (interactor)
  (with-class-slot-values interactor (current-window current-window-pos) interactor
    (with-slot-values (dimensions root-position screen-dimensions) current-window
      (destructuring-bind (wid hi) dimensions
	(destructuring-bind (screen-width screen-height) screen-dimensions
	  (destructuring-bind (rootx rooty) root-position
	    (let* ((screen-left (max 0 rootx))
		   (screen-right (min screen-width (+ rootx wid)))
		   (screen-top (max 0 rooty))
		   (screen-bottom (min screen-height (+ rooty hi)))
		   (screen-center-x (ash (+ screen-left screen-right) -1))
		   (screen-center-y (ash (+ screen-top screen-bottom) -1))
		   (center-x (- screen-center-x rootx))
		   (center-y (- screen-center-y rooty))
		   (thresh  (round (min wid hi) 3))
		   )
	      (declare (fixnum wid hi rootx rooty screen-left screen-right
			       screen-top screen-bottom screen-center-x screen-center-y
			       center-x center-y))
	      ;; warp pointer to center of window
	      (when (>
		     (+ (abs (- (aref current-window-pos 0) center-x))
			(abs (- (aref current-window-pos 1) center-y)))
		     thresh)
		(warp-pointer current-window center-x center-y)
		;; remember pointer position
		(setf (current-window-pos interactor)
		      (cv (dfloat center-x) (dfloat center-y) 0.0)))
	      )))))))

;;; set the mouse cursor to blank (invisible)
(defmethod set-blank-cursor ((window t))
  (set-cursor (widget window)
              #-mswindows
              (format nil "@~a black" (truename "$FREEDIUSTK/tk/library/blank.xbm"))
              ;; This is just insane.  For this particular command,
              ;; the forward slashes are crucial, so we can't just do
              ;; a truename.
              #+mswindows
              (format nil "{@~a/tk/library/blank.cur}"
		      #-sbcl (sys::getenv "FREEDIUSTK")
		      #+sbcl (sb-posix::getenv "FREEDIUSTK")
		      )
              ;; (format nil "{@~a}" (truename "$FREEDIUS/tk/library/blank.cur"))
              ))

;;; reset the "normal" mouse cursor
(defmethod unset-blank-cursor ((window t))
  (set-cursor (widget window) ""))
  
;;;
;;; These MUST be methods if we wish to conditionalize on CLIM usage:
;;;
(defmethod enable-no-mouse-button-motion-callback (window)
  (tcl-cmd `(bind ,(widget window) "<Motion>" "{qcme_mouse_handler %W motion %b %s %x %y ;  break }")))

(defmethod disable-no-mouse-button-motion-callback (window)
  (tcl-cmd  `(bind ,(widget window) "<Motion>" "")))

  
#|
(tk::set-mouse-cursor "." "crosshair black")
(tk::set-mouse-cursor (widget (selected-window)) "crosshair black")
(tk::set-mouse-cursor (tk::widget-toplevel (widget (selected-window))) "crosshair yellow")
(tk::set-mouse-cursor (tk::widget-toplevel (widget (selected-window))) "")
(warp-pointer-to-center *interactor*)
(tcl-cmd `(,(widget (view-window (top-view))) config -cursor
	   ,(format nil "@~a black" (truename "$FREEDIUS/tk/library/blank.xbm"))))
(tcl-cmd `(,(widget (view-window (top-view))) config -cursor ""))
(tcl-cmd `(,(widget (view-window (top-view))) config -cursor tcross))
(tcl-cmd `(,(widget (view-window (top-view))) cget -cursor ))

(let ((tk::*tk-verbose* t))
  (tcl-cmd `(bind ,(widget (view-window (top-view))) "<Motion>" "{qcme_mouse_handler %W motion %b %s %x %y ;  break }")))
(let ((tk::*tk-verbose* t))
  (tcl-cmd  `(bind ,(widget (view-window (top-view))) "<Motion>" "")))
|#


;;; Called for <Motion> events with no mouse buttons.
#+out-of-date-and-unused
(defmethod glwin-free-motion-callback (panel widget window-pos)
  (let ((interactor *interactor*))
    (with-class-slots interactor
	  (selected-objects current-window popup-drag drag-op drag-object-type
			    current-window-pos window-motion)
	interactor
      (let* ((window (widget-window widget))
	     (current-view (current-view interactor)))
	(set-state interactor window window-pos)
	(when current-view
	  (let ((previously-selected-objects selected-objects))
	    (catch 'bypass-redisplay
	      (drag-select-object interactor))
	    (when nil ;(and previously-selected-objects (null selected-objects))
	      (redisplay current-view :from-backing-store nil))
	    ))))))


;;; This needs to be here since it depends on class INTERACTOR being defined
;;; This is directly called from Glwin widget
;;;(defmethod glwin-mouse-buttonrelease-callback (panel widget)
;;;  (declare (ignore panel))
;;;  (let ((window (widget-window widget)))
;;;    (with-class-slots interactor (drag-op popup-drag) *interactor*
;;;      (let ((op drag-op))
;;;        ;;(format t "glwin-mouse-buttonrelease-callback ~a~%" drag-op)
;;;        (setq drag-op 'drag-uv popup-drag nil) ; why do we transition to 'drag-uv?
;;;        (unless (eq op 'drag-select-object) ; why is this conditional?
;;;          (stop-drag *interactor* window))
;;;        ))))

;;; This needs to be here since it depends on class INTERACTOR being defined
;;; This is directly called from Glwin widget
;;; This seems to work.  Not sure why the previous version of the method was needed before.
;;;(defmethod glwin-mouse-buttonrelease-callback (panel widget button state)
;;;  (declare (ignore panel))
;;;  (with-class-slots interactor (drag-op popup-drag) *interactor*
;;;    (setq drag-op nil popup-drag nil) 
;;;    (stop-drag *interactor* (widget-window widget))))

;(fmakunbound 'glwin-mouse-buttonrelease-callback)
(defmethod glwin-mouse-buttonrelease-callback (panel widget mouse-event)
  (declare (ignore panel))
  (mv-bind (function drag-type wheel-op)
      (get-mouse-event-function (get-mouse-event-table (widget-window widget)) mouse-event)
    (when (and function (not wheel-op))
      ;; ignore unhandled event names.
      (with-class-slots interactor (drag-op popup-drag drag-object-type) *interactor*
	;(format t "glwin-mouse-buttonrelease-callback ~a~%" (list mouse-event popup-drag drag-object-type))
	(when drag-object-type
	  (setq drag-op nil popup-drag nil) 
	  (stop-drag *interactor* (widget-window widget)))))))


(defmethod object-drag-p ((interactor interactor))
  (with-class-slot-values interactor (popup-drag drag-object-type drag-op) interactor
    (and popup-drag
	 (not (eq drag-object-type 'image))
	 (not (eq drag-op 'drag-select-object)))))
  
(defmethod image-drag-p ((interactor interactor))
  (with-class-slots interactor (popup-drag drag-object-type) interactor
    (and popup-drag (eq drag-object-type 'image))))
  
;;;(defmethod select-drag-p ((interactor interactor))
;;;  (with-class-slots interactor (popup-drag drag-op) interactor
;;;    (and popup-drag (eq drag-op 'drag-select-object))))

;;;(defmethod select-drag-p ((interactor interactor))
;;;  (with-class-slots interactor (popup-drag drag-object-type) interactor
;;;    (and popup-drag (eq drag-object-type 'drag-select))))

(defmethod select-drag-p ((interactor interactor))
  (with-class-slots interactor (popup-drag drag-object-type) interactor
    (eq drag-object-type 'drag-select)))

(defmethod stop-drag (interactor window)
  (unless (select-drag-p interactor)
    (disable-no-mouse-button-motion-callback window)
    ;(break)
    (unset-blank-cursor window))
  ;;(format t "stop-drag ~a~%" window)
  (when (eq (drag-object-type interactor) 'image)
    (let ((view (top-view window)))
      (when view
	(redisplay view))))
  ;; added Mon Feb 23 2004
  (setf (drag-object-type interactor) nil)
  (setf (popup-drag interactor) nil)
  )

(defun start-drag (interactor new-drag-op drag-object-type)
  (with-class-slots interactor
      (popup-drag drag-op drag-start-window-pos current-window-pos current-window )
      interactor
    (update-window-parameters current-window)

    ;(format t "start-drag ~a ~a ~%" current-window popup-drag)
      ;; (when popup-drag (break))
    (unless popup-drag			; This is needed for starting drag from popup menu
      (setf drag-op new-drag-op
	    popup-drag t
	    (drag-object-type interactor) drag-object-type
	    drag-start-window-pos current-window-pos
	    ))
    ;(format t "start-drag ~a~%" (list new-drag-op drag-object-type popup-drag (select-drag-p interactor)))
    (unless (select-drag-p interactor)
      (warp-pointer-to-center interactor) 
      ;; Attempt to fix an occasional bug if mouse is moving when command is inititiated.
      ;; Call  tk::do-events to suck up and ignore all pending motion events
      (let ((*ignore-tk-motion-callbacks* t)) (tk::do-events))
      (enable-no-mouse-button-motion-callback current-window)
      (set-blank-cursor current-window))
    
    ;; The selected-object should be outside the object-sets of the views,
    ;; making the following unnecessary.  
    ;; This assumes the backing-store properly contains the object-sets with
    ;; backing-store-p = T.
    (unless (or (image-drag-p interactor) (select-drag-p interactor))
      (let ((object (selected-object interactor)))
	(when object
	  ;;(format t "start-drag (or (image-drag-p interactor) (select-drag-p interactor))~%")
	  (update-object-before object)
	  (let (views-requiring-redisplay)
	    (map-over-active-object-views
	     (object view)
	     (when (redisplay-required view interactor)
	       (push view views-requiring-redisplay)))
	    ;; Must compute this list first, since redisplay changes the
	    ;; object-sets, making it impossible to determine if other than the
	    ;; first view requires redisplay.
	    (loop for view in views-requiring-redisplay
		  ;;do (format t "redisplay ~a~%" view)
		  do (redisplay view))
	    ;;(describe *interactor*)
	    ;(format t "~a~%" views-requiring-redisplay) ;(glFinish) (break)
	    ))
	))))

(defun start-image-drag (interactor new-drag-op)
  (start-drag interactor new-drag-op 'image))
  
(defun start-object-drag (interactor new-drag-op)
  (when (selected-objects)
    (start-drag interactor new-drag-op 'gl-object)))

(defvar *image-pos-vector* (math::cv 0.0 0.0 0.0))
(defvar *2d-pos-vector* (math::cv 0.0 0.0 0.0))

;;;(defmethod show-image-point-info (pos view)
;;;  (let* ((window-to-2d (transforms::inverse-transform
;;;                        (transforms::2d-to-window-transform view)))
;;;         (2d-to-image  (transforms::inverse-transform
;;;                        (transforms::image-to-2d-transform view)))
;;;         (window-to-image (transforms::compose-transforms window-to-2d 2d-to-image)))
;;;    (declare (ignorable window-to-image))
;;;    (transforms::transform-vector window-to-2d pos *2d-pos-vector*)
;;;    (format t "~%window x,y = (~5f,~5f); " (aref pos 0) (aref pos 1)) ;
;;;    (format t "2D x,y = (~5f,~5f); " (aref *2d-pos-vector* 0) (aref *2d-pos-vector* 1))
;;;    (transforms::transform-vector 2d-to-image *2d-pos-vector* *image-pos-vector*)
;;;    (let ((image (view-image view))
;;;          (u (round (aref *image-pos-vector* 0)))
;;;          (v (round (aref *image-pos-vector* 1))))
;;;      (format t "image x,y = (~d,~d); " u v)
;;;      (when (and image
;;;                 (img::image-p image)
;;;                 (< -1 u (img::image-x-dim image))
;;;                 (< -1 v (img::image-y-dim image)))
;;;        ;;(format t "intensity = ~a)" (multiple-value-list (img::c-iref image u v)))
;;;        ;;(format t "intensity = ~a)" (multiple-value-list (img::mv-iref image u v)))
;;;        (format t "intensity = ~a)" (img::iref* image u v))
;;;        ))
;;;    (terpri)
;;;    (force-output)
;;;    ))

;;;(defun image-pixel-string (image u v)
;;;  (setq u (floor u) v (floor v))
;;;  (when (and image
;;;             (img::image-p image)
;;;             (< -1 u (img::image-x-dim image))
;;;             (< -1 v (img::image-y-dim image)))
;;;    (let ((pixel-components
;;;           (multiple-value-list (img::mv-iref image u v))
;;;           ))
;;;      (if (< (length pixel-components) 2)
;;;          (format nil "~a" (car pixel-components))
;;;          (format nil "~a" pixel-components)))))

#|
(defmethod image-pixel-string ((image img::image) u v)
  (setq u (floor u) v (floor v))
  (when (and image
	     (img::image-p image)
	     (< -1 u (img::image-x-dim image))
	     (< -1 v (img::image-y-dim image)))
    (format nil "~a" (img::diref* image u v))))

;;; need this for paged-image-rgb also
(defmethod image-pixel-string ((image img::array-image-rgb) u v)
  (setq u (floor u) v (floor v))
  (when (and image
	     (img::image-p image)
	     (< -1 u (img::image-x-dim image))
	     (< -1 v (img::image-y-dim image)))
    (format nil "~a" (img::vdiref image u v))))
|#

(defun image-pixel-string (image u v)
  (format nil "~a" (image-pixel-value image u v)))

(defmethod image-pixel-value ((image img::image) u v)
  (setq u (floor u) v (floor v))
  (when (and image
	     (img::image-p image)
	     (< -1 u (img::image-x-dim image))
	     (< -1 v (img::image-y-dim image)))
    (img::diref* image u v)))

;;; need this for paged-image-rgb also
(defmethod image-pixel-value ((image img::array-image-rgb) u v)
  (setq u (floor u) v (floor v))
  (when (and image
	     (img::image-p image)
	     (< -1 u (img::image-x-dim image))
	     (< -1 v (img::image-y-dim image)))
    (img::vdiref image u v)))

(declaim (special *cme-selection-panel*))
(declaim (special *most-recent-pixel-value*))

;; Certain other types of view do not contain images, so should be
;; handled differently, e.g., for timelines, we may want to show the
;; timestamp at a given point, or the events that are active at that
;; point...

(defmethod show-image-point-info (pos (view view))
  (if *cme-selection-panel*
      (update-selection-panel)
      (progn
	(inverse-transform-vector (2d-to-window-transform view) pos *2d-pos-vector*)
	(inverse-transform-vector (image-to-2d-transform view) *2d-pos-vector* *image-pos-vector*)
	;;(transform-vector (inverse-transform (image-to-2d-transform view)) *2d-pos-vector* *image-pos-vector*)
	(tk::with-output-to-slime-repl
	    (let* ((image (view-image view))
		   (u (round (aref *image-pos-vector* 0)))
		   (v (round (aref *image-pos-vector* 1)))
		   (doc-line (format nil "W(~3d,~3d) 2D(~5,1f,~5,1f) I(~5,1f,~5,1f)"
				     (aref pos 0) (aref pos 1)
				     (aref *2d-pos-vector* 0) (aref *2d-pos-vector* 1)
				     (aref *image-pos-vector* 0) (aref *image-pos-vector* 1)))
		   (value   (ignore-errors (setq *most-recent-pixel-value* (and image (image-pixel-value image u v)))))
		   (image-pixel-string (format nil "~a" value)))
	      (progn
		(format t "~%window x,y = (~5f,~5f); " (aref pos 0) (aref pos 1)) ;
		(format t "2D x,y = (~5f,~5f); " (aref *2d-pos-vector* 0) (aref *2d-pos-vector* 1))
		(format t "image x,y = (~d,~d); " u v)
		)
	      (when image-pixel-string
		;;(format t "intensity = ~a)" (multiple-value-list (img::c-iref image u v)))
		(setq doc-line (format nil "~a Pixel ~a" doc-line image-pixel-string))
		(format t "intensity = ~a)" image-pixel-string))
	      (set-documentation2 doc-line))
	  (terpri)
	  (force-output)
	  ))))

(declaim (special *feedback-buffer*))

#+old
(defmethod highlight-drag-select-object ((interactor interactor))
  (when (selected-objects interactor)
    (unhighlight-selected-objects))
  ;; Not sure about setting selected-window here.
  (setf (selected-window interactor) (current-window interactor))
  (setq *feedback-buffer* nil)
  (start-drag interactor 'drag-select-object 'drag-select)
  (catch 'bypass-redisplay (funcall (drag-op interactor) interactor))
  )



(defmethod deselect-objects ((interactor interactor))
  (when (selected-objects interactor)
    (unhighlight-selected-objects)
    (setf (selected-objects interactor) nil)))

;;; Connolly version
;;; This is not a drag-op, but initiates the DRAG-SELECT-OBJECT drag operation
(defmethod highlight-drag-select-object (interactor)
  (when (selected-objects interactor)
    (unhighlight-selected-objects))
  ;; Connolly addition
  (let ((win (current-window interactor))
	(pos (current-window-pos interactor)))
    (setf (selected-window interactor) win)
    (when win
      (let ((view (top-view win)))
	(when view
	  (progn ;ignore-errors
	    (show-image-point-info pos view))
	  (tk::print-and-set-top-level-variables (list (view-image view)))
    
	  ;; This is dangerous - drastic slowdown on Linux.  How about a mode switch toggle?
	  ;; #+never
	  (progn (setq *feedback-buffer* nil)
		 (start-drag interactor 'drag-select-object 'drag-select)
		 (catch 'bypass-redisplay (funcall (drag-op interactor) nil interactor)))
	  )))))



;;; *********************  OPERATIONS ON 2D-TO-WINDOW-TRANSFORM  *********************

;;; *********************  2D MOTION  *********************

;;(defparameter *drag-amplification* 4.0)
(defparameter *drag-amplification* 1.0)

(defmethod drag-uv (object interactor)
  (declare (ignore object))
  (with-class-slot-values interactor (window-motion) interactor
    (bind-vector-elements (dx dy) window-motion
      ;;(format t "drag-uv ~a ~a~%" window-motion (2d-to-window-transform (current-view interactor)))
      ;;(format t "drag-uv ~a ~a~%" (current-window-pos interactor) window-motion)
      (let ((s *drag-amplification*))
        (declare (double-float s))
	(let ((view (current-view interactor))
	      (delta (cv (* s dx) (* s dy) 0.0)))
	  (move-by (2d-to-window-transform view)
		   delta)
	  ;; Mod -CIC 4/13/2006 - If this view is in a spatial group,
	  ;; translate ALL views in the group.
	  (translate-spatial-tandem-views view delta)
	  )))))

;;; *********************  2D SCALE AND ROTATION   *********************

(defparameter *scale-change-per-screen-motion* 32.0)
(defparameter *rotation-per-screen-motion* (/ 360.0 1280))
(defparameter *tmpmat* (make-4x4-matrix ))

;;; pin-position is in window-coordinates
(defmethod scale-rot-relative-to ((interactor interactor) pin-position)
  ;;(format t "scale-rot-relative-to ~%")
  (with-class-slot-values interactor (window-motion) interactor
    (bind-vector-elements (dx dy) window-motion
      (let* ((view (current-view interactor)) ;(win current-window)
	     ;; 360 degreen motion for for full screen width motion
	     (dtheta (* (the double-float *rotation-per-screen-motion*) dx))
	     ;; allow factor of 16 scale change for half screen height motion
	     (dscale (expt (the double-float *scale-change-per-screen-motion*)
			   (/ dy 1024.0)))
	     (2d-to-window-transform (2d-to-window-transform view))
	     )
	(when (get-prop view :inhibit-scale-rot-rotation) (setq dtheta 0.0))
	;; Mod -CIC 4/13/2006 - If the view is in a SPATIAL-GROUP,
	;; modify all views using the same scaling and rotation.  Not
	;; sure I like this.  We need a more general way of applying
	;; "tandem" operations, but doing so only when it makes sense
	;; to the user.
	(let ((m (multiply-matrices (make-and-fill-4x4-matrix dscale 0.0 0.0 0.0
							      0.0 dscale 0.0 0.0
							      0.0 0.0 1.0 0.0
							      0.0 0.0 0.0 1.0)
				    (math::make-4x4-rotation-matrix :z-deg dtheta))))
	  (pre-multiply-transform-matrix
	   ;; alternatively ROTATE-RELATIVE-TO-WORLD-BY, where world means window
	   2d-to-window-transform
	   m :center-of-rotation-vector pin-position)
	  (let ((group (get-spatial-views view)))
	    (when group
	      (loop for v in group
		    unless (eq view v)
		      do (pre-multiply-transform-matrix
			  (2d-to-window-transform v)
			     m :center-of-rotation-vector pin-position)
			 (redisplay v))))
	  )))))

(defmethod scale-rot-at-mouse (object interactor)
  (declare (ignore object))
  (scale-rot-relative-to interactor (drag-start-window-pos interactor)))

(defmethod scale-rot-at-center (object interactor)
  (declare (ignore object))
  (with-class-slot-values interactor (current-window) interactor
    (multiple-value-bind (width height)
	(dimensions current-window)
      (scale-rot-relative-to interactor (cv (* .5 width) (* .5 height) 0.0)))))


(defmethod scale-image-relative-to-center ((interactor interactor) dscale)
					;(format t "scale-image-relative-to-center~%")
  (with-class-slot-values interactor (current-window) interactor
    (when (current-view interactor)
      (multiple-value-bind (width height) (dimensions current-window)
	(let* ((view (current-view interactor))	;(win current-window)
	       (2d-to-window-transform (2d-to-window-transform view)))
	  (pre-multiply-transform-matrix 2d-to-window-transform
					 (make-and-fill-4x4-matrix dscale 0.0 0.0 0.0
								   0.0 dscale 0.0 0.0
								   0.0 0.0 1.0 0.0
								   0.0 0.0 0.0 1.0)
					 :center-of-rotation-vector 
					 (cv (* .5 width) (* .5 height) 0.0))

	  (redisplay (current-view interactor)))))))

(defmethod scale-relative-to ((interactor interactor) pin-position)
  ;;(format t "scale-rot-relative-to ~%")
  (with-class-slot-values interactor (window-motion) interactor
    (when (current-view interactor)
      (bind-vector-elements (dx dy) window-motion
	(let* ((view (current-view interactor))	;(win current-window)
	       ;; allow factor of 16 scale change for half screen height motion
	       (dscale (expt (the double-float *scale-change-per-screen-motion*)
			     (/ (max-dx-dy dx dy) 1024.0)))
	       (2d-to-window-transform (2d-to-window-transform view))
	       )
	  (pre-multiply-transform-matrix
	   ;; alternatively ROTATE-RELATIVE-TO-WORLD-BY, where world means window
	   2d-to-window-transform
	   (make-and-fill-4x4-matrix dscale 0.0 0.0 0.0
				     0.0 dscale 0.0 0.0
				     0.0 0.0 1.0 0.0
				     0.0 0.0 0.0 1.0)
	   :center-of-rotation-vector pin-position))))))

(defmethod scale-at-mouse (object interactor)
  (declare (ignore object))
  (scale-relative-to interactor (drag-start-window-pos interactor)))

;;; I appear to get double mouse-wheel events -- change this to a 2.0^(1/(2*n))
(defparameter *scroll-button-zoom-factor* (expt 2.0 (/ 1.0 3.0)))
;;(defparameter *scroll-button-zoom-factor* (expt 2.0 (/ 1.0 4.0)))

;;; It would be nice to get the image-to-window scale-factor in exact sync with
;;; a power of 2, so that no interpolation blurring occurs at every 3rd
;;; rotation of the scroll wheel.  On the other hand, if we within (sqrt
;;; *scroll-button-zoom-factor*) = 1.12 of an exact power of 2, it probably will
;;; not matter very much.  There will be very little blurring as a result.

(defmethod scroll-zoom-out (interactor)
  (when (and (eq (drag-op interactor) 'drag-uv))
    (scale-image-relative-to-center interactor (/ *scroll-button-zoom-factor*))))

(defmethod scroll-zoom-in (interactor)
  (when (and (eq (drag-op interactor) 'drag-uv))
    (scale-image-relative-to-center interactor *scroll-button-zoom-factor*)))


(defmethod cycle-stack ((window basic-window))
  (let* ((view-stack (view-stack window))
	 (first (pop view-stack)))
    (setf (view-stack window) (append view-stack (list first)))
    ))

(defmethod cycle-stack ((interactor interactor))
  (cycle-stack (current-window interactor)))

(defmethod clear-view-stack ((window basic-window))
  (setf (view-stack window) nil))

(defmethod zoom-to-fit ((interactor interactor))
  (let ((view (current-view interactor)))
    (when view
      (setf (2d-to-window-transform view)
	    (default-2d-to-window-transform view (view-image view)))
      (window-damaged interactor (view-window view)))))

(defmethod zoom-to-fit ((view view))
  (setf (2d-to-window-transform view)
	(default-2d-to-window-transform view (view-image view)))
  (window-damaged *interactor* (view-window view)))

(defmethod zoom-1-to-1 ((interactor interactor))
  (with-class-slot-values interactor (current-window current-window-pos) interactor
    (let ((current-view (current-view interactor)))
      (when current-view
	(let ((2dpos (inverse-transform-vector (2d-to-window-transform current-view) current-window-pos)))
	  (setf (2d-to-window-transform current-view)
		(parity-2d-to-window-transform current-window (view-image current-view)))
	  (multiple-value-bind (wid hi) (dimensions current-window)
	    (let* ((2d-to-window-transform (2d-to-window-transform current-view))
		   (mat (transform-matrix 2d-to-window-transform)))
	      (bind-vector-elements (x y) (transform-vector 2d-to-window-transform 2dpos)
		(decf (aref mat 0 3) (- x (* .5 wid)))
		(decf (aref mat 1 3) (- y (* .5 hi)))
		(transforms::update-transform 2d-to-window-transform)
		(set-mouse-cursorpos current-window (* .5 wid) (* .5 hi))
		(current-window-damaged interactor)
		))))))))


(defparameter *zoom-to-fit-object-minimum-scale* 2.0)

(defmethod fit-object-2d-to-window-matrix (win bbox mat)
  (mv-bind (width height) (dimensions win)
    (unless width
      (mv-setq (width height) (set-window-dimensions win)))
    (let* ((margin 0.9)
	   (xdim (- (aref bbox 1) (aref bbox 0)))  ;; Object width
	   (ydim (- (aref bbox 3) (aref bbox 2)))  ;; Object height
	   (x-mid (* 0.5 (+ (aref bbox 1) (aref bbox 0))))
	   (y-mid (* 0.5 (+ (aref bbox 3) (aref bbox 2))))
	   (xscale (/ width xdim))
	   (yscale (/ height ydim))
	   (scale (* margin (min xscale yscale)))
	   (obj-dx (* xdim 0.5))
	   (obj-dy (* ydim 0.5)))

      (setf scale (* margin scale))   ;; scale brings object coords into window coords.

      
      ;; xoff and yoff bring us to the object.  These are in
      ;; window coordinates, so they must be scaled.  Also, add
      ;; in half the object size to map the window center to the
      ;; object center:
      (let ((xoff  (+ (* -1.0 scale x-mid) (* 2.5 (- 1.0 margin) width))) 
	    (yoff  (+ (* 1.0 scale y-mid) (* 2.5 (- 1.0 margin) height)))
	    )
	(setf (aref mat 0 0) scale)
	(setf (aref mat 0 3) xoff)
	(setf (aref mat 1 1) (- scale))
	(setf (aref mat 1 3) yoff))
      mat)))


(defun zoom-to-fit-object (obj view)
  (let ((bbox (object-bounding-box-in-2d-world obj (2d-world view))))
    (when bbox
      (fit-object-2d-to-window-matrix
       (view-window view)
       bbox
       (transform-matrix (2d-to-window-transform view))
       ))))




(defmethod com-zoom-to-fit-object ((interactor interactor))
  (let ((view (current-view interactor))
	(obj (selected-object interactor)))
    (zoom-to-fit-object obj view)
    (window-damaged interactor (view-window view))))





#|
Attempt to make cleaner interface for command dispatch.


Mouse Button Dispatch:

Here are the things we need to discriminate:

   1. user interface context
        determined from global state, window state, view state ...
 
   2. object
        . window identity or window class  (eq win <winid>) or (typep win <class>)
        . image
        . object (spatial object)

   3. modifiers: control meta shift.
      No support for super or hyper.

   4. event
      . button-press 1 2 or 3
      . button-release 
      . Do we need button-click distinct from button-press?

 
For popup menus we have specs like:

    (context object menu-item-string command doc-string)

For bucky menus we have specs like:

    (context object (modifiers button) command prompt-string)



|#




(defun window-damaged (interactor window)
  ;; (format t "window-damaged ~a~%" window)
  (view-changed window)
  ;; should redisplay-damaged-views be called now, or the next time around the
  ;; event loop?
  (redisplay-damaged-views interactor))

(defun current-window-damaged (interactor)
  (window-damaged interactor (current-window interactor)))


;;; want M such that inv(M)*Pw = inv(M2d->w)*Pw, ie. Pw is stationary w.r.t. composition

(defun modify-2d-to-window-transform (2d-to-window-transform matrix window-pt)
  (let ((2d-pt (inverse-transform-vector 2d-to-window-transform window-pt)))
    (transforms::post-multiply 2d-to-window-transform matrix nil)
    (let* ((mat (transform-matrix 2d-to-window-transform))
	   (window-pt2 (transform-vector 2d-to-window-transform 2d-pt)))
      (bind-vector-elements (x0 y0) window-pt
	(bind-vector-elements (x1 y1) window-pt2
	  (incf (aref mat 0 3) (- x0 x1))
	  (incf (aref mat 1 3) (- y0 y1))))
      (transforms::update-transform 2d-to-window-transform))))


;;; This should probably move to a different file 
	
(defvar *zoom-in-matrix* (make-and-fill-4x4-matrix 2.0 0.0 0.0 1.0
						   0.0 2.0 0.0 1.0
						   0.0 0.0 1.0 0.0
						   0.0 0.0 0.0 1.0))

(defvar *zoom-out-matrix* (make-and-fill-4x4-matrix .5 0.0 0.0 -.5
						   0.0 .5 0.0 -.5
						   0.0 0.0 1.0 0.0
						   0.0 0.0 0.0 1.0))

(defvar *rot-cw-90-matrix*
  (make-and-fill-4x4-matrix 0.0 -1.0 0.0 0.0
			    1.0 0.0 0.0 0.0
			    0.0 0.0 1.0 0.0
			    0.0 0.0 0.0 1.0))


(defvar *rot-cw-180-matrix*
  (make-and-fill-4x4-matrix -1.0 0.0 0.0 0.0
			    0.0 -1.0 0.0 0.0
			    0.0 0.0 1.0 0.0
			    0.0 0.0 0.0 1.0))

(defvar *rot-cw-270-matrix*
  (make-and-fill-4x4-matrix 0.0 1.0 0.0 0.0
			    -1.0 0.0 0.0 0.0
			    0.0 0.0 1.0 0.0
			    0.0 0.0 0.0 1.0))

;;; These next 4 transforms are left-handed.

(defvar *flip-x-matrix*
  (make-and-fill-4x4-matrix -1.0 0.0 0.0 0.0
			    0.0 1.0 0.0 0.0
			    0.0 0.0 1.0 0.0
			    0.0 0.0 0.0 1.0))

(defvar *flip-y-matrix*
  (make-and-fill-4x4-matrix 1.0 0.0 0.0 0.0
			    0.0 -1.0 0.0 0.0
			    0.0 0.0 1.0 0.0
			    0.0 0.0 0.0 1.0))

(defvar *transpose_matrix*
  (make-and-fill-4x4-matrix 0.0 1.0 0.0 0.0
			    1.0 0.0 0.0 0.0
			    0.0 0.0 1.0 0.0
			    0.0 0.0 0.0 1.0))

(defvar *neg-transpose-matrix*
  (make-and-fill-4x4-matrix 0.0 -1.0 0.0 0.0
			    -1.0 0.0 0.0 0.0
			    0.0 0.0 1.0 0.0
			    0.0 0.0 0.0 1.0))

(defvar *identity-matrix* (make-4x4-identity-matrix ))

(defgeneric com-zoom-in (object)
  (:documentation "Zoom In"))

(defmethod com-zoom-in ((interactor interactor))
  (with-class-slots interactor (current-window current-window-pos) interactor
    (let ((current-view (current-view interactor)))
      (when current-view
	(modify-2d-to-window-transform
	 (2d-to-window-transform current-view) *zoom-in-matrix* current-window-pos)
	(current-window-damaged interactor)))))


(defmethod com-zoom-out ((interactor interactor))
  (with-class-slots interactor (current-window current-window-pos) interactor
    (let ((current-view (current-view interactor)))
      (when current-view
	(modify-2d-to-window-transform
	 (2d-to-window-transform current-view) *zoom-out-matrix* current-window-pos)
	(current-window-damaged interactor)))))


(defmethod com-recenter ((interactor interactor))
  (with-class-slots interactor (current-window current-window-pos) interactor
    (let ((current-view (current-view interactor)))
      (when current-view
	(multiple-value-bind (wid hi) (dimensions current-window)
	  (bind-vector-elements (x y) current-window-pos
	    (let* ((2d-to-window-transform (2d-to-window-transform current-view))
		   (mat (transform-matrix 2d-to-window-transform)))
	      (decf (aref mat 0 3) (- x (* .5 wid)))
	      (decf (aref mat 1 3) (- y (* .5 hi)))
	      (transforms::update-transform 2d-to-window-transform)
	      (set-mouse-cursorpos current-window (* .5 wid) (* .5 hi))
	      (current-window-damaged interactor)
	      )))))))


(defmethod com-copy-view ((interactor interactor))
  (with-class-slots interactor (selected-window current-window current-window-pos) interactor
    (let ((new-view (copy-view (top-view selected-window))))
      (push-view new-view current-window)
      (current-window-damaged interactor)
      )))


(defmethod com-move-view ((interactor interactor))
  (with-class-slots interactor (selected-window current-window) interactor
    (let ((view (pop-view selected-window)))
      (push-view view current-window)
      (current-window-damaged interactor)
      )))

(defmethod com-pop-view ((interactor interactor))
  (with-class-slots interactor (current-window) interactor
    (pop-view current-window)
    (current-window-damaged interactor)
    ))

(defmethod com-cycle-stack ((interactor interactor))
  (with-class-slots interactor ( current-window) interactor
    (cycle-stack current-window)
    (current-window-damaged interactor)
    ))

(defmethod com-pop-view ((interactor interactor))
  (with-class-slots interactor ( current-window) interactor
    (pop-view current-window)
    (current-window-damaged interactor)))

;;; This is invoked from <Right> mouse event
(defmethod com-popup-menu ((interactor interactor))
  ;; CME6 action: (object-menu-click (get-user-interface-context mouse-window) object mouse-window x y))
  (basic-elt-popup-ui-popup-menu interactor))
 

#|
(describe (top-view (selected-window *interactor*)))
(describe (2d-to-window-transform (top-view (selected-window *interactor*))))
(describe (copy-view (top-view (selected-window *interactor*))))
(type-of (top-view (selected-window *interactor*)))

(setq img (view-image (top-view)))

(push-image img (view-window (top-view)))
|#



;;; Object Commands



;;; When adding vertices, make sure that the most recent vertex is selected, a la CME.
(defmethod com-add-vertex ((interactor interactor))
  ;(format t "com-add-vertex~%")
  (let ((object (caar (selected-objects interactor)))
	(fragment (cadar (selected-objects interactor) )))
    (when (and object fragment)
#||
      (setf (selected-objects interactor)
	    (list (list object
			(make-instance 'object-vertex
				       :object object
				       :vertex-id (obj::add-vertex object fragment))))
	    ))))
||#
      ;;(setf (selected-objects interactor) nil)
      (typecase fragment
	(obj::object-arc 
	 (let ((new-vertex-id (obj::add-vertex object fragment)))
	   (setf (selected-objects interactor)
		 (list (list object (make-instance 'object-vertex :object object
						   :vertex-id new-vertex-id))))))
	(obj::object-vertex 
	 (setf (obj::vertex-id fragment) (obj::add-vertex object fragment))))
      (start-popup-object-drag 'move-object-vertex-uv)
      )))


(defmethod com-delete-vertex ((interactor interactor))
  (let ((object (caar (selected-objects interactor)))
	(fragment (cadar (selected-objects interactor) )))
    (when (and object fragment)
      (obj::delete-vertex object fragment)
      (setf (selected-objects interactor) nil)))) 





#| unfinished

(defmethod com-x-slice ((interactor interactor)) 
  "Graph a horizontal slice of the image at the mouse selected point."
  (mv-bind (source-pane window-pos)
      (pick-a-point "Pick a Horizontal Line To Graph")
    (let ((graph-pane (next-pane interactor))
	  (fix-image-y (floor source-image-y))
	  end-index)
					;(send graph-pane :clear-window-and-label)
      (draw-line source-pane
		 0 fix-image-y
		 (1- (image-x-dim source-image)) fix-image-y
		 :alu *xor-green-alu*)
      (multiple-value-bind (x-left ig1 x-right)
	  (get-corners source-pane)
	(ignore ig1)
	(psetq x-left (fix (max 0 (min x-left x-right)))
	       x-right (fix (max x-left x-right)))
	(setq end-index (- (min (image-x-dim source-image)
				x-right)
			   x-left))
      
	(with-scan-line-buffers ((bufr (make-dfloat-scan-line-buffer source-image end-index)))
	  (image-getline source-image bufr x-left fix-image-y end-index)
	  (push-object
	   (eval-cache (x-slice source-image fix-image-y x-left end-index)
	       (array-graph-object
		bufr
		:x-label "x"
		:y-label (if (> (inside-width graph-pane) 300)
			     (format nil "intensity of row ~a" fix-image-y)
			     (format nil "row ~a" fix-image-y))
		:clear-window t
		:invalid-value (and (image-floatp source-image) 0)
		:x-axis-xform
		(function (lambda(x) (values (+ x x-left)
					     (- x x-left)))) ; lexical closure
		:graph-style (if (image-floatp source-image) :invalids-removed nil)
		:print-stats t
		:alu-name :black-alu	;:alu *black-alu*
		))
	   graph-pane))))))

|#


(defmethod cycle-display-mode ((interactor interactor))
  (let ((view (current-view interactor)))
    (setf *gl-shading-enabled* t)
    (setf (shading-enabled (display-attributes view))
	  (not (shading-enabled (display-attributes view))))))

(defmethod com-site-view-tool ((interactor interactor))
  (view-rotation-cvv-panel (current-view interactor)))


(defmethod com-move-w-to-ground ((interactor interactor))
  (move-object-w-to-dtm (selected-object interactor) interactor))


(defmethod com-move-every-w-to-ground ((interactor interactor))
  (move-object-verts-w-to-dtm (selected-object interactor) interactor))

(defmethod make-extrusion ((object 3d-closed-curve) &rest initargs &key top-z z-size object-set)
  (let* ((verts (obj::vertex-array object))
	 (extrusion (apply 'make-instance
			   'extruded-object
			   :top-vertices (loop for k from 0 below (array-dimension verts 0)
					       collect (bind-vector-elements (x y z) (obj::vertex-array-vertex verts k)
							 (cv x y (or top-z z))))
			   :z-size z-size
			   initargs )))
    (setf (object-to-parent-transform extrusion)
	  (object-to-parent-transform object))
    (setf (parent extrusion) (parent object))
    (when object-set (gui::add-object extrusion object-set))
    extrusion))


;;;
;;; 

(defmethod tk::tk-callback (panel widget item-name (event (eql 'tk::menu-release-timeout)) args)
  ;(format t "~%Mouse release callback!") 
  (force-output)
  (when tk::*waiting-for-menu-choice*
    ;(format t "~%Setting tk::*waiting-for-menu-choice* to ~a" (setq tk::*waiting-for-menu-choice* nil))
    (tk::tk-lower tk::*menu*)
    (throw 'tk::menu-abort
      (setq tk::*menu-choice* NIL ; (list :popdown tk::*menu*)
	    tk::*menu-choice-type* :no-selection))
    ))




(defun rectangle-to-image-coords (rectangle image)
  (let* ((2d-world (world rectangle))
	(verts (obj::vertex-array rectangle))
	(o2w (object-to-world-transform rectangle))
	(i22d (image-to-2d-transform image)))
    (loop for i from 0 below (array-dimension verts 0)
	  for v = (inverse-transform-vector
			  i22d (transform-vector
					 o2w (obj::vertex-array-vertex verts i)))
	  for x = (aref v 0)
	  for y = (aref v 1)
	  minimize x into xmin
	  maximize x into xmax
	  minimize y into ymin
	  maximize y into ymax
	  finally (return (values (round xmin) (round ymin) (round (- xmax xmin)) (round (- ymax ymin)))))))


(defmethod window-image-with-rectangle ((rectangle obj::2d-rectangle) (image img::image))
  (multiple-value-bind (x0 y0 xdim ydim)
      (rectangle-to-image-coords rectangle image)
    (img::image-window image x0 y0 xdim ydim)))


(defmethod window-image-with-rectangle ((rectangle obj::2d-rectangle) (image img::color-image))
  (multiple-value-bind (x0 y0 xdim ydim)
      (rectangle-to-image-coords rectangle image)
    (let ((red (img::image-window (img::red-image image) x0 y0 xdim ydim))
	  (green (img::image-window (img::green-image image) x0 y0 xdim ydim))
	  (blue (img::image-window (img::blue-image image) x0 y0 xdim ydim)))
      (make-image (list xdim ydim)
		  :element-type (image-element-type image)
		  :band-interleaved-image (img::image-window (img::band-interleaved-image image) x0 y0 xdim ydim)
		  :image-type 'img::color-image
		  :component-names (img::component-names image)
		  :component-images (list red green blue)
		  ))))

;;; Wed Mar 29 2006 LHQ  - I have disabled these because WITH-SELECTED-RESULT-PANE is not defined.

(defmethod com-binary-image-op (op (interactor interactor))
  (let ((image-a (view-image (current-view interactor)))
	(image-b (pick-an-image "Pick an image to subtract.")))
    (with-selected-result-pane ("Pick a pane for the result")
      (funcall op image-a image-b))))

(defmethod com-unary-image-op (op (interactor interactor))
  (with-selected-result-pane ()
    (funcall op (view-image (current-view interactor)))))



;;; Thu Jan 21 2010 - use GL to allow window grabs - this is a pretty
;;; useful feature for grabbing window contents...

(defun make-gl-buffer-image (window  &optional (element-type 'img::rgba8) (pad 1))
  (let ((w (* pad (floor (window-width window) pad)))
        (h (window-height window)))
    (make-image (list w h)
                :element-type element-type
                :block-x-dim w
                :block-y-dim h
                )))
  


#+old
(defun grab-gl-buffer (&key (window (selected-pane)) into-image (element-type 'IMG::RGBA8) (buffer GL_BACK) (pad 1))
  (gl::with-gl-window (window)
    ;; (glMakeCurrent window)
    ;; This code seems to have a problem - there is a often mismatch
    ;; between the grabbed frame and the image.  May need to make an
    ;; image whose raster size is a multiple of 4.
    (let* ((w (* pad (floor (window-width window) pad)))
	   (h (window-height window))
	   (image (or into-image
		      (make-image (list w h)
				  :element-type element-type
				  :block-x-dim w
				  :block-y-dim h
				  ))))
      (glReadBuffer buffer)
      (glReadPixels 0 0 w h
		    (case element-type
		      (img::rgb8 GL_RGB)
		      (img::rgba8 GL_RGBA)
		      (t GL_LUMINANCE))
		    GL_UNSIGNED_BYTE
		    (img::image-array image))
      image)))


(defun grab-gl-buffer (&key (window (selected-pane)) into-image (element-type 'IMG::RGBA8) (buffer GL_BACK) (pad 1))
  (gl::with-gl-window (window)
    (let ((w (* pad (floor (window-width window) pad)))
          (h (window-height window))
          (image (or into-image (make-gl-buffer-image window element-type pad))))
      (glReadBuffer buffer)
      (glReadPixels 0 0 w h
		    (case element-type
		      (img::rgb8 GL_RGB)
		      (img::rgba8 GL_RGBA)
		      (t GL_LUMINANCE))
		    GL_UNSIGNED_BYTE
		    (img::image-array image))
      image)))




(defmethod com-grab-window ((interactor interactor))
  (with-selected-result-pane ()
    (with-class-slots interactor (current-window) interactor
      (grab-gl-buffer :window current-window))))


(defmethod com-toggle-tandem-view ((interactor interactor))
  (let* ((view (current-view interactor))
	 (group (view-spatial-group view)))
    (if group
	(remove-view view group)
	(let ((group (find-view-group (view-window view))))
	  (if group
	      (add-view view group)
	      (group-views-spatially (list view)))))))


;;;
;;; I'm sure this had different semantics, but now, this operation
;;; simply selects the immediate parent IFF it is a COMPOSITE-OBJECT.
;;;

(defmethod com-close-self ((interactor interactor))
  (let ((obj (selected-object interactor)))
    (when (typep (parent obj) 'COMPOSITE-OBJECT)
      (select-object (parent obj) interactor))))
