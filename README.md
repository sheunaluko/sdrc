# sdrc

# Installation steps for Mac OSX

###### install brew 
```
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```
###### install python  
```
brew install python 
```
###### install virtualenv 
```
pip3 install virtualenv 
```
###### make dir  
```
vitualenv --python=python3 py 
```
###### activate 
```
cd py
source bin/activate 
```
###### install hy 
```
pip install git+https://github.com/hylang/hy.git 
```
###### clone repo 
```
git clone https://github.com/sheunaluko/sdrc.git
```
###### get deps
```
cd sdrc
pip install BioPython pandas xlrd openpyxl
```

# How to run 
```
cd dev/py 
source bin/activate 
cd sdrc 
#edit the param file first then run: 
python sdrc_main.py
```

# How to re sync code after updates
```
cd dev/py/sdrc 
git pull origin master 
```
If errors arise, you can try:
```
git stash
git pull origin master
``` 
Or you can simply remove the cache folder, sdrc_parameters.txt, and any generated files then re-run:
```
git pull origin master 
``` 
