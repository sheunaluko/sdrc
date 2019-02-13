;; Sun Jul 15 03:23:55 PDT 2018
;; @Copyright Sheun Aluko 
;; alukosheun@gmail.com 

(import Bio.Entrez)
(import [time :as t] ) 
(import [genp :as gp])
(import [util :as u ] )
(import [info :as i])
(import [pandas :as p])
(import [numpy :as n])
(import subprocess)

; going to hoist all the parameters to the top here  --- >  
; they get modified by sdrc_main before the program is run 

(setv sdrc-filename "SDRC-memberlist.xlsx") 
(setv sdrc-start-date "2016/09/01" )  ;; "2017/09/01") ;; Form of the date is as such: YYYY/mm/dd 
(setv sdrc-end-date "2018/09/01" )  ;; 2018/09/01") 
(setv sdrc-rows 100 ) 
(setv keywords None) 
(setv sdrc-authors None) 
(setv sdrc-collaborators None) 
(setv sdrc-collaborators-set None) 
(setv sdf None ) 
(setv output_file None) 
(setv rmg-file  "/Users/oluwa/Downloads/grants.xlsx")
(setv rmg-header 0) 


;; -- > end params 

;;; need a function that will initialize some variables that depend on the parameters   ---- > 
;; see prepare fn below after the following UTIL / helper fns 

(defn read-excel [fname]
  (p.read_excel fname :dtype n.str))

(defn convert-author-name-2 [n]
  (-> n 
      (.strip) 
      (.replace "," "")
      (.replace "." "")))

(defn get-sdrc-names [] 
  (u.amap convert-author-name-2
          (u.atake sdrc-rows
                   (-> (read-excel sdrc-filename) (get "Center Member")))))

(defn process-component [c] 
  (-> c 
      (.strip) 
      (.lower)
      (.replace "," "")
      (.replace "." "")))


(defn get-sdrc-collaborators [] 
  (u.amap (fn [a] 
            (setv tokens (.split (.lower a) " ") ) ;; convert to lower case 
            (+ (first tokens)  ;; take last name 
               " " 
               (first (second tokens )))) ;; and the first char of next token 
            sdrc-authors))


;; this fn assumes that the parameter file has been interpreted by sdrc_main.py and 
;; this files vars have been reset appropriately 
(defn prepare-for-cache [] 
  (global sdrc-authors) 
  (global sdrc-collaborators) 
  (global sdrc-collaborators-set) 
  (setv sdrc-authors (u.atake sdrc-rows  (get-sdrc-names)))
  (setv sdrc-collaborators (get-sdrc-collaborators))
  (setv sdrc-collaborators-set (set (get-sdrc-collaborators))))


;; after prepare-for-cache is called, then cache-all is called 
;; next we need sort through the cached data to produce lists of ids 
;; next section of code does that 


(setv special_grant_ids None)
(setv keyword-ids {} )   ;; this will be set when prepare-for-write (below) is called 

