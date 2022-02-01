$log Entering file: %system.incName%
$Title 21-1XXX REFA ENERGI - Affaldsoptimering
$eolcom #
$OnText
Projekt:    21-1XXX REFA ENERGI - Affaldsoptimering
Filnavn:    REFAmain.gms
Scope:      Prototyping af model for optimering af affaldsdisponering
Repository: GitHub: <none>
Dato:       2021-09-15 08:14
$OffText

# ENCODING SKAL VÆRE ANSI FOR AT DANSKE BOGSTAVER 'OVERLEVER' I KOMMENTARER.
# Danske bogstaver kan IKKE bruges i model-elementer, såsom set-elementer, parameternavne, m.v.
#--- set dummy / sæ, sø, så, sÆ, sØ, sÅ /;

# Globale erklæringer og shorthands.
option dispwidth = 80;

# Shorthand for boolean constants.
Scalar FALSE 'Shorthand for false = 0 (zero)' / 0 /;
Scalar TRUE  'Shorthand for true  = 1 (one)'  / 1 /;

# Arbejdsvariable
Scalar VirtualUsed     'Angiver at virtuelle ressourcer er brugt (bløde infeasibiliteter)';
Scalar Found           'Angiver at logisk betingelse er opfyldt';
Scalar FoundError      'Angiver at fejl er fundet';
Scalar tiny / 1E-14 /;
Scalar Big  / 1E+9  /;
Scalar NaN             'Bruges til at angive void input fra Excel' / -9.99 /;
Scalar tmp1, tmp2, tmp3;

VirtualUsed = FALSE;

# ------------------------------------------------------------------------------------------------
# Erklaering af sets
# ------------------------------------------------------------------------------------------------

set bound         'Bounds'          / Min, Max /;
set dir           'Flowretning'     / drain, source /;
set phiKind       'Type phi-faktor' / 85, 95 /;
set iter          'iterationer'     / iter0 * iter30 /;
set scen          'Scenarier'       / scen0, scen1 * scen30 /;  # scen0 er referencescenariet.
set moall         'Aarsmaaneder'   / mo0 * mo36 /;  # Daekker op til 3 aar. Elementet 'mo0' anvendes kun for at sikre tom kolonne i udskrivning til Excel.
set mo(moall)     'Aktive maaneder';
set moparm(moall) 'Scenarie periode for aktuel parameter';
alias(mo,moa);
moparm(moall) = no;

set typeCO2 'CO2-Opgørelsestype' / afgift, kvote, total /;

set owner 'Anlaegsejere'  / refa, gsf /;

set fkind 'Drivm.-typer'  / 1 'affald', 2 'biomasse', 3 'varme', 4 'peakfuel' /;

Set f     'Drivmidler'    / DepoSort, DepoSmaat, DepoNedd, Dagren, AndetBrand, Trae,
                            DagrenRast, DagrenInst, DagrenHandel, DagrenRestau, Erhverv, DagrenErhverv,
                            HandelKontor, Privat, TyskRest, PolskRest, PcbTrae, TraeRekv, Halm, Pulver, FlisAffald,
                            NyAff1, NyAff2, NyAff3, NyAff4, NyAff5,
                            Flis, NSvarme, PeakFuel /;

set fa(f)                 'Affaldstyper';
set fb(f)                 'Biobraendsler';
set fc(f)                 'Overskudsvarme';
set fr(f)                 'PeakK braendsel';
set fx(f)                 'Andre braendsler end affald';
set frefa(f)              'REFA braendsler';
set fgsf(f)               'GSF braendsler';
set fbiogen(f)            'Biogene brændsler (uden afgifter)';
set fsto(f)               'Lagerbare braendsler';   # Lagerbarhed er ikke dynamisk, da det vil kræve særskilt lagerstyring for at sikre tømning, hvis status bortfalder i perioden.
set fdis(f)               'Braendsler som skal bortskaffes';
set ffri(f)               'Braendsler med fri tonnage';
set fflex(f)              'Braendsler med fleksibel månedstonnage';
set f2own(f,owner)        'Tilknytning af fuel til ejer';
set fpospris(f,moall)     'Braendsler med positiv pris (modtagepris)';
set fnegpris(f,moall)     'Braendsler med negativ pris (købspris))';

set uaggr     'Sammenfattende anlæg'  / Affald, Fliskedel, SR-kedel /;

set ukind     'Anlaegstyper'   / 1 'affald', 2 'biomasse', 3 'varme', 4 'Cooler', 5 'PeakK' /;
set u         'Anlaeg'         / Ovn2, Ovn3, FlisK, NS, Cooler, PeakK /;
set up(u)     'Prod-anlaeg'    / Ovn2, Ovn3, FlisK, NS, PeakK /;
set ua(u)     'Affaldsanlaeg'  / Ovn2, Ovn3 /;
set ub(u)     'Bioanlaeg'      / FlisK /;
set uc(u)     'OV-leverance'   / NS /;
set ur(u)     'SR-kedler'      / PeakK /;
set uv(u)     'Koelere'        / Cooler /;
set ux(u)     'Andre anlaeg end affald'      / FlisK, NS, Cooler, PeakK /;
set upx(u)    'Andre prod-anlæg end affald'  / FlisK, NS, PeakK /;
set urefa(u)  'REFA anlaeg'            / Ovn2, Ovn3, FlisK, Cooler /;
set uprefa(u) 'REFA produktionsanlaeg' / Ovn2, Ovn3, FlisK /;
set ugsf(u)   'Guldborgsund anlaeg'    / PeakK /;

set uprio(up)       'Prioriterede anlaeg';
set uprio2up(up,up) 'Anlaegsprioriteter';   # Rækkefølge af prioriteter oprettes på basis af DataU(up,'prioritet')

set s     'Lagre' / sto1 * sto2 /;          # I første omgang tiltænkt affaldslagre.
set sa(s) 'Affaldslagre';
set sq(s) 'Varmelagre';

set u2f(u,f)  'Gyldige kombinationer af anlæg og drivmidler';
set s2f(s,f)  'Gyldige kombinationer af lagre og drivmidler';

set labDataCtrl           'Styringparms'       / RunScenarios, IncludeGSF, VirtuelVarme, VirtuelAffald, SkorstensMetode, FixAffald, RgkRabatSats, RgkAndelRabat, Varmesalgspris, EgetforbrugKVV /;
set labSchCol             'Periodeomfang'      / FirstYear, LastYear, FirstPeriod, LastPeriod /;
set labSchRow             'Periodeomfang'      / aar, maaned, dato /;
set labDataU              'DataU labels'       / Aktiv, Ukind, Prioritet, MinLhv, MaxLhv, MinTon, MaxTon, kapQNom, kapRgk, kapE, MinLast, KapMin, EtaE, EtaQ, DVMWhq, DVtime /;
set labDataStoUniq        'DataSto labels'     / StoKind, LoadInit, LoadMin, LoadMax, DLoadMax, LossRate, LoadCost, DLoadCost, ResetFirst, ResetIntv, ResetLast /;  # stoKind=1 er affalds-, stoKind=2 er varmelager.
set labDataPrognUniq      'Prognose labels'    / Ndage, Turbine, Varmebehov, NSprod, ELprod, Bypass, Elpris, ETS, AFV, ATL, CO2aff, ETSaff, CO2afgAff, NOxAff, NOxFlis, EnrPeak, CO2peak, NOxPeak /;
set labDataFuelUniq       'DataFuel labels'    / Fkind, Lagerbar, Fri, Flex, Bortskaf, TilOvn2, TilOvn3, MinTonnage, MaxTonnage, InitSto1, InitSto2, Pris, LHV, NOxKgTon, CO2kgGJ /;
set labDataSto            'DataSto labels'     / Aktiv, set.labDataStoUniq /;
set labDataProgn          'Prognose labels'    / Aktiv, set.labDataPrognUniq, set.u /;
set labDataFuel           'DataFuel labels'    / Aktiv, set.labDataFuelUniq /;
set taxkind(labDataProgn) 'Omkostningstyper'   / ETS, AFV, ATL, CO2aff, ETSaff, CO2afgAff, NOxAff, NOxFlis, EnrPeak, CO2peak, NOxPeak /;

set fuelItem(labDataFuel) 'Brændselsdata som kan periodiseres ' / TilOvn2, TilOvn3, MinTonnage, MaxTonnage, Pris, LHV, Co2kgGJ /; #--- Lagerbar, Fri, Flex,

set labPrognScen(labDataProgn) 'Aktive prognose scenarie-parms';

set scRec       'Scen-records'        / screc1 * screc30 /;
set labScenRec  'Scen-records'        / ScenId, Aktiv, Niveau1, Niveau2, Niveau3, FirstPeriod, LastPeriod, FirstValue, LastValue /;
set droot       'Data på niveau 1'    / Control, Schedule, Plant, Storage, Prognoses, Fuel, FuelBounds /;
set drootPermitted(droot)             / Control,           Plant, Storage, Prognoses, Fuel, FuelBounds /;

Singleton set ufparm(u,f);
Singleton set sfparm(s,f);
Singleton set labPrognSingle(labDataProgn);
Singleton set actScen(scen)    'Aktuelt scenarie';
Singleton set actScRec(scRec);
Singleton set actRoot(droot);
Singleton set actControl2(labDataCtrl);
Singleton set actSchedule2(labSchRow);
Singleton set actSchedule3(labSchCol);
Singleton set actPlant2(u);
Singleton set actPlant3(labDataU);
Singleton set actStorage2(s);
Singleton set actStorage3(labDataSto);
Singleton set actPrognoses2(labDataProgn);
Singleton set actFuel2(f);
Singleton set actFuel3(labDataFuel);
Singleton set actFuelBounds2(f);
Singleton set actFuelBounds3(fuelItem);

actScen(scen)   = no;
actScRec(scRec) = no;

alias(upa, up);

# ------------------------------------------------------------------------------------------------
# Erklaering af parametre
# ------------------------------------------------------------------------------------------------
# Penalty faktorer til objektfunktionen.
Scalar    Penalty_bOnU              'Penalty på bOnU'           / 0000E+5 /;
Scalar    Penalty_QRgkMiss          'Penalty på QRgkMiss'       /   10    /;      # Denne penalty må ikke være højere end tillaegsafgiften.
Scalar    Penalty_QInfeas           'Penalty på QInfeas'        / 5000    /;      # Pålægges virtuel varmekilder og -dræn.
Scalar    Penalty_AffTInfeas        'Penalty på AffTInfeas'     / 5000    /;      # Pålægges virtuel affaldstonnage kilde og -dræn.
Scalar    Penalty_AffaldsGensalg    'Affald gensalgspris'       / 1500.00  /;      # Pålægges ikke-udnyttet affald.
Scalar    OnQInfeas                 'On/Off på virtuel varme'   / 0       /;
Scalar    OnAffTInfeas              'On/Off på virtuel affald'  / 0       /;
Scalar    LhvMWhAffTInfeas          'LHV af virtuel affald'     / 3.0    /;                        # 3.0 MWhf/ton svarende til 10.80 GJ/ton.
Parameter Gain_Qaff(u)              'Gevinst for affaldsvarme'  / 'Ovn2' 10.00, 'Ovn3' 10.00  /;   # Tillægges varmeproduktion på Ovn3 for at sikre udlastning før NS-varmen og flisvarme.

# Arbejdsparametre til scenarie håndtering
Scalar ScenId;
Scalar ActualScenId;
Scalar NScenRecFound 'Antal aktive scenarie records for aktuelle scenarie';
Scalar Level1, Level2, Level3;  # Ordinale positioner af data typer i scenarie record.
Scalar FirstPeriod, LastPeriod, FirstValue, LastValue;  # Ordinale positioner af perioder hhv. værdier i scenarie record.
Scalar NVal;
Scalar FirstYear, LastYear, Ofz;

