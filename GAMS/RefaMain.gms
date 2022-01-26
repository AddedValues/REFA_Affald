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

# ENCODING SKAL V�RE ANSI FOR AT DANSKE BOGSTAVER 'OVERLEVER' I KOMMENTARER.
# Danske bogstaver kan IKKE bruges i model-elementer, s�som set-elementer, parameternavne, m.v.
#--- set dummy / s�, s�, s�, s�, s�, s� /;

# Globale erkl�ringer og shorthands. 
option dispwidth = 80; 

# Shorthand for boolean constants.
Scalar FALSE 'Shorthand for false = 0 (zero)' / 0 /;
Scalar TRUE  'Shorthand for true  = 1 (one)'  / 1 /;

# Arbejdsvariable
Scalar VirtualUsed     'Angiver at virtuelle ressourcer er brugt (bl�de infeasibiliteter)';
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

set bound     'Bounds'          / Min, Max, Lhv, ModtPris, CO2tonton /;
set dir       'Flowretning'     / drain, source /;

set phiKind   'Type phi-faktor' / 85, 95 /;
set iter      'iterationer'     / iter0 * iter30 /; 

set scen      'Scenarier'       / scen0, scen1 * scen30 /;  # scen0 er referencescenariet.

#--- set mo   'Aarsmaaneder'   / jan, feb, mar, apr, maj, jun, jul, aug, sep, okt, nov, dec /;
#--- set mo   'Aarsmaaneder'   / jan /;
set moall     'Aarsmaaneder'   / mo0 * mo36 /;  # Daekker op til 3 aar. Elementet 'mo0' anvendes kun for at sikre tom kolonne i udskrivning til Excel.
set mo(moall) 'Aktive maaneder';
alias(mo,moa);

set labDataCtrl       'Styringparms'       / RunScenarios, IncludeGSF, VirtuelVarme, VirtuelAffald, SkorstensMetode, FixAffald, RgkRabatSats, RgkAndelRabat, Varmesalgspris, EgetforbrugKVV /;
set labScheduleCol    'Periodeomfang'      / FirstYear, LastYear, FirstPeriod, LastPeriod /;
set labScheduleRow    'Periodeomfang'      / aar, maaned, dato /;
set labDataU          'DataU labels'       / Aktiv, Ukind, Prioritet, MinLhv, MaxLhv, MinTon, MaxTon, kapQNom, kapRgk, kapE, MinLast, KapMin, EtaE, EtaQ, DVMWhq, DVtime /;
set labProgn          'Prognose labels'    / Aktiv, Ndage, Ovn2, Ovn3, FlisK, NS, Cooler, PeakK, Turbine, Varmebehov, NSprod, ELprod, Bypass, Elpris,
                                             ETS, AFV, ATL, CO2aff, ETSaff, CO2afgAff, NOxAff, NOxFlis, EnrPeak, CO2peak, NOxPeak /;
set labDataFuel       'DataFuel labels'    / Aktiv, Fkind, Lagerbar, Fri, Flex, Bortskaf, TilOvn2, TilOvn3, MinTonnage, MaxTonnage, InitSto1, InitSto2, Pris, Brandv, NOxKgTon, CO2kgGJ /;
set labDataSto        'DataSto labels'     / Aktiv, StoKind, LoadInit, LoadMin, LoadMax, DLoadMax, LossRate, LoadCost, DLoadCost, ResetFirst, ResetIntv, ResetLast /;  # stoKind=1 er affalds-, stoKind=2 er varmelager.
set taxkind(labProgn) 'Omkostningstyper'   / ETS, AFV, ATL, CO2aff, ETSaff, CO2afgAff, NOxAff, NOxFlis, EnrPeak, CO2peak, NOxPeak /;
set typeCO2           'CO2-Opg�relsestype' / afgift, kvote, total /;

set labPrognScen(labProgn) 'Aktive prognose scenarie-parms';

set owner     'Anlaegsejere'   / refa, gsf /;

set fkind 'Drivm.-typer'  / 1 'affald', 2 'biomasse', 3 'varme', 4 'peakfuel' /;

Set f     'Drivmidler'    / DepoSort, DepoSmaat, DepoNedd, Dagren, AndetBrand, Trae,
                            DagrenRast, DagrenInst, DagrenHandel, DagrenRestau, Erhverv, DagrenErhverv,
                            HandelKontor, Privat, TyskRest, PolskRest, PcbTrae, TraeRekv, Halm, Pulver, FlisAffald,
                            NyAff1, NyAff2, NyAff3, NyAff4, NyAff5,
                            Flis, NSvarme, PeakFuel /;
#--- Set f     'Drivmidler'    / Dagren,
#---                             Flis, NSvarme /;
#--- Set f             'Drivmidler' / f1 * f29 /;
set fa(f)           'Affaldstyper';
set fb(f)           'Biobraendsler';
set fc(f)           'Overskudsvarme';
set fr(f)           'PeakK braendsel';
set fsto(f)         'Lagerbare braendsler';
set fdis(f)         'Braendsler som skal bortskaffes';
set ffri(f)         'Braendsler med fri tonnage';
set fflex(f)        'Braendsler med fleksibel m�nedstonnage';
set faux(f)         'Andre braendsler end affald';
set f2own(f,owner)  'Tilknytning af fuel til ejer';
set frefa(f)        'REFA braendsler';
set fgsf(f)         'GSF braendsler';
set fpospris(f)     'Braendsler med positiv pris (modtagepris)';
set fnegpris(f)     'Braendsler med negativ pris (k�bspris))';
set fbiogen(f)      'Biogene br�ndsler (uden afgifter)';

set uaggr     'Sammenfattende anl�g'  / Affald, Fliskedel, SR-kedel /;

set ukind     'Anlaegstyper'   / 1 'affald', 2 'biomasse', 3 'varme', 4 'Cooler', 5 'PeakK' /;
set u         'Anlaeg'         / Ovn2, Ovn3, FlisK, NS, Cooler, PeakK /;
set up(u)     'Prod-anlaeg'    / Ovn2, Ovn3, FlisK, NS, PeakK /;
set ua(u)     'Affaldsanlaeg'  / Ovn2, Ovn3 /;
set ub(u)     'Bioanlaeg'      / FlisK /;
set uc(u)     'OV-leverance'   / NS /;
set ur(u)     'SR-kedler'      / PeakK /;
set uv(u)     'Koelere'        / Cooler /;
set uaux(u)   'Andre anlaeg end affald'      / FlisK, NS, Cooler, PeakK /;
set upaux(u)  'Andre prod-anl�g end affald'  / FlisK, NS, PeakK /;
set urefa(u)  'REFA anlaeg'            / Ovn2, Ovn3, FlisK, Cooler /;
set uprefa(u) 'REFA produktionsanlaeg' / Ovn2, Ovn3, FlisK /;
set ugsf(u)   'Guldborgsund anlaeg'    / PeakK /;

set uprio(up)       'Prioriterede anlaeg';
set uprio2up(up,up) 'Anlaegsprioriteter';   # R�kkef�lge af prioriteter oprettes p� basis af DataU(up,'prioritet')

set s     'Lagre' / sto1 * sto2 /;          # I f�rste omgang tilt�nkt affaldslagre.
set sa(s) 'Affaldslagre';
set sq(s) 'Varmelagre';

set u2f(u,f)  'Gyldige kombinationer af anl�g og drivmidler';
set s2f(s,f)  'Gyldige kombinationer af lagre og drivmidler';

Singleton set ufparm(u,f);
Singleton set sfparm(s,f);
Singleton set labPrognSingle(labProgn);
Singleton set actScen(scen)    'Aktuelt scenarie';
actScen(scen) = no;

alias(upa, up);

# ------------------------------------------------------------------------------------------------
# Erklaering af parametre
# ------------------------------------------------------------------------------------------------
# Penalty faktorer til objektfunktionen.
Scalar    Penalty_bOnU              'Penalty p� bOnU'           / 0000E+5 /;
Scalar    Penalty_QRgkMiss          'Penalty p� QRgkMiss'       /   10    /;      # Denne penalty m� ikke v�re h�jere end tillaegsafgiften.
Scalar    Penalty_QInfeas           'Penalty p� QInfeas'        / 5000    /;      # P�l�gges virtuel varmekilder og -dr�n.
Scalar    Penalty_AffTInfeas        'Penalty p� AffTInfeas'     / 5000    /;      # P�l�gges virtuel affaldstonnage kilde og -dr�n.
Scalar    Penalty_AffaldsGensalg    'Affald gensalgspris'       / 1500.00  /;      # P�l�gges ikke-udnyttet affald.
Scalar    OnQInfeas                 'On/Off p� virtuel varme'   / 0       /;
Scalar    OnAffTInfeas              'On/Off p� virtuel affald'  / 0       /;
Scalar    LhvMWhAffTInfeas          'LHV af virtuel affald'     / 3.0    /;                        # 3.0 MWhf/ton svarende til 10.80 GJ/ton.
Parameter Gain_Qaff(u)              'Gevinst for affaldsvarme'  / 'Ovn2' 10.00, 'Ovn3' 10.00  /;   # Till�gges varmeproduktion p� Ovn3 for at sikre udlastning f�r NS-varmen og flisvarme.

# Indl�ses via DataCtrl.
Scalar    RgkRabatSats              'Rabatsats p� ATL'          / 0.10    /;
Scalar    RgkRabatMinShare          'Taerskel for RGK rabat'    / 0.07    /;
Scalar    VarmeSalgspris            'Varmesalgspris DKK/MWhq'   / 200.00  /;
Scalar    AffaldsOmkAndel           'Affaldssiden omk.andel'    / 0.45    /;
Scalar    SkorstensMetode           '0/1 for skorstensmetode'   / 0       /;
Scalar    EgetforbrugKVV            'Angiver egetforbrug MWhe/d�gn';  
Scalar    RunScenarios              'Angiver 0/1 om scenarier skal k�res';
Scalar    FixAffald                 'Angiver 0/1 om affaldsfraktioner skal fikseres p� m�nedsniveau';
Scalar    NactiveM                  'Antal aktive m�neder';

Scalar    dbup, dbupa;
Scalar    db, qdeliv;

Parameter IncludeOwner(owner)       '<>0 => Ejer med i OBJ'     / refa 1, gsf 0 /;
Parameter IncludePlant(u);
Parameter IncludeFuel(f);

Parameter Scen_Progn(scen,labProgn)       'Scenarier p� prognoser';
Parameter Scen_Progn_Transpose(labProgn,scen)       'Transponering af Scen_Progn';
Parameter Schedule(labScheduleRow, labScheduleCol)  'Periode start/stop';
Parameter DataCtrl(labDataCtrl)          'Data for styringsparametre';
Parameter DataU(u, labDataU)             'Data for anlaeg';
Parameter DataSto(s, labDataSto)         'Lagerspecifikationer';
Parameter Prognoses(moall,labProgn)      'Data for prognoser';
Parameter DataFuel(f, labDataFuel)       'Data for drivmidler';
Parameter FuelBounds(f,bound,moall)      'Maengdegraenser for drivmidler';
Parameter FixValueAffT(moall)            'Fikserede m�nedstonnager p� affald';
Parameter DoFixAffT(moall)               'Angiver True/False at m�nedstonnagen p� affald skal fikseres';

Parameter OnU(u)                         'Angiver om anlaeg er til raadighed';
Parameter OnF(f)                         'Angiver om drivmiddel er til raadighed';
Parameter OnS(s)                         'Angiver om lager er til raadighed';
Parameter OnM(moall)                     'Angiver om en given maaned er aktiv';
Parameter OnBypass(moall)                'Angiver 0/1 om turbine-bypass er tilladt';
Parameter Hours(moall)                   'Antal timer i maaned';
Parameter AvailDaysU(moall,u)            'Antal raadige dage';
Parameter ShareAvailU(u,moall)           'Andel af fuld r�dighed p� m�nedsbasis';
Parameter AvailDaysTurb(moall)           'Antal raadige dage for dampturbinen';
Parameter ShareAvailTurb(moall)          'Andel af fuld r�dighed af dampturbinen m�nedsbasis';
Parameter Peget(moall)                   'Elektrisk egetforbrug KKV-anl�gget';
#--- Parameter ShareBypass(moall)             'Andel af bypass-drift p� m�nedsbasis';
#--- Parameter HoursBypass(moall)             'Antal timer med turbine-bypass';
                                         
Parameter MinLhvMWh(u)                   'Mindste braendvaerdi affaldsanlaeg GJ/ton';
Parameter MaxLhvMWh(u)                   'St�rste braendvaerdi affaldsanlaeg GJ/ton';
Parameter MinTon(u)                      'Mindste indfyringskapacitet ton/h';
Parameter MaxTon(u)                      'Stoerste indfyringskapacitet ton/h';
Parameter KapMin(u)                      'Mindste modtrykslast MWq';
Parameter KapNom(u)                      'Stoerste modtrykskapacitet MWq';
Parameter KapMax(u)                      'Stoerste samlede varmekapacitet MWq';
Parameter KapRgk(u)                      'RGK kapacitet MWq';
Parameter KapE(u,moall)                  'El bruttokapacitet MWe';
Parameter EtaQ(u)                        'Varmevirkningsgrad';
Parameter EtaRgk(u)                      'Varmevirkningsgrad';
Parameter EtaE(u,moall)                  'Elvirkningsgrad (er m�nedsafh�ngig i 2021)';
Parameter DvMWhq(u)                      'DV-omkostning pr. MWhf';
Parameter DvTime(u)                      'DV-omkostning pr. driftstimer'; 
Parameter StoLoadInitF(s,f)              'Initial lagerbeholdning for hvert br�ndsel';
Parameter StoLoadInitQ(s)                'Initial lagerbeholdning for varmelagre';
Parameter StoLoadMin(s,moall)            'Min. lagerbeholdning';
Parameter StoLoadMax(s,moall)            'Max. lagerbeholdning';
Parameter StoDLoadMax(s,moall)           'Max. lager�ndring i periode';
Parameter StoLoadCostRate(s,moall)       'Omkostning for opbevaring';
Parameter StoDLoadCostRate(s,moall)      'Omkostning for lager�ndring';
Parameter StoLossRate(s,moall)           'Max. lagertab ift. forrige periodes beholdning';
Parameter StoFirstReset(s)               'Antal initielle perioder som omslutter f�rste nulstiling af lagerstand';
Parameter StoIntvReset(s)                'Antal perioder som omslutter f�rste nulstiling af lagerstand, efter f�rste nulstilling';

Parameter MinTonnageYear(f)              'Braendselstonnage min aarsniveau [ton/aar]';
Parameter MaxTonnageYear(f)              'Braendselstonnage max aarsniveau [ton/aar]';
Parameter LhvMWh(f)                      'Braendvaerdi [MWf]';
Parameter CO2potenTon(f,typeCO2,moall)   'CO2-emission [tonCO2/tonBr�ndsel]';
Parameter Qdemand(moall)                 'FJV-behov';
#--- Parameter IncomeElec(moall)              'El-indkomst [DKK]';
#--- Parameter PowerProd(moall)               'Elproduktion MWhe';
Parameter PowerPrice(moall)              'El-pris DKK/MWhe';
Parameter TariffElProd(moall)            'Tarif p� elproduktion [DKK/MWhe]';
Parameter TaxAfvMWh(moall)               'Affaldsvarmeafgift [DKK/MWhq]';
Parameter TaxAtlMWh(moall)               'Affaldstillaegsafgift [DKK/MWhf]';
Parameter TaxEtsTon(moall)               'CO2 Kvotepris [DKK/tom]';
Parameter TaxCO2TonF(f,moall)            'CO2-afgift p� br�ndselsniveau [DKK/tonCO2]';
Parameter CO2ContentAff(moall)           'CO2 indhold affald [kgCO2 / tonAffald]';
Parameter TaxCO2AffTon(moall)            'CO2 afgift affald [DKK/tonCO2]';
Parameter TaxNOxAffkg(moall)             'NOx afgift affald [DKK/kgNOx]';
Parameter TaxNOxFlisTon(moall)           'NOx afgift flis [DKK/tom]';
Parameter TaxEnrPeakTon(moall)           'Energiafgift SR-kedler [DKK/tom]';
Parameter TaxCO2peakTon(moall)           'CO2 afgift SR-kedler [DKK/tom]';
Parameter TaxNOxPeakTon(moall)           'NOx afgift SR-kedler [DKK/tom]';

Parameter EaffGross(moall)               'Max energiproduktion for affaldsanlaeg MWh';
Parameter QaffMmax(ua,moall)             'Max. modtryksvarme fra affaldsanl�g';
Parameter QrgkMax(ua,moall)              'Max. RGK-varme fra affaldsanl�g';
Parameter QaffTotalMax(moall)            'Max. total varme fra affaldsanl�g';
Parameter TaxATLMax(moall)               'Oevre graense for ATL';
Parameter RgkRabatMax(moall)             'Oevre graense for ATL rabat';
Parameter QRgkMissMax                    'Oevre graense for QRgkMiss';

$If not errorfree $exit

# Indlaesning af input parametre

$onecho > REFAinput.txt
set=labPrognScen        rng=Scen!C7:J7                      cDim=1
par=Scen_Progn           rng=Scen!A7:J37              rdim=1 cdim=1
par=DataCtrl            rng=DataCtrl!B4:C20          rdim=1 cdim=0
par=Schedule            rng=DataU!A3:E6              rdim=1 cdim=1
par=DataU               rng=DataU!A11:O17            rdim=1 cdim=1
par=DataSto             rng=DataU!Q11:AC17           rdim=1 cdim=1
par=Prognoses           rng=DataU!D22:AC58           rdim=1 cdim=1
par=DataFuel            rng=DataFuel!C4:T33          rdim=1 cdim=1
par=FuelBounds          rng=DataFuel!B39:AM178       rdim=2 cdim=1
par=FixValueAffT       rng=DataFuel!D182:AM183       rdim=0 cdim=1
$offecho

$call "ERASE  REFAinputM.gdx"
$call "GDXXRW REFAinputM.xlsm RWait=1 Trace=3 @REFAinput.txt"

# Indlaesning fra GDX-fil genereret af GDXXRW.
# $LoadDC bruges for at sikre, at der ikke findes elementer, som ikke er gyldige for den aktuelle parameter.
# $Load udfoerer samme operation som $LoadDC, men ignorerer ugyldige elementer.
# $Load anvendes her for at tillade at indsaette linjer med beskrivende tekst.

