$log Entering file: %system.incName%

# Filnavn: RefaDataSetup.gms
# Denne fil inkluderes af RefaMain.gms.
# Indeholder kode til opsætning af data efter scenarie-parsing.


# OBS: Ændring af Schedule eksponeres IKKE som scenarie-variabel.

# Initialisering af aktive perioder (maaneder).
OnM(moall)     = DataProgn('aktiv',moall);
mo(moall)      = no;
mo(moall)      = OnM(moall);
NactiveM       = sum(moall, OnM(moall));
Hours(moall) = 24 * DataProgn('Ndage',moall);
moFirst(moall) = no;
moFirst(mo)    = mo.first;


# Brændsels attributter.
fsto(f)  = DataFuel(f,'Lagerbar') NE 0;
fdis(f)  = DataFuel(f,'Bortskaf') NE 0;
ffri(f)  = DataFuel(f,'Fri')      NE 0 AND fa(f);
fflex(f) = DataFuel(f,'Flex')     NE 0 AND fa(f) AND NOT DataCtrl('FixAffald2021');
display "DEBUG: ffri, fflex =", ffri, fflex;

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
FixAffald2021       = DataCtrl('FixAffald2021') NE 0;
FixAffaldSum        = DataCtrl('FixAffaldSum') NE 0;
DeltaTonAktiv       = DataCtrlRead('DeltaTonAktiv') NE 0;

# SKIP: Initialisering af overordnet rådighed af anlæg, lagre, brændsler og måneder.
# Kan være gjort i scenarie specifikationen.
OnU(u,mo) = DataU(u,'Aktiv',mo);
OnS(s,mo) = DataSto(s,'Aktiv',mo);
OnF(f,mo) = DataFuel(f,'Aktiv');
OnGU(u)   = sum(mo, OnU(u,mo)) GE 1;
OnGS(s)   = sum(mo, OnS(s,mo)) GE 1;
OnGF(f)   = sum(mo, OnF(f,mo)) GE 1;

# Anlægsprioriteter og kompatibilitet.
# Prioriteter kan p.t. IKKE ændres via scenarier.
uprio(up) = no;
uprio2up(up,upa) = no;
Loop (up $(DataU(up,'aktiv',moFirst) NE 0 AND DataU(up,'prioritet',moFirst) GT 0),
  dbup = ord(up);
  uprio(up) = yes;
  Loop (upa $(OnGU(upa) NE 0 AND DataU(upa,'prioritet',moFirst) LT DataU(up,'prioritet',moFirst) AND NOT sameas(up,upa)),
    dbupa = ord(upa);
    uprio2up(up,upa) = yes;
  );
);

u2f(ua,fa,moall) = no;
Loop (fa, 
  u2f('Ovn2',fa,mo) = FuelBounds(fa,'TilOvn2',mo) NE 0;
  u2f('Ovn3',fa,mo) = FuelBounds(fa,'TilOvn3',mo) NE 0;
);

Loop (u,
  Loop (labDataProgn $sameas(u,labDataProgn),
    AvailDaysU(mo,u)  = DataProgn(labDataProgn,mo) $(OnU(u,mo) AND OnM(mo));
    ShareAvailU(u,mo) = max(0.0, min(1.0, AvailDaysU(mo,u) / DataProgn('Ndage',mo) ));
  );
);

# Turbinens rådighed kan højst være lig med Ovn3-rådigheden.
AvailDaysTurb(mo)  = min(AvailDaysU(mo,'Ovn3'), DataProgn('Turbine',mo) $(OnU('Ovn3',mo)));
ShareAvailTurb(mo) = max(0.0, min(1.0, AvailDaysTurb(mo) / DataProgn('Ndage',mo) ));

# Ovn3 er KV-anlæg med mulighed for turbine-bypass-drift.
#OBS: Bypass-drift ændret fra forskrift til optimerings-aspekt, dvs. styret af objektfunktionen.
#     Underkastet en forskrift om bypass er tilladt eller ej i en given måned.
#--- ShareBypass(mo) = max(0.0, min(1.0, DataProgn(mo,'Bypass') / (24 * DataProgn(mo,'Ovn3')) ));
#--- HoursBypass(mo) = DataProgn(mo,'Bypass');
OnBypass(mo) = DataProgn('Bypass',mo);
Peget(mo)    = EgetforbrugKVV * AvailDaysTurb(mo);
#--- display mo, OnGU, OnGF, OnM, Hours, AvailDaysU, ShareAvailU, ShareBypass;


# Produktionsanlæg og kølere.