# Indlæses via DataCtrl.
Scalar    RgkRabatSats              'Rabatsats på ATL'          / 0.10    /;
Scalar    RgkRabatMinShare          'Taerskel for RGK rabat'    / 0.07    /;
Scalar    VarmeSalgspris            'Varmesalgspris DKK/MWhq'   / 200.00  /;
Scalar    AffaldsOmkAndel           'Affaldssiden omk.andel'    / 0.45    /;
Scalar    SkorstensMetode           '0/1 for skorstensmetode'   / 0       /;
Scalar    EgetforbrugKVV            'Angiver egetforbrug MWhe/døgn';
Scalar    RunScenarios              'Angiver 0/1 om scenarier skal køres';
Scalar    FixAffald                 'Angiver 0/1 om affaldsfraktioner skal fikseres på månedsniveau';
Scalar    NactiveM                  'Antal aktive måneder';

Scalar    dbup, dbupa;
Scalar    db, qdeliv;
Scalar    Nfbiogen                  'Antal biogene affaldsfraktioner';

Parameter ParmValues(moall)         'Aktuelle scenarie parm værdier';

Parameter IncludeOwner(owner)       '<>0 => Ejer med i OBJ'     / refa 1, gsf 0 /;
Parameter IncludePlant(u);
Parameter IncludeFuel(f);

Parameter ScenRecs(scRec,labScenRec) 'Scenarie-forskrifter';
Parameter ActualScRec(labScenRec);

#--- Parameter Scen_Progn(scen,labDataProgn)            'Scenarier på prognoser';
#--- Parameter Scen_Progn_Transpose(labDataProgn,scen)  'Transponering af Scen_Progn';

Parameter Schedule(labSchRow,labSchCol)  'Periode start/stop';
Parameter DataCtrl(labDataCtrl)          'Data for styringsparametre';
Parameter DataU(u,labDataU)              'Data for anlaeg';
Parameter DataSto(s,labDataSto)          'Lagerspecifikationer';
Parameter DataProgn(moall,labDataProgn)  'Data for prognoser';
Parameter DataFuel(f,labDataFuel)        'Data for drivmidler';
Parameter FuelBounds(f,fuelItem,moall)   'Maengdegraenser for drivmidler';
Parameter FixValueAffT(moall)            'Fikserede månedstonnager på affald';
Parameter DoFixAffT(moall)               'Angiver True/False at månedstonnagen på affald skal fikseres';

Parameter OnGU(u)                        'Angiver om anlaeg er til raadighed overhovedet';
Parameter OnGS(s)                        'Angiver om lager er til raadighed overhovedet';
Parameter OnGF(f)                        'Angiver om drivmiddel er til raadighed overhovedet';
Parameter OnU(u,moall)                   'Angiver om anlaeg er til raadighed i given måned';
Parameter OnS(s,moall)                   'Angiver om lager er til raadighed i given måned';
Parameter OnF(f,moall)                   'Angiver om drivmiddel er til raadighed i given måned';
Parameter OnM(moall)                     'Angiver om en given maaned er aktiv';
Parameter OnBypass(moall)                'Angiver 0/1 om turbine-bypass er tilladt';
Parameter Hours(moall)                   'Antal timer i maaned';
Parameter AvailDaysU(moall,u)            'Antal raadige dage';
Parameter ShareAvailU(u,moall)           'Andel af fuld rådighed på månedsbasis';
Parameter AvailDaysTurb(moall)           'Antal raadige dage for dampturbinen';
Parameter ShareAvailTurb(moall)          'Andel af fuld rådighed af dampturbinen månedsbasis';
Parameter NSprod(moall)                  'Øvre grænse for NS-varme [MWhq]';
Parameter Peget(moall)                   'Elektrisk egetforbrug KKV-anlægget';

Parameter MinLhvMWh(u,moall)             'Mindste braendvaerdi affaldsanlaeg GJ/ton';
Parameter MaxLhvMWh(u,moall)             'Største braendvaerdi affaldsanlaeg GJ/ton';
Parameter MinTon(u,moall)                'Mindste indfyringskapacitet ton/h';
Parameter MaxTon(u,moall)                'Stoerste indfyringskapacitet ton/h';
Parameter KapMin(u,moall)                'Mindste modtrykslast MWq';
Parameter KapQNom(u,moall)                'Stoerste modtrykskapacitet MWq';
Parameter KapMax(u,moall)                'Stoerste samlede varmekapacitet MWq';
Parameter KapRgk(u,moall)                'RGK kapacitet MWq';
Parameter KapE(u,moall)                  'El bruttokapacitet MWe';
Parameter EtaQ(u,moall)                  'Varmevirkningsgrad';
Parameter EtaRgk(u,moall)                'Varmevirkningsgrad';
Parameter EtaE(u,moall)                  'Elvirkningsgrad (er månedsafhængig i 2021)';
Parameter DvMWhq(u,moall)                'DV-omkostning pr. MWhf';
Parameter DvTime(u,moall)                'DV-omkostning pr. driftstimer';
Parameter StoLoadInitF(s,f)              'Initial lagerbeholdning for hvert brændsel';
Parameter StoLoadInitQ(s)                'Initial lagerbeholdning for varmelagre';
Parameter StoLoadMin(s,moall)            'Min. lagerbeholdning';
Parameter StoLoadMax(s,moall)            'Max. lagerbeholdning';
Parameter StoDLoadMax(s,moall)           'Max. lagerændring i periode';
Parameter StoLoadCostRate(s,moall)       'Omkostning for opbevaring';
Parameter StoDLoadCostRate(s,moall)      'Omkostning for lagerændring';
Parameter StoLossRate(s,moall)           'Max. lagertab ift. forrige periodes beholdning';
Parameter StoFirstReset(s)               'Antal initielle perioder som omslutter første nulstiling af lagerstand';
Parameter StoIntvReset(s)                'Antal perioder som omslutter første nulstiling af lagerstand, efter første nulstilling';

Parameter MinTonnageYear(f)              'Braendselstonnage min aarsniveau [ton/aar]';
Parameter MaxTonnageYear(f)              'Braendselstonnage max aarsniveau [ton/aar]';
Parameter LhvMWh(f,moall)                'Braendvaerdi [MWf]';
Parameter CO2potenTon(f,typeCO2,moall)   'CO2-emission [tonCO2/tonBrændsel]';
Parameter Qdemand(moall)                 'FJV-behov';
#--- Parameter IncomeElec(moall)              'El-indkomst [DKK]';
#--- Parameter PowerProd(moall)               'Elproduktion MWhe';
Parameter PowerPrice(moall)              'El-pris DKK/MWhe';
Parameter TariffElProd(moall)            'Tarif på elproduktion [DKK/MWhe]';
Parameter TaxAfvMWh(moall)               'Affaldsvarmeafgift [DKK/MWhq]';
Parameter TaxAtlMWh(moall)               'Affaldstillaegsafgift [DKK/MWhq]';
Parameter TaxEtsTon(moall)               'CO2 Kvotepris [DKK/tom]';
Parameter TaxCO2TonF(f,moall)            'CO2-afgift på brændselsniveau [DKK/tonCO2]';
Parameter CO2ContentAff(moall)           'CO2 indhold affald [kgCO2 / tonAffald]';
Parameter TaxCO2AffTon(moall)            'CO2 afgift affald [DKK/tonCO2]';
Parameter TaxNOxAffkg(moall)             'NOx afgift affald [DKK/kgNOx]';
Parameter TaxNOxFlisTon(moall)           'NOx afgift flis [DKK/tom]';
Parameter TaxEnrPeakTon(moall)           'Energiafgift SR-kedler [DKK/tom]';
Parameter TaxCO2peakTon(moall)           'CO2 afgift SR-kedler [DKK/tom]';
Parameter TaxNOxPeakTon(moall)           'NOx afgift SR-kedler [DKK/tom]';

Parameter EaffGross(moall)               'Max energiproduktion for affaldsanlaeg MWh';
Parameter QaffMmax(ua,moall)             'Max. modtryksvarme fra affaldsanlæg';
Parameter QrgkMax(ua,moall)              'Max. RGK-varme fra affaldsanlæg';
Parameter QaffTotalMax(moall)            'Max. total varme fra affaldsanlæg';
Parameter TaxATLMax(moall)               'Oevre graense for ATL';
Parameter RgkRabatMax(moall)             'Oevre graense for ATL rabat';
Parameter QRgkMissMax(moall)             'Oevre graense for QRgkMiss';

$If not errorfree $exit

# Indlaesning af input parametre

$onecho > REFAinput.txt
*--- set=labPrognScen        rng=Scen!C7:J7                      cdim=1
*--- par=Scen_Progn          rng=Scen!A7:J37              rdim=1 cdim=1
par=ScenRecs            rng=Scen!N5:W100             rdim=1 cdim=1
par=DataCtrl            rng=DataCtrl!B4:C20          rdim=1 cdim=0
par=Schedule            rng=DataU!A3:E6              rdim=1 cdim=1
par=DataU               rng=DataU!A11:O17            rdim=1 cdim=1
par=DataSto             rng=DataU!Q11:AC17           rdim=1 cdim=1
par=DataProgn           rng=DataU!D22:AC58           rdim=1 cdim=1
par=DataFuel            rng=DataFuel!C4:T33          rdim=1 cdim=1
par=FuelBounds          rng=DataFuel!B39:AM250       rdim=2 cdim=1
par=FixValueAffT        rng=DataFuel!D254:AM255      rdim=0 cdim=1
$offecho

$call "ERASE  REFAinputM.gdx"
$call "GDXXRW REFAinputM.xlsm RWait=1 Trace=3 @REFAinput.txt"

# Indlaesning fra GDX-fil genereret af GDXXRW.
# $LoadDC bruges for at sikre, at der ikke findes elementer, som ikke er gyldige for den aktuelle parameter.
# $Load udfoerer samme operation som $LoadDC, men ignorerer ugyldige elementer.
# $Load anvendes her for at tillade at indsaette linjer med beskrivende tekst.

$GDXIN REFAinputM.gdx

$LOAD   labPrognScen
*--- $LOAD   Scen_Progn
$LOAD   ScenRecs
$LOAD   DataCtrl
$LOAD   Schedule
$LOAD   DataU
$LOAD   DataSto
$LOAD   DataProgn
$LOAD   DataFuel
$LOAD   FuelBounds
$LOAD   FixValueAffT

$GDXIN   # Close GDX file.
$log  LOG: Finished loading input data from GDXIN.

#--- display labPrognScen, Scen_Progn, DataCtrl, DataU, Schedule, DataProgn, DataFuel, FuelBounds, DataSto;
#--- abort "BEVIDST STOP";

#begin Opsætning af subsets, som IKKE afledes af inputdata.

# Braendselstyper: Disse kan ikke ændres af scenarier.
# fsto:  Brændsler, som må lagres (bemærk af tømning af lagre er en særskilt restriktion)
# fdis:  Brændsler, som skal modtages og forbrændes hhv. om muligt lagres.
# ffri:  Brændsler, hvor den øvre grænse aftagemængde er en optimeringsvariabel.
# fflex: Brændsler, hvor månedstonnagen er fri, men årstonnagen skal respekteres.
# fx:  Brændsler, som ikke er affaldsbrændsler.

fa(f)    = DataFuel(f,'fkind') EQ 1;
fb(f)    = DataFuel(f,'fkind') EQ 2;
fc(f)    = DataFuel(f,'fkind') EQ 3;
fr(f)    = DataFuel(f,'fkind') EQ 4;
fx(f)    = NOT fa(f);
fsto(f)  = DataFuel(f,'Lagerbar') NE 0;
fdis(f)  = DataFuel(f,'Bortskaf') NE 0;
ffri(f)  = DataFuel(f,'Fri')      NE 0 AND fa(f);
fflex(f) = DataFuel(f,'Flex')     NE 0 AND fa(f);

# Identifikation af lagertyper.
sa(s) = DataSto(s,'stoKind') EQ 1;
sq(s) = DataSto(s,'stoKind') EQ 2;

