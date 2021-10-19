# %% Imports 
#region Imports
import os
import io
import math
import numpy as np
import pandas as pd 
import xlwings as xw
import matplotlib.pyplot as plt
import gekko as gk
from array import array
from gekko import GEKKO
#endregion 
#-------------------------------------------------------------------
# %% Read input from Excel fil REFAinput.xlsb  
#region Read input
pathfolder = r'C:\\GitHub\\REFA Affald\\Excel'
filename = r'REFAinputX.xlsm'
path = os.path.join(pathfolder, filename)
 
#--- dfDataU = pd.read_excel(path, sheet_name='DataU', header=4, index_col=2, nrows=10-4)

wb = xw.Book(path)

sh = wb.sheets['ModelParms']
dfModelParms: pd.DataFrame
dfModelParms = sh.range('B4').options(pd.DataFrame, index=True, header=True, expand='table').value

sh = wb.sheets['DataU']
dfDataU : pd.DataFrame
dfProgn : pd.DataFrame
dfAvailU : pd.DataFrame
dfDataU  = sh.range('B4').options(pd.DataFrame, index=True, header=True, expand='table').value
#--- dfDataU  = sh.range('B4:D6').options(pd.DataFrame, index=True, header=True).value
dfProgn  = sh.range('B15').options(pd.DataFrame, index=True, header=True, expand='table').value
dfAvailU = sh.range('B31').options(pd.DataFrame, index=True, header=True, expand='table').value

sh = wb.sheets['Fuel']
dfDataFuel   : pd.DataFrame
dfFuelBounds : pd.DataFrame
dfDataFuel   = sh.range('C4').options(pd.DataFrame, index=True, header=True, expand='table').value
dfFuelBounds = sh.range('R4').options(pd.DataFrame, index=True, header=True, expand='table').value

print('Input data imported.')

# Example: extracting certain rows
#--- [x for x in dfFuelBounds['Fraktion'] if x.startswith('Dagren')]
# rowsdag = [x.startswith('Dag') for x in dfFuelBounds['Fraktion'] ]
# dfDummy = dfFuelBounds[rowsdag]
#endregion 
#---------------------------------------------------------------------------
#%% Extract comfortable arrays from dataframes.
#region Extract comfortable arrays from dataframes.
# Model parms
penalty_QrgkMiss = dfModelParms.loc['Penalty_QRgkMiss','Værdi']
rgkRabatMinShare = dfModelParms.loc['RgkRabatMinShare','Værdi']
rgkRabatSats     = dfModelParms.loc['RgkRabatSats','Værdi']

# Define lookup list and dicts.
months = ['jan','feb','mar','apr','maj','jun','jul','aug','sep','okt','nov','dec']
#TODO Shortlisting months for debugging purposes.
months = ['jan','feb']
nmo = len(months)

ukinds = {'affald':1, 'biomasse':2, 'varme':3, 'peak':4, 'cooler':5}
fkinds = {'affald':1, 'biomasse':2, 'varme':3, 'peak':4}

# Plant units
# Creating lookups for active items.
# Reverse (from active to all) is using the get_loc function of the pd.Series class.
# Example: allIndex = units.get_loc('Cooler') # gives the position of 'Cooler' in units.
units = dfDataU.index
nunit = len(units)
onU = dfDataU['aktiv'] != 0
aunits = [u for u in units if onU[u]]
naunit = len(aunits)
uRev = [i for i,on in enumerate(onU) if on]  # Absolute index of active units.
auprod = [u for u in units if onU[u] and dfDataU.loc[u,'ukind'] != ukinds['cooler']]
nauprod = len(auprod)

# All parameters, variables and equations will  refer to active entities only.
kapTon = dfDataU['kapTon'][onU == True]
kapNom = dfDataU['kapNom'][onU == True]
kapRgk = dfDataU['kapRgk'][onU == True]
kapMin = dfDataU['kapMin'][onU == True]
kapMax = kapNom + kapRgk
etaq   = dfDataU['etaq'][onU == True]
costDV = dfDataU['DV'][onU == True]
costAux = dfDataU['aux'][onU == True]

# Priority scheme of production units. Higher priority value implies higher priority toward lower units of lower priority values.
# Two or more units may have same priority.
priority = dfDataU['prioritet'][onU == True]
dropunits = [u for u in aunits if priority[u] == 0]
uprio = priority.drop(labels=dropunits, inplace=False)
uprio2up = np.zeros((nauprod, nauprod), dtype=bool)
for up1 in uprio:
    for up2 in aunits:
        if priority[up1] > priority[up2]:
            uprio2up[up1,up2] = True

# Prognoses.
days = dfProgn['ndage']
qdem = dfProgn['varmebehov']
power = dfProgn['ELprod']
taxEts = dfProgn['ets']
taxAfvMWh = dfProgn['afv'] / 3.6
taxAtlMWh = dfProgn['atl'] / 3.6
if not onU['Ovn3']:
    power = np.zeros((nmo), dtype=float)

