
# Denne fil inkluderes af RefaMain.gms.

# Initialisering af overordnet rådighed af anlæg, lagre, brændsler og måneder.
OnGU(u)         = DataU(u,'aktiv');
OnGF(f)         = DataFuel(f,'aktiv');
OnGS(s)         = DataSto(s,'aktiv');
OnM(moall)      = DataProgn(moall,'aktiv');
DvMWhq(u,moall) = DataU(u,'DVMWhq');
DvTime(u,moall) = DataU(u,'DvTime');
EtaQ(u,moall)   = DataU(u,'EtaQ')
EtaRgk(u,moall) = DataU(u,'EtaRgk')

OnU(u,mo)       = OnGU(u);
OnS(s,mo)       = OnGS(s);
OnF(f,mo)       = OnGF(f);
Hours(moall)    = 24 * DataProgn(moall,'ndage');

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

Loop (u $OnU(u,mo),
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


# Produktionsanlæg og kølere.

MinLhvMWh(ua,moall) = DataU(ua,'MinLhv') / 3.6;
MaxLhvMWh(ua,moall) = DataU(ua,'MaxLhv') / 3.6;
MinTon(ua,moall)    = DataU(ua,'MinTon');
MaxTon(ua,moall)    = DataU(ua,'Maxton');
KapMin(u,moall)     = DataU(u, 'KapMin');
KapRgk(ua,moall)    = DataU(ua,'KapRgk');
KapNom(u,moall)     = DataU(u,'KapQNom');
KapE(u,moall)       = DataU(u,'KapE');
EtaE(u,moall)       = DataU(u,'EtaE');
EtaQ(u,moall)       = DataU(u,'EtaQ');
EtaRgk(u,moall)     = DataU(u,'KapRgk') / DataU(u,'KapQNom') * EtaQ(u);
DvMWhq(u,moall)     = DataU(u,'DvMWhq');
DvTime(u,moall)     = DataU(u,'DvTime');
KapMax(u,moall)     = KapNom(u) + KapRgk(u);

# EtaE er 18 % til og med august 2021, og derefter antages værdien givet i DataU.
# KapE er 7,5 MWe til og med august 2021, og derefter antages værdien givet i DataU.
if (Schedule('aar','FirstYear') EQ 2021,
  Loop (moall $(ord(moall) GE 1 AND ord(moall) LE 8+1),   # OBS: moall starter med element mo0, derfor 8+1 t.o.m. august. 
    EtaE('Ovn3', moall) = 0.18;
    KapE('Ovn3', moall) = 7.5;
  );
);

# Lagre.
Loop (fa, 
  StoLoadInitF('sto1',fa) = DataFuel(fa,'InitSto1');  #--- $DataFuel(fa,'InitSto1') GE 0.0;      
  StoLoadInitF('sto2',fa) = DataFuel(fa,'InitSto2');  #--- $DataFuel(fa,'InitSto2') GE 0.0;      
);
StoLoadInitQ(sq) = DataSto(sq,'LoadInit');

StoLoadMin(s,mo)       = DataSto(s,'LoadMin');
StoLoadMax(s,mo)       = DataSto(s,'LoadMax');
StoDLoadMax(s,mo)      = DataSto(s,'DLoadMax');
StoLoadCostRate(s,mo)  = DataSto(s,'LoadCost');
StoDLoadCostRate(s,mo) = DataSto(s,'DLoadCost');
StoLossRate(s,mo)      = DataSto(s,'LossRate');
StoFirstReset(s)       = DataSto(s,'ResetFirst');
StoIntvReset(s)        = DataSto(s,'ResetIntv');
StoFirstReset(s)       = ifthen(StoFirstReset(s) EQ 0.0, StoIntvReset(s), min(StoFirstReset(s), StoIntvReset(s)) );

# Brændsler.
fpospris(f,moall) = yes;
fpospris(f,moall) = DataFuel(f,'pris') GE 0.0;
fnegpris(f,moall) = NOT fpospris(f,moall);
fbiogen(f)        = fa(f) AND (DataFuel(f,'CO2kgGJ') EQ 0);

MinTonnageYear(f) = DataFuel(f,'minTonnage');
MaxTonnageYear(f) = DataFuel(f,'maxTonnage');
LhvMWh(f,mo)      = DataFuel(f,'brandv') / 3.6;

DoFixAffT(mo) = FixAffald AND (FixValueAffT(mo) NE NaN);

# Emissionsopgørelsen for affald er som udgangspunkt efter skorstensmetoden, hvor CO2-indholdet af  hver fraktion er kendt.
# Men uden skorstensmetoden anvendes i stedet for SKATs emissionssatser, som desuden er forskellige efter om det er CO2-afgift eller CO2-kvoteforbruget, som skal opgøres !!!
CO2potenTon(f,typeCO2,mo) = DataFuel(f,'brandv') * DataFuel(f,'CO2kgGJ') / 1000;  # ton CO2 / ton brændsel.
if (NOT SkorstensMetode,
  CO2potenTon(fa,typeCO2,mo) = DataFuel(fa,'brandv') * [DataProgn(mo,'CO2aff') $sameas(typeCO2,'afgift') + DataProgn(mo,'ETSaff') $sameas(typeCO2,'kvote')] / 1000;
);
CO2potenTon(fbiogen,typeCO2,mo) = 0.0;

Qdemand(mo)       = DataProgn(mo,'Varmebehov');
#--- PowerProd(mo)     = DataProgn(mo,'ELprod');
PowerPrice(mo)    = DataProgn(mo,'ELpris');
#TODO: Tarif på indfødning af elproduktion på nettet skal flyttes til DataCtrl.
TariffElProd(mo)  = 4.00;  
#--- IncomeElec(mo)    = PowerProd(mo) * PowerPrice(mo) $OnGU('Ovn3');
TaxAfvMWh(mo)     = DataProgn(mo,'AFV') * 3.6;
TaxAtlMWh(mo)     = DataProgn(mo,'ATL') * 3.6;
TaxEtsTon(mo)     = DataProgn(mo,'ETS');
CO2ContentAff(mo) = DataProgn(mo,'CO2aff') * 3.6 / 1E3;   # CO2-indhold i generisk affald [ton CO2 / MWhq] med ref. til den afgiftspligtige varme/energi.
TaxCO2AffTon(mo)  = DataProgn(mo,'CO2afgAff');
TaxNOxAffkg(mo)   = DataProgn(mo,'NOxAff');
TaxNOxFlisTon(mo) = DataProgn(mo,'NOxFlis') * DataFuel('flis','brandv');
TaxEnrPeakTon(mo) = DataProgn(mo,'EnrPeak') * DataFuel('peakfuel','brandv');
TaxCO2peakTon(mo) = DataProgn(mo,'CO2peak');
TaxNOxPeakTon(mo) = DataProgn(mo,'NOxPeak');
#--- display MinTonnageYear, MaxTonnageYear, LhvMWh, Qdemand, PowerProd, PowerPrice, IncomeElec, TaxAfvMWh, TaxAtlMWh, TaxEtsTon, TaxCO2AffTon, TaxCO2peakTon;

# Special-haandtering af oevre graense for Nordic Sugar varme.
FuelBounds('NSvarme','max',moall) = DataProgn(moall,'NS');

# Diversen øvre grænser for varmeproduktion og lageromkostning.
QbypassMax(mo)    = ShareAvailTurb(mo) * Hours(mo) * KapE('Ovn3',mo)  - Peget(mo);  # Peget har taget højde for turbinens rådighed.
QtotalAffMax(mo)  = sum(ua $OnU(ua,mo), (EtaQ(ua) + EtaRgk(ua)) * sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), LhvMWh(fa,mo) * LhvMWh(fa,mo)) ) + QbypassMax(mo);
StoCostLoadMax(s) = smax(mo, StoLoadMax(s,mo) * StoLoadCostRate(s,mo));