# Tilknytning af affaldsfraktioner til lagre.
# Brugergivne restriktioner på kombinationer af lagre og brændselsfraktioner.
s2f(s,f)   = no;
s2f(sa,fa) = DataFuel(fa,'lagerbar') AND DataSto(sa,'aktiv');

# Brugergivet tilknytning af lagre til affaldsfraktioner kræver oprettelse af nye elementer i labDataFuel.
Loop (fa,
  s2f('sto1',fa) = s2f('sto1',fa) AND (DataFuel(fa,'InitSto1') GE 0);
  s2f('sto2',fa) = s2f('sto2',fa) AND (DataFuel(fa,'InitSto2') GE 0);
);

# Kompabilitet mellem anlæg og brændsler.
u2f(u,f)   = no;
u2f(ub,fb) = yes;
u2f(uc,fc) = yes;
u2f(ur,fr) = yes;

# Brugergivne restriktioner på kombinationer af affaldsanlæg og brændselsfraktioner.
ufparm(u,f) = no;
sfparm(s,f) = no;

# OBS: Tilknytning af braendsel til ejer underforstaar eksklusivitet.
f2own(f,owner)           = no;
f2own(fa,        'refa') = yes;
f2own('NSvarme', 'refa') = yes;
f2own('flis',    'refa') = yes;
f2own('peakfuel','gsf')  = yes;

frefa(f)         = no;
frefa(fa)        = yes;
frefa('flis')    = yes;

fgsf(f)          = no;
fgsf('NSvarme')  = yes;
fgsf('peakfuel') = yes;

IncludePlant(urefa) = IncludeOwner('refa');
IncludePlant('NS')  = IncludeOwner('refa');

IncludeFuel(frefa)  = IncludeOwner('refa');
IncludeFuel(fgsf)   = IncludeOwner('gsf');

#--- display f, fa, fb, fc, fr, fsto, fdis, ffri, u2f, IncludeOwner, IncludePlant, IncludeFuel;
#end Opsætning af subsets, som IKKE afledes af inputdata.

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


$If not errorfree $exit


# Initialisering af arbejdsvariable som anvendes i Equations.
Parameter Phi(phiKind,moall)      'Aktuel værdi af Phi = Fbiogen/F';
Parameter QtotalAffMax(moall)     'Max. aff-varme';
Parameter QbypassMax(moall)       'Max. bypass-varme';
Parameter StoCostLoadMax(s)       'Max. lageromkostning';

mo(moall) = yes;
OnGU(u)   = yes;
OnGS(s)   = yes;
OnGF(f)   = yes;
OnU(u,moall)    = yes;
OnS(s,moall)    = yes;
OnF(f,moall)    = yes;
EtaQ(u,moall)   = NaN;
EtaRgk(u,moall) = NaN;
LhvMWh(f,moall) = NaN;

# ------------------------------------------------------------------------------------------------
# Erklaering af variable.
# ------------------------------------------------------------------------------------------------
Free     variable NPV                           'Nutidsvaerdi af affaldsdisponering';

Binary   variable bOnU(u,moall)                 'Anlaeg on-off';
Binary   variable bOnRgk(ua,moall)              'Affaldsanlaeg RGK on-off';
Binary   variable bOnRgkRabat(moall)            'Indikator for om der i given kan opnaas RGK rabat';
Binary   variable bOnSto(s,moall)               'Indikator for om et lager bruges i given maaned ';

Positive variable FuelConsT(u,f,moall)          'Drivmiddel forbrug på hvert anlaeg [ton]';
Positive variable FuelConsP(f,moall)            'Effekt af drivmiddel forbrug [MWf]';
Positive variable FuelResaleT(f,moall)          'Drivmiddel gensalg / ikke-udnyttet [ton]';
Positive variable FuelDelivT(f,moall)           'Drivmiddel leverance på hvert anlaeg [ton]';
Positive variable FuelDelivFreeSumT(f)          'Samlet braendselsmængde frie fraktioner';

Free     variable StoDLoadF(s,f,moall)          'Lagerført brændsel (pos. til lager)';

Positive variable StoCostAll(s,moall)           'Samlet lageromkostning';
Positive variable StoCostLoad(s,moall)          'Lageromkostning på beholdning';
Positive variable StoCostDLoad(s,moall)         'Transportomk. til/fra lagre';
Positive variable StoLoad(s,moall)              'Aktuel lagerbeholdning';
Positive variable StoLoss(s,moall)              'Aktuelt lagertab';
Positive variable StoLossF(s,f,moall)           'Lagertab på affaldsfraktioner [ton]';
Free     variable StoDLoad(s,moall)             'Aktuel lagerændring positivt indgående i lager';
Positive variable StoDLoadAbs(s,moall)          'Absolut værdi af StoDLoad';
Positive variable StoLoadF(s,f,moall)           'Lagerbeholdning af givet brændsel på givet lager';


Positive variable PbrutMax(moall)               'Max. mulige brutto elproduktion [MWhe]';
Positive variable Pbrut(moall)                  'Brutto elproduktion [MWhe]';
Positive variable Pnet(moall)                   'Netto elproduktion [MWhe]';
Positive variable Qbypass(moall)                'Bypass varme [MWhq]';
Positive variable Q(u,moall)                    'Grundlast MWq';
Positive variable QaffM(ua,moall)               'Modtryksvarme på affaldsanlaeg MWq';
Positive variable Qrgk(u,moall)                 'RGK produktion MWq';
Positive variable Qafv(moall)                   'Varme pålagt affaldvarmeafgift';
Positive variable QRgkMiss(moall)               'Slack variabel til beregning om RGK-rabat kan opnaas';

Positive variable FEBiogen(u,moall)             'Indfyret biogen affaldsenergi [MWhf]';
Positive variable FuelHeatAff(moall)            'Afgiftspligtigt affald medgået til varmeproduktion';
Positive variable QBiogen(u,moall)              'Biogen affaldsvarme [GJ]';

Positive variable QtotalCool(moall)             'Sum af total bortkølet varme på affaldsanlæg';
Positive variable QtotalAff(moall)              'Sum af total varmeproduktion på affaldsanlæg';
Positive variable EtotalAff(moall)              'Sum af varme- og elproduktion på affaldsanlæg';
Positive variable QtotalAfgift(phiKind,moall)   'Afgiftspligtig varme ATL- hhv. CO2-afgift';
Positive variable QudenRgk(moall)               'Afgiftspligtig varme (ATL, CO2) uden RGK-rabat';
Positive variable QmedRgk(moall)                'Afgiftspligtig varme (ATL, CO2) med RGK-rabat';
Positive variable Quden_X_bOnRgkRabat(moall)    'Produktet bOnRgkRabat * Qtotal';
Positive variable Qmed_X_bOnRgkRabat(moall)     'Produktet (1 - bOnRgkRabat) * Qtotal';

Positive variable IncomeTotal(moall)            'Indkomst total';
Positive variable IncomeElec(moall)             'El-indkomst [DKK]';
Positive variable IncomeHeat(moall)             'Indkomnst for varmesalg til GSF';
Positive variable IncomeAff(f,moall)            'Indkomnst for affaldsmodtagelse DKK';
Positive variable RgkRabat(moall)               'RGK rabat på tillaegsafgift';
Positive variable CostsTotal(moall)             'Omkostninger Total';
Positive variable CostsTotalOwner(owner,moall)  'Omkostninger Total fordelt på ejere';
Positive variable CostsU(u,moall)               'Omkostninger anlægsdrift DKK';
#--- Positive variable CostsTotalF(owner, moall)   'Omkostninger Total på drivmidler DKK';
Positive variable CostsPurchaseF(f,moall)       'Omkostninger til braendselsindkoeb DKK';

Positive variable TaxAFV(moall)                 'Omkostninger til affaldvarmeafgift DKK';
Positive variable TaxATL(moall)                 'Omkostninger til affaldstillaegsafgift DKK';
Positive variable TaxCO2total(moall)            'Omkostninger til CO2-afgift DKK';
Positive variable TaxCO2Aff(moall)              'CO2-afgift på affald';
Positive variable TaxCO2Aux(moall)              'CO2-afgift på øvrige brændsler';
Positive variable TaxCO2F(f,moall)              'Omkostninger til CO2-afgift fordelt på braendselstype DKK';
Positive variable TaxNOxF(f,moall)              'Omkostninger til NOx-afgift fordelt på braendselstype DKK';
Positive variable TaxEnr(moall)                 'Energiafgift (gaelder kun fossiltfyrede anlaeg)';


Positive variable CostsETS(moall)               'Omkostninger til CO2-kvoter DKK';
Positive variable CO2emisF(f,moall,typeCO2)     'CO2-emission fordelt på type';
Positive variable CO2emisAff(moall,typeCO2)     'Afgifts- hhv. kvotebelagt affaldsemission';
Positive variable TotalAffEProd(moall)          'Samlet energiproduktion affaldsanlaeg';

Positive variable QInfeas(dir,moall)            'Virtual varmedraen og -kilde [MWhq]';
Positive variable AffTInfeas(dir,moall)         'Virtual affaldstonnage kilde og dræn [ton]';
# ------------------------------------------------------------------------------------------------
# Erklaering af ligninger.
# RGK kan moduleres kontinuert: RGK deaktiveres hvis Qdemand < Qmodtryk
# ------------------------------------------------------------------------------------------------
# Fordeling af omkostninger mellem affalds- og varmesiden:
# * AffaldsOmkAndel er andelen, som affaldssiden skal bære.
# * Til affaldssiden 100 pct: Kvoteomkostning
# * Til fordeling: Alle afgifter
# ------------------------------------------------------------------------------------------------

Equation  ZQ_Obj                           'Objective';
Equation  ZQ_IncomeTotal(moall)            'Indkomst Total';
Equation  ZQ_IncomeElec(moall)             'Indkomst Elsalg';
Equation  ZQ_IncomeHeat(moall)             'Indkomst Varmesalg til GSF';
Equation  ZQ_IncomeAff(f,moall)            'Indkomst på affaldsfraktioner';
Equation  ZQ_CostsTotal(moall)             'Omkostninger Total';
Equation  ZQ_CostsTotalOwner(owner,moall)  'Omkostninger fordelt på ejer';
Equation  ZQ_CostsU(u,moall)               'Omkostninger på anlaeg';
#--- Equation  ZQ_CostsTotalF(owner,moall)    'Omkostninger totalt på drivmidler';
Equation  ZQ_CostsPurchaseF(f,moall)       'Omkostninger til køb af affald fordelt på affaldstyper';
Equation  ZQ_TaxAFV(moall)                 'Affaldsvarmeafgift DKK';
Equation  ZQ_TaxATL(moall)                 'Affaldstillaegsafgift foer evt. rabat DKK';
Equation  ZQ_TaxNOxF(f,moall)              'NOx-afgift på brændsler';
Equation  ZQ_TaxEnr(moall)                 'Energiafgift på fossil varme';

Equation ZQ_FuelConsP(f,moall);
Equation ZQ_FEBiogen(ua,moall);
Equation ZQ_QtotalCool(moall);
Equation ZQ_QtotalAff(moall);
Equation ZQ_EtotalAff(moall);
Equation ZQ_QtotalAfgift(phiKind,moall);
Equation ZQ_QUdenRgk(moall);
Equation ZQ_QMedRgk(moall);
Equation ZQ_QudenRgkProductMax1(moall);
Equation ZQ_QudenRgkProductMin2(moall);
Equation ZQ_QudenRgkProductMax2(moall);
Equation ZQ_QmedRgkProductMax1(moall);
Equation ZQ_QmedRgkProductMin2(moall);
Equation ZQ_QmedRgkProductMax2(moall);

Equation ZQ_TaxCO2total(moall);
Equation ZQ_TaxCO2Aff(moall);
Equation ZQ_TaxCO2Aux(moall);

