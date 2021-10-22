# %% Imports 
#region Imports and basic setup
import enum
import os
import io
import logging as logn
import math
import numpy as np
import pandas as pd 
import xlwings as xw
import matplotlib.pyplot as plt
import gekko as gk
from array import array
from gekko import GEKKO

# Setup logger(s): Levels are: DEBUG, INFO, WARNING, ERROR, CRITICAL. See https://realpython.com/python-logging/
logn.basicConfig(level=logn.DEBUG, filename='RefaMain.log', filemode='w',
                 format='%(asctime)s : %(levelname)s : %(message)s', datefmt='%y-%b-%d %H.%M.%S')
"""
Example of logging an exception:
a =5; b = 0;
try:
  c = a / b
except Exception as e:
  logging.error("Exception occurred", exc_info=True)
  
OR simply:
logging.exception("Exception occurred")
"""
#endregion -------------------------------------------------------------------

# %% Read input from Excel fil REFAinput.xlsb  

#region Define periods.

allMonths = ['jan','feb','mar','apr','maj','jun','jul','aug','sep','okt','nov','dec']
months = ['jan','feb','mar','apr','maj','jun','jul','aug','sep','okt','nov','dec']
#TODO Shortlisting months for debugging purposes.
months = ['jan','feb']
nmo = len(months)
dropMonths = [mo for mo in allMonths if not mo in months]
# Create index for active months. ixmo[imo] yields index for an active month in all months.
ixmo = np.empty((nmo), dtype=int)
for imo, mo in enumerate(months):
    ixmo[imo] = allMonths.index(mo)

#endregion 

#region Read input

pathfolder = r'C:\\GitHub\\REFA Affald\\Excel'
filename = r'REFAinputX.xlsm'
path = os.path.join(pathfolder, filename)
wb = xw.Book(path)
sh = wb.sheets['ModelParms']
dfModelParms:pd.DataFrame = sh.range('B4').options(pd.DataFrame, index=True, header=True, expand='table').value
sh = wb.sheets['DataU']
dfAllDataUnit:pd.DataFrame  = sh.range('B4').options(pd.DataFrame, index=True, header=True, expand='table').value
dfAllProgn:pd.DataFrame  = sh.range('B15').options(pd.DataFrame, index=True, header=True, expand='table').value
dfAllAvailU:pd.DataFrame = sh.range('B31').options(pd.DataFrame, index=True, header=True, expand='table').value
sh = wb.sheets['Fuel']
dfAllDataFuel:pd.DataFrame   = sh.range('C4').options(pd.DataFrame, index=True, header=True, expand='table').value
dfAllFuelBounds:pd.DataFrame = sh.range('R4').options(pd.DataFrame, index=True, header=True, expand='table').value

print('Input data imported.')

#region Filter out inactive entities

gunits = {u:iu for iu,u in enumerate(dfAllDataUnit.index)}  # Key:Value is unitname:index
gfuels = {f:i for i,f in enumerate(dfAllDataFuel.index)}    # Key:Value is fuelname:index
onU = dfAllDataUnit['aktiv'] != 0
onF = dfAllDataFuel['aktiv'] != 0
units = {u:iu for iu,u in enumerate(gunits.keys()) if onU[u]}  # Key:Value is unitname:globalindex
fuels = {f:i for i,f in enumerate(gfuels.keys()) if onF[f]}    # Key:Value is fuelname:globalindex
dropUnits = [u for u in gunits if u not in units]
dropFuels = [f for f in gfuels if f not in fuels]

dfDataUnit:pd.DataFrame = dfAllDataUnit.drop(index=dropUnits)
dfAvailU:pd.DataFrame   = dfAllAvailU.drop(index=dropMonths)
dfProgn:pd.DataFrame    = dfAllProgn.drop(index=['SUM'] + dropMonths)
dfDataFuel:pd.DataFrame = dfAllDataFuel.drop(index=dropFuels)

# Convert dfFuelBounds into 2 dataframes for ease of access.
dfFuelBounds:pd.DataFrame = dfAllFuelBounds.drop(index=dropFuels, columns=dropMonths)
dfFuelMin:pd.DataFrame = (dfFuelBounds[dfFuelBounds['Bound']=='min']).drop(columns=['Bound'])
dfFuelMax:pd.DataFrame = (dfFuelBounds[dfFuelBounds['Bound']=='max']).drop(columns=['Bound'])

FuelMin = dfFuelMin.to_numpy()
FuelMax = dfFuelMax.to_numpy()

#endregion 

# Example: extracting certain rows
#--- [x for x in dfFuelBounds['Fraktion'] if x.startswith('Dagren')]
# rowsdag = [x.startswith('Dag') for x in dfFuelBounds['Fraktion'] ]
# dfDummy = dfFuelBounds[rowsdag]
#endregion 
#---------------------------------------------------------------------------

#%% Extract comfortable arrays from dataframes.

#region Extract comfortable arrays from dataframes.

ukinds = {'affald':1, 'biomasse':2, 'varme':3, 'peak':4, 'cooler':5}
fkinds = {'affald':1, 'biomasse':2, 'varme':3, 'peak':4}

#region Plant units.
uprod  = [u for u in gunits if onU[u] and dfDataUnit.loc[u,'ukind'] != ukinds['cooler']]
nuprod = len(uprod)

# Mapping from active to global unit index and reverse.
# Prefix 'g' indicates a global entity.
ngunit = len(gunits)
nunit  = len(units)

iu2igu = np.ones(nunit, dtype=int) * (-111)
for i,u in enumerate(units):
    iu2igu[i] = gunits[u]

igu2iu = np.ones(ngunit, dtype=int) * (-111)
for i,igu in enumerate(iu2igu):
    igu2iu[igu] = i

