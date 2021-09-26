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
dfAvailU : pd.DataFrame
dfDataU  = sh.range('B4').options(pd.DataFrame, index=True, header=True, expand='table').value
#--- dfDataU  = sh.range('B4:D6').options(pd.DataFrame, index=True, header=True).value
dfProgn  = sh.range('B15').options(pd.DataFrame, index=True, header=True, expand='table').value
dfAvailU = sh.range('B31').options(pd.DataFrame, index=True, header=True, expand='table').value

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

# Define lookup list and dicts.
months = ['jan','feb','mar','apr','maj','jun','jul','aug','sep','okt','nov','dec']
months = ['jan','feb']
nmo = len(months)

ukinds = {'affald':1, 'biomasse':2, 'varme':3, 'peak':4, 'cooler':5}
fkinds = {'affald':1, 'biomasse':2, 'varme':3}

# Priority scheme of production units.
uprio = ['ovn3', 'NS']


# Plant units
units = dfDataU.index
nunit = len(units)
onU = dfDataU['aktiv'] != 0
aunits = [u for u in units if onU[u]]
naunit = len(aunits)
uReverse = [i for i,on in enumerate(onU) if on]  # Absolute index of active units.
auprod = [u for u in units if onU[u] and dfDataU.loc[u,'ukind'] != ukinds['cooler']]
nauprod = len(auprod)

aulookup = dict()  # key is unit name, value is active index
aulookup = [{au,i} for i, au in enumerate(aunits)]
     
# All parameters shall refer to active entities.
kapTon = dfDataU['kapTon'][onU == True]
kapNom = dfDataU['kapNom'][onU == True]
kapRgk = dfDataU['kapRgk'][onU == True]
kapMin = dfDataU['kapMin'][onU == True]
kapMax = kapNom + kapRgk
etaq = dfDataU['etaq'][onU == True]
costDV = dfDataU['DV'][onU == True]
costAux = dfDataU['aux'][onU == True]

# Prognoses
days = dfProgn['ndage']
qdem = dfProgn['varmebehov']
power = dfProgn['ELprod']
taxEts = dfProgn['ets']
taxAfvMWh = dfProgn['afv'] / 3.6
taxAtlMWh = dfProgn['atl'] / 3.6


# Fuels
fuels = dfDataFuel.index
nfuel = len(fuels)
onF = dfDataFuel['aktiv'] != 0
afuels = [f for f in fuels if onF[f]]
nafuel = len(afuels)
fReverse = [i for i,on in enumerate(onF) if on]  # Absolute index of active fuels.

fkind = dfDataFuel['fkind'][onF == True]
storable = (dfDataFuel['lagerbart'] != 0)[onF == True]
tonnage = dfDataFuel['tonnage'][onF == True]
fuelprice = dfDataFuel['pris'][onF == True]
lhvMWf = dfDataFuel['brandv'][onF == True] / 3.6
shareCo2 = dfDataFuel['co2andel'][onF == True]
#---------------------------------------------------------------------------

#%% TEST begin

# dropunits = [u for u in units if u not in aunits]
# dropfuels = [f for f in fuels if f not in afuels]
# dd = dfFuelBounds[dfFuelBounds['Bound']=='max']
# dd2 = dd.drop(dropfuels, inplace=False).drop(columns='Bound')
#---------------------------------------------------------------------------

#%% TEST end

dropunits = [u for u in units if u not in aunits]
dropfuels = [f for f in fuels if f not in afuels]

# dfFuelBounds shall be converted into 2 dataframes.
dfFuelMax = (dfFuelBounds[dfFuelBounds['Bound']=='max']).drop(dropfuels, inplace=False).drop(columns='Bound')
dfFuelMin = (dfFuelBounds[dfFuelBounds['Bound']=='min']).drop(dropfuels, inplace=False).drop(columns='Bound')

# Setup lookup tables.

ua = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['affald']  ].index if onU[uu]]
ub = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['biomasse']].index if onU[uu]]
uc = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['varme']   ].index if onU[uu]]
up = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['peak']    ].index if onU[uu]]
uv = [uu for uu in dfDataU[dfDataU['ukind'] == ukinds['cooler']  ].index if onU[uu]]
nua = len(ua); nub = len(ub); nuc = len(uc); nup = len(uv); nuv = len(uv)

