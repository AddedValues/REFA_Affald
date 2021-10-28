# %% Imports 
#region Imports and basic setup
import enum
import os
import io
import logging as logn
import math
import itertools
import more_itertools
import numpy as np
from numpy.core.fromnumeric import var
import pandas as pd 
import xlwings as xw
import matplotlib.pyplot as plt
import mip as mp
from sys   import stdout
from mip   import Model, xsum, maximize, BINARY
from array import array

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
months = ['jan','mar']
nmo = len(months)
dropMonths = [mo for mo in allMonths if not mo in months]
# Create index for active months. ixmo[imo] yields index for an active month in all months.
ixgmo = np.empty((nmo), dtype=int)
ixmo = [imo for imo in range(nmo)]
for igmo, mo in enumerate(months):
    ixgmo[igmo] = allMonths.index(mo)

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

FuelMin = np.transpose(dfFuelMin.to_numpy())
FuelMax = np.transpose(dfFuelMax.to_numpy())

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

u2idx = {u:i for i, u in enumerate(units)}
idx2u = [u for i,u in enumerate(units.keys())]

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

f2idx = {f:i for i, f in enumerate(fuels)}
idx2f = [f for i,f in enumerate(fuels.keys())]

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
nua = len(ua); nub = len(ub); nuc = len(uc); nur = len(ur); nuv = len(uv); nuaux = len(uaux); nuprio = len(uprio)

# Indexers of unit groups. Indexers are prefixed with ixu.
ixu     = [iu for iu in range(nunit)]
ixua    = [iu for iu,u in enumerate(units.keys()) if u in ua]
ixub    = [iu for iu,u in enumerate(units.keys()) if u in ub]
ixuc    = [iu for iu,u in enumerate(units.keys()) if u in uc]
ixur    = [iu for iu,u in enumerate(units.keys()) if u in ur]
ixuv    = [iu for iu,u in enumerate(units.keys()) if u in uv]
ixuprod = [iu for iu,u in enumerate(units.keys()) if u not in uv]
ixuaux  = [iu for iu,u in enumerate(units.keys()) if u in uaux]
ixuprio = [iu for iu,u in enumerate(units.keys()) if u in uprio]

#endregion 

#region Fuel groups and indexers.
fa    = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['affald']  ].index if onF[ff]]
fb    = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['biomasse']].index if onF[ff]]
fc    = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['varme']   ].index if onF[ff]]
fr    = [ff for ff in dfDataFuel[dfDataFuel['fkind'] == fkinds['peak']    ].index if onF[ff]]
faux  = [ff for ff in dfDataFuel[dfDataFuel['fkind'] != fkinds['affald']  ].index if onF[ff]]
ffri  = [ff for ff in dfDataFuel[dfDataFuel['fri'] != 0].index if onF[ff] and ff in fa]
fdis  = [ff for ff in dfDataFuel[dfDataFuel['bortskaffes'] != 0].index if onF[ff] and ff in fa]
fsto  = [ff for ff in dfDataFuel[dfDataFuel['lagerbar'] != 0].index if onF[ff] and ff in fa]
nfa   = len(fa); nfb = len(fb); nfc = len(fc); 
nfaux = len(faux); nffri = len(ffri); nfdis = len(fdis); nfsto = len(fsto)

# Indexers for fuel groups. Indexers are prefixed with ixf
ixf    = [i for i in range(nfuel)]
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

print('Counters and indexers are defined.')
#endregion 
#--------------------------------------------------------------------------------------

#%% Extract parameters from input data.
#region Extract parameters from input data.
 
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
MinLhvMWh = dfDataUnit['MinLhv'] / 3.6
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
lhvMWh     = dfDataFuel['brandv'] / 3.6
shareCo2   = dfDataFuel['co2andel']
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
        for iff in ixfa:
            if u2f[iua,iff]:
                f2 += FuelMax[imo,iff] * lhvMWh[iff]
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
    if f in fdis and f not in fsto and f not in ffri:
        for imo in range(nmo):
            pass
        
#endregion Feasibility checks


#%% 
#region Setup of optimization model. 

# Create new MIP model.
m = Model(name='REFA Waste Optimizer', sense=mp.MAXIMIZE, solver_name='CBC')