Equation  ZQ_CostsETS(moall)             'CO2-kvoteomkostning DKK';
Equation  ZQ_TaxCO2total(moall)          'CO2-afgift DKK';
#--- Equation  ZQ_TaxCO2F(f,moall)            'CO2-afgift fordelt på braendselstyper DKK';
Equation  ZQ_Qafv(moall)                 'Varme hvoraf der skal svares AFV [MWhq]';
Equation  ZQ_CO2emisF(f,moall,typeCO2)   'CO2-maengde hvoraf der skal svares afgift hhv. ETS [ton]';
Equation  ZQ_CO2emisAff(moall,typeCO2);

Equation  ZQ_PrioUp(up,up,moall)         'Prioritet af uprio over visse up anlaeg';


# OBS: GSF-omkostninger skal medtages i Obj for at sikre at varme leveres fra REFAs anlæg.
#      REFA's økonomi vil blive optimeret selvom GSF-omkostningerne er medtaget, netop fordi
#      GSF's varmeproduktionspris er (betydeligt) højere end REFA's.
# Hvordan med Nordic Sugars varmeleverance?
#   Den pålægges en overskudsvarmeafgift, som kan resultere i en lavere VPO_V end REFA kan præstere med indkøbt affald hhv. flis.
#   Dermed er det ikke umiddelbart let at afgøre, om NS-varmen indebærer en omkostning for REFA.
#   NS-varmen leveres højst i månederne okt-feb med tyngden i nov-jan, en periode hvor REFAs affaldsanlæg er udlastede.

ZQ_Obj  ..  NPV  =E=  sum(mo,
                         IncomeTotal(mo)
                         + sum(ua, Gain_Qaff(ua) * QaffM(ua,mo))   # Kun modtryksvarme skal fremmes, idet RGK ikke skal være aktiv når bortkøling er aktiv.
                         - CostsTotal(mo)
                         - [
                             + Penalty_bOnU     * sum(u $OnU(u,mo), bOnU(u,mo))
                             + Penalty_QRgkMiss * QRgkMiss(mo)
                             + [Penalty_QInfeas        * sum(dir, QInfeas(dir,mo))]    $OnQInfeas
                             + [Penalty_AffTInfeas     * sum(dir, AffTInfeas(dir,mo))] $OnAffTInfeas
                             + [Penalty_AffaldsGensalg * sum(f $OnF(f,mo), FuelResaleT(f,mo))]
                           ] );

ZQ_IncomeTotal(mo)   .. IncomeTotal(mo)   =E=  sum(fa $OnF(fa,mo), IncomeAff(fa,mo)) + RgkRabat(mo) + IncomeElec(mo) + IncomeHeat(mo);

ZQ_IncomeElec(mo)   ..  IncomeElec(mo)    =E=  Pnet(mo) * (PowerPrice(mo) - TariffElProd(mo));

ZQ_IncomeHeat(mo)   ..  IncomeHeat(mo)    =E=  VarmeSalgspris * sum(u $(OnU(u,mo) AND up(u) AND urefa(u)), Q(u,mo));

ZQ_IncomeAff(fa,mo)  .. IncomeAff(fa,mo)  =E=  FuelDelivT(fa,mo) * FuelBounds(fa,'Pris',mo) $(OnF(fa,mo) AND fpospris(fa,mo));

ZQ_CostsTotal(mo)    .. CostsTotal(mo)    =E= sum(owner, CostsTotalOwner(owner,mo));

ZQ_CostsTotalOwner(owner,mo) .. CostsTotalOwner(owner,mo)  =E=
                                [  sum(urefa $OnU(urefa,mo), CostsU(urefa,mo))
                                 + sum(s $OnS(s,mo), StoCostAll(s,mo))
                                 + sum(frefa $OnF(frefa,mo), CostsPurchaseF(frefa,mo) + TaxNOxF(frefa,mo))
                                 + TaxAFV(mo) + TaxATL(mo) + TaxCO2Aff(mo) + CostsETS(mo)
                                ] $sameas(owner,'refa')
                              + [  sum(ugsf $OnU(ugsf,mo), CostsU(ugsf,mo))
                                 + sum(fgsf $OnF(fgsf,mo), CostsPurchaseF(fgsf,mo) + TaxNOxF(fgsf,mo))
                                 + TaxCO2Aux(mo) + TaxEnr(mo)
                                ] $sameas(owner,'gsf');

ZQ_CostsU(u,mo)      .. CostsU(u,mo)      =E=  [Q(u,mo) * DvMWhq(u,mo) + bOnU(u,mo) * DvTime(u,mo)] $OnU(u,mo);

ZQ_CostsPurchaseF(f,mo) $(OnF(f,mo) AND fnegpris(f,mo)) .. CostsPurchaseF(f,mo)  =E=  FuelDelivT(f,mo) * (-FuelBounds(f,'Pris',mo));

# Beregning af afgiftspligtigt affald.

ZQ_FuelConsP(f,mo) $OnF(f,mo) .. FuelConsP(f,mo)  =E=  sum(u $(OnU(u,mo) AND u2f(u,f)), FuelConsT(u,f,mo) * LhvMWh(f,mo));  #---  + [AffTInfeas('source',mo) - AffTInfeas('drain',mo)] * LhvMWhAffTInfeas $OnAffTInfeas;

# Opgørelse af biogen affaldsmængde for hver ovn-linje.
ZQ_FEBiogen(ua,mo) .. FEBiogen(ua,mo)  =E=  sum(fbiogen $(OnF(fbiogen,mo) AND u2f(ua,fbiogen)), FuelConsT(ua,fbiogen,mo) * LhvMWh(fbiogen,mo));

# Opsummering af varmemængder til mere overskuelig afgiftsberegning.
ZQ_QtotalCool(mo) ..  QtotalCool(mo)  =E=  sum(uv $OnU(uv,mo), Q(uv,mo));
ZQ_QtotalAff(mo)  ..  QtotalAff(mo)   =E=  sum(ua $OnU(ua,mo), Q(ua,mo));
ZQ_EtotalAff(mo)  ..  EtotalAff(mo)   =E=  QtotalAff(mo) + Pbrut(mo);

# Affaldvarme-afgift:
ZQ_TaxAFV(mo)     .. TaxAFV(mo)     =E=  TaxAfvMWh(mo) * Qafv(mo);
ZQ_Qafv(mo)       .. Qafv(mo)       =E=  sum(ua $OnU(ua,mo), Q(ua,mo) - 0.85 * FEBiogen(ua,mo)) - sum(uv $OnU(uv,mo), Q(uv,mo));   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.

# Fælles for affaldstillægs- og CO2-afgift.
ZQ_QUdenRgk(mo)   .. QudenRgk(mo)  =E=  (1 - Phi('85',mo)) * [QtotalAff(mo)                      ] / 1.2;
ZQ_QMedRgk(mo)    .. QmedRgk(mo)   =E=  (1 - Phi('95',mo)) * [QtotalAff(mo) - 0.1 * EtotalAff(mo)] / 1.2;
#--- BUGFIX: ZQ_QMedRgk(mo)    .. QmedRgk(mo)   =E=  [QtotalAff(mo) - 0.1 * EtotalAff(mo) * (1 - Phi('95',mo))] / 1.2;

# Beregn produktet af bOnRgkRabat * QmedRgk hhv (1 - bOnRgkRabat) * QudenRgk.
# Produktet bruges i ZQ_TaxATL hhv. ZQ_TaxCO2Aff.

# Afgiftspligtig affaldsmængde henført til varmeproduktion.
#Bugfix: Mangler faktor 1.2:
#--- ZQ_QtotalAfgift(phiKind,mo) .. QtotalAfgift(phiKind,mo)  =E=  [QtotalAff(mo) - 0.1 * EtotalAff(mo) $sameas(phiKind,'95') ] * (1 - phi(phiKind,mo));
ZQ_QtotalAfgift(phiKind,mo) .. QtotalAfgift(phiKind,mo)  =E=  (1 - phi(phiKind,mo)) * [QtotalAff(mo) - 0.1 * EtotalAff(mo) $sameas(phiKind,'95')] / 1.2 ;

# Beregning af afgiftspligtig varme når bOnRgkRabat == 0, dvs. når (1 - bOnRgkRabat) == 1.
ZQ_QudenRgkProductMax1(mo) .. Quden_X_bOnRgkRabat(mo)                          =L=  (1 - bOnRgkRabat(mo)) * QtotalAffMax(mo);
ZQ_QudenRgkProductMin2(mo) .. 0                                                =L=  QtotalAfgift('85',mo) - Quden_X_bOnRgkRabat(mo);
ZQ_QudenRgkProductMax2(mo) .. QtotalAfgift('85',mo) - Quden_X_bOnRgkRabat(mo)  =L=  bOnRgkRabat(mo) * QtotalAffMax(mo);

# Beregning af afgiftspligtig varme når bOnRgkRabat == 1.
ZQ_QmedRgkProductMax1(mo) .. Qmed_X_bOnRgkRabat(mo)                          =L=  bOnRgkRabat(mo) * QtotalAffMax(mo);
ZQ_QmedRgkProductMin2(mo) .. 0                                               =L=  QtotalAfgift('95',mo) - Qmed_X_bOnRgkRabat(mo);
ZQ_QmedRgkProductMax2(mo) .. QtotalAfgift('95',mo) - Qmed_X_bOnRgkRabat(mo)  =L=  (1 - bOnRgkRabat(mo)) * QtotalAffMax(mo);

# Tillægsafgift af affald baseret på SKAT's administrative satser:
ZQ_TaxATL(mo)     .. TaxATL(mo)    =E=  TaxAtlMWh(mo) * (Quden_X_bOnRgkRabat(mo) + Qmed_X_bOnRgkRabat(mo));

# CO2-afgift for alle anlæg:
ZQ_TaxCO2total(mo) .. TaxCO2total(mo)  =E=  TaxCO2Aff(mo) + TaxCO2Aux(mo);

# CO2-afgift af affald baseret på SKAT's administrative satser:
#Bugfix: EY-beregninger inddrager ikke elproduktionen (ER IKKE CHECKET OM DET STEMMER OVERENS MED CO2-AFGIFTSLOVEN)
#--- ZQ_TaxCO2Aff(mo) ..  TaxCO2Aff(mo)  =E=  TaxCO2AffTon(mo) * CO2ContentAff(mo) * (Quden_X_bOnRgkRabat(mo) + Qmed_X_bOnRgkRabat(mo));
ZQ_TaxCO2Aff(mo) ..  TaxCO2Aff(mo)  =E=  TaxCO2AffTon(mo) * CO2ContentAff(mo) * QudenrGK(mo);

ZQ_CostsETS(mo)  ..  CostsETS(mo)   =E=   TaxEtsTon(mo) * sum(fa $OnF(fa,mo), CO2emisF(fa,mo,'kvote'));  # Kun affaldsanlægget er kvoteomfattet.

# CO2-afgift på ikke-affaldsanlæg (p.t. ingen afgift på biomasse):
ZQ_TaxCO2Aux(mo)  .. TaxCO2Aux(mo)  =E=  sum(fr $OnF(fr,mo), sum(ur $(OnU(ur,mo) AND u2f(ur,fr)), FuelConsT(ur,fr,mo))) * TaxCO2peakTon(mo);

# Den fulde CO2-emission uden hensyntagen til fradrag for elproduktion, da det kun vedrører beregning af CO2-afgiften, men ikke mængden.
ZQ_CO2emisF(f,mo,typeCO2) $OnF(f,mo) .. CO2emisF(f,mo,typeCO2)  =E=  sum(u $(OnU(u,mo) AND u2f(u,f)), FuelConsT(u,f,mo)) * CO2potenTon(f,typeCO2,mo);
ZQ_CO2emisAff(mo,typeCO2)            .. CO2emisAff(mo,typeCO2)  =E=  sum(fa, CO2emisF(fa,mo,typeCO2));