display QtotalAffMax, QbypassMax, StoCostLoadMax;

# EaffGross skal være mininum af energiindhold af rådige mængder affald hhv. affaldsanlæggets fuldlastkapacitet.
# Hvis affaldstonnager er fikseret, skal begrænsningen i QaffMmax lempes.
QaffMmax(ua,moall) = min(ShareAvailU(ua,moall) * Hours(moall) * KapNom(ua), [sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), FuelBounds(fa,'max',moall) * EtaQ(ua) * LhvMWh(fa,mo))]) $OnU(ua,mo);
Loop (mo $DoFixAffT(mo), 
  QaffMmax(ua,mo) =  ShareAvailU(ua,mo) * Hours(mo) * KapNom(ua);
);
QrgkMax(ua,moall)   = KapRgk(ua) / KapNom(ua) * QaffMmax(ua,moall);
QaffTotalMax(moall) = sum(ua $OnU(ua,mo), ShareAvailU(ua,moall) * (QaffMmax(ua,moall) + QrgkMax(ua,moall)) );

TaxATLMax(mo) = sum(ua $OnU(ua,mo), ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua)) * TaxAtlMWh(mo);
RgkRabatMax(mo) = RgkRabatSats * TaxATLMax(mo);
QRgkMissMax = 2 * RgkRabatMinShare * sum(ua $OnU(ua,mo), 31 * 24 * KapNom(ua));  # Faktoren 2 er en sikkerhedsfaktor mod infeasibilitet.

$If not errorfree $exit

#end Opsætning af sets og parametre afledt fra inputdata.