u2idx = [{u,i} for i, u in enumerate(units)]
idx2u = [{i:u} for i,u in enumerate(units.keys())]

#endregion 

#region Unit priorities.
# Priority scheme of production units. Higher priority value implies higher priority toward lower units of lower priority values.
# Two or more units may have same priority.
priority = dfDataUnit['prioritet']
dropPrioUnits = [u for u in units if priority[u] == 0]
uprio = priority.drop(labels=dropPrioUnits, inplace=False)
nuprio = len(uprio)
uprio2up = np.zeros((nuprio, nuprod), dtype=bool)
for iu1, u1 in enumerate(uprio.index):
    for iu2, u2 in enumerate(uprod):
        if priority[u1] > priority[u2]:
            uprio2up[iu1,iu2] = True
#endregion

#region Fuels
ngfuel = len(gfuels)
nfuel = len(fuels)

# Mapping from active to global fuel index and reverse.
if2igf = np.ones(nfuel, dtype=int) * (-111)
for i,f in enumerate(fuels):
    if2igf[i] = gfuels[f]

igf2if = np.ones(ngfuel, dtype=int) * (-111)
for i,igf in enumerate(if2igf):
    igf2if[igf] = i

f2idx = [{f,i} for i, f in enumerate(fuels)]
idx2f = [{i:f} for i,f in enumerate(fuels.keys())]

#endregion
 
#endregion ---------------------------------------------------------------------------

#region Define counters and lookups

#region Plant unit groups and indexers.
ua   = [uu for uu in dfDataUnit[dfDataUnit['ukind'] == ukinds['affald']  ].index if onU[uu]]
ub   = [uu for uu in dfDataUnit[dfDataUnit['ukind'] == ukinds['biomasse']].index if onU[uu]]
uc   = [uu for uu in dfDataUnit[dfDataUnit['ukind'] == ukinds['varme']   ].index if onU[uu]]
ur   = [uu for uu in dfDataUnit[dfDataUnit['ukind'] == ukinds['peak']    ].index if onU[uu]]
uv   = [uu for uu in dfDataUnit[dfDataUnit['ukind'] == ukinds['cooler']  ].index if onU[uu]]
uaux = [uu for uu in dfDataUnit[dfDataUnit['ukind'] != ukinds['affald']].index if onU[uu] and uu not in uv]
nua = len(ua); nub = len(ub); nuc = len(uc); nur = len(ur); nuv = len(uv); nuaux = len(uaux)

# Indices of unit groups. Mapping is prefixed with ixu.
ixua = [iu for iu,u in enumerate(units.keys()) if u in ua]
ixub = [iu for iu,u in enumerate(units.keys()) if u in ub]
ixuc = [iu for iu,u in enumerate(units.keys()) if u in uc]
ixur = [iu for iu,u in enumerate(units.keys()) if u in ur]
ixuv = [iu for iu,u in enumerate(units.keys()) if u in uv]
ixuprod = [iu for iu,u in enumerate(units.keys()) if u not in uv]
ixuaux  = [iu for iu,u in enumerate(units.keys()) if u in uaux]

#endregion 

#region Fuel groups and indexers.
fa   = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['affald']  ].index if onF[ff]]
fb   = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['biomasse']].index if onF[ff]]
fc   = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['varme']   ].index if onF[ff]]
fr   = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['peak']    ].index if onF[ff]]
faux = [ff for ff in dfDataFuel[dfDataFuel['fkind'] != fkinds['affald']  ].index if onF[ff]]
ffri = [ff for ff in dfDataFuel[dfDataFuel['fri'] != 0].index if onF[ff] and ff in fa]
fdis = [ff for ff in dfDataFuel[dfDataFuel['bortskaffes'] != 0].index if onF[ff] and ff in fa]
fsto = [ff for ff in dfDataFuel[dfDataFuel['lagerbar'] != 0].index if onF[ff] and ff in fa]
nfa   = len(fa); nfb = len(fb); nfc = len(fc); 
nfaux = len(faux); nffri = len(ffri); nfdis = len(fdis); nfsto = len(fsto)

# Mappings from active fuel index to absolute fuel index. Mapping prefixed with ixf
ixfa   = [i for i,f in enumerate(fuels.keys()) if f in fa]
ixfb   = [i for i,f in enumerate(fuels.keys()) if f in fb]
ixfc   = [i for i,f in enumerate(fuels.keys()) if f in fc]
ixfr   = [i for i,f in enumerate(fuels.keys()) if f in fr]
ixfaux = [i for i,f in enumerate(fuels.keys()) if f in faux]
ixfdis = [i for i,f in enumerate(fuels.keys()) if f in fdis]
ixffri = [i for i,f in enumerate(fuels.keys()) if f in ffri]
ixfsto = [i for i,f in enumerate(fuels.keys()) if f in fsto]
#endregion 

# Truth table for match of fuel and plant unit.
dfu2f = pd.DataFrame(index=uprod, columns=fuels, dtype=bool)
for u in uprod:
    for f in fuels:
        dfu2f.at[u,f] = (u in ua and f in fa) or (u in ub and f in fb) or (u in uc and f in fc) or (u in ur and f in fr)
u2f = dfu2f.to_numpy()

#region Obsolete indexers
#--- ibegu = {'ua':0,     'ub':nua,           'uc':nua + nub,           'ur':nua + nub + nuc,           'uv': nua + nub + nuc + nur,           'uaux': nua}
#--- iendu = {'ua':nua-1, 'ub':nua + nub - 1, 'uc':nua + nub + nuc - 1, 'ur':nua + nub + nuc + nur - 1, 'uv': nua + nub + nuc + nur + nuv - 1, 'uaux': nua + nub + nuc + nur - 1} 
#--- 
#--- ibegf = {'fa':0,     'fb':nfa,           'fc':nfa + nfb,           'faux': nfa}
#--- iendf = {'fa':nfa-1, 'fb':nfa + nfb - 1, 'fc':nfa + nfb + nfc - 1, 'faux': nfa + nfb + nfc + nfaux - 1} 