# Fuels
fuels = dfDataFuel.index
nfuel = len(fuels)
onF = dfDataFuel['aktiv'] != 0
afuels = [f for f in fuels if onF[f]]
nafuel = len(afuels)
fRev = [i for i,on in enumerate(onF) if on]  # Absolute index of active fuels.
fkind = dfDataFuel['fkind'][onF == True]
storable = (dfDataFuel['lagerbar'] != 0)[onF == True]
minTonnage = dfDataFuel['minTonnage'][onF == True]
maxTonnage = dfDataFuel['maxTonnage'][onF == True]
fuelprice = dfDataFuel['pris'][onF == True]
lhvMWf = dfDataFuel['brandv'][onF == True] / 3.6
shareCo2 = dfDataFuel['co2andel'][onF == True]
MinLhvMWh = dfDataU['MinLhv'][onU == True] / 3.6

#endregion ---------------------------------------------------------------------------

#region Define counters and lookups

# Lookup by name.
iaunit  = [{au,i} for i, au in enumerate(aunits)]
iafuel  = [{af,i} for i, af in enumerate(afuels)]

# Lookup by compact index.
aubyidx = [{i:u} for i,u in enumerate(aunits)]
afbyidx = [{i:f} for i,f in enumerate(afuels)]

# Entities to be filtered from dataframes.
dropunits = [u for u in units if u not in aunits]
dropfuels = [f for f in fuels if f not in afuels]

# dfFuelBounds shall be converted into 2 dataframes.
dfFuelMax = (dfFuelBounds[dfFuelBounds['Bound']=='max']).drop(dropfuels, inplace=False).drop(columns='Bound')
dfFuelMin = (dfFuelBounds[dfFuelBounds['Bound']=='min']).drop(dropfuels, inplace=False).drop(columns='Bound')

# Setup lookup tables.

ua   = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['affald']  ].index if onU[uu]]
ub   = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['biomasse']].index if onU[uu]]
uc   = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['varme']   ].index if onU[uu]]
ur   = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['peak']    ].index if onU[uu]]
uv   = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['cooler']  ].index if onU[uu]]
uaux = [uu for uu in dfDataU[dfDataU['ukind'] != ukinds['affald']].index if onU[uu]]
nua = len(ua); nub = len(ub); nuc = len(uc); nup = len(uv); nuv = len(uv); nuaux = len(uaux)

fa   = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['affald']  ].index if onF[ff]]
fb   = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['biomasse']].index if onF[ff]]
fc   = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['varme']   ].index if onF[ff]]
fr   = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['peak']    ].index if onF[ff]]
faux = [ff for ff in dfDataFuel[dfDataFuel['fkind'] != fkinds['affald']  ].index if onF[ff]]
ffri = [ff for ff in dfDataFuel[dfDataFuel['fri'] != 0].index if onF[ff]]
fdis = [ff for ff in dfDataFuel[dfDataFuel['bortskaffes'] != 0].index if onF[ff]]
fsto = [ff for ff in dfDataFuel[dfDataFuel['lagerbar'] != 0].index if onF[ff]]
nfa   = len(fa); nfb = len(fb); nfc = len(fc); 
nfaux = len(faux); nffri = len(ffri); nfdis = len(fdis); nfsto = len(fsto)

u2f = pd.DataFrame(index=auprod, columns=afuels, dtype=bool)
for u in auprod:
    for f in afuels:
        u2f.at[u,f] = (u in ua and f in fa) or (u in ub and f in fb) or (u in uc and f in fc) or (u in ur and f in fr)

# print(u2f)
u2f = u2f.to_numpy()

ibegu = {'ua':0,     'ub':nua,           'uc':nua + nub,           'ur':nua + nub + nuc,           'uv': nua + nub + nuc + nup,           'uaux': nua}
iendu = {'ua':nua-1, 'ub':nua + nub - 1, 'uc':nua + nub + nuc - 1, 'ur':nua + nub + nuc + nup - 1, 'uv': nua + nub + nuc + nup + nuv - 1, 'uaux': nua + nub + nuc + nup - 1} 

ibegf = {'fa':0,     'fb':nfa,           'fc':nfa + nfb,           'faux': nfa}
iendf = {'fa':nfa-1, 'fb':nfa + nfb - 1, 'fc':nfa + nfb + nfc - 1, 'faux': nfa + nfb + nfc + nfaux - 1} 

# Specific indices
iacooler = -1
if nuv > 0:
	iacooler = ibegu['uv']

# Availabilities
hours = days * 24
shareAvailU = np.zeros(shape=(nmo,naunit), dtype=float)
for imo, mo in enumerate(months):
    for iu, u in enumerate(aunits):
        # shareAvailU[imo,iu] = max(0.0, min(1.0, dfAvailU.at[mo,u] / days[mo]) )
        shareAvailU[imo,iu] = dfAvailU.at[mo,u] / days[mo]

print('Counters and lookups are defined.')
#endregion 
#--------------------------------------------------------------------------------------
#%% Compute parameters