# NOx-afgift:
ZQ_TaxNOxF(f,mo) $OnF(f,mo) .. TaxNOxF(f,mo)  =E=  sum(ua $(OnU(ua,mo) AND u2f(ua,f)), FuelConsT(ua,f,mo)) * DataFuel(f,'NOxKgTon') * TaxNOxAffkg(mo) $fa(f)
                                                 + sum(ub $(OnU(ub,mo) AND u2f(ub,f)), FuelConsT(ub,f,mo)) * TaxNOxFlisTon(mo) $fb(f)
                                                 + sum(ur $(OnU(ur,mo) AND u2f(ur,f)), FuelConsT(ur,f,mo)) * TaxNOxPeakTon(mo) $fr(f);

# Energiafgift SR-kedel:
ZQ_TaxEnr(mo)              .. TaxEnr(mo)     =E=  sum(ur $OnU(ur,mo), FuelConsT(ur,'peakfuel',mo)) * TaxEnrPeakTon(mo);

# Prioritering af anlægsdrift.
# Aktiveringsprioritering: Sikrer kun aktivering, men ikke udlastning/udregulering.
ZQ_PrioUp(uprio,up,mo) $(OnU(uprio,mo) AND OnU(up,mo) AND AvailDaysU(mo,uprio) AND AvailDaysU(mo,up)) ..  bOnU(up,mo)  =L=  bOnU(uprio,mo);

# NS-varme skal udnyttes fuldt ud efter Ovn3 og før Ovn2 kommer i indgreb. Da NS kun kommer om vinteren, tvinges NS-varmen ind i fuldt omfang fremfor et loft.
Equation ZQ_PrioNS(moall) 'NS-varme skal udnyttes fuldt ud';
ZQ_PrioNS(mo) $OnU('NS',mo) .. Q('NS',mo)  =E=  NSprod(mo) * bOnU('NS',mo);

# Desuden skal REFA-anlæg være udlastet, inden GSF-anlæg starter, idet GSF-anlæg ikke skal optræde i OBJ, da det vil forcere Ovn3 i bypass og maksimere RGK.
# GSF-omkostninger er REFA uvedkommende.
# Så det er reelt en model med to ejere, men kun den enes økonomi skal optimeres.
# Da GSF-anlæg ikke kan optræde i OBJ, må udlastning af REFA-anlæg derfor sikres på anden vis.


#begin Beregning af RGK-rabat
# -------------------------------------------------------------------------------------------------------------------------------
# Beregning af RGK-rabatten indebærer 2 trin:
#   1: Bestem den manglende RGK-varme QRgkMiss, som er nødvendig for at opnå rabatten.
#      Det gøres med en ulighed samt en penalty på QRgkMiss i objektfunktionen for at tvinge den mod nul, når rabatten er i hus.
#   2: Beregn rabatten ved den ulineære ligning: RgkRabat =E= bOnRgkRabat * (RgkRabatSats * TaxATL);
#      Produktet af de 2 variable bOnRgkRabat og TaxATL omformuleres vha. 4 ligninger, som indhegner RgkRabat.
# --------------------------------------------------------------------------------------------------------------------------------
Equation  ZQ_TotalAffEprod(moall)  'Samlet energiproduktion MWh';
Equation  ZQ_QRgkMiss(moall)       'Bestem manglende RGK-varme for at opnaa rabat';
Equation  ZQ_bOnRgkRabat(moall)    'Bestem bOnRgkRabat';

ZQ_TotalAffEprod(mo)  ..  TotalAffEProd(mo)  =E=  Pbrut(mo) + sum(ua $OnU(ua,mo), Q(ua,mo));       # Samlet energioutput fra affaldsanlæg. Bruges til beregning af RGK-rabat.
ZQ_QRgkMiss(mo)       ..  sum(ua $OnU(ua,mo), Qrgk(ua,mo)) + QRgkMiss(mo)  =G=  RgkRabatMinShare * TotalAffEProd(mo);
ZQ_bOnRgkRabat(mo)    ..  QRgkMiss(mo)  =L=  (1 - bOnRgkRabat(mo)) * QRgkMissMax(mo);

#OBS: Udkommenteresde inaktive / ugyldige restriktioner slettet

# Beregning af produktet: RgkRabat =E= bOnRgkRabat * (RgkRabatSats * TaxATL);
#--- Equation  ZQ_RgkRabatMin1(moall);
Equation  ZQ_RgkRabatMax1(moall);
Equation  ZQ_RgkRabatMin2(moall);
Equation  ZQ_RgkRabatMax2(moall);

#--- ZQ_RgkRabatMin1(mo) .. 0  =L=  RgkRabat(mo);
ZQ_RgkRabatMax1(mo) ..  RgkRabat(mo)                              =L=  RgkRabatMax(mo) * bOnRgkRabat(mo);
ZQ_RgkRabatMin2(mo) ..  0 * (1 - bOnRgkRabat(mo))                 =L=  RgkRabatSats * TaxATL(mo) - RgkRabat(mo);
ZQ_RgkRabatMax2(mo) ..  RgkRabatSats * TaxATL(mo) - RGKrabat(mo)  =L=  RgkRabatMax(mo) * (1 - bOnRgkRabat(mo));

#end Beregning af RGK-rabat

#begin Varmebalancer og elproduktion
Equation ZQ_PbrutMin(moall)              'Mindste brutto elproduktion';
Equation ZQ_PbrutMax(moall)              'Brutto elproduktion baseret på modtryksvarme og eta';
Equation ZQ_Pbrut(moall)                 'Brutto elproduktion';
Equation ZQ_Pnet(moall)                  'Netto elproduktion';
Equation ZQ_Qbypass(moall)               'Bypass varmeproduktion';

Equation  ZQ_Qdemand(moall)              'Opfyldelse af fjv-behov';
Equation  ZQ_Qaff(ua,moall)              'Samlet varmeprod. affaldsanlaeg';
Equation  ZQ_QaffM(ua,moall)             'Samlet modtryks-varmeprod. affaldsanlaeg';
Equation  ZQ_Qrgk(ua,moall)              'RGK produktion på affaldsanlaeg';
Equation  ZQ_QrgkMax(ua,moall)           'RGK produktion oevre graense';
Equation  ZQ_Qaux(u,moall)               'Samlet varmeprod. oevrige anlaeg end affald';
Equation  ZQ_QaffMmax(ua,moall)          'Max. modtryksvarmeproduktion';
Equation  ZQ_CoolMax(moall)              'Loft over bortkoeling';
Equation  ZQ_QminAux(u,moall)            'Sikring af nedre graense på varmeproduktion på ikke-affaldsanlæg';
Equation  ZQ_QMaxAux(u,moall)            'Aktiv status begraenset af total raadighed på ikke-affaldsanlæg';
Equation  ZQ_QminAff(u,moall)            'Sikring af nedre graense på varmeproduktion på affaldsanlæg';
Equation  ZQ_QMaxAff(u,moall)            'Aktiv status begraenset af total raadighed på affaldsanlæg';
Equation  ZQ_bOnRgk(ua,moall)            'Angiver om RGK er aktiv';
Equation  ZQ_bOnRgkMax(u,moall)          'Forebygger RGK når bortkøling er aktiv';
Equation  ZQ_QrgkTandem(moall)           'Hvis RGK er aktiv, gælder det begge affaldsovne';  # Skyldes røggaskobling i RGK-anlægget.

# Beregning af elproduktion. Det antages, at omsætning fra bypass-damp til fjernvarme er 1-til-1, dvs. 100 pct. effektiv bypass-drift.
#--- ZQ_PbrutMax(mo)$OnGU('Ovn3')  .. PbrutMax(mo) =E=  EtaE('Ovn3',mo) * sum(fa $(OnGF(fa) AND u2f('Ovn3',fa)), FuelConsT('Ovn3',fa,mo) * LhvMWh(fa));
#--- ZQ_Pbrut(mo)   $OnGU('Ovn3')  .. Pbrut(mo)    =E=  PbrutMax(mo) * (1 - ShareBypass(mo));
#--- ZQ_Pnet(mo)    $OnGU('Ovn3')  .. Pnet(mo)     =E=  Pbrut(mo) - Peget(mo) * (1 - ShareBypass(mo));  # Peget har taget hensyn til bypass.
#--- ZQ_Pnet(mo)    $OnGU('Ovn3')  .. Pnet(mo)     =L=  Pbrut(mo) - Peget(mo) * (1 - ShareBypass(mo));  # Peget har taget hensyn til bypass.
#--- ZQ_Pbrut(mo)   $OnGU('Ovn3')  .. Pbrut(mo)    =L=  PbrutMax(mo) * (1 - ShareBypass(mo));
#--- ZQ_Qbypass(mo) $OnGU('Ovn3')  .. Qbypass(mo)  =E=  (PbrutMax(mo) - Peget(mo)) * ShareBypass(mo);

#TODO: Omkostninger til at dække el-egetforbruget, når turbinen er ude, er ikke medtaget i objektfunktionen.

# PbrutMax er begrænset af QAffM, som igen er begrænset af ShareAvailU('Ovn3',mo) via QaffMmax.
# Derfor skal PbrutMax herunder først bringes tilbage til fuldt rådighedsniveau af Ovn3, dernæst multipliceres med turbinens rådighed.
# Egetforbruget dækkes kun når turbinen er til rådighed.
ZQ_PbrutMin(mo) $OnU('Ovn3',mo) .. Pbrut(mo)    =G=  Peget(mo) * bOnU('Ovn3',mo);
ZQ_PbrutMax(mo) $OnU('Ovn3',mo) .. PbrutMax(mo) =E=  EtaE('Ovn3',mo) * QAffM('Ovn3',mo) / EtaQ('Ovn3',mo);
ZQ_Pbrut(mo)    $OnU('Ovn3',mo) .. Pbrut(mo)    =L=  PbrutMax(mo) / ShareAvailU('Ovn3',mo) * ShareAvailTurb(mo);   # Egetforbruget dækkes kun når turbinen er til rådighed.
ZQ_Pnet(mo)     $OnU('Ovn3',mo) .. Pnet(mo)     =E=  Pbrut(mo) - Peget(mo);
ZQ_Qbypass(mo)  $OnU('Ovn3',mo) .. Qbypass(mo)  =E=  PbrutMax(mo) - Pbrut(mo);  # Antager 100 pct. effektiv bypass-drift.

ZQ_Qdemand(mo)                  ..  Qdemand(mo)   =E=  sum(up $OnU(up,mo), Q(up,mo)) - sum(uv $OnU(uv,mo), Q(uv,mo)) + [QInfeas('source',mo) - QInfeas('drain',mo)] $OnQInfeas;
ZQ_Qaff(ua,mo)     $OnU(ua,mo)  ..  Q(ua,mo)      =E=  [QaffM(ua,mo) + Qrgk(ua,mo)] + Qbypass(mo) $sameas(ua,'Ovn3');
ZQ_QaffM(ua,mo)    $OnU(ua,mo)  ..  QaffM(ua,mo)  =E=  EtaQ(ua,mo) * [sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), FuelConsT(ua,fa,mo) * LhvMWh(fa,mo))] $OnU(ua,mo);
ZQ_QaffMmax(ua,mo) $OnU(ua,mo)  ..  QAffM(ua,mo)  =L=  QaffMmax(ua,mo);
ZQ_Qrgk(ua,mo)     $OnU(ua,mo)  ..  Qrgk(ua,mo)   =L=  KapRgk(ua,mo) / KapQNom(ua,mo) * QaffM(ua,mo);
ZQ_QrgkMax(ua,mo)  $OnU(ua,mo)  ..  Qrgk(ua,mo)   =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);

ZQ_Qaux(upx,mo) $OnU(upx,mo)  ..  Q(upx,mo)  =E=  [sum(fx $(OnF(fx,mo) AND u2f(upx,fx)), FuelConsT(upx,fx,mo) * EtaQ(upx,mo) * LhvMWh(fx,mo))] $OnU(upx,mo);

ZQ_CoolMax(mo)                    ..  sum(uv $OnU(uv,mo), Q(uv,mo))  =L=  sum(ua $OnU(ua,mo), Q(ua,mo));

