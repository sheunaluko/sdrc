import genp 
import gen 
gen.prepare_for_cache() 

import grant_main

ss = genp.get_rmg_sheets() 

df = ss[0][1] 

ms = genp.get_members_from_sheet(df).values 

dm = set( [ y for y in ms if genp.name_is_member(y)] ) 

lm = set( [ y for y in df.loc[df['SDRC Member'] == 'Y']['Investigator'].values ] ) 
