$log Entering file: %system.incName%

# Filnavn: RefaScenParsing.gms
# Denne fil inkluderes af RefaMain.gms.
# Indeholder kode til parsing af scenarie-records.


#begin Parsing af scenarie records.
actScRec(scRec) = no;
ActualScenId    = ord(scen) - 1;

PrevDEBUG = DEBUG;
DEBUG     = TRUE;

NScenRecFound = 0;

#TODO: Fjern stmt herunder, når debug af scenarie-setup er afsluttet.
continue $(ActualScenId EQ 0);

if (DEBUG, display  "START PÅ SCENARIE PARSING", actScen; );

Loop (scRec,
  # Filtrering af records som matcher aktuelle scenarie.
  actScRec(scRec) = yes;
  ActualScRec(labScenRec) = ScenRecs(actScRec,labScenRec);
  ScenId = ActualScRec('ScenId');
  if (DEBUG, display  "RECORD: ------------------------------------------------", actScRec, ActualScRec;  );   
  break $(ScenId GT ActualScenId);
  continue $(ActualScRec('Aktiv') EQ 0);

  # Inspicér niveau 1: Data typer, som i scenarie-record er angivet med ordinal position.
  Level1 = ActualScRec('Niveau1');
  Level2 = ActualScRec('Niveau2');
  Level3 = ActualScRec('Niveau3');

  #TODO: CHECK periodeangivelser op mod sekvenset mo(moall).
  #--- FirstPeriod = max(1, ActualScRec('FirstPeriod'));
  #--- LastPeriod  = max(1, ActualScRec('LastPeriod'));
  FastVaerdi      = ActualScRec('FastVaerdi');
  GivenFastVaerdi = (abs(FastVaerdi - NaN) GT 1E-8);
  if (DEBUG, display  Level1, Level2, Level3, FastVaerdi, GivenFastVaerdi; );  # Bruges til debug, hvis fejl detekteres nedstrøms denne parsing.

  NScenRecFound = NScenRecFound + 1;
  
  # Check gyldighed af ordinaler. Ordinal = -1 angiver fejl i record.
  # OBS: Niveau2 og Niveau3 er successivt betingede af valget af det foregående niveau.
  if (Level1 LE 0 OR Level1 GT card(droot),
    #! abort.noerror er også en (eneste?) mulighed for at stoppe eksekvering uden fejlmelding.
    abort "Fejl i Niveau1 på scenarie record actScRec", actScRec;
  );
  actRoot(drootPermitted) = ord(drootPermitted) EQ Level1;

  # Overfør månedsværdier til vektor ParmValues.
  Loop (labScenRec,
    Loop (mo $sameas(labScenRec,mo),
      ParmValues(mo) = ScenRecs(scRec,labScenRec);
    );
  );
  NVal = sum(mo, (abs(ParmValues(mo) - NaN) GT 1E-8)); 
  if (DEBUG, display ParmValues, NVal; );

  # Statuskode tildeles hvor der er tvetydigt input i specifikationen.
  # Statuskode = NaN (-9.99): Intet at bemærke
  #            = 1          : Både FastVaerdi og periode-data er angivet (FastVaerdi anvendes).

  # Udgrening afh. af Niveau1-valget.
  
  if (sameas(actRoot,'Control'),
    if (Level2 LE 0 OR Level2 GT card(labDataCtrl), abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
    if (NOT GivenFastVaerdi, abort "Scenarie kan kun specificere DataCtrl-parms vha. FastVaerdi, men NaN er indgivet.");

    # Control accepterer kun angivelse af fast værdi, dvs. ingen tidsafhængighed.
    actControl2(labDataCtrl) = ord(labDataCtrl) EQ Level2;
    DataCtrl(actControl2) = FastVaerdi;
    if (DEBUG, display actControl2, FastVaerdi; );

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
    if (Level2 LE 0 OR Level2 GT card(u),        abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
    if (Level3 LE 0 OR Level3 GT card(labDataU), abort "Fejl i niveau 3 på scenarie record actScRec", actScRec; );

    actPlant2(u) = ord(u) EQ Level2;
    actPlant3(labDataU) = ord(labDataU) EQ Level3;
    if (DEBUG, display  actPlant2, actPlant3; );

    # Principielt er alle anlægsparametre tidsafhængige.
    # Hvis kun FastVaerdi er angivet dvs. forskellig fra NaN, så anvendes denne for hele perioden, ellers anvendes ParmValues.
    if (GivenFastVaerdi,
      if (NVal > 0, ScenRecs(scRec,'Statuskode') = 1;);
      DataU(actPlant2,actPlant3,mo) = FastVaerdi;
    else 
      DataU(actPlant2,actPlant3,mo) = ParmValues(mo);
    );
#---    if (sameas(actPlant3,'Aktiv'),
#---      OnU(actPlant2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actPlant3,'MinLhv')),
#---      MinLhvMWh(actPlant2,moparm) = ParmValues(moparm) / 3.6;
#---    elseif (sameas(actPlant3,'MaxLhv')),
#---      MaxLhvMWh(actPlant2,moparm) = ParmValues(moparm) / 3.6;
#---    elseif (sameas(actPlant3,'MinTon')),
#---      MinTon(actPlant2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actPlant3,'MaxTon')),
#---      MaxTon(actPlant2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actPlant3,'KapQNom')),
#---      KapQNom(actPlant2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actPlant3,'KapRgk')),
#---      KapRgk(actPlant2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actPlant3,'KapE')),
#---      KapE(actPlant2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actPlant3,'EtaE')),
#---      EtaE(actPlant2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actPlant3,'EtaQ')),
#---      EtaQ(actPlant2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actPlant2,'DVMWhq')),
#---      DvMWhq(actPlant2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actPlant2,'DVtime')),
#---      DvTime(actPlant2,moparm) = ParmValues(moparm);
#---    else
#---      abort "Fejl i implementering af niveau 3 på Plant", actPlant3;
#---    );

  elseif (sameas(actRoot,'Storage')),
    if (Level2 LE 0 OR Level2 GT card(s),          abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
    if (Level3 LE 0 OR Level3 GT card(labDataSto), abort "Fejl i niveau 3 på scenarie record actScRec", actScRec; );

    actStorage2(s) = ord(s) EQ Level2;
    actStorage3(labDataSto) = ord(labDataSto) EQ Level3;
    if (DEBUG, display  actStorage2, actStorage3; );

    # Hvis kun FastVaerdi er angivet dvs. forskellig fra NaN, så anvendes denne for hele perioden, ellers anvendes ParmValues.
    if (GivenFastVaerdi,
      if (NVal > 0, ScenRecs(scRec,'Statuskode') = 1;);
      DataSto(actStorage2,actStorage3,mo) = FastVaerdi;
    else 
      DataSto(actStorage2,actStorage3,mo) = ParmValues(mo);
    );
    
    # Hvis kun FastVaerdi er angivet dvs. forskellig fra NaN, så anvendes denne for hele perioden, ellers anvendes ParmValues.
    # En stor del af lager-attributter er ikke implementeret som tidsafhængige, de øvrige optræder i set stoItem.
    Loop (labDataSto $sameas(labDataSto,actStorage3),
      if (stoItem(labDataSto),
        if (GivenFastVaerdi,
        if (NVal > 0, ScenRecs(scRec,'Statuskode') = 1;);
          DataSto(actStorage2,actStorage3,mo) = FastVaerdi;
        else 
          DataSto(actStorage2,actStorage3,mo) = ParmValues(mo);
        );
      else 
        DataSto(actStorage2,actStorage3,mo) = FastVaerdi;
      );
    );

#---    if (sameas(actStorage3,'Aktiv'),
#---      OnS(actStorage2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actStorage3,'StoKind')),
#---      abort "StoKind kan ikke ændres af scenarier.", ActualScRec;
#---    elseif (sameas(actStorage3,'LoadInit')),
#---      StoLoadInitQ(actStorage2) = FirstValue;
#---    elseif (sameas(actStorage3,'LoadMin')),
#---      StoLoadMin(actStorage2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actStorage3,'LoadMax')),
#---      StoLoadMax(actStorage2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actStorage3,'DLoadMax')),
#---      StoDLoadMax(actStorage2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actStorage3,'LossRate')),
#---      StoLossRate(actStorage2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actStorage3,'LoadCost')),
#---      StoLoadCostRate(actStorage2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actStorage3,'DLoadCost')),
#---      StoDLoadCostRate(actStorage2,moparm) = ParmValues(moparm);
#---    elseif (sameas(actStorage3,'ResetFirst')),
#---      StoFirstReset(actStorage2) = FirstValue;
#---    elseif (sameas(actStorage3,'ResetIntv')),
#---      StoIntvReset(actStorage2) = FirstValue;
#---    elseif (sameas(actStorage3,'ResetLast')),
#---      StoFirstReset(actStorage2) = FirstValue;
#---    else
#---      abort "Fejl i implementering af niveau 3 på Storage", actStorage3;
#---    );

  elseif (sameas(actRoot,'Prognoses')),
$OffOrder
    actPrognoses2(labDataProgn) = ord(labDataProgn) EQ Level2;
$OnOrder
    if (Level2 LE 0 OR Level2 GT card(labDataProgn), abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
    if (DEBUG, display actPrognoses2; );

    if (sameas(actPrognoses2,'Aktiv'),
      abort "Fejl i implementering af scenarie prognoses: Aktiv er ikke tilladt, da den styres af Schedule.", ActualScRec;
    elseif (sameas(actPrognoses2,'ELprod')),
      abort "FEJL i Scenarie-spec: Elprod kan ikke angives.", ActualScRec;
    );

    # Hvis kun FastVaerdi er angivet dvs. forskellig fra NaN, så anvendes denne for hele perioden, ellers anvendes ParmValues.
    if (GivenFastVaerdi,
      if (NVal > 0, ScenRecs(scRec,'Statuskode') = 1;);
      DataProgn(actPrognoses2,mo) = FastVaerdi
  else 
      DataProgn(actPrognoses2,mo) = ParmValues(mo);
    );

  elseif (sameas(actRoot,'Fuel')),
    if (Level2 LE 0 OR Level2 GT card(f),           abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
    if (Level3 LE 0 OR Level3 GT card(labDataFuel), abort "Fejl i niveau 3 på scenarie record actScRec", actScRec; );

    actFuel2(f)           = ord(f) EQ Level2;
    actFuel3(labDataFuel) = ord(labDataFuel) EQ Level3;
    if (DEBUG, display  actFuel2, actFuel3; );

    # Hvis kun FastVaerdi er angivet dvs. forskellig fra NaN, så anvendes denne for hele perioden, ellers anvendes ParmValues.
    # En stor del af Fuel-attributter er ikke implementeret som tidsafhængige, de øvrige optræder i set fuelItem.
    Loop (labDataFuel $sameas(labDataFuel,actFuel3),
      if (fuelItem(labDataFuel),
        if (GivenFastVaerdi AND NVal GT 0,
          ScenRecs(scRec,'Statuskode') = 1;
          DataFuel(actFuel2,actFuel3,mo) = FastVaerdi;
          if (DEBUG, display "Assign FastVaerdi til FuelItem";);
        else 
          if (DEBUG, display "Assign ParmValues til FuelItem";);
          DataFuel(actFuel2,actFuel3,mo) = ParmValues(mo);
        );
      else 
#---        if (DEBUG, display "Assign ParmValues til Non-FuelItem";);
#---        DataFuel(actFuel2,actFuel3,mo) = FastVaerdi;
        if (GivenFastVaerdi AND NVal GT 0,
          ScenRecs(scRec,'Statuskode') = 1;
          DataFuel(actFuel2,actFuel3,mo) = FastVaerdi;
          if (DEBUG, display "Assign FastVaerdi til Non-FuelItem";);
        else 
          if (DEBUG, display "Assign ParmValues til Non-FuelItem";);
          DataFuel(actFuel2,actFuel3,mo) = ParmValues(mo);
        );
      );
    );

#---    DataFuel(actFuel2,actFuel3) = FirstValue;
#---
#---    if (sameas(actFuel3,'Aktiv'),
#---      OnF(actFuel2,moparm) = ParmValues(moparm);
#---      DataFuel(actFuel2,'Aktiv')
#---      
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
#---    elseif (sameas(actFuel3,'InitSto1')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;
#---    elseif (sameas(actFuel3,'InitSto2')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;;
#---    elseif (sameas(actFuel3,'NOxKgTon')),
#---      DataFuel(actFuel2,actFuel3) = FirstValue;
#---    
#---    else
#---      DataFuel(actFuel2,actFuel3,mo) = FirstValue;
#---    );

#---  elseif (sameas(actRoot,'FuelBounds')),
#---    if (Level2 LE 0 OR Level2 GT card(f),        abort "Fejl i niveau 2 på scenarie record actScRec", actScRec; );
#---    if (Level3 LE 0 OR Level3 GT card(fuelItem), abort "Fejl i niveau 3 på scenarie record actScRec", actScRec; );
#---    
#---    actFuelBounds2(f)        = ord(f) EQ Level2;
#---    actFuelBounds3(fuelItem) = ord(fuelItem) EQ Level3;
#---    if (DEBUG, display  actFuelBounds2, actFuelBounds3; );
#---
#---    FuelBounds(actFuelBounds2,actFuelBounds3,moparm) = ParmValues(moparm);

  else
    abort "Fejl i Niveau case-structure: Niveau1=actRoot ikke implementeret.", actRoot;
  );
);

if (DEBUG, display  NScenRecFound; );


#end   Parsing af scenarie records.

execute_unload "RefaMain.gdx";
abort.noerror "BEVIDST STOP";

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  END SCENARIO PARSING  >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


DEBUG = PrevDebug;