MinLhvMWh(ua,mo) = DataU(ua,'MinLhv',mo) / 3.6;
MaxLhvMWh(ua,mo) = DataU(ua,'MaxLhv',mo) / 3.6;
MinTon(ua,mo)    = DataU(ua,'MinTon',mo);
MaxTon(ua,mo)    = DataU(ua,'Maxton',mo);
KapMin(u,mo)     = DataU(u, 'KapMin',mo);
KapRgk(ua,mo)    = DataU(ua,'KapRgk',mo);
KapQNom(u,mo)    = DataU(u,'KapQNom',mo);
KapE(u,mo)       = DataU(u,'KapE',mo);
EtaE(u,mo)       = DataU(u,'EtaE',mo);
EtaQ(u,mo)       = DataU(u,'EtaQ',mo);
DvMWhq(u,mo)     = DataU(u,'DvMWhq',mo);
DvTime(u,mo)     = DataU(u,'DvTime',mo);

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
display FirstYear, LastYear, Ofz, EtaE, KapE;
# Opdatér DataU med de tvangsgivne egenskaber.
DataU('Ovn3','EtaE',mo) = EtaE('Ovn3',mo);
DataU('Ovn3','KapE',mo) = KapE('Ovn3',mo);

# Lagre.
Loop (fa, 
  StoLoadInitF('sto1',fa) = DataFuel(fa,'InitSto1');
  StoLoadInitF('sto2',fa) = DataFuel(fa,'InitSto2');
);
# Tids-uafhængige parametre.
StoLoadInitQ(sq)       = DataSto(sq,'LoadInit',moFirst);
StoFirstReset(s)       = DataSto(s,'ResetFirst',moFirst);
StoIntvReset(s)        = DataSto(s,'ResetIntv',moFirst);
StoFirstReset(s)       = ifthen(StoFirstReset(s) EQ 0.0, StoIntvReset(s), min(StoFirstReset(s), StoIntvReset(s)) );

# Tidsafhængige parametre.
StoLoadMin(s,mo)       = DataSto(s,'LoadMin',mo);
StoLoadMax(s,mo)       = DataSto(s,'LoadMax',mo);
StoDLoadMax(s,mo)      = DataSto(s,'DLoadMax',mo);
StoLossRate(s,mo)      = DataSto(s,'LossRate',mo);
StoLoadCostRate(s,mo)  = DataSto(s,'LoadCost',mo);
StoDLoadCostRate(s,mo) = DataSto(s,'DLoadCost',mo);


# Brændsler.
fpospris(f,mo) = yes;
fpospris(f,mo) = FuelBounds(f,'pris',mo) GE 0.0;
fnegpris(f,mo) = NOT fpospris(f,mo);
fbiogen(f)     = fa(f) AND (sum(mo, FuelBounds(f,'CO2kgGJ',mo)) EQ 0);

# DeltaTon er tolerancen på månedstonnagen. Fleksible brændsler har fuld årstonnage til rådighed hver måned (men månedssummen er underlagt den rådige middelmånedsmængde i FuelBounds).
DeltaTon(f)  = IfThen(fflex(f), 1.0, DataFuel(f,'DeltaTon') / 12) * DataFuel(f,'MaxTonnage') $DeltaTonAktiv;
MinTonSum(f) = DataFuel(f,'MinTonnage');
MaxTonSum(f) = DataFuel(f,'MaxTonnage');
LhvMWh(f,mo) = FuelBounds(f,'LHV',mo) / 3.6;
NSprod(mo)   = DataProgn('NSprod',mo);

DoFixAffT(mo) = FixAffaldSum AND (FixValueAffT(mo) NE NaN);

# Emissionsopgørelsen for affald er som udgangspunkt efter skorstensmetoden, hvor CO2-indholdet af  hver fraktion er kendt.
# Men uden skorstensmetoden anvendes i stedet for SKATs emissionssatser, som desuden er forskellige efter om det er CO2-afgift eller CO2-kvoteforbruget, som skal opgøres !!!
CO2potenTon(f,typeCO2,mo) = FuelBounds(f,'LHV',mo) * FuelBounds(f,'CO2kgGJ',mo) / 1000;  # ton CO2 / ton brændsel.
if (NOT SkorstensMetode,
  CO2potenTon(fa,typeCO2,mo) = FuelBounds(fa,'LHV',mo) * [DataProgn('CO2aff',mo) $sameas(typeCO2,'afgift') + DataProgn('ETSaff',mo) $sameas(typeCO2,'kvote')] / 1000;
);
CO2potenTon(fbiogen,typeCO2,mo) = 0.0;