# EaffGross(mo)    = QaffTotalMax(mo) + Power(mo);
# QaffMmax(ua,mo)  = min(ShareAvailU(ua,mo) * Hours(mo) * KapNom(ua), 
#                       [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelBounds(fa,'max',mo) * EtaQ(ua) * LhvMWh(fa))]) $OnU(ua);
# QrgkMax(ua,mo)   = KapRgk(ua) / KapNom(ua) * QaffMmax(ua,mo);
# QaffTotalMax(mo) = sum(ua $OnU(ua), ShareAvailU(ua,mo) * (QaffMmax(ua,mo) + QrgkMax(ua,mo)) );
# CostsATLMax(mo) = sum(ua $OnU(ua), ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua)) * TaxAtlMWh(mo);
# RgkRabatMax(mo) = RgkRabatSats * CostsATLMax(mo);
# QRgkMissMax = 2 * RgkRabatMinShare * sum(ua $OnU(ua), 31 * 24 * KapNom(ua));  # Faktoren 2 er en sikkerhedsfaktor mod inffeasibilitet.

EaffGross    = np.zeros((nmo), dtype=float)
QaffMmax     = np.zeros((nmo,nua), dtype=float)
QrgkMax      = np.zeros((nmo,nua), dtype=float)
QaffTotalMax = np.zeros((nmo), dtype=float)
CostsATLmax  = np.zeros((nmo), dtype=float)
RgkRabatMax  = np.zeros((nmo), dtype=float)

for imo in range(nmo):
    qaff = 0.0
    atlmax = 0.0
    for iua in range(ibegu['ua'], iendu['ua']):
        f1 = shareAvailU[imo,iua] * hours[imo] * kapNom[iua]
        f2 = 0.0
        for ifa, fa in enumerate(afuels):
            if u2f[iua,ifa]:
                f2 += dfFuelMax.iloc[imo,ifa] * lhvMWf[ifa]
        f2 *= etaq[iua]
        QaffMmax[imo,iua] = min(f1, f2)
        QrgkMax[imo,iua]  = kapRgk[iua] / kapNom[iua] * QaffMmax[imo,iua]
        qaff += shareAvailU[imo,iua] * (QaffMmax[imo,iua] + QrgkMax[imo,iua])
        atlmax += shareAvailU[imo,iua] * hours[imo] * kapMax[iua]

    QaffTotalMax[imo] = qaff
    EaffGross[imo] = QaffTotalMax[imo] + power[imo] 
    CostsATLmax[imo] = atlmax * taxAtlMWh[imo]
    RgkRabatMax[imo] = rgkRabatSats * CostsATLmax[imo]

QRgkMissMax = 0.0
for iua in range(ibegu['ua'], iendu['ua']):
    QRgkMissMax += 2 * rgkRabatMinShare * 31 * 24 * kapNom[iua]

#--------------------------------------------------------------------------------------
# %% Setup of optimization model

# Create new model
m = GEKKO()         
m.options.SOLVER=1  # APOPT is an MINLP solver
#--------------------------------------------------------------------------------------
#%% Create model variables.

# Variables are only defined on active entities.
# Hence results for non-active entities default to zero.

NPV = m.Var('NPV')  # Objective variable.

# Fundamental decision variables. Python variables prefixed with 'v' as compared to GAMS variables.
vbOnU        = m.Array(m.Var, (nmo, nauprod), integer=True)
vbOnRgk      = m.Array(m.Var, (nmo, nua),     integer=True)
vbOnRgkRabat = m.Array(m.Var, (nmo, nua),     integer=True)

# FuelDemand(mo,u,f):
vFuelDemand        = m.Array(m.Var, (nmo, nauprod, nafuel), lb=0.0)
vFuelDemandFreeSum = m.Array(m.Var, (nmo), lb=0.0)

vQ        = m.Array(m.Var, (nmo, nauprod), lb=0.0)
vQrgkMiss = m.Array(m.Var, (nmo),          lb=0.0)
vQafv     = m.Array(m.Var, (nmo),          lb=0.0)
vQrgk     = m.Array(m.Var, (nmo, nua),     lb=0.0)
vQaffM    = m.Array(m.Var, (nmo, nua),     lb=0.0)

vRgkRabat      = m.Array(m.Var, (nmo),     lb=0.0)
vTotalAffEProd = m.Array(m.Var, (nmo),     lb=0.0)

# Intermediate variable (assigned below)
# vIncomeTotal   = m.Array(m.Var, (nmo),          lb=0.0)
# vIncomeAff     = m.Array(m.Var, (nmo, nafuel))
# vCostsU        = m.Array(m.Var, (nmo, nauprod), lb=0.0)
# vCostsTotalF   = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsAFV      = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsATL      = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsETS      = m.Array(m.Var, (nmo),          lb=0.0)
# vCO2emis       = m.Array(m.Var, (nmo, nafuel),  lb=0.0)

# Intermediate variable will be stored in ndarrays.
vIncomeTotal    = np.empty((nmo),          object) 
vIncomeAff      = np.empty((nmo, nafuel),  object)
vCostsU         = np.empty((nmo, nauprod), object)
vCostsTotalF    = np.empty((nmo),          object)
vCostsTotalAuxF = np.empty((nmo),          object)
vCostsAuxF      = np.empty((nmo, nfaux),   object)
vCostsAFV       = np.empty((nmo),          object)
vCostsATL       = np.empty((nmo),          object)
vCostsETS       = np.empty((nmo),          object)
vCO2emis        = np.empty((nmo, nafuel),  object)