$GDXIN REFAinputM.gdx

$LOAD   labPrognScen
$LOAD   Scen_Progn
$LOAD   DataCtrl
$LOAD   Schedule
$LOAD   DataU
$LOAD   DataSto
$LOAD   Prognoses
$LOAD   DataFuel
$LOAD   FuelBounds
$LOAD   FixValueAffT

$GDXIN   # Close GDX file.
$log  LOG: Finished loading input data from GDXIN.

#--- display labPrognScen, Scen_Progn, DataCtrl, DataU, Schedule, Prognoses, DataFuel, FuelBounds, DataSto;
#--- abort "BEVIDST STOP";

#begin Ops�tning af subsets, som IKKE afledes af inputdata.

# Braendselstyper.
fa(f) = DataFuel(f,'fkind') EQ 1;
fb(f) = DataFuel(f,'fkind') EQ 2;
fc(f) = DataFuel(f,'fkind') EQ 3;
fr(f) = DataFuel(f,'fkind') EQ 4;

# Kompabilitet mellem anl�g og br�ndsler.
u2f(u,f)   = no;
u2f(ub,fb) = yes;
u2f(uc,fc) = yes;
u2f(ur,fr) = yes;

# Brugergivne restriktioner p� kombinationer af affaldsanl�g og br�ndselsfraktioner.
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
#end Ops�tning af subsets, som IKKE afledes af inputdata.


# Overf�rsel af parametre p� overordnet modelniveau.
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

# Verific�r scenarier.
Scalar nScenActive 'Antal aktive definerede scenarier';
if (RunScenarios,
  nScenActive = sum(scen, 1 $Scen_Progn(scen,'Aktiv'));
  if (nScenActive EQ 0,
    display nScenActive, Scen_Progn;
    abort "RunScenarios er TRUE (NE 0), men ingen scenarier i Scen_Progn er aktive.";
  );
);

$If not errorfree $exit


# Initialisering af arbejdsvariable som anvendes i Equations.
Parameter Phi(phiKind,moall)      'Aktuel v�rdi af Phi = Fbiogen/F';
Parameter QtotalAffMax(moall)     'Max. aff-varme';
Parameter StoCostLoadMax(s)       'Max. lageromkostning';

mo(moall) = yes;
OnU(u)    = yes;
OnS(s)    = yes;
OnF(f)    = yes;
s2f(s,f)  = no;
EtaQ(u)   = NaN;
EtaRgk(u) = NaN;
LhvMWh(f) = NaN;

# ------------------------------------------------------------------------------------------------
# Erklaering af variable.
# ------------------------------------------------------------------------------------------------
Free     variable NPV                           'Nutidsvaerdi af affaldsdisponering';
                                                
Binary   variable bOnU(u,moall)                 'Anlaeg on-off';
Binary   variable bOnRgk(ua,moall)              'Affaldsanlaeg RGK on-off';
Binary   variable bOnRgkRabat(moall)            'Indikator for om der i given kan opnaas RGK rabat';
Binary   variable bOnSto(s,moall)               'Indikator for om et lager bruges i given maaned ';
                                                
Positive variable FuelConsT(u,f,moall)          'Drivmiddel forbrug p� hvert anlaeg [ton]';
Positive variable FuelConsP(f,moall)            'Effekt af drivmiddel forbrug [MWf]';
Positive variable FuelResaleT(f,moall)          'Drivmiddel gensalg / ikke-udnyttet [ton]';
Positive variable FuelDelivT(f,moall)           'Drivmiddel leverance p� hvert anlaeg [ton]';
Positive variable FuelDelivFreeSumT(f)          'Samlet braendselsm�ngde frie fraktioner';
                                        
Free     variable StoDLoadF(s,f,moall)          'Lagerf�rt br�ndsel (pos. til lager)';

Positive variable StoCostAll(s,moall)           'Samlet lageromkostning';
Positive variable StoCostLoad(s,moall)          'Lageromkostning p� beholdning';
Positive variable StoCostDLoad(s,moall)         'Transportomk. til/fra lagre';
Positive variable StoLoad(s,moall)              'Aktuel lagerbeholdning';
Positive variable StoLoss(s,moall)              'Aktuelt lagertab';
Positive variable StoLossF(s,f,moall)           'Lagertab p� affaldsfraktioner [ton]';
Free     variable StoDLoad(s,moall)             'Aktuel lager�ndring positivt indg�ende i lager';
Positive variable StoDLoadAbs(s,moall)          'Absolut v�rdi af StoDLoad';
Positive variable StoLoadF(s,f,moall)           'Lagerbeholdning af givet br�ndsel p� givet lager';

           
Positive variable PbrutMax(moall)               'Max. mulige brutto elproduktion [MWhe]';
Positive variable Pbrut(moall)                  'Brutto elproduktion [MWhe]';
Positive variable Pnet(moall)                   'Netto elproduktion [MWhe]';
Positive variable Qbypass(moall)                'Bypass varme [MWhq]';
Positive variable Q(u,moall)                    'Grundlast MWq';
Positive variable QaffM(ua,moall)               'Modtryksvarme p� affaldsanlaeg MWq';
Positive variable Qrgk(u,moall)                 'RGK produktion MWq';
Positive variable Qafv(moall)                   'Varme p�lagt affaldvarmeafgift';
Positive variable QRgkMiss(moall)               'Slack variabel til beregning om RGK-rabat kan opnaas';
                                                
Positive variable FEBiogen(u,moall)             'Indfyret biogen affaldsenergi [GJ]';
Positive variable FuelHeatAff(moall)            'Afgiftspligtigt affald medg�et til varmeproduktion';
Positive variable QBiogen(u,moall)              'Biogen affaldsvarme [GJ]';
                                                
Positive variable QtotalCool(moall)             'Sum af total bortk�let varme p� affaldsanl�g';
Positive variable QtotalAff(moall)              'Sum af total varmeproduktion p� affaldsanl�g';
Positive variable EtotalAff(moall)              'Sum af varme- og elproduktion p� affaldsanl�g';
Positive variable QtotalAfgift(phiKind,moall)   'Afgiftspligtig varme ATL- hhv. CO2-afgift';
Positive variable QudenRgk(moall)               'Afgiftspligtig varme (ATL, CO2) uden RGK-rabat';
Positive variable QmedRgk(moall)                'Afgiftspligtig varme (ATL, CO2) med RGK-rabat';
Positive variable Quden_X_bOnRgkRabat(moall)    'Produktet bOnRgkRabat * Qtotal';
Positive variable Qmed_X_bOnRgkRabat(moall)     'Produktet (1 - bOnRgkRabat) * Qtotal';
                                                
Positive variable IncomeTotal(moall)            'Indkomst total';
Positive variable IncomeElec(moall)             'El-indkomst [DKK]';
Positive variable IncomeHeat(moall)             'Indkomnst for varmesalg til GSF';
Positive variable IncomeAff(f,moall)            'Indkomnst for affaldsmodtagelse DKK';
Positive variable RgkRabat(moall)               'RGK rabat p� tillaegsafgift';
Positive variable CostsTotal(moall)             'Omkostninger Total';
Positive variable CostsTotalOwner(owner,moall)  'Omkostninger Total fordelt p� ejere';
Positive variable CostsU(u,moall)               'Omkostninger anl�gsdrift DKK';
#--- Positive variable CostsTotalF(owner, moall)   'Omkostninger Total p� drivmidler DKK';
Positive variable CostsPurchaseF(f,moall)       'Omkostninger til braendselsindkoeb DKK';
                                                
Positive variable TaxAFV(moall)                 'Omkostninger til affaldvarmeafgift DKK';
Positive variable TaxATL(moall)                 'Omkostninger til affaldstillaegsafgift DKK';
Positive variable TaxCO2total(moall)            'Omkostninger til CO2-afgift DKK';
Positive variable TaxCO2Aff(moall)              'CO2-afgift p� affald';
Positive variable TaxCO2Aux(moall)              'CO2-afgift p� �vrige br�ndsler';
Positive variable TaxCO2F(f,moall)              'Omkostninger til CO2-afgift fordelt p� braendselstype DKK';
Positive variable TaxNOxF(f,moall)              'Omkostninger til NOx-afgift fordelt p� braendselstype DKK';
Positive variable TaxEnr(moall)                 'Energiafgift (gaelder kun fossiltfyrede anlaeg)';


Positive variable CostsETS(moall)               'Omkostninger til CO2-kvoter DKK';
Positive variable CO2emisF(f,moall,typeCO2)     'CO2-emission fordelt p� type';
Positive variable CO2emisAff(moall,typeCO2)     'Afgifts- hhv. kvotebelagt affaldsemission';
Positive variable TotalAffEProd(moall)          'Samlet energiproduktion affaldsanlaeg';
                                                
Positive variable QInfeas(dir,moall)            'Virtual varmedraen og -kilde [MWhq]';
Positive variable AffTInfeas(dir,moall)         'Virtual affaldstonnage kilde og dr�n [ton]';
# ------------------------------------------------------------------------------------------------
# Erklaering af ligninger.
# RGK kan moduleres kontinuert: RGK deaktiveres hvis Qdemand < Qmodtryk
# ------------------------------------------------------------------------------------------------
# Fordeling af omkostninger mellem affalds- og varmesiden:
# * AffaldsOmkAndel er andelen, som affaldssiden skal b�re.
# * Til affaldssiden 100 pct: Kvoteomkostning
# * Til fordeling: Alle afgifter
# ------------------------------------------------------------------------------------------------

Equation  ZQ_Obj                           'Objective';
Equation  ZQ_IncomeTotal(moall)            'Indkomst Total';
Equation  ZQ_IncomeElec(moall)             'Indkomst Elsalg';
Equation  ZQ_IncomeHeat(moall)             'Indkomst Varmesalg til GSF';
Equation  ZQ_IncomeAff(f,moall)            'Indkomst p� affaldsfraktioner';
Equation  ZQ_CostsTotal(moall)             'Omkostninger Total';
Equation  ZQ_CostsTotalOwner(owner,moall)  'Omkostninger fordelt p� ejer';
Equation  ZQ_CostsU(u,moall)               'Omkostninger p� anlaeg';
#--- Equation  ZQ_CostsTotalF(owner,moall)    'Omkostninger totalt p� drivmidler';
Equation  ZQ_CostsPurchaseF(f,moall)       'Omkostninger til k�b af affald fordelt p� affaldstyper';
Equation  ZQ_TaxAFV(moall)                 'Affaldsvarmeafgift DKK';
Equation  ZQ_TaxATL(moall)                 'Affaldstillaegsafgift foer evt. rabat DKK';
Equation  ZQ_TaxNOxF(f,moall)              'NOx-afgift p� br�ndsler';
Equation  ZQ_TaxEnr(moall)                 'Energiafgift p� fossil varme';

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
#--- Equation  ZQ_TaxCO2F(f,moall)            'CO2-afgift fordelt p� braendselstyper DKK';
Equation  ZQ_Qafv(moall)                 'Varme hvoraf der skal svares AFV [MWhq]';
Equation  ZQ_CO2emisF(f,moall,typeCO2)   'CO2-maengde hvoraf der skal svares afgift hhv. ETS [ton]';
Equation  ZQ_CO2emisAff(moall,typeCO2);

Equation  ZQ_PrioUp(up,up,moall)         'Prioritet af uprio over visse up anlaeg';


# OBS: GSF-omkostninger skal medtages i Obj for at sikre at varme leveres fra REFAs anl�g.
#      REFA's �konomi vil blive optimeret selvom GSF-omkostningerne er medtaget, netop fordi
#      GSF's varmeproduktionspris er (betydeligt) h�jere end REFA's.
# Hvordan med Nordic Sugars varmeleverance?
#   Den p�l�gges en overskudsvarmeafgift, som kan resultere i en lavere VPO_V end REFA kan pr�stere med indk�bt affald hhv. flis.
#   Dermed er det ikke umiddelbart let at afg�re, om NS-varmen indeb�rer en omkostning for REFA.
#   NS-varmen leveres h�jst i m�nederne okt-feb med tyngden i nov-jan, en periode hvor REFAs affaldsanl�g er udlastede.

ZQ_Obj  ..  NPV  =E=  sum(mo,
                         IncomeTotal(mo)
                         + sum(ua, Gain_Qaff(ua) * QaffM(ua,mo))   # Kun modtryksvarme skal fremmes, idet RGK ikke skal v�re aktiv n�r bortk�ling er aktiv.
                         - CostsTotal(mo)
                         - [ 
                             + Penalty_bOnU * sum(u $OnU(u), bOnU(u,mo))
                             + Penalty_QRgkMiss * QRgkMiss(mo)
                             + [Penalty_QInfeas    * sum(dir, QInfeas(dir,mo))]    $OnQInfeas
                             + [Penalty_AffTInfeas * sum(dir, AffTInfeas(dir,mo))] $OnAffTInfeas
                             + [Penalty_AffaldsGensalg * sum(f $OnF(f), FuelResaleT(f,mo))]
                           ] );

ZQ_IncomeTotal(mo)   .. IncomeTotal(mo)   =E=  sum(fa $OnF(fa), IncomeAff(fa,mo)) + RgkRabat(mo) + IncomeElec(mo) + IncomeHeat(mo);

ZQ_IncomeElec(mo)   ..  IncomeElec(mo)    =E=  Pnet(mo) * (PowerPrice(mo) - TariffElProd(mo));

ZQ_IncomeHeat(mo)   ..  IncomeHeat(mo)    =E=  VarmeSalgspris * sum(u $(OnU(u) AND up(u) AND urefa(u)), Q(u,mo));

ZQ_IncomeAff(fa,mo)  .. IncomeAff(fa,mo)  =E=  FuelDelivT(fa,mo) * FuelBounds(fa,'ModtPris',mo) $(OnF(fa) AND fpospris(fa));

#TODO: Kun REFA omkostninger skal med, ikke GSF ditto.
ZQ_CostsTotal(mo)    .. CostsTotal(mo)    =E= sum(owner, CostsTotalOwner(owner,mo));

#--- ZQ_CostsTotal(mo)    .. CostsTotal(mo)  =E=   sum(u $OnU(u), CostsU(u,mo))
#---                                             + sum(s $OnS(s), StoCostAll(s,mo))
#---                                             + sum(f $OnF(f), CostsPurchaseF(f,mo) + TaxNOxF(f,mo))
#---                                             + (TaxAFV(mo) + TaxATL(mo) + TaxCO2total(mo) + CostsETS(mo) + TaxEnr(mo));
                                            
ZQ_CostsTotalOwner(owner,mo) .. CostsTotalOwner(owner,mo)  =E= 
                                [  sum(urefa $OnU(urefa), CostsU(urefa,mo)) 
                                 + sum(s $OnS(s), StoCostAll(s,mo))
                                 + sum(frefa $OnF(frefa), CostsPurchaseF(frefa,mo) + TaxNOxF(frefa,mo))
                                 + TaxAFV(mo) + TaxATL(mo) + TaxCO2Aff(mo) + CostsETS(mo) 
                                ] $sameas(owner,'refa')
                              + [  sum(ugsf $OnU(ugsf), CostsU(ugsf,mo)) 
                                 + sum(fgsf $OnF(fgsf), CostsPurchaseF(fgsf,mo) + TaxNOxF(fgsf,mo))
                                 + TaxCO2Aux(mo) + TaxEnr(mo)
                                ] $sameas(owner,'gsf');
                            
ZQ_CostsU(u,mo)      .. CostsU(u,mo)      =E=  [Q(u,mo) * DvMWhq(u) + bOnU(u,mo) * DvTime(u)] $OnU(u);

#--- ZQ_CostsTotalF(owner,mo)   .. CostsTotalF(owner,mo) =E=
#---                                  sum(f $(OnF(f) AND f2own(f,owner) AND fnegpris(f)), CostsPurchaseF(f,mo))
#---                                  + sum(f $(OnF(f) AND f2own(f,owner)), TaxCO2F(f,mo) + TaxNOxF(f,mo))
#---                                  + TaxEnr(mo) $sameas(owner,'gsf')
#---                                  + (TaxAFV(mo) + TaxATL(mo) + CostsETS(mo)) $sameas(owner,'refa');


ZQ_CostsPurchaseF(f,mo) $(OnF(f) AND fnegpris(f)) .. CostsPurchaseF(f,mo)  =E=  FuelDelivT(f,mo) * (-FuelBounds(f,'ModtPris',mo));

# Beregning af afgiftspligtigt affald.

ZQ_FuelConsP(f,mo) $OnF(f) .. FuelConsP(f,mo)  =E=  sum(u $(OnU(u) AND u2f(u,f)), FuelConsT(u,f,mo) * LhvMWh(f));  #---  + [AffTInfeas('source',mo) - AffTInfeas('drain',mo)] * LhvMWhAffTInfeas $OnAffTInfeas;

# Opg�relse af biogen affaldsm�ngde for hver ovn-linje.
ZQ_FEBiogen(ua,mo) .. FEBiogen(ua,mo)  =E=  sum(fbiogen $(OnF(fbiogen) AND u2f(ua,fbiogen)), FuelConsT(ua,fbiogen,mo) * LhvMWh(fbiogen));

# Opsummering af varmem�ngder til mere overskuelig afgiftsberegning.
ZQ_QtotalCool(mo) ..  QtotalCool(mo)  =E=  sum(uv $OnU(uv), Q(uv,mo));
ZQ_QtotalAff(mo)  ..  QtotalAff(mo)   =E=  sum(ua $OnU(ua), Q(ua,mo));
ZQ_EtotalAff(mo)  ..  EtotalAff(mo)   =E=  QtotalAff(mo) + Pbrut(mo);

# Affaldvarme-afgift:
ZQ_TaxAFV(mo)     .. TaxAFV(mo)     =E=  TaxAfvMWh(mo) * Qafv(mo);
ZQ_Qafv(mo)       .. Qafv(mo)       =E=  sum(ua $OnU(ua), Q(ua,mo) - 0.85 * FEBiogen(ua,mo)) - sum(uv $OnU(uv), Q(uv,mo));   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.