#--- # Specific indices
#--- iacooler = -1
#--- if nuv > 0:
#---     iacooler = ibegu['uv']
#--- 
#endregion Obsolete indexers

print('Counters and indexers are defined.')
#endregion 
#--------------------------------------------------------------------------------------

#%% Extract parameters from input data.
#region 
 
# All parameters, variables and equations will refer to active entities only.

#region Plant unit parms.
kapTon  = dfDataUnit['kapTon']
kapNom  = dfDataUnit['kapNom']
kapRgk  = dfDataUnit['kapRgk']
kapMin  = dfDataUnit['kapMin']
kapMax  = kapNom + kapRgk
etaq    = dfDataUnit['etaq']
costDV  = dfDataUnit['DV']
costAux = dfDataUnit['aux']
#endregion

#region Prognoses parms.
days      = dfProgn['ndage'].to_numpy()
qdem      = dfProgn['varmebehov'].to_numpy()
taxEtsTon = dfProgn['ets'].to_numpy()
taxAfvMWh = dfProgn['afv'].to_numpy() / 3.6
taxAtlMWh = dfProgn['atl'].to_numpy() / 3.6
power     = dfProgn['ELprod'].to_numpy()
if not onU['Ovn3']:
    power = np.zeros((nmo), dtype=float)
#endregion 

#region Fuel parms.
fkind      = dfDataFuel['fkind']
storable   = (dfDataFuel['lagerbar'] != 0)
minTonnage = dfDataFuel['minTonnage']
maxTonnage = dfDataFuel['maxTonnage']
fuelprice  = dfDataFuel['pris']
lhvMWf     = dfDataFuel['brandv'] / 3.6
shareCo2   = dfDataFuel['co2andel']
MinLhvMWh  = dfDataUnit['MinLhv'] / 3.6
#endregion 

#region Availabilities
hours = days * 24
shareAvailU = np.zeros(shape=(nmo,nunit), dtype=float)
availDays   = np.zeros(shape=(nmo,nunit), dtype=float)
for imo, mo in enumerate(months):
    for iua, u in enumerate(units):
        shareAvailU[imo,iua] = dfAvailU.at[mo,u] / days[imo]
        availDays[imo,iua] = dfAvailU.at[mo,u]
#endregion 
#endregion 

#%% Compute model parameters.

#region Hard-coded model parms
penalty_bOnU     = dfModelParms.loc['Penalty_bOnU',    'Værdi']
penalty_QrgkMiss = dfModelParms.loc['Penalty_QRgkMiss','Værdi']
rgkRabatMinShare = dfModelParms.loc['RgkRabatMinShare','Værdi']
rgkRabatSats     = dfModelParms.loc['RgkRabatSats',    'Værdi']
heatSalesPrice   = dfModelParms.loc['Varmesalgspris',  'Værdi']
#endregion 

#region Derived model parms
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
    for iua in ixua:  
        f1 = shareAvailU[imo,iua] * hours[imo] * kapNom[iua]
        f2 = 0.0
        for ifa in ixfa:
            if u2f[iua,ifa]:
                f2 += FuelMax[ifa,imo] * lhvMWf[ifa]
        f2 *= etaq[iua]
        QaffMmax[imo,iua] = min(f1, f2)
        QrgkMax[imo,iua]  = kapRgk[iua] / kapNom[iua] * QaffMmax[imo,iua]
        qaff   += shareAvailU[imo,iua] * (QaffMmax[imo,iua] + QrgkMax[imo,iua])
        atlmax += shareAvailU[imo,iua] * hours[imo] * kapMax[iua]

    EaffGross[imo]    = QaffTotalMax[imo] + power[imo] 
    CostsATLmax[imo]  = atlmax * taxAtlMWh[imo]
    RgkRabatMax[imo]  = rgkRabatSats * CostsATLmax[imo]

QRgkMissMax = 0.0
for iua in ixua:  
    QRgkMissMax += 2 * rgkRabatMinShare * 31 * 24 * kapNom[iua]

#endregion 

#%% ?????????????????????????????????????????????????????
#region Feasibility checks

#TODO Check if the mandatory amount of fuels surpasses the capacity of plants i.e. prechecking equation ZQ_FuelMin and others.
#TODO Maybe rather introduce penalized virtual waste fuel amounts (slacks) that can pinpoint the problem.
#TODO And a virtual penalized cooler.

# ZQ_FuelMin(f,mo) $(OnF(f) AND NOT fsto(f) AND NOT ffri(f) AND fdis(f))  ..  
#   sum(u $(OnU(u)  AND u2f(u,f)), FuelDemand(u,f,mo))  =G=  FuelBounds(f,'min',mo);
# ZQ_FuelMaxYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDemand(u,fdis,mo)))  =L=  MaxTonnageAar(fdis) * card(mo) / 12;
# ZQ_QaffM(ua,mo)    $OnU(ua)  ..  QaffM(ua,mo) =E=  [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * EtaQ(ua) * LhvMWh(fa))] $OnU(ua);
# ZQ_Qbio(ub,mo)     $OnU(ub)  ..  Q(ub,mo)     =E=  [sum(fb $(OnF(fb) AND u2f(ub,fb)), FuelDemand(ub,fb,mo) * EtaQ(ub) * LhvMWh(fb))] $OnU(ub);
# ZQ_Qvarme(uc,mo)   $OnU(uc)  ..  Q(uc,mo)     =E=  [sum(fc $(OnF(fc) AND u2f(uc,fc)), FuelDemand(uc,fc,mo))] $OnU(uc);  # Varme er i MWhq, mens øvrige drivmidler er i ton.
# ZQ_Qpeak(ur,mo)    $OnU(ur)  ..  Q(ur,mo)     =E=  [sum(fr $(OnF(fr) AND u2f(ur,fr)), FuelDemand(ur,fr,mo) * EtaQ(ur) * LhvMWh(fr))] $OnU(ur); 