print('Variables have been defined')
#--------------------------------------------------------------------------------------
#%% Create equations.

pPenalty_bOnU     = m.Param(value=1E+3, name='Penalty_bOnU')
pPenalty_QrgkMiss = m.Param(value=20.0, name='Penalty_QrgkMiss')

allEqns = dict()    # Dictionary for all equations.

objective = np.sum(vIncomeTotal) - np.sum(vCostsU) - np.sum(vCostsTotalF) - pPenalty_bOnU * np.sum(vbOnU) - pPenalty_QrgkMiss * np.sum(vQrgkMiss) 
m.Obj(objective)
allEqns['Objective'] = objective

# ZQ_IncomeTotal(mo)       .. IncomeTotal(mo)   =E=  sum(fa $OnF(fa), IncomeAff(fa,mo)) + RgkRabat(mo) + VarmeSalgspris * sum(up $OnU(up), Q(up,mo));

for imo in range(nmo):
    exIncomeTotal = vRgkRabat[imo]
    for iff in range(nafuel):
        exIncomeTotal += vIncomeAff[imo,iff]
    vIncomeTotal[imo] = m.Intermediate(exIncomeTotal, 'IncomeTotal_' + months[imo])

# ZQ_IncomeAff(fa,mo)      .. IncomeAff(fa,mo)  =E=  sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * DataFuel(fa,'pris')) $OnF(fa);
for imo in range(nmo):
    for iff in range(nafuel):
        exIncomeF = 0.0
        for iu in range(ibegu['ua'], iendu['ur']):   # All production units
            exIncomeF += vFuelDemand[imo,iu,iff] * fuelprice[iff]
        vIncomeAff[imo,iff] = m.Intermediate(exIncomeF, 'IncomeF_' + afbyidx[iff] + '_' + months[imo])

# ZQ_CostsU(u,mo) .. CostsU(u,mo)  =E=  Q(u,mo) * (DataU(u,'dv') + DataU(u,'aux') ) $OnU(u);
for imo in range(nmo):
    for iu in range(naunit):
        vCostsU = m.Intermediate(vQ[imo,iu] * (costDV[iu] + costAux[iu]))

# ZQ_Qafv(mo) .. Qafv(mo)  =E=  sum(ua $OnU(ua), Q(ua,mo)) - Q('cooler',mo);   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.
for imo in range(nmo):
    exQAfv = 0.0
    if onU['cooler']:
        exQAfv = -vQ[imo,iaunit['cooler']] 
    for iu in range(ibegu['ua'], iendu['ua']):
        exQAfv     += vQ[imo,iu] 
    vQafv[imo]           = m.Intermediate(exQAfv,           'Qafv'         + months[imo])

# ZQ_CO2emis(f,mo) $OnF(f) .. CO2emis(f,mo)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelDemand(up,f,mo)) * DataFuel(f,'co2andel');  
for imo in range(nmo):
    for iff in range(nafuel):
        exCO2emis = 0.0
        for iu in range(ibegu['ua'], iendu['ur']):   # All production units
            exCO2emis += vFuelDemand[imo,iu,iff] * shareCo2[iff]
        vCO2emis[imo,iff] = m.Intermediate(exCO2emis, 'CO2emis_' + afbyidx[iff] + '_' + months[imo])

# ZQ_CostsETS(mo) .. CostsETS(mo)  =E=  sum(f $OnF(f), CO2emis(f,mo)) * TaxEtsTon(mo);
for imo in range(nmo):
    exCostsETS = 0.0
    for iff in range(nafuel):
        exCostsETS += vCO2emis[imo,iff] * taxEts[imo]
    vCostsETS[imo] = m.Intermediate(exCostsETS, 'CostsETS_' + months[imo])

# ZQ_CostsAFV(mo)          .. CostsAFV(mo)        =E=  Qafv(mo) * TaxAfvMWh(mo);
for imo in range(nmo):
    for iu in range(ibegu['ua'], iendu['ua']):
        exQAfv += vQ[imo,iu] 
    vCostsAFV[imo] = m.Intermediate(vQafv[imo] * taxAfvMWh[imo], 'CostsTotalF_' + months[imo])

# ZQ_CostsATL(mo) .. CostsATL(mo)  =E=  sum(ua $OnU(ua), Q(ua,mo)) * TaxAtlMWh(mo);
for imo in range(nmo):
    exCostsATL = 0.0
    for iu in range(ibegu['ua'], iendu['ua']):
        exCostsATL += vQ[imo,iu] * taxAtlMWh[imo]
    vCostsATL[imo]       = m.Intermediate(exCostsATL,       'CostsATL'     + months[imo])

# ZQ_CostsTotalF(mo) .. CostsTotalF(mo)  =E=  CostsTotalAuxF(mo) + CostsAFV(mo) + CostsATL(mo) + CostsETS(mo);
for imo in range(nmo):
    vCostsTotalF[imo]    = m.Intermediate(vCostsTotalAuxF[imo] + vCostsAFV[imo] + vCostsATL[imo] + vCostsETS[imo], 'CostsTotalF_' + months[imo])