(defn is-collaborator-match [ a ] 
  (or #* (lfor s sdrc-collaborators (gp.contains (.lower a) s))))

(defn find-collaborators [article]
  (setv authors-list (get article "AuthorList"))
  (setv result [] ) 
  (for [a authors-list] 
    (when (is-collaborator-match a)
      (.append result a)))
  (if result  
    (.join "," result )
    "None" ))
  
(defn grant? [article ]
  (setv id (get article "Id" ))
  (if (in id special_grant_ids)
    "Yes" 
    "No"))
  

(defn get-ids-for-keyword  [k]
  (setv tmp [] ) 
  (for [a sdrc-authors ] 
    (setv data (load-author-info a))
    (setv info (get data k))
    (when info
      (for [d info] 
        (.append tmp (get d "Id" )) )))
  (set tmp))

(defn load-keyword-ids [] 
  (global keyword-ids) 
  (for [k keywords ]
    (assoc keyword-ids k (get-ids-for-keyword k))))

(defn is-keyword? [key article] 
  (setv id (get article "Id")) 
  (if (in id  (get keyword-ids key))
    "Yes" 
    "No"))


;; this function assumes that cache-all (defined below) has already been called 
;; and that all the author data is stored in the cache folder 
(defn prepare-for-write [] 
  (global special_grant_ids) 
  (setv special_grant_ids (u.amap (fn [i] (get i "Id")) (search-summary "DK116074 [grant_number]")))
  (load-keyword-ids)  )
  

;; ------------------- > 
 

;; in this final section of code we write the tsv file! 

(defn write-pubmed-data-1 [] 
  (setv f output_file) 
  (setv spit (fn [d] 
               (gp.append_file f d)))
  (setv spit-tab (fn [d] (spit (+ d "\t"))))
  (setv spit-line (fn [d] (spit (+ d "\n"))))
  
  ;a write file header 
  (spit "Author\tArticle Title\tPub Date")  
  ; write keywords 
  (for [k keywords]
    (spit (+ "\t" k))) 
  ; rest of header
  (spit "\tkeywords>0 ?\tCollaborators\tAuthorList\tPubMedId\tDK116074\n")
  ;; ok header is done 

  ;; will loop through authors and write their data 
  (for [a sdrc-authors ] 
    (print "Writing for author: " a ) 
    (setv data (load-author-info a)) 
    (setv articles (get data "date"))
    (if articles 
      (for [ article articles ] 
        (spit-tab a) 
        (spit-tab (get article "Title"))
        (spit-tab (get article "PubDate"))
        ;;now for the keywords
        (setv some-keywords "No")
        (for [k keywords] 
          (setv result (is-keyword? k article))
          (if (= "Yes" result)
            (setv some-keywords "Yes") )
          (spit-tab result))
        (spit-tab some-keywords)
        ;;and then the rest of the row 
        (spit-tab (find-collaborators article)) ; collabs 
        (spit-tab (.join "," (get article "AuthorList"))) ; authorList 
        (spit-tab (get article "Id")) ;ID 
        (spit-line (grant? article)) );grant   (note spit-line here to end the row! ) 
      ;;if no articles then write just author name
      (spit (+ a "\t\n")))))
  


(defn write-no-duplicates [] 
  
  (setv f (.replace output_file ".tsv" "_unique.tsv"))
  (setv spit (fn [d] 
               (gp.append_file f d)))
  (setv spit-tab (fn [d] (spit (+ d "\t"))))
  (setv spit-line (fn [d] (spit (+ d "\n"))))
  
  ;a write file header 
  (spit "Article Title\tPub Date\tSDRC Authors")  
  ; write keywords 
  (for [k keywords]
    (spit (+ "\t" k))) 
  ; rest of header
  (spit "\tkeywords>0 ?\tPubMedId\tDK116074\n")
  ;; ok header is done 
    
  (setv used-ids (set)) 
  (setv articles-to-write [])

  ;; will loop through authors 
  (for [a sdrc-authors ] 
    (setv data (load-author-info a)) 
    (setv articles (get data "date") ) 
    (when articles 
      (for [ article articles ] 
        (setv id (get article "Id")) 
        (unless (in id used-ids) 
          (.append articles-to-write article)
          (.add used-ids id)))))
  ;; ok at this point all the articles that should be written should be loaded, with copies 
  ;; omitted. 
  ;; lets sort them based on their title 
  (.sort articles-to-write :key (fn [a] 
                                  (get a "Title")))
  
  
  ;; and then write everything to the file 
  (for [article articles-to-write]
    (setv title (get article "Title"))
    (setv short-title (+ 
                        (.join " " (u.atake 6 (.split title " ")))
                        "..."))
    (print "Writing: " short-title) 
    (spit-tab title)
    (spit-tab (get article "PubDate"))
    (spit-tab (find-collaborators article)) ; collabs 
    ;;now for the keywords
    (setv some-keywords "No")
    (for [k keywords] 
      (setv result (is-keyword? k article))
      (if (= "Yes" result)
        (setv some-keywords "Yes") )
      (spit-tab result))
    (spit-tab some-keywords)
    ;;and then the rest of the row 
    (spit-tab (get article "Id")) ;ID 
    (spit-line (grant? article)) ))



(defn sdrc-date-range [] 
  (+ sdrc-start-date ":" sdrc-end-date)) 



 
(setv Bio.Entrez.email "oluwa@stanford.edu") 
(setv Bio.Entrez.api_key "c4c637fb444e1b9c28b66ff523ad32c83308")
(setv retmax 10000)

(defn search-pubmed [q] 
      (Bio.Entrez.read 
            (Bio.Entrez.esearch :db "pubmed" :retmax retmax :term q)))

(defn get-summary [l]
  (Bio.Entrez.read 
    (Bio.Entrez.esummary :db "pubmed" :id (gp.stringify_list l ))))


(defn search-summary [q] 
  (setv l  (get (search-pubmed q) "IdList")) 
  (if (= 0 (len l )) 
    None    ;; must handle case when Id list is empty 
    (get-summary 
      l )))    
    

    
(defn get-first-author [summary]
  (first (get summary "AuthorList")))

;; write a function to create queries quickly  
;; like this.. 
;; (smart-query  :affiliation [["stanford"]] :author [["chi j"  "fu y"] ["strom e"]])
;; The value for the filter is a vec of vecs, where outer vector contains collections
;; that will use OR and inner vectors will use AND. So above for author translates to 
;; (chi j [au] AND fu y [au]) OR strom e [au] 

;; need to have dictionary to translate affiliation keys to the 
;; two letter version 
;; this is stored in info.hy 


;; TODO Next  = = = = = >   [  ]  
;; -------------------
;; Almost at a significant milestone. 
;; for the below two functions , will use 
;; lfor @ https://github.com/hylang/hy/blob/master/docs/language/api.rst
;; for implementation | Sun Jul 15 03:39:42 PDT 2018

(defn expand-filter [k v] 
;; takes a key and filter value and creates a string 
  (gp.expand_filter k v))

(defn smart-query [&kwargs props] 
  (setv expanded (list 
                   (map (fn [k]
                          ;;get the value 
                          (setv filter-value (get props k))
                          ;;exand it  
                          (expand-filter k filter-value))
                        props)))
  ;;last step is to AND together the list of expanded filters 
  (setv final (gp.stringify_list_sep expanded " AND "))
  ;;return that result  
  final)

;; - -----------------------------






;; need a function to transform the name in the excel sheet into the form for the pubmed query 
(defn truncate-last-name [n] ;; john doe -> john d
  (setv tmp (.split n " "))
  (+ (first tmp) " " (first (last tmp))))

(defn convert-author-name [n] 
  ;; 1. turn to all lower case 
  ;; 2. delete the comma 
  ;; 3. remove all but first letter of last name 
  (-> n 
      (.lower) 
      (.replace "," "")
      (truncate-last-name)))

;; will need to make the above function more robust 
;; to names like "John C. Doe" for example       
;; 1) split using one white space 
;; 2) trim each component 
;; 3) remove commas and periods from each compoenent 
;; 4) add the first component to a whitespace and the first letter of the 
;;    remaining components joined with "" (empty char) 


