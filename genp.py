import hy 
import util 
import info as i 
import json 
import re 
import gen as g 
import pandas as p 
import importlib 
import sys 

debug = None 

def stringify_list_sep(l,sep) : 
    if isinstance(l, list) : 
        return  sep.join(l) 
    else :
        return l
    
def stringify_list(l) : 
    return stringify_list_sep(l, ",")


filter_translations = i.filter_translations

def expand_filter(k,v) : 
    filter_id = filter_translations[k] 
    filter_suffix =  " [" +  filter_id + "]" 
    ors = [ "(" + stringify_list_sep(list(map(lambda x: x + filter_suffix , ands)), " AND ") + ")" for ands in v ]
    expanded = "( " + stringify_list_sep(ors, " OR " ) + " )"
    return expanded 


def acopy(tmp) : 
    str = tmp.encode() 
    from subprocess import Popen, PIPE
    p = Popen(['xsel', '-bi'], stdin=PIPE)
    p.communicate(input=str)

def cwd() : 
    import os
    return os.getcwd() 
    
def write_json(fname, obj) : 
    with open(fname, 'w') as outfile : 
        json.dump(obj, outfile) 
    print("Wrote ", fname)

def read_json(fname) : 
    with open(fname) as f:
        data = json.load(f)
    return data 
        
def check_for_file(fname)  : 
    import os.path
    return os.path.isfile(fname) 


def append_file(fname, strang) : 
    if not check_for_file(fname) : 
        mode = 'w' 
    else : 
        mode = 'a+' 

    with open(fname, mode) as outfile : 
        outfile.write(strang)






def contains(a1,a2) :  
    return bool(re.search(a2, a1))



# WILL DO RMG PARSING HERE SINCE WORKING WITH DATA FRAMES 
def get_rmg_sheets() : 
    return [ x for x in g.parse_rmg_file() if not x[1].empty ] 

# For Colleen’s document, I need the code to identify when SDRC member is
# involved whether as investigator or co-investigator or any capacity. For each project,
# if the code could pull the investigator name (whether SDRC member or not) and then group 
# all co/sub-investigators into another column, that will be great.



def flip_name(name) : 
    tokens = [ s.strip() for s in name.split(",")]
    if len(tokens) == 2  : 
        return tokens[1] + " " + tokens[0] 
    else : 
        return tokens[1] + " " + tokens[0] + " " +  " ".join(tokens[2:])


def parse_members_list(members) : 
    return ", ".join([flip_name(m) for m in members ] )

def remove_stuff_from_name(name) : 
    return name.strip().replace(".","").replace(",","").replace("Dr ","").replace("Prof ","").lower()

def parse_name_for_matching(name) : 
    tokens = [ remove_stuff_from_name(s) for s in name.split(",")]
    return tokens[0] + " " + tokens[1][0]

def name_is_member(inv) :
    if g.sdrc_collaborators_set : 
        return parse_name_for_matching(inv) in g.sdrc_collaborators_set 
    else  : 
        raise Exception("gen.sdrc-collaborators-set not defined yet, need to init gen.hy")
def get_members_from_sheet(s) : 
    return s['Investigator']
    

# handles a group of ids where struct is [ name, df ]
def handle_id_group(arg) :
    [ID, df] = arg 
    global debug
    debug = arg
    # need to get the investigator name 
    try : 
        PI = df.loc[df['Role'] == "Principal Investigator"]['Investigator'].values[0]
    except : 
        PI = "none" 
    
    # get the SDRC members 
    labeled_members = df.loc[df['SDRC Member'] == 'Y']['Investigator'].values

    # because sometimes they are not labeled properly, we will also get them by manually searching: 
    found_members = [i for i in df['Investigator'].values if name_is_member(i) ] 

    # merge the arrays into list removing duplicates 
    members = list( set(labeled_members).union(set(found_members))  ) 


    # get a complete list of all Investigators minus the PI
    all_sub_investigators = df.loc[df['Role'] != "Principal Investigator"]['Investigator'].values 
    
    debug = df 
    #print("=> " + str(ID) )
    # get the old (unchanged) data 
    old = None 

    # oh wow... 
    old  = df.iloc[0:1,4:]  # get first row, 4th and remaining columns 

    debug = [df,ID,old]
    # figure out what index we got 
    ind = old.index.values[0]
    
    # create the new first couple columns of the data frame to return USING THAT INDEX
    new = p.DataFrame({'Project Id': [ID] , 
                       'Principal Investigator': [PI] , 
                       'SDRC Members': parse_members_list(members), 
                       'Non-PI Investigators' : parse_members_list(all_sub_investigators)} , 
                      index = [ind])

    # merge the new columns with the unchanged ones 
    result = p.concat([new, old], axis=1, sort=False)
    
    # return for production 
    return result # [new,old]
    
    
    # return for testing
    return { 'PI' : PI ,
             'MEMBERS' : members , 
             'SUB_INV' : all_sub_investigators , 
             'df' : df , 
             'new' : new, 
             'old' : old, 
             'result' : result } 

              
def parse_sheet(s) : 
    # look at all projects
    # group those by ids , returns iterable
    grouped_projects_by_ID = s.groupby('Project ID')
    projects_vector = [] 
    for ID, group in grouped_projects_by_ID : 
        projects_vector.append( [ ID, group ] ) 
    return projects_vector 

def sheet_to_df(sn,s) : 
    print("Parsing sheet: " + sn)
    projects_vector = parse_sheet(s) 
    dfs = [ handle_id_group(g)  for g in projects_vector ] 
    return p.concat(dfs, axis=0, sort=False, ignore_index=True) 

    
def nexttt() :     
    # group by the project ID 
    projects = members.groupby('Project ID') 
    # loop through this and create a vector 
    projects_vector = [] 
    for name, group in projects : 
        projects_vector.append( [ name, group ] ) 
        
    return projects_vector 
    

def test() : 
    sheets = get_rmg_sheets() 
    s1 = sheets[0][1] 
    d  = sheet_to_df('first',s1) 
    return d

def rmg_do_all() : 
    parsed_sheets = [ [sn, sheet_to_df(sn,s)] for sn,s in get_rmg_sheets() ]
    # now write the excel file 
    writer = p.ExcelWriter(g.rmg_output)
    for sn, s in parsed_sheets : 
        print(f'Writing: {sn}') 
        s.to_excel(writer,sn)
    writer.save()
    print("Finished writing: " + g.rmg_output)

def my_module()  : 
    return sys.modules["genp"]

def r() : 
    importlib.reload(my_module()) 
    
def foo() : 
    print("hey there!!!" ) 