#endregion 

#region Create model variables.

# Variables are only defined on active entities hence results for non-active entities default to zero.

# NPV = m.add_var(name='NPV', var_type=mp.CONTINUOUS)  # Objective variable.

# Fundamental decision variables. Python variables prefixed with 'v' as compared to GAMS variables.
# An instance of class mip.Var defaults to a positive and continuous variable.

vbOnU   = [[m.add_var(name='bOnU[{0}][{1}]'.format(months[imo], u),    var_type=mp.BINARY) for u in units] for imo in ixmo]
vbOnRgk = [[m.add_var(name='bOnRgk[{0}][{1}]'.format(months[imo], u),  var_type=mp.BINARY) for u in ua   ] for imo in ixmo]
vbOnRgkRabat = [m.add_var(name='bOnRgkRabat[{0}]'.format(months[imo]), var_type=mp.BINARY) for imo in ixmo] 

# vbOnU        = m.Array(m.Var, (nmo, nunit),   integer=True)
# vbOnRgk      = m.Array(m.Var, (nmo, nua),     integer=True)
# vbOnRgkRabat = m.Array(m.Var, (nmo, nua),     integer=True)

vFuelDemand        = [[[m.add_var(name='FuelDemand[{0},{1},{2}]'.format(months[imo],u,f), 
                        var_type=mp.CONTINUOUS, lb=0.0) for f in fuels] for u in uprod] for imo in ixmo]

vFuelDemandFreeSum = [m.add_var(name='FuelDemandFreeSum[{0}]'.format(idx2f[iffri]), 
                      var_type=mp.CONTINUOUS, lb=0.0) for iffri in ixffri]

# vFuelDemand        = m.Array(m.Var, (nmo, nuprod, nfuel), lb=0.0)
# vFuelDemandFreeSum = m.Array(m.Var, (nffri),              lb=0.0)

vQ        = [[m.add_var(name='Q[{0}][{1}]'.format(months[imo], u)    ) for u in units] for imo in ixmo]
vQrgkMiss =  [m.add_var(name='QrgkMiss[{0}]'.format(months[imo])     ) for imo in ixmo] 
vQafv     =  [m.add_var(name='Qafv[{0}]'.format(months[imo])         ) for imo in ixmo] 
vQrgk     = [[m.add_var(name='Qrgk[{0}][{1}]'.format(months[imo], u) ) for u in ua] for imo in ixmo]
vQaffM    = [[m.add_var(name='QaffM[{0}][{1}]'.format(months[imo], u)) for u in ua] for imo in ixmo]

# vQ        = m.Array(m.Var, (nmo, nunit),   lb=0.0)
# vQrgkMiss = m.Array(m.Var, (nmo),          lb=0.0)
# vQafv     = m.Array(m.Var, (nmo),          lb=0.0)
# vQrgk     = m.Array(m.Var, (nmo, nua),     lb=0.0)
# vQaffM    = m.Array(m.Var, (nmo, nua),     lb=0.0)

vRgkRabat      =  [m.add_var(name='RgkRabat[{0}]'.format(months[imo])     ) for imo in ixmo] 
vTotalAffEProd =  [m.add_var(name='TotalAffEProd[{0}]'.format(months[imo])) for imo in ixmo] 

# vRgkRabat      = m.Array(m.Var, (nmo),     lb=0.0)
# vTotalAffEProd = m.Array(m.Var, (nmo),     lb=0.0)

vIncomeTotal    =  [m.add_var(name='IncomeTotal[{0}]'.format(months[imo])   ) for imo in ixmo] 
vCostsTotalF    =  [m.add_var(name='CostsTotalF[{0}]'.format(months[imo])   ) for imo in ixmo]
vCostsTotalAuxF =  [m.add_var(name='CostsTotalAuxF[{0}]'.format(months[imo])) for imo in ixmo]
vCostsAFV       =  [m.add_var(name='CostsAFV[{0}]'.format(months[imo])      ) for imo in ixmo]
vCostsATL       =  [m.add_var(name='CostsATL[{0}]'.format(months[imo])      ) for imo in ixmo]
vCostsETS       =  [m.add_var(name='CostsETS[{0}]'.format(months[imo])      ) for imo in ixmo]
									
