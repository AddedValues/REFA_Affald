# %% Imports 
import os
import io
import math
import gekko
import numpy as np
from numpy.lib.arraysetops import isin
import pandas as pd 
import xlwings as xw
import matplotlib.pyplot as plt
from array import array
import gekko as gk
from gekko import GEKKO
#-------------------------------------------------------------------
# %% Read input from Excel fil REFAinput.xlsb  

pathfolder = r'C:\\GitHub\\REFA Affald\\'
filename = r'REFAinput.xlsm'
path = os.path.join(pathfolder, filename)

#--- dfDataU = pd.read_excel(path, sheet_name='DataU', header=4, index_col=2, nrows=10-4)

wb = xw.Book(path)

sh = wb.sheets['DataU']
dfDataU : pd.DataFrame
dfProgn : pd.DataFrame
dfAvail : pd.DataFrame
dfDataU = sh.range('B4').options(pd.DataFrame, index=True, header=True, expand='table').value
#--- dfDataU = sh.range('B4:D6').options(pd.DataFrame, index=True, header=True).value
dfProgn = sh.range('B15').options(pd.DataFrame, index=True, header=True, expand='table').value
dfAvail = sh.range('B31').options(pd.DataFrame, index=True, header=True, expand='table').value

sh = wb.sheets['Fuel']
dfDataFuel   : pd.DataFrame
dfFuelBounds : pd.DataFrame
dfDataFuel   = sh.range('C4').options(pd.DataFrame, index=True, header=True, expand='table').value
dfFuelBounds = sh.range('O4').options(pd.DataFrame, index=False, header=True, expand='table').value

print('Input data imported.')

# Example: extracting certain rows
#--- [x for x in dfFuelBounds['Fraktion'] if x.startswith('Dag')]
# rowsdag = [x.startswith('Dag') for x in dfFuelBounds['Fraktion'] ]
# dfDummy = dfFuelBounds[rowsdag]

#---------------------------------------------------------------------------
#%% Extract comfortable arrays from dataframes.
# Define counters.
units = dfDataU.index
nunit = len(units)
fuels = dfDataFuel.index
nfuel = len(fuels)
onU = dfDataU['aktiv']
kapTon = dfDataU['kapTon']
kapNom = dfDataU['kapNom']
kapRgk = dfDataU['kapRgk']
etaq = dfDataU['etaq']
costDV = dfDataU['DV']
costAux = dfDataU['aux']
days = dfProgn['ndage']
qdem = dfProgn['varmebehov']
power = dfProgn['ELprod']
taxEts = dfProgn['ets']
taxAfv = dfProgn['afv'] / 3.6
taxAtl = dfProgn['atl'] / 3.6

onF = dfDataFuel['aktiv']
fkind = dfDataFuel['fkind']
storable = [x for x in dfDataFuel['lagerbart'] != 0]
tonnage = dfDataFuel['tonnage']
price = dfDataFuel['pris']
lhvMWf = dfDataFuel['brandv'] / 3.6
shareCo2 = dfDataFuel['co2andel']

# dfFuelBounds shall be converted into 2 dataframes
dfFuelMax = dfFuelBounds[dfFuelBounds['Bound']=='max']
dfFuelMin = dfFuelBounds[dfFuelBounds['Bound']=='min']

# Setup lookup tables.

# Aktive items.
aunits = [unit for unit in units if onU[unit]]
afuels = [fuel for fuel in fuels if onF[fuel]]

#HACK: reducing no. of active fuels for debugging purposes.
afuels = afuels[:2]


naunit = len(aunits)
nafuel = len(afuels)


months = ['jan','feb','mar','apr','maj','jun','jul','aug','sep','okt','nov','dec']
months = ['jan','feb']
nmo = len(months)
ukinds = {'affald':1, 'biomasse':2, 'varme':3, 'peak':4, 'cooler':5}
fkinds  = {'affald':1, 'biomasse':2, 'varme':3}

#TODO: ua .. uc shall use the dict ukind.
ua = [uu for uu in dfDataU[dfDataU['ukind']==1].index if onU[uu]]
ub = [uu for uu in dfDataU[dfDataU['ukind']==2].index if onU[uu]]
uc = [uu for uu in dfDataU[dfDataU['ukind']==3].index if onU[uu]]

#TODO: fa .. fc shall use the dict fkind.
fa = [ff for ff in dfDataFuel[dfDataFuel['fkind']==1].index if onF[ff]]
fb = [ff for ff in dfDataFuel[dfDataFuel['fkind']==2].index if onF[ff]]
fc = [ff for ff in dfDataFuel[dfDataFuel['fkind']==3].index if onF[ff]]