# F�lles for affaldstill�gs- og CO2-afgift.
ZQ_QUdenRgk(mo)   .. QudenRgk(mo)  =E=  [QtotalAff(mo) * (1 - Phi('85',mo))] / 1.2;
ZQ_QMedRgk(mo)    .. QmedRgk(mo)   =E=  [QtotalAff(mo) - 0.1 * EtotalAff(mo) * (1 - Phi('95',mo))] / 1.2;

# Beregn produktet af bOnRgkRabat * QmedRgk hhv (1 - bOnRgkRabat) * QudenRgk. 
# Produktet bruges i ZQ_TaxATL hhv. ZQ_TaxCO2Aff.

# Afgiftspligtig affaldsm�ngde henf�rt til varmeproduktion.
ZQ_QtotalAfgift(phiKind,mo) .. QtotalAfgift(phiKind,mo)  =E=  [QtotalAff(mo) - 0.1 * EtotalAff(mo) $sameas(phiKind,'95') ] * (1 - phi(phiKind,mo)); 

# Beregning af afgiftspligtig varme n�r bOnRgkRabat == 0, dvs. n�r (1 - bOnRgkRabat) == 1.
ZQ_QudenRgkProductMax1(mo) .. Quden_X_bOnRgkRabat(mo)                          =L=  (1 - bOnRgkRabat(mo)) * QtotalAffMax(mo);
ZQ_QudenRgkProductMin2(mo) .. 0                                                =L=  QtotalAfgift('85',mo) - Quden_X_bOnRgkRabat(mo);
ZQ_QudenRgkProductMax2(mo) .. QtotalAfgift('85',mo) - Quden_X_bOnRgkRabat(mo)  =L=  bOnRgkRabat(mo) * QtotalAffMax(mo);

# Beregning af afgiftspligtig varme n�r bOnRgkRabat == 1.
ZQ_QmedRgkProductMax1(mo) .. Qmed_X_bOnRgkRabat(mo)                          =L=  bOnRgkRabat(mo) * QtotalAffMax(mo);
ZQ_QmedRgkProductMin2(mo) .. 0                                               =L=  QtotalAfgift('95',mo) - Qmed_X_bOnRgkRabat(mo);
ZQ_QmedRgkProductMax2(mo) .. QtotalAfgift('95',mo) - Qmed_X_bOnRgkRabat(mo)  =L=  (1 - bOnRgkRabat(mo)) * QtotalAffMax(mo);


# Till�gsafgift af affald baseret p� SKAT's administrative satser:
ZQ_TaxATL(mo)     .. TaxATL(mo)    =E=  TaxAtlMWh(mo) * (Quden_X_bOnRgkRabat(mo) + Qmed_X_bOnRgkRabat(mo));

# CO2-afgift for alle anl�g:
ZQ_TaxCO2total(mo) .. TaxCO2total(mo)  =E=  TaxCO2Aff(mo) + TaxCO2Aux(mo);

# CO2-afgift af affald baseret p� SKAT's administrative satser:
ZQ_TaxCO2Aff(mo) ..  TaxCO2Aff(mo)  =E=  TaxCO2AffTon(mo) * CO2ContentAff(mo) * (Quden_X_bOnRgkRabat(mo) + Qmed_X_bOnRgkRabat(mo));

ZQ_CostsETS(mo)  ..  CostsETS(mo)   =E=   TaxEtsTon(mo) * sum(fa $OnF(fa), CO2emisF(fa,mo,'kvote'));  # Kun affaldsanl�gget er kvoteomfattet.

# CO2-afgift p� ikke-affaldsanl�g (p.t. ingen afgift p� biomasse):
ZQ_TaxCO2Aux(mo)  .. TaxCO2Aux(mo)  =E=  sum(fr $OnF(fr), sum(ur $(OnU(ur) AND u2f(ur,fr)), FuelConsT(ur,fr,mo))) * TaxCO2peakTon(mo);

# Den fulde CO2-emission uden hensyntagen til fradrag for elproduktion, da det kun vedr�rer beregning af CO2-afgiften, men ikke m�ngden.
ZQ_CO2emisF(f,mo,typeCO2) $OnF(f) .. CO2emisF(f,mo,typeCO2)  =E=  sum(u $(OnU(u) AND u2f(u,f)), FuelConsT(u,f,mo)) * CO2potenTon(f,typeCO2,mo);
ZQ_CO2emisAff(mo,typeCO2)         .. CO2emisAff(mo,typeCO2)  =E=  sum(fa, CO2emisF(fa,mo,typeCO2));
#--- ZQ_CO2emisAff(mo,typeCO2)         .. CO2emisAff(mo,typeCO2)  =E=  QudenRgk(mo) * CO2ContentAff(mo) $sameas(typeCO2,'afgift') + sum(fa, CO2emisF(fa,mo,typeCO2)) $sameas(typeCO2,'kvote');

#--- ZQ_TaxCO2(mo)              .. TaxCO2(mo)     =E=  sum(f $OnF(f), TaxCO2F(f,mo)); 
#--- ZQ_TaxCO2F(f,mo) $OnF(f)   .. TaxCO2F(f,mo)  =E=  sum(ua $(OnU(ua) AND u2f(ua,f)), FuelConsT(ua,f,mo)) * TaxCO2AffTon(mo) $fa(f) 
#---                                                 + sum(ur $(OnU(ur) AND u2f(ur,f)), FuelConsT(ur,f,mo)) * TaxCO2peakTon(mo) $fr(f); 
#--- ZQ_CostsETS(mo)            .. CostsETS(mo)   =E=  sum(fa $OnF(fa), CO2emis(fa,mo,'kvote')) * TaxEtsTon(mo);  # Kun affaldsanl?gget er kvoteomfattet. 
#---  
#--- ZQ_Qafv(mo)                .. Qafv(mo)       =E=  sum(ua $OnU(ua), Q(ua,mo)) - sum(uv $OnU(uv), Q(uv,mo));   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling. 
#---  
#--- #--- ZQ_CO2emis(f,mo) $OnF(f)   .. CO2emis(f,mo)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelConsT(up,f,mo)) * CO2potenTon(f); 
#--- ZQ_CO2emis(f,mo,typeCO2) $OnF(f)   .. CO2emis(f,mo,typeCO2)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelConsT(up,f,mo)) * CO2potenTon(f,typeCO2,mo); 
#---  


# NOx-afgift:
ZQ_TaxNOxF(f,mo) $OnF(f)   .. TaxNOxF(f,mo)  =E=  sum(ua $(OnU(ua) AND u2f(ua,f)), FuelConsT(ua,f,mo)) * DataFuel(f,'NOxKgTon') * TaxNOxAffkg(mo) $fa(f)
                                                + sum(ub $(OnU(ub) AND u2f(ub,f)), FuelConsT(ub,f,mo)) * TaxNOxFlisTon(mo) $fb(f)
                                                + sum(ur $(OnU(ur) AND u2f(ur,f)), FuelConsT(ur,f,mo)) * TaxNOxPeakTon(mo) $fr(f);
                                                
# Energiafgift SR-kedel:
ZQ_TaxEnr(mo)              .. TaxEnr(mo)     =E=  sum(ur $OnU(ur), FuelConsT(ur,'peakfuel',mo)) * TaxEnrPeakTon(mo);

# Prioritering af anl�gsdrift.
# Aktiveringsprioritering: Sikrer kun aktivering, men ikke udlastning/udregulering.
ZQ_PrioUp(uprio,up,mo) $(OnU(uprio) AND OnU(up) AND AvailDaysU(mo,uprio) AND AvailDaysU(mo,up)) ..  bOnU(up,mo)  =L=  bOnU(uprio,mo);

# NS-varme skal udnyttes fuldt ud efter Ovn3 og f�r Ovn2 kommer i indgreb. Da NS kun kommer om vinteren, tvinges NS-varmen ind i fuldt omfang fremfor et loft.
Equation ZQ_PrioNS(moall) 'NS-varme skal udnyttes fuldt ud';
ZQ_PrioNS(mo) $OnU('NS') .. Q('NS',mo)  =E=  Prognoses(mo,'NSprod') * bOnU('NS',mo);

# Desuden skal REFA-anl�g v�re udlastet, inden GSF-anl�g starter, idet GSF-anl�g ikke skal optr�de i OBJ, da det vil forcere Ovn3 i bypass og maksimere RGK.
# GSF-omkostninger er REFA uvedkommende.
# S� det er reelt en model med to ejere, men kun den enes �konomi skal optimeres.
# Da GSF-anl�g ikke kan optr�de i OBJ, m� udlastning af REFA-anl�g derfor sikres p� anden vis.


#begin Beregning af RGK-rabat
# -------------------------------------------------------------------------------------------------------------------------------
# Beregning af RGK-rabatten indeb�rer 2 trin:
#   1: Bestem den manglende RGK-varme QRgkMiss, som er n�dvendig for at opn� rabatten.
#      Det g�res med en ulighed samt en penalty p� QRgkMiss i objektfunktionen for at tvinge den mod nul, n�r rabatten er i hus.
#   2: Beregn rabatten ved den uline�re ligning: RgkRabat =E= bOnRgkRabat * (RgkRabatSats * TaxATL);
#      Produktet af de 2 variable bOnRgkRabat og TaxATL omformuleres vha. 4 ligninger, som indhegner RgkRabat.
# --------------------------------------------------------------------------------------------------------------------------------
Equation  ZQ_TotalAffEprod(moall)  'Samlet energiproduktion MWh';
Equation  ZQ_QRgkMiss(moall)       'Bestem manglende RGK-varme for at opnaa rabat';
Equation  ZQ_bOnRgkRabat(moall)    'Bestem bOnRgkRabat';

ZQ_TotalAffEprod(mo)  ..  TotalAffEProd(mo)  =E=  Pbrut(mo) + sum(ua $OnU(ua), Q(ua,mo));       # Samlet energioutput fra affaldsanl�g. Bruges til beregning af RGK-rabat.
ZQ_QRgkMiss(mo)       ..  sum(ua $OnU(ua), Qrgk(ua,mo)) + QRgkMiss(mo)  =G=  RgkRabatMinShare * TotalAffEProd(mo);
ZQ_bOnRgkRabat(mo)    ..  QRgkMiss(mo)  =L=  (1 - bOnRgkRabat(mo)) * QRgkMissMax;

#OBS: Udkommenteresde inaktive / ugyldige restriktioner slettet

# Beregning af produktet: RgkRabat =E= bOnRgkRabat * (RgkRabatSats * TaxATL);
#--- Equation  ZQ_RgkRabatMin1(moall);
Equation  ZQ_RgkRabatMax1(moall);
Equation  ZQ_RgkRabatMin2(moall);
Equation  ZQ_RgkRabatMax2(moall);

#--- ZQ_RgkRabatMin1(mo) .. 0  =L=  RgkRabat(mo);
ZQ_RgkRabatMax1(mo) .. RgkRabat(mo)  =L=  RgkRabatMax(mo) * bOnRgkRabat(mo);
ZQ_RgkRabatMin2(mo) ..  0 * (1 - bOnRgkRabat(mo))                   =L=  RgkRabatSats * TaxATL(mo) - RgkRabat(mo);
ZQ_RgkRabatMax2(mo) ..  RgkRabatSats * TaxATL(mo) - RGKrabat(mo)  =L=  RgkRabatMax(mo) * (1 - bOnRgkRabat(mo));

#end Beregning af RGK-rabat

#begin Varmebalancer og elproduktion
Equation ZQ_PbrutMin(moall)              'Mindste brutto elproduktion';
Equation ZQ_PbrutMax(moall)              'Brutto elproduktion baseret p� modtryksvarme og eta';
Equation ZQ_Pbrut(moall)                 'Brutto elproduktion';
Equation ZQ_Pnet(moall)                  'Netto elproduktion';
Equation ZQ_Qbypass(moall)               'Bypass varmeproduktion';

Equation  ZQ_Qdemand(moall)              'Opfyldelse af fjv-behov';
Equation  ZQ_Qaff(ua,moall)              'Samlet varmeprod. affaldsanlaeg';
Equation  ZQ_QaffM(ua,moall)             'Samlet modtryks-varmeprod. affaldsanlaeg';
Equation  ZQ_Qrgk(ua,moall)              'RGK produktion p� affaldsanlaeg';
Equation  ZQ_QrgkMax(ua,moall)           'RGK produktion oevre graense';
Equation  ZQ_Qaux(u,moall)               'Samlet varmeprod. oevrige anlaeg end affald';
Equation  ZQ_QaffMmax(ua,moall)          'Max. modtryksvarmeproduktion';
Equation  ZQ_CoolMax(moall)              'Loft over bortkoeling';
Equation  ZQ_QminAux(u,moall)            'Sikring af nedre graense p� varmeproduktion p� ikke-affaldsanl�g';
Equation  ZQ_QMaxAux(u,moall)            'Aktiv status begraenset af total raadighed p� ikke-affaldsanl�g';
Equation  ZQ_QminAff(u,moall)            'Sikring af nedre graense p� varmeproduktion p� affaldsanl�g';
Equation  ZQ_QMaxAff(u,moall)            'Aktiv status begraenset af total raadighed p� affaldsanl�g';
Equation  ZQ_bOnRgk(ua,moall)            'Angiver om RGK er aktiv';
Equation  ZQ_bOnRgkMax(u,moall)          'Forebygger RGK n�r bortk�ling er aktiv';
Equation  ZQ_QrgkTandem(moall)           'Hvis RGK er aktiv, g�lder det begge affaldsovne';  # Skyldes r�ggaskobling i RGK-anl�gget.

# Beregning af elproduktion. Det antages, at oms�tning fra bypass-damp til fjernvarme er 1-til-1, dvs. 100 pct. effektiv bypass-drift.
#--- ZQ_PbrutMax(mo)$OnU('Ovn3')  .. PbrutMax(mo) =E=  EtaE('Ovn3',mo) * sum(fa $(OnF(fa) AND u2f('Ovn3',fa)), FuelConsT('Ovn3',fa,mo) * LhvMWh(fa));
#--- ZQ_Pbrut(mo)   $OnU('Ovn3')  .. Pbrut(mo)    =E=  PbrutMax(mo) * (1 - ShareBypass(mo));
#--- ZQ_Pnet(mo)    $OnU('Ovn3')  .. Pnet(mo)     =E=  Pbrut(mo) - Peget(mo) * (1 - ShareBypass(mo));  # Peget har taget hensyn til bypass.
#--- ZQ_Pnet(mo)    $OnU('Ovn3')  .. Pnet(mo)     =L=  Pbrut(mo) - Peget(mo) * (1 - ShareBypass(mo));  # Peget har taget hensyn til bypass.
#--- ZQ_Pbrut(mo)   $OnU('Ovn3')  .. Pbrut(mo)    =L=  PbrutMax(mo) * (1 - ShareBypass(mo));
#--- ZQ_Qbypass(mo) $OnU('Ovn3')  .. Qbypass(mo)  =E=  (PbrutMax(mo) - Peget(mo)) * ShareBypass(mo);

#TODO: Omkostninger til at d�kke el-egetforbruget, n�r turbinen er ude, er ikke medtaget i objektfunktionen.

ZQ_PbrutMin(mo) $OnU('Ovn3') .. Pbrut(mo)    =G=  Peget(mo) * bOnU('Ovn3',mo);
ZQ_PbrutMax(mo) $OnU('Ovn3') .. PbrutMax(mo) =E=  EtaE('Ovn3',mo) * QAffM('Ovn3',mo) / EtaQ('Ovn3');
# PbrutMax er begr�nset af QAffM, som igen er begr�nset af ShareAvailU('Ovn3',mo) via QaffMmax.
# Derfor skal PbrutMax herunder f�rst bringes tilbage til fuldt r�dighedsniveau af Ovn3, dern�st multipliceres med turbinens r�dighed.
ZQ_Pbrut(mo)    $OnU('Ovn3') .. Pbrut(mo)    =L=  PbrutMax(mo) / ShareAvailU('Ovn3',mo) * ShareAvailTurb(mo);   # Egetforbruget d�kkes kun n�r turbinen er til r�dighed.
#--- ZQ_Pbrut(mo)    $OnU('Ovn3') .. Pbrut(mo)    =L=  PbrutMax(mo) * ShareAvailTurb(mo);   # Egetforbruget d�kkes kun n�r turbinen er til r�dighed.
#--- ZQ_Pbrut(mo)    $OnU('Ovn3') .. Pbrut(mo)    =L=  PbrutMax(mo);   # Egetforbruget d�kkes kun n�r turbinen er til r�dighed.
ZQ_Pnet(mo)     $OnU('Ovn3')     .. Pnet(mo)     =E=  Pbrut(mo) - Peget(mo); 
ZQ_Qbypass(mo)  $OnU('Ovn3')     .. Qbypass(mo)  =E=  PbrutMax(mo) - Pbrut(mo);  # Antager 100 pct. effektiv bypass-drift.
                                 
ZQ_Qdemand(mo)                   ..  Qdemand(mo)   =E=  sum(up $OnU(up), Q(up,mo)) - sum(uv $OnU(uv), Q(uv,mo)) + [QInfeas('source',mo) - QInfeas('drain',mo)] $OnQInfeas;
ZQ_Qaff(ua,mo)     $OnU(ua)      ..  Q(ua,mo)      =E=  [QaffM(ua,mo) + Qrgk(ua,mo)] + Qbypass(mo) $sameas(ua,'Ovn3');
ZQ_QaffM(ua,mo)    $OnU(ua)      ..  QaffM(ua,mo)  =E=  [sum(fa $(OnF(fa) AND u2f(ua,fa)), EtaQ(ua) * FuelConsT(ua,fa,mo) * LhvMWh(fa))] $OnU(ua);
ZQ_QaffMmax(ua,mo) $OnU(ua)      ..  QAffM(ua,mo)  =L=  QaffMmax(ua,mo);    
ZQ_Qrgk(ua,mo)     $OnU(ua)      ..  Qrgk(ua,mo)   =L=  KapRgk(ua) / KapNom(ua) * QaffM(ua,mo);
ZQ_QrgkMax(ua,mo)  $OnU(ua)      ..  Qrgk(ua,mo)   =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);
                                 
ZQ_Qaux(upaux,mo) $OnU(upaux)    ..  Q(upaux,mo)  =E=  [sum(faux $(OnF(faux) AND u2f(upaux,faux)), FuelConsT(upaux,faux,mo) * EtaQ(upaux) * LhvMWh(faux))] $OnU(upaux);
                                 