ZQ_QMinAux(ux,mo) $OnU(ux,mo) ..  Q(ux,mo)  =G=  ShareAvailU(ux,mo) * Hours(mo) * KapMin(ux,mo) * bOnU(ux,mo);   #  Restriktionen på timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
ZQ_QMaxAux(ux,mo) $OnU(ux,mo) ..  Q(ux,mo)  =L=  ShareAvailU(ux,mo) * Hours(mo) * KapMax(ux,mo) * bOnU(ux,mo);

# Grænser for varmeproduktion på affaldsanlæg indsættes kun, når affaldstonnage-summen ikke er fikseret.
#OBS: Qbypass indgår i Q('Ovn3',mo).
ZQ_QMinAff(ua,mo) $(OnU(ua,mo) AND NOT DoFixAffT(mo)) ..  Q(ua,mo)  =G=  ShareAvailU(ua,mo) * Hours(mo) * KapMin(ua,mo) * bOnU(ua,mo) + Qbypass(mo) $sameas(ua,'Ovn3');   #  Restriktionen på timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
ZQ_QMaxAff(ua,mo) $(OnU(ua,mo) AND NOT DoFixAffT(mo)) ..  Q(ua,mo)  =L=  ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua,mo) * bOnU(ua,mo) + Qbypass(mo) $sameas(ua,'Ovn3');

#--- ZQ_QrgkTandem(mo)  ..  bOnRgk('Ovn2',mo)  =E=  bOnRgk('Ovn3',mo);
ZQ_QrgkTandem(mo)   $(OnU('Ovn2',mo) AND OnU('Ovn3',mo))   ..  QRgk('Ovn2',mo)  =E=  Qrgk('Ovn3',mo) * kapRgk('Ovn2',mo) / kapRgk('Ovn3',mo);
ZQ_bOnRgk(ua,mo)    $OnU(ua,mo) ..  Qrgk(ua,mo)    =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);
ZQ_bOnRgkMax(ua,mo) $OnU(ua,mo) ..  bOnRgk(ua,mo)  =L=  (1 - sum(uv $OnU(uv,mo), bOnU(uv,mo)) / card(uv));

#end Varmebalancer

# Restriktioner på affaldsforbrug på aars- hhv. maanedsniveau.
# Dagrenovation skal bortskaffes hurtigt, hvilket sikres ved at angive mindstegraenser for affaldsforbrug på maanedsniveau.
# Andre drivmidler er lagerbarer og kan derfor disponeres over hele året, men skal også bortskaffes.

# Alle braendsler skal respektere nedre og oevre graense for forbrug.
# Alle ikke-lagerbare og bortskafbare braendsler skal respektere mindsteforbrug på maanedsniveau.
# Alle ikke-bortskafbare affaldsfraktioner skal respektere et jævn
# Ikke-bortskafbare braendsler (fdis(f)) skal kun respektere mindste- og størsteforbruget på maanedsniveau.
# Alle braendsler markeret som bortskaffes, skal bortskaffes indenfor et løbende aar (lovkrav for affald).
# Braendvaerdi af indfyret affaldsmix skal overholde mindstevaerdi.
# Kapaciteten af affaldsanlaeg er både bundet af tonnage [ton/h] og varmeeffekt.

# Disponering af affaldsfraktioner

Equation ZQ_FuelCons(f,moall)   'Relation mellem afbrændt, leveret og lagerført brændsel (if any)';

ZQ_FuelCons(f,mo)  $OnF(f,mo)  ..  sum(u $(OnU(u,mo) AND u2f(u,f)), FuelConsT(u,f,mo))  =E=  FuelDelivT(f,mo) - [sum(sa $(OnS(sa,mo) and s2f(sa,f)), StoDLoadF(sa,f,mo))] $fsto(f);

# Fiksering af affaldstonnager (option).
Equation ZQ_FixAffDelivSumT(moall) 'Fiksering af sum af affaldstonnager';
ZQ_FixAffDelivSumT(mo) $DoFixAffT(mo) .. sum(fa $OnF(fa,mo), FuelDelivT(fa,mo))  =E=  FixValueAffT(mo) - AffTInfeas('drain',mo) $OnAffTInfeas;

# Grænser for leverancer, når fiksering af affaldstonnage IKKE er aktiv.
Equation  ZQ_FuelMin(f,moall)   'Mindste drivmiddelforbrug på månedsniveau';
Equation  ZQ_FuelMax(f,moall)   'Stoerste drivmiddelforbrug på månedsniveau';
Equation  ZQ_FuelMinYear(f)     'Mindste braendselsforbrug på årsniveau';
Equation  ZQ_FuelMaxYear(f)     'Stoerste braendselsforbrug på årsniveau';

# Fleksible brændsler skal ikke overholde månedsgrænser, kun årsgrænser.
ZQ_FuelMin(f,mo) $(OnF(f,mo) AND fdis(f) AND NOT fflex(f) AND NOT ffri(f))  ..  FuelDelivT(f,mo) + FuelResaleT(f,mo)  =G=  FuelBounds(f,'MinTonnage',mo);
ZQ_FuelMax(f,mo) $(OnF(f,mo) AND fdis(f) AND NOT fflex(f))                  ..  FuelDelivT(f,mo) + FuelResaleT(f,mo)  =L=  FuelBounds(f,'MaxTonnage',mo) * (1 + 1E-6);  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.

ZQ_FuelMinYear(f)  $(OnGF(f) AND fdis(f)) ..  sum(mo $OnF(f,mo),  FuelDelivT(f,mo) + FuelResaleT(f,mo))    =G=  MinTonnageYear(f) * sum(mo $OnF(f,mo), 1) / 12;
ZQ_FuelMaxYear(fa) $(OnGF(fa))            ..  sum(mo $OnF(fa,mo), FuelDelivT(fa,mo) + FuelResaleT(fa,mo))  =L=  MaxTonnageYear(fa) * [(sum(mo $OnF(fa,mo), 1) / 12) $(NOT fflex(fa)) + 1 $fflex(fa)] * (1 + 1E-6);

# Krav til frie affaldsfraktioner.
Equation ZQ_FuelDelivFreeSum(f)              'Aarstonnage af frie affaldsfraktioner';
Equation ZQ_FuelMinFreeNonStorable(f,moall)  'Ligeligt tonnageforbrug af ikke-lagerbare frie affaldsfraktioner';

ZQ_FuelDelivFreeSum(ffri) $(OnGF(ffri) AND card(mo) GT 1)                               ..  FuelDelivFreeSumT(ffri)  =E=  sum(mo $OnF(ffri,mo), FuelDelivT(ffri,mo));
ZQ_FuelMinFreeNonStorable(ffri,mo) $(OnF(ffri,mo) AND NOT fsto(ffri) AND card(mo) GT 1) ..  FuelDelivT(ffri,mo)      =E=  FuelDelivFreeSumT(ffri) / card(mo);

# Restriktioner på tonnage og braendvaerdi for affaldsanlaeg.
# OBS: Aktiveres kun, hvis affaldstonnagesumme ikke er fikseret.
Equation ZQ_MinTonnage(u,moall)    'Mindste tonnage for affaldsanlaeg';
Equation ZQ_MaxTonnage(u,moall)    'Stoerste tonnage for affaldsanlaeg';
Equation ZQ_MinLhvAffald(u,moall)  'Mindste braendvaerdi for affaldsblanding';

ZQ_MinTonnage(ua,mo)   $(OnU(ua,mo) AND NOT DoFixAffT(mo))  ..  sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), FuelConsT(ua,fa,mo))  =G=  ShareAvailU(ua,mo) * Hours(mo) * MinTon(ua,mo);
ZQ_MaxTonnage(ua,mo)   $(OnU(ua,mo) AND NOT DoFixAffT(mo))  ..  sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), FuelConsT(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * MaxTon(ua,mo);
ZQ_MinLhvAffald(ua,mo) $(OnU(ua,mo) AND NOT DoFixAffT(mo))  ..  MinLhvMWh(ua,mo) * sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), FuelConsT(ua,fa,mo))  =L=  sum(fa $(OnF(fa,mo) AND u2f(ua,fa)), FuelConsT(ua,fa,mo) * LhvMWh(fa,mo));

# Lagerdisponering.
Equation ZQ_StoCostAll(s,moall)       'Samlet lageromkostning';
Equation ZQ_StoCostLoad(s,moall)      'Lageromkostning opbevaring';
Equation ZQ_StoCostDLoad(s,moall)     'Lageromkostning transport';
Equation ZQ_bOnSto(s,moall)           'Sikrer at bOnSto afspejler lagerbeholdning';
Equation ZQ_StoLoadMin(s,moall)       'Nedre grænse for lagerbeholdning';
Equation ZQ_StoLoadMax(s,moall)       'Øvre grænse for lagerbeholdning';
Equation ZQ_StoLoadQ(s,moall)         'Varmelagerbeholdning og -ændring';
Equation ZQ_StoLoadA(s,moall)         'Affaldslagerbeholdning og -ændring';
Equation ZQ_StoLoadF(s,f,moall)       'Tilvækst på affaldslagre';
Equation ZQ_StoLossF(s,f,moall)       'Lagertab på affaldsfraktioner';
Equation ZQ_StoLossA(s,moall)         'Lagertab proport. til beholdning';
Equation ZQ_StoLossQ(s,moall)         'Tab på varmelagre';
Equation ZQ_StoDLoad(s,moall)         'Samlet lagerændring';
Equation ZQ_StoDLoadMax(s,moall)      'Max. lagerændring';
Equation ZQ_StoDLoadAbs1(s,moall)     'Abs funktion på lagerændring StoDLoad';
Equation ZQ_StoDLoadAbs2(s,moall)     'Abs funktion på lagerændring StoDLoad';
Equation ZQ_StoFirstReset(s,moall)    'Første nulstilling af lagerbeholdning';
Equation ZQ_StoResetIntv(s,moall)     'Øvrige nulstillinger af lagerbeholdning';

ZQ_StoCostAll(s,mo)   $OnS(s,mo)  ..  StoCostAll(s,mo)    =E=  StoCostLoad(s,mo) + StoCostDLoad(s,mo);
ZQ_StoCostLoad(s,mo)  $OnS(s,mo)  ..  StoCostLoad(s,mo)   =E=  StoLoadCostRate(s,mo) * StoLoad(s,mo);
ZQ_StoCostDLoad(s,mo) $OnS(s,mo)  ..  StoCostDLoad(s,mo)  =E=  StoDLoadCostRate(s,mo) * StoDLoadAbs(s,mo);

ZQ_bOnSto(s,mo) $OnS(s,mo)        ..  StoCostAll(s,mo)    =L=  bOnSto(s,mo) * StoCostLoadMax(s);

ZQ_StoLoadMin(s,mo) $OnS(s,mo)    ..  StoLoad(s,mo)       =G=  StoLoadMin(s,mo);
ZQ_StoLoadMax(s,mo) $OnS(s,mo)    ..  StoLoad(s,mo)       =L=  StoLoadMax(s,mo);

ZQ_StoDLoad(sa,mo) $OnS(sa,mo)    ..  sum(fsto $(OnF(fsto,mo) AND s2f(sa,fsto)), StoDLoadF(sa,fsto,mo))  =E=  StoDLoad(sa,mo);

# Lageret af en given fraktion kan højst tømmes.

Equation ZQ_StoDLoadFMin(s,f,moall)  'Lagerbeholdningsændring af given fraktion';
Equation ZQ_StoLoadSum(s,moall)      'Sum af fraktioner på givet lager';

# Sikring af at StoDLoadF ikke overstiger lagerbeholdningen fra forrige måned og ikke trækker mere ud af lageret end beholdningen.
$OffOrder
ZQ_StoDLoadFMin(sa,fsto,mo) $(OnS(sa,mo) AND OnF(fsto,mo) AND s2f(sa,fsto)) .. [StoLoadInitF(sa,fsto) $(ord(mo) EQ 1) + StoLoadF(sa,fsto,mo-1) $(ord(mo) GT 1)] + StoDLoadF(sa,fsto,mo)  =G=  0.0;
$OnOrder
ZQ_StoLoadSum(s,mo) $OnS(s,mo)          .. StoLoad(s,mo)  =E=  sum(fsto $(OnF(fsto,mo) AND s2f(s,fsto)), StoLoadF(s,fsto,mo));