u2f = pd.DataFrame(index=aunits, columns=afuels, dtype=bool)
for u in units:
    for f in fuels:
        u2f.at[u,f] = (u in ua and f in fa) or (u in ub and f in fb) or (u in uc and f in fc)
#  u2f.to_numpy()

print('Counters and lookups are defined.')
#--------------------------------------------------------------------------------------
# %% Setup of optimization model

# Create new model
m = GEKKO()         
m.options.SOLVER=1  # APOPT is an MINLP solver

# Declare model constants
rgkRabatMinShare = m.Const(name='rabatMinShare', value=0.07)
rgkRabatSats = m.Const(name='rgkRabatSats', value = 0.10)

# Declare model parameters
# width = m.Param(value=60)
# thickness = m.Param(value=0.15)
# density = m.Param(value=0.3)
# modulus = m.Param(value=30000)
# load = m.Param(value=66)


# # Declare variables and initial guesses
NPV = m.Var('NPV')  # Objective variable.
#--------------------------------------------------------------------------------------

#%% Misc. helper functions

# NB: GEKKO stores names in lower case.

def createVars(varname:str, dim, lowerBound=None, upperBound=None, isInteger=False) -> np.ndarray:
    print('varname={0}, dim={1}'.format(varname, dim))
    if lowerBound is not None and upperBound is not None and lowerBound >= upperBound:
        raise ValueError('Conflicting bounds: lowerBound={0} GE upperBound={1}'.format(lowerBound, upperBound))
    vars = m.Array(m.Var, dim, integer=isInteger, lb=lowerBound, ub=upperBound)

    # if lowerBound is None:
    #     if upperBound is None:
    #         vars = m.Array(m.Var, dim, integer=isInteger)
    #     else: 
    #         vars = m.Array(m.Var, dim, integer=isInteger, ub=upperBound)
    # elif upperBound is None:
    #     vars = m.Array(m.Var, dim, integer=isInteger, lb=lowerBound)
    # else:
    #     vars = m.Array(m.Var, dim, integer=isInteger, lb=lowerBound, ub=upperBound)

    return vars

def createVar2D(varname:str, dim, lowerBound=None, upperBound=None, isInteger=False) -> np.ndarray:
    print('varname={0}, dim={1}'.format(varname, dim))
    if lowerBound is None:
        if upperBound is None:
            vars = m.Array(m.Var, dim, integer=isInteger)
        else: 
            vars = m.Array(m.Var, dim, integer=isInteger, ub=upperBound)
    elif upperBound is None:
        vars = m.Array(m.Var, dim, integer=isInteger, lb=lowerBound)
    else:
        vars = m.Array(m.Var, dim, integer=isInteger, lb=lowerBound, ub=upperBound)

    return vars

def createVars1D(prefix:str, serIndex:list, lowerBound:float, upperBound:float = None, integer=False) -> pd.Series:
    vars = pd.Series(index=serIndex, dtype=object)
    for i in serIndex:
        vname = prefix + i 
        if lowerBound is None:
            if upperBound is None:
                vars.at[i] = m.Var(name=vname, integer=integer)
            else:
                vars.at[i] = m.Var(name=vname, integer=integer, up=upperBound)
        elif upperBound is None:
            vars.at[i] = m.Var(name=vname, integer=integer, lb=lowerBound)
        else:
            vars.at[i] = m.Var(name=vname, integer=integer, lb=lowerBound, up=upperBound)

    return vars
#--------------------------------------------------------------------------------------

#%% Create model variables.

# xx = m.Array(m.Var, (2))
# m.Obj(np.sum(xx**2))

#%%
# Fundamental decision variables.
# vbOnU(mo,u):
vbOnU = m.Array(m.Var, (nmo, naunit), integer=True)
# vbOnF(mo,f):
vbOnF = m.Array(m.Var, (nmo, nafuel), integer=True)




vRgkRabat = m.Array(m.Var, (nmo, naunit), lb=0.0)


#--------------------------------------------------------------------------------------

#%%
# vbOnU = pd.DataFrame(index=months, columns=aunits.to_numpy())
# for mo in months:
#     for u in aunits:
#         name = 'vbOnU_' + mo + '_' + u
#         vbOnU.at[mo,u] = m.Var(name=name, integer=True)

# vbOnF(mo,f):
vbOnF = pd.DataFrame(index=months, columns=afuels.to_numpy())
for mo in months:
    for f in afuels:
        name = 'vbOnF_' + mo + '_' + f
        vbOnF.at[mo,f] = m.Var(name=name, integer=True)