fa = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['affald']  ].index if onF[ff]]
fb = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['biomasse']].index if onF[ff]]
fc = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['varme']   ].index if onF[ff]]
nfa = len(fa); nfb = len(fb); nfc = len(fc)

u2f = pd.DataFrame(index=auprod, columns=afuels, dtype=bool)
for u in auprod:
    for f in afuels:
        u2f.at[u,f] = (u in ua and f in fa) or (u in ub and f in fb) or (u in uc and f in fc)

# Convert data frames to arrays and include only active entities.
aunit = [{i:u} for i,u in enumerate(aunits)]
afuel = [{i:f} for i,f in enumerate(afuels)]
print(u2f)
u2f = u2f.to_numpy()

ibegu = {'ua':0, 'ub':nua, 'uc':nua + nub, 'up':nua + nub + nuc}
ibegf = {'fa':0, 'fb':nfa, 'fc':nfa + nfb}
iendu = {'ua':nua, 'ub':nua + nub, 'uc':nua + nub + nuc, 'up': nua + nub + nuc + nup} 
iendf = {'fa':nfa, 'fb':nfa + nfb, 'fc':nfa + nfb + nfc} 

# Availabilities
hours = days * 24
shareAvailU = np.zeros(shape=(nmo,naunit), dtype=float)
for imo, mo in enumerate(months):
    for iu, u in enumerate(aunits):
        # shareAvailU[imo,iu] = max(0.0, min(1.0, dfAvailU.at[mo,u] / days[mo]) )
        shareAvailU[imo,iu] = dfAvailU.at[mo,u] / days[mo]

print('Counters and lookups are defined.')
#--------------------------------------------------------------------------------------
#%% Compute parameters

rgkRabatMinShare = 0.07
rgkRabatSats = 0.10

# QaffMmax(ua,mo)  = min(ShareAvailU(ua,mo) * Hours(mo) * KapNom(ua), 
#                       [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelBounds(fa,'max',mo) * EtaQ(ua) * LhvMWh(fa))]) $OnU(ua);
# QrgkMax(ua,mo)   = KapRgk(ua) / KapNom(ua) * QaffMmax(ua,mo);
# QaffTotalMax(mo) = sum(ua $OnU(ua), ShareAvailU(ua,mo) * (QaffMmax(ua,mo) + QrgkMax(ua,mo)) );
# EaffGross(mo)    = QaffTotalMax(mo) + Power(mo);
# CostsATLMax(mo) = sum(ua $OnU(ua), ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua)) * TaxAtlMWh(mo);
# RgkRabatMax(mo) = RgkRabatSats * CostsATLMax(mo);
# QRgkMissMax = 2 * RgkRabatMinShare * sum(ua $OnU(ua), 31 * 24 * KapNom(ua));  # Faktoren 2 er en sikkerhedsfaktor mod inffeasibilitet.

QaffMmax     = np.zeros((nmo,nua), dtype=float)
QrgkMax      = np.zeros((nmo,nua), dtype=float)
QaffTotalMax = np.zeros((nmo), dtype=float)
EaffGross    = np.zeros((nmo), dtype=float)
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
# Results for non-active entities hence default to zero.

NPV = m.Var('NPV')  # Objective variable.

# Fundamental decision variables.
vbOnU        = m.Array(m.Var, (nmo, nauprod), integer=True)
vbOnRgk      = m.Array(m.Var, (nmo, nua),     integer=True)
vbOnRgkRabat = m.Array(m.Var, (nmo, nua),     integer=True)

# FuelDemand(mo,u,f):
vFuelDemand = m.Array(m.Var, (nmo, nauprod, nafuel), lb=0.0)

vQ        = m.Array(m.Var, (nmo, nauprod), lb=0.0)
vQrgkMiss = m.Array(m.Var, (nmo),          lb=0.0)
vQafv     = m.Array(m.Var, (nmo),          lb=0.0)
vQrgk     = m.Array(m.Var, (nmo, nua),     lb=0.0)
vQaffM    = m.Array(m.Var, (nmo, nua),     lb=0.0)