ZQ_CoolMax(mo)                   ..  sum(uv $OnU(uv), Q(uv,mo))  =L=  sum(ua $OnU(ua), Q(ua,mo));

ZQ_QMinAux(uaux,mo) $OnU(uaux)   ..  Q(uaux,mo)  =G=  ShareAvailU(uaux,mo) * Hours(mo) * KapMin(uaux) * bOnU(uaux,mo);   #  Restriktionen p� timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
ZQ_QMaxAux(uaux,mo) $OnU(uaux)   ..  Q(uaux,mo)  =L=  ShareAvailU(uaux,mo) * Hours(mo) * KapMax(uaux) * bOnU(uaux,mo);

# Gr�nser for varmeproduktion p� affaldsanl�g inds�ttes kun, n�r affaldstonnage-summen ikke er fikseret.
#OBS: Qbypass indg�r i Q('Ovn3',mo).
ZQ_QMinAff(ua,mo) $(OnU(ua) AND NOT DoFixAffT(mo)) ..  Q(ua,mo)  =G=  ShareAvailU(ua,mo) * Hours(mo) * KapMin(ua) * bOnU(ua,mo) + Qbypass(mo) $sameas(ua,'Ovn3');   #  Restriktionen p� timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
ZQ_QMaxAff(ua,mo) $(OnU(ua) AND NOT DoFixAffT(mo)) ..  Q(ua,mo)  =L=  ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua) * bOnU(ua,mo) + Qbypass(mo) $sameas(ua,'Ovn3');

#--- ZQ_QrgkTandem(mo)                                  ..  bOnRgk('Ovn2',mo)  =E=  bOnRgk('Ovn3',mo);
ZQ_QrgkTandem(mo) $(OnU('Ovn2') AND OnU('Ovn3'))   ..  QRgk('Ovn2',mo)  =E=  Qrgk('Ovn3',mo) * kapRgk('Ovn2') / kapRgk('Ovn3');
ZQ_bOnRgk(ua,mo)  $OnU(ua)   ..  Qrgk(ua,mo)    =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);
ZQ_bOnRgkMax(ua,mo) $OnU(ua) ..  bOnRgk(ua,mo)  =L=  (1 - sum(uv $OnU(uv), bOnU(uv,mo)) / card(uv));

#end Varmebalancer

# Restriktioner p� affaldsforbrug p� aars- hhv. maanedsniveau.
# Dagrenovation skal bortskaffes hurtigt, hvilket sikres ved at angive mindstegraenser for affaldsforbrug p� maanedsniveau.
# Andre drivmidler er lagerbarer og kan derfor disponeres over hele �ret, men skal ogs� bortskaffes.

# Alle braendsler skal respektere nedre og oevre graense for forbrug.
# Alle ikke-lagerbare og bortskafbare braendsler skal respektere mindsteforbrug p� maanedsniveau.
# Alle ikke-bortskafbare affaldsfraktioner skal respektere et j�vn
# Ikke-bortskafbare braendsler (fdis(f)) skal kun respektere mindste- og st�rsteforbruget p� maanedsniveau.
# Alle braendsler markeret som bortskaffes, skal bortskaffes indenfor et l�bende aar (lovkrav for affald).
# Braendvaerdi af indfyret affaldsmix skal overholde mindstevaerdi.
# Kapaciteten af affaldsanlaeg er b�de bundet af tonnage [ton/h] og varmeeffekt.

# Disponering af affaldsfraktioner

Equation ZQ_FuelCons(f,moall)   'Relation mellem afbr�ndt, leveret og lagerf�rt br�ndsel (if any)';

ZQ_FuelCons(f,mo)  $OnF(f)  ..  sum(u $(OnU(u) AND u2f(u,f)), FuelConsT(u,f,mo))  =E=  FuelDelivT(f,mo) - [sum(sa $(OnS(sa) and s2f(sa,f)), StoDLoadF(sa,f,mo))] $fsto(f);

# Fiksering af affaldstonnager (option).
Equation ZQ_FixAffDelivSumT(moall) 'Fiksering af sum af affaldstonnager';
ZQ_FixAffDelivSumT(mo) $DoFixAffT(mo) .. sum(fa $OnF(fa), FuelDelivT(fa,mo))  =E=  FixValueAffT(mo) - AffTInfeas('drain',mo) $OnAffTInfeas;
#--- ZQ_FixAffDelivSumT(mo) $DoFixAffT(mo) .. sum(fa $OnF(fa), FuelDelivT(fa,mo))  =L=  FixValueAffT(mo);

# Gr�nser for leverancer, hvis fiksering af affaldstonnage IKKE er aktiv.

Equation  ZQ_FuelMin(f,moall)   'Mindste drivmiddelforbrug p� m�nedsniveau';
Equation  ZQ_FuelMax(f,moall)   'Stoerste drivmiddelforbrug p� m�nedsniveau';
Equation  ZQ_FuelMinYear(f)     'Mindste braendselsforbrug p� �rsniveau';
Equation  ZQ_FuelMaxYear(f)     'Stoerste braendselsforbrug p� �rsniveau';

#--- ZQ_FuelMin(f,mo) $((NOT fa(f) OR NOT DoFixAffT(mo)) AND OnF(f) AND fdis(f) AND NOT ffri(f))  ..  FuelDelivT(f,mo) + FuelResaleT(f,mo)  =G=  FuelBounds(f,'min',mo);
#--- ZQ_FuelMax(f,mo) $((NOT fa(f) OR NOT DoFixAffT(mo)) AND OnF(f) AND fdis(f))                  ..  FuelDelivT(f,mo) + FuelResaleT(f,mo)  =L=  FuelBounds(f,'max',mo) * (1 + 1E-8);  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.
#--- ZQ_FuelMinYear(fdis)  $(OnF(fdis) AND NOT FixAffald) ..  sum(mo $OnM(mo), FuelDelivT(fdis,mo) + FuelResaleT(fdis,mo))  =G=  MinTonnageYear(fdis) * card(mo) / 12;
#--- ZQ_FuelMaxYear(fdis)  $(OnF(fdis) AND NOT FixAffald) ..  sum(mo $OnM(mo), FuelDelivT(fdis,mo) + FuelResaleT(fdis,mo))  =L=  MaxTonnageYear(fdis) * card(mo) / 12 * (1 + 1E-8);

# Fleksible br�ndsler skal ikke overholde m�nedsgr�nser, kun �rsgr�nser.
ZQ_FuelMin(f,mo) $(OnF(f) AND fdis(f) AND NOT fflex(f) AND NOT ffri(f))  ..  FuelDelivT(f,mo) + FuelResaleT(f,mo)  =G=  FuelBounds(f,'min',mo);
ZQ_FuelMax(f,mo) $(OnF(f) AND fdis(f) AND NOT fflex(f))                  ..  FuelDelivT(f,mo) + FuelResaleT(f,mo)  =L=  FuelBounds(f,'max',mo) * (1 + 1E-6);  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.

ZQ_FuelMinYear(f)  $(OnF(f) AND fdis(f)) ..  sum(mo, FuelDelivT(f,mo) + FuelResaleT(f,mo))  =G=  MinTonnageYear(f) * card(mo) / 12;
# Nedenst�ende �ndring medf�rer, at fliskedlen ikke kommer i drift !!!!!!!!
# Det skyldes af faux ogs� kommer ind under begr�nsningen, men det skal kun g�lde for affaldsbr�ndsler.
ZQ_FuelMaxYear(fa)  $(OnF(fa))             ..  sum(mo, FuelDelivT(fa,mo) + FuelResaleT(fa,mo))  =L=  MaxTonnageYear(fa) * card(mo) / 12 * (1 + 1E-6);
#--- ZQ_FuelMaxYear(f)  $(OnF(f))             ..  sum(mo, FuelDelivT(f,mo) + FuelResaleT(f,mo))  =L=  MaxTonnageYear(f) * card(mo) / 12 * (1 + 1E-6);
#--- ZQ_FuelMaxYear(f)  $(OnF(f) AND fdis(f)) ..  sum(mo, FuelDelivT(f,mo) + FuelResaleT(f,mo))  =L=  MaxTonnageYear(f) * card(mo) / 12 * (1 + 1E-8);

# Krav til frie affaldsfraktioner.
Equation ZQ_FuelDelivFreeSum(f)              'Aarstonnage af frie affaldsfraktioner';
Equation ZQ_FuelMinFreeNonStorable(f,moall)  'Ligeligt tonnageforbrug af ikke-lagerbare frie affaldsfraktioner';

ZQ_FuelDelivFreeSum(ffri) $(OnF(ffri) AND card(mo) GT 1)                             ..  FuelDelivFreeSumT(ffri)  =E=  sum(mo, FuelDelivT(ffri,mo));
ZQ_FuelMinFreeNonStorable(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri) AND card(mo) GT 1) ..  FuelDelivT(ffri,mo)      =E=  FuelDelivFreeSumT(ffri) / card(mo);

# Restriktioner p� tonnage og braendvaerdi for affaldsanlaeg. 
# OBS: Aktiveres kun, hvis affaldstonnagesumme ikke er fikseret.
Equation ZQ_MinTonnage(u,moall)    'Mindste tonnage for affaldsanlaeg';
Equation ZQ_MaxTonnage(u,moall)    'Stoerste tonnage for affaldsanlaeg';
Equation ZQ_MinLhvAffald(u,moall)  'Mindste braendvaerdi for affaldsblanding';

#--- ZQ_MaxTonnage(ua,mo) $OnU(ua)    ..  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDelivT(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * KapTon(ua);
#--- ZQ_MinLhvAffald(ua,mo) $OnU(ua)  ..  MinLhvMWh(ua) * sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDelivT(ua,fa,mo))
#---                                       =L=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDelivT(ua,fa,mo) * LhvMWh(fa));

ZQ_MinTonnage(ua,mo)   $(OnU(ua) AND NOT DoFixAffT(mo))  ..  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelConsT(ua,fa,mo))  =G=  ShareAvailU(ua,mo) * Hours(mo) * MinTon(ua);
ZQ_MaxTonnage(ua,mo)   $(OnU(ua) AND NOT DoFixAffT(mo))  ..  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelConsT(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * MaxTon(ua);
ZQ_MinLhvAffald(ua,mo) $(OnU(ua) AND NOT DoFixAffT(mo))  ..  MinLhvMWh(ua) * sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelConsT(ua,fa,mo))  =L=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelConsT(ua,fa,mo) * LhvMWh(fa));

# Lagerdisponering.
Equation ZQ_StoCostAll(s,moall)       'Samlet lageromkostning';
Equation ZQ_StoCostLoad(s,moall)      'Lageromkostning opbevaring';
Equation ZQ_StoCostDLoad(s,moall)     'Lageromkostning transport';
Equation ZQ_bOnSto(s,moall)           'Sikrer at bOnSto afspejler lagerbeholdning';
Equation ZQ_StoLoadMin(s,moall)       'Nedre gr�nse for lagerbeholdning';
Equation ZQ_StoLoadMax(s,moall)       '�vre gr�nse for lagerbeholdning';
Equation ZQ_StoLoadQ(s,moall)         'Varmelagerbeholdning og -�ndring';
Equation ZQ_StoLoadA(s,moall)         'Affaldslagerbeholdning og -�ndring';
Equation ZQ_StoLoadF(s,f,moall)       'Tilv�kst p� affaldslagre';
Equation ZQ_StoLossF(s,f,moall)       'Lagertab p� affaldsfraktioner';
Equation ZQ_StoLossA(s,moall)         'Lagertab proport. til beholdning';
Equation ZQ_StoLossQ(s,moall)         'Tab p� varmelagre';
Equation ZQ_StoDLoad(s,moall)         'Samlet lager�ndring';
Equation ZQ_StoDLoadMax(s,moall)      'Max. lager�ndring';
Equation ZQ_StoDLoadAbs1(s,moall)     'Abs funktion p� lager�ndring StoDLoad';
Equation ZQ_StoDLoadAbs2(s,moall)     'Abs funktion p� lager�ndring StoDLoad';
Equation ZQ_StoFirstReset(s,moall)    'F�rste nulstilling af lagerbeholdning';
Equation ZQ_StoResetIntv(s,moall)     '�vrige nulstillinger af lagerbeholdning';

ZQ_StoCostAll(s,mo)   $OnS(s)  ..  StoCostAll(s,mo)    =E=  StoCostLoad(s,mo) + StoCostDLoad(s,mo);
ZQ_StoCostLoad(s,mo)  $OnS(s)  ..  StoCostLoad(s,mo)   =E=  StoLoadCostRate(s,mo) * StoLoad(s,mo);
ZQ_StoCostDLoad(s,mo) $OnS(s)  ..  StoCostDLoad(s,mo)  =E=  StoDLoadCostRate(s,mo) * StoDLoadAbs(s,mo);

ZQ_bOnSto(s,mo) $OnS(s)        ..  StoCostAll(s,mo)    =L=  bOnSto(s,mo) * StoCostLoadMax(s);
                               
ZQ_StoLoadMin(s,mo) $OnS(s)    ..  StoLoad(s,mo)       =G=  StoLoadMin(s,mo);
ZQ_StoLoadMax(s,mo) $OnS(s)    ..  StoLoad(s,mo)       =L=  StoLoadMax(s,mo);

ZQ_StoDLoad(sa,mo) $OnS(sa)    ..  sum(fsto $(OnF(fsto) AND s2f(sa,fsto)), StoDLoadF(sa,fsto,mo))  =E=  StoDLoad(sa,mo);

# Lageret af en given fraktion kan h�jst t�mmes.

Equation ZQ_StoDLoadFMin(s,f,moall)  'Lagerbeholdnings�ndring af given fraktion';
Equation ZQ_StoLoadSum(s,moall)      'Sum af fraktioner p� givet lager';

# Sikring af at StoDLoadF ikke overstiger lagerbeholdningen fra forrige m�ned og ikke tr�kker mere ud af lageret end beholdningen.
$OffOrder
ZQ_StoDLoadFMin(sa,fsto,mo) $(OnS(sa) AND OnF(fsto) AND s2f(sa,fsto)) .. [StoLoadInitF(sa,fsto) $(ord(mo) EQ 1) + StoLoadF(sa,fsto,mo-1) $(ord(mo) GT 1)] + StoDLoadF(sa,fsto,mo)  =G=  0.0;
$OnOrder
ZQ_StoLoadSum(s,mo) $OnS(s)          .. StoLoad(s,mo)  =E=  sum(fsto $(OnF(fsto) AND s2f(s,fsto)), StoLoadF(s,fsto,mo));

$OffOrder
#--- ZQ_StoLoad(s,mo) $OnS(s)         ..  StoLoad(s,mo)         =E=  StoLoad(s,mo-1) + StoDLoad(s,mo) - StoLoss(s,mo-1);
#--- ZQ_StoLoadQ(sq,mo) $OnS(sq)       ..  StoLoad(sq,mo)        =E=  [StoLoadInitF(s,fsto) $(ord(mo) EQ 1) + StoLoadF(sa,fsto,mo-1) $(ord(mo) GT 1)] + StoDLoadF(sa,fsto,mo) - StoLossF(sa,fsto,mo-1);
# Affaldslagre h�ndteres p� fraktionsbasis, mens varmelagre kun indeholder �t species.
ZQ_StoLoadQ(sq,mo) $OnS(sq)       ..  StoLoad(sq,mo)        =E=  [StoLoadInitQ(sq) $(ord(mo) EQ 1) + StoLoad(sq,mo-1) $(ord(mo) GT 1)] + StoDLoad(sq,mo) - StoLoss(sq,mo);
ZQ_StoLoadA(sa,mo) $OnS(sa)       ..  StoLoad(sa,mo)        =E=  sum(fsto $(OnF(fsto) AND s2f(sa,fsto)), StoLoadF(sa,fsto,mo));
ZQ_StoLoadF(sa,fsto,mo) $OnS(sa)  ..  StoLoadF(sa,fsto,mo)  =E=  [StoLoadInitF(sa,fsto) $(ord(mo) EQ 1) + StoLoadF(sa,fsto,mo-1) $(ord(mo) GT 1)] + StoDLoadF(sa,fsto,mo) - StoLossF(sa,fsto,mo);
$OnOrder

ZQ_StoLossF(sa,fsto,mo) $(OnS(sa) AND OnF(fsto) AND s2f(sa,fsto))  ..  StoLossF(sa,fsto,mo)  =E=  StoLossRate(sa,mo) * StoLoadF(sa,fsto,mo);

ZQ_StoLossA(sa,mo) $OnS(sa)  ..  StoLoss(sa,mo)             =E=  sum(fsto $(OnF(fsto) and s2f(sa,fsto)), StoLossF(sa,fsto,mo));
ZQ_StoLossQ(sq,mo) $OnS(sq)  ..  StoLoss(sq,mo)             =E=  StoLossRate(sq,mo) * StoLoad(sq,mo);

ZQ_StoDLoadMax(s,mo)         ..  StoDLoadAbs(s,mo)          =L=  StoDLoadMax(s,mo) $OnS(s);
ZQ_StoDLoadAbs1(s,mo)        ..  +StoDLoad(s,mo)            =L=  StoDLoadAbs(s,mo) $OnS(s);
ZQ_StoDLoadAbs2(s,mo)        ..  -StoDLoad(s,mo)            =L=  StoDLoadAbs(s,mo) $OnS(s);

# OBS: ZQ_StoFirstReset d�kker med �n ligning pr. lager perioden frem til og med f�rst nulstilling. Denne ligning tilknyttes f�rste m�ned.
# TODO: Lageret fyldes op frem mod slutningen af planperioden, fordi modtageindkomsten g�r det lukrativt.
#       Planperioden b�r derfor indeholde et krav om t�mning af lageret i dens sidste m�ned.
$OffOrder
ZQ_StoFirstReset(s,mo) $OnS(s)  ..  sum(moa $(ord(mo) EQ 1 AND ord(mo) LE StoFirstReset(s)), bOnSto(s,moa))  =L=  StoFirstReset(s) - 1;
ZQ_StoResetIntv(s,mo) $OnS(s)   ..  sum(moa $(ord(mo) GT StoFirstReset(s) AND ord(moa) GE ord(mo) AND ord(moa) LE (ord(mo) - 1 + StoIntvReset(s))), bOnSto(s,moa))  =L=  StoIntvReset(s) - 1;
$OnOrder