vCostsU         = [[m.add_var(name='CostsU[{0}][{1}]'.format(months[imo],u)            )  for u in units]    for imo in ixmo] 
vIncomeAff      = [[m.add_var(name='IncomeAff[{0}][{1}]'.format(months[imo],f)         )  for f in fa]       for imo in ixmo] 
vCO2emis        = [[m.add_var(name='CO2emis[{0}][{1}]'.format(months[imo],f)           )  for f in fuels]    for imo in ixmo] 
vCostsAuxF      = [[m.add_var(name='CostsAuxF[{0}][{1}]'.format(months[imo],idx2f[iff]))  for iff in ixfaux] for imo in ixmo] 

# Intermediate variable (assigned below)
# vIncomeTotal    = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsTotalF    = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsTotalAuxF = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsAFV       = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsATL       = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsETS       = m.Array(m.Var, (nmo),          lb=0.0)
# vCostsU         = m.Array(m.Var, (nmo, nunit),   lb=0.0)
# vIncomeAff      = m.Array(m.Var, (nmo, nfuel),   lb=0.0)
# vCO2emis        = m.Array(m.Var, (nmo, nfuel),   lb=0.0)
# vCostsAuxF      = m.Array(m.Var, (nmo, nfaux),   lb=0.0)

print('Primary model variables have been defined')
#endregion 

#%% Create equations.
#region Equations

allEqns = dict()    # Dictionary for all equations.

# ZQ_Obj  ..  NPV  =E=  sum(mo, IncomeTotal(mo) 
#                       - [
#                            sum(u $OnU(u), CostsU(u,mo)) 
#                          + CostsTotalF(mo) 
#                          + Penalty_bOnU * sum(u, bOnU(u,mo)) 
#                          + Penalty_QRgkMiss * QRgkMiss(mo)
#                         ] );

objective = xsum(vIncomeTotal) - (
                  xsum(vCostsU[imo][iu] for imo in ixmo for iu in ixu) 
                + xsum(vCostsTotalF) 
                + penalty_bOnU * xsum(vbOnU[imo][iu] for imo in ixmo for iu in ixu) 
                + penalty_QrgkMiss * xsum(vQrgkMiss)
            )
m.objective = maximize(objective)
logn.debug('objective ={0}'.format(str(objective)) )
allEqns['Objective'] = objective

# ZQ_IncomeTotal(mo) .. IncomeTotal(mo)  =E=  sum(fa $OnF(fa), IncomeAff(fa,mo)) + RgkRabat(mo) + VarmeSalgspris * sum(up $OnU(up), Q(up,mo));
# Heat sales price excluded as it merely is an offset not affecting the optimization unless close to zero where absolute tolerance should be used.

allEqns['IncomeTotal'] = [m.add_constr(
    vIncomeTotal[imo] == vRgkRabat[imo] + xsum(vIncomeAff[imo][ifa] for ifa in ixfa),
    name='IncomeTotal[{0}]'.format(months[imo]), ) for imo in ixmo]

# ZQ_IncomeAff(fa,mo) .. IncomeAff(fa,mo)  =E=  sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * DataFuel(fa,'pris')) $OnF(fa);
eqns = list()
for imo in range(nmo):
    for ifk,ifa in enumerate(ixfa):
        eq = vIncomeAff[imo][ifk] == xsum(vFuelDemand[imo][iua][ifa] * fuelprice[ifa] for iua in ixua) 
        eqName = 'IncomeAff[{0}][{1}]'.format(months[imo], idx2f[ifa])
        eqns.append(m.add_constr(eq, name=eqName))
allEqns['IncomeAff'] = eqns

# ZQ_CostsU(u,mo) .. CostsU(u,mo)  =E=  Q(u,mo) * (DataU(u,'dv') + DataU(u,'aux') ) $OnU(u);
eqns = list()
for imo in range(nmo):
    eqns.append([m.add_constr( vCostsU[imo][iu] == vQ[imo][iu] * (costDV[iu]+costAux[iu]),
                 name='CostsU[{0}][{1}]'.format(months[imo],idx2u[iu])) for iu in ixu])
