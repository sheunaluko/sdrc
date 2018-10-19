;; Sun Jul 15 03:19:34 PDT 2018
;; @Copyright Sheun Aluko 
;; alukosheun@gmail.com 



(defn print-keys [l] 
  (for [k (.keys l)]
    (print (+ "-- Printing keys:\n- " k "\n"))))

(defn print-key [l k] 
  (for [i (if (isinstance l list)
              l
              [l])] 
    (print (+  (get i k) "\n"))))

(defn amap [f c] 
  (list 
    (map f c)))

(defn arest [c]
  (list 
    (rest c))) 

(defn atake [num l]
  (list (take num l )))

(defn adrop [num l] 
  (list (drop num l ))) 


(defn amerge [a b] 
  (setv r {}) 
  (r.update a) 
  (r.update b)
  r) 


(defn read-file [file]
  (with [f (open file)]
    (.read f)))


(defn partition [coll num] 
  (setv result [] ) 
  (setv remaining coll)
  (while remaining 
    (.append result (atake num remaining)) 
    (setv remaining (adrop num remaining)))
  result )
    
  