# Erkl�ring af optimeringsmodels ligninger.
model modelREFA / all /;


#--- # DEBUG: Udskrivning af modeldata f�r solve.
#--- $gdxout "REFAmain.gdx"
#--- $unload
#--- $gdxout

$If not errorfree $exit

# End-of-Model-Declaration

# Erkl�ring af scenario Loop

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
Scalar    NPV_REFA_V      'REFAs nutidsv�rdi';
Scalar    NPV_Total_V     'Total nutidsv�rdi (REFA + GSF)';
Scalar    Penalty_QInfeasTotal, Penalty_AffTInfeasTotal;                          # Penalty bidrag fra infeasibiliteter.
Scalar    Penalty_bOnUTotal, Penalty_QRgkMissTotal, Penalty_AffaldsGensalgTotal;  # Penalty bidrag p� objektfunktionen.
Scalar    PerStart;    
Scalar    PerSlut;
Scalar    TimeOfWritingMasterResults   'Tidsstempel for udskrivning af resultater for aktuelt scenarie';
Scalar    Gain_QaffTotal               'Samlede virtuelle gevinst for affaldsvarme';                        # Gain bidrag p� objektfunktionen.
#--- Parameter Scen_TimeStamp(scen)         'Tidsstempel for scenarier';

# Kopi af data, som kan �ndres af scenarieparametre
Parameter PrognosesSaved(moall,labProgn)   'Kopi af referencedata for prognoser';

Parameter Scen_Overview(topic,scen)    'N�gletal (sum) for scenarier';
Parameter Scen_Q(u,scen)               'Varmem�ngder (sum) for scenarier';
Parameter Scen_FuelDeliv(f,scen)       'Br�ndselsm�ngder (sum) for scenarier';
Parameter Scen_IncomeFuel(f,scen)      'Br�ndselsindt�gt (sum) for scenarier';

Parameter DataCtrl_V(labDataCtrl);
Parameter DataU_V(u,labDataU);
Parameter DataSto_V(s,labDataSto);
Parameter DataFuel_V(f,labDataFuel);
Parameter Prognoses_V(labProgn,moall)      'Prognoser transponeret';
Parameter FuelBounds_V(f,bound,moall);
Parameter FuelDeliv_V(f,moall)             'Leveret br�ndsel';
Parameter FuelConsT_V(u,f,moall)           'Afbr�ndt br�ndsel for givet anl�g';
Parameter FuelConsP_V(u,f,moall)           'Effekt af afbr�ndt br�ndsel for givet anl�g';
Parameter StoDLoadF_V(s,f,moall)           'Lager�ndring for givet lager og br�ndsel';
Parameter StoLoadF_V(s,f,moall)            'Lagerbeholdning for givet lager og br�ndsel';
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
Parameter RefaBypassVarme_V(moall)         'REFA Bypass-varme p� Ovn3 [MWhq]';
Parameter RefaRgkProd_V(moall)             'REFA RGK-varmeproduktion [MWhq]';
Parameter RefaRgkShare_V(moall)            'RGK-varmens andel af REFA energiproduktion';
Parameter RefaBortkoeletVarme_V(moall)     'REFA bortkoelet varme [MWhq]';
Parameter VarmeVarProdOmkTotal_V(moall)    'Variabel varmepris p� tvaers af alle produktionsanl�g DKK/MWhq';
Parameter VarmeVarProdOmkRefa_V(moall)     'Variabel varmepris p� tvaers af REFA-produktionsanl�g DKK/MWhq';
Parameter RefaLagerBeholdning_V(s,moall)   'Lagerbeholdning [ton]';

Parameter VPO_V(uaggr,moall)               'VPO_V DKK/MWhq';

Parameter Usage_V(u,moall)                 'Kapacitetsudnyttelse af anl�g';
Parameter LhvCons_V(u,moall)               'Realiseret br�ndv�rdi';
Parameter FuelConsumed_V(u,moall)          'Tonnage afbr�ndt timebasis';
Parameter AffaldConsTotal_V(moall)         'Tonnage totalt afbr�ndt';
Parameter AffaldAvail_V(moall)             'R�dig affaldsm�ngde [ton]';
Parameter AffaldUudnyttet_V(moall)         'Ikke-udnyttet affald [ton]';
Parameter AffaldLagret_V(moall)            'Lagerstand [ton]';

Parameter GsfTotalVarOmk_V(moall)          'Guldborgsund Forsyning Total indkomst [DKK]';
Parameter GsfAnlaegsVarOmk_V(moall)        'Guldborgsund Forsyning Var anlaegs omk [DKK]';
Parameter GsfBraendselsVarOmk_V(moall)     'Guldborgsund Forsyning Var braendsels omk. [DKK]';
Parameter GsfAfgifter_V(moall)             'Guldborgsund Forsyning Afgifter [DKK]';
Parameter GsfCO2emission_V(moall)          'Guldborgsund Forsyning CO2 emission [ton]';
Parameter GsfTotalVarmeProd_V(moall)       'Guldborgsund Forsyning Total Varmeproduktion [MWhq]';

Parameter NsTotalVarmeProd_V(moall)        'Nordic Sugar Total varmeproduktion [MWhq]';

# Begin Erkl�ring af iterations Loop p� Phi-faktorer.

$OnText
 Ops�tning af parametre til iterativ afgiftsberegning.
 Afgifter knyttet til affaldsanl�g er uline�re i produktionsvariable og 
 det er omst�ndeligt at lave bivariate approksimationer af de kvadratiske led.
 Ulineariteten opst�r, fordi den afgiftspligtige varme Qafg = Qtotal * (F - Fbiogen) / F,
 hvor Fbiogen er den afgiftsfrie br�ndselseffekt MWf og F er den fulde br�ndselseffekt.
 Ligningen omskrives til Qafg = Qtotal * (1 - phi), hvor phi = Fbiogen / Fenergi.
 Generelt skal ogs� fossile br�ndsler som olie og gas l�gges ind under Fbiogen, 
 men de har s� deres egne afgifter i mods�tning til biogene br�ndsler.
 Bem�rk, at Fenergi beregnes forskelligt afh. af RGK-produktion eller ej:
   Fenergi = (Qtotal + P) / 0.85   uden RGK-produktion.
   Fenergu = (Qtotal + P) / 0.95   med  RGK-produktion.
   
 Da regnetiden for modellen er p� f� sekunder, anvendes i stedet for en iterativ metode.
 I f�rste iteration s�ttes phi := 0 og afgifterne beregnes nu ved line�re ligninger.
 Efter solve beregnes den v�rdi, som phi har p� basis af de forbrugte affaldsm�ngder.
 Dern�st gentages optimeringen og phi genberegnes, indtil et stopkriterium er opfyldt.
 Stopkriteriet er den f�rste af: 
   1:  Max. antal iterationer 
   2:  Afvigelsen: Delta = (Metric[i] - Metric[i-1]) / (Metric[i] + Metric[i-1])
  
 Iterationshistorien opsamles i en parameter indekseret med set iter. 
$OffText

Scalar    NiterMax / 10 /;
Scalar    IterNo                       'Iterationsnummer';
Scalar    ConvergenceFound             'Angiver 0/1 at iterationen er konvergeret';
Scalar    DeltaConvMetricTol           'Tolerance p� relativ konvergensmetrik-afvigelse ift. forrige iteration' / 0.001 /;
Scalar    DeltaAfgift                  'Afgiftsafvigelse ift. forrige iteration';
Scalar    DeltaConvMetric              'Relativ konvergensmetrikafvigelse ift. forrige iteration';
Scalar    PhiScale                     'Nedskaleringsfaktor p� phi' / 0.70 /;

# Erkl�ring af parametre til iterativ l�sning af uline�r afgiftsberegning.
Parameter eE(phiKind)                  'Energivirkningsgrad'   / '85' 0.85,  '95' 0.95 /;
Parameter Fenergi(phiKind,moall)       'Aktuel v�rdi af Fenergi = (Qtotal + P)/e';
Parameter QafgAfv(moall)               'Efterberegning af affaldvarmeafgiftspligtig varme';
Parameter QafgAtl(moall)               'Efterberegning af affaldtill�gsafgiftspligtig varme';
Parameter QafgCO2(moall)               'Efterberegning af CO2-afgiftspligtig varme';
Parameter AfgAfv(moall)                'Afgiftssum AFV';
Parameter AfgAtl(moall)                'Afgiftssum ATL';
Parameter AfgCO2(moall)                'Afgiftssum CO2';
Parameter AfgiftTotal(moall)           'Afgiftssum';
Parameter QcoolTotal(moall)            'Total bortk�let varme';
Parameter Qtotal(moall)                'Total varmeproduktion affaldsanl�g';
Parameter EnergiTotal(moall)           'Total energiproduktion affaldsanl�g';
Parameter FEBiogenTotal(moall)         'Total biogen indfyret effekt affaldsanl�g';
Parameter PhiIter(phiKind,moall,iter)  'Iterationshistorie for phi';
Parameter AfgiftTotalIter(moall,iter)  'Afgiftssum';
Parameter DeltaAfgiftIter(iter)        'Iterationshistorie p� afgiftsafvigelse';
Parameter ConvMetric(moall)            'Konvergensmetrikbasis for afgiftsiteration';
Parameter ConvMetricIter(moall,iter)   'Konvergensmetrikbasis-historik for afgiftsiteration';
Parameter DeltaConvMetricIter(iter)    'Konvergensmetrik-historik for afgiftsiteration';

Parameter dPhi(phiKind)                      'Phi-�ndring ift. forrige iteration';
Parameter dPhiChange(phiKind)                '�ndring af Phi-�ndring ift. forrige iteration';
Parameter dPhiIter(phiKind,moall,iter)       'Phi-�ndring ift. forrige iteration';
Parameter dPhiChangeIter(phiKind,moall,iter) '�ndring af Phi-�ndring ift. forrige iteration';

# End Erkl�ring af iterations Loop p� Phi-faktorer.


# ===================================================  BEGIN SCENARIE LOOP  =============================================================

# Initialisering af scenarie Loop.

# Tag backup af parametre i Prognoses, som er aktive i Scen_Progn.
PrognosesSaved(moall,labPrognScen) = Prognoses(moall,labPrognScen);

nScen = 0;
Scen_Progn('scen0','Aktiv') = 1;                    # Reference-scenariet beregnes altid.
Scen_Progn_Transpose(labPrognScen,'scen0') = tiny;

