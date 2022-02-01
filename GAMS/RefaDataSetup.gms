$log Entering file: %system.incName%

# Filnavn: RefaDataSetup.gms
# Denne fil inkluderes af RefaMain.gms.
# Indeholder kode til opsætning af data efter scenarie-parsing.


# OBS: Ændring af Schedule eksponeres IKKE som scenarie-variabel.


# Brændsels attributter.
fsto(f)  = DataFuel(f,'Lagerbar') NE 0;
fdis(f)  = DataFuel(f,'Bortskaf') NE 0;
ffri(f)  = DataFuel(f,'Fri')      NE 0 AND fa(f);
fflex(f) = DataFuel(f,'Flex')     NE 0 AND fa(f);

OnM(moall)   = DataProgn(moall,'aktiv');

# Overførsel af parametre på overordnet modelniveau.
IncludeOwner('gsf') = DataCtrl('IncludeGSF') NE 0;
OnQInfeas           = DataCtrl('VirtuelVarme') NE 0;
OnAffTInfeas        = DataCtrl('VirtuelAffald') NE 0;
RgkRabatSats        = DataCtrl('RgkRabatSats');
RgkRabatMinShare    = DataCtrl('RgkAndelRabat');
VarmeSalgspris      = DataCtrl('VarmeSalgspris');
SkorstensMetode     = DataCtrl('SkorstensMetode');
EgetforbrugKVV      = DataCtrl('EgetforbrugKVV');
RunScenarios        = DataCtrl('RunScenarios') NE 0;
FixAffald           = DataCtrl('FixAffald') NE 0;

# SKIP: Initialisering af overordnet rådighed af anlæg, lagre, brændsler og måneder.
# Kan være gjort i scenarie specifikationen.

# SKIP: OnU, OnS og OnF kan være modificeret af scenariet specifikationen.
OnGU(u)   = sum(mo, OnU(u,mo)) GE 1;
OnGS(s)   = sum(mo, OnS(s,mo)) GE 1;
OnGF(f)   = sum(mo, OnF(f,mo)) GE 1;

# SKIP: Hours(moall) = 24 * DataProgn(moall,'Ndage');

# Initialisering af aktive perioder (maaneder).
mo(moall) = no;
mo(moall) = OnM(moall);
NactiveM  = sum(moall, OnM(moall));

# Anlægsprioriteter og kompatibilitet.
uprio(up) = no;
uprio2up(up,upa) = no;
Loop (up $(DataU(up,'aktiv') NE 0 AND DataU(up,'prioritet') GT 0),
  dbup = ord(up);
  uprio(up) = yes;
  Loop (upa $(DataU(upa,'aktiv') NE 0 AND DataU(upa,'prioritet') LT DataU(up,'prioritet') AND NOT sameas(up,upa)),
    dbupa = ord(upa);
    uprio2up(up,upa) = yes;
  );
);

u2f(ua,fa) = no;
Loop (fa, 
  u2f('Ovn2',fa) = DataFuel(fa,'TilOvn2') NE 0;
  u2f('Ovn3',fa) = DataFuel(fa,'TilOvn3') NE 0;
);

Loop (u,
  Loop (labDataProgn $sameas(u,labDataProgn),
    AvailDaysU(mo,u)  = DataProgn(mo,labDataProgn) $(OnU(u,mo) AND OnM(mo));
    ShareAvailU(u,mo) = max(0.0, min(1.0, AvailDaysU(mo,u) / DataProgn(mo,'Ndage') ));
  );
);

# Turbinens rådighed kan højst være lig med Ovn3-rådigheden.
AvailDaysTurb(mo)  = min(AvailDaysU(mo,'Ovn3'), DataProgn(mo,'Turbine') $(OnU('Ovn3',mo)));
ShareAvailTurb(mo) = max(0.0, min(1.0, AvailDaysTurb(mo) / DataProgn(mo,'Ndage') ));

# Ovn3 er KV-anlæg med mulighed for turbine-bypass-drift.
#OBS: Bypass-drift ændret fra forskrift til optimerings-aspekt, dvs. styret af objektfunktionen.
#     Underkastet en forskrift om bypass er tilladt eller ej i en given måned.
#--- ShareBypass(mo) = max(0.0, min(1.0, DataProgn(mo,'Bypass') / (24 * DataProgn(mo,'Ovn3')) ));
#--- HoursBypass(mo) = DataProgn(mo,'Bypass');
OnBypass(mo) = DataProgn(mo,'Bypass');
Peget(mo)    = EgetforbrugKVV * (AvailDaysTurb(mo));
#--- Peget(mo)       = EgetforbrugKVV * (AvailDaysU(mo,'Ovn3'));  #---   - HoursBypass(mo));
#--- display mo, OnGU, OnGF, OnM, Hours, AvailDaysU, ShareAvailU, ShareBypass;


# SKIP: Produktionsanlæg og kølere.