# ZQ_CostsTotalAuxF(mo)    .. CostsTotalAuxF(mo)  =E=  sum(faux, CostsAuxF(faux,mo));
for imo in range(nmo):
    exCostsTotalAuxF = 0.0
    for iff in range(nfaux):
        exCostsAuxF = 0.0
        for iu in range(ibegu['uaux'], iendu['uaux']):
            exCostsAuxF += vFuelDemand[imo,iu,iff] * fuelprice[iff]
        vCostsAuxF[imo,iff] = m.Intermediate(exCostsAuxF, 'CostsAuxF_' + afbyidx[iff] + '_' + months[imo])
        exCostsTotalAuxF += vCostsAuxF[imo,iff]
    vCostsTotalAuxF[imo] = m.Intermediate(exCostsTotalAuxF, 'CostsTotalAuxF_' + months[imo])

# ZQ_CostsAuxF(faux,mo) .. CostsAuxF(faux,mo)  =E=  sum(uaux $(OnU(uaux) AND u2f(uaux,faux)), FuelDemand(uaux,faux,mo) * DataFuel(faux,'pris') );
for imo in range(nmo):
    exCostsAuxF = 0.0
    for iff in range(ibegu['uaux'], iendu['uaux']):
        for iu in range(ibegu['uaux'], iendu['uaux']):   # All auxiliary production units.
            exCostsAuxF += vFuelDemand[imo,iu,iff] * fuelprice[iff]
        vCostsAuxF[imo,iff] = m.Intermediate(exCostsAuxF, 'CostsAuxF_' + afbyidx[iff] + '_' + months[imo])

# ZQ_PrioUp(uprio,up,mo) $(OnU(uprio) AND OnU(up) AND AvailDaysU(mo,uprio) AND AvailDaysU(mo,up)) ..  bOnU(up,mo)  =L=  bOnU(uprio,mo); 
eqPrioUp = list()
for imo in range(nmo):
    for up1 in uprio:
        eqn = None
        for up2 in auprod:
            if uprio2up[up1,up2]:
                eqn = m.Equation(vbOnU[up1] <= vbOnU[up2]) 
        if eqn is not None:
            eqPrioUp.append(eqn)

if len(eqPrioUp) > 0:
    allEqns['PrioUp'] = eqPrioUp

# ZQ_TotalAffEprod(mo)  ..  TotalAffEProd(mo)  =E=  Power(mo) + sum(ua $OnU(ua), Q(ua,mo));       # Samlet energioutput fra affaldsanlæg. Bruges til beregning af RGK-rabat.
vTotalAffEProd = np.empty((nmo), dtype=object)
for imo in range(nmo):
    eqTotalAffEprod = power[imo]
    for iu in ua:
        eqTotalAffEprod += vQ[imo,iu]
    vTotalAffEProd[imo] = m.Intermediate(eqTotalAffEprod, name='TotalAffEProd_' + months[imo])

# ZQ_QRgkMiss(mo)       ..  sum(ua $OnU(ua), Qrgk(ua,mo)) + QRgkMiss(mo)  =G=  RgkRabatMinShare * TotalAffEProd(mo);
# ZQ_bOnRgkRabat(mo)    ..  QRgkMiss(mo)  =L=  (1 - bOnRgkRabat(mo)) * QRgkMissMax;
eqQRgkMiss    = np.empty((nmo), dtype=object)
eqbOnRgkRabat = np.empty((nmo), dtype=object)

for imo in range(nmo):
    eqLhsQrgkMiss = 0.0
    for iu in ua:
        eqLhsQrgkMiss += vQ[imo,iu] + vQrgk[imo,iu]
    vQrgkMiss[imo] = m.Intermediate(eqLhsQrgkMiss, name='QrgkMiss_' + months[imo])
    
    eqQRgkMiss[imo]    = m.Equation(vTotalAffEProd[imo] >= rgkRabatMinShare * vTotalAffEProd[imo])
    eqbOnRgkRabat[imo] = m.Equation(vQrgkMiss[imo] <= (1.0 - vbOnRgkRabat[imo]) * QRgkMissMax)
    
allEqns['QRgkMiss'] = eqQRgkMiss
allEqns['bOnRgkRabat'] = eqbOnRgkRabat

# ZQ_RgkRabatMax1(mo) .. RgkRabat(mo)  =L=  RgkRabatMax(mo) * bOnRgkRabat(mo);
# ZQ_RgkRabatMin2(mo) ..  0 * (1 - bOnRgkRabat(mo))                   =L=  RgkRabatSats * CostsATL(mo) - RgkRabat(mo);
# ZQ_RgkRabatMax2(mo) ..  RgkRabatSats * CostsATL(mo) - RGKrabat(mo)  =L=  RgkRabatMax(mo) * (1 - bOnRgkRabat(mo));