for f in fuels:
    if fdis(f) and not fsto(f) and not ffri(f):
        for imo in range(nmo):
            pass
        
#endregion Feasibility checks

#--------------------------------------------------------------------------------------
# %% Setup of optimization model

# Create new GEKKO model.
m = GEKKO(remote=False, name='REFA Waste Optimizer')
m.options.SOLVER=1  # APOPT is a MINLP solver

#--------------------------------------------------------------------------------------
#%% Create model variables.

# Variables are only defined on active entities.
# Hence results for non-active entities default to zero.

NPV = m.Var('NPV')  # Objective variable.

# Fundamental decision variables. Python variables prefixed with 'v' as compared to GAMS variables.
vbOnU        = m.Array(m.Var, (nmo, nuprod),  integer=True)
vbOnRgk      = m.Array(m.Var, (nmo, nua),     integer=True)
vbOnRgkRabat = m.Array(m.Var, (nmo, nua),     integer=True)

# FuelDemand(mo,u,f):
vFuelDemand        = m.Array(m.Var, (nmo, nuprod, nfuel), lb=0.0)
vFuelDemandFreeSum = m.Array(m.Var, (nmo), lb=0.0)

vQ        = m.Array(m.Var, (nmo, nuprod), lb=0.0)
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
vIncomeAff      = np.empty((nmo, nfuel),  object)
vCostsU         = np.empty((nmo, nuprod), object)
vCostsTotalF    = np.empty((nmo),          object)
vCostsTotalAuxF = np.empty((nmo),          object)
vCostsAuxF      = np.empty((nmo, nfaux),   object)
vCostsAFV       = np.empty((nmo),          object)
vCostsATL       = np.empty((nmo),          object)
vCostsETS       = np.empty((nmo),          object)
vCO2emis        = np.empty((nmo, nfuel),  object)

print('Primary model variables have been defined')
#--------------------------------------------------------------------------------------

#%% Create equations.
#region Equations

pPenalty_bOnU     = m.Param(value=1E+3, name='Penalty_bOnU')
pPenalty_QrgkMiss = m.Param(value=20.0, name='Penalty_QrgkMiss')

allEqns = dict()    # Dictionary for all equations.

# ZQ_Obj  ..  NPV  =E=  sum(mo, IncomeTotal(mo) 
#                       - [
#                            sum(u $OnU(u), CostsU(u,mo)) 
#                          + CostsTotalF(mo) 
#                          + Penalty_bOnU * sum(u, bOnU(u,mo)) 
#                          + Penalty_QRgkMiss * QRgkMiss(mo)
#                         ] );

objective = np.sum(vIncomeTotal) - (np.sum(vCostsU) + np.sum(vCostsTotalF) + pPenalty_bOnU * np.sum(vbOnU) + pPenalty_QrgkMiss * np.sum(vQrgkMiss)) 
m.Obj(objective)
logn.debug('objective ={0}'.format(repr(objective)) )
allEqns['Objective'] = objective

# ZQ_IncomeTotal(mo) .. IncomeTotal(mo)  =E=  sum(fa $OnF(fa), IncomeAff(fa,mo)) + RgkRabat(mo) + VarmeSalgspris * sum(up $OnU(up), Q(up,mo));
# Heat sales price excluded as it merely is an offset not affecting the optimization unless close to zero where absolute tolerance should be used.
for imo in range(nmo):
    exIncomeTotal = vRgkRabat[imo]
    for iff in range(nfuel):
        exIncomeTotal += vIncomeAff[imo,iff]
    vIncomeTotal[imo] = m.Intermediate(exIncomeTotal, 'IncomeTotal_' + months[imo])
    logn.debug('vIncomeTotal[{0}} = {1}'.format(months[imo], repr(vIncomeTotal[imo])) )

# ZQ_IncomeAff(fa,mo) .. IncomeAff(fa,mo)  =E=  sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * DataFuel(fa,'pris')) $OnF(fa);
for imo in range(nmo):
    for iff in range(nfuel):
        exIncomeF = 0.0
        for iua in ixua:  #--- range(ibegu['ua'], iendu['ua']):   # All waste production units
            exIncomeF += vFuelDemand[imo,iua,iff] * fuelprice[iff]
        vIncomeAff[imo,iff] = m.Intermediate(exIncomeF, 'IncomeF_' + idx2f[iff] + '_' + months[imo])

# ZQ_CostsU(u,mo) .. CostsU(u,mo)  =E=  Q(u,mo) * (DataU(u,'dv') + DataU(u,'aux') ) $OnU(u);
for imo in range(nmo):
    for iua in range(nunit):
        vCostsU = m.Intermediate(vQ[imo,iua] * (costDV[iua] + costAux[iua]))

# ZQ_Qafv(mo) .. Qafv(mo)  =E=  sum(ua $OnU(ua), Q(ua,mo)) - Q('cooler',mo);   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.
for imo in range(nmo):
    if onU['cooler']:
        exQAfv = -vQ[imo,u2idx['cooler']] 
    else:
        exQAfv = 0.0
    for iua in ixua:  #--- range(ibegu['ua'], iendu['ua']):
        exQAfv += vQ[imo,iua] 
    vQafv[imo] = m.Intermediate(exQAfv, 'Qafv_' + months[imo])