vRgkRabat      = m.Array(m.Var, (nmo),     lb=0.0)
vTotalAffEProd = m.Array(m.Var, (nmo),     lb=0.0)

# Intermediate variable (assigned below)
# vIncomeTotal   = m.Array(m.Var, (nmo),          lb=0.0)
# vIncomeF       = m.Array(m.Var, (nmo, nafuel))
# vCostsU        = m.Array(m.Var, (nmo, nauprod), lb=0.0)
# vCostsTotalF   = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsAFV      = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsATL      = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsETS      = m.Array(m.Var, (nmo),          lb=0.0)
# vCO2emis       = m.Array(m.Var, (nmo, nafuel),  lb=0.0)

# Intermediate variable will be stored in ndarrays.
vIncomeTotal   = np.empty((nmo),          object) 
vIncomeF       = np.empty((nmo, nafuel),  object)
vCostsU        = np.empty((nmo, nauprod), object)
vCostsTotalF   = np.empty((nmo),          object)
vCostsAFV      = np.empty((nmo),          object)
vCostsATL      = np.empty((nmo),          object)
vCostsETS      = np.empty((nmo),          object)
vCO2emis       = np.empty((nmo, nafuel),  object)

print('Variables are defined')
#--------------------------------------------------------------------------------------
#%% Create equations.

pPenalty_bOnU     = m.Param(value=1E+3)
pPenalty_QrgkMiss = m.Param(value=20.0)

allEqns = dict()

objective = np.sum(vIncomeTotal) - np.sum(vCostsU) - np.sum(vCostsTotalF) \
            - pPenalty_bOnU * np.sum(vbOnU) - pPenalty_QrgkMiss * np.sum(vQrgkMiss) 
m.Obj(objective)
allEqns['Objective'] = objective

# ZQ_IncomeTotal(mo) .. IncomeTotal(mo)  =E=  sum(f $OnF(f), IncomeF(f,mo)) + RgkRabat(mo);
# ZQ_CostsTotalF(mo) .. CostsTotalF(mo)  =E=  CostsAFV(mo) + CostsATL(mo) + CostsETS(mo);
# ZQ_CostsAFV(mo)    .. CostsAFV(mo)     =E=  Qafv(mo) * TaxAfvMWh(mo);
# ZQ_CostsATL(mo)    .. CostsATL(mo)     =E=  sum(ua $OnU(ua), Q(ua,mo)) * TaxAtlMWh(mo);
# ZQ_CostsETS(mo)    .. CostsETS(mo)     =E=  sum(f $OnF(f), CO2emis(f,mo)) * TaxEtsTon(mo);
# ZQ_Qafv(mo)              .. Qafv(mo)         =E=  sum(ua $OnU(ua), Q(ua,mo)) - Q('cooler',mo);   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.
# ZQ_CO2emis(f,mo) $OnF(f) .. CO2emis(f,mo)    =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelDemand(up,f,mo)) * DataFuel(f,'co2andel');  
# ZQ_IncomeF(f,mo) $OnF(f) .. IncomeF(f,mo)    =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelDemand(up,f,mo) * DataFuel(f,'pris')) $OnF(f);
# ZQ_CostsU(u,mo) $OnU(u)  .. CostsU(u,mo)     =E=  Q(u,mo) * (DataU(u,'dv') + DataU(u,'aux') ) $OnU(u);