Loop (scen $Scen_Progn(scen,'Aktiv'),               # Begin-of-scenario Loop
actScen(scen) = yes;
nScen = nScen + 1;
display actScen, nScen;

# Overf�rsel af aktuelle scenaries parametre.
# scen0 er reference-scenarie og skal derfor ikke have modificeret parametre.
# Aktuelt kan kun prognose-parametre specificeres, men �vrige datatyper kan tilf�jes.
# Dermed kan principielt alle parametre g�res til scenarieparametre.
# Al initialisering af afledte sets og parametre f�lger efter overf�rsel af parameterv�rdier for aktuelt scenarie.

# F�rst tilbagestilles p�virkede scenarieparametre til udgangspunktet.
if (ord(scen) GT 1,
  Prognoses(mo,labPrognScen) = PrognosesSaved(mo,labPrognScen);

  # Kun ikke-NaN parametre overf�res fra scenariet.
  Loop (labPrognScen,
    if (Scen_Progn(actScen,labPrognScen) NE NaN,
      Prognoses(mo,labPrognScen) = Scen_Progn(actScen,labPrognScen);
    );
  );
);

#begin Rimelighedskontrol af potentielt modificerede inputtabeller.

Loop (labDataU $(NOT sameas(labDataU,'KapMin') AND NOT sameas(labDataU,'MinLast')),
  tmp1 = sum(u, DataU(u,labDataU));
  tmp2 = ord(labDataU);
  if (tmp1 EQ 0, 
    display tmp2;
    abort "ERROR: Mindst �n kolonne (se tmp2) i DataU summer til nul.";
  );
);

Loop (labDataSto $(NOT sameas(labDataSto,'Aktiv') AND NOT sameas(labDataSto,'LoadInit') AND NOT sameas(labDataSto,'LoadMin') AND NOT sameas(labDataSto,'LossRate')),
  tmp1 = sum(s, DataSto(s,labDataSto));
  tmp2 = ord(labDataSto);
  if (tmp1 EQ 0, 
    display tmp2;
    abort "ERROR: Mindst �n kolonne (se tmp2) i DataSto summer til nul.";
  );
);

$OffOrder
Loop (labProgn,
  labPrognSingle(labProgn) = yes;
  tmp1 = sum(moall, Prognoses(moall,labProgn));
  if (tmp1 EQ 0, 
    display labPrognSingle;
    abort "ERROR: Mindst �n kolonne (se labPrognSingle) i Prognoses summer til nul.";
  );
);
$OnOrder

Loop (labDataFuel,
  tmp1 = sum(f, DataFuel(f,labDataFuel));
  tmp2 = ord(labDataFuel);
  if (tmp1 EQ 0, 
    display tmp2;
    abort "ERROR: Mindst �n kolonne (se tmp2) i DataFuel summer til nul.";
  );
);

$OffOrder
Loop (bound $(sameas(bound,'max')), 
  tmp3 = ord(bound);
  Loop (fa $DataFuel(fa,'Aktiv'),
    tmp1 = sum(moall, FuelBounds(fa,bound,moall));
    tmp2 = ord(fa);
    if (tmp1 EQ 0, 
      display tmp3, tmp2;
      abort "ERROR: Mindst �n r�kke (se bound=tmp3, fa=tmp2) i FuelBounds summer til nul.";
    );
  );
);
$OnOrder

#end Rimelighedskontrol af potentielt modificerede inputtabeller.



#begin Ops�tning af sets og parametre afledt fra inputdata.

# NEDENSTAAENDE DYNAMISKE SAET KAN IKKE BRUGES TIL ERKLAERING AF VARIABLE OG LIGNINGER, DERFOR ER DE DEAKTIVERET.
#--- # Anlaegstyper
#--- ua(u)   = DataU(u,'ukind') EQ 1;
#--- ub(u)   = DataU(u,'ukind') EQ 2;
#--- uc(u)   = DataU(u,'ukind') EQ 3;
#--- uv(u)   = DataU(u,'ukind') EQ 4;
#--- ur(u)   = DataU(u,'ukind') EQ 5;
#--- up(u)   = NOT uv(u);
#--- uaux(u) = NOT ua(u);


# Anl�gsprioriteter.
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
#--- display uprio, uprio2up;

u2f(ua,fa) = no;
Loop (fa, 
  u2f('Ovn2',fa) = DataFuel(fa,'TilOvn2') NE 0;
  u2f('Ovn3',fa) = DataFuel(fa,'TilOvn3') NE 0;
);

# Undertyper af br�ndsler:
# fsto:  Br�ndsler, som m� lagres (bem�rk af t�mning af lagre er en s�rskilt restriktion)
# fdis:  Br�ndsler, som skal modtages og forbr�ndes hhv. om muligt lagres. 
# ffri:  Br�ndsler, hvor den �vre gr�nse aftagem�ngde er en optimeringsvariabel.
# fflex: Br�ndsler, hvor m�nedstonnagen er fri, men �rstonnagen skal respekteres.
# faux:  Br�ndsler, som ikke er affaldsbr�ndsler.

fsto(f)  = DataFuel(f,'Lagerbar') NE 0;
fdis(f)  = DataFuel(f,'Bortskaf') NE 0;
ffri(f)  = DataFuel(f,'Fri')      NE 0 AND fa(f);
fflex(f) = DataFuel(f,'Flex')     NE 0 AND fa(f);
faux(f)  = NOT fa(f);

# Identifikation af lagertyper.
sa(s) = DataSto(s,'stoKind') EQ 1;
sq(s) = DataSto(s,'stoKind') EQ 2;

# Tilknytning af affaldsfraktioner til lagre.
# Brugergivne restriktioner p� kombinationer af lagre og br�ndselsfraktioner.

s2f(s,f)   = no;
s2f(sa,fa) = DataFuel(fa,'lagerbar') AND DataSto(sa,'aktiv');

# Brugergivet tilknytning af lagre til affaldsfraktioner kr�ver oprettelse af nye elementer i labDataFuel.
Loop (fa, 
  Loop (sa,
    Loop (labDataFuel $sameas(sa,labDataFuel),
      tmp1 = DataFuel(fa,labDataFuel);
      # En negativ v�rdi DataFuel(fa,labDataFuel) angiver, at lageret ikke kan opbevare br�ndslet fa.
      s2f(sa,fa) = s2f(sa,fa) AND (tmp1 GE 0);
    );
  );
);

# Overordnet r�dighed af anl�g, lagre, br�ndsler og m�neder.
OnU(u)       = DataU(u,'aktiv');
OnF(f)       = DataFuel(f,'aktiv');
OnS(s)       = DataSto(s,'aktiv');
OnM(moall)   = Prognoses(moall,'aktiv');
Hours(moall) = 24 * Prognoses(moall,'ndage');

# Initialisering af aktive perioder (maaneder).
mo(moall) = no;
mo(moall) = OnM(moall);
NactiveM  = sum(moall, OnM(moall));

Loop (u $OnU(u),
  Loop (labProgn $sameas(u,labProgn),
    AvailDaysU(mo,u)  = Prognoses(mo,labProgn) $(OnU(u) AND OnM(mo));
    ShareAvailU(u,mo) = max(0.0, min(1.0, AvailDaysU(mo,u) / Prognoses(mo,'Ndage') ));
  );
);

AvailDaysTurb(mo)  = Prognoses(mo,'Turbine') $(OnU('Ovn3') AND OnM(mo));
ShareAvailTurb(mo) = max(0.0, min(1.0, AvailDaysTurb(mo) / Prognoses(mo,'Ndage') ));

# Ovn3 er KV-anl�g med mulighed for turbine-bypass-drift.
#OBS: Bypass-drift �ndret fra forskrift til optimerings-aspekt, dvs. styret af objektfunktionen.
#     Underkastet en forskrift om bypass er tilladt eller ej i en given m�ned.
#--- ShareBypass(mo) = max(0.0, min(1.0, Prognoses(mo,'Bypass') / (24 * Prognoses(mo,'Ovn3')) ));
#--- HoursBypass(mo) = Prognoses(mo,'Bypass');
OnBypass(mo) = Prognoses(mo,'Bypass');
Peget(mo)    = EgetforbrugKVV * (AvailDaysTurb(mo));
#--- Peget(mo)       = EgetforbrugKVV * (AvailDaysU(mo,'Ovn3'));  #---   - HoursBypass(mo));
#--- display mo, OnU, OnF, OnM, Hours, AvailDaysU, ShareAvailU, ShareBypass;


# Produktionsanl�g og k�lere.

MinLhvMWh(ua) = DataU(ua,'MinLhv') / 3.6;
MaxLhvMWh(ua) = DataU(ua,'MaxLhv') / 3.6;
MinTon(ua)    = DataU(ua,'MinTon');
MaxTon(ua)    = DataU(ua,'Maxton');
KapMin(u)     = DataU(u, 'KapMin');
KapRgk(ua)    = DataU(ua,'KapRgk');
KapNom(u)     = DataU(u,'KapQNom');
KapE(u,moall) = DataU(u,'KapE');
EtaE(u,moall) = DataU(u,'EtaE');
EtaQ(u)       = DataU(u,'EtaQ');
EtaRgk(u)     = DataU(u,'KapRgk') / DataU(u,'KapQNom') * EtaQ(u);
DvMWhq(u)     = DataU(u,'DvMWhq');
DvTime(u)     = DataU(u,'DvTime');
KapMax(u)     = KapNom(u) + KapRgk(u);

# EtaE er 18 % til og med august 2021, og derefter antages v�rdien givet i DataU.
# KapE er 7,5 MWe til og med august 2021, og derefter antages v�rdien givet i DataU.
if (Schedule('aar','FirstYear') EQ 2021,
  Loop (moall $(ord(moall) GE 1 AND ord(moall) LE 8+1),   # OBS: moall starter med element mo0, derfor 8+1 t.o.m. august. 
    EtaE('Ovn3', moall) = 0.18;
    KapE('Ovn3', moall) = 7.5;
  );
);

#--- display MinLhvMWh, MinTon, MaxTon, KapMin, KapNom, KapRgk, KapMax, EtaE, EtaQ, EtaRgk, DvMWhq, DvTime;

# Lagre. Parametre g�res alment periodeafh�ngige, da det giver max. fleksiblitet ift. scenarie-specifikation.
Loop (fa, 
  StoLoadInitF('sto1',fa) = DataFuel(fa,'InitSto1');      
  StoLoadInitF('sto2',fa) = DataFuel(fa,'InitSto2');      
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

# Prognoser.
#--- Parameter FuelBoundsModif(f,bound,moall) 'Maengdegraenser for drivmidler som inddrager anl�gsr�dighed';
fpospris(f)       = yes;
fpospris(f)       = DataFuel(f,'pris') GE 0.0;
fnegpris(f)       = NOT fpospris(f);
fbiogen(f)        = fa(f) AND (DataFuel(f,'CO2kgGJ') EQ 0);

MinTonnageYear(f) = DataFuel(f,'minTonnage');
MaxTonnageYear(f) = DataFuel(f,'maxTonnage');
LhvMWh(f)         = DataFuel(f,'brandv') / 3.6;

DoFixAffT(mo) = FixAffald AND (FixValueAffT(mo) NE NaN);
#--- execute_unload "REFAmain.gdx";
#--- abort "BEVIDST STOP";

# �rskrav til affaldsfraktioner, som skal bortskaffes.
# FuelBounds er beregnet p� basis af fuldlast hver m�ned og ligelig fordeling af �rstonnage henover m�nederne.
# Gr�nserne skal tage hensyn til r�digheden af affaldsovnen. Det antages at overskydende affald s�lges og dermed ikke indg�r i regnskabet.
# Der er b�de begr�nsninger....
# FuelBoundsModif(fa,'min',mo) = FuelBounds(fa,'min',mo) * sum(ua $OnU(ua), MaxTon(ua) * 24 * AvailDaysU(ua,mo))

#--- FuelBoundsModif(f,bound,mo) = FuelBounds(f,bound,mo);
#--- FuelBoundsModif(fa,'min',mo) = min(FuelBounds(fa,'min',mo), sum(ua $OnU(ua), MaxTon(ua) * 24 * AvailDaysU(mo,ua)));
#--- FuelBoundsModif(fa,'max',mo) = max(FuelBounds(fa,'max',mo), sum(ua $OnU(ua), MinTon(ua) * 24 * AvailDaysU(mo,ua)));


#=== ZQ_FuelMin(f,mo) $(OnF(f) AND fdis(f) AND NOT ffri(f))  ..  FuelDelivT(f,mo)  =G=  FuelBounds(f,'min',mo);
#=== ZQ_FuelMax(f,mo) $(OnF(f) AND fdis(f))                  ..  FuelDelivT(f,mo)  =L=  FuelBounds(f,'max',mo) * 1.0001;  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.



# Emissionsopg�relsen for affald er som udgangspunkt efter skorstensmetoden, hvor CO2-indholdet af  hver fraktion er kendt.
# Men uden skorstensmetoden anvendes i stedet for SKATs emissionssatser, som desuden er forskellige efter om det er CO2-afgift eller CO2-kvoteforbruget, som skal opg�res !!!
CO2potenTon(f,typeCO2,mo) = DataFuel(f,'brandv') * DataFuel(f,'CO2kgGJ') / 1000;  # ton CO2 / ton br�ndsel.
if (NOT SkorstensMetode,
  CO2potenTon(fa,typeCO2,mo) = DataFuel(fa,'brandv') * [Prognoses(mo,'CO2aff') $sameas(typeCO2,'afgift') + Prognoses(mo,'ETSaff') $sameas(typeCO2,'kvote')] / 1000;
);
CO2potenTon(fbiogen,typeCO2,mo) = 0.0;

Qdemand(mo)       = Prognoses(mo,'varmebehov');
#--- PowerProd(mo)     = Prognoses(mo,'ELprod');
PowerPrice(mo)    = Prognoses(mo,'ELpris');
#TODO: Tarif p� indf�dning af elproduktion p� nettet skal flyttes til DataCtrl.
TariffElProd(mo)  = 4.00;  
#--- IncomeElec(mo)    = PowerProd(mo) * PowerPrice(mo) $OnU('Ovn3');
TaxAfvMWh(mo)     = Prognoses(mo,'afv') * 3.6;
TaxAtlMWh(mo)     = Prognoses(mo,'atl') * 3.6;
TaxEtsTon(mo)     = Prognoses(mo,'ets');
CO2ContentAff(mo) = Prognoses(mo,'CO2aff') / 1E3;   # CO2-indhold i generisk affald [ton CO2 / GJf]
TaxCO2AffTon(mo)  = Prognoses(mo,'CO2afgAff');
TaxNOxAffkg(mo)   = Prognoses(mo,'NOxAff');
TaxNOxFlisTon(mo) = Prognoses(mo,'NOxFlis') * DataFuel('flis','brandv');
TaxEnrPeakTon(mo) = Prognoses(mo,'EnrPeak') * DataFuel('peakfuel','brandv');
TaxCO2peakTon(mo) = Prognoses(mo,'CO2peak');
TaxNOxPeakTon(mo) = Prognoses(mo,'NOxPeak');
#--- display MinTonnageYear, MaxTonnageYear, LhvMWh, Qdemand, PowerProd, PowerPrice, IncomeElec, TaxAfvMWh, TaxAtlMWh, TaxEtsTon, TaxCO2AffTon, TaxCO2peakTon;

# Special-haandtering af oevre graense for Nordic Sugar varme.
FuelBounds('NSvarme','max',moall) = Prognoses(moall,'NS');

QtotalAffMax(mo)  = sum(ua $OnU(ua), (EtaQ(ua) + EtaRgk(ua)) * sum(fa $(OnF(fa) AND u2f(ua,fa)), LhvMWh(fa) * FuelBounds(fa,'max',mo)) );
StoCostLoadMax(s) = smax(mo, StoLoadMax(s,mo) * StoLoadCostRate(s,mo));

display QtotalAffMax, StoCostLoadMax;

# EaffGross skal v�re mininum af energiindhold af r�dige m�ngder affald hhv. affaldsanl�ggets fuldlastkapacitet.
#--- QaffMmax(ua,moall)  = min(ShareAvailU(ua,moall) * Hours(moall) * KapNom(ua), [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelBounds(fa,'max',moall) * EtaQ(ua) * LhvMWh(fa))]) $OnU(ua);
QaffMmax(ua,moall) = min(ShareAvailU(ua,moall) * Hours(moall) * KapNom(ua), [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelBounds(fa,'max',moall) * EtaQ(ua) * LhvMWh(fa))]) $OnU(ua);
# Hvis affaldstonnager er fikseret, skal begr�nsningen i QaffMmax lempes.
Loop (mo $DoFixAffT(mo), 
  QaffMmax(ua,mo) =  ShareAvailU(ua,mo) * Hours(mo) * KapNom(ua);
);
QrgkMax(ua,moall)   = KapRgk(ua) / KapNom(ua) * QaffMmax(ua,moall);
QaffTotalMax(moall) = sum(ua $OnU(ua), ShareAvailU(ua,moall) * (QaffMmax(ua,moall) + QrgkMax(ua,moall)) );
#--- EaffGross(moall)    = QaffTotalMax(moall) + PowerProd(moall);
#--- display QaffMmax, QrgkMax, QaffTotalMax, EaffGross;

TaxATLMax(mo) = sum(ua $OnU(ua), ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua)) * TaxAtlMWh(mo);
RgkRabatMax(mo) = RgkRabatSats * TaxATLMax(mo);
QRgkMissMax = 2 * RgkRabatMinShare * sum(ua $OnU(ua), 31 * 24 * KapNom(ua));  # Faktoren 2 er en sikkerhedsfaktor mod infeasibilitet.
#--- display TaxATLMax, RgkRabatMax, QRgkMissMax;

#--- execute_unload "REFAmain.gdx";
#--- abort "BEVIDST STOP EFTER QaffMmax";
$If not errorfree $exit

#end Ops�tning af sets og parametre afledt fra inputdata.


#begin Initialisering af variable.

# Fiksering af ikke-forbundne anl�g+drivmidler, samt af ikke-aktive anlaeg og ikke-aktive drivmidler.
# F�rst l�snes variable, som kunne v�re blevet fikseret i forrige scenarie.
if (nScen GE 2 AND FALSE,
  bOnU.up(u,mo)              =  1;
  bOnSto.up(s,mo)            =  1; 
  bOnRgk.up(ua,mo)           =  1; 
  bOnRgkRabat.up(mo)         =  1; 
  Q.fx(u,mo)                 = Big;
  CostsU.fx(u,mo)            = Big;
  FuelConsT.fx(u,f,mo)       = Big;
  Pbrut.fx(mo)               = Big;
  Pnet.fx(mo)                = Big;
  Qbypass.fx(mo)             = Big;
  StoLoad.up(s,mo)           = Big;
  StoLoss.up(s,mo)           = Big;
  StoDLoad.up(s,mo)          = Big;
  StoDLoadAbs.up(s,mo)       = Big;
  StoCostAll.up(s,mo)        = Big;
  StoDLoadF.up(s,f,mo)       = Big;
  CostsPurchaseF.up(f,mo)    = Big;
  IncomeAff.up(f,mo)         = Big;
  CO2emisF.up(f,mo,typeCO2)  = Big;
  FuelDelivT.up(f,mo)        = Big;
  FuelConsT.up(u,f,mo)       = Big;
  FuelConsP.up(f,mo)         = Big;
  StoDLoadF.up(s,f,mo)       = Big;
  CostsPurchaseF.up(f,mo)    = Big;
  IncomeAff.up(f,mo)         = Big;
  StoLoad.up(s,mo)           = Big;
);

# Dern�st udf�res fikseringer svarende til det aktuelle scenarie.
Loop (u $(NOT OnU(u)),
  bOnU.fx(u,mo)         = 0.0;
  Q.fx(u,mo)            = 0.0;
  CostsU.fx(u,mo)       = 0.0;
  FuelConsT.fx(u,f,mo)  = 0.0;
);

if (NOT OnU('Ovn3'),
  Pbrut.fx(mo)   = 0.0;
  Pnet.fx(mo)    = 0.0;
  Qbypass.fx(mo) = 0.0;
);

Loop (s $(NOT OnS(s)),
  bOnSto.fx(s,mo)      = 0.0;
  StoLoad.fx(s,mo)     = 0.0;
  StoLoss.fx(s,mo)     = 0.0;
  StoDLoad.fx(s,mo)    = 0.0;
  StoDLoadAbs.fx(s,mo) = 0.0;
  StoCostAll.fx(s,mo)  = 0.0;
  StoDLoadF.fx(s,f,mo) = 0.0;
);

Loop (f $(NOT OnF(f)),
  CostsPurchaseF.fx(f,mo)    = 0.0;
  IncomeAff.fx(f,mo)         = 0.0;
  CO2emisF.fx(f,mo,typeCO2)  = 0.0;
  FuelDelivT.fx(f,mo)        = 0.0;
  FuelConsT.fx(u,f,mo)       = 0.0;
  FuelConsP.fx(f,mo)         = 0.0;
  StoDLoadF.fx(s,f,mo)       = 0.0;
);

Loop (f,
  if (fpospris(f),
    CostsPurchaseF.fx(f,mo) = 0.0;
  else
    IncomeAff.fx(f,mo) = 0.0;
  );
);

# Fiksering (betinget) af lagerbeholdning i sidste m�ned.
$OffOrder
Loop (s $OnS(s),
  if (DataSto(s,'ResetLast') NE 0, 
    bOnSto.fx(s,mo)  $(ord(mo) EQ NactiveM) = 0; 
    StoLoad.fx(s,mo) $(ord(mo) EQ NactiveM) = 0.0;
  );
);
$OnOrder

# Fiksering af RGK-produktion til nul p� ikke-aktive affaldsanlaeg.
Loop (ua $(NOT OnU(ua)), bOnRgk.fx(ua,mo) = 0.0; );

# Restriktion p� bypass.
Loop (mo, 
  if (NOT OnBypass(mo),
    Qbypass.fx(mo) = 0.0;
  );
);

#end Initialisering af variable.


# Initialisering f�r iteration af Phi-faktorer.
ConvergenceFound = FALSE;
PhiIter(phiKind,mo,iter) = 0.0;
dPhiIter(phiKind,mo,iter) = 0.0;

Phi(phiKind,mo)             = 0.2;    # Startg�t (b�r v�re positivt).
PhiIter(phiKind,mo,'iter0') = Phi(phiKind,mo);
dPhiIter(phiKind,mo,'iter0') = 0.0;

