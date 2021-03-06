$log Entering file: %system.incName%

# Filnavn: RefaDataReset.gms
#  Denne fil inkluderes af RefaMain.gms.
# Indeholder kode til tilbagestiling af inputdata før scenarie-parsing.

# Først tilbagestilles påvirkede parametre til udgangspunktet.
if (NOT sameas(actScen,'scen0'),
  DataCtrl(labDataCtrl)           = DataCtrlRead(labDataCtrl);  
  Schedule(labSchRow,labSchCol)   = ScheduleRead(labSchRow,labSchCol); 
  DataU(u,labDataU,mo)            = DataURead(u,labDataU);   
  DataSto(s,labDataSto,mo)        = DataStoRead(s,labDataSto);  
  DataProgn(labDataProgn,mo)      = DataPrognRead(mo,labDataProgn);  
  DataFuel(f,labDataFuel)         = DataFuelRead(f,labDataFuel);  
  FuelBounds(f,fuelItem,mo)       = FuelBoundsRead(f,fuelItem,mo);
);
# OBS: Ændring af Schedule eksponeres ikke som scenarie-variabel.



#--- # Brændsels attributter.
#--- fsto(f)  = DataFuel(f,'Lagerbar') NE 0;
#--- fdis(f)  = DataFuel(f,'Bortskaf') NE 0;
#--- ffri(f)  = DataFuel(f,'Fri')      NE 0 AND fa(f);
#--- fflex(f) = DataFuel(f,'Flex')     NE 0 AND fa(f);
#--- 
#--- # OBS: Ændring af Schedule eksponeres ikke som scenarie-variabel.
#--- 
#--- # Overførsel af parametre på overordnet modelniveau.
#--- IncludeOwner('gsf') = DataCtrl('IncludeGSF') NE 0;
#--- OnQInfeas           = DataCtrl('VirtuelVarme') NE 0;
#--- OnAffTInfeas        = DataCtrl('VirtuelAffald') NE 0;
#--- RgkRabatSats        = DataCtrl('RgkRabatSats');
#--- RgkRabatMinShare    = DataCtrl('RgkAndelRabat');
#--- VarmeSalgspris      = DataCtrl('VarmeSalgspris');
#--- SkorstensMetode     = DataCtrl('SkorstensMetode');
#--- EgetforbrugKVV      = DataCtrl('EgetforbrugKVV');
#--- RunScenarios        = DataCtrl('RunScenarios') NE 0;
#--- FixAffaldSum           = DataCtrl('FixAffaldSum') NE 0;
#--- 
#--- # Initialisering af overordnet rådighed af anlæg, lagre, brændsler og måneder.
#--- # Initialisering af aktive perioder (maaneder).
#--- mo(moall)  = no;
#--- OnM(moall) = DataProgn('aktiv',moall);
#--- mo(moall)  = OnM(moall);
#--- NactiveM   = sum(moall, OnM(moall));
#--- 
#--- DvMWhq(u,mo) = DataU(u,'DVMWhq');
#--- DvTime(u,mo) = DataU(u,'DvTime');
#--- EtaQ(u,mo)   = DataU(u,'EtaQ');
#--- 
#--- OnU(u,mo) = DataU(u,'Aktiv');
#--- OnS(s,mo) = DataSto(s,'Aktiv');
#--- OnF(f,mo) = DataFuel(f,'Aktiv');
#--- OnGU(u)   = sum(mo, OnU(u,mo)) GE 1;
#--- OnGS(s)   = sum(mo, OnS(s,mo)) GE 1;
#--- OnGF(f)   = sum(mo, OnF(f,mo)) GE 1;
#--- 
#--- Hours(moall) = 24 * DataProgn(moall,'Ndage');
#--- 
#--- # Anlægsprioriteter og kompatibilitet.
#--- uprio(up) = no;
#--- uprio2up(up,upa) = no;
#--- Loop (up $(DataURead(up,'aktiv') NE 0 AND DataURead(up,'prioritet') GT 0),
#---   dbup = ord(up);
#---   uprio(up) = yes;
#---   Loop (upa $(DataURead(upa,'aktiv') NE 0 AND DataURead(upa,'prioritet') LT DataURead(up,'prioritet') AND NOT sameas(up,upa)),
#---     dbupa = ord(upa);
#---     uprio2up(up,upa) = yes;
#---   );
#--- );
#--- 
#--- u2f(ua,fa,mo) = no;
#--- Loop (fa, 
#---   u2f('Ovn2',fa,mo) = DataFuel(fa,'TilOvn2',mo) NE 0;
#---   u2f('Ovn3',fa,mo) = DataFuel(fa,'TilOvn3',mo) NE 0;
#--- );
#--- 
#--- Loop (u,
#---   Loop (labDataProgn $sameas(u,labDataProgn),
#---     AvailDaysU(mo,u)  = DataProgn(labDataProgn,mo) $OnU(u,mo);
#---     ShareAvailU(u,mo) = max(0.0, min(1.0, AvailDaysU(mo,u) / DataProgn('Ndage',mo) ));
#---   );
#--- );
#--- 
#--- # Turbinens rådighed kan højst være lig med Ovn3-rådigheden.
#--- AvailDaysTurb(mo)  = min(AvailDaysU(mo,'Ovn3'), DataProgn('Turbine',mo) $(OnU('Ovn3',mo)));
#--- ShareAvailTurb(mo) = max(0.0, min(1.0, AvailDaysTurb(mo) / DataProgn('Ndage',mo) ));
#--- 
#--- # Ovn3 er KV-anlæg med mulighed for turbine-bypass-drift.
#--- #OBS: Bypass-drift ændret fra forskrift til optimerings-aspekt, dvs. styret af objektfunktionen.
#--- #     Underkastet en forskrift om bypass er tilladt eller ej i en given måned.
#--- #--- ShareBypass(mo) = max(0.0, min(1.0, DataProgn(mo,'Bypass') / (24 * DataProgn(mo,'Ovn3')) ));
#--- #--- HoursBypass(mo) = DataProgn(mo,'Bypass');
#--- OnBypass(mo) = DataProgn('Bypass',mo);
#--- Peget(mo)    = EgetforbrugKVV * AvailDaysTurb(mo);
#--- #--- Peget(mo)       = EgetforbrugKVV * (AvailDaysU(mo,'Ovn3'));  #---   - HoursBypass(mo));
#--- display mo, OnGU, OnGF, OnM, Hours, AvailDaysU, ShareAvailU, ShareBypass;
#--- 
# Produktionsanlæg og kølere.
#--- MinLhvMWh(ua,mo) = DataU(ua,'MinLhv') / 3.6;
#--- MaxLhvMWh(ua,mo) = DataU(ua,'MaxLhv') / 3.6;
#--- MinTon(ua,mo)    = DataU(ua,'MinTon');
#--- MaxTon(ua,mo)    = DataU(ua,'Maxton');
#--- KapQmin(u,mo)     = DataU(u, 'KapQmin');
#--- KapRgk(ua,mo)    = DataU(ua,'KapRgk');
#--- KapQNom(u,mo)    = DataU(u,'KapQNom');
#--- KapE(u,mo)       = DataU(u,'KapE');
#--- EtaE(u,mo)       = DataU(u,'EtaE');
#--- EtaQ(u,mo)       = DataU(u,'EtaQ');
#--- EtaRgk(u,mo)     = KapRgk(u,mo) / KapQNom(u,mo) * EtaQ(u,mo);
#--- DvMWhq(u,mo)     = DataU(u,'DvMWhq');
#--- DvTime(u,mo)     = DataU(u,'DvTime');
#--- KapQmax(u,mo)     = KapQNom(u,mo) + KapRgk(u,mo);
#---
#--- # EtaE er 18 % til og med august 2021, og derefter antages værdien givet i DataU.
#--- # KapE er 7,5 MWe til og med august 2021, og derefter antages værdien givet i DataU.
#--- FirstYear = Schedule('aar','FirstYear');
#--- LastYear  = Schedule('aar','LastYear');
#--- if (FirstYear LE 2021 AND LastYear GE 2021,
#---   Ofz = 12 * (2021 - FirstYear);
#---   Loop (moall $(ord(moall) GE (Ofz + 1) AND ord(moall) LE Ofz + (8+1)),   # OBS: moall starter med element mo0, derfor 8+1 t.o.m. august. 
#---     EtaE('Ovn3', moall) = 0.18;
#---     KapE('Ovn3', moall) = 7.5;
#---   );
#--- );
#--- 
#--- # Lagre.
#--- Loop (fa, 
#---   StoLoadInitF('sto1',fa) = DataFuel(fa,'InitSto1');  #--- $DataFuel(fa,'InitSto1') GE 0.0;      
#---   StoLoadInitF('sto2',fa) = DataFuel(fa,'InitSto2');  #--- $DataFuel(fa,'InitSto2') GE 0.0;      
#--- );
#--- StoLoadInitQ(sq) = DataSto(sq,'LoadInit');
#--- 
#--- StoLoadMin(s,mo)       = DataSto(s,'LoadMin');
#--- StoLoadMax(s,mo)       = DataSto(s,'LoadMax');
#--- StoDLoadMax(s,mo)      = DataSto(s,'DLoadMax');
#--- StoLossRate(s,mo)      = DataSto(s,'LossRate');
#--- StoLoadCostRate(s,mo)  = DataSto(s,'LoadCost');
#--- StoDLoadCostRate(s,mo) = DataSto(s,'DLoadCost');
#--- StoFirstReset(s)       = DataSto(s,'ResetFirst');
#--- StoIntvReset(s)        = DataSto(s,'ResetIntv');
#--- StoFirstReset(s)       = ifthen(StoFirstReset(s) EQ 0.0, StoIntvReset(s), min(StoFirstReset(s), StoIntvReset(s)) );
#---
#--- # Brændsler.
#--- fpospris(f,mo) = yes;
#--- fpospris(f,mo) = FuelBounds(f,'pris',mo) GE 0.0;
#--- fnegpris(f,mo) = NOT fpospris(f,mo);
#--- fbiogen(f)     = fa(f) AND (sum(mo, FuelBounds(f,'CO2kgGJ',mo)) EQ 0);
#--- 
#--- MinTonSum(f) = DataFuel(f,'MinTonnage');
#--- MaxTonSum(f) = DataFuel(f,'MaxTonnage');
#--- LhvMWh(f,mo)      = FuelBounds(f,'LHV',mo) / 3.6;
#--- NSprod(mo)        = DataProgn(mo,'NSprod');
#--- 
#--- DoFixAffT(mo) = FixAffaldSum AND (FixValueAffT(mo) NE NaN);
#---
#--- # Emissionsopgørelsen for affald er som udgangspunkt efter skorstensmetoden, hvor CO2-indholdet af  hver fraktion er kendt.
#--- # Men uden skorstensmetoden anvendes i stedet for SKATs emissionssatser, som desuden er forskellige efter om det er CO2-afgift eller CO2-kvoteforbruget, som skal opgøres !!!
#--- CO2potenTon(f,typeCO2,mo) = DataFuel(f,'LHV') * DataFuel(f,'CO2kgGJ') / 1000;  # ton CO2 / ton brændsel.
#--- if (NOT SkorstensMetode,
#---   CO2potenTon(fa,typeCO2,mo) = DataFuel(fa,'LHV') * [DataProgn(mo,'CO2aff') $sameas(typeCO2,'afgift') + DataProgn(mo,'ETSaff') $sameas(typeCO2,'kvote')] / 1000;
#--- );
#--- CO2potenTon(fbiogen,typeCO2,mo) = 0.0;
#---
#--- Qdemand(mo)       = DataProgn(mo,'Varmebehov');
#--- #--- PowerProd(mo)     = DataProgn(mo,'ELprod');
#--- PowerPrice(mo)    = DataProgn(mo,'ELpris');
#--- #TODO: Tarif på indfødning af elproduktion på nettet skal flyttes til DataCtrl.
#--- TariffElProd(mo)  = 4.00;  
#--- #--- IncomeElec(mo)    = PowerProd(mo) * PowerPrice(mo) $OnGU('Ovn3');
#--- TaxAfvMWh(mo)     = DataProgn(mo,'AFV') * 3.6;
#--- TaxAtlMWh(mo)     = DataProgn(mo,'ATL') * 3.6;
#--- TaxEtsTon(mo)     = DataProgn(mo,'ETS');
#--- CO2ContentAff(mo) = DataProgn(mo,'CO2aff') * 3.6 / 1E3;   # CO2-indhold i generisk affald [ton CO2 / MWhq] med ref. til den afgiftspligtige varme/energi.
#--- TaxCO2AffTon(mo)  = DataProgn(mo,'CO2afgAff');
#--- TaxNOxAffkg(mo)   = DataProgn(mo,'NOxAff');
#--- TaxNOxFlisTon(mo) = DataProgn(mo,'NOxFlis') * DataFuel('flis','LHV');
#--- TaxEnrPeakTon(mo) = DataProgn(mo,'EnrPeak') * DataFuel('peakfuel','LHV');
#--- TaxCO2peakTon(mo) = DataProgn(mo,'CO2peak');
#--- TaxNOxPeakTon(mo) = DataProgn(mo,'NOxPeak');
#--- #--- display MinTonSum, MaxTonSum, LhvMWh, Qdemand, PowerProd, PowerPrice, IncomeElec, TaxAfvMWh, TaxAtlMWh, TaxEtsTon, TaxCO2AffTon, TaxCO2peakTon;
#--- 
#--- # Special-haandtering af oevre graense for Nordic Sugar varme.
#--- FuelBounds('NSvarme','MaxTonnage',moall) = DataProgn(moall,'NS');
#--- 
#--- # Diverse øvre grænser for varmeproduktion og lageromkostning.
#--- QbypassMax(mo)    = ShareAvailTurb(mo) * Hours(mo) * KapE('Ovn3',mo)  - Peget(mo);  # Peget har taget højde for turbinens rådighed.
#--- QtotalAffMax(mo)  = sum(ua $OnU(ua,mo), (EtaQ(ua,mo) + EtaRgk(ua,mo)) * sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), LhvMWh(fa,mo) * LhvMWh(fa,mo)) ) + QbypassMax(mo);
#--- StoCostLoadMax(s) = smax(mo, StoLoadMax(s,mo) * StoLoadCostRate(s,mo));
#--- 
#--- display QtotalAffMax, QbypassMax, StoCostLoadMax;
#---
#--- # EaffGross skal være mininum af energiindhold af rådige mængder affald hhv. affaldsanlæggets fuldlastkapacitet.
#--- # Hvis affaldstonnager er fikseret, skal begrænsningen i QaffMmax lempes.
#--- QaffMmax(ua,mo) = min(ShareAvailU(ua,mo) * Hours(mo) * KapQNom(ua,mo), [sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), EtaQ(ua,mo) * LhvMWh(fa,mo) * FuelBounds(fa,'MaxTonnage',mo))]) $OnU(ua,mo);
#--- Loop (mo $DoFixAffT(mo), 
#---   QaffMmax(ua,mo) =  ShareAvailU(ua,mo) * Hours(mo) * KapQNom(ua,mo);
#--- );
#--- QrgkMax(ua,mo)   = KapRgk(ua,mo) / KapQNom(ua,mo) * QaffMmax(ua,mo);
#--- QaffTotalMax(mo) = sum(ua $OnU(ua,mo), ShareAvailU(ua,mo) * (QaffMmax(ua,mo) + QrgkMax(ua,mo)) );
#--- 
#--- TaxATLMax(mo) = sum(ua $OnU(ua,mo), ShareAvailU(ua,mo) * Hours(mo) * KapQmax(ua,mo)) * TaxAtlMWh(mo);
#--- RgkRabatMax(mo) = RgkRabatSats * TaxATLMax(mo);
#--- QRgkMissMax(mo) = 2 * RgkRabatMinShare * sum(ua $OnU(ua,mo), 31 * 24 * KapQNom(ua,mo));  # Faktoren 2 er en sikkerhedsfaktor mod infeasibilitet.
#--- 
$If not errorfree $exit

#end Opsætning af sets og parametre afledt fra inputdata.