# ZQ_CO2emis(f,mo) $OnF(f) .. CO2emis(f,mo)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelDemand(up,f,mo)) * DataFuel(f,'co2andel');  
for imo in range(nmo):
    for iff in range(nfuel):
        exCO2emis = 0.0
        for iua in ixuprod:  #--- range(ibegu['ua'], iendu['ur']):   # All production units
            exCO2emis += vFuelDemand[imo,iua,iff] * shareCo2[iff]
        vCO2emis[imo,iff] = m.Intermediate(exCO2emis, 'CO2emis_' + idx2f[iff] + '_' + months[imo])

# ZQ_CostsETS(mo) .. CostsETS(mo)  =E=  sum(f $OnF(f), CO2emis(f,mo)) * taxEtsTonTon(mo);
for imo in range(nmo):
    exCostsETS = 0.0
    for iff in range(nfuel):
        exCostsETS += vCO2emis[imo,iff] * taxEtsTon[imo]
    vCostsETS[imo] = m.Intermediate(exCostsETS, 'CostsETS_' + months[imo])

# ZQ_CostsAFV(mo) .. CostsAFV(mo)  =E=  Qafv(mo) * TaxAfvMWh(mo);
for imo in range(nmo):
    exQAfv = 0.0
    for iua in ixua:  #--- range(ibegu['ua'], iendu['ua']):
        exQAfv += vQafv[imo,iua] 
    vCostsAFV[imo] = m.Intermediate(exQAfv * taxAfvMWh[imo], 'CostsAFV_' + months[imo])

# ZQ_CostsATL(mo) .. CostsATL(mo)  =E=  sum(ua $OnU(ua), Q(ua,mo)) * TaxAtlMWh(mo);
for imo in range(nmo):
    exCostsATL = 0.0
    for iua in ixua:  #--- range(ibegu['ua'], iendu['ua']):
        exCostsATL += vQ[imo,iua] * taxAtlMWh[imo]
    vCostsATL[imo] = m.Intermediate(exCostsATL, 'CostsATL_' + months[imo])

# ZQ_CostsTotalF(mo) .. CostsTotalF(mo)  =E=  CostsTotalAuxF(mo) + CostsAFV(mo) + CostsATL(mo) + CostsETS(mo);
for imo in range(nmo):
    vCostsTotalF[imo] = m.Intermediate(vCostsTotalAuxF[imo] + vCostsAFV[imo] + vCostsATL[imo] + vCostsETS[imo], 'CostsTotalF_' + months[imo])

# ZQ_CostsTotalAuxF(mo) .. CostsTotalAuxF(mo)  =E=  sum(faux, CostsAuxF(faux,mo));
# ZQ_CostsAuxF(faux,mo) .. CostsAuxF(faux,mo)  =E=  sum(uaux $(OnU(uaux) AND u2f(uaux,faux)), FuelDemand(uaux,faux,mo) * DataFuel(faux,'pris') );
for imo in range(nmo):
    exCostsTotalAuxF = 0.0
    for iff in range(nfaux):
        exCostsAuxF = 0.0
        for iua in ixuaux:    #--- range(ibegu['uaux'], iendu['uaux']):
            exCostsAuxF += vFuelDemand[imo,iua,iff] * fuelprice[iff]
        vCostsAuxF[imo,iff] = m.Intermediate(exCostsAuxF, 'CostsAuxF_' + idx2f[iff] + '_' + months[imo])
        exCostsTotalAuxF += vCostsAuxF[imo,iff]
    vCostsTotalAuxF[imo] = m.Intermediate(exCostsTotalAuxF, 'CostsTotalAuxF_' + months[imo])

# ZQ_PrioUp(uprio,up,mo) $(OnU(uprio) AND OnU(up) AND AvailDaysU(mo,uprio) AND AvailDaysU(mo,up)) ..  bOnU(up,mo)  =L=  bOnU(uprio,mo); 
eqPrioUp = list()
for imo in range(nmo):
    for iu1, up1 in enumerate(uprio):
            eqn = None
            for iu2, up2 in enumerate(uprod):
                if uprio2up[iu1,iu2] and availDays[imo,iu1] and availDays[imo,iu2] > 0:
                    eqn = m.Equation(vbOnU[iu1] <= vbOnU[iu2]) 
            if eqn is not None:
                eqPrioUp.append(eqn)

if len(eqPrioUp) > 0:
    allEqns['PrioUp'] = eqPrioUp

# ZQ_TotalAffEprod(mo)  ..  TotalAffEProd(mo)  =E=  Power(mo) + sum(ua $OnU(ua), Q(ua,mo));     # Samlet energioutput fra affaldsanlæg. Bruges til beregning af RGK-rabat.
vTotalAffEProd = np.empty((nmo), dtype=object)
for imo in range(nmo):
    eqTotalAffEprod = power[imo]
    for iua in ua:
        eqTotalAffEprod += vQ[imo,iua]
    vTotalAffEProd[imo] = m.Intermediate(eqTotalAffEprod, name='TotalAffEProd_' + months[imo])

# ZQ_QRgkMiss(mo)       ..  sum(ua $OnU(ua), Qrgk(ua,mo)) + QRgkMiss(mo)  =G=  RgkRabatMinShare * TotalAffEProd(mo);
# ZQ_bOnRgkRabat(mo)    ..  QRgkMiss(mo)  =L=  (1 - bOnRgkRabat(mo)) * QRgkMissMax;
if nua > 0:
	eqQRgkMiss    = np.empty((nmo), dtype=object)
	eqbOnRgkRabat = np.empty((nmo), dtype=object)
	for imo in range(nmo):
		eqLhsQrgkMiss = 0.0
		for iua in ixua:  
			eqLhsQrgkMiss += vQ[imo,iua] + vQrgk[imo,iua]
		vQrgkMiss[imo]     = m.Intermediate(eqLhsQrgkMiss, name='QrgkMiss_' + months[imo])
		eqQRgkMiss[imo]    = m.Equation(vTotalAffEProd[imo]  >=  rgkRabatMinShare * vTotalAffEProd[imo])
		eqbOnRgkRabat[imo] = m.Equation(vQrgkMiss[imo]       <=  (1.0 - vbOnRgkRabat[imo]) * QRgkMissMax)
		
	allEqns['QRgkMiss'] = eqQRgkMiss
	allEqns['bOnRgkRabat'] = eqbOnRgkRabat