allEqns['CostsU'] = eqns

# ZQ_Qafv(mo) .. Qafv(mo)  =E=  sum(ua $OnU(ua), Q(ua,mo)) - Q('cooler',mo);   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.
eqns = list()
eqns = [m.add_constr(vQafv[imo] == xsum(vQ[imo][iua] for iua in ixua) - xsum(vQ[imo][iuv] for iuv in ixuv),
        name='Qafv[{0}]'.format(months[imo])) for imo in ixmo]
allEqns['Qafv'] = eqns

# ZQ_CO2emis(f,mo) $OnF(f) .. CO2emis(f,mo)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelDemand(up,f,mo)) * DataFuel(f,'co2andel');  
eqns = list()
for imo in range(nmo):
    for iff in ixf:
        eq = vCO2emis[imo][iff] == xsum( vFuelDemand[imo][iu][iff] * shareCo2[iff] for iu in [i for i in ixuprod if u2f[i,iff]])
        name = 'CO2emis[{0}][{1}]'.format(months[imo],idx2f[iff])
        eqns.append(m.add_constr(eq,name=name))
allEqns['CO2emis'] = eqns

# ZQ_CostsETS(mo) .. CostsETS(mo)  =E=  sum(f $OnF(f), CO2emis(f,mo)) * taxEtsTonTon(mo);
allEqns['CostsETS'] = [m.add_constr( vCostsETS[imo] == xsum(vCO2emis[imo][iff] * taxEtsTon[imo] for iff in ixf), 
                       name='CostsETS[{0}]'.format(months[imo])) for imo in ixmo]

# ZQ_CostsAFV(mo) .. CostsAFV(mo)  =E=  Qafv(mo) * TaxAfvMWh(mo);
allEqns['CostsAFV'] = [m.add_constr(vCostsAFV[imo] == vQafv[imo] * taxAfvMWh[imo], 
                       name='CostsAFV[{0}]'.format(months[imo])) for imo in ixmo]

# ZQ_CostsATL(mo) .. CostsATL(mo)  =E=  sum(ua $OnU(ua), Q(ua,mo)) * TaxAtlMWh(mo);
allEqns['CostsATL'] = [m.add_constr(vCostsATL[imo] == xsum(vQ[imo][iua] for iua in ixua) * taxAtlMWh[imo], 
                       name='CostsATL[{0}]'.format(months[imo])) for imo in ixmo]

# ZQ_CostsTotalF(mo) .. CostsTotalF(mo)  =E=  CostsTotalAuxF(mo) + CostsAFV(mo) + CostsATL(mo) + CostsETS(mo);
allEqns['CostsTotalF'] = [m.add_constr(vCostsTotalF[imo] == vCostsTotalAuxF[imo] + vCostsAFV[imo] + vCostsATL[imo] + vCostsETS[imo], 
                          name='CostsATL[{0}]'.format(months[imo])) for imo in ixmo]

# ZQ_CostsTotalAuxF(mo) .. CostsTotalAuxF(mo)  =E=  sum(faux, CostsAuxF(faux,mo));
allEqns['CostsTotalAuxF'] = [m.add_constr(vCostsTotalAuxF[imo] == xsum(vCostsAuxF[imo][ifk] for ifk,ifaux in enumerate(ixfaux)),
                             name='CostsTotalAuxF[{0}]'.format(months[imo])) for imo in ixmo]

# ZQ_CostsAuxF(faux,mo) .. CostsAuxF(faux,mo)  =E=  sum(uaux $(OnU(uaux) AND u2f(uaux,faux)), FuelDemand(uaux,faux,mo) * DataFuel(faux,'pris') );
allEqns['CostsAuxF'] = [[m.add_constr(vCostsAuxF[imo][ifk] == xsum(vFuelDemand[imo][iuaux][ifaux] for iuaux in [i for i in ixuaux if u2f[i,ifaux]]) * fuelprice[ifaux] ,
                             name='CostsAuxF[{0}]'.format(months[imo])) for ifk,ifaux in enumerate(ixfaux)] for imo in ixmo]