Loop (iter $(ord(iter) GE 2),
  IterNo = ord(iter) - 1;
  display "F�r SOLVE i Iteration no.", IterNo;
  
  option MIP=gurobi;    
  modelREFA.optFile = 1;
  #--- option MIP=CBC;
  #--- modelREFA.optFile = 0;
  
  option LIMROW=250, LIMCOL=250;  
  if (IterNo GE 2, 
    option LIMROW=0, LIMCOL=0;
    option SOLPRINT=OFF;
  );
  
  solve modelREFA maximizing NPV using MIP;
  
  if (modelREFA.modelStat GE 3 AND modelREFA.modelStat NE 8,
    display "Ingen l�sning fundet.";
    execute_unload "REFAmain.gdx";
    abort "Solve af model mislykkedes.";
  );
  
  # Phi opdateres p� basis af seneste optimeringsl�sning.
  QcoolTotal(mo)      = sum(uv $OnU(uv), Q.L(uv,mo));
  Qtotal(mo)          = sum(ua $OnU(ua), Q.L(ua,mo));
  EnergiTotal(mo)     = Qtotal(mo) + Pbrut.L(mo);
  FEBiogenTotal(mo)   = sum(ua $OnU(ua), FEBiogen.L(ua,mo));
  Fenergi(phiKind,mo) = [sum(ua $OnU(ua), Q.L(ua,mo)) + Pbrut.L(mo)] / eE(phiKind);
  Phi(phiKind,mo)     = ifthen(Fenergi(phiKind,mo) EQ 0.0, 0.0, FEBiogenTotal(mo) / Fenergi(phiKind,mo) );
  PhiIter(phiKind,mo,iter) = Phi(phiKind,mo);

  # Beregn afgiftssum og sammenlign med forrige iteration.
  # AffaldVarme-afgift: Qafg = Qtotal - Qk�l - 0.85 * Fbiogen
  # Till�gs-afgift for bOnRgkRabat = 0:     Qafg = Qtotal * (1 - phi85) / 1.2    
  # Till�gs-afgift for bOnRgkRabat = 1:     Qafg = [Qtotal - 0.1 * (Qtotal + Pbrut)] * (1 - phi95) / 1.2 
  # CO2-afgift     for bOnRgkRabat = 0:     Qafg = Qtotal * (1 - phi85) / 1.2   
  # CO2-afgift     for bOnRgkRabat = 1:     Qafg = [Qtotal - 0.1 * (Qtotal + Pbrut)] * (1 - phi95) / 1.2 
  # phi = Fbiogen / Fenergi;  Fenergi = (Qtotal + Pbrut) / e;  phi85 = phi(e=0.85);  phi95 = phi(e=0.95);
    
  QafgAfv(mo) = Qtotal(mo) - QcoolTotal(mo) - 0.85 * FEBiogenTotal(mo);
  QafgAtl(mo) = [(Qtotal(mo) * (1 - Phi('85',mo)) * (1 - bOnRgkRabat.L(mo)))  +  (Qtotal(mo) - 0.1 * EnergiTotal(mo) * (1 - Phi('95',mo))) * bOnRgkRabat.L(mo) ] / 1.2;
  QafgCO2(mo) = [(Qtotal(mo) * (1 - Phi('85',mo)) * (1 - bOnRgkRabat.L(mo)))  +  (Qtotal(mo) - 0.1 * EnergiTotal(mo) * (1 - Phi('95',mo))) * bOnRgkRabat.L(mo) ] / 1.2;
  
  AfgAfv(mo) = QafgAfv(mo) * TaxAfvMWh(mo);
  AfgAtl(mo) = QafgAtl(mo) * TaxAtlMWh(mo);
  AfgCO2(mo) = QafgCO2(mo) * TaxCO2AffTon(mo) * CO2ContentAff(mo);  # Uden skorstensmetoden.

  AfgiftTotal(mo)          = AfgAfv(mo) + AfgAtl(mo) + AfgCO2(mo);
  AfgiftTotalIter(mo,iter) = AfgiftTotal(mo);

  DeltaAfgift           = 2 * (sum(mo, abs(AfgiftTotalIter(mo,iter) - AfgiftTotalIter(mo,iter-1)))) / sum(mo, abs(AfgiftTotalIter(mo,iter) + AfgiftTotalIter(mo,iter-1)));
  DeltaAfgiftIter(iter) = deltaAfgift;

  # BEREGNING AF METRIK FOR KONVERGENS (D�KNINGSBIDRAG)
  # DeltaConvMetric beregnes p� m�nedsniveau som relativ �ndring for at sikre at d�rligt konvergerende m�neder vejer tungt ind i konvergensvurderingen.
  ConvMetric(mo)            = IncomeTotal.L(mo) - CostsTotal.L(mo);
  ConvMetricIter(mo,iter)   = ConvMetric(mo);
  DeltaConvMetric           = 2 * (sum(mo, abs(ConvMetricIter(mo,iter) - ConvMetricIter(mo,iter-1)))) / sum(mo, abs(ConvMetricIter(mo,iter) + ConvMetricIter(mo,iter-1))) / card(mo);
  DeltaConvMetricIter(iter) = max(tiny, DeltaConvMetric);

  # Check for oscillationer p� m�nedsbasis.
  Found = FALSE
  #--- display "Detektering af oscillation af Phi:", IterNo, Phi;
  Loop (mo,
    dPhi(phiKind)       = PhiIter(phiKind,mo,iter) - PhiIter(phiKind,mo,iter-1);
    dPhiChange(phiKind) = abs(abs(dPhi(phiKind) - abs(dPhiIter(phiKind,mo,iter-1))));

    dPhiIter(phiKind,mo,iter)       = dPhi(phiKind);
    dPhiChangeIter(phiKind,mo,iter) = dPhiChange(phiKind);

    Loop (phiKind,
      if (IterNo GE 3 AND dPhi(phiKind) GT 1E-3,  # Kun oscillation hvis Phi har �ndret sig siden forrige iteration.
        if (dPhiChange(phiKind) LE 1E-4,
          # Oscillation detekteret - just�r begge Phi-faktorer for aktuel m�ned.
          Found =  TRUE;
          Phi(phiKind,mo)          = PhiScale * (Phi(phiKind,mo) - PhiIter(phiKind,mo,iter-1));
          PhiIter(phiKind,mo,iter) = Phi(phiKind,mo);
        );
      );
    );
  );
  if (Found,
    display "Detektering af oscillation af Phi:";
  else
    display "Ingen oscillation af Phi fundet:";
  );
  
  # Stopkriterier testes.
  #--- display "Iteration p� uline�re afgiftsberegning:", IterNo, DeltaConvMetric, DeltaConvMetricTol;
  
  # Konvergens opn�et i forrige iteration - aktuelle iteration er en finpudsning.
  if (ConvergenceFound,
    display "Konvergens opn�et og finpudset", IterNo;
    break;
  );

  # Max. antal iterationer.
  if (IterNo GE NiterMax, 
    display 'Max. antal iterationer anvendt.';
    break;
  );

  if (DeltaConvMetric <= DeltaConvMetricTol, 
    display 'Konvergens opn�et. �ndring af afgiftsbetaling opfylder accepttolerancen.', IterNo, DeltaConvMetric, DeltaConvMetricTol;
    ConvergenceFound = TRUE;
    break;
    #--- Udf�r endnu en iteration, s� modelvariable bliver opdateret med seneste justering af phi.
  else
    display "Endnu ingen konvergens opn�et.";
  );
);

# ------------------------------------------------------------------------------------------------
# Efterbehandling af resultater for aktuelt scenarie.
# ------------------------------------------------------------------------------------------------

# Tilbagef�ring til NPV af penalty costs og omkostninger fra ikke-inkluderede anlaeg og braendsler samt gevinst for Ovn3-varme.
Penalty_bOnUTotal           = Penalty_bOnU * sum(mo, sum(u, bOnU.L(u,mo)));
Penalty_QRgkMissTotal       = Penalty_QRgkMiss * sum(mo, QRgkMiss.L(mo));
Penalty_AffaldsGensalgTotal = Penalty_AffaldsGensalg * sum(mo, sum(f $OnF(f), FuelResaleT.L(f,mo)));
Penalty_QInfeasTotal        = Penalty_QInfeas    * sum(dir, sum(mo, QInfeas.L(dir,mo)));
Penalty_AffTInfeasTotal     = Penalty_AffTInfeas * sum(dir, sum(mo, AffTInfeas.L(dir,mo)));
Gain_QaffTotal              = sum(ua, Gain_Qaff(ua) * sum(mo, Q.L(ua,mo)));

# NPV_Total_V er den samlede NPV med tilbagef�rte penalties.
NPV_Total_V = NPV.L + [Penalty_QInfeasTotal + Penalty_AffTInfeasTotal] 
                    + [Penalty_bOnUTotal + Penalty_QRgkMissTotal + Penalty_AffaldsGensalgTotal]
                    - [Gain_QaffTotal];

# NPV_REFA_V er REFAs andel af NPV med tilbagef�rte penalties og tilbagef�rte GSF-omkostninger.
NPV_REFA_V  = NPV_Total_V + sum(mo, CostsTotalOwner.L('gsf',mo));

#--- display Penalty_bOnUTotal, Penalty_QRgkMissTotal, NPV.L, NPV_Total_V, NPV_REFA_V;


# ------------------------------------------------------------------------------------------------
# Udskriv resultater til Excel output fil.
# ------------------------------------------------------------------------------------------------

# Tidsstempel for beregningens udfoerelse.

TimeOfWritingMasterResults = jnow;
PerStart = Schedule('dato','firstPeriod');
PerSlut  = Schedule('dato','lastPeriod');
VPO_V(uaggr,mo) = 0.0;
# Sammenfatning af aggregerede resultater.

# Scenarieresultater
Loop (mo $(NOT sameas(mo,'mo0')),
  RefaAffaldModtagelse_V(mo)               = max(tiny, sum(fa $OnF(fa), IncomeAff.L(fa,mo)));
  RefaRgkRabat_V(mo)                       = max(tiny, RgkRabat.L(mo));
  RefaElsalg_V(mo)                         = max(tiny, IncomeElec.L(mo));
  RefaVarmeSalg_V(mo)                      = max(tiny, IncomeHeat.L(mo));
  RefaTotalVarIndkomst_V(mo)               = RefaAffaldModtagelse_V(mo) + RefaRgkRabat_V(mo) + RefaElsalg_V(mo) + RefaVarmeSalg_V(mo);
  OverView('REFA-Affald-Modtagelse',mo)    = max(tiny, RefaAffaldModtagelse_V(mo) );
  OverView('REFA-RGK-Rabat',mo)            = max(tiny, RefaRgkRabat_V(mo) );
  OverView('REFA-Elsalg',mo)               = max(tiny, RefaElsalg_V(mo) );
  OverView('REFA-Varmesalg',mo)            = max(tiny, RefaVarmeSalg_V(mo) );

  RefaAnlaegsVarOmk_V(mo)                  = sum(urefa $OnU(urefa), CostsU.L(urefa,mo));
  RefaBraendselsVarOmk_V(mo)               = sum(frefa, CostsPurchaseF.L(frefa,mo));
  RefaAfgifter_V(mo)                       = TaxAFV.L(mo) + TaxATL.L(mo) + TaxCO2Aff.L(mo) + sum(frefa, TaxNOxF.L(frefa,mo));
  RefaKvoteOmk_V(mo)                       = max(tiny, CostsETS.L(mo));  # Kun REFA er kvoteomfattet.
  RefaStoCost_V(mo)                        = sum(s $OnS(s), StoCostAll.L(s,mo));
  RefaTotalVarOmk_V(mo)                    = RefaAnlaegsVarOmk_V(mo) + RefaBraendselsVarOmk_V(mo) + RefaAfgifter_V(mo) + RefaKvoteOmk_V(mo) + RefaStoCost_V(mo);
  RefaDaekningsbidrag_V(mo)                = RefaTotalVarIndkomst_V(mo) - RefaTotalVarOmk_V(mo);
  OverView('REFA-AnlaegsVarOmk',mo)        = max(tiny, RefaAnlaegsVarOmk_V(mo) );
  OverView('REFA-BraendselOmk',mo)         = max(tiny, RefaBraendselsVarOmk_V(mo) );
  OverView('REFA-Afgifter',mo)             = max(tiny, RefaAfgifter_V(mo) );
  OverView('REFA-CO2-Kvoteomk',mo)         = max(tiny, RefaKvoteOmk_V(mo) );
  OverView('REFA-Lageromkostning',mo)      = max(tiny, RefaStoCost_V(mo) );
  OverView('REFA-Total-Var-Indkomst',mo)   = max(tiny, RefaTotalVarIndkomst_V(mo) );
  OverView('REFA-Total-Var-Omkostning',mo) = max(tiny, RefaTotalVarOmk_V(mo) );
  OverView('REFA-Daekningsbidrag',mo)      = ifthen(RefaDaekningsbidrag_V(mo) EQ 0.0, tiny, RefaDaekningsbidrag_V(mo));

# TODO: Skal tilrettes �ndrede CO2-opg�relser.
  RefaCO2emission_V(mo,typeCO2)            = max(tiny, sum(frefa $OnF(frefa), CO2emisF.L(frefa,mo,typeCO2)) );
  RefaElproduktionBrutto_V(mo)             = max(tiny, Pbrut.L(mo));
  RefaElproduktionNetto_V(mo)              = max(tiny, Pnet.L(mo));
  OverView('REFA-CO2-Emission-afgift',mo)  = RefaCO2emission_V(mo,'afgift');
  OverView('REFA-CO2-Emission-kvote',mo)   = RefaCO2emission_V(mo,'kvote');
  OverView('REFA-El-produktion-Brutto',mo) = RefaElproduktionBrutto_V(mo);
  OverView('REFA-El-produktion-Netto',mo)  = RefaElproduktionNetto_V(mo);

  AffaldAvail_V(mo)     = max(tiny, sum(fa $OnF(fa), FuelBounds(fa,'max',mo)));
  AffaldConsTotal_V(mo) = max(tiny, sum(fa, sum(ua, FuelConsT.L(ua,fa,mo))));
  AffaldUudnyttet_V(mo) = max(tiny, sum(fa, FuelResaleT.L(fa,mo)));
  AffaldLagret_V(mo)    = max(tiny, sum(s, StoLoad.L(s,mo)));
  Overview('REFA-Total-Affald-Raadighed',mo) = AffaldAvail_V(mo);
  Overview('REFA-Affald-anvendt',mo)         = AffaldConsTotal_V(mo);
  Overview('REFA-Affald-Uudnyttet',mo)       = AffaldUudnyttet_V(mo);
  Overview('REFA-Affald-Lagret',mo)          = AffaldLagret_V(mo);

 
  RefaVarmeProd_V(mo)       = max(tiny, sum(uprefa $OnU(uprefa), Q.L(uprefa,mo)) );
  RefaModtrykProd_V(mo)     = max(tiny, sum(ua $OnU(ua), QAffM.L(ua,mo)) );
  RefaBypassVarme_V(mo)     = max(tiny, Qbypass.L(mo));
  RefaRgkProd_V(mo)         = max(tiny, sum(ua $OnU(ua), Qrgk.L(ua,mo)) );
  RefaRgkShare_V(mo)        = max(tiny, sum(ua $OnU(ua), Qrgk.L(ua,mo)) / sum(ua $OnU(ua), Q.L(ua,mo)) );
  RefaBortkoeletVarme_V(mo) = max(tiny, sum(uv $OnU(uv), Q.L(uv,mo)) );
  RefaVarmeLeveret_V(mo)    = RefaVarmeProd_V(mo) - RefaBortkoeletVarme_V(mo);
  OverView('REFA-Total-Varme-Produktion',mo) = RefaVarmeProd_V(mo);
  OverView('REFA-Leveret-Varme',mo)          = RefaVarmeLeveret_V(mo);
  OverView('REFA-Modtryk-Varme',mo)          = RefaModtrykProd_V(mo);
  OverView('REFA-Bypass-Varme',mo)           = RefaBypassVarme_V(mo);
  OverView('REFA-RGK-Varme',mo)              = RefaRgkProd_V(mo);
  OverView('REFA-RGK-Andel',mo)              = RefaRgkShare_V(mo);
  OverView('REFA-Bortkoelet-Varme',mo)       = RefaBortkoeletVarme_V(mo);

  GsfAnlaegsVarOmk_V(mo)                    = sum(ugsf, CostsU.L(ugsf, mo) );
  GsfBraendselsVarOmk_V(mo)                 = sum(fgsf, CostsPurchaseF.L(fgsf,mo) );
  GsfAfgifter_V(mo)                         = sum(fgsf, TaxCO2Aux.L(mo) + taxNOxF.L(fgsf,mo)) + TaxEnr.L(mo);
  GsfCO2emission_V(mo)                      = sum(fgsf, CO2emisF.L(fgsf,mo,'afgift') );
  GsfTotalVarmeProd_V(mo)                   = sum(ugsf, Q.L(ugsf,mo) );
  GsfTotalVarOmk_V(mo)                      = GsfAnlaegsVarOmk_V(mo) + GsfBraendselsVarOmk_V(mo) + GsfAfgifter_V(mo);
  OverView('GSF-AnlaegsVarOmk',mo)          = max(tiny, GsfAnlaegsVarOmk_V(mo) );
  OverView('GSF-BraendselOmk',mo)           = max(tiny, GsfBraendselsVarOmk_V(mo) );
  OverView('GSF-Afgifter',mo)               = max(tiny, GsfAfgifter_V(mo) );
  OverView('GSF-CO2-Emission',mo)           = max(tiny, GsfCO2emission_V(mo) );
  OverView('GSF-Total-Varme-Produktion',mo) = max(tiny, GsfTotalVarmeProd_V(mo) );
  OverView('GSF-Total-Var-Omkostning',mo)   = max(tiny, GsfTotalVarOmk_V(mo) );

  NsTotalVarmeProd_V(mo)                    = max(tiny, sum(uc, Q.L(uc,mo)) );
  OverView('NS-Total-Varme-Produktion',mo)  = NsTotalVarmeProd_V(mo);
  
  OverView('Virtuel-Varme-Kilde',mo)          = max(tiny, QInfeas.L('source',mo));
  OverView('Virtuel-Varme-Draen',mo)          = max(tiny, QInfeas.L('drain',mo));
  OverView('Virtuel-Affaldstonnage-Kilde',mo) = max(tiny, AffTInfeas.L('source',mo));
  OverView('Virtuel-Affaldstonnage-Draen',mo) = max(tiny, AffTInfeas.L('drain',mo));

#---  VarmeVarProdOmkTotal_V(mo) = (sum(u $OnU(u), CostsU.L(u,mo)) + sum(owner, CostsTotalF.L(owner,mo)) - IncomeTotal.L(mo)) / (sum(up, Q.L(up,mo) - sum(uv, Q.L(uv,mo))));
#---  VarmeVarProdOmkRefa_V(mo)  = (sum(urefa, CostsU.L(urefa,mo)) + CostsTotalF.L('refa',mo) - IncomeTotal.L(mo)) / (sum(uprefa, Q.L(uprefa,mo)) - sum(uv, Q.L(uv,mo)));
  VarmeVarProdOmkTotal_V(mo)  = (RefaTotalVarOmk_V(mo) - RefaTotalVarIndkomst_V(mo) + GsfTotalVarOmk_V(mo)) / Qdemand(mo);
  VarmeVarProdOmkRefa_V(mo)   = (RefaTotalVarOmk_V(mo) - RefaTotalVarIndkomst_V(mo)) / (sum(uprefa, Q.L(uprefa,mo)) - sum(uv, Q.L(uv,mo)));
  Overview('FJV-behov',mo)                      = max(tiny, Qdemand(mo));
  OverView('Total-Var-Varmeproduktions-Omk',mo) = ifthen(VarmeVarProdOmkTotal_V(mo) EQ 0.0, tiny, VarmeVarProdOmkTotal_V(mo));
  OverView('REFA-Var-Varmeproduktions-Omk',mo)  = ifthen(VarmeVarProdOmkRefa_V(mo) EQ 0.0,  tiny, VarmeVarProdOmkRefa_V(mo));


  Loop (f,
    FuelDeliv_V(f,mo) = max(tiny, FuelDelivT.L(f,mo));
    IncomeFuel_V(f,mo) = IncomeAff.L(f,mo) - CostsPurchaseF.L(f,mo);
    if (IncomeFuel_V(f,mo) EQ 0.0, IncomeFuel_V(f,mo) = tiny; );
  );
  
  FuelConsT_V(u,f,mo) = max(tiny, FuelConsT.L(u,f,mo));
  FuelConsP_V(u,f,mo) = max(tiny, FuelConsT.L(u,f,mo) * LhvMWh(f));
  
  Loop (f $(OnF(f) AND fa(f) AND fsto(f)),
    StoDLoadF_V(sa,f,mo)  = max(tiny, StoDLoadF.L(sa,f,mo));
    StoLoadF_V(sa,f,mo)   = max(tiny, StoLoadF.L(sa,f,mo));
  );

  StoLoadAll_V(s,mo) = max(tiny, StoLoad.L(s,mo));
  

  Q_V(u,mo)  = ifthen (Q.L(u,mo) EQ 0.0, tiny, Q.L(u,mo));
  Q_V(uv,mo) = -Q_V(uv,mo);  # Negation aht. afbildning i sheet Overblik.
  #--- RefaRgkProd_V(mo) = sum(ua, Qrgk.L(ua,mo));
  Loop (u $OnU(u),
    if (Q.L(u,mo) GT 0.0,
      Usage_V(u,mo) = Q.L(u,mo) / (KapNom(u) * ShareAvailU(u,mo) * Hours(mo));
    else
      Usage_V(u,mo) = tiny;
    );
    if (up(u), 
      # Realiseret br�ndv�rdi.
      tmp1 = sum(f $(OnF(f) AND u2f(u,f)), FuelConsT.L(u,f,mo));
      if (tmp1 GT 0.0, 
        LhvCons_V(u,mo) = 3.6 * sum(f $(OnF(f) AND u2f(u,f)), FuelConsT.L(u,f,mo) * LhvMWh(f)) / tmp1;
      );
      # Tonnage indfyret.
      tmp2 = ShareAvailU(u,mo) * Hours(mo);
      if (tmp2 GT 0.0, 
        FuelConsumed_V(u,mo) = sum(f $(OnF(f) AND u2f(u,f)), FuelConsT.L(u,f,mo)) / tmp2;
      );
    );
  );
      
  # VPO_V: Varmeproduktionsomkostning pr. aggregeret anl�g og m�ned.
  # Affaldsanl�g
  db = RefaAffaldModtagelse_V(mo) + RefaRgkRabat_V(mo) + RefaElsalg_V(mo)
       - sum(ua, CostsU.L(ua,mo))
       - sum(fa, CostsPurchaseF.L(fa,mo))
       - TaxAFV.L(mo) + TaxATL.L(mo) + TaxCO2Aff.L(mo) + sum(fa, TaxNOxF.L(fa,mo))
       - RefaKvoteOmk_V(mo) 
       - RefaStoCost_V(mo); 
  qdeliv = sum(ua, Q.L(ua,mo)) - sum(uv, Q.L(uv,mo));
  if (qdeliv GT 1E-8, VPO_V('Affald',mo) = -db/qdeliv; );
  
  # Fliskedel
  db = - sum(ub, CostsU.L(ub,mo))
       - sum(fb, CostsPurchaseF.L(fb,mo))
       - sum(fb, TaxNOxF.L(fb,mo));
   qdeliv = sum(ub, Q.L(ub,mo));
  if (qdeliv GT 1E-8, VPO_V('Fliskedel',mo) = -db/qdeliv; );

  # SR-kedel
  db = - sum(ur, CostsU.L(ur,mo))
       - sum(fr, CostsPurchaseF.L(fr,mo))
       - sum(fr, TaxNOxF.L(fr,mo));
   qdeliv = sum(ur, Q.L(ur,mo));
  if (qdeliv GT 1E-8, VPO_V('SR-kedel',mo) = -db/qdeliv; );
);

