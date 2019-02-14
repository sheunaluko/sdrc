;; Wed Feb 13 15:55:22 PST 2019
;; @Copyright Sheun Aluko 
;; alukosheun@gmail.com 

(import [gen :as g]) 
(import [util :as u]) 
(import [genp :as gp])
(import [pandas :as p])


;; this file will focus on retrieving data in large batches 
  
;; will be written 
(setv cached-data {}) 
(setv keyword-ids {}) 
(setv author-articles {}) 
(setv grant-ids None)

;; run before main 
(defn init [] 
  (print "Initializing...")
  (global grant_ids)
  (setv grant-ids
        (set (u.amap (fn [i] (get i "Id")) (g.search-summary "DK116074 [grant_number]"))))
  (g.prepare-for-cache))

;; we get ALL author papers AND .. 
;; for each keyword we get all the data 
(defn get-data []
  (global cached-data) 
  (global keyword-ids) 
  (setv cached-data {} ) 
  ;; get all data  
  (print (+ "Date range: " (g.sdrc-date-range)))
  (print "Retrieving all author papers...")
  (setv all-articles (g.search-summary (g.author-list-search g.sdrc-authors "date")))
  (setv all-ids     (set (u.amap (fn [i] (get i "Id")) all-articles)))
  (assoc cached-data "all" all-articles) 
  (assoc keyword-ids "all" all-ids) 

  ;; get keyword data 
  (for [k g.keywords]
    (print (+  "Retriving data for keyword: " k))
    (setv tmp (g.search-summary (g.author-list-keyword-search g.sdrc-authors k)))
    (setv tmp-ids (set (u.amap (fn [i] (get i "Id")) tmp)))
    (assoc cached-data k tmp)
    (assoc keyword-ids  k tmp-ids))

  (print "Finished getting data"))
  

;; helper function 
(defn is-article-keyword [article k] 
  (in (get article "Id" )
      (get keyword-ids k)))
           

(defn get-keyword-info [article]
  (setv ret {} ) 
  (setv any_true False) 
  (for [k g.keywords]
    (setv tmp (is-article-keyword article k))
    (if  tmp (setv any_true True)) ;;keeps track if any are true 
    (assoc ret k  tmp))
  (assoc ret "any" any_true)
  ;; and the grant value too 
  (assoc ret "grant" (in (get article "Id") grant-ids))
  ret)

(defn sort-author-articles [] 
  (print "Sorting by author...")
  (global author-articles) 
  ;; first we will initialize empty arrays 
  (for [c g.sdrc-collaborators]
    (assoc author-articles c []))
  ;; now will loop through all articles 
  (for [a (get cached-data "all")]
    ;; get keyword-info 
    (setv keyword-info (get-keyword-info a))
    ;; get the collaborators 
    (setv collaborators (g.find-collaborators-2 a))
    
    ;; now we will update the corresponding collaborator fields with this article 
             
    (when collaborators
      (for [c collaborators] 
        (u.update-in author-articles [c] (fn [arr]
                                           (.append arr {"article" a "keyword-info" keyword-info 
                                                         "collaborators" collaborators})
                                           arr)))))
  ;; Now we will sort by article title 
  (for [k author-articles]
    (.sort (get author-articles k) :key (fn [a] 
                                          (u.get-in a ["article" "Title"]))))
  (print "Done"))