# ZQ_PrioUp(uprio,up,mo) $(OnU(uprio) AND OnU(up) AND AvailDaysU(mo,uprio) AND AvailDaysU(mo,up)) ..  bOnU(up,mo)  =L=  bOnU(uprio,mo); 
eqns = list()
for imo in range(nmo):
    for iu1, up1 in enumerate(uprio):
        for iu2, up2 in enumerate(uprod):
            if uprio2up[iu1,iu2] and availDays[imo,iu1] and availDays[imo,iu2] > 0:
                eqns.append(m.add_constr(vbOnU[imo][iu1] <= vbOnU[imo][iu2], name='PrioUp[{0}][{1}]'.format(months[imo],idx2u[ixuprio[iu1]]))) 
allEqns['PrioUp'] = eqns

# ZQ_TotalAffEprod(mo)  ..  TotalAffEProd(mo)  =E=  Power(mo) + sum(ua $OnU(ua), Q(ua,mo));     # Samlet energioutput fra affaldsanlæg. Bruges til beregning af RGK-rabat.
allEqns['TotalAffEProd'] = [m.add_constr(vTotalAffEProd[imo] == power[imo] + xsum(vQ[imo][iua] for iua in ixua), 
                            name='TotalAffEProd[{0}]'.format(months[imo])) for imo in ixmo]

# ZQ_QRgkMiss(mo)       ..  sum(ua $OnU(ua), Qrgk(ua,mo)) + QRgkMiss(mo)  =G=  RgkRabatMinShare * TotalAffEProd(mo);
allEqns['QRgkMiss'] = [m.add_constr(xsum(vQrgk[imo][iua] for iua in ixua) + vQrgkMiss[imo] >= rgkRabatMinShare * vTotalAffEProd[imo], 
                       name='QrgkMiss[{0}]'.format(months[imo])) for imo in ixmo]

# ZQ_bOnRgkRabat(mo)    ..  QRgkMiss(mo)  =L=  (1 - bOnRgkRabat(mo)) * QRgkMissMax;
allEqns['bOnRgkRabat'] = [m.add_constr(vQrgkMiss[imo] <= (1 - vbOnRgkRabat[imo]) * QRgkMissMax, 
                            name='bOnRgkRabat[{0}]'.format(months[imo])) for imo in ixmo]

# ZQ_RgkRabatMax1(mo) ..  RgkRabat(mo)                                =L=  RgkRabatMax(mo) * bOnRgkRabat(mo);
# ZQ_RgkRabatMin2(mo) ..  0 * (1 - bOnRgkRabat(mo))                   =L=  RgkRabatSats * CostsATL(mo) - RgkRabat(mo);
# ZQ_RgkRabatMax2(mo) ..  RgkRabatSats * CostsATL(mo) - RGKrabat(mo)  =L=  RgkRabatMax(mo) * (1 - bOnRgkRabat(mo));
if nua > 0:

    allEqns['RgkRabatMax1'] = [m.add_constr(vRgkRabat[imo] <= RgkRabatMax[imo] * vbOnRgkRabat[imo], 
                               name='RgkRabatMax1[{0}]'.format(months[imo])) for imo in ixmo]

    allEqns['RgkRabatMin2'] = [m.add_constr( 0.0 <= rgkRabatSats * vCostsATL[imo] - vRgkRabat[imo], 
                               name='RgkRabatMin2[{0}]'.format(months[imo])) for imo in ixmo]

    allEqns['RgkRabatMax2'] = [m.add_constr(rgkRabatSats * vCostsATL[imo] - vRgkRabat[imo] <= RgkRabatMax[imo] * (1 - vbOnRgkRabat[imo]),
                               name='RgkRabatMax2[{0}]'.format(months[imo])) for imo in ixmo]

# ZQ_Qdemand(mo) ..  Qdemand(mo)  =E=  sum(up $OnU(up), Q(up,mo)) - Q('cooler',mo) $OnU('cooler');

allEqns['Qdemand'] = [m.add_constr(xsum(vQ[imo][iup] for iup in ixuprod) - xsum(vQ[imo][iuv] for iuv in ixuv) == qdem[imo], 
                      name='Qdemand[{0}]'.format(months[imo])) for imo in ixmo]

