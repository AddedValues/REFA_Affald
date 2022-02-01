$log Entering file: %system.incName%

# Filnavn: RefaScenParsing.gms
# Denne fil inkluderes af RefaMain.gms.
# Indeholder kode til parsing af scenarie-records.



#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  SCENARIO PARSING  >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#begin Parsing af scenarie records.
actScRec(scRec) = no;
ActualScenId    = ord(scen) - 1;

NScenRecFound = 0;

#TODO: Fjern stmt herunder, når debug af scenarie-setup er afsluttet.
continue $(ActualScenId EQ 0);

display "START PÅ SCENARIE PARSING", actScen;

Loop (scRec,
  # Filtrering af records som matcher aktuelle scenarie.
  actScRec(scRec) = yes;
  ActualScRec(labScenRec) = ScenRecs(actScRec,labScenRec);
  ScenId = ActualScRec('ScenId');
  display "RECORD: ", actScRec, ActualScRec, ScenId, ActualScenId;
  break $(ScenId GT ActualScenId);
  continue $(ActualScRec('Aktiv') EQ 0);

  NScenRecFound = NScenRecFound + 1;

  # Inspicér niveau 1: Data typer, som i scenarie-record er angivet med ordinal position.
  Level1 = ActualScRec('Niveau1');
  Level2 = ActualScRec('Niveau2');
  Level3 = ActualScRec('Niveau3');

  FirstPeriod = max(1, min(card(mo), ActualScRec('FirstPeriod')));
  LastPeriod  = max(1, min(card(mo), ActualScRec('LastPeriod')));
  FirstValue  = ActualScRec('FirstValue');
  LastValue   = ActualScRec('LastValue');
  display Level1, Level2, Level3;  # Bruges til debug, hvis fejl detekteres nedstrøms denne parsing.

  # Check gyldighed af periodeangivelser: Angives med løbende måned fra først måned angivet i Schedule('Aar','FirstYear') .. Schedule('Aar','LastYear').
  if (FirstPeriod GT LastPeriod, abort "Scenarie: FirstPeriod er større end LastPeriod.", ActualScRec; );

  # Check gyldighed af ordinaler. Ordinal = -1 angiver fejl i record.
  # OBS: Niveau2 og Niveau3 er successivt betingede af valget af Niveau1.
  if (Level1 LE 0 OR Level1 GT card(droot),
    #! abort.noerror er også en (eneste?) mulighed for at stoppe eksekvering uden fejlmelding.
    abort "Fejl i Niveau1 på scenarie record actScRec", actScRec;
  );
  actRoot(drootPermitted) = ord(drootPermitted) EQ Level1;

  # Lineær interpolation af værdier over den angivne delperiode.
$OffOrder
  moparm(mo) = [ord(mo) GE FirstPeriod AND ord(mo) LE LastPeriod];
  NVal = LastPeriod - FirstPeriod + 1;
  ParmValues(moall) = 0.0;
  ParmValues(mo) $moparm(mo) = FirstValue + (ord(mo) - FirstPeriod) * (LastValue - FirstValue) / Nval;
$OnOrder
  display NVal, ParmValues;

  # Udgrening afh. af Niveau1-valget.
  if (sameas(actRoot,'Control'),
    if (Level2 LE 0 OR Level2 GT card(labDataCtrl), abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
    actControl2(labDataCtrl) = ord(labDataCtrl) EQ Level2;
    display actControl2;
    # Her indsættes kode til modifikation af den tilhørende parameter (datatabel).
    # Periodeangivelse og LastValue ignoreres her.
    DataCtrl(actControl2) = FirstValue;

#---  elseif (sameas(actRoot,'Schedule')),
#---    if (Level2 LE 0 OR Level2 GT card(labSchRow) - 1, abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
#---    actSchedule2(labSchRow) = ord(labSchRow) EQ Level2;
#---    if (Level3 LE 0 OR Level3 GT card(labSchCol), abort "Fejl i niveau 3 på scenarie record actScRec", actScRec; );
#---    actSchedule3(labSchCol) = ord(labSchCol) EQ Level3;
#---    display actSchedule2, actSchedule3;
#---    # Periodeangivelse ignoreres her, men første værdi checkes.
#---    if (sameas(actSchedule2,'Aar'),
#---      if (FirstValue LT Schedule('Aar','FirstYear') OR FirstValue GT Schedule('Aar','LastYear'),
#---        abort "FEJL i ActualScRec: Scenarie LastYear ligger udenfor FirstYear eller LastYear i Schedule", ActualScRec;
#---      );
#---    elseif (sameas(actSchedule2,'Maaned')),
#---      if (FirstValue LE 0 OR FirstValue GT 12,
#---       abort "FEJL i scenarie: Første måned er udenfor området.", ActualScRec;
#---      );
#---    );
#---    Schedule(actSchedule2,actSchedule3) = FirstValue;

  elseif (sameas(actRoot,'Plant')),
    if (Level2 LE 0 OR Level2 GT card(u), abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
    actPlant2(u) = ord(u) EQ Level2;
    if (Level3 LE 0 OR Level3 GT card(labDataU), abort "Fejl i niveau 3 på scenarie record actScRec", actScRec; );
    actPlant3(labDataU) = ord(labDataU) EQ Level3;
    display actPlant2, actPlant3;

    # Principielt er alle anlægsparametre tidsafhængige.
    if (sameas(actPlant3,'Aktiv'),
      OnU(actPlant2,moparm) = ParmValues(moparm);
    elseif (sameas(actPlant3,'MinLhv')),
      MinLhvMWh(actPlant2,moparm) = ParmValues(moparm) / 3.6;
    elseif (sameas(actPlant3,'MaxLhv')),
      MaxLhvMWh(actPlant2,moparm) = ParmValues(moparm) / 3.6;
    elseif (sameas(actPlant3,'MinTon')),
      MinTon(actPlant2,moparm) = ParmValues(moparm);
    elseif (sameas(actPlant3,'MaxTon')),
      MaxTon(actPlant2,moparm) = ParmValues(moparm);
    elseif (sameas(actPlant3,'KapQNom')),
      KapQNom(actPlant2,moparm) = ParmValues(moparm);
    elseif (sameas(actPlant3,'KapRgk')),
      KapRgk(actPlant2,moparm) = ParmValues(moparm);
    elseif (sameas(actPlant3,'KapE')),
      KapE(actPlant2,moparm) = ParmValues(moparm);
    elseif (sameas(actPlant3,'EtaE')),
      EtaE(actPlant2,moparm) = ParmValues(moparm);
    elseif (sameas(actPlant3,'EtaQ')),
      EtaQ(actPlant2,moparm) = ParmValues(moparm);
    elseif (sameas(actPlant2,'DVMWhq')),
      DvMWhq(actPlant2,moparm) = ParmValues(moparm);
    elseif (sameas(actPlant2,'DVtime')),
      DvTime(actPlant2,moparm) = ParmValues(moparm);
    else
      abort "Fejl i implementering af niveau 3 på Plant", actPlant3;
    );

  elseif (sameas(actRoot,'Storage')),
    if (Level2 LE 0 OR Level2 GT card(s), abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
    actStorage2(s) = ord(s) EQ Level2;
    if (Level3 LE 0 OR Level3 GT card(labDataSto), abort "Fejl i niveau 3 på scenarie record actScRec", actScRec; );
    actStorage3(labDataSto) = ord(labDataSto) EQ Level3;
    display actStorage2, actStorage3;

    if (sameas(actStorage3,'Aktiv'),
      OnS(actStorage2,moparm) = ParmValues(moparm);
    elseif (sameas(actStorage3,'StoKind')),
      abort "StoKind kan ikke ændres af scenarier.", ActualScRec;
    elseif (sameas(actStorage3,'LoadInit')),
      StoLoadInitQ(actStorage2) = FirstValue;
    elseif (sameas(actStorage3,'LoadMin')),
      StoLoadMin(actStorage2,moparm) = ParmValues(moparm);
    elseif (sameas(actStorage3,'LoadMax')),
      StoLoadMax(actStorage2,moparm) = ParmValues(moparm);
    elseif (sameas(actStorage3,'DLoadMax')),
      StoDLoadMax(actStorage2,moparm) = ParmValues(moparm);
    elseif (sameas(actStorage3,'LossRate')),
      StoLossRate(actStorage2,moparm) = ParmValues(moparm);
    elseif (sameas(actStorage3,'LoadCost')),
      StoLoadCostRate(actStorage2,moparm) = ParmValues(moparm);
    elseif (sameas(actStorage3,'DLoadCost')),
      StoDLoadCostRate(actStorage2,moparm) = ParmValues(moparm);
    elseif (sameas(actStorage3,'ResetFirst')),
      StoFirstReset(actStorage2) = FirstValue;
    elseif (sameas(actStorage3,'ResetIntv')),
      StoIntvReset(actStorage2) = FirstValue;
    elseif (sameas(actStorage3,'ResetLast')),
      StoFirstReset(actStorage2) = FirstValue;
    else
      abort "Fejl i implementering af niveau 3 på Storage", actStorage3;
    );

  elseif (sameas(actRoot,'Prognoses')),
    if (Level2 LE 0 OR Level2 GT card(labDataProgn), abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
$OffOrder
    actPrognoses2(labDataProgn) = ord(labDataProgn) EQ Level2;
$OnOrder
    display actPrognoses2;

#--- Parameter AvailDaysTurbine(moall);
#--- Parameter NSprod(moall);
#--- Parameter CO2ETSaff(moall);

    # Her modificeres direkte i DataProgn, da den indeholder tidsdimensionen.
    DataProgn(moparm,actPrognoses2) = ParmValues(moparm);

    if (sameas(actPrognoses2,'Aktiv'),
      abort "Fejl i implementering af scenarie prognoses: Aktiv er ikke tilladt, da den styres af Schedule.", ActualScRec;
    elseif (sameas(actPrognoses2,'ELprod')),
      abort "FEJL i Scanrie-spec: Elprod kan ikke angives.", ActualScRec;
    );

  elseif (sameas(actRoot,'Fuel')),
    if (Level2 LE 0 OR Level2 GT card(f), abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
    actFuel2(f) = ord(f) EQ Level2;
    if (Level3 LE 0 OR Level3 GT card(labDataFuel), abort "Fejl i niveau 3 på scenarie record actScRec", actScRec; );
    actFuel3(labDataFuel) = ord(labDataFuel) EQ Level3;
    display actFuel2, actFuel3;

    # Kun udvalgte brændselsparametre kan gøres tidsafhængige.
    if (sameas(actFuel3,'Aktiv'),
      OnF(actFuel2,moparm) = ParmValues(moparm);
      
#---    elseif (sameas(actFuel3,'Lagerbar')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;
#---    elseif (sameas(actFuel3,'Fri')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;
#---    elseif (sameas(actFuel3,'Flex')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;
#---    elseif (sameas(actFuel3,'Bortskaf')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;
#---    elseif (sameas(actFuel3,'TilOvn2')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;
#---    elseif (sameas(actFuel3,'TilOvn3')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;
#---    elseif (sameas(actFuel3,'MinTonnage')),
#---      KapRgk(actFuel3,moparm) = ParmValues(moparm);
#---    elseif (sameas(actFuel3,'MaxTonnage')),
#---      KapE(actFuel3,moparm) = ParmValues(moparm);
#---    elseif (sameas(actFuel3,'InitSto1')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;
#---    elseif (sameas(actFuel3,'InitSto2')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;;
#---    elseif (sameas(actFuel3,'NOxKgTon')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;
    
    else
      DataFuel(actFuel2,actFuel3) = FirstValue;
    );

  elseif (sameas(actRoot,'FuelBounds')),
    if (Level2 LE 0 OR Level2 GT card(f), abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
    actFuelBounds2(f) = ord(f) EQ Level2;
    if (Level3 LE 0 OR Level3 GT card(fuelItem), abort "Fejl i niveau 3 på scenarie record actScRec", actScRec; );
    actFuelBounds3(fuelItem) = ord(fuelItem) EQ Level3;
    display actFuelBounds2, actFuelBounds3;

    FuelBounds(actFuelBounds2,actFuelBounds3,moparm) = ParmValues(moparm);

  else
    abort "Fejl i Niveau case-structure: Niveau1=actRoot ikke implementeret.", actRoot;
  );
);

display NScenRecFound;

#--- # Verificér scenarier.
#--- Scalar nScenActive 'Antal aktive definerede scenarier';
#--- if (RunScenarios,
#---   nScenActive = sum(scen, 1 $Scen_Progn(scen,'Aktiv'));
#---   if (nScenActive EQ 0,
#---     display nScenActive, Scen_Progn;
#---     abort "RunScenarios er TRUE (NE 0), men ingen scenarier i Scen_Progn er aktive.";
#---   );
#--- );


#end   Parsing af scenarie records.

#--- execute_unload "RefaMain.gdx";
#--- abort.noerror "BEVIDST STOP";

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  END SCENARIO PARSING  >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>



