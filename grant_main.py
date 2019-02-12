import hy 
import gen 
import util 
import json
import genp 
import os 
import shutil
import genp  

parameter_filename = "sdrc_params.txt" 

#load param file into variables 
[sdrc_filename , sdrc_rows, start_date , end_date , keywords ,output_file, grant_filename]  = [s.split("=")[1].strip() for s  in util.read_file(parameter_filename).split("\n") if s is not '' ] 

grant_output = genp.cwd() + "/" + "parsed_rmg.xlsx"

print("\n\n=================================\nSTANFORD DIABETES RESEARCH CENTER\n=================================") 
print("Created for Kiran Kocherlakota, contact: oluwa@stanford.edu , (901) 652-5382, Sun Oct 14 13:43:38 PDT 2018") 

print("\nLoading param file...") 
print( f'grant_file  = {grant_filename}\n')
print("\nREMEMBER that each sheet in the grant file must START with the column names (i.e. have no header.")

r = input("Please verify that the parameters above are correct, then press Enter to continue...")




#configure gen.hy module with correct parameters 
gen.sdrc_filename   = sdrc_filename 
gen.sdrc_start_date = start_date 
gen.sdrc_end_date   = end_date  
gen.sdrc_rows       = int(sdrc_rows )
gen.keywords        = json.loads(keywords)  
gen.output_file     = output_file 
gen.rmg_file        = grant_filename
gen.rmg_output      = grant_output

if genp.check_for_file(grant_output) : 
    ans = input("The (GRANT) output file already exists.. would you like to overwrite it? (type yes/no)")
    if ( ans.lower() != "yes" ) : 
        print("Please change the output_file parameter if you do not wish to overwrite, then re-run the program")
        exit()
    os.remove(grant_output) 
        

gen.prepare_for_cache()
genp.rmg_do_all()



print("\n\n=================================\nSTANFORD DIABETES RESEARCH CENTER\n=================================") 
print("Created for Kiran Kocherlakota, contact: oluwa@stanford.edu , (901) 652-5382, Sun Oct 14 13:43:38 PDT 2018\n\n") 