eqRgkRabatMax1 = np.empty((nmo), dtype=object)
eqRgkRabatMin2 = np.empty((nmo), dtype=object)
eqRgkRabatMax2 = np.empty((nmo), dtype=object)
for imo in range(nmo):
    eqRgkRabatMax1[imo] = m.Equation( vRgkRabat[imo] <= RgkRabatMax[imo] * vbOnRgkRabat[imo] )
    eqRgkRabatMin2[imo] = m.Equation( 0.0 <= rgkRabatSats * vCostsATL[imo] - vRgkRabat[imo] )
    eqRgkRabatMax2[imo] = m.Equation( rgkRabatSats * vCostsATL[imo] - vRgkRabat[imo]  <=  RgkRabatMax[imo] * (1 - vbOnRgkRabat[imo]) )

allEqns['RgkRabatMax1'] = eqRgkRabatMax1
allEqns['RgkRabatMin2'] = eqRgkRabatMin2
allEqns['RgkRabatMax2'] = eqRgkRabatMax2

# ZQ_Qdemand(mo)              ..  Qdemand(mo)  =E=  sum(up $OnU(up), Q(up,mo)) - Q('cooler',mo) $OnU('cooler');
eqQdemand  = np.empty((nmo),        dtype=object)
for imo in range(nmo):
    eqQdem = 0.0
    if onU['cooler']:
        eqQdem = -vQ[imo,iaunit['cooler']]
    for iu in range(nauprod):
        eqQdem += vQ[imo,iu]
    
    eqQdemand[imo] = m.Equation( eqQdem )
    
allEqns['Qdemand'] = eqQdemand

# ZQ_Qaff(ua,mo)    $OnU(ua)  ..  Q(ua,mo)     =E=  [QaffM(ua,mo) + Qrgk(ua,mo)];
# ZQ_QaffM(ua,mo)   $OnU(ua)  ..  QaffM(ua,mo) =E=  [sum(fa $(OnFF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * EtaQ(ua) * LhvMWh(fa))] $OnU(ua);
# ZQ_Qrgk(ua,mo)    $OnU(ua)  ..  Qrgk(ua,mo)  =L=  KapRgk(ua) / KapNom(ua) * QaffM(ua,mo);  
# ZQ_QrgkMax(ua,mo) $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);  
eqQaff     = np.empty((nmo,nua),    dtype=object)
eqQaffM    = np.empty((nmo,nua),    dtype=object)
eqQrgk     = np.empty((nmo,nua),    dtype=object)
eqQrgkMax  = np.empty((nmo,nua),    dtype=object)
for imo in range(nmo):
    # Waste plant heat balances
    for iua in range(ibegu['ua'], iendu['ua']):
        eqQaff[imo,iua]    = m.Equation( vQ[imo,iua] == vQaffM[imo,iua] + vQrgk[imo,iua] )
        eqQrgk[imo,iua]    = m.Equation( vQrgk[imo,iua] <= kapRgk[iua] / kapNom[iua] * vQaffM[imo,iua])
        eqQrgkMax[imo,iua] = m.Equation( vQrgk[imo,iua] <= kapRgk[iua] / kapNom[iua] * vQaffM[imo,iua])
        rhsEqQaffM = 0.0
        for ifa in range(ibegf['fa'], iendf['fa']):
            if u2f[iua,ifa]:
                rhsEqQaffM += vFuelDemand[imo,iua,ifa] * etaq[iua] * lhvMWf[ifa]
                
        eqQaffM[imo,iua] = m.Equation( vQaffM[imo,iua] == rhsEqQaffM )

allEqns['Qaff']    = eqQaff
allEqns['QaffM']   = eqQaffM
allEqns['Qrgk']    = eqQrgk
allEqns['QrgkMax'] = eqQrgkMax

# ZQ_Qbio(ub,mo)    $OnU(ub)  ..  Q(ub,mo)     =E=  [sum(fb $(OnF(fb) AND u2f(ub,fb)), FuelDemand(ub,fb,mo) * EtaQ(ub) * LhvMWh(fb))]  $OnU(ub);
eqQbio     = np.empty((nmo,nub),    dtype=object)
for imo in range(nmo):
    # Biomass plant heat balances
    for iub in range(ibegu['ub'], iendu['ub']):
        rhsEqQbio = 0.0
        for ifb in range(ibegf['fb'], iendf['fb']):
            if u2f[iub,ifb]:
                rhsEqQbio += vFuelDemand[imo,iub,ifb] * etaq[iub] * lhvMWf[ifb]

        eqQbio[imo,iub] = m.Equation( vQ[imo,iub] == rhsEqQbio )

allEqns['Qbio'] = eqQbio

# ZQ_Qvarme(uc,mo)  $OnU(uc)  ..  Q(uc,mo)     =E=  [sum(fc $(OnF(fc) AND u2f(uc,fc)), FuelDemand(uc,fc,mo))] $OnU(uc);  # Varme er i MWhq, mens øvrige drivmidler er i ton.
eqQvarme   = np.empty((nmo,nuc),    dtype=object)
for imo in range(nmo):
    # External excess heat balances
    for iuc in range(ibegu['uc'], iendu['uc']):
        rhsEqQvarme = 0.0
        for ifc in range(ibegf['fc'], iendf['fc']):
            if u2f[iuc,ifc]:
                rhsEqQvarme += vFuelDemand[imo,iuc,ifc]
                
        eqQvarme[imo,iuc] = m.Equation( vQ[imo,iuc] == rhsEqQvarme )
        