for imo in range(nmo):
    vCostsTotalF[imo] = m.Intermediate( vCostsAFV[imo] + vCostsATL[imo] + vCostsETS[imo], 'CostsTotalF_' + months[imo])
    vCostsAFV[imo]    = m.Intermediate(vQafv[imo] * taxAfvMWh[imo], 'CostsTotalF_' + months[imo])
    eqIncomeTotal = vRgkRabat[imo]
    eqQAfv = 0.0 if not onU['cooler'] else -vQ[imo,aulookup['cooler']]
    for iff in range(nafuel):
        eqIncomeTotal += vIncomeF[imo,iff]
        eqCostsETS    += vCO2emis[imo,iff] * taxEts[imo]

        eqCO2emis = 0.0
        eqIncomeF = 0.0
        for iu in range(ibegu['ua'], iendu['uc']):   # All production units
            eqCO2emis += vFuelDemand[imo,iu,iff] * shareCo2[iff]
            eqIncomeF += vFuelDemand[imo,iu,iff] * fuelprice[iff]
        vCO2emis[imo,iff] = m.Intermediate(eqCO2emis, 'CO2emis_' + afuel[iff] + '_' + months[imo])
        vIncomeF[imo,iff] = m.Intermediate(eqIncomeF, 'IncomeF_' + afuel[iff] + '_' + months[imo])
    
    eqCostsETS = 0.0
    eqCostsATL = 0.0
    for iu in range(ibegu['ua'], iendu['ua']):
        eqCostsATL += vQ[imo,iu] * taxAtlMWh[imo]
        eqQAfv     += vQ[imo,iu] 

    for iu in range(naunit):
        vCostsU = m.Intermediate(vQ[imo,iu] * (costDV[iu] + costAux[iu]))

    vIncomeTotal[imo] = m.Intermediate(eqIncomeTotal, 'IncomeTotal_' + months[imo])
    vCostsETS[imo]    = m.Intermediate(eqCostsETS,    'CostsETS'     + months[imo])
    vCostsATL[imo]    = m.Intermediate(eqCostsATL,    'CostsATL'     + months[imo])
    vQafv[imo]        = m.Intermediate(eqQAfv,        'Qafv'         + months[imo])

# ZQ_PrioUp(uprio,up,mo) $(OnU(uprio) AND OnU(up) AND AvailDaysU(mo,uprio) AND AvailDaysU(mo,up)) ..  bOnU(up,mo)  =L=  bOnU(uprio,mo); 
eqPrioUp = list()
for imo in range(nmo):
    #TODO: use correct indices to active entities.
    for up1 in uprio:
        if onU[up1]:
            for up2 in auprod:
                if onU[up2]:
                    eqn = m.Equation(vbOnU[up1] <= vbOnU[up2]) 
                    eqPrioUp.append(eqn)
allEqns['PrioUp'] = eqPrioUp

# ZQ_TotalAffEprod(mo)  ..  TotalAffEProd(mo)  =E=  Power(mo) + sum(ua $OnU(ua), Q(ua,mo));       # Samlet energioutput fra affaldsanlæg. Bruges til beregning af RGK-rabat.
# ZQ_QRgkMiss(mo)       ..  sum(ua $OnU(ua), Qrgk(ua,mo)) + QRgkMiss(mo)  =G=  RgkRabatMinShare * TotalAffEProd(mo);
# ZQ_bOnRgkRabat(mo)    ..  QRgkMiss(mo)  =L=  (1 - bOnRgkRabat(mo)) * QRgkMissMax;

vTotalAffEProd = np.empty((nmo), dtype=object)
eqQRgkMiss     = np.empty((nmo), dtype=object)
eqbOnRgkRabat  = np.empty((nmo), dtype=object)
for imo in nmo:
    eqTotalAffEprod = power[imo]
    eqLhsQrgkMiss = 0.0
    for iu in ua:
        eqTotalAffEprod += vQ[imo,iu]
        eqLhsQrgkMiss   += vQ[imo,iu] + vQrgk[imo,iu]
    
    vTotalAffEProd[imo] = m.Intermediate( eqTotalAffEprod, name='TotalAffEProd_' + months[imo] )
    eqQRgkMiss[imo]     = m.Equation( vTotalAffEProd[imo] >= rgkRabatMinShare * vTotalAffEProd[imo] )
    eqbOnRgkRabat[imo]  = m.Equation( vQrgkMiss[imo] <= (1.0 - vbOnRgkRabat[imo]) * QRgkMissMax )

# ZQ_RgkRabatMax1(mo) .. RgkRabat(mo)  =L=  RgkRabatMax(mo) * bOnRgkRabat(mo);
# ZQ_RgkRabatMin2(mo) ..  0 * (1 - bOnRgkRabat(mo))                   =L=  RgkRabatSats * CostsATL(mo) - RgkRabat(mo);
# ZQ_RgkRabatMax2(mo) ..  RgkRabatSats * CostsATL(mo) - RGKrabat(mo)  =L=  RgkRabatMax(mo) * (1 - bOnRgkRabat(mo));