# SKIP: --- MinLhvMWh(ua,mo) = DataU(ua,'MinLhv') / 3.6;
# SKIP: --- MaxLhvMWh(ua,mo) = DataU(ua,'MaxLhv') / 3.6;
# SKIP: --- MinTon(ua,mo)    = DataU(ua,'MinTon');
# SKIP: --- MaxTon(ua,mo)    = DataU(ua,'Maxton');
# SKIP: --- KapMin(u,mo)     = DataU(u, 'KapMin');
# SKIP: --- KapRgk(ua,mo)    = DataU(ua,'KapRgk');
# SKIP: --- KapQNom(u,mo)    = DataU(u,'KapQNom');
# SKIP: --- KapE(u,mo)       = DataU(u,'KapE');
# SKIP: --- EtaE(u,mo)       = DataU(u,'EtaE');
# SKIP: --- EtaQ(u,mo)       = DataU(u,'EtaQ');
# SKIP: --- DvMWhq(u,mo)     = DataU(u,'DvMWhq');
# SKIP: --- DvTime(u,mo)     = DataU(u,'DvTime');

EtaRgk(u,mo) = KapRgk(u,mo) / KapQNom(u,mo) * EtaQ(u,mo);
KapMax(u,mo) = KapQNom(u,mo) + KapRgk(u,mo);

# EtaE er 18 % til og med august 2021, og derefter antages værdien givet i DataU.
# KapE er 7,5 MWe til og med august 2021, og derefter antages værdien givet i DataU.
FirstYear = Schedule('aar','FirstYear');
LastYear  = Schedule('aar','LastYear');
if (FirstYear LE 2021 AND LastYear GE 2021,
  Ofz = 12 * (2021 - FirstYear);
  Loop (moall $(ord(moall) GE (Ofz + 1) AND ord(moall) LE Ofz + (8+1)),   # OBS: moall starter med element mo0, derfor 8+1 t.o.m. august. 
    EtaE('Ovn3', moall) = 0.18;
    KapE('Ovn3', moall) = 7.5;
  );
);

# Lagre.
# SKIP: --- Loop (fa, 
# SKIP: ---   StoLoadInitF('sto1',fa) = DataFuel(fa,'InitSto1');  #--- $DataFuel(fa,'InitSto1') GE 0.0;      
# SKIP: ---   StoLoadInitF('sto2',fa) = DataFuel(fa,'InitSto2');  #--- $DataFuel(fa,'InitSto2') GE 0.0;      
# SKIP: --- );
# SKIP: --- StoLoadInitQ(sq) = DataSto(sq,'LoadInit');
# SKIP: --- StoLoadMin(s,mo)       = DataSto(s,'LoadMin');
# SKIP: --- StoLoadMax(s,mo)       = DataSto(s,'LoadMax');
# SKIP: --- StoDLoadMax(s,mo)      = DataSto(s,'DLoadMax');
# SKIP: --- StoLossRate(s,mo)      = DataSto(s,'LossRate');
# SKIP: --- StoLoadCostRate(s,mo)  = DataSto(s,'LoadCost');
# SKIP: --- StoDLoadCostRate(s,mo) = DataSto(s,'DLoadCost');
# SKIP: --- StoFirstReset(s)       = DataSto(s,'ResetFirst');
# SKIP: --- StoIntvReset(s)        = DataSto(s,'ResetIntv');

StoFirstReset(s)       = ifthen(StoFirstReset(s) EQ 0.0, StoIntvReset(s), min(StoFirstReset(s), StoIntvReset(s)) );

# Brændsler.
fpospris(f,mo) = yes;
fpospris(f,mo) = FuelBounds(f,'pris',mo) GE 0.0;
fnegpris(f,mo) = NOT fpospris(f,mo);
fbiogen(f)     = fa(f) AND (sum(mo, FuelBounds(f,'CO2kgGJ',mo)) EQ 0);

MinTonnageYear(f) = DataFuel(f,'MinTonnage');
MaxTonnageYear(f) = DataFuel(f,'MaxTonnage');
LhvMWh(f,mo)      = FuelBounds(f,'LHV',mo) / 3.6;
NSprod(mo)        = DataProgn(mo,'NSprod');

DoFixAffT(mo) = FixAffald AND (FixValueAffT(mo) NE NaN);

# Emissionsopgørelsen for affald er som udgangspunkt efter skorstensmetoden, hvor CO2-indholdet af  hver fraktion er kendt.
# Men uden skorstensmetoden anvendes i stedet for SKATs emissionssatser, som desuden er forskellige efter om det er CO2-afgift eller CO2-kvoteforbruget, som skal opgøres !!!
CO2potenTon(f,typeCO2,mo) = DataFuel(f,'LHV') * DataFuel(f,'CO2kgGJ') / 1000;  # ton CO2 / ton brændsel.
if (NOT SkorstensMetode,
  CO2potenTon(fa,typeCO2,mo) = DataFuel(fa,'LHV') * [DataProgn(mo,'CO2aff') $sameas(typeCO2,'afgift') + DataProgn(mo,'ETSaff') $sameas(typeCO2,'kvote')] / 1000;
);
CO2potenTon(fbiogen,typeCO2,mo) = 0.0;