$OffOrder
#--- ZQ_StoLoad(s,mo) $OnGS(s)         ..  StoLoad(s,mo)         =E=  StoLoad(s,mo-1) + StoDLoad(s,mo) - StoLoss(s,mo-1);
#--- ZQ_StoLoadQ(sq,mo) $OnGS(sq)       ..  StoLoad(sq,mo)        =E=  [StoLoadInitF(s,fsto) $(ord(mo) EQ 1) + StoLoadF(sa,fsto,mo-1) $(ord(mo) GT 1)] + StoDLoadF(sa,fsto,mo) - StoLossF(sa,fsto,mo-1);
# Affaldslagre håndteres på fraktionsbasis, mens varmelagre kun indeholder ét species.
ZQ_StoLoadQ(sq,mo) $OnS(sq,mo)       ..  StoLoad(sq,mo)        =E=  [StoLoadInitQ(sq) $(ord(mo) EQ 1) + StoLoad(sq,mo-1) $(ord(mo) GT 1)] + StoDLoad(sq,mo) - StoLoss(sq,mo);
ZQ_StoLoadA(sa,mo) $OnS(sa,mo)       ..  StoLoad(sa,mo)        =E=  sum(fsto $(OnF(fsto,mo) AND s2f(sa,fsto)), StoLoadF(sa,fsto,mo));
ZQ_StoLoadF(sa,fsto,mo) $OnS(sa,mo)  ..  StoLoadF(sa,fsto,mo)  =E=  [StoLoadInitF(sa,fsto) $(ord(mo) EQ 1) + StoLoadF(sa,fsto,mo-1) $(ord(mo) GT 1)] + StoDLoadF(sa,fsto,mo) - StoLossF(sa,fsto,mo);
$OnOrder

ZQ_StoLossF(sa,fsto,mo) $(OnS(sa,mo) AND OnF(fsto,mo) AND s2f(sa,fsto))  ..  StoLossF(sa,fsto,mo)  =E=  StoLossRate(sa,mo) * StoLoadF(sa,fsto,mo);

ZQ_StoLossA(sa,mo) $OnS(sa,mo)  ..  StoLoss(sa,mo)     =E=  sum(fsto $(OnF(fsto,mo) and s2f(sa,fsto)), StoLossF(sa,fsto,mo));
ZQ_StoLossQ(sq,mo) $OnS(sq,mo)  ..  StoLoss(sq,mo)     =E=  StoLossRate(sq,mo) * StoLoad(sq,mo);

ZQ_StoDLoadMax(s,mo)            ..  StoDLoadAbs(s,mo)  =L=  StoDLoadMax(s,mo) $OnS(s,mo);
ZQ_StoDLoadAbs1(s,mo)           ..  +StoDLoad(s,mo)    =L=  StoDLoadAbs(s,mo) $OnS(s,mo);
ZQ_StoDLoadAbs2(s,mo)           ..  -StoDLoad(s,mo)    =L=  StoDLoadAbs(s,mo) $OnS(s,mo);

# OBS: ZQ_StoFirstReset dækker med én ligning pr. lager perioden frem til og med først nulstilling. Denne ligning tilknyttes første måned.
# TODO: Lageret fyldes op frem mod slutningen af planperioden, fordi modtageindkomsten gør det lukrativt.
#       Planperioden bør derfor indeholde et krav om tømning af lageret i dens sidste måned.
$OffOrder
ZQ_StoFirstReset(s,mo) $OnS(s,mo)  ..  sum(moa $(ord(mo) EQ 1 AND ord(mo) LE StoFirstReset(s)), bOnSto(s,moa))  =L=  StoFirstReset(s) - 1;
ZQ_StoResetIntv(s,mo)  $OnS(s,mo)  ..  sum(moa $(ord(mo) GT StoFirstReset(s) AND ord(moa) GE ord(mo) AND ord(moa) LE (ord(mo) - 1 + StoIntvReset(s))), bOnSto(s,moa))  =L=  StoIntvReset(s) - 1;
$OnOrder


# Erklæring af optimeringsmodels ligninger.
model modelREFA / all /;

#--- # DEBUG: Udskrivning af modeldata før solve.
#--- $gdxout "REFAmain.gdx"
#--- $unload
#--- $gdxout

$If not errorfree $exit

# End-of-Model-Declaration

# Erklæring af scenario Loop

set topic  / Tidsstempel, FJV-behov, Total-NPV, Total-Var-Varmeproduktions-Omk,
             REFA-NPV, REFA-Var-Varmeproduktions-Omk,
             REFA-Daekningsbidrag, REFA-Total-Var-Indkomst, REFA-Affald-Modtagelse, REFA-RGK-Rabat, REFA-Elsalg, REFA-Varmesalg,
             REFA-Total-Var-Omkostning, REFA-AnlaegsVarOmk, REFA-BraendselOmk, REFA-Afgifter, REFA-CO2-Kvoteomk, REFA-Lageromkostning,
             REFA-CO2-Emission-Afgift, REFA-CO2-Emission-Kvote, REFA-El-produktion-Brutto, REFA-El-produktion-Netto,
             REFA-Total-Affald-Raadighed, REFA-Affald-anvendt, REFA-Affald-Uudnyttet, REFA-Affald-Lagret,
             REFA-Total-Varme-Produktion, REFA-Leveret-Varme, REFA-Modtryk-Varme, REFA-Bypass-Varme, REFA-RGK-Varme, REFA-RGK-Andel, REFA-Bortkoelet-Varme,
             GSF-Total-Var-Omkostning,  GSF-AnlaegsVarOmk,  GSF-BraendselOmk,  GSF-Afgifter,  GSF-CO2-Emission,  GSF-Total-Varme-Produktion,
             NS-Total-Varme-Produktion,
             Virtuel-Varme-Kilde, Virtuel-Varme-Draen, Virtuel-Affaldstonnage-Kilde, Virtuel-Affaldstonnage-Draen
             /;

set topicSummable(topic) 'Emner som skal summeres i Scen_Overview';
topicSummable(topic)         = yes;
topicSummable('Tidsstempel') = no;
topicSummable('Total-NPV')   = no;
topicSummable('REFA-NPV')    = no;


Scalar    nScen           'Antal beregnede aktive scenarier';
Scalar    NPV_REFA_V      'REFAs nutidsværdi';
Scalar    NPV_Total_V     'Total nutidsværdi (REFA + GSF)';
Scalar    Penalty_QInfeasTotal, Penalty_AffTInfeasTotal;                          # Penalty bidrag fra infeasibiliteter.
Scalar    Penalty_bOnUTotal, Penalty_QRgkMissTotal, Penalty_AffaldsGensalgTotal;  # Penalty bidrag på objektfunktionen.
Scalar    PerStart;
Scalar    PerSlut;
Scalar    TimeOfWritingMasterResults   'Tidsstempel for udskrivning af resultater for aktuelt scenarie';
Scalar    Gain_QaffTotal               'Samlede virtuelle gevinst for affaldsvarme';                        # Gain bidrag på objektfunktionen.
#--- Parameter Scen_TimeStamp(scen)         'Tidsstempel for scenarier';

# Kopi af data, som kan ændres af scenarieparametre
Parameter DataPrognSaved(moall,labDataProgn)   'Kopi af referencedata for prognoser';
Parameter DataCtrlSaved(labDataCtrl);
Parameter ScheduleSaved(labSchRow,labSchCol);
Parameter DataUSaved(u,labDataU);
Parameter DataStoSaved(s,labDataSto);
Parameter DataPrognSaved(moall,labDataProgn);
Parameter DataFuelSaved(f,labDataFuel);
Parameter FuelBoundsSaved(f,fuelItem,moall);

Parameter Scen_Overview(topic,scen)    'Nøgletal (sum) for scenarier';
Parameter Scen_Q(u,scen)               'Varmemængder (sum) for scenarier';
Parameter Scen_FuelDeliv(f,scen)       'Brændselsmængder (sum) for scenarier';
Parameter Scen_IncomeFuel(f,scen)      'Brændselsindtægt (sum) for scenarier';

Parameter DataCtrl_V(labDataCtrl);
Parameter DataU_V(u,labDataU);
Parameter DataSto_V(s,labDataSto);
Parameter DataFuel_V(f,labDataFuel);
Parameter DataProgn_V(labDataProgn,moall)      'Prognoser transponeret';
Parameter FuelBounds_V(f,fuelItem,moall);
Parameter FuelDeliv_V(f,moall)             'Leveret brændsel';
Parameter FuelConsT_V(u,f,moall)           'Afbrændt brændsel for givet anlæg';
Parameter FuelConsP_V(u,f,moall)           'Effekt af afbrændt brændsel for givet anlæg';
Parameter StoDLoadF_V(s,f,moall)           'Lagerændring for givet lager og brændsel';
Parameter StoLoadF_V(s,f,moall)            'Lagerbeholdning for givet lager og brændsel';
Parameter StoLoadAll_V(s,moall)            'Lagerbeholdning ialt for givet lager';
Parameter IncomeFuel_V(f,moall);
Parameter Q_V(u,moall);

Parameter Overview(topic,moall);
Parameter RefaDaekningsbidrag_V(moall)     'Daekningsbidrag for REFA [DKK]';
Parameter RefaTotalVarIndkomst_V(moall)    'REFA Total variabel indkomst [DKK]';
Parameter RefaAffaldModtagelse_V(moall)    'REFA Affald modtageindkomst [DKK]';
Parameter RefaRgkRabat_V(moall)            'REFA RGK-rabat for affald [DKK]';
Parameter RefaElsalg_V(moall)              'REFA Indkomst elsalg [DKK]';
Parameter RefaVarmeSalg_V(moall)           'REFA Indkomst varmesalg [DKK]';

Parameter RefaTotalVarOmk_V(moall)         'REFA Total variabel indkomst [DKK]';
Parameter RefaAnlaegsVarOmk_V(moall)       'REFA Var anlaegs omk [DKK]';
Parameter RefaBraendselsVarOmk_V(moall)    'REFA Var braendsels omk. [DKK]';
Parameter RefaAfgifter_V(moall)            'REFA afgifter [DKK]';
Parameter RefaKvoteOmk_V(moall)            'REFA CO2 kvote-omk. [DKK]';
Parameter RefaStoCost_V(moall)             'REFA Lageromkostning [DKK]';
Parameter RefaCO2emission_V(moall,typeCO2) 'REFA CO2 emission [ton]';
Parameter RefaElproduktionBrutto_V(moall)  'REFA brutto elproduktion [MWhe]';
Parameter RefaElproduktionNetto_V(moall)   'REFA netto elproduktion [MWhe]';

Parameter RefaVarmeProd_V(moall)           'REFA Total varmeproduktion [MWhq]';
Parameter RefaVarmeLeveret_V(moall)        'REFA Leveret varme [MWhq]';
Parameter RefaModtrykProd_V(moall)         'REFA Total modtryksvarmeproduktion [MWhq]';
Parameter RefaBypassVarme_V(moall)         'REFA Bypass-varme på Ovn3 [MWhq]';
Parameter RefaRgkProd_V(moall)             'REFA RGK-varmeproduktion [MWhq]';
Parameter RefaRgkShare_V(moall)            'RGK-varmens andel af REFA energiproduktion';
Parameter RefaBortkoeletVarme_V(moall)     'REFA bortkoelet varme [MWhq]';
Parameter VarmeVarProdOmkTotal_V(moall)    'Variabel varmepris på tvaers af alle produktionsanlæg DKK/MWhq';
Parameter VarmeVarProdOmkRefa_V(moall)     'Variabel varmepris på tvaers af REFA-produktionsanlæg DKK/MWhq';
Parameter RefaLagerBeholdning_V(s,moall)   'Lagerbeholdning [ton]';