# ZQ_Qaff(ua,mo)    $OnU(ua)  ..  Q(ua,mo)     =E=  [QaffM(ua,mo) + Qrgk(ua,mo)];
# ZQ_QaffM(ua,mo)   $OnU(ua)  ..  QaffM(ua,mo) =E=  [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * EtaQ(ua) * LhvMWh(fa))] $OnU(ua);
# ZQ_Qrgk(ua,mo)    $OnU(ua)  ..  Qrgk(ua,mo)  =L=  KapRgk(ua) / KapNom(ua) * QaffM(ua,mo);  
# ZQ_QrgkMax(ua,mo) $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);  
if len(ua) > 0:
    # Waste plant heat balances.

    allEqns['Qaff'] = [[m.add_constr(vQ[imo][iua] == vQaffM[imo][iua] + vQrgk[imo][iua], 
                        name='Qaff[{0}][{1}]'.format(months[imo],idx2u[iua])) for iua in ixua] for imo in ixmo]

    allEqns['QaffM'] = [[m.add_constr(vQaffM[imo][iua] == xsum(vFuelDemand[imo][iua][ifa] * lhvMWh[ifa] for ifa in ixfa) * etaq[iua], 
                         name='QaffM[{0}][{1}]'.format(months[imo],idx2u[iua])) for iua in ixua] for imo in ixmo]

    allEqns['Qrgk'] = [[m.add_constr(vQrgk[imo][iua] <= kapRgk[iua] / kapNom[iua] * vQaffM[imo][iua], 
                        name='Qrgk[{0}][{1}]'.format(months[imo],idx2u[iua])) for iua in ixua] for imo in ixmo]

    allEqns['QrgkMax'] = [[m.add_constr(vQrgk[imo][iua] <= QrgkMax[imo][iua] + vbOnRgk[imo][iua], 
                           name='QrgkMax[{0}][{1}]'.format(months[imo],idx2u[iua])) for iua in ixua] for imo in ixmo]

# ZQ_Qaux(uaux,mo) $OnU(uo) ..  Q(uaux,mo)  =E=  [sum(faux $(OnF(faux) AND u2f(uaux,faux)), FuelDemand(uaux,faux,mo) * EtaQ(uaux) * LhvMWh(faux))] $OnU(uaux);
if nuaux > 0:
    # Other than waste plant heat balances.
    allEqns['Qaux'] = [[m.add_constr(vQ[imo][iuaux] == xsum(vFuelDemand[imo][iuaux][ifa] * lhvMWh[ifa] for ifa in ixfa) * etaq[iuaux], 
                       name='Qaux[{0}][{1}]]'.format(months[imo],idx2u[iuaux])) for iuaux in ixuaux] for imo in ixmo]

# ZQ_QMin(u,mo) $OnU(u) ..  Q(u,mo)  =G=  ShareAvailU(u,mo) * Hours(mo) * KapMin(u) * bOnU(u,mo);   #  Restriktionen paa timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
# ZQ_QMax(u,mo) $OnU(u) ..  Q(u,mo)  =L=  ShareAvailU(u,mo) * Hours(mo) * KapMax(u) * bOnU(u,mo);  
# Capacity bounds for all plant units.

allEqns['QMin'] = [[m.add_constr(vQ[imo][iu] >= shareAvailU[imo,iu] * hours[imo] * kapMin[iu] * vbOnU[imo][iu],
                    name='QMin[{0}][{1}]]'.format(months[imo],idx2u[iu])) for iu in ixu] for imo in ixmo]
allEqns['QMax'] = [[m.add_constr(vQ[imo][iu] <= shareAvailU[imo,iu] * hours[imo] * kapMax[iu] * vbOnU[imo][iu],
                    name='QMax[{0}][{1}]]'.format(months[imo],idx2u[iu])) for iu in ixu] for imo in ixmo]

# ZQ_QaffMmax(ua,mo) $OnU(ua) ..  QAffM(ua,mo)  =L=  QaffMmax(ua,mo);
allEqns['QaffMax'] = [[m.add_constr( vQaffM[imo][iua] <= QaffMmax[imo,iua], name='QaffMax[{0}][{1}]'.format(months[imo],idx2u[iua])) for iua in ixua]]

