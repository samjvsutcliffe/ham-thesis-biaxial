import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import pandas as pd
import os
import numpy as np
import re

from scipy import integrate

def extract_vals(f):
    output,refine,load = f.split("-")
    #refine = float(refine)
    return refine,float(load)

from scipy import integrate
def calculate_gf(disp,load):
    i = np.argmax(load)
    print("Max at {}mm".format(disp[i]*1e3))
    return integrate.trapz(load[i:],disp[i:])

super_dir = "/nobackup/rmvn14/thesis/biaxial/"
output_regex = re.compile("data*")                                 
output_list = list(filter(output_regex.match,os.listdir(super_dir)))
output_list.sort()

if len(output_list) == 1:
    top_dir = super_dir + "./{}/".format(output_list[0]) 
else:
    for i,out in enumerate(output_list):                                    
        print("{}: {}".format(i,out))                                       
    top_dir = super_dir + "./{}/".format(output_list[int(input())]) 

#top_dir = "/nobackup/rmvn14/thesis/biaxial/data/"
regex = re.compile(r'^output.*')
folders = list(filter(regex.search,os.listdir(top_dir)))
plt.figure(1)
def get_load(filename):
    mpm = pd.read_csv(top_dir+filename)
    mpm["disp"] = mpm["disp"].abs()
    mpm["load"] = mpm["load"].abs()
    return mpm


folders.sort()

for i in folders:
    loadfile = "./{}/load-disp.csv".format(i)
    if os.path.isfile(top_dir+loadfile):
        print("loading folder: ",i)
        mpm = get_load(loadfile)
        if len(mpm["load"]) > 0:
            plt.plot(mpm["disp"].values*1e3,mpm["load"].values,label=i,marker="x")
            print("GF ",i," :",calculate_gf(mpm["disp"],mpm["load"]))
plt.xlabel("Displacement (mm)")
plt.ylabel("Load (N)")
plt.legend()
plt.show()