DataCtrl_V(labDataCtrl)     = ifthen(DataCtrl(labDataCtrl)   EQ 0.0, tiny, DataCtrl(labDataCtrl));
DataU_V(u,labDataU)         = ifthen(DataU(u,labDataU)       EQ 0.0, tiny, DataU(u,labDataU)); 
DataU_V(u,'MinLast')        = 0.0;
DataU_V(u,'KapMin')         = 0.0;
DataSto_V(s,labDataSto)     = ifthen(DataSto(s,labDataSto)   EQ 0.0, tiny, DataSto(s,labDataSto)); 
DataFuel_V(f,labDataFuel)   = ifthen(DataFuel(f,labDataFuel) EQ 0.0, tiny, DataFuel(f,labDataFuel)); 
Prognoses_V(labProgn,mo)    = ifthen(Prognoses(mo,labProgn) EQ 0.0, tiny, Prognoses(mo,labProgn));
Prognoses_V(labProgn,'mo0') = tiny;  # Sikrer udskrivning af tom kolonne i output-udgaven af Prognoses.
FuelBounds_V(f,bound,mo)    = max(tiny, FuelBounds(f,bound,mo));
FuelBounds_V(f,bound,'mo0') = 0.0;   # Sikrer at kolonne 'mo0' ikke udskrives til Excel.
FuelDeliv_V(f,'mo0')        = 0.0;   # Sikrer at kolonne 'mo0' ikke udskrives til Excel.
StoDLoadF_V(s,f,'mo0')      = 0.0;
FuelConsT_V(u,f,'mo0')      = 0.0;


VirtualUsed = VirtualUsed OR sum(dir, sum(mo, QInfeas.L(dir,mo))) GT tiny OR sum(dir, sum(mo, AffTInfeas.L(dir,mo))) GT tiny;

# Overf�rsel af aktuelt scenaries n�gletal til opsamlings-array.
#--- Scen_TimeStamp(actScen) = mod(TimeOfWritingMasterResults, 1);  # Gemmer kun tidspunktet, men ikke d�gnet.

Scen_Q(u,actScen)          = sum(mo, Q_V(u,mo));
Scen_FuelDeliv(f,actScen)  = sum(mo, FuelDeliv_V(f,mo));
Scen_IncomeFuel(f,actScen) = sum(mo, IncomeFuel_V(f,mo));

Scen_Overview('Tidsstempel',actScen) = frac(TimeOfWritingMasterResults);  # Gemmer kun tidspunktet, men ikke d�gnet.
Scen_Overview('Total-NPV',actScen) = NPV_Total_V;
Scen_Overview('REFA-NPV', actScen) = NPV_REFA_V;

Loop (topicSummable,
  Scen_Overview(topicSummable,actScen) = sum(mo, OverView(topicSummable,mo));
);
# F�lgende topic giver ikke mening som sumtal.
Scen_Overview('REFA-RGK-Andel',actScen) = 0.0;

Scen_Progn_Transpose(labProgn,actScen) = 0.0;
Loop (labPrognScen $(Scen_Progn(actScen,labPrognScen) NE NaN),  #---  AND NOT sameas(labPrognScen,'Aktiv')),
  Scen_Progn_Transpose(labPrognScen,actScen) = Scen_Progn(actScen,labPrognScen);
);


execute_unload 'REFAoutput.gdx',
TimeOfWritingMasterResults, scen, actScen,
bound, moall, mo, fkind, f, fa, fb, fc, fr, u, up, ua, ub, uc, ur, u2f, s2f, 
labDataU, labDataFuel, labScheduleRow, labScheduleCol, labProgn, taxkind, topic, typeCO2,
Scen_Overview, Scen_Q, Scen_FuelDeliv, Scen_IncomeFuel, 
Scen_Progn, Schedule, DataCtrl_V, DataU_V, DataSto_V, Prognoses_V, AvailDaysU, DataFuel_V, FuelBounds_V, 
OnU, OnF, OnM, OnS, Hours, ShareAvailU, EtaQ, KapMin, KapNom, KapRgk, KapMax, Qdemand, LhvMWh, 
Pbrut, Pnet, Qbypass, 
TaxAfvMWh, TaxAtlMWh, TaxCO2AffTon, TaxCO2peakTon,
EaffGross, QaffMmax, QrgkMax, QaffTotalMax, TaxATLMax, RgkRabatMax,
OverView, NPV_Total_V, NPV_REFA_V, Prognoses_V, FuelDeliv_V, FuelConsT_V, StoLoadF_V, StoDLoadF_V, IncomeFuel_V, Q_V, VPO_V,
PerStart, PerSlut, VirtualUsed,

RefaDaekningsbidrag_V,
RefaTotalVarIndkomst_V,
RefaAffaldModtagelse_V,
RefaRgkRabat_V,
RefaElsalg_V,

RefaTotalVarOmk_V,
RefaAnlaegsVarOmk_V,
RefaBraendselsVarOmk_V,
RefaAfgifter_V,
RefaKvoteOmk_V,
RefaStoCost_V,
RefaCO2emission_V,
RefaElproduktionBrutto_V, 
RefaElproduktionNetto_V,

AffaldConsTotal_V,
AffaldAvail_V,
AffaldUudnyttet_V,
AffaldLagret_V,

RefaVarmeProd_V,
RefaVarmeLeveret_V, 
RefaModtrykProd_V,
RefaBypassVarme_V, 
RefaRgkProd_V,
RefaRgkShare_V,
RefaBortkoeletVarme_V,
VarmeVarProdOmkTotal_V,
VarmeVarProdOmkRefa_V,
RefaLagerBeholdning_V,
StoLoadAll_V,
Usage_V,
LhvCons_V,

GsfTotalVarOmk_V,
GsfAnlaegsVarOmk_V,
GsfBraendselsVarOmk_V,
GsfAfgifter_V,
GsfCO2emission_V,
GsfTotalVarmeProd_V
;

$OnText
* NOTE on using GDXXRW to export GDX results to Excel. McCarl
* Any item to be exported must be unloaded (saved) to a gdx file using the execute_unload stmt (see above).
* 1: By default an item is assumed to be a table (2D) and the first index being the row index.
* 2: By vectors (1D) do specify cdim=0 to obtain a column vector, otherwise a row vector is obtained.
* 3: GDXXRW args options cdim and rdim DataCtrl how a multi-dim item is written to the Excel sheet:
*    a: cdim is the no. of dimensions going into columns.
*    b: rdim is the no. of dimensions going into rows.
*    c: The dimension of the item must equal cdim + rdim.
* 4: Column indices are the rightmost indices of the item (indices are set names).
* 5: The name of the item is not written as a part of export stmt eg var=<varname> rng=<sheetname>!<topleft cell> cdim=... rdim=...
* 6: When cdim=0 the range will hold no header row ie. the range should be addressed to begin one row lower than multidim. items.
* 7: Formulas cannot be written. A text starting with '=' raises a 'Parameter missing for option' error.
* See details and examples in the McCarl article "Rearranging rows and columns" in the GAMS Documentation Center.
$OffText


$onecho > REFAoutput.txt
filter=0

* OBS: Vaerdier udskrives i basale enheder, men formatteres i Excel til visning af fx. tusinder fremfor enere.

*begin Individuelle dataark

* sheet Inputs
par=DataCtrl_V            rng=Inputs!B3         cdim=0  rdim=1
text="Styringsparameter"  rng=Inputs!B2:B2
par=Schedule              rng=Inputs!B15        cdim=1  rdim=1
text="Schedule"           rng=Inputs!B15:B15
par=DataU_V               rng=Inputs!B21        cdim=1  rdim=1
text="DataU"              rng=Inputs!B21:B21
par=DataSto_V             rng=Inputs!B29        cdim=1  rdim=1
text="DataSto"            rng=Inputs!B29:B29
par=DataFuel_V            rng=Inputs!B43        cdim=1  rdim=1
text="DataFuel"           rng=Inputs!B43:B43
par=Prognoses_V           rng=Inputs!T15        cdim=1  rdim=1
text="Prognoser"          rng=Inputs!T15:T15
par=FuelBounds_V          rng=Inputs!T43        cdim=1  rdim=2
text="FuelBounds"         rng=Inputs!T43:T43

*end   Individuelle dataark

* Overview is the last sheet to be written hence becomes the actual sheet when opening Excel file.

*begin sheet Overblik
par=TimeOfWritingMasterResults      rng=Overblik!C1:C1
text="Tidsstempel"                  rng=Overblik!A1:A1
par=VirtualUsed                     rng=Overblik!B1:B1
par=PerStart                        rng=Overblik!B2:B2
par=PerSlut                         rng=Overblik!C2:C2
par=NPV_Total_V                     rng=Overblik!B3:B3
text="Total-NPV"                    rng=Overblik!A3:A3
par=NPV_REFA_V                      rng=Overblik!B4:B4
text="REFA-NPV"                     rng=Overblik!A4:A4
par=OverView                        rng=Overblik!C6          cdim=1  rdim=1
text="Overblik"                     rng=Overblik!C6:C6
par=Q_V                             rng=Overblik!C49         cdim=1  rdim=1
text="Varmem�ngder"                 rng=Overblik!A49:A49
par=FuelDeliv_V                     rng=Overblik!C57         cdim=1  rdim=1
text="Br�ndselsforbrug"             rng=Overblik!A57:A57
par=IncomeFuel_V                    rng=Overblik!C89         cdim=1  rdim=1
text="Br�ndselsindkomst"            rng=Overblik!A89:A89
par=Usage_V                         rng=Overblik!C121        cdim=1  rdim=1
text="Kapacitetsudnyttelse"         rng=Overblik!A121:A121
par=StoLoadAll_V                    rng=Overblik!C130        cdim=1 rdim=1
text="Lagerbeholdning totalt"       rng=Overblik!A130:A130   
text="Lager"                        rng=Overblik!C130:C130   
par=StoLoadF_V                      rng=Overblik!B138        cdim=1 rdim=2
text="Lagerbeh. pr fraktion"        rng=Overblik!A138:A138   
text="Lager"                        rng=Overblik!B138:B138   
text="Fraktion"                     rng=Overblik!C138:C138   
*end

$offecho

# Write the output Excel file using GDXXRW.
execute "gdxxrw.exe REFAoutput.gdx o=REFAoutput.xlsm trace=1 @REFAoutput.txt";

execute_unload "REFAmain.gdx";

$If not errorfree $exit

# ======================================================================================================================
# Python script to copy the recently saved output files.
embeddedCode Python:
  import os
  import shutil
  import datetime
  currentDate = datetime.datetime.today().strftime('%Y-%m-%d %Hh%Mm%Ss')

  #--- actIter = list(gams.get('actIter'))[0]
  #--- per  = 'per' + str(int( list(gams.get('PeriodLast'))[0] ))
  #--- scenId = str(int( list(gams.get('ScenId'))[0] ))
  #--- gams.printLog("per = " + per + ", scenId = " + scenId)

  #--- wkdir = gams.wsWorkingDir  # Does not work.
  wkdir = os.getcwd()
  #--- gams.printLog('wkdir: '+ wkdir)

  # Copy Excel file assigning it a name including current iteration, no. of periods and a timestamp.
  fpathOld = os.path.join(wkdir, r'REFAoutput.xlsm')
  fpathNew = os.path.join(wkdir, r'Output\REFAoutput (' + str(currentDate) + ').xlsm')

  shutil.copyfile(fpathOld, fpathNew)
  gams.printLog('Excel file "' + os.path.split(fpathNew)[1] + '" written to folder: ' + wkdir)

  # Copy gdx file assigning it a name including current iteration, no. of periods and a timestamp.
  fpathOld = os.path.join(wkdir, r'REFAmain.gdx')
  fpathNew = os.path.join(wkdir, r'Output\REFAmain (' + str(currentDate) + ').gdx')

  shutil.copyfile(fpathOld, fpathNew)
  gams.printLog('GDX file "' + os.path.split(fpathNew)[1] + '" written to folder: ' + wkdir)

endEmbeddedCode
# ======================================================================================================================

if (NOT RunScenarios, 
  display "Scenarier udover referencen skal ikke beregnes";
  break;
);

); # End-of-scenario Loop
# ===================================================  END SCENARIE LOOP  =============================================================

# Sammenfattende n�gletal for alle scenarier

if (RunScenarios,
  TimeOfWritingMasterResults = jnow;
  
  execute_unload 'REFAscens.gdx',
  TimeOfWritingMasterResults,
  scen, actScen,
  bound, moall, mo, fkind, f, fa, fb, fc, fr, u, up, ua, ub, uc, ur, u2f, s2f, 
  labDataU, labDataFuel, labScheduleRow, labScheduleCol, labProgn, taxkind, topic, typeCO2,
  PerStart, PerSlut, nScen, nScenActive, VirtualUsed,
  Scen_Progn, Scen_Progn_Transpose, #--- Scen_TimeStamp, 
  Scen_Overview, Scen_Q, Scen_FuelDeliv, Scen_IncomeFuel;
  
  #TODO: Udskriv til Excel-fil REFAOutputScens.xlsm 

$onecho > REFAscens.txt
filter=0

* OBS: Vaerdier udskrives i basale enheder, men formatteres i Excel til visning af fx. tusinder fremfor enere.

*begin sheet Overblik
par=TimeOfWritingMasterResults      rng=Overblik!C1:C1
par=VirtualUsed                     rng=Overblik!B1:B1
par=PerStart                        rng=Overblik!B2:B2
par=PerSlut                         rng=Overblik!C2:C2
par=Scen_Progn_Transpose            rng=Overblik!C4          cdim=1  rdim=1
par=Scen_Overview                   rng=Overblik!C14         cdim=1  rdim=1
text="N�gletal"                     rng=Overblik!C14:C14
par=Scen_Q                          rng=Overblik!C59         cdim=1  rdim=1
text="Varmem�ngder"                 rng=Overblik!C59:C59
par=Scen_FuelDeliv                  rng=Overblik!C67         cdim=1  rdim=1
text="Br�ndselsforbrug"             rng=Overblik!C67:C67
par=Scen_IncomeFuel                 rng=Overblik!C99         cdim=1  rdim=1
text="Br�ndselsindkomst"            rng=Overblik!C99:C99
*end

$offecho

# Write the output Excel file using GDXXRW.
execute "gdxxrw.exe REFAscens.gdx o=REFAscens.xlsm trace=1 @REFAscens.txt";

$If not errorfree $exit
  
# ======================================================================================================================
# Python script to copy the recently saved output files.
embeddedCode Python:
  import os
  import shutil
  import datetime
  currentDate = datetime.datetime.today().strftime('%Y-%m-%d %Hh%Mm%Ss')

  #--- actIter = list(gams.get('actIter'))[0]
  #--- per  = 'per' + str(int( list(gams.get('PeriodLast'))[0] ))
  #--- scenId = str(int( list(gams.get('ScenId'))[0] ))
  #--- gams.printLog("per = " + per + ", scenId = " + scenId)

  wkdir = os.getcwd()

  # Copy Excel file assigning it a name including current iteration, no. of periods and a timestamp.
  fpathOld = os.path.join(wkdir, r'REFAscens.xlsm')
  fpathNew = os.path.join(wkdir, r'Output\REFAscens (' + str(currentDate) + ').xlsm')

  shutil.copyfile(fpathOld, fpathNew)
  gams.printLog('Excel file "' + os.path.split(fpathNew)[1] + '" written to folder: ' + wkdir)

  # Copy gdx file assigning it a name including current iteration, no. of periods and a timestamp.
  fpathOld = os.path.join(wkdir, r'REFAscens.gdx')
  fpathNew = os.path.join(wkdir, r'Output\REFAscens (' + str(currentDate) + ').gdx')

  shutil.copyfile(fpathOld, fpathNew)
  gams.printLog('GDX file "' + os.path.split(fpathNew)[1] + '" written to folder: ' + wkdir)

endEmbeddedCode
# ======================================================================================================================
 
);