# vbOnRgk(mo,ua):
vbOnRgk = pd.DataFrame(index=months, columns=u.to_numpy())
for mo in months:
    for u in [uu for uu in ua if uu in aunits]:
        name = 'vbOnRgk_' + mo + '_' + u
        vbOnF.at[mo,u] = m.Var(name=name, integer=True)

# vbOnRgkRabat(mo,ua):
vbOnRgkRabat = pd.DataFrame(index=months, columns=ua.to_numpy())
for mo in months:
    for u in [uu for uu in ua if uu in aunits]:
        name = 'vbOnRgkRabat_' + mo + '_' + u
        vbOnF.at[mo,u] = m.Var(name=name, integer=True)

# FuelDemand(mo,u,f):
# Create unique column names cf. u2f truth table.
ufCols = list()
for u in aunits:
    for f in afuels:
        if u2f.at[u,f]:
            ufCols.append(u + '_' + f)

vFuelDemand = pd.DataFrame(index=months, columns=ufCols)
for mo in months:
    for colname in ufCols:
        name = 'vFuelDemand_' + colname
        vFuelDemand.at[mo,colname] = m.Var(name=name, lb=0.0)

# Q(mo,u):
vQ = pd.DataFrame(index=months, columns=aunits.to_numpy())
for mo in months:
    for u in aunits:
        name = 'vQ_' + mo + '_' + u
        vQ.at[mo,u] = m.Var(name=name, lb=0.0)

# Qrgk(mo,ua)
vQrgk = pd.DataFrame(index=months, columns=ua)
for mo in months:
    for u in ua:
        name = 'vQrgk_' + mo + '_' + ua
        vQrgk.at[mo,ua] = m.Var(name=name, lb=0.0)

# Qrgk(mo,ua)
vRgkRabat = pd.DataFrame(index=months, columns=ua)
for mo in months:
    for u in ua:
        name = 'vQrgk_' + mo + '_' + ua
        vQrgk.at[mo,ua] = m.Var(name=name, lb=0.0)

# Variable som kun er tidsafhængige:  Var(mo)
vRgkRabat = createVars1D('vRgkRabat_', months, lowerBound=0.0)
vQrgkMiss = createVars1D('vQrgkMiss_', months, lowerBound=0.0)
vQafv     = createVars1D('vQafv_',     months, lowerBound=0.0)

# QaffM(mo,ua)
vQaffM = pd.DataFrame(index=months, columns=ua)
for mo in months:
    for u in ua:
        name = 'vQaffM_' + mo + '_' + ua
        vQaffM.at[mo,ua] = m.Var(name=name, lb=0.0)

# vIncomeTotal = createVars1D('vIncomeTotal_', months, lowerBound=0.0, upperBound=None)
# vCostsTotalF = createVars1D('vCostsTotalF_', months, lowerBound=0.0)
# vCostsAFV = createVars1D('vCostsAFV_', months, lowerBound=0.0)
# vCostsATL = createVars1D('vCostsATL_', months, lowerBound=0.0)
# vCostsETS = createVars1D('vCostsETS_', months, lowerBound=0.0)
# vTotalAffEProd = createVars1D('vTotalAffEProd_', months, lowerBound=0.0)


#%%-----------------------------------------------------------


height = m.Var(value=30.00,lb=10.0,ub=50.0)
# diameter = m.Var(value=3.00,lb=1.0,ub=4.0)
# weight = m.Var()

# # Intermediate variables with explicit equations
# leng = m.Intermediate(m.sqrt((width/2)**2 + height**2))
# area = m.Intermediate(np.pi * diameter * thickness)
# iovera = m.Intermediate((diameter**2 + thickness**2)/8)
# stress = m.Intermediate(load * leng / (2*area*height))
# buckling = m.Intermediate(np.pi**2 * modulus \
#               * iovera / (leng**2))
# deflection = m.Intermediate(load * leng**3 \
#               / (2 * modulus * area * height**2))

# # implicit equations
# m.Equation(weight==2*density*area*leng)
# m.Equation(weight < 24)
# m.Equation(stress < 100)
# m.Equation(stress < buckling)
# m.Equation(deflection < 0.25)

# Objective 
# m.Maximize(NPV)

# # solve optimization
# m.solve()  # remote=False for local solve

# print ('')
# print ('--- Results of the Optimization Problem ---')
# print ('Height: ' + str(height.value))
# print ('Diameter: ' + str(diameter.value))
# print ('Weight: ' + str(weight.value))
# %%