Parameter VPO_V(uaggr,moall)               'VPO_V DKK/MWhq';

Parameter Usage_V(u,moall)                 'Kapacitetsudnyttelse af anlæg';
Parameter LhvCons_V(u,moall)               'Realiseret brændværdi';
Parameter FuelConsumed_V(u,moall)          'Tonnage afbrændt timebasis';
Parameter AffaldConsTotal_V(moall)         'Tonnage totalt afbrændt';
Parameter AffaldAvail_V(moall)             'Rådig affaldsmængde [ton]';
Parameter AffaldUudnyttet_V(moall)         'Ikke-udnyttet affald [ton]';
Parameter AffaldLagret_V(moall)            'Lagerstand [ton]';

Parameter GsfTotalVarOmk_V(moall)          'Guldborgsund Forsyning Total indkomst [DKK]';
Parameter GsfAnlaegsVarOmk_V(moall)        'Guldborgsund Forsyning Var anlaegs omk [DKK]';
Parameter GsfBraendselsVarOmk_V(moall)     'Guldborgsund Forsyning Var braendsels omk. [DKK]';
Parameter GsfAfgifter_V(moall)             'Guldborgsund Forsyning Afgifter [DKK]';
Parameter GsfCO2emission_V(moall)          'Guldborgsund Forsyning CO2 emission [ton]';
Parameter GsfTotalVarmeProd_V(moall)       'Guldborgsund Forsyning Total Varmeproduktion [MWhq]';

Parameter NsTotalVarmeProd_V(moall)        'Nordic Sugar Total varmeproduktion [MWhq]';

# Begin Erklæring af iterations Loop på Phi-faktorer.

$OnText
 Opsætning af parametre til iterativ afgiftsberegning.
 Afgifter knyttet til affaldsanlæg er ulineære i produktionsvariable og
 det er omstændeligt at lave bivariate approksimationer af de kvadratiske led.
 Ulineariteten opstår, fordi den afgiftspligtige varme Qafg = Qtotal * (F - Fbiogen) / F,
 hvor Fbiogen er den afgiftsfrie brændselseffekt MWf og F er den fulde brændselseffekt.
 Ligningen omskrives til Qafg = Qtotal * (1 - phi), hvor phi = Fbiogen / Fenergi.
 Generelt skal også fossile brændsler som olie og gas lægges ind under Fbiogen,
 men de har så deres egne afgifter i modsætning til biogene brændsler.
 Bemærk, at Fenergi beregnes forskelligt afh. af RGK-produktion eller ej:
   Fenergi = (Qtotal + P) / 0.85   uden RGK-produktion.
   Fenergi = (Qtotal + P) / 0.95   med  RGK-produktion.

 Da regnetiden for modellen er på få sekunder, anvendes i stedet for en iterativ metode.
 I første iteration sættes phi := 0 og afgifterne beregnes nu ved lineære ligninger.
 Efter solve beregnes den værdi, som phi har på basis af de forbrugte affaldsmængder.
 Dernæst gentages optimeringen og phi genberegnes, indtil et stopkriterium er opfyldt.
 Stopkriteriet er den første af:
   1:  Max. antal iterationer
   2:  Afvigelsen: Delta = (Metric[i] - Metric[i-1]) / (Metric[i] + Metric[i-1])

 Iterationshistorien opsamles i en parameter indekseret med set iter.
$OffText

Scalar    NiterMax / 10 /;
Scalar    IterNo                       'Iterationsnummer';
Scalar    ConvergenceFound             'Angiver 0/1 at iterationen er konvergeret';
Scalar    DeltaConvMetricTol           'Tolerance på relativ konvergensmetrik-afvigelse ift. forrige iteration' / 0.001 /;
Scalar    DeltaAfgift                  'Afgiftsafvigelse ift. forrige iteration';
Scalar    DeltaConvMetric              'Relativ konvergensmetrikafvigelse ift. forrige iteration';
Scalar    PhiScale                     'Nedskaleringsfaktor på phi' / 0.70 /;

# Erklæring af parametre til iterativ løsning af ulineær afgiftsberegning.
Parameter eE(phiKind)                  'Energivirkningsgrad'   / '85' 0.85,  '95' 0.95 /;
Parameter Fenergi(phiKind,moall)       'Aktuel værdi af Fenergi = (Qtotal + P)/e';
Parameter QafgAfv(moall)               'Efterberegning af affaldvarmeafgiftspligtig varme';
Parameter QafgAtl(moall)               'Efterberegning af affaldtillægsafgiftspligtig varme';
Parameter QafgCO2(moall)               'Efterberegning af CO2-afgiftspligtig varme';
Parameter AfgAfv(moall)                'Afgiftssum AFV';
Parameter AfgAtl(moall)                'Afgiftssum ATL';
Parameter AfgCO2(moall)                'Afgiftssum CO2';
Parameter AfgiftTotal(moall)           'Afgiftssum';
Parameter QcoolTotal(moall)            'Total bortkølet varme';
Parameter Qtotal(moall)                'Total varmeproduktion affaldsanlæg';
Parameter EnergiTotal(moall)           'Total energiproduktion affaldsanlæg';
Parameter FEBiogenTotal(moall)         'Total biogen indfyret effekt affaldsanlæg';
Parameter PhiIter(phiKind,moall,iter)  'Iterationshistorie for phi';
Parameter AfgiftTotalIter(moall,iter)  'Afgiftssum';
Parameter DeltaAfgiftIter(iter)        'Iterationshistorie på afgiftsafvigelse';
Parameter ConvMetric(moall)            'Konvergensmetrikbasis for afgiftsiteration';
Parameter ConvMetricIter(moall,iter)   'Konvergensmetrikbasis-historik for afgiftsiteration';
Parameter DeltaConvMetricIter(iter)    'Konvergensmetrik-historik for afgiftsiteration';

Parameter dPhi(phiKind)                      'Phi-ændring ift. forrige iteration';
Parameter dPhiChange(phiKind)                'Ændring af Phi-ændring ift. forrige iteration';
Parameter dPhiIter(phiKind,moall,iter)       'Phi-ændring ift. forrige iteration';
Parameter dPhiChangeIter(phiKind,moall,iter) 'Ændring af Phi-ændring ift. forrige iteration';

# End Erklæring af iterations Loop på Phi-faktorer.


#begin Rimelighedskontrol af potentielt modificerede inputtabeller.

Loop (labDataU $(NOT sameas(labDataU,'KapMin') AND NOT sameas(labDataU,'MinLast')),
  tmp1 = sum(u, DataU(u,labDataU));
  tmp2 = ord(labDataU);
  if (tmp1 EQ 0,
    display tmp2;
    abort "ERROR: Mindst én kolonne (se tmp2) i DataU summer til nul.";
  );
);

Loop (labDataSto $(NOT sameas(labDataSto,'Aktiv') AND NOT sameas(labDataSto,'LoadInit') AND NOT sameas(labDataSto,'LoadMin') AND NOT sameas(labDataSto,'LossRate')),
  tmp1 = sum(s, DataSto(s,labDataSto));
  tmp2 = ord(labDataSto);
  if (tmp1 EQ 0,
    display tmp2;
    abort "ERROR: Mindst én kolonne (se tmp2) i DataSto summer til nul.";
  );
);

$OffOrder
Loop (labDataProgn,
  labPrognSingle(labDataProgn) = yes;
  tmp1 = sum(moall, DataProgn(moall,labDataProgn));
  if (tmp1 EQ 0,
    display labPrognSingle;
    abort "ERROR: Mindst én kolonne (se labPrognSingle) i DataProgn summer til nul.";
  );
);
$OnOrder

Loop (labDataFuel,
  tmp1 = sum(f, DataFuel(f,labDataFuel));
  tmp2 = ord(labDataFuel);
  if (tmp1 EQ 0,
    display tmp2;
    abort "ERROR: Mindst én kolonne (se tmp2) i DataFuel summer til nul.";
  );
);

$OffOrder
Loop (fuelItem $(sameas(fuelItem,'MaxTonnage')),
  tmp3 = ord(fuelItem);
  Loop (fa $DataFuel(fa,'Aktiv'),
    tmp1 = sum(moall, FuelBounds(fa,fuelItem,moall));
    tmp2 = ord(fa);
    if (tmp1 EQ 0,
      display tmp3, tmp2;
      abort "ERROR: Mindst én række (se fuelItem=tmp3, fa=tmp2) i FuelBounds summer til nul.";
    );
  );
);
$OnOrder

#end Rimelighedskontrol af potentielt modificerede inputtabeller.

# ===================================================  BEGIN SCENARIE BLOCK =============================================================

#begin Initialisering af scenarie Loop.

# Tag backup af parametre i DataProgn, som er aktive i Scen_Progn.
DataPrognSaved(moall,labPrognScen) = DataProgn(moall,labPrognScen);
DataCtrlSaved(labDataCtrl)         = DataCtrl(labDataCtrl);
ScheduleSaved(labSchRow,labSchCol) = Schedule(labSchRow,labSchCol);
DataUSaved(u,labDataU)             = DataU(u,labDataU);
DataStoSaved(s,labDataSto)         = DataSto(s,labDataSto);
DataPrognSaved(moall,labDataProgn) = DataProgn(moall,labDataProgn);
DataFuelSaved(f,labDataFuel)       = DataFuel(f,labDataFuel);
FuelBoundsSaved(f,fuelItem,moall)  = FuelBounds(f,fuelItem,moall);

#TODO: Fjern Scen_Progn, som erstattes af ScenRecs.
nScen = 0;
#--- Scen_Progn('scen0','Aktiv') = 1;                    # Reference-scenariet beregnes altid.
#--- Scen_Progn_Transpose(labPrognScen,'scen0') = tiny;  # Sikrer at scen0 også bliver overført, da nul-værdier ikke overføres.

Parameter NScenSpec(scen);
NScenSpec(scen) = 0;
Loop (scRec,
  if (ScenRecs(scRec,'Aktiv') GT 0,
    ScenId = ScenRecs(scRec,'ScenId');
	Loop (scen $(ord(scen) EQ ScenId + 1),
      NScenRec(scen) = NScenRec(scen) + 1;
    );  
  );  
);
display NScenRec;


#end   Initialisering af scenarie Loop.

# ===================================================  BEGIN SCENARIE LOOP  =============================================================

Loop (scen $(NScenRec(scen) GT 0), 
actScen(scen) = yes;
nScen = nScen + 1;
# Check om der er defineret aktive records for det aktuelle scenarie.
display actScen, nScen;

# Overførsel af aktuelle scenaries parametre.
# scen0 er reference-scenarie og skal derfor ikke have modificeret parametre.
# Aktuelt kan kun prognose-parametre specificeres, men øvrige datatyper kan tilføjes.
# Dermed kan principielt alle parametre gøres til scenarieparametre.
# Al initialisering af afledte sets og parametre følger efter overførsel af parameterværdier for aktuelt scenarie.

# Indlæs kode til tilbagestilling af anlægsdata mv. til udgangspunktet.
$Include RefaDataReset.gms

# Indlæs kode til parsing af scenarie-records.
$Include RefaScenParsing.gms

# Indlæs kode til opsætning af afledte parametre, hvis kilde kan være ændret af scenarie-specifikationen.
$Include RefaDataSetup.gms

# Indlæs kode til initialisering af variable.
$Include RefaInitVars.gms

# Indlæs kode til optimering af modellen, herunder ulineær iteration på afgiftsberegning.
$Include RefaSolveModel.gms

# Indlæs kode til udskrivning af resultater for aktuelt scenarie.
$Include RefaWriteOutput.gms


if (NOT RunScenarios, display "Scenarier udover referencen skal ikke beregnes";);
break $(NOT RunScenarios);

); # End-of-scenario Loop
# ===================================================  END SCENARIE LOOP  =============================================================

# Indlæs kode til udskrivning af sammenfatning for alle scenarier.
$Include RefaWriteScenarios.gms