allEqns['Qvarme']   = eqQvarme

# # ZQ_Qpeak(ur,mo) $OnU(ur)  ..  Q(ur,mo)     =E=  [sum(fr $(OnF(fr) AND u2f(ur,fr)), FuelDemand(ur,fr,mo) * EtaQ(ur) * LhvMWh(fr))] $OnU(ur); 
eqQpeak    = np.empty((nmo,nup),    dtype=object)
for imo in range(nmo):
    # Peak boiler heat balances
    for iur in range(ibegu['ur'], iendu['ur']):
        rhsEqQpeak = 0.0
        for ifr in range(ibegf['fr'], iendf['fr']):
            if u2f[iur,ifr]:
                rhsEqQpeak += vFuelDemand[imo,iur,ifr]
                
        eqQpeak[imo,iur] = m.Equation( vQ[imo,iur] == rhsEqQpeak)
        
allEqns['Qpeak']    = eqQpeak    

# ZQ_QMin(u,mo)      $OnU(u)  ..  Q(u,mo)      =G=  ShareAvailU(u,mo) * Hours(mo) * KapMin(u) * bOnU(u,mo);   #  Restriktionen paa timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
# ZQ_QMax(u,mo)      $OnU(u)  ..  Q(u,mo)      =L=  ShareAvailU(u,mo) * Hours(mo) * KapMax(u) * bOnU(u,mo);  
eqQMin = np.empty((nmo,naunit), dtype=object)
eqQMax = np.empty((nmo,naunit), dtype=object)
for imo in range(nmo):
    for iu in range(naunit):
        eqQMin[imo,iu] = m.Equation( vQ[imo,iua] >= shareAvailU[imo,iu] * hours[imo] * kapMin[iu] * vbOnU[imo,iu] )
        eqQMax[imo,iu] = m.Equation( vQ[imo,iua] <= shareAvailU[imo,iu] * hours[imo] * kapMax[iu] * vbOnU[imo,iu] )
allEqns['QMin'] = eqQMin
allEqns['QMax'] = eqQMax

# ZQ_QaffMmax(ua,mo) $OnU(ua) ..  QAffM(ua,mo)    =L=  QaffMmax(ua,mo);
# ZQ_bOnRgk(ua,mo)   $OnU(ua) ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);  
# ZQ_CoolMax(mo)              ..  Q('cooler',mo)  =L=  sum(ua $OnU(ua), Q(ua,mo));
eqQaffMmax = np.empty((nmo,nua), dtype=object)
eqQCoolMax = np.empty((nmo),     dtype=object)
eqbOnRgk   = np.empty((nmo,nua), dtype=object)
for imo in range(nmo):
    eqLhsCoolMax = 0.0
    for iu in range(ibegu['ua'], iendu['ua']):
        eqQaffMmax[imo,iu] = m.Equation( vQrgk[imo,iu]  <= QrgkMax[imo,iu] * vbOnRgk[imo,iu] )
        eqbOnRgk[imo,iu]   = m.Equation( vQaffM[imo,iu] <= QaffMmax[imo,iu] )
        eqLhsCoolMax       += vQ[imo,iacooler]
    if onU['cooler']:
        eqQCoolMax[imo] = m.Equation( vQ[imo,iacooler] <= shareAvailU[imo,iacooler] * hours[imo] * kapMax[iacooler] )
    
allEqns['QaffMMax'] = eqQaffMmax 
allEqns['bOnRgk']   = eqbOnRgk
if onU['cooler']:
	allEqns['QCoolMax'] = eqQCoolMax 


# ZQ_FuelMin(f,mo) $(OnF(f) AND NOT fsto(f) AND NOT ffri(f) AND fdis(f))  ..  sum(u $(OnU(u)  AND u2f(u,f)),  FuelDemand(u,f,mo))   =G=  FuelBounds(f,'min',mo);
eqFuelMin = np.empty((nmo,nua), dtype=object)
for imo in range(nmo):
    rhsMin = 0.0
    lhsMin = 0.0
    for ifa in range(ibegf['fa'], iendf['fa']):
        f = afuels[f]
        if f not in fsto and f not in ffri and f in fdis:
            rhsMin += dfFuelMin.iloc[ifa,imo] 
            for iua in range(ibegu['ua'], iendu['ua']):
                if u2f[iua,ifa]:
                    lhsMin += vFuelDemand[imo,iua,ifa] 
        if lhsMin != 0.0:
            eqFuelMin[imo,ifa] = m.Equation( lhsMin == rhsMin )
            
allEqns['FuelMin'] = eqFuelMin