# ZQ_RgkRabatMax1(mo) ..  RgkRabat(mo)                                =L=  RgkRabatMax(mo) * bOnRgkRabat(mo);
# ZQ_RgkRabatMin2(mo) ..  0 * (1 - bOnRgkRabat(mo))                   =L=  RgkRabatSats * CostsATL(mo) - RgkRabat(mo);
# ZQ_RgkRabatMax2(mo) ..  RgkRabatSats * CostsATL(mo) - RGKrabat(mo)  =L=  RgkRabatMax(mo) * (1 - bOnRgkRabat(mo));
if nua > 0:
	eqRgkRabatMax1 = np.empty((nmo), dtype=object)
	eqRgkRabatMin2 = np.empty((nmo), dtype=object)
	eqRgkRabatMax2 = np.empty((nmo), dtype=object)
	for imo in range(nmo):
		eqRgkRabatMax1[imo] = m.Equation( vRgkRabat[imo]  <=  RgkRabatMax[imo] * vbOnRgkRabat[imo] )
		eqRgkRabatMin2[imo] = m.Equation( 0.0  <=  rgkRabatSats * vCostsATL[imo] - vRgkRabat[imo] )
		eqRgkRabatMax2[imo] = m.Equation( rgkRabatSats * vCostsATL[imo] - vRgkRabat[imo]  <=  RgkRabatMax[imo] * (1 - vbOnRgkRabat[imo]) )

	allEqns['RgkRabatMax1'] = eqRgkRabatMax1
	allEqns['RgkRabatMin2'] = eqRgkRabatMin2
	allEqns['RgkRabatMax2'] = eqRgkRabatMax2

# ZQ_Qdemand(mo) ..  Qdemand(mo)  =E=  sum(up $OnU(up), Q(up,mo)) - Q('cooler',mo) $OnU('cooler');
if nuprod > 0:
	eqQdemand  = np.empty((nmo), dtype=object)
	for imo in range(nmo):
		eqQdem = 0.0
		for iuv in ixuv:
			eqQdem += -vQ[imo,iuv]
		for iu in ixuprod:
			eqQdem += vQ[imo,iu]
		eqQdemand[imo] = m.Equation( eqQdem )
	allEqns['Qdemand'] = eqQdemand

# ZQ_Qaff(ua,mo)    $OnU(ua)  ..  Q(ua,mo)     =E=  [QaffM(ua,mo) + Qrgk(ua,mo)];
# ZQ_QaffM(ua,mo)   $OnU(ua)  ..  QaffM(ua,mo) =E=  [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * EtaQ(ua) * LhvMWh(fa))] $OnU(ua);
# ZQ_Qrgk(ua,mo)    $OnU(ua)  ..  Qrgk(ua,mo)  =L=  KapRgk(ua) / KapNom(ua) * QaffM(ua,mo);  
# ZQ_QrgkMax(ua,mo) $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);  
if nua > 0:
    eqQaff    = np.empty((nmo,nua), dtype=object)
    eqQaffM   = np.empty((nmo,nua), dtype=object)
    eqQrgk    = np.empty((nmo,nua), dtype=object)
    eqQrgkMax = np.empty((nmo,nua), dtype=object)
    for imo in range(nmo):
        # Waste plant heat balances
        for iua in ixua:  #--- range(ibegu['ua'], iendu['ua']):
            eqQaff[imo,iua]    = m.Equation( vQ[imo,iua]     ==  vQaffM[imo,iua] + vQrgk[imo,iua] )
            eqQrgk[imo,iua]    = m.Equation( vQrgk[imo,iua]  <=  kapRgk[iua] / kapNom[iua] * vQaffM[imo,iua] )
            eqQrgkMax[imo,iua] = m.Equation( vQrgk[imo,iua]  <=  QrgkMax[imo] )
            
            rhsEqQaffM = 0.0
            for ifa in ixfa:   #--- range(ibegf['fa'], iendf['fa']):
                if u2f[iua,ifa]:
                    rhsEqQaffM += vFuelDemand[imo,iua,ifa] * etaq[iua] * lhvMWf[ifa]
            eqQaffM[imo,iua] = m.Equation( vQaffM[imo,iua] == rhsEqQaffM )
    
    allEqns['Qaff']    = eqQaff
    allEqns['QaffM']   = eqQaffM
    allEqns['Qrgk']    = eqQrgk
    allEqns['QrgkMax'] = eqQrgkMax

# ZQ_Qbio(ub,mo) $OnU(ub)  ..  Q(ub,mo)  =E=  [sum(fb $(OnF(fb) AND u2f(ub,fb)), FuelDemand(ub,fb,mo) * EtaQ(ub) * LhvMWh(fb))]  $OnU(ub);
if nub > 0:
    eqQbio = np.empty((nmo,nub), dtype=object)
    for imo in range(nmo):
        # Biomass plant heat balances
        for iub in ixub:   #--- range(ibegu['ub'], iendu['ub']):
            rhsEqQbio = 0.0
            for ifb in ixfb:  #--- range(ibegf['fb'], iendf['fb']):
                if u2f[iub,ifb]:
                    rhsEqQbio += vFuelDemand[imo,iub,ifb] * etaq[iub] * lhvMWf[ifb]
            eqQbio[imo,iub] = m.Equation( vQ[imo,iub] == rhsEqQbio )
    allEqns['Qbio'] = eqQbio