# ZQ_bOnRgk(ua,mo)   $OnU(ua) ..  Qrgk(ua,mo)   =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);  
allEqns['QaffMax'] = [[m.add_constr( vQrgk[imo][iua] <= QrgkMax[imo,iua] * vbOnRgk[imo][iua], name='bOnRgk[{0}][{1}]'.format(months[imo],idx2u[iua])) for iua in ixua]]

# ZQ_CoolMax(mo)  ..  Q('cooler',mo)  =L=  sum(ua $OnU(ua), Q(ua,mo));
# Only waste plant heat may be diverted to coolers.
if nuv > 0:
    allEqns['CoolMax'] = [m.add_constr(xsum(vQ[imo][iv] for iv in ixuv) <= xsum(vQ[imo][iua] for iua in ixua),
                          name='CoolMax[{0}'.format(months[imo])) for imo in ixmo]

# ZQ_FuelMin(f,mo) $(OnF(f) AND NOT fsto(f) AND NOT ffri(f) AND fdis(f)) .. sum(u $(OnU(u)  AND u2f(u,f)), FuelDemand(u,f,mo))  =G=  FuelBounds(f,'min',mo);
# Non-storable, non-free, disposable waste fuels must conform to a lower bound of fuel demand within each period (month).
ff = [iff for iff in ixf if (iff not in ixfsto) and (iff not in ixffri) and (iff in ixfdis) ]
allEqns['FuelMin'] = [[m.add_constr(xsum(vFuelDemand[imo][iup][iff] for iup in [iu for iu in ixuprod if u2f[iu,iff]]) >= FuelMin[imo,iff], 
                       name='FuelMin[{0}][{1}]'.format(months[imo],idx2f[iff])) for iff in ff] for imo in ixmo]

# ZQ_FuelMax(f,mo) $(OnF(f) AND fdis(f)) ..  sum(u $(OnU(u)  AND u2f(u,f)),  FuelDemand(u,f,mo))   =L=  FuelBounds(f,'max',mo) * 1.0001;  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.
# All disposable waste fuels must conform to the upper bound.
ff = [ifa for ifa in ixf if (ifa in ixfdis)]
allEqns['FuelMax'] = [[m.add_constr(xsum(vFuelDemand[imo][iup][iff] for iup in [iu for iu in ixuprod if u2f[iu,iff]]) <= FuelMax[imo,iff], 
                       name='FuelMax[{0}][{1}]'.format(months[imo],idx2f[iff])) for iff in ff] for imo in ixmo]

# for imo in ixmo:
#     for iff in ff:
#         for iu in [i for i in ixuprod if u2f[i,iff]]:
#             try:
#                 print('imo={}, iff={}, iu={}, vFuelDemand={}'.format(imo,iff,iu,str(vFuelDemand[imo][iu][iff])))
#             except Exception as ex:
#                 print(str(ex))

# ZQ_FuelMinYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDemand(u,fdis,mo)))  =G=  MinTonnageAar(fdis) * card(mo) / 12;
allEqns['FuelMinYear'] = [m.add_constr(xsum(vFuelDemand[imo][iup][iff] for iup in [iu for iu in ixuprod if u2f[iu,iff]]) >= minTonnage[iff] * nmo/12, 
                          name='FuelMinYear'.format(idx2f[ifdis])) for ifdis in ixfdis]

# ZQ_FuelMaxYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDemand(u,fdis,mo)))  =L=  MaxTonnageAar(fdis) * card(mo) / 12;
allEqns['FuelMaxYear'] = [m.add_constr(xsum(vFuelDemand[imo][iup][iff] for iup in [iu for iu in ixuprod if u2f[iu,iff]]) <= maxTonnage[iff] * nmo/12, 
                          name='FuelMaxYear'.format(idx2f[ifdis])) for ifdis in ixfdis]

