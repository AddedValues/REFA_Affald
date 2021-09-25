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

pathfolder = r'C:\\GitHub\\REFA Affald\\Excel'
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
dfFuelBounds = sh.range('O4').options(pd.DataFrame, index=True, header=True, expand='table').value

print('Input data imported.')

# Example: extracting certain rows
#--- [x for x in dfFuelBounds['Fraktion'] if x.startswith('Dag')]
# rowsdag = [x.startswith('Dag') for x in dfFuelBounds['Fraktion'] ]
# dfDummy = dfFuelBounds[rowsdag]

#---------------------------------------------------------------------------
#%% Extract comfortable arrays from dataframes.

# Plant units
units = dfDataU.index
nunit = len(units)
onU = dfDataU['aktiv'] != 0
aunits = [u for u in units if onU[u]]
naunit = len(aunits)

kapTon = dfDataU['kapTon'][onU == True]
kapNom = dfDataU['kapNom'][onU == True]
kapRgk = dfDataU['kapRgk'][onU == True]
etaq = dfDataU['etaq'][onU == True]
costDV = dfDataU['DV'][onU == True]
costAux = dfDataU['aux'][onU == True]

# Prognoses
days = dfProgn['ndage']
qdem = dfProgn['varmebehov']
power = dfProgn['ELprod']
taxEts = dfProgn['ets']
taxAfv = dfProgn['afv'] / 3.6
taxAtl = dfProgn['atl'] / 3.6

# Fuels
fuels = dfDataFuel.index
nfuel = len(fuels)
onF = dfDataFuel['aktiv'] != 0
afuels = [f for f in fuels if onF[f]]
nafuel = len(afuels)

fkind = dfDataFuel['fkind'][onF == True]
storable = (dfDataFuel['lagerbart'] != 0)[onF == True]
tonnage = dfDataFuel['tonnage'][onF == True]
price = dfDataFuel['pris'][onF == True]
lhvMWf = dfDataFuel['brandv'][onF == True] / 3.6
shareCo2 = dfDataFuel['co2andel'][onF == True]

#%% TEST begin

# dropunits = [u for u in units if u not in aunits]
# dropfuels = [f for f in fuels if f not in afuels]
# dd = dfFuelBounds[dfFuelBounds['Bound']=='max']
# dd2 = dd.drop(dropfuels, inplace=False).drop(columns='Bound')

#%% TEST end

# dfFuelBounds shall be converted into 2 dataframes.
dfFuelMax = (dfFuelBounds[dfFuelBounds['Bound']=='max']).drop(dropfuels, inplace=False).drop(columns='Bound')
dfFuelMin = (dfFuelBounds[dfFuelBounds['Bound']=='min']).drop(dropfuels, inplace=False).drop(columns='Bound')

# Setup lookup tables.
months = ['jan','feb','mar','apr','maj','jun','jul','aug','sep','okt','nov','dec']
months = ['jan','feb']
nmo = len(months)

ukinds = {'affald':1, 'biomasse':2, 'varme':3, 'peak':4, 'cooler':5}
fkinds  = {'affald':1, 'biomasse':2, 'varme':3}

ua = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['affald']  ].index if onU[uu]]
ub = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['biomasse']].index if onU[uu]]
uc = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['varme']   ].index if onU[uu]]
nua = len(ua); nub = len(ub); nuc = len(uc)

fa = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['affald']  ].index if onF[ff]]
fb = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['biomasse']].index if onF[ff]]
fc = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['varme']   ].index if onF[ff]]
nfa = len(fa); nfb = len(fb); nfc = len(fc)




#--------------------------------------------------------------------------------------

#%%
u2f = pd.DataFrame(index=aunits, columns=afuels, dtype=bool)
for u in aunits:
    for f in afuels:
        u2f.at[u,f] = (u in ua and f in fa) or (u in ub and f in fb) or (u in uc and f in fc)
#%%
# Convert data frames to arrays and include only active entities.
aunit = [{i:u} for i,u in enumerate(aunits)]
afuel = [{i:f} for i,f in enumerate(afuels)]
u2f = u2f.to_numpy()


print('Counters and lookups are defined.')
#--------------------------------------------------------------------------------------
# %% Setup of optimization model

# Create new model
m = GEKKO()         
m.options.SOLVER=1  # APOPT is an MINLP solver

# Declare model constants
rgkRabatMinShare = m.Const(name='rabatMinShare', value=0.07)
rgkRabatSats = m.Const(name='rgkRabatSats', value = 0.10)