(defn convert-authors-articles-to-rows [author]
  ;; expects list of {"article" _ "keyword-info"}
  ;; the desired columns are :: 
  ;; Author, Article Title, Pub Date, [Keywords], Any_Keywords, Collaborators, AuthorList, Id
  ;; DK116074
  (global author-articles) 
  (setv authors-articles (get author-articles author))
  (setv all-rows [])
  (for [tmp authors-articles]
    (setv ret [] )
    (setv article  (get tmp "article"))
    (setv ki (get tmp "keyword-info"))
    (setv collaborators (get tmp "collaborators"))
    (.append ret author)
    (.append ret (str (get article "Title")))
    (.append ret (str ( get article "PubDate")))
    (for [k g.keywords]
      (.append ret (if (get ki k) "Yes" "No")))
    (.append ret (if (get ki "any") "Yes" "No"))
    ;;remove this author from collaborators 
    (setv collab (lfor c collaborators :if (!= c author) c))
    (.append ret (.join "," collab))
    ;;Author List
    (.append ret (.join "," (get article "AuthorList")))
    (.append ret (str (get article "Id")))
    (.append ret  (if (get ki "grant") "Yes" "No"))
    
    ;;now append tert to all-rows 
    (.append all-rows ret))
  ;;return all-rows 
  all-rows )



(defn get-author-data-frame [] 
  (print "Making authors data frame...") 
  (global author-articles) 
  (setv sorted-keys (u.sorted-keys author-articles))
  (setv tmp []) 
  (for [k sorted-keys]
    (.append tmp (convert-authors-articles-to-rows k)))
  (setv data (+ #* tmp))
  (setv cols (+ #* [["Author" "ArticleTitle" "PubDate"] 
                    (lfor k g.keywords k)
                    ["Any_Keyword?" "Collaborators" "AuthorList"  "PubMedId" "DK116074"]]))
  (setv data-frame (gp.get_data_frame  data cols))
  (print "Done.")
  data-frame)


(defn get-unique-data-frame [] 
  (print "Making unique articles data frame...") 
  (setv cols (+ #* [["ArticleTitle" "PubDate"] 
                    (lfor k g.keywords k)
                    ["AnyKeyword?" "Collaborators" "AuthorList"  "PubMedId" "DK116074"]]))
  ;; get all articles
  (setv all-articles (get cached-data "all"))
  ;; sort them 
  (.sort all-articles :key (fn [a] (get a "Title")))
  ;;build 2d array
  (setv data [])
  (for [article all-articles]
    (setv ret [] )    
    (setv ki (get-keyword-info article))
    (setv collaborators (g.find-collaborators-2 article))
    (if (not collaborators) 
      (do 
        (print "\nwarning:: -- please check ~> ")
        (print (+ "No collaborators found for: ID=" (get article "Id") ", Title=" (get article "Title")))
        (print (+ "Authors: "  (.join "," (get article "AuthorList"))))
        (print "The above article matched the original query but will be excluded because no sdrc authors could be found.\n")
        (continue)))
    
    (.append ret (str (get article "Title")))
    (.append ret (str (get article "PubDate")))
    (for [k g.keywords]
      (.append ret (if (get ki k) "Yes" "No")))
    (.append ret (if (get ki "any") "Yes" "No"))
    (.append ret (.join "," collaborators))
    ;;Author List
    (.append ret (.join "," (get article "AuthorList")))
    (.append ret (str (get article "Id")))
    (.append ret  (if (get ki "grant") "Yes" "No"))
    
    ;;now append to data 
    (.append data ret))
  (setv data-frame (gp.get_data_frame data cols))
  (print "Done.")
  data-frame)

;; Now for excel writing 
(defn write-all []
  (print "Restructuring data...")
  (setv writer (p.ExcelWriter (u.ensure-ext g.output_file "xlsx")))
  (setv author-df (get-author-data-frame))
  (setv unique-df (get-unique-data-frame))
  (print "[Note]:: You can look into the 'search_queries' file to see what queries are being made to the PubMed server.\n")
  (print "Starting excel write operation: ")
  (print "Writing authors sheet...")
  (setv date-range (.replace (.replace (g.sdrc-date-range) "/" "-") 
                             ":" "_"))
  (.to_excel author-df writer (+ "auth_" date-range) :index False)
  (print "Writing uniqe articles sheet...")
  (.to_excel unique-df  writer (+ "unq_" date-range) :index False)
  (print "Saving excel")
  (.save writer)
  (print "Done <3"))
  
(defn main [] 
  (init) 
  (get-data)
  (sort-author-articles)
  (write-all))