(defn convert-author-name-3 [n]
  (setv tmp (u.amap process-component 
                    (.split n " ")))
  (+ (first tmp) 
     " " 
     (.join "" (u.amap first 
                     (u.arest tmp)))))

      

;; now i will define the dict objects that will be used for the various searches 
(defn base-query [] 
  {"afilliation" [["stanford"]] ;;double vector , see comments above 
   "publication_date" [[(sdrc-date-range)]]})

(defn searches [] 
  {"date" (base-query)
   "date-diabetes"   (u.amerge (base-query) {"text_word" [["diabetes"]]})
   "date-grant"      (u.amerge (base-query) { "grant_number" [["DK11704"]]})})

(defn keyword-search [k] 
  (u.amerge (base-query) {"text_word" [[k]]}))
                
(defn author-search [author search-type] 
  (setv query (u.amerge (get (searches) search-type) {"author" [[author]]}))
  (setv result (smart-query #** query))
  result)

(defn author-keyword-search [author key] 
  (setv query (u.amerge (keyword-search key)  {"author" [[author]]}))
  (setv result (smart-query #** query))
  result)


;; --- Going to add the ability to try and GET ALL THE AUTHORS at once ! 
(defn author-list-search [author-list search-type]
  (setv alist (lfor a author-list [a] )) 
  (setv query (u.amerge (get (searches) search-type) {"author" alist}))
  (setv result (smart-query #** query))
  result)

(defn author-list-keyword-search [author-list key]
  (setv alist (lfor a author-list [a] )) 
  (setv query (u.amerge (keyword-search key) {"author" alist}))
  (setv result (smart-query #** query))
  result)


;; --- 


;; ok the idea is to be able to cache these searches locally to my machine as 
;; json files.. I think the best way is to have a file for each author
;; the files will be a json dictionary that has fields: date, diabetes, grant  

(setv cache-folder "cache") 

(defn author2fname [author] 
  (-> author 
      (.replace " " "_") 
      (+ ".json")))

(defn get-fname [author]
  (+ (gp.cwd) "/" cache-folder "/"  (author2fname author )))

(defn get-and-save-author-info [author] 
  (print "\nRetrieving data for:  " author ) 
  (setv fname (get-fname author))
  (setv delay 2 ) ;; time in s to be respectful to their api 
  ;; ok so the next thing we need to do is build the json structure by requesting data
  
  (setv date-info (search-summary (author-search author "date")))
  (print " --Date (" (if date-info (len date-info) 0) ")")
  (t.sleep delay) 

  (setv grant-info (search-summary (author-search author "date-grant" ))) 
  (print " --Grant (" (if grant-info (len grant-info) 0) ")")

  
  ;;allocate the keyword struct
  (print "Retrieving keyword searches...") 
  (setv keyword-data {} ) 
  (for [k keywords] 
    ;; do the search for the keyword 
    (setv curr-data (search-summary (author-keyword-search author k)))
    (print " --" k " (" (if curr-data (len curr-data) 0) ")")
    ;;store it into  keyword_data dict
    (assoc keyword-data k curr-data ) 
    ;;delay a bit for extra respect to the api ... 
    (t.sleep delay)) 

  ;; ok so at this point we should have all the required info 
  ;; lets combine it into one data structure then return it for debugging, as well as write 
  ;; it to the cache folder 
  (setv data (u.amerge {"date" date-info "grant"  grant-info } 
                       keyword-data))
  (gp.write_json fname data) 
  data)
  
(defn cache-author-info [author]  
  ;; the first thing we should do, since this is a cache, is to check if the author has 
  ;; already been cached 
  (setv fname (get-fname author))
  (if (gp.check_for_file fname ) 
    ;;file exists.. do nothing  
    (print (+  "File already exists: "  fname ) ) 
    ;;nope.. so then we will actually request all of the information 
    (get-and-save-author-info author ))) 

(defn cache-all [] 
  (for [a sdrc-authors ] 
    (cache-author-info a)))

;; OK at this point we need to be able to load data from the cache 
;; i guess for now if there is a cache miss then we will retrieve the necessary data, why not 
(defn load-author-info [author] 
  (setv fname (get-fname author)) 
  (if (gp.check_for_file fname) 
    (do (print "Retrieving from cache.." ) 
        (gp.read_json fname)) 
    (do (print "Information is not cached.. retrieving.") 
        (get-and-save-author-info author))))
 


(setv sum-file "/Users/oluwa/Downloads/authors_summary" )

(defn summarize-author [a] 
  (setv info (load-author-info a))
  (setv date (get info "date"))
  (setv diabetes (get info "diabetes"))
  (gp.append_file sum-file (+  "\n" a "\n" )) 
  (gp.append_file sum-file  "-- ALL IN PAST YEAR: \n")
  (when date 
    (for [i date] 
      (gp.append_file sum-file (+ (get i "Title") "\n"))))
  (gp.append_file sum-file  "-- DIABETES IN PAST YEAR: \n")
  (when diabetes 
    (for [i diabetes] 
    (gp.append_file sum-file (+ (get i "Title") "\n"))))
  (gp.append_file sum-file "\n"))


(defn summarize-authors [] 
  (for [a sdrc-authors] 
    (print (+ "Writing: "  a "\n"))
    (summarize-author a)))

(defn get-all-article-ids [] 
  (for [a sdrc-authors] 
    None ))

;; want utilities for parsing the news file 
(setv news-file "/Users/oluwa/dev/python/hylang/hylang/entrez/NEWS.txt")

(defn parse-author-news [text-block] 
  ; first step is to split with new lines 
  (setv lines (.split text-block  "\n"))
  (setv author (nth lines 0))
  
  ; now we partition the rest into pairs of [ [title, url] , [t,u] ... ] 
  (setv data (u.partition (u.adrop 1 lines) 2)) 
  [author data] ) 
        
                     

(defn parse-news [] 
  (setv text (u.read-file news-file))
  (setv text-blocks (filter None  (.split text "\n\n\n" )))
  (lfor block text-blocks (parse-author-news block)))

(defn get-link-date [l] 
  (setv file (+ (gp.cwd) "/extract_date_from_link"))
  (.strip (subprocess.check_output [ file  l ] )))


(defn write-news-csv [] 
  (setv news (parse-news)) 
  (setv file "/Users/oluwa/Downloads/news2.csv")
  (gp.append_file file "Author\tTitle\tLink\tDate\n") 
  (for [ [author data] news ] 
    (print "Writing for author: " author )
    (for [ [title link] data ] 
      (setv date (or (get-link-date link) "unknown"))
      (gp.append_file file (+ author "\t" title "\t" link "\t" (string date) "\n")))))





  
;; for the poster --> just run it with the time frame 
;; re-run the code with different years 

;; MATCH BY LAST NAME AND FIRST INITITAL --- SEND BY WEDNESDAY NEXT WEEK ! ! ! ! 

;; WANTS SEARCH -- September 2016 , AUGUST 2017 
;; --- 

;; try to exclude 



;; would like to be able to search using TEXT WORDS -> WILL OUTPUT THE ENTIRE SHEET 
;; all the different 

;; would like to have date for news items 


;; would like to do something with her spreadsheet 


;; PARSING COLLEEN's sheet 
;; filename is rmg_file 


;;  pd.ExcelFile('path_to_file.xls')
;; df1 = pd.read_excel(xls, 'Sheet1')
;; df2 = pd.read_excel(xls, 'Sheet2')


(defn parse-rmg-file []
  (setv E (p.ExcelFile rmg-file))
  (setv sheet-names E.sheet_names)
  (lfor sheet sheet-names [sheet (.parse E :sheet_name sheet  :header rmg-header) ] )) 