eqRgkRabatMax1 = np.empty((nmo), dtype=object)
eqRgkRabatMin2 = np.empty((nmo), dtype=object)
eqRgkRabatMax2 = np.empty((nmo), dtype=object)
for imo in nmo:
    eqRgkRabatMax1[imo] = m.Equation( vRgkRabat[imo] <= RgkRabatMax[imo] * vbOnRgkRabat[imo] )
    eqRgkRabatMin2[imo] = m.Equation( 0.0 <= rgkRabatSats * vCostsATL[imo] - vRgkRabat[imo] )
    eqRgkRabatMax2[imo] = m.Equation( rgkRabatSats * vCostsATL[imo] - vRgkRabat[imo]  <=  RgkRabatMax[imo] * (1 - vbOnRgkRabat[imo]) )

allEqns['RgkRabatMax1'] = eqRgkRabatMax1
allEqns['RgkRabatMin2'] = eqRgkRabatMin2
allEqns['RgkRabatMax2'] = eqRgkRabatMax2

# ZQ_Qdemand(mo)              ..  Qdemand(mo)  =E=  sum(up $OnU(up), Q(up,mo)) - Q('cooler',mo) $OnU('cooler');
# ZQ_Qaff(ua,mo)    $OnU(ua)  ..  Q(ua,mo)     =E=  [QaffM(ua,mo) + Qrgk(ua,mo)];
# ZQ_QaffM(ua,mo)   $OnU(ua)  ..  QaffM(ua,mo) =E=  [sum(fa $(OnFF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * EtaQ(ua) * LhvMWh(fa))] $OnU(ua);
# ZQ_Qbio(ub,mo)    $OnU(ub)  ..  Q(ub,mo)     =E=  [sum(fb $(OnF(fb) AND u2f(ub,fb)), FuelDemand(ub,fb,mo) * EtaQ(ub) * LhvMWh(fb))]  $OnU(ub);
# ZQ_Qvarme(uc,mo)  $OnU(uc)  ..  Q(uc,mo)     =E=  [sum(fc $(OnF(fc) AND u2f(uc,fc)), FuelDemand(uc,fc,mo))] $OnU(uc);  # Varme er i MWhq, mens øvrige drivmidler er i ton.
# ZQ_Qrgk(ua,mo)    $OnU(ua)  ..  Qrgk(ua,mo)  =L=  KapRgk(ua) / KapNom(ua) * QaffM(ua,mo);  
# ZQ_QrgkMax(ua,mo) $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);  
# ZQ_QMin(u,mo)     $OnU(u)   ..  Q(u,mo)      =G=  ShareAvailU(u,mo) * Hours(mo) * KapMin(u) * bOnU(u,mo);

# Heat balance equations.
eqQdemand = np.empty((nmo), dtype=object)
eqQaff    = np.empty((nmo,nua), dtype=object)
eqQaffM   = np.empty((nmo,nua), dtype=object)
eqQbio    = np.empty((nmo,nub), dtype=object)
eqQvarme  = np.empty((nmo,nuc), dtype=object)
eqQrgk    = np.empty((nmo,nua), dtype=object)
eqQrgkMax = np.empty((nmo,nua), dtype=object)
eqQMin    = np.empty((nmo,naunit), dtype=object)

for imo in nmo:
    eqQdem = -vQ[imo,indexau['cooler']] if onU['cooler'] else 0.0
    for iu in range(nauprod):
        eqQdem += vQ[imo,iu]
    eqQdemand[imo] = m.Equation( eqQdem )

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

    # Biomass plant heat balances
    for iub in range(ibegu['ub'], iendu['ub']):
        rhsEqQbio = 0.0
        for ifb in range(ibegf['fb'], iendf['fb']):
            if u2f[iub,ifb]:
                rhsEqQbio += vFuelDemand[imo,iub,ifb] * etaq[iub] * lhvMWf[ifb]
        eqQbio[imo,iub] = m.Equation( vQ[imo,iub] == rhsEqQbio )

    # External excess heat balances
    for iuc in range(ibegu['uc'], iendu['uc']):
        rhsEqQvarme = 0.0
        for ifc in range(ibegf['fc'], iendf['fc']):
            if u2f[iuc,ifc]:
                rhsEqQvarme += vFuelDemand[imo,iuc,ifc]
        eqQvarme[imo,iub] = m.Equation( vQ[imo,iuc] == rhsEqQvarme )

    # All units
    for iu in range(nauprod):
        eqQMin[imo,iu] = m.Equation( vQ[imo,iua] >= shareAvailU[imo,iu] * hours[imo] * kapMin[iu] * vbOnU[imo,iu] )


