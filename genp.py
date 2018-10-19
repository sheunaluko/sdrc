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


newsapi = NewsApiClient(api_key=i.news_api_key) 

# /v2/everything

def search_news(query) : 
    # must note that this defaults to the past year 
    all_articles = newsapi.get_everything(q=query, 
                                          #from_param='2017-09-01',
                                          #to='2018-09-01',
                                          language='en',
                                          sort_by='relevancy' )  
    return all_articles  


def search_news_page(query, p ) : 
    all_articles = newsapi.get_everything(q=query, 
                                          from_param='2017-09-01',
                                          to='2018-09-01',
                                          language='en',
                                          sort_by='relevancy', 
                                          page = p ) 
    return all_articles  



def contains(a1,a2) :  
    return bool(re.search(a2, a1))



# WILL DO RMG PARSING HERE SINCE WORKING WITH DATA FRAMES 
def get_rmg_sheets() : 
    return g.parse_rmg_file()

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
    members = df.loc[df['SDRC Member'] == 'Y']['Investigator'].values
    # create vec of the [ [member, role ] ... ] (no longer needed) 
    # members_and_roles = [ [ m['Investigator'] , m['Role'] ] for i,m in members.iterrows()]
    # get a complete list of all Investigators minus the PI
    
    all_sub_investigators = df.loc[df['Role'] != "Principal Investigator"]['Investigator'].values 
    
    debug = df 
    print("=> " + str(ID) )
    # get the old (unchanged) data 
    old = None 
    
    # oh wow... get ready for some ugly code ! 
    try : 
        old  = df[['School','Department', 'Owning Org', 'Agreement', 'Segment', 'Direct Sponsor',
                   'Direct Sponsor Program Code', 'Direct Sponsor Program', 'Segment Start Date',
                   'Segment End Date', 'Project Title', 'Segment Total']].iloc[0:1,:] #only first row
    except :
        try : 
            old = df[['School',' Department', 'Owning Org', 'Agreement Type', 'Direct Sponsor',
                      'Direct Sponsor Reference', 'Proposed Start Date', 'Proposed End Date',
                      'Project Title', 'Total Requested']].iloc[0:1,:]
        except : 
            old = df[['School', 'Dept', 'Org', 'Agreement', 'Direct Sponsor',
                      'Direct Sponsor Reference', 'Direct Sponsor Program Code',
                      'Direct Sponsor Program','Proposed Start Date', 'Proposed End Date',
                      'Proposal Title',' Total Requested']].iloc[0:1,:]
            
            

            
        
    debug = [df,ID,old]
    # figure out what index we got 
    ind = old.index.values[0]
    
    # create the new first couple columns of the data frame to return USING THAT INDEX
    new = p.DataFrame({'Project Id': [ID] , 
                       'Principal Investigator': [PI] , 
                       'SDRC Members': parse_members_list(members), 
                       'All Investigators' : parse_members_list(all_sub_investigators)} , 
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
    # only look at projects which have SDRC member
    members = s.loc[s['SDRC Member'] == 'Y' ] 
    # want to get all the IDs of projects that have an SDRC member 
    project_IDs_with_members = set(members['Project ID'])
    # now get all of the projects from the ORIGINAL data (not just members) with those IDs 
    projects_with_members = s.loc[s['Project ID'].isin(project_IDs_with_members)]
    # group those by ids , returns iterable
    grouped_projects_by_ID = projects_with_members.groupby('Project ID')
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
    d  = sheet_to_df(s1) 
    return d

def rmg_do_all() : 
    parsed_sheets = [ [sn, sheet_to_df(sn,s)] for sn,s in get_rmg_sheets() ]
    # now write the excel file 
    writer = p.ExcelWriter('rmg_parsed.xlsx')
    for sn, s in parsed_sheets : 
        print(sn) 
        s.to_excel(writer,sn)
    writer.save()

def my_module()  : 
    return sys.modules["genp"]

def r() : 
    importlib.reload(my_module()) 
    
def foo() : 
    print("hey there!!!" ) 