#TODO: Tarif på indfødning af elproduktion på nettet skal flyttes til DataCtrl.
Qdemand(mo)       = DataProgn(mo,'Varmebehov');
PowerPrice(mo)    = DataProgn(mo,'ELpris');
TariffElProd(mo)  = 4.00;  
TaxAfvMWh(mo)     = DataProgn(mo,'AFV') * 3.6;
TaxAtlMWh(mo)     = DataProgn(mo,'ATL') * 3.6;
TaxEtsTon(mo)     = DataProgn(mo,'ETS');
CO2ContentAff(mo) = DataProgn(mo,'CO2aff') * 3.6 / 1E3;   # CO2-indhold i generisk affald [ton CO2 / MWhq] med ref. til den afgiftspligtige varme/energi.
TaxCO2AffTon(mo)  = DataProgn(mo,'CO2afgAff');
TaxNOxAffkg(mo)   = DataProgn(mo,'NOxAff');
TaxNOxFlisTon(mo) = DataProgn(mo,'NOxFlis') * DataFuel('flis','LHV');
TaxEnrPeakTon(mo) = DataProgn(mo,'EnrPeak') * DataFuel('peakfuel','LHV');
TaxCO2peakTon(mo) = DataProgn(mo,'CO2peak');
TaxNOxPeakTon(mo) = DataProgn(mo,'NOxPeak');
#--- display MinTonnageYear, MaxTonnageYear, LhvMWh, Qdemand, PowerProd, PowerPrice, IncomeElec, TaxAfvMWh, TaxAtlMWh, TaxEtsTon, TaxCO2AffTon, TaxCO2peakTon;

# Special-haandtering af oevre graense for Nordic Sugar varme.
FuelBounds('NSvarme','MaxTonnage',moall) = DataProgn(moall,'NS');

# Diversen øvre grænser for varmeproduktion og lageromkostning.
QbypassMax(mo)    = ShareAvailTurb(mo) * Hours(mo) * KapE('Ovn3',mo)  - Peget(mo);  # Peget har taget højde for turbinens rådighed.
QtotalAffMax(mo)  = sum(ua $OnU(ua,mo), (EtaQ(ua,mo) + EtaRgk(ua,mo)) * sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), LhvMWh(fa,mo) * LhvMWh(fa,mo)) ) + QbypassMax(mo);
StoCostLoadMax(s) = smax(mo, StoLoadMax(s,mo) * StoLoadCostRate(s,mo));

display QtotalAffMax, QbypassMax, StoCostLoadMax;

# EaffGross skal være mininum af energiindhold af rådige mængder affald hhv. affaldsanlæggets fuldlastkapacitet.
# Hvis affaldstonnager er fikseret, skal begrænsningen i QaffMmax lempes.
QaffMmax(ua,mo) = min(ShareAvailU(ua,mo) * Hours(mo) * KapQNom(ua,mo), [sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), FuelBounds(fa,'MaxTonnage',mo) * EtaQ(ua,mo) * LhvMWh(fa,mo))]) $OnU(ua,mo);
Loop (mo $DoFixAffT(mo), 
  QaffMmax(ua,mo) =  ShareAvailU(ua,mo) * Hours(mo) * KapQNom(ua,mo);
);
QrgkMax(ua,mo)   = KapRgk(ua,mo) / KapQNom(ua,mo) * QaffMmax(ua,mo);
QaffTotalMax(mo) = sum(ua $OnU(ua,mo), ShareAvailU(ua,mo) * (QaffMmax(ua,mo) + QrgkMax(ua,mo)) );

TaxATLMax(mo)   = sum(ua $OnU(ua,mo), ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua,mo)) * TaxAtlMWh(mo);
RgkRabatMax(mo) = RgkRabatSats * TaxATLMax(mo);
QRgkMissMax(mo) = 2 * RgkRabatMinShare * sum(ua $OnU(ua,mo), 31 * 24 * KapQNom(ua,mo));  # Faktoren 2 er en sikkerhedsfaktor mod infeasibilitet.

$If not errorfree $exit

#end Opsætning af sets og parametre afledt fra inputdata.


 
#TODO: Fjern Scen_Progn, som erstattes af ScenRecs.

#--- if (ord(scen) GT 1,
#---   DataProgn(mo,labPrognScen) = DataPrognSaved(mo,labPrognScen);
#--- 
#---   # Kun ikke-NaN parametre overføres fra scenariet.
#---   Loop (labPrognScen,
#---     if (Scen_Progn(actScen,labPrognScen) NE NaN,
#---       DataProgn(mo,labPrognScen) = Scen_Progn(actScen,labPrognScen);
#---     );
#---   );
#--- );