allEqns['Qdemand'] = eqQdemand
allEqns['Qaff']    = eqQaff
allEqns['QaffM']   = eqQaffM
allEqns['Qbio']    = eqQbio
allEqns['Qvarme']  = eqQvarme
allEqns['Qrgk']    = eqQrgk
allEqns['QrgkMax'] = eqQrgkMax
allEqns['QMin']    = eqQMin

# All waste must be removed within a year.
# ZQ_AffUseYear(fa) $OnF(fa) ..  sum(mo, sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelDemand(ua,fa,mo)))  =E=  sum(mo, FuelBounds(fa,'max',mo));
eqAffUseYear = list()
for ifa in range(ibegf['fa'], iendf['fa']):
    rhs = 0.0
    lhs = 0.0
    for imo in range(nmo):
        rhs += dfFuelMax.iloc[ifa,imo] 
        for iua in range(ibegu['ua'], iendu['ua']):
            lhs += vFuelDemand[imo,iua,ifa] 
    eqn = m.Equation(lhs == rhs)
    eqAffUseYear.append(eqn)
if len(eqAffUseYear) > 0:
    allEqns['AffUseYear'] = eqAffUseYear

# Any fuel may have limits within each month.
# ZQ_FuelMin(f,mo) $OnF(f) .. sum(u  $(OnU(u)  AND u2f(u,f)),   FuelDemand(u,f,mo))     =G=  FuelBounds(f,'min',mo);
for iff in range(0, nafuel):
    eqFuelMin = list()
    for imo in range(nmo):
        rhs = dfFuelMin.iloc[iff,imo]
        if rhs > 0.0:  # Only lower bounds GT zero are relevant as vFuelDemand is non-negative.
            lhs = 0.0
            for iu in range(0, iendu['uc']):
                if u2f[iu,iff]: 
                    lhs += vFuelDemand[imo,iu,iff] 
            eqn = m.Equation(lhs >= rhs)
            eqFuelMin.append(eqn)
    if len(eqFuelMin) > 0:
        allEqns['FuelMin_' + afuels[iff]] = eqFuelMin

# All biomass consumption may be subject to an annual upper bound.
# ZQ_BioUseYear(fb) $OnF(fb) ..  sum(mo, sum(ub $(OnU(ub) AND u2f(ub,fb)), FuelDemand(ub,fb,mo)))  =L=  sum(mo, FuelBounds(fb,'max',mo));
eqBioUseYear = list()
for ifb in range(ibegf['fb'], iendf['fb']):
    rhs = 0.0
    lhs = 0.0
    for imo in range(nmo):
        rhs += dfFuelMax.iloc[ifb,imo] 
        for iub in range(ibegu['ub'], iendu['ub']):
            lhs += vFuelDemand[imo,iub,ifb] 
    eqn = m.Equation(lhs <= rhs)
    eqBioUseYear.append(eqn)
if len(eqBioUseYear) > 0:
    allEqns['BioUseYear'] = eqBioUseYear

# All externally supplied heat must be consumed within a year.
# ZQ_OVUseYear(fc)  $OnF(fc) ..  sum(mo, sum(uc $(OnU(uc) AND u2f(uc,fc)), FuelDemand(uc,fc,mo)))  =E=  sum(mo, FuelBounds(fc,'max',mo));
eqOVUseYear = list()
for ifc in range(ibegf['fc'], iendf['fc']):
    rhs = 0.0
    lhs = 0.0
    for imo in range(nmo):
        rhs += dfFuelMax.iloc[ifc,imo] 
        for iuc in range(ibegu['uc'], iendu['uc']):
            lhs += vFuelDemand[imo,iuc,ifc] 
    eqn = m.Equation(lhs == rhs)
    eqOVUseYear.append(eqn)
if len(eqOVUseYear) > 0:
    allEqns['OVUseYear'] = eqOVUseYear

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