#TODO: Tarif på indfødning af elproduktion på nettet skal flyttes til DataCtrl.
Qdemand(mo)       = DataProgn('Varmebehov',mo);
PowerPrice(mo)    = DataProgn('ELpris',mo);
TariffElProd(mo)  = 4.00;  
TaxAfvMWh(mo)     = DataProgn('AFV',mo) * 3.6;
TaxAtlMWh(mo)     = DataProgn('ATL',mo) * 3.6;
TaxEtsTon(mo)     = DataProgn('ETS',mo);
CO2ContentAff(mo) = DataProgn('CO2aff',mo) * 3.6 / 1E3;   # CO2-indhold i generisk affald [ton CO2 / MWhq] med ref. til den afgiftspligtige varme/energi.
TaxCO2AffTon(mo)  = DataProgn('CO2afgAff',mo);
TaxNOxAffkg(mo)   = DataProgn('NOxAff',mo);
TaxNOxFlisTon(mo) = DataProgn('NOxFlis',mo) * FuelBounds('flis','LHV',mo);
TaxEnrPeakTon(mo) = DataProgn('EnrPeak',mo) * FuelBounds('peakfuel','LHV',mo);
TaxCO2peakTon(mo) = DataProgn('CO2peak',mo);
TaxNOxPeakTon(mo) = DataProgn('NOxPeak',mo);
#--- display MinTonSum, MaxTonSum, LhvMWh, Qdemand, PowerProd, PowerPrice, IncomeElec, TaxAfvMWh, TaxAtlMWh, TaxEtsTon, TaxCO2AffTon, TaxCO2peakTon;

# Special-haandtering af oevre graense for Nordic Sugar varme.
FuelBounds('NSvarme','MaxTonnage',mo) = DataProgn('NS',mo);

# Diverse øvre grænser for varmeproduktion og lageromkostning.
# QbypassMax er baseret på el-kapaciteten af Ovn3
# QtotalAffMax er baseret på rådig affaldstonnage.
#BUGFIX: QbypassMax skal være uafhængig af turbinens rådighed, men blot afhængig af Ovn3-rådigheden.
#        Når turbinen er ude, kan dampen fra el-egetforbruget også anvendes til bypass-varme.
#        QbypassMax begrænser også QtotalAffMax og dermed modtryksproduktionen på ovnene.
#--- QbypassMax(mo)    = ShareAvailTurb(mo) * Hours(mo) * KapE('Ovn3',mo) - Peget(mo);  # Peget har taget højde for turbinens rådighed.
QbypassMax(mo)    = ShareAvailU('Ovn3',mo) * Hours(mo) * KapE('Ovn3',mo) - Peget(mo) + AvailDaysTurb(mo) * EgetforbrugKVV; 
QtotalAffMax(mo)  = sum(ua $OnU(ua,mo), ShareAvailU(ua,mo) * (EtaQ(ua,mo) + EtaRgk(ua,mo)) 
                                         * sum(fa $(OnF(fa,mo) AND u2f(ua,fa,mo)), LhvMWh(fa,mo) * FuelBounds(fa,'MaxTonnage',mo)) ) + QbypassMax(mo);
StoCostLoadMax(s) = smax(mo, StoLoadMax(s,mo) * StoLoadCostRate(s,mo));
display ShareAvailU, EtaQ, EtaRgk, LhvMwh;
display QtotalAffMax, QbypassMax, StoCostLoadMax;

# EaffGross skal være mininum af energiindhold af rådige mængder affald hhv. affaldsanlæggets fuldlastkapacitet.
# Hvis affaldstonnager er fikseret, skal begrænsningen i QaffMmax lempes.
QaffMmax(ua,mo) = min(ShareAvailU(ua,mo) * Hours(mo) * KapQNom(ua,mo), [sum(fa $(OnF(fa,mo) AND u2f(ua,fa,mo)), EtaQ(ua,mo) * LhvMWh(fa,mo) * FuelBounds(fa,'MaxTonnage',mo) )]) $OnU(ua,mo);
Loop (mo $DoFixAffT(mo), 
  QaffMmax(ua,mo) =  ShareAvailU(ua,mo) * Hours(mo) * KapQNom(ua,mo) $OnU(ua,mo);
);
QrgkMax(ua,mo)   = KapRgk(ua,mo) / KapQNom(ua,mo) * QaffMmax(ua,mo);
QaffTotalMax(mo) = sum(ua $OnU(ua,mo), ShareAvailU(ua,mo) * (QaffMmax(ua,mo) + QrgkMax(ua,mo)) );

TaxATLMax(mo)   = sum(ua $OnU(ua,mo), ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua,mo)) * TaxAtlMWh(mo);
RgkRabatMax(mo) = RgkRabatSats * TaxATLMax(mo);
QRgkMissMax(mo) = 2 * RgkRabatMinShare * sum(ua $OnU(ua,mo), 31 * 24 * KapQNom(ua,mo));  # Faktoren 2 er en sikkerhedsfaktor mod infeasibilitet.

$If not errorfree $exit

#end Opsætning af sets og parametre afledt fra inputdata.