#--------------------------------------------------------------------------------------
#%% Create model variables.

# Variables are only defined on active entities.
# Results for non-active entities hence default to zero.

NPV = m.Var('NPV')  # Objective variable.

# Fundamental decision variables.
vbOnU        = m.Array(m.Var, (nmo, naunit), integer=True)
vbOnRgk      = m.Array(m.Var, (nmo, nua), integer=True)
vbOnRgkRabat = m.Array(m.Var, (nmo, nua), integer=True)

# FuelDemand(mo,u,f):
vFuelDemand = m.Array(m.Var, (nmo, naunit, nafuel), lb=0.0)

vQ        = m.Array(m.Var, (nmo, naunit), lb=0.0)
vQrgkMiss = m.Array(m.Var, (nmo),         lb=0.0)
vQafv     = m.Array(m.Var, (nmo),         lb=0.0)
vQrgk     = m.Array(m.Var, (nmo, nua),    lb=0.0)
vQaffM    = m.Array(m.Var, (nmo, nua),    lb=0.0)

vIncomeTotal   = m.Array(m.Var, (nmo),         lb=0.0)
vIncomeF       = m.Array(m.Var, (nmo, nafuel))
vRgkRabat      = m.Array(m.Var, (nmo),         lb=0.0)
vCostsU        = m.Array(m.Var, (nmo, naunit), lb=0.0)
vCostsTotalF   = m.Array(m.Var, (nmo),         lb=0.0)
vCostsAFV      = m.Array(m.Var, (nmo),         lb=0.0)
vCostsATL      = m.Array(m.Var, (nmo),         lb=0.0)
vCostsETS      = m.Array(m.Var, (nmo),         lb=0.0)
vCO2emis       = m.Array(m.Var, (nmo, nafuel), lb=0.0)
vTotalAffEProd = m.Array(m.Var, (nmo),         lb=0.0)

#--------------------------------------------------------------------------------------

#%% Create equations.

pPenalty_bOnU     = m.Param(value=1E+3)
pPenalty_QrgkMiss = m.Param(value=20.0)

# Objective
m.Obj(np.sum(vIncomeTotal) - np.sum(vCostsU) - np.sum(vCostsTotalF) \
      - pPenalty_bOnU * np.sum(vbOnU) - pPenalty_QrgkMiss * np.sum(vQrgkMiss) )

# IncomeTotal
eqIncomeTotal = list()
for mo in range(months):
    
    # eqIncomeTotal.append( == np.sum()
    pass


# Equation  ZQ_AffUseYear(f)   'Affaldsforbrug på aarsniveau';
# Equation  ZQ_AffMin(f,mo)    'Mindste  drivmiddelforbrug paa maanedsniveau';
# Equation  ZQ_BioUseYear(f)   'Biomasseforbrug på aarsniveau';
# Equation  ZQ_OVUseYear(f)    'Overskudsvarmeforbrug på aarsniveau';

# ZQ_AffUseYear(fa) $OnF(fa) ..  sum(mo, sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelDemand(ua,fa,mo)))  =E=  sum(mo, FuelBounds(fa,'max',mo));
# ZQ_AffMin(fa,mo)  $OnF(fa) ..          sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelDemand(ua,fa,mo))   =G=  FuelBounds(fa,'min',mo);
# ZQ_BioUseYear(fb) $OnF(fb) ..  sum(mo, sum(ub $(OnU(ub) AND u2f(ub,fb)), FuelDemand(ub,fb,mo)))  =L=  sum(mo, FuelBounds(fb,'max',mo));
# ZQ_OVUseYear(fc)  $OnF(fc) ..  sum(mo, sum(uc $(OnU(uc) AND u2f(uc,fc)), FuelDemand(uc,fc,mo)))  =E=  sum(mo, FuelBounds(fc,'max',mo));

eqAffUseYear = list()
for ifa in range(nfa):
    ub = dfFuelBounds[fa[ifa]]
    m.Equation()
    pass
    


for mo in range(nmo):
    m.Equations


#%%
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

# m.options.IMODE = 3  # Steady state optimization.
# # solve optimization
# m.solve(disp=True)  # remote=False for local solve

# print ('')
# print ('--- Results of the Optimization Problem ---')
# print ('Height: ' + str(height.value))
# print ('Diameter: ' + str(diameter.value))
# print ('Weight: ' + str(weight.value))
# %%