# ZQ_FuelDemandFreeSum(ffri) $(OnF(ffri) AND card(mo) GT 1) .. FuelDemandFreeSum(ffri)  =E=  sum(mo, sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDemand(ua,ffri,mo) ) );
if nmo >= 2:
    allEqns['FuelDemandFreeSum'] = [m.add_constr(vFuelDemandFreeSum[ifk] == xsum(vFuelDemand[imo][iua][iffri] for iua in ixua if u2f[iua,iffri]),
                                    name='FuelDemandFreeSum[{0}]'.format(idx2f[iffri])) for ifk,iffri in enumerate(ixffri)]

# ZQ_FuelMinFreeNonStorable(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri) AND card(mo) GT 1) 
#    .. sum(ua $(OnU(ua) AND u2f(ua,ffri)), FuelDemand(ua,ffri,mo))  =E=  FuelDemandFreeSum(ffri) / card(mo);
ff = [ifa for ifa in ixfa if (ifa in ixffri) and (ifa not in ixfsto)]
if nmo >= 2:
    allEqns['FuelMinFreeNonStorable'] = \
      [[m.add_constr( xsum(vFuelDemand[imo][iua][iffri] for iua in ixua if u2f[iua,iffri]) == vFuelDemandFreeSum[ifk],
        name='FuelMinFreeNonStorable[{0}]'.format(idx2f[iffri]) ) for ifk,iffri in enumerate(ixffri) ] for imo in ixmo]

# ZQ_MaxTonnage(ua,mo) $OnU(ua) .. sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * KapTon(ua);
allEqns['MaxTonnage'] = [[m.add_constr( xsum(vFuelDemand[imo][iua][ifa] for ifa in ixfa if u2f[iua,ifa]) <= shareAvailU[imo,iua] * hours[imo] * kapTon[iua] , 
                          name='MaxTonnage[{0}][{1}]'.format(months[imo],idx2u[iua])) for iua in ixua] for imo in ixmo]

# ZQ_MinLhvAffald(ua,mo) $OnU(ua)  ..  MinLhvMWh(ua) * sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo))  =L=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * LhvMWh(fa));
allEqns['MinLhvAffald'] = [[m.add_constr(
                           MinLhvMWh[iua] * xsum(vFuelDemand[imo][iua][ifa] for ifa in ixfa if u2f[iua,ifa]) 
                           <= xsum(vFuelDemand[imo][iua][ifa] * lhvMWh[ifa] for ifa in ixfa if u2f[iua,ifa]), 
                           name='MinLhvAffald[{0}][{1}]' ) for iua in ixua] for imo in ixmo]

#end region Equations
#%%
m.write('RefaMainMip.lp')
#----------------------------------------------------------------------------------------------------
#%% Solving the model

#region Providing initial feasible solution.

# See: https://docs.python-mip.com/en/latest/custom.html#providing-initial-feasible-solutions

# inits = [(vbOnU[imo][ixur[0]], 1.0) for imo in ixmo]
# m.start(inits)

#%%

f = io.open('constraints.txt',mode='w')
# c:mp.entities.Constr 
for i,c in enumerate(m.constrs):
    if 2 <= i <=5:
        f.write('\n{0:4d}\t{1:35}\t{2}'.format(i,c.name,c.expr))
        print(i,c.name,': ', c.expr) #---, str(c),c)
f.close()

#%%

#region Displaying the model equations

def printEqn(eqns):
    print(str(eqns))
    if type(eqns) != list:
        print('{0} = {1}'.format(eqns.name.ljust(35), str(eqns)))
    else:
        for e in eqns.items:
            printEqn(e)

for name,eqns in allEqns.items():
    print('{0}:'.format(name))
    printEqn(eqns)

#endregion 

#%%

m.sense = mp.MAXIMIZE
m.start

optStats : mp.OptimizationStatus = m.optimize(max_seconds=30)

if optStats.value == optStats.INFEASIBLE:
    culprits = m.validate_mip_start()

# Checking if a solution was found.
if m.num_solutions > 0:
    print('{0} solutions were found'.format(m.num_solutions))
    print('NPV={0}\n'.format(objective.x))
    print('\nFuelDemand:')
    print('\n')
    for imo in ixmo:
        for iff in ixf:
            print('FuelDemand[{0}][{1}]'.format(months[imo], idx2f[iff], sum([vFuelDemand[imo][i].x for iup in ixuprod if u2f[iup,iff]])) )

# %%
