# sdrc

# install brew 
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# install python  
brew install python 

# install virtualenv 
pip3 install virtualenv 

# make dir  
vitualenv --python=python3 py 

# activate 
cd py
source bin/activate 

# install pip 
pip install git+https://github.com/hylang/hy.git 

# clone repo 
git clone https://github.com/sheunaluko/sdrc.git

# get deps 
pip install BioPython pandas xlrd 

