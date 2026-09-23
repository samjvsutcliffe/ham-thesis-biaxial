(in-package :cl-mpm/examples/damage/biaxial)
(defparameter *refine* (parse-float:parse-float (if (uiop:getenv "REFINE") (uiop:getenv "REFINE") "1")))
(let ((threads (parse-integer (if (uiop:getenv "OMP_NUM_THREADS") (uiop:getenv "OMP_NUM_THREADS") "16"))))
  ;(setf lparallel:*kernel* (lparallel:make-kernel threads :name "custom-kernel"))
  (cl-mpm/utils:set-workers threads)
  (format t "Thread count ~D~%" threads))
(defmethod cl-mpm/damage::damage-model-calculate-y ((mp cl-mpm/particle::particle-fpd-isotropic) dt)
  (with-accessors ((strain cl-mpm/particle::mp-strain)
                   (undamaged-stress cl-mpm/particle::mp-undamaged-stress)
                   (E cl-mpm/particle::mp-e)
                   (de cl-mpm/particle::mp-elastic-matrix)
                   (y cl-mpm/particle::mp-damage-y-local)
                   (angle cl-mpm/particle::mp-friction-angle)
                   (model cl-mpm/particle::mp-friction-model)
                   (pd-inc cl-mpm/particle::mp-plastic-damage-evolution)
                   (ps-vm cl-mpm/particle::mp-strain-plastic-vm))
      mp
    (let ((stress undamaged-stress)
          (ps-y (sqrt (* E (expt ps-vm 2)))))
      (setf
       y
       (+
        (if pd-inc ps-y 0d0)
        (ecase model
          (:SE (cl-mpm/damage::tensile-energy-norm strain e de))
          (:RANKINE (cl-mpm/damage::criterion-rankine stress))
          (:RANKINE-SMOOTH (cl-mpm/damage::criterion-rankine-smooth stress))
          (:PRINC-STRAIN (cl-mpm/damage::criterion-max-principal-strain strain e))
          (:PRINC-STRESS (cl-mpm/damage::criterion-max-principal-stress stress))
          (:DP (cl-mpm/damage::drucker-prager-criterion stress angle))
          (:MC (cl-mpm/damage::criterion-mohr-coloumb-stress-tensile stress angle))
          (:MCR (cl-mpm/damage::criterion-mohr-coloumb-rankine-stress-tensile stress angle))
          ))))))

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
      :damping (sqrt 2d0)
      :min-adaptive-steps 0
      :max-adaptive-steps 6
      :adaption-constant 4
      :max-damage-inc 1.10d0
      ;:min-damage-inc 0.1d0
      :substeps (round (* refine 50))
      :sub-conv-steps 500
      :criteria 1d-6
      :stagger-damage :HYBRID
      ;:true-stagger nil
      :save-vtk-dr nil
      :save-vtk-loadstep t
      :dt-scale 0.9d0))))

(defparameter *angle* (let ((var (uiop:getenv "ANGLE"))) (if var (parse-float:parse-float var) 1d0)))
(defparameter *model* (let ((var (uiop:getenv "MODEL"))) (if var var "MC")))
(defparameter *tension* (let ((var (uiop:getenv "TENSION"))) (if var (string= var "TRUE") nil)))
(defparameter *model-hash* (serapeum:dict "MC" :MC "DP" :DP "RANKINE" :RANKINE "SE" :SE))

(defparameter *name* (let ((var (uiop:getenv "NAME"))) (if var var "")))
;(defparameter *model-hash* (serapeum:dict "MC" :MC "DP" :DP "RANKINE" :RANKINE "SE" :SE))

(let ((refine *refine*)
      (angle *angle*)
      (model (gethash *model* *model-hash*)))
  (setup :mps 3
         :refine refine
         :enable-fbar nil
         :kt (- 1d0 1d-6)
         :angle angle
         :angle-r 0d0
         :gf 40d0
         :model model
         :epsilon-scale 1d2
         :local-length 10d-3;(/ 0.01d0 refine)
         )
  (let ((particle 'cl-mpm/particle::particle-fpd-isotropic))
    (cl-mpm::iterate-over-mps
      (cl-mpm:sim-mps *sim*)
      (lambda (mp)
        (change-class mp particle))))
  (setf (cl-mpm/damage::sim-enable-length-localisation *sim*) nil)
  ;(setf (cl-mpm/damage::sim-enable-ekl *sim*) t)
  (let ((output-dir (format nil "/nobackup/rmvn14/thesis/biaxial/data-~A/output-~A-~A-~F-~D/" *name*
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