# ZQ_Qvarme(uc,mo)  $OnU(uc)  .. Q(uc,mo)  =E=  [sum(fc $(OnF(fc) AND u2f(uc,fc)), FuelDemand(uc,fc,mo))] $OnU(uc);  # Varme er i MWhq, mens øvrige drivmidler er i ton.
if nuc > 0:
    eqQvarme = np.empty((nmo,nuc), dtype=object)
    for imo in range(nmo):
        # External excess heat balances
        for iuc in ixuc:  #--- range(ibegu['uc'], iendu['uc']):
            rhsEqQvarme = 0.0
            for ifc in ixfc:   #--- range(ibegf['fc'], iendf['fc']):
                if u2f[iuc,ifc]:
                    rhsEqQvarme += vFuelDemand[imo,iuc,ifc]
                    
            eqQvarme[imo,iuc] = m.Equation( vQ[imo,iuc] == rhsEqQvarme )
    allEqns['Qvarme']   = eqQvarme

# # ZQ_Qpeak(ur,mo) $OnU(ur)  ..  Q(ur,mo)     =E=  [sum(fr $(OnF(fr) AND u2f(ur,fr)), FuelDemand(ur,fr,mo) * EtaQ(ur) * LhvMWh(fr))] $OnU(ur); 
if nur > 0:
    eqQpeak = np.empty((nmo,nur), dtype=object)
    for imo in range(nmo):
        # Peak boiler heat balances
        for iur in ixur:   #--- range(ibegu['ur'], iendu['ur']):
            rhsEqQpeak = 0.0
            for ifr in ixfr:   #--- range(ibegf['fr'], iendf['fr']):
                if u2f[iur,ifr]:
                    rhsEqQpeak += vFuelDemand[imo,iur,ifr]
            eqQpeak[imo,iur] = m.Equation( vQ[imo,iur] == rhsEqQpeak )
    allEqns['Qpeak']    = eqQpeak    

# ZQ_QMin(u,mo) $OnU(u) ..  Q(u,mo)  =G=  ShareAvailU(u,mo) * Hours(mo) * KapMin(u) * bOnU(u,mo);   #  Restriktionen paa timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
# ZQ_QMax(u,mo) $OnU(u) ..  Q(u,mo)  =L=  ShareAvailU(u,mo) * Hours(mo) * KapMax(u) * bOnU(u,mo);  
eqQMin = np.empty((nmo,nunit), dtype=object)
eqQMax = np.empty((nmo,nunit), dtype=object)
for imo in range(nmo):
    for iua in range(nunit):
        eqQMin[imo,iua] = m.Equation( vQ[imo,iua] >= shareAvailU[imo,iua] * hours[imo] * kapMin[iua] * vbOnU[imo,iua] )
        eqQMax[imo,iua] = m.Equation( vQ[imo,iua] <= shareAvailU[imo,iua] * hours[imo] * kapMax[iua] * vbOnU[imo,iua] )
allEqns['QMin'] = eqQMin
allEqns['QMax'] = eqQMax

# ZQ_QaffMmax(ua,mo) $OnU(ua) ..  QAffM(ua,mo)  =L=  QaffMmax(ua,mo);
# ZQ_bOnRgk(ua,mo)   $OnU(ua) ..  Qrgk(ua,mo)   =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);  
if nua > 0:
    eqQaffMmax = np.empty((nmo,nua), dtype=object)
    eqbOnRgk   = np.empty((nmo,nua), dtype=object)
    for imo in range(nmo):
        for iua in ixua:  #--- range(ibegu['ua'], iendu['ua']):
            eqQaffMmax[imo,iua] = m.Equation( vQaffM[imo,iua] <= QaffMmax[imo,iua] )
            eqbOnRgk[imo,iua]   = m.Equation( vQrgk[imo,iua]  <= QrgkMax[imo,iua] * vbOnRgk[imo,iua] )
    allEqns['QaffMMax'] = eqQaffMmax 
    allEqns['bOnRgk']   = eqbOnRgk

# ZQ_CoolMax(mo)  ..  Q('cooler',mo)  =L=  sum(ua $OnU(ua), Q(ua,mo));
if nuv > 0:
    eqQCoolMax = np.empty((nmo), dtype=object)
    for imo in range(nmo):
        lhs = 0.0
        for iuv in ixuv:
            lhs += vQ[imo,iuv]
        rhs = 0.0
        for iua in ixua:  
            rhs += vQ[imo,iua]
        eqQCoolMax[imo] = m.Equation( lhs <= rhs )
    allEqns['QCoolMax'] = eqQCoolMax 

# ZQ_FuelMin(f,mo) $(OnF(f) AND NOT fsto(f) AND NOT ffri(f) AND fdis(f))  
#   ..  sum(u $(OnU(u)  AND u2f(u,f)), FuelDemand(u,f,mo))  =G=  FuelBounds(f,'min',mo);
if nua > 0:
    eqFuelMin = np.empty((nmo,nua), dtype=object)
    for imo in range(nmo):
        rhsMin = 0.0
        lhsMin = 0.0
        for ifa in ixfa:  
            f = fuels[f]
            if (f not in fsto) and (f not in ffri) and (f in fdis):
                rhsMin += FuelMin[ifa,imo] 
                for iua in ixua: 
                    if u2f[iua,ifa]:
                        lhsMin += vFuelDemand[imo,iua,ifa] 
                eqFuelMin[imo,ifa] = m.Equation( lhsMin >= rhsMin )
    if len(eqFuelMin) > 0:
        allEqns['FuelMin'] = eqFuelMin

