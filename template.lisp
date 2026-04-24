(in-package :cl-mpm/examples/damage/biaxial)
(defparameter *refine* (parse-float:parse-float (if (uiop:getenv "REFINE") (uiop:getenv "REFINE") "1")))
(let ((threads (parse-integer (if (uiop:getenv "OMP_NUM_THREADS") (uiop:getenv "OMP_NUM_THREADS") "16"))))
  (setf lparallel:*kernel* (lparallel:make-kernel threads :name "custom-kernel"))
  (format t "Thread count ~D~%" threads))

(defun run (&key (output-dir (format nil "./output/"))
              (refine 1)
              (tensile nil)
              (enable-plastic nil)
              (enable-damage t)
              (csv-dir nil)
              (lstps 5)
              (total-disp -5d-3)
              (csv-filename (format nil "load-disp.csv")))
  (unless csv-dir
    (setf csv-dir output-dir))
  (let* ((current-disp 0d0)
         (step 0))
    (when tensile
      (setf total-disp (abs total-disp)))
    (defparameter *data-disp* (list 0d0))
    (defparameter *data-load* (list 0d0))
    (defparameter *displacement* 0d0)
    (loop for f in (uiop:directory-files (uiop:merge-pathnames* "./outframes/")) do (uiop:delete-file-if-exists f))

    (vgplot:close-all-plots)
    (time
     (cl-mpm/dynamic-relaxation::run-adaptive-load-control
      *sim*
      :output-dir output-dir
      :plotter (lambda (sim))
      :loading-function (lambda (i)
                          (setf current-disp (* i total-disp))
                          (cl-mpm/penalty::bc-set-displacement
                           *penalty*
                           (cl-mpm/utils:vector-from-list (list 0d0 current-disp 0d0))))
      :post-conv-step (lambda (sim)
                        (push current-disp *data-disp*)
                        (let ((load (get-load)))
                          (format t "Load ~E~%" load)
                          (push load *data-load*))
                        ;; (plot-load-disp)
                        (save-csv csv-dir csv-filename *data-disp* *data-load*)
                        ;; (output-disp-data output-dir)
                        (incf step))
      :load-steps lstps
      :enable-plastic enable-plastic
      :enable-damage enable-damage
      :damping (sqrt 1d0)
      :min-adaptive-steps 0
      :max-adaptive-steps 2
      :adaption-constant 4
      :max-damage-inc 1.10d0
      :min-damage-inc 0.1d0
      :substeps (round (* refine 50))
      :sub-conv-steps 50
      :criteria 1d-3
      :true-stagger nil
      :save-vtk-dr nil
      :save-vtk-loadstep t
      :dt-scale 1d0))))

(defparameter *angle* (let ((var (uiop:getenv "ANGLE"))) (if var (parse-float:parse-float var) 1d0)))
(defparameter *model* (let ((var (uiop:getenv "MODEL"))) (if var var "MC")))
(defparameter *tension* (let ((var (uiop:getenv "TENSION"))) (if var (string= var "TRUE") nil)))
(defparameter *model-hash* (serapeum:dict "MC" :MC "DP" :DP "RANKINE" :RANKINE "SE" :SE))

;(defparameter *model-hash* (serapeum:dict "MC" :MC "DP" :DP "RANKINE" :RANKINE "SE" :SE))

(let ((refine *refine*)
      (angle *angle*)
      (model (gethash *model* *model-hash*)))
  (setup :mps 3
         :refine refine
         :enable-fbar t
         :kt (- 1d0 1d-6)
         :angle angle
         :angle-r 0d0
         :gf 40d0
         :model model
         :epsilon-scale 1d2
         ;:local-length (/ 0.01d0 refine)
         )
  (let ((particle 'cl-mpm/particle::particle-fpd-isotropic))
    (cl-mpm::iterate-over-mps
      (cl-mpm:sim-mps *sim*)
      (lambda (mp)
        (change-class mp particle))))
  ;(setf (cl-mpm/damage::sim-enable-length-localisation *sim*) t)
  ;(setf (cl-mpm/damage::sim-enable-ekl *sim*) t)
  (let ((output-dir (format nil "/nobackup/rmvn14/thesis/biaxial/data/output-~A-~A-~F-~D/"
                            (if *tension* "T" "C")
                            model angle refine)))
    (format t "Testing ~A~%" output-dir)
    (time
     (run :output-dir output-dir
          :lstps 50
          :total-disp -5d-3
          :enable-damage t
          :tensile *tension*
          :refine refine))))