# ZQ_FuelMax(f,mo) $(OnF(f) AND fdis(f)) ..  sum(u $(OnU(u)  AND u2f(u,f)),  FuelDemand(u,f,mo))   =L=  FuelBounds(f,'max',mo) * 1.0001;  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.
eqFuelMax = np.empty((nmo,nua), dtype=object)
for imo in range(nmo):
    rhsMax = 0.0
    lhsMax = 0.0
    for ifa in range(ibegf['fa'], iendf['fa']):
        f = afuels[f]
        if f in fdis:
            rhsMax += dfFuelMax.iloc[ifa,imo] * (1.0001) 
            for iua in range(ibegu['ua'], iendu['ua']):
                if u2f[iua,ifa]:
                    lhsMax += vFuelDemand[imo,iua,ifa] 
        if lhsMax != 0.0:
            eqFuelMax[imo,ifa] = m.Equation( lhsMax == rhsMax )
            
allEqns['FuelMax'] = eqFuelMax

# ZQ_FuelMinYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDemand(u,fdis,mo)))  =G=  MinTonnageAar(fdis) * card(mo) / 12;
# ZQ_FuelMaxYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDemand(u,fdis,mo)))  =L=  MaxTonnageAar(fdis) * card(mo) / 12;
nfdis = len(fdis)
if nfdis > 0:
    eqFuelMinYear = np.empty(nfdis, dtype=object) 
    eqFuelMaxYear = np.empty(nfdis, dtype=object) 
    ifdis = -1
    for iff in range(nafuel):
        f = afuels[iff]
        if f in fdis:
            ifdis += 1 
            lhs = 0.0
            for imo in range(nmo):
                for iua in range(nauprod):
                    if u2f(iu,iff):
                        lhs += vFuelDemand[imo,ifdis,iu]
                        
            eqFuelMinYear[ifdis] = m.Equation( lhs >= minTonnage[ifdis] * nmo / 12 )
            eqFuelMaxYear[ifdis] = m.Equation( lhs <= maxTonnage[ifdis] * nmo / 12 )
                
allEqns['FuelMinYear'] = eqFuelMinYear
allEqns['FuelMaxYear'] = eqFuelMaxYear
        

# ZQ_FuelDemandFreeSum(ffri) $(OnF(ffri) AND card(mo) GT 1)  .. FuelDemandFreeSum(ffri)  =E=  sum(mo, sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDemand(ua,ffri,mo) ) );
# ZQ_FuelMinFreeNonStorable(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri) AND card(mo) GT 1) ..  sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDemand(ua,ffri,mo))  =E=  FuelDemandFreeSum(ffri) / card(mo);
nffri = len(ffri) 
eqFuelDemandFreeSum = np.empty((nffri), dtype=object)
for iffri, f in enumerate(ffri):
    if nmo >= 2:
        rhs = 0.0
        rhsSto = 0.0
        for iua in range(ibegu['ua'], iendu['ua']):
            if u2f[iua,iffri]:
                for imo in range(nmo):
                    rhs += vFuelDemand[imo,iua,iffri] 

        if rhs != 0.0:
            eqFuelDemandFreeSum[iffri] = m.Equation( vFuelDemandFreeSum[iffri] == rhs)
            
if len(eqFuelDemandFreeSum) > 0:
    allEqns['FuelDemandFreeSum'] = eqFuelDemandFreeSum

vFuelDemandFreeSum = m.Array(m.Var, (nmo), lb=0.0)

# ZQ_MaxTonnage(ua,mo) $OnU(ua) .. sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * KapTon(ua);
eqMaxTonnage = np.empty((nmo,nua), dtype=object)
for imo in range(nmo):
    for iua in range(ibegu['ua'], iendu['ua']):
        lhs = 0.0
        for ifa in range(ibegf['fa'], iendf['fa']):
            if u2f[iua,ifa]:
                lhs += vFuelDemand[imo,iua,ifa] 
        if lhs != 0.0:
            rhs = shareAvailU[imo,iua] * hours[imo] * kapTon[iua]
            eqMaxTonnage[imo,iua] = m.Equation( lhs <= rhs )

if len(eqMaxTonnage) > 0:            
    allEqns['MaxTonnage'] = eqMaxTonnage

# ZQ_MinLhvAffald(ua,mo) $OnU(ua)  ..  MinLhvMWh(ua) * sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo))  =L=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * LhvMWh(fa));
eqMinLhvAffald = np.empty((nmo,nua), dtype=object)
for imo in range(nmo):
    for iua in range(ibegu['ua'], iendu['ua']):
        lhs = 0.0
        rhs = 0.0
        for ifa in range(ibegf['fa'], iendf['fa']):
            if u2f[iua,ifa]:
                lhs += vFuelDemand[imo,iua,ifa] 
                rhs += vFuelDemand[imo,iua,ifa] * lhvMWf[ifa]
        if lhs != 0.0:
            lhs *= MinLhvMWh[iua]
            rhs = shareAvailU[imo,iua] * hours[imo] * kapTon[iua]
            eqMinLhvAffald[imo,iua] = m.Equation( lhs <= rhs )

if len(eqMinLhvAffald) > 0:            
    allEqns['MinLhvAffald'] = eqMinLhvAffald


#----------------------------------------------------------------------------------------------------
#%% Solving the model
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