# ZQ_FuelMax(f,mo) $(OnF(f) AND fdis(f)) ..  sum(u $(OnU(u)  AND u2f(u,f)),  FuelDemand(u,f,mo))   =L=  FuelBounds(f,'max',mo) * 1.0001;  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.
if nua > 0:
    eqFuelMax = np.empty((nmo,nua), dtype=object)
    for imo in range(nmo):
        rhsMax = 0.0
        lhsMax = 0.0
        for ifa in ixfa:  
            f = fuels[f]
            if f in fdis:
                rhsMax += FuelMax[ifa,imo] * (1.0001) 
                for iua in ixua: 
                    if u2f[iua,ifa]:
                        lhsMax += vFuelDemand[imo,iua,ifa] 
            if lhsMax != 0.0:
                eqFuelMax[imo,ifa] = m.Equation( lhsMax <= rhsMax )
    allEqns['FuelMax'] = eqFuelMax

# ZQ_FuelMinYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDemand(u,fdis,mo)))  =G=  MinTonnageAar(fdis) * card(mo) / 12;
# ZQ_FuelMaxYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDemand(u,fdis,mo)))  =L=  MaxTonnageAar(fdis) * card(mo) / 12;
if nfdis > 0:
    eqFuelMinYear = np.empty(nfdis, dtype=object) 
    eqFuelMaxYear = np.empty(nfdis, dtype=object) 
    ifdis = -1
    for iff in range(nfuel):
        f = fuels[iff]
        if f in fdis:
            ifdis += 1 
            lhs = 0.0
            found = False
            for iua in range(nuprod):
                if u2f(iua,iff):
                    for imo in range(nmo):
                        found = True
                        lhs += vFuelDemand[imo,iua,ifdis]
            if found:
                eqFuelMinYear[ifdis] = m.Equation( lhs >= minTonnage[ifdis] * nmo / 12 )
                eqFuelMaxYear[ifdis] = m.Equation( lhs <= maxTonnage[ifdis] * nmo / 12 )
    allEqns['FuelMinYear'] = eqFuelMinYear
    allEqns['FuelMaxYear'] = eqFuelMaxYear

# ZQ_FuelDemandFreeSum(ffri) $(OnF(ffri) AND card(mo) GT 1) .. FuelDemandFreeSum(ffri)  =E=  sum(mo, sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDemand(ua,ffri,mo) ) );
if nffri > 0 and nmo >= 2:
    for iffri in ixffri:
        exFuelDemandFreeSum = 0.0
        for iua in ixua:  #--- range(ibegu['ua'], iendu['ua']):
            if u2f[iua,iffri]:
                for imo in range(nmo):
                    exFuelDemandFreeSum += vFuelDemand[imo,iua,iffri] 
        if exFuelDemandFreeSum != 0.0:
            fuelName = fuels[idx2f[iffri]]
            vFuelDemandFreeSum[iffri] = m.Intermediate(exFuelDemandFreeSum, name='FuelDemandFreeSum_' + fuelName)

# ZQ_FuelMinFreeNonStorable(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri) AND card(mo) GT 1) 
#    .. sum(ua $(OnU(ua) AND u2f(ua,ffri)), FuelDemand(ua,ffri,mo))  =E=  FuelDemandFreeSum(ffri) / card(mo);
if nffri > 0 and nmo >= 2:
    eqFuelMinFreeNonStorable = np.empty((nmo,nffri), dtype=object) 
    iffri = -1
    for f in ffri:
        iffri += 1
        if not storable[f]:
            for imo in range(nmo):
                found = False
                lhs = 0.0
                for iua in ixua:  #--- range(ibegu['ua'], iendu['ua']):
                    if u2f[iua,iffri]:
                        found = True
                        lhs += vFuelDemand[imo,iua,iffri] 
                if found:
                    fuelName = fuels[idx2f[iffri]]
                    eqFuelMinFreeNonStorable[imo,iffri] = m.Equation( lhs == vFuelDemandFreeSum[iffri] / nmo )
    allEqns['FuelMinFreeNonStorable'] = eqFuelMinFreeNonStorable

# ZQ_MaxTonnage(ua,mo) $OnU(ua) .. sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * KapTon(ua);
if nua > 0:
    eqMaxTonnage = np.empty((nmo,nua), dtype=object)
    for imo in range(nmo):
        for iua in ixua:  #--- range(ibegu['ua'], iendu['ua']):
            lhs = 0.0
            for ifa in ixfa:   #--- range(ibegf['fa'], iendf['fa']):
                if u2f[iua,ifa]:
                    lhs += vFuelDemand[imo,iua,ifa] 
            if lhs != 0.0:
                rhs = shareAvailU[imo,iua] * hours[imo] * kapTon[iua]
                eqMaxTonnage[imo,iua] = m.Equation( lhs <= rhs )
    allEqns['MaxTonnage'] = eqMaxTonnage

# ZQ_MinLhvAffald(ua,mo) $OnU(ua)  ..  MinLhvMWh(ua) * sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo))  =L=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * LhvMWh(fa));
if nua > 0:
    eqMinLhvAffald = np.empty((nmo,nua), dtype=object)
    for imo in range(nmo):
        for iua in ixua:  #--- range(ibegu['ua'], iendu['ua']):
            lhs = 0.0
            rhs = 0.0
            for ifa in ixfa:  #--- range(ibegf['fa'], iendf['fa']):
                if u2f[iua,ifa]:
                    lhs += vFuelDemand[imo,iua,ifa] 
                    rhs += vFuelDemand[imo,iua,ifa] * lhvMWf[ifa]
            if lhs != 0.0:
                lhs *= MinLhvMWh[iua]
                rhs = shareAvailU[imo,iua] * hours[imo] * kapTon[iua]
                eqMinLhvAffald[imo,iua] = m.Equation( lhs <= rhs )
    allEqns['MinLhvAffald'] = eqMinLhvAffald

#end region Equations
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
