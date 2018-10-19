# sdrc

# Installation steps for Mac OSX

1. install brew 
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

2. install python  
brew install python 

3. install virtualenv 
pip3 install virtualenv 

4. make dir  
vitualenv --python=python3 py 

5. activate 
cd py
source bin/activate 

6. install hy 
pip install git+https://github.com/hylang/hy.git 

7. clone repo 
git clone https://github.com/sheunaluko/sdrc.git

8. get deps
cd sdrc
pip install BioPython pandas xlrd 

9. ready to go 
python sdrc_main.py
