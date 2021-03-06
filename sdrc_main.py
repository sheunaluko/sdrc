import hy 
import gen 
import util 
import json
import genp 
import os 
import shutil

parameter_filename = "sdrc_params.txt" 

#load param file into variables 
[sdrc_filename , sdrc_rows, start_date , end_date , keywords ,output_file, grant_file]  = [s.split("=")[1].strip() for s  in util.read_file(parameter_filename).split("\n") if s is not '' ] 

output_file = genp.cwd() + "/" + output_file + ".tsv" 

print("\n\n=================================\nSTANFORD DIABETES RESEARCH CENTER\n=================================") 
print("Created for Kiran Kocherlakota, contact: oluwa@stanford.edu , (901) 652-5382, Sun Oct 14 13:43:38 PDT 2018\n\n") 

print("\nLoading param file...") 
print( f'members_file = {sdrc_filename}\nnum_rows     = {sdrc_rows}\nstart_date   = {start_date}\nend_date     = {end_date}\nkeywords     = {keywords}\noutput_file  = {output_file}\n')




r = input("Please verify that the parameters above are correct,\n especially the date format, then press Enter to continue...")




#configure gen.hy module with correct parameters 
gen.sdrc_filename   = sdrc_filename 
gen.sdrc_start_date = start_date 
gen.sdrc_end_date   = end_date  
gen.sdrc_rows       = int(sdrc_rows)
gen.keywords        = json.loads(keywords)  
gen.output_file     = output_file 

print("\nUsing date range: " + gen.sdrc_date_range() + "\n" ) 

if genp.check_for_file(output_file) : 
    ans = input("The output file already exists.. would you like to overwrite it? (type yes/no)")
    if ( ans.lower() != "yes" ) : 
        print("Please change the output_file parameter if you do not wish to overwrite, then re-run the program")
        exit()
    os.remove(output_file) 
    unique = output_file.replace(".tsv" , "_unique.tsv")
    if genp.check_for_file(unique) : 
        os.remove(unique)
        
#need to clear the cache folder 
cache = genp.cwd() + "/cache" 
if os.path.isdir(cache) : 
    #clear it 
    #print("Clearing cache directory") 
    #shutil.rmtree(cache)
    #os.mkdir(cache) 
    pass
else : 
    #make it 
    print("Making cache directory") 
    os.mkdir(cache) 
    
#call prepare to initialize remaining vars which depend on the params just supplied
gen.prepare_for_cache() 

#cache all the author information 
gen.cache_all() 


#write the file (but dont forget to prepare-for-write first ! ) 
gen.prepare_for_write() 
gen.write_pubmed_data_1() 
gen.write_no_duplicates()

              
            





print("\n\n=================================\nSTANFORD DIABETES RESEARCH CENTER\n=================================") 
print("Created for Kiran Kocherlakota, contact: oluwa@stanford.edu , (901) 652-5382, Sun Oct 14 13:43:38 PDT 2018\n\n") 
