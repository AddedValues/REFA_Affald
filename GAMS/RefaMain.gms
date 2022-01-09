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

# Shorthand for boolean constants.
Scalar FALSE 'Shorthand for false = 0 (zero)' / 0 /;
Scalar TRUE  'Shorthand for true  = 1 (one)'  / 1 /;

# Arbejdsvariable
Scalar Found      'Angiver at logisk betingelse er opfyldt';
Scalar FoundError 'Angiver at fejl er fundet';
Scalar tiny / 1E-14/;
Scalar tmp1, tmp2, tmp3;

# ------------------------------------------------------------------------------------------------
# Erklaering af sets
# ------------------------------------------------------------------------------------------------

set bound     'Bounds'         / Min, Max, Lhv, ModtPris, CO2tonton/;
set dir       'Flowretning'    / drain, source /;

#--- set mo    'Aarsmaaneder'   / jan, feb, mar, apr, maj, jun, jul, aug, sep, okt, nov, dec /;
#--- set mo    'Aarsmaaneder'   / jan /;
set moall     'Aarsmaaneder'   / mo0 * mo36 /;  # Daekker op til 3 aar. Elementet 'mo0' anvendes kun for at sikre tom kolonne i udskrivning til Excel.
set mo(moall) 'Aktive maaneder';
alias(mo,moa);

set labDataCtrl       'Styringparms'       / IncludeGSF, VirtuelVarme, RgkRabatSats, RgkAndelRabat, Varmesalgspris, SkorstensMetode /;
set labScheduleCol    'Periodeomfang'      / FirstYear, LastYear, FirstPeriod, LastPeriod /;
set labScheduleRow    'Periodeomfang'      / aar, maaned, dato /;
set labDataU          'DataU labels'       / Aktiv, Ukind, Prioritet, minLhv, kapTon, kapNom, kapRgk, kapMax, MinLast, KapMin, EtaE, EtaQ, DV /;
set labProgn          'Prognose labels'    / Aktiv, Ndage, Ovn2, Ovn3, FlisK, NS, Cooler, PeakK, Varmebehov, NSprod, ELprod, Elpris,
                                             ETS, AFV, ATL, CO2aff, ETSaff, CO2afgAff, NOxAff, NOxFlis, EnrPeak, CO2peak, NOxPeak /;
set labDataFuel       'DataFuel labels'    / Aktiv, Fkind, Lagerbar, Fri, Bortskaf, TilOvn2, TilOvn3, MinTonnage, MaxTonnage, InitSto1, InitSto2, Pris, Brandv, CO2kgGJ /;
set labDataSto        'DataSto labels'     / Aktiv, StoKind, LoadMin, LoadMax, DLoadMax, LossRate, LoadCost, DLoadCost, ResetFirst, ResetIntv, ResetLast /;  # stoKind=1 er affalds-, stoKind=2 er varmelager.
set taxkind(labProgn) 'Omkostningstyper'   / ETS, AFV, ATL, CO2aff, ETSaff, CO2afgAff, NOxAff, NOxFlis, EnrPeak, CO2peak, NOxPeak /;
set typeCO2           'CO2-Opgørelsestype' / afgift, kvote /;


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
set fa(f)         'Affaldstyper';
set fb(f)         'Biobraendsler';
set fc(f)         'Overskudsvarme';
set fr(f)         'PeakK braendsel';
set fsto(f)       'Lagerbare braendsler';
set fdis(f)       'Braendsler som skal bortskaffes';
set ffri(f)       'Braendsler med fri tonnage';
set faux(f)       'Andre braendsler end affald';
set fown(f,owner) 'Tilknytning af fuel til ejer';
set frefa(f)      'REFA braendsler';
set fgsf(f)       'GSF braendsler';
set fpospris(f)   'Braendsler med positiv pris (modtagepris)';
set fnegpris(f)   'Braendsler med negativ pris (købspris))';
set fbiogen(f)    'Biogene brændsler (uden afgifter)';

set ukind     'Anlaegstyper'   / 1 'affald', 2 'biomasse', 3 'varme', 4 'Cooler', 5 'PeakK' /;
set u         'Anlaeg'         / Ovn2, Ovn3, FlisK, NS, Cooler, PeakK /;
set up(u)     'Prod-anlaeg'    / Ovn2, Ovn3, FlisK, NS, PeakK /;
set ua(u)     'Affaldsanlaeg'  / Ovn2, Ovn3 /;
set ub(u)     'Bioanlaeg'      / FlisK /;
set uc(u)     'OV-leverance'   / NS /;
set ur(u)     'SR-kedler'      / PeakK /;
set uv(u)     'Koelere'        / Cooler /;
set uaux(u)   'Andre prod-anlaeg end affald' / FlisK, NS, PeakK /;
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


# ------------------------------------------------------------------------------------------------
# Erklaering af input parametre
# ------------------------------------------------------------------------------------------------
Scalar    Penalty_bOnU              'Penalty på bOnU'           / 00000E+5 /;
Scalar    Penalty_QRgkMiss          'Penalty på QRgkMiss'       /   20 /;      # Denne penalty må ikke være højere end tillaegsafgiften.
Scalar    Penalty_QInfeas           'Penalty på QInfeasDir'     / 5000 /;      # Denne penalty må ikke være højere end tillaegsafgiften.
Scalar    OnQInfeas                 'On/Off på virtual varme'   / 0    /;
Scalar    RgkRabatSats              'Rabatsats på ATL'          / 0.10 /;
Scalar    RgkRabatMinShare          'Taerskel for RGK rabat'    / 0.07 /;
Scalar    VarmeSalgspris            'Varmesalgspris DKK/MWhq'   / 200.0 /;
Scalar    AffaldsOmkAndel           'Affaldssiden omk.andel'    / 0.45  /;
Scalar    SkorstensMetode           '0/1 for skorstensmetode'   / 0     /;
Scalar    NactiveM                  'Antal aktive måneder';

#TODO : IncludeOwner skal indlæses fra inputfilen.
Parameter IncludeOwner(owner)       '!= 0 => Ejer smed i OBJ'   / refa 1, gsf 0 /;
Parameter IncludePlant(u);
Parameter IncludeFuel(f);

Parameter Schedule(labScheduleRow, labScheduleCol)  'Periode start/stop';
Parameter DataCtrl(labDataCtrl)     'Data for styringsparametre';
Parameter DataU(u, labDataU)        'Data for anlaeg';
Parameter DataSto(s, labDataSto)    'Lagerspecifikationer';
Parameter Prognoses(moall,labProgn) 'Data for prognoser';
Parameter DataFuel(f, labDataFuel)  'Data for drivmidler';
Parameter FuelBounds(f,bound,moall) 'Maengdegraenser for drivmidler';

$If not errorfree $exit

# Indlaesning af input parametre

$onecho > REFAinput.txt
par=DataCtrl            rng=DataCtrl!B4:C8           rdim=1 cdim=0
par=Schedule            rng=DataU!A3:E6              rdim=1 cdim=1
par=DataU               rng=DataU!A11:L17            rdim=1 cdim=1
par=DataSto             rng=DataU!N11:Y17            rdim=1 cdim=1
par=Prognoses           rng=DataU!D22:AA58           rdim=1 cdim=1
par=DataFuel            rng=DataFuel!C4:S33          rdim=1 cdim=1
par=FuelBounds          rng=DataFuel!B39:AM174       rdim=2 cdim=1
$offecho

$call "ERASE  REFAinputM.gdx"
$call "GDXXRW REFAinputM.xlsm RWait=1 Trace=3 @REFAinput.txt"

# Indlaesning fra GDX-fil genereret af GDXXRW.
# $LoadDC bruges for at sikre, at der ikke findes elementer, som ikke er gyldige for den aktuelle parameter.
# $Load udfoerer samme operation som $LoadDC, men ignorerer ugyldige elementer.
# $Load anvendes her for at tillade at indsaette linjer med beskrivende tekst.

$GDXIN REFAinputM.gdx

$LOAD   DataCtrl
$LOAD   Schedule
$LOAD   DataU
$LOAD   DataSto
$LOAD   Prognoses
$LOAD   DataFuel
$LOAD   FuelBounds

$GDXIN   # Close GDX file.
$log  Finished loading input data from GDXIN.

display DataCtrl, DataU, Schedule, Prognoses, DataFuel, FuelBounds, DataSto;

IncludeOwner('gsf') = DataCtrl('IncludeGSF');
OnQInfeas           = DataCtrl('VirtuelVarme');
RgkRabatSats        = DataCtrl('RgkRabatSats');
RgkRabatMinShare    = DataCtrl('RgkAndelRabat');
VarmeSalgspris      = DataCtrl('VarmeSalgspris');
SkorstensMetode     = DataCtrl('SkorstensMetode');

$If not errorfree $exit

# ------------------------------------------------------------------------------------------------
# Erklaering af mellemregnings og output parametre.
# ------------------------------------------------------------------------------------------------

# NEDENSTAAENDE DYNAMISKE SAET KAN IKKE BRUGES TIL ERKLAERING AF VARIABLE OG LIGNINGER, DERFOR ER DE DEAKTIVERET.
#--- # Anlaegstyper
#--- ua(u)   = DataU(u,'ukind') EQ 1;
#--- ub(u)   = DataU(u,'ukind') EQ 2;
#--- uc(u)   = DataU(u,'ukind') EQ 3;
#--- uv(u)   = DataU(u,'ukind') EQ 4;
#--- ur(u)   = DataU(u,'ukind') EQ 5;
#--- up(u)   = NOT uv(u);
#--- uaux(u) = NOT ua(u);

# Anlægsprioriteter.
Scalar dbup, dbupa;
alias(upa, up);
uprio(up) = no;
uprio2up(up,upa) = no;
loop (up $(DataU(up,'aktiv') NE 0 AND DataU(up,'prioritet') GT 0),
  dbup = ord(up);
  uprio(up) = yes;
  loop (upa $(DataU(upa,'aktiv') NE 0 AND DataU(upa,'prioritet') LT DataU(up,'prioritet') AND NOT sameas(up,upa)),
    dbupa = ord(upa);
    uprio2up(up,upa) = yes;
  );
);
display uprio, uprio2up;

# Braendselstyper.
fa(f) = DataFuel(f,'fkind') EQ 1;
fb(f) = DataFuel(f,'fkind') EQ 2;
fc(f) = DataFuel(f,'fkind') EQ 3;
fr(f) = DataFuel(f,'fkind') EQ 4;

u2f(u,f)   = no;
u2f(ub,fb) = yes;
u2f(uc,fc) = yes;
u2f(ur,fr) = yes;

# Brugergivne restriktioner på kombinationer af affaldsanlæg og brændselsfraktioner.
singleton set ufparm(u,f);
ufparm(u,f) = no;

loop (fa, 
  u2f('Ovn2',fa) = DataFuel(fa,'TilOvn2') NE 0;
  u2f('Ovn3',fa) = DataFuel(fa,'TilOvn3') NE 0;
);

# Undertyper af brændsler:
# fsto: Brændsler, som må lagres (bemærk af tømning af lagre er en særskilt restriktion)
# fdis: Brændsler, som skal modtages og forbrændes hhv. om muligt lagres. 
# ffri: Brændsler, hvor den øvre grænse aftagemængde er en optimeringsvariabel.
# faux: Brændsler, som ikke er affaldsbrændsler.

fsto(f) = DataFuel(f,'lagerbar') NE 0;
fdis(f) = DataFuel(f,'bortskaf') NE 0;
ffri(f) = DataFuel(f,'fri') NE 0 AND fa(f);
faux(f) = NOT fa(f);

# Identifikation af lagertyper.
sa(s) = DataSto(s,'stoKind') EQ 1;
sq(s) = DataSto(s,'stoKind') EQ 2;

# Tilknytning af affaldsfraktioner til lagre.
# Brugergivne restriktioner på kombinationer af lagre og brændselsfraktioner.
singleton set sfparm(s,f);
sfparm(s,f) = no;

s2f(s,f)   = no;
s2f(sa,fa) = DataFuel(fa,'lagerbar') AND DataSto(sa,'aktiv');

# Brugergivet tilknytning af lagre til affaldsfraktioner kræver oprettelse af nye elementer i labDataFuel.
loop (fa, 
  loop (sa,
    loop (labDataFuel $sameas(sa,labDataFuel),
      tmp1 = DataFuel(fa,labDataFuel);
      # En negativ værdi DataFuel(fa,labDataFuel) angiver, at lageret ikke kan opbevare brændslet fa.
      s2f(sa,fa) = s2f(sa,fa) AND (tmp1 GE 0);
    );
  );
);


# OBS: Tilknytning af braendsel til ejer underforstaar eksklusivitet.
fown(f,owner)           = no;
fown(fa,        'refa') = yes;
fown('NSvarme', 'refa') = yes;
fown('flis',    'refa') = yes;
fown('peakfuel','gsf')  = yes;

frefa(f)         = no;
frefa(fa)        = yes;
frefa('flis')    = yes;
frefa('NSvarme') = yes;

fgsf(f)          = no;
fgsf('peakfuel') = yes;

IncludePlant(urefa) = IncludeOwner('refa');
IncludePlant('NS')  = IncludeOwner('refa');

IncludeFuel(frefa)  = IncludeOwner('refa');
IncludeFuel(fgsf)   = IncludeOwner('gsf');

display f, fa, fb, fc, fr, fsto, fdis, ffri, u2f, IncludeOwner, IncludePlant, IncludeFuel;


Parameter OnU(u)               'Angiver om anlaeg er til raadighed';
Parameter OnF(f)               'Angiver om drivmiddel er til raadighed';
Parameter OnS(s)               'Angiver om lager er til raadighed';
Parameter OnM(moall)           'Angiver om en given maaned er aktiv';
Parameter Hours(moall)         'Antal timer i maaned';
Parameter AvailDaysU(moall,u)  'Antal raadige dage';
Parameter ShareAvailU(u,moall) 'Andel af fuld raadighed';
Parameter EtaQ(u)              'Varmevirkningsgrad';
Parameter EtaRgk(u)            'Varmevirkningsgrad';

OnU(u)       = DataU(u,'aktiv');
OnF(f)       = DataFuel(f,'aktiv');
Ons(s)       = DataSto(s,'aktiv');
OnM(moall)   = Prognoses(moall,'aktiv');
Hours(moall) = 24 * Prognoses(moall,'ndage');
EtaQ(u)      = DataU(u,'etaq');
EtaRgk(u)    = DataU(u,'KapRgk') / DataU(u,'KapNom') * EtaQ(u);

# Initialisering af aktive perioder (maaneder).
mo(moall) = no;
mo(moall) = OnM(moall);
NactiveM  = sum(moall, OnM(moall));

loop (u $OnU(u),
  loop (labProgn $sameas(u,labProgn),
    AvailDaysU(mo,u)  = Prognoses(mo,labProgn) $(OnU(u) AND OnM(mo));
    ShareAvailU(u,mo) = max(0.0, min(1.0, AvailDaysU(mo,u) / Prognoses(mo,'Ndage') ));
  );
);

display mo, OnU, OnF, OnM, Hours, AvailDaysU, ShareAvailU, EtaQ;

# Rimelighedskontrol af inputtabeller.
loop (labDataU $(NOT sameas(labDataU,'KapMin') AND NOT sameas(labDataU,'MinLast')),
  tmp1 = sum(u, DataU(u,labDataU));
  tmp2 = ord(labDataU);
  if (tmp1 EQ 0, 
    display tmp2;
    abort "ERROR: Mindst én kolonne (se tmp2) i DataU summer til nul.";
  );
);

loop (labDataSto $(NOT sameas(labDataSto,'Aktiv') AND NOT sameas(labDataSto,'LoadMin') AND NOT sameas(labDataSto,'LossRate')),
  tmp1 = sum(s, DataSto(s,labDataSto));
  tmp2 = ord(labDataSto);
  if (tmp1 EQ 0, 
    display tmp2;
    abort "ERROR: Mindst én kolonne (se tmp2) i DataSto summer til nul.";
  );
);

singleton set labPrognSingle(labProgn);
$OffOrder
loop (labProgn,
  labPrognSingle(labProgn) = yes;
  tmp1 = sum(moall, Prognoses(moall,labProgn));
  if (tmp1 EQ 0, 
    display labPrognSingle;
    abort "ERROR: Mindst én kolonne (se labPrognSingle) i Prognoses summer til nul.";
  );
);
$OnOrder

loop (labDataFuel,
  tmp1 = sum(f, DataFuel(f,labDataFuel));
  tmp2 = ord(labDataFuel);
  if (tmp1 EQ 0, 
    display tmp2;
    abort "ERROR: Mindst én kolonne (se tmp2) i DataFuel summer til nul.";
  );
);

$OffOrder
loop (bound $(sameas(bound,'max')), 
  tmp3 = ord(bound);
  loop (fa $OnF(fa),
    tmp1 = sum(moall, FuelBounds(fa,bound,moall));
    tmp2 = ord(fa);
    if (tmp1 EQ 0, 
      display tmp3, tmp2;
      abort "ERROR: Mindst én række (se bound=tmp3, fa=tmp2) i FuelBounds summer til nul.";
    );
  );
);
$OnOrder

# Produktionsanlæg og kølere.
Parameter MinLhvMWh(u)   'Mindste braendvaerdi affaldsanlaeg GJ/ton';
Parameter KapTon(u)      'Stoerste indfyringskapacitet ton/h';
Parameter KapMin(u)      'Mindste modtrykslast MWq';
Parameter KapNom(u)      'Stoerste modtrykskapacitet MWq';
Parameter KapMax(u)      'Stoerste samlede varmekapacitet MWq';
Parameter KapRgk(u)      'RGK kapacitet MWq';
MinLhvMWh(ua) = DataU(ua,'MinLhv') / 3.6;
KapTon(ua)    = DataU(ua,'kapTon');
KapMin(u)     = DataU(u, 'kapMin');
KapRgk(ua)    = DataU(ua,'kapRgk');
KapNom(u)     = DataU(u, 'KapNom');
KapMax(u)     = KapNom(u) + KapRgk(u);
display MinLhvMWh, KapTon, KapMin, KapNom, KapRgk, KapMax ;

# Lagre. Parametre gøres alment periodeafhængige, da det giver max. fleksiblitet ift. scenarie-specifikation.
Parameter StoLoadInitF(s,f)          'Initial lagerbeholdning for hvert brændsel';
Parameter StoLoadMin(s,moall)        'Min. lagerbeholdning';
Parameter StoLoadMax(s,moall)        'Max. lagerbeholdning';
Parameter StoDLoadMax(s,moall)       'Max. lagerændring i periode';
Parameter StoLoadCostRate(s,moall)   'Omkostning for opbevaring';
Parameter StoDLoadCostRate(s,moall)  'Omkostning for lagerændring';
Parameter StoLossRate(s,moall)       'Max. lagertab ift. forrige periodes beholdning';
Parameter StoFirstReset(s)           'Antal initielle perioder som omslutter første nulstiling af lagerstand';
Parameter StoIntvReset(s)            'Antal perioder som omslutter første nulstiling af lagerstand, efter første nulstilling';

loop (fa, 
  StoLoadInitF('sto1',fa) = DataFuel(fa,'InitSto1');      
  StoLoadInitF('sto2',fa) = DataFuel(fa,'InitSto2');      
);

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
Parameter IncomeElec(moall)             'El-indkomst [DKK]';
Parameter MinTonnageYear(f)             'Braendselstonnage min aarsniveau [ton/aar]';
Parameter MaxTonnageYear(f)             'Braendselstonnage max aarsniveau [ton/aar]';
Parameter LhvMWh(f)                     'Braendvaerdi [MWf]';
Parameter CO2potenTon(f,typeCO2,moall)  'CO2-emission [ton/ton]';
Parameter Qdemand(moall)                'FJV-behov';
Parameter PowerProd(moall)              'Elproduktion MWhe';
Parameter PowerPrice(moall)             'El-pris DKK/MWhe';
Parameter TaxAfvMWh(moall)              'Affaldsvarmeafgift [DKK/MWhq]';
Parameter TaxAtlMWh(moall)              'Affaldstillaegsafgift [DKK/MWhf]';
Parameter TaxEtsTon(moall)              'CO2 Kvotepris [DKK/tom]';
Parameter TaxCO2AffTon(moall)           'CO2 afgift affald [DKK/tonCO2]';
Parameter TaxNOxAffTon(moall)           'NOx afgift affald [DKK/tonCO2]';
Parameter TaxNOxFlisTon(moall)          'NOx afgift flis [DKK/tom]';
Parameter TaxEnrPeakTon(moall)          'Energiafgift SR-kedler [DKK/tom]';
Parameter TaxCO2peakTon(moall)          'CO2 afgift SR-kedler [DKK/tom]';
Parameter TaxNOxPeakTon(moall)          'NOx afgift SR-kedler [DKK/tom]';

fpospris(f)       = yes;
fpospris(f)       = DataFuel(f,'pris') GE 0.0;
fnegpris(f)       = NOT fpospris(f);
fbiogen(f)        = fa(f) AND (DataFuel(f,'CO2kgGJ') EQ 0);

MinTonnageYear(f) = DataFuel(f,'minTonnage');
MaxTonnageYear(f) = DataFuel(f,'maxTonnage');
LhvMWh(f)         = DataFuel(f,'brandv') / 3.6;

# Emissionsopgørelsen for affald er som udgangspunkt efter skorstensmetoden, hvor CO2-indholdet af  hver fraktion er kendt.
# Men uden skorstensmetoden anvendes i stedet for SKATs emissionssatser, som desuden er forskellige efter om det er CO2-afgift eller CO2-kvoteforbruget, som skal opgøres !!!
CO2potenTon(f,typeCO2,mo) = DataFuel(f,'brandv') * DataFuel(f,'CO2kgGJ') / 1000;  # ton CO2 / ton brændsel.
if (NOT SkorstensMetode,
  CO2potenTon(fa,typeCO2,mo) = DataFuel(fa,'brandv') * [Prognoses(mo,'CO2aff') $sameas(typeCO2,'afgift') + Prognoses(mo,'ETSaff') $sameas(typeCO2,'kvote')] / 1000;
);

Qdemand(mo)       = Prognoses(mo,'varmebehov');
PowerProd(mo)     = Prognoses(mo,'ELprod');
PowerPrice(mo)    = Prognoses(mo,'ELpris');
IncomeElec(mo)    = PowerProd(mo) * PowerPrice(mo) $OnU('Ovn3');
TaxAfvMWh(mo)     = Prognoses(mo,'afv') * 3.6;
TaxAtlMWh(mo)     = Prognoses(mo,'atl') * 3.6;
TaxEtsTon(mo)     = Prognoses(mo,'ets');
TaxCO2AffTon(mo)  = Prognoses(mo,'CO2afgAff');
TaxNOxAffTon(mo)  = Prognoses(mo,'NOxAff');
TaxNOxFlisTon(mo) = Prognoses(mo,'NOxFlis') * DataFuel('flis','brandv');
TaxEnrPeakTon(mo) = Prognoses(mo,'EnrPeak') * DataFuel('peakfuel','brandv');
TaxCO2peakTon(mo) = Prognoses(mo,'CO2peak');
TaxNOxPeakTon(mo) = Prognoses(mo,'NOxPeak');
display MinTonnageYear, MaxTonnageYear, LhvMWh, Qdemand, PowerProd, PowerPrice, IncomeElec, TaxAfvMWh, TaxAtlMWh, TaxEtsTon, TaxCO2AffTon, TaxCO2peakTon;

# Special-haandtering af oevre graense for Nordic Sugar varme.
FuelBounds('NSvarme','max',moall) = Prognoses(moall,'NS');

# EaffGross skal være mininum af energiindhold af rådige mængder affald hhv. affaldsanlæggets fuldlastkapacitet.
Parameter EaffGross(moall)     'Max energiproduktion for affaldsanlaeg MWh';
Parameter QaffMmax(ua,moall)   'Max. modtryksvarme fra affaldsanlæg';
Parameter QrgkMax(ua,moall)    'Max. RGK-varme fra affaldsanlæg';
Parameter QaffTotalMax(moall)  'Max. total varme fra affaldsanlæg';
QaffMmax(ua,moall)  = min(ShareAvailU(ua,moall) * Hours(moall) * KapNom(ua), [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelBounds(fa,'max',moall) * EtaQ(ua) * LhvMWh(fa))]) $OnU(ua);
QrgkMax(ua,moall)   = KapRgk(ua) / KapNom(ua) * QaffMmax(ua,moall);
QaffTotalMax(moall) = sum(ua $OnU(ua), ShareAvailU(ua,moall) * (QaffMmax(ua,moall) + QrgkMax(ua,moall)) );
EaffGross(moall)    = QaffTotalMax(moall) + PowerProd(moall);
display QaffMmax, QrgkMax, QaffTotalMax, EaffGross;

Parameter TaxATLMax(moall) 'Oevre graense for ATL';
Parameter RgkRabatMax(moall) 'Oevre graense for ATL rabat';
Parameter QRgkMissMax     'Oevre graense for QRgkMiss';
TaxATLMax(mo) = sum(ua $OnU(ua), ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua)) * TaxAtlMWh(mo);
RgkRabatMax(mo) = RgkRabatSats * TaxATLMax(mo);
QRgkMissMax = 2 * RgkRabatMinShare * sum(ua $OnU(ua), 31 * 24 * KapNom(ua));  # Faktoren 2 er en sikkerhedsfaktor mod inffeasibilitet.
display TaxATLMax, RgkRabatMax, QRgkMissMax;

$If not errorfree $exit

# ------------------------------------------------------------------------------------------------
# Erklaering af variable.
# ------------------------------------------------------------------------------------------------
Free     variable NPV                         'Nutidsvaerdi af affaldsdisponering';

Binary   variable bOnU(u,moall)               'Anlaeg on-off';
Binary   variable bOnRgk(ua,moall)            'Affaldsanlaeg RGK on-off';
Binary   variable bOnRgkRabat(moall)          'Indikator for om der i given kan opnaas RGK rabat';
Binary   variable bOnSto(s,moall)             'Indikator for om et lager bruges i given maaned ';

Positive variable FuelCons(u,f,moall)         'Drivmiddel forbrug på hvert anlaeg';
Positive variable FuelDeliv(f,moall)          'Drivmiddel leverance på hvert anlaeg';
Positive variable FuelDelivFreeSum(f)         'Samlet braendselsmængde frie fraktioner';

Free variable StoDLoadF(s,f,moall)             'Lagerført brændsel (pos. til lager)';

Positive variable StoCostAll(s,moall)         'Samlet lageromkostning';
Positive variable StoCostLoad(s,moall)        'Lageromkostning på beholdning';
Positive variable StoCostDLoad(s,moall)       'Transportomk. til/fra lagre';
Positive variable StoLoad(s,moall)            'Aktuel lagerbeholdning';
Positive variable StoLoss(s,moall)            'Aktuelt lagertab';
Free     variable StoDLoad(s,moall)           'Aktuel lagerændring positivt indgående i lager';
Positive variable StoDLoadAbs(s,moall)        'Absolut værdi af StoDLoad';
Positive variable StoLoadF(s,f,moall)         'Lagerbeholdning af givet brændsel på givet lager';

Positive variable Q(u,moall)                  'Grundlast MWq';
Positive variable QaffM(ua,moall)             'Modtryksvarme på affaldsanlaeg MWq';
Positive variable Qrgk(u,moall)               'RGK produktion MWq';
Positive variable Qafv(moall)                 'Varme pålagt affaldvarmeafgift';
Positive variable QRgkMiss(moall)             'Slack variabel til beregning om RGK-rabat kan opnaas';

Positive variable FEBiogen(u,moall)           'Indfyret biogen affaldsenergi [GJ]';
Positive variable FuelHeatAff(moall)          'Afgiftspligtigt affald medgået til varmeproduktion';
Positive variable QBiogen(u,moall)            'Biogen affaldsvarme [GJ]';

Positive variable IncomeTotal(moall)          'Indkomst total';
Positive variable IncomeHeat(moall)           'Indkomnst for varmesalg til GSF';
Positive variable IncomeAff(f,moall)          'Indkomnst for affaldsmodtagelse DKK';
Positive variable RgkRabat(moall)             'RGK rabat på tillaegsafgift';
Positive variable CostsU(u,moall)             'Omkostninger anlægsdrift DKK';
Positive variable CostsTotalF(owner, moall)   'Omkostninger Total på drivmidler DKK';
Positive variable CostsPurchaseF(f,moall)     'Omkostninger til braendselsindkoeb DKK';

Positive variable TaxAFV(moall)               'Omkostninger til affaldvarmeafgift DKK';
Positive variable TaxATL(moall)               'Omkostninger til affaldstillaegsafgift DKK';
Positive variable TaxCO2(moall)               'Omkostninger til CO2-afgift DKK';
Positive variable TaxCO2F(f,moall)            'Omkostninger til CO2-afgift fordelt på braendselstype DKK';
Positive variable TaxNOxF(f,moall)            'Omkostninger til NOx-afgift fordelt på braendselstype DKK';
Positive variable TaxEnr(moall)               'Energiafgift (gaelder kun fossiltfyrede anlaeg)';

Positive variable CostsETS(moall)             'Omkostninger til CO2-kvoter DKK';
Positive variable CO2emis(f,moall,typeCO2)    'CO2-emission fordelt på type';
Positive variable TotalAffEProd(moall)        'Samlet energiproduktion affaldsanlaeg';

Positive variable QInfeasDir(dir,moall)       'Virtual varmedraen og -kilde [MWhq]';

# @@@@@@@@@@@@@@@@@@@@@@@@  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG
IncomeTotal.up(moall) = 1E+8;
IncomeAff.up(f,moall) = 1E+8;
RgkRabat.up(moall)    = 1E+8;

# @@@@@@@@@@@@@@@@@@@@@@@@  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG


#--- # Initial lagerbeholdning.  DISABLED: Håndteres nu i equation ZQ_StoDLoadFMin.
#--- $OffOrder
#--- StoLoadF.fx(sa,fa,mo-1) $(ord(mo) EQ 1) = StoLoadInitF(sa,fa);
#--- $OnOrder

# Fiksering af ikke-forbundne anlæg+drivmidler, samt af ikke-aktive anlaeg og ikke-aktive drivmidler.
loop (u $(NOT OnU(u)),
  bOnU.fx(u,mo)         = 0.0;
  Q.fx(u,mo)            = 0.0;
  CostsU.fx(u,mo)       = 0.0;
  FuelCons.fx(u,f,mo)   = 0.0;
);

loop (s $(NOT OnS(s)),
  bOnSto.fx(s,mo)      = 0.0;
  StoLoad.fx(s,mo)     = 0.0;
  StoLoss.fx(s,mo)     = 0.0;
  StoDLoad.fx(s,mo)    = 0.0;
  StoDLoadAbs.fx(s,mo) = 0.0;
  StoCostAll.fx(s,mo)  = 0.0;
  StoDLoadF.fx(s,f,mo)  = 0.0;
);

loop (f $(NOT OnF(f)),
  CostsPurchaseF.fx(f,mo)    = 0.0;
  IncomeAff.fx(f,mo)         = 0.0;
  CO2emis.fx(f,mo,typeCO2)   = 0.0;
  FuelDeliv.fx(f,mo)         = 0.0;
  FuelCons.fx(u,f,mo)        = 0.0;
  StoDLoadF.fx(s,f,mo)       = 0.0;
);

loop (f,
  if (fpospris(f),
    CostsPurchaseF.fx(f,mo) = 0.0;
  else
    IncomeAff.fx(f,mo) = 0.0;
  );
);

# Fiksering (betinget) af lagerbeholdning i sidste måned.
$OffOrder
loop (s $OnS(s),
  if (DataSto(s,'ResetLast') NE 0, 
    bOnSto.fx(s,mo)  $(ord(mo) EQ NactiveM) = 0; 
    StoLoad.fx(s,mo) $(ord(mo) EQ NactiveM) = 0.0;
  );
);
$OnOrder

# Fiksering af RGK-produktion til nul på ikke-aktive affaldsanlaeg.
loop (ua $(NOT OnU(ua)), bOnRgk.fx(ua,mo) = 0.0; );

# ------------------------------------------------------------------------------------------------
# Erklaering af ligninger.
# RGK kan moduleres kontinuert: RGK deaktiveres hvis Qdemand < Qmodtryk
# ------------------------------------------------------------------------------------------------
# Fordeling af omkostninger mellem affalds- og varmesiden:
# * AffaldsOmkAndel er andelen, som affaldssiden skal bære.
# * Til affaldssiden 100 pct: Kvoteomkostning
# * Til fordeling: Alle afgifter
# ------------------------------------------------------------------------------------------------

Equation  ZQ_Obj                         'Objective';
Equation  ZQ_IncomeTotal(moall)          'Indkomst Total';
Equation  ZQ_IncomeHeat(moall)           'Indkomst Varmesalg til GSF';
Equation  ZQ_IncomeAff(f,moall)          'Indkomst på affaldsfraktioner';
Equation  ZQ_CostsU(u,moall)             'Omkostninger på anlaeg';
Equation  ZQ_CostsTotalF(owner,moall)    'Omkostninger totalt på drivmidler';
Equation  ZQ_CostsPurchaseF(f,moall)     'Omkostninger til køb af affald fordelt på affaldstyper';
Equation  ZQ_TaxAFV(moall)               'Affaldsvarmeafgift DKK';
Equation  ZQ_TaxATL(moall)               'Affaldstillaegsafgift foer evt. rabat DKK';

Equation  ZQ_TaxNOxF(f,moall)            'NOx-afgift på brændsler';
Equation  ZQ_TaxEnr(moall)               'Energiafgift på fossil varme';

Equation  ZQ_CostsETS(moall)             'CO2-kvoteomkostning DKK';
Equation  ZQ_TaxCO2(moall)               'CO2-afgift DKK';
Equation  ZQ_TaxCO2F(f,moall)            'CO2-afgift fordelt på braendselstyper DKK';
Equation  ZQ_Qafv(moall)                 'Varme hvoraf der skal svares AFV [MWhq]';
Equation  ZQ_CO2emis(f,moall,typeCO2)    'CO2-maengde hvoraf der skal svares afgift hhv. ETS [ton]';
Equation  ZQ_PrioUp(up,up,moall)         'Prioritet af uprio over visse up anlaeg';


# OBS: GSF-omkostninger skal medtages i Obj for at sikre at varme leveres fra REFAs anlæg.

ZQ_Obj  ..  NPV  =E=  sum(mo,
                         IncomeTotal(mo)
                         - [
                              sum(u $OnU(u), CostsU(u,mo))
                            + sum(s $OnS(s), StoCostAll(s,mo))
                            + sum(f $OnF(f), CostsPurchaseF(f,mo) + TaxCO2F(f,mo) + TaxNOxF(f,mo))
                            + (TaxAFV(mo) + TaxATL(mo) + CostsETS(mo) + TaxEnr(mo))
                            + Penalty_bOnU * sum(u $OnU(u), bOnU(u,mo))
                            + Penalty_QRgkMiss * QRgkMiss(mo)
                            + [Penalty_QInfeas * sum(dir, QInfeasDir(dir,mo))] $OnQInfeas
                           ] );

ZQ_IncomeTotal(mo)   .. IncomeTotal(mo)   =E=  sum(fa $OnF(fa), IncomeAff(fa,mo)) + RgkRabat(mo) + IncomeElec(mo) + IncomeHeat(mo);

ZQ_IncomeHeat(mo)   ..  IncomeHeat(mo)    =E=  VarmeSalgspris * sum(u $(OnU(u) AND up(u) AND urefa(u)), Q(u,mo));

#--- ZQ_IncomeAff(fa,mo)  .. IncomeAff(fa,mo)  =E=  sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelDeliv(ua,fa,mo) * DataFuel(fa,'pris')) $(OnF(fa) AND fpospris(fa));
ZQ_IncomeAff(fa,mo)  .. IncomeAff(fa,mo)  =E=  FuelDeliv(fa,mo) * DataFuel(fa,'pris') $(OnF(fa) AND fpospris(fa));

ZQ_CostsU(u,mo)      .. CostsU(u,mo)      =E=  Q(u,mo) * DataU(u,'dv') $OnU(u);

# SKAT har i 2010 kommunikeret (Røggasreglen), at tillægsafgiften betales af den totale producerede varme, og ikke af den indfyrede energi, da elproduktion ikke må beskattes (jf. EU).
# Â¤Â¤Â¤Â¤Â¤Â¤Â¤Â¤ TODO Tillægsafgiftsberegningen skal korrigeres, så den matcher Kulafgiftsloven Â§ 5.
# Â¤Â¤Â¤Â¤Â¤Â¤Â¤Â¤      Det gælder beregning af faktisk energiindhold (som er KV-afhængigt) og hensyntagen til andre brændsler (biogene).

#TODO Affaldvarmeafgiften skal betales af varmesiden, og skal derfor ikke indgaa i en isoleret optimering for affaldssiden.
ZQ_CostsTotalF(owner,mo)   .. CostsTotalF(owner,mo) =E=
                                 sum(f $(OnF(f) AND fown(f,owner) AND fnegpris(f)), CostsPurchaseF(f,mo))
                                 + sum(f $(OnF(f) AND fown(f,owner)), TaxCO2F(f,mo) + TaxNOxF(f,mo))
                                 + TaxEnr(mo) $sameas(owner,'gsf')
                                 + (TaxAFV(mo) + TaxATL(mo) + CostsETS(mo)) $sameas(owner,'refa');


#--- ZQ_CostsPurchaseF(f,mo) $(OnF(f) AND fnegpris(f)) .. CostsPurchaseF(f,mo)  =E=  sum(u $(OnU(u) AND u2f(u,f)), FuelDeliv(u,f,mo) ) * (-DataFuel(f,'pris'));
ZQ_CostsPurchaseF(f,mo) $(OnF(f) AND fnegpris(f)) .. CostsPurchaseF(f,mo)  =E=  FuelDeliv(f,mo) * (-DataFuel(f,'pris'));

#TODO Afgiftsberegninger for affaldsvarme-, tillægs- og CO2-afgifter skal korrigeres jf. SKAT's anvisninger.

ZQ_TaxAFV(mo)              .. TaxAFV(mo)     =E=  Qafv(mo) * TaxAfvMWh(mo);
ZQ_TaxATL(mo)              .. TaxATL(mo)     =E=  sum(ua $OnU(ua), FuelHeatAff(mo)) * TaxAtlMWh(mo);

ZQ_TaxNOxF(f,mo) $OnF(f)   .. TaxNOxF(f,mo)  =E=  sum(ua $OnU(ua), FuelCons(ua,f,mo)) * TaxNOxAffTon(mo)  $fa(f)
                                                + sum(ub $OnU(ub), FuelCons(ub,f,mo)) * TaxNOxFlisTon(mo) $fb(f)
                                                + sum(ur $OnU(ur), FuelCons(ur,f,mo)) * TaxNOxPeakTon(mo) $fr(f);
ZQ_TaxEnr(mo)              .. TaxEnr(mo)     =E=  sum(ur $OnU(ur), FuelCons(ur,'peakfuel',mo)) * TaxEnrPeakTon(mo);

ZQ_TaxCO2(mo)              .. TaxCO2(mo)     =E=  sum(f $OnF(f), TaxCO2F(f,mo));
ZQ_TaxCO2F(f,mo) $OnF(f)   .. TaxCO2F(f,mo)  =E=  sum(ua $(OnU(ua) AND u2f(ua,f)), FuelCons(ua,f,mo)) * TaxCO2AffTon(mo) $fa(f)
                                                + sum(ur $(OnU(ur) AND u2f(ur,f)), FuelCons(ur,f,mo)) * TaxCO2peakTon(mo) $fr(f);
ZQ_CostsETS(mo)            .. CostsETS(mo)   =E=  sum(fa $OnF(fa), CO2emis(fa,mo,'kvote')) * TaxEtsTon(mo);  # Kun affaldsanlægget er kvoteomfattet.

ZQ_Qafv(mo)                .. Qafv(mo)       =E=  sum(ua $OnU(ua), Q(ua,mo)) - sum(uv $OnU(uv), Q(uv,mo));   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.

#--- ZQ_CO2emis(f,mo) $OnF(f)   .. CO2emis(f,mo)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelCons(up,f,mo)) * CO2potenTon(f);
ZQ_CO2emis(f,mo,typeCO2) $OnF(f)   .. CO2emis(f,mo,typeCO2)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelCons(up,f,mo)) * CO2potenTon(f,typeCO2,mo);

ZQ_PrioUp(uprio,up,mo) $(OnU(uprio) AND OnU(up) AND AvailDaysU(mo,uprio) AND AvailDaysU(mo,up)) ..  bOnU(up,mo)  =L=  bOnU(uprio,mo);

# Beregning af afgiftspligtigt affald.
# Opgørelse af biogen affaldsmængde for hver ovn-linje.
Equation ZQ_FEBiogen(u,moall);
Equation ZQ_QBiogen(u,moall);
Equation ZQ_FuelHeatAff(moall);

ZQ_FEBiogen(ua,mo) .. FEBiogen(ua,mo)  =E=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelCons(ua,fa,mo) * LhvMWh(fa) $(DataFuel(fa,'CO2kgGJ') EQ 0) );
ZQ_QBiogen(ua,mo)  .. QBiogen(ua,mo)   =E=  EtaQ(ua) * FEBiogen(ua,mo);
ZQ_FuelHeatAff(mo) .. FuelHeatAff(mo)  =E=  sum(ua $OnU(ua), Q(ua,mo)) - PowerProd(mo);

# Beregning af varme, hvoraf der skal betales affaldvarmeafgift.
#--- ZQ_Qafv(mo)         ..  Qafv(mo)  =E=  sum(ua $OnU(ua), Q(ua,mo) - QBiogen(ua,mo)) - sum(uv $OnU(uv), Q(uv,mo));   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.

#TODO Beregning herunder skal korrigeres - brændsel til elproduktion samt biogent skal undtages.


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

ZQ_TotalAffEprod(mo)  ..  TotalAffEProd(mo)  =E=  PowerProd(mo) + sum(ua $OnU(ua), Q(ua,mo));       # Samlet energioutput fra affaldsanlæg. Bruges til beregning af RGK-rabat.
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

#begin Varmebalancer
Equation  ZQ_Qdemand(moall)              'Opfyldelse af fjv-behov';
Equation  ZQ_Qaff(ua,moall)              'Samlet varmeprod. affaldsanlaeg';
Equation  ZQ_QaffM(ua,moall)             'Samlet modtryks-varmeprod. affaldsanlaeg';
Equation  ZQ_Qrgk(ua,moall)              'RGK produktion på affaldsanlaeg';
Equation  ZQ_QrgkMax(ua,moall)           'RGK produktion oevre graense';
Equation  ZQ_Qaux(u,moall)               'Samlet varmeprod. oevrige anlaeg end affald';
Equation  ZQ_QaffMmax(ua,moall)          'Max. modtryksvarmeproduktion';
Equation  ZQ_CoolMax(moall)              'Loft over bortkoeling';
Equation  ZQ_Qmin(u,moall)               'Sikring af nedre graense på varmeproduktion';
Equation  ZQ_QMax(u,moall)               'Aktiv status begraenset af total raadighed';
Equation  ZQ_bOnRgk(ua,moall)            'Angiver om RGK er aktiv';

ZQ_Qdemand(mo)               ..  Qdemand(mo)  =E=  sum(up $OnU(up), Q(up,mo)) - sum(uv $OnU(uv), Q(uv,mo)) + [QInfeasDir('source',mo) - QInfeasDir('drain',mo)] $OnQInfeas;
ZQ_Qaff(ua,mo)     $OnU(ua)  ..  Q(ua,mo)     =E=  [QaffM(ua,mo) + Qrgk(ua,mo)];
ZQ_QaffM(ua,mo)    $OnU(ua)  ..  QaffM(ua,mo) =E=  [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelCons(ua,fa,mo) * EtaQ(ua) * LhvMWh(fa))] $OnU(ua);
ZQ_Qrgk(ua,mo)     $OnU(ua)  ..  Qrgk(ua,mo)  =L=  KapRgk(ua) / KapNom(ua) * QaffM(ua,mo);
ZQ_QrgkMax(ua,mo)  $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);

ZQ_Qaux(uaux,mo) $OnU(uaux)  ..  Q(uaux,mo)   =E=  [sum(faux $(OnF(faux) AND u2f(uaux,faux)), FuelCons(uaux,faux,mo) * EtaQ(uaux) * LhvMWh(faux))] $OnU(uaux);


ZQ_QaffMmax(ua,mo) $OnU(ua)  ..  QAffM(ua,mo)                =L=  QaffMmax(ua,mo);
ZQ_CoolMax(mo)               ..  sum(uv $OnU(uv), Q(uv,mo))  =L=  sum(ua $OnU(ua), Q(ua,mo));

ZQ_QMin(u,mo)      $OnU(u)   ..  Q(u,mo)      =G=  ShareAvailU(u,mo) * Hours(mo) * KapMin(u) * bOnU(u,mo);   #  Restriktionen på timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
ZQ_QMax(u,mo)      $OnU(u)   ..  Q(u,mo)      =L=  ShareAvailU(u,mo) * Hours(mo) * KapMax(u) * bOnU(u,mo);
ZQ_bOnRgk(ua,mo)   $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);

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

Equation ZQ_StoDLoad(s,moall)   'Samlet lagermængde';
Equation ZQ_FuelCons(f,moall)   'Relation mellem afbrændt, leveret og lagerført brændsel (if any)';

ZQ_StoDLoad(sa,mo) $OnS(sa) ..  sum(fsto $(OnF(fsto) AND s2f(sa,fsto)), StoDLoadF(sa,fsto,mo))  =E=  StoDLoad(sa,mo);
ZQ_FuelCons(f,mo)  $OnF(f)  ..  sum(u $(OnU(u) AND u2f(u,f)), FuelCons(u,f,mo))                =E=  FuelDeliv(f,mo) - [sum(sa $(OnS(sa) and s2f(sa,f)), StoDLoadF(sa,f,mo))] $fsto(f);

# Grænser for leverancer.
Equation  ZQ_FuelMin(f,moall)   'Mindste drivmiddelforbrug på månedsniveau';
Equation  ZQ_FuelMax(f,moall)   'Stoerste drivmiddelforbrug på månedsniveau';

#-- ZQ_FuelMin(f,mo) $(OnF(f) AND fdis(f) AND NOT fsto(f) AND NOT ffri(f))  ..  sum(u $(OnU(u)  AND u2f(u,f)),  FuelDeliv(u,f,mo))   =G=  FuelBounds(f,'min',mo);
#-- ZQ_FuelMax(f,mo) $(OnF(f) AND fdis(f)) ..  sum(u $(OnU(u)  AND u2f(u,f)),  FuelDeliv(u,f,mo))  =L=  FuelBounds(f,'max',mo) * 1.0001;  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.

#--- ZQ_FuelMin(f,mo) $(OnF(f) AND fdis(f) AND NOT fsto(f) AND NOT ffri(f))  ..  FuelDeliv(f,mo)  =G=  FuelBounds(f,'min',mo);
ZQ_FuelMin(f,mo) $(OnF(f) AND fdis(f) AND NOT ffri(f))  ..  FuelDeliv(f,mo)  =G=  FuelBounds(f,'min',mo);
ZQ_FuelMax(f,mo) $(OnF(f) AND fdis(f))                  ..  FuelDeliv(f,mo)  =L=  FuelBounds(f,'max',mo) * 1.0001;  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.

# Årskrav til affaldsfraktioner, som skal bortskaffes.
Equation  ZQ_FuelMinYear(f)  'Mindste braendselsforbrug på årsniveau';
Equation  ZQ_FuelMaxYear(f)  'Stoerste braendselsforbrug på årsniveau';

#--- ZQ_FuelMinYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDeliv(u,fdis,mo)))  =G=  MinTonnageYear(fdis) * card(mo) / 12;
#--- ZQ_FuelMaxYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDeliv(u,fdis,mo)))  =L=  MaxTonnageYear(fdis) * card(mo) / 12;

ZQ_FuelMinYear(fdis)  $OnF(fdis)  ..  sum(mo, FuelDeliv(fdis,mo))  =G=  MinTonnageYear(fdis) * card(mo) / 12;
ZQ_FuelMaxYear(fdis)  $OnF(fdis)  ..  sum(mo, FuelDeliv(fdis,mo))  =L=  MaxTonnageYear(fdis) * card(mo) / 12;

# Krav til frie affaldsfraktioner.
Equation ZQ_FuelDelivFreeSum(f)              'Aarstonnage af frie affaldsfraktioner';
Equation ZQ_FuelMinFreeNonStorable(f,moall)  'Ligeligt tonnageforbrug af ikke-lagerbare frie affaldsfraktioner';
#--- Equation ZQ_FuelMinFree(f,moall)     'Mindste maengde ikke-lagerbare frie affaldsfraktioner';
#--- Equation ZQ_FuelMaxFree(f,moall)     'stoerste maengde til ikke-lagerbare frie affaldsfraktioner';

ZQ_FuelDelivFreeSum(ffri) $(OnF(ffri) AND card(mo) GT 1)                             ..  FuelDelivFreeSum(ffri)  =E=  sum(mo, FuelDeliv(ffri,mo));
ZQ_FuelMinFreeNonStorable(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri) AND card(mo) GT 1) ..  FuelDeliv(ffri,mo)      =E=  FuelDelivFreeSum(ffri) / card(mo);
#--- ZQ_FuelDelivFreeSum(ffri) $(OnF(ffri) AND card(mo) GT 1)                             .. FuelDelivFreeSum(ffri)  =E=  sum(mo, sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDeliv(ua,ffri,mo) ) );
#--- ZQ_FuelMinFreeNonStorable(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri) AND card(mo) GT 1) ..  sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDeliv(ua,ffri,mo))  =E=  FuelDelivFreeSum(ffri) / card(mo);
#--- ZQ_FuelMinFree(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri)) ..  sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDeliv(ua,ffri,mo))  =G=  FuelDelivFreeSum(ffri);
#--- ZQ_FuelMaxFree(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri)) ..  sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDeliv(ua,ffri,mo))  =L=  FuelDelivFreeSum(ffri) * 1.0001;

# Restriktioner på tonnage og braendvaerdi for affaldsanlaeg.
Equation ZQ_MaxTonnage(u,moall)    'Stoerste tonnage for affaldsanlaeg';
Equation ZQ_MinLhvAffald(u,moall)  'Mindste braendvaerdi for affaldsblanding';

#--- ZQ_MaxTonnage(ua,mo) $OnU(ua)    ..  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDeliv(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * KapTon(ua);
#--- ZQ_MinLhvAffald(ua,mo) $OnU(ua)  ..  MinLhvMWh(ua) * sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDeliv(ua,fa,mo))
#---                                       =L=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDeliv(ua,fa,mo) * LhvMWh(fa));

ZQ_MaxTonnage(ua,mo) $OnU(ua)    ..  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelCons(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * KapTon(ua);
ZQ_MinLhvAffald(ua,mo) $OnU(ua)  ..  MinLhvMWh(ua) * sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelCons(ua,fa,mo))  =L=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelCons(ua,fa,mo) * LhvMWh(fa));

# Lagerdisponering.
Equation ZQ_StoCostAll(s,moall)       'Samlet lageromkostning';
Equation ZQ_StoCostLoad(s,moall)      'Lageromkostning opbevaring';
Equation ZQ_StoCostDLoad(s,moall)     'Lageromkostning transport';
Equation ZQ_StoLoadMin(s,moall)       'Nedre grænse for lagerbeholdning';
Equation ZQ_StoLoadMax(s,moall)       'Øvre grænse for lagerbeholdning';
Equation ZQ_StoLoad(s,moall)          'Lagerbeholdning og -ændring';
Equation ZQ_StoLoss(s,moall)          'Lagertab proport. til beholdning';
Equation ZQ_StoDLoadMax(s,moall)      'Max. lagerændring';
Equation ZQ_StoDLoadAbs1(s,moall)     'Abs funktion på lagerændring StoDLoad';
Equation ZQ_StoDLoadAbs2(s,moall)     'Abs funktion på lagerændring StoDLoad';
Equation ZQ_StoFirstReset(s,moall)    'Første nulstilling af lagerbeholdning';
Equation ZQ_StoResetIntv(s,moall)     'Øvrige nulstillinger af lagerbeholdning';

ZQ_StoCostAll(s,mo)   $OnS(s)  ..  StoCostAll(s,mo)    =E=  StoCostLoad(s,mo) + StoCostDLoad(s,mo);
ZQ_StoCostLoad(s,mo)  $OnS(s)  ..  StoCostLoad(s,mo)   =E=  StoLoadCostRate(s,mo) * StoLoad(s,mo);
ZQ_StoCostDLoad(s,mo) $OnS(s)  ..  StoCostDLoad(s,mo)  =E=  StoDLoadCostRate(s,mo) * StoDLoadAbs(s,mo);


ZQ_StoLoadMin(s,mo) $OnS(s) ..  StoLoad(s,mo)      =G=  StoLoadMin(s,mo);
ZQ_StoLoadMax(s,mo) $OnS(s) ..  StoLoad(s,mo)      =L=  StoLoadMax(s,mo);

# Lageret af en given fraktion kan højst tømmes.

Equation ZQ_StoDLoadFMin(s,f,moall)  'Lagerbeholdningsændring af given fraktion';
Equation ZQ_StoLoadSum(s,moall)     'Sum af fraktioner på givet lager';

# Sikring af at StoDLoadF ikke overstiger lagerbeholdningen fra forrige måned.
#--- ZQ_StoDLoadFMin(sa,fsto,mo) $OnS(sa) .. StoLoadF(sa,fsto,mo) + StoDLoadF(sa,fsto,mo)  =G=  0.0;
$OffOrder
ZQ_StoDLoadFMin(sa,fsto,mo) $OnS(sa) .. [StoLoadInitF(sa,fsto) $(ord(mo) EQ 1) + StoLoadF(sa,fsto,mo-1) $(ord(mo) GT 1)] + StoDLoadF(sa,fsto,mo)  =G=  0.0;
$OnOrder
ZQ_StoLoadSum(s,mo) $OnS(s)          .. StoLoad(s,mo)  =E=  sum(fsto $(OnF(fsto) AND s2f(s,fsto)), StoLoadF(s,fsto,mo));


$OffOrder
ZQ_StoLoad(s,mo) $OnS(s)    ..  StoLoad(s,mo)      =E=  StoLoad(s,mo-1) + StoDLoad(s,mo) - StoLoss(s,mo-1);
$OnOrder
ZQ_StoLoss(s,mo) $OnS(s)    ..  StoLoss(s,mo)      =E=  StoLossRate(s,mo) * StoLoad(s,mo);
ZQ_StoDLoadMax(s,mo)        ..  StoDLoadAbs(s,mo)  =L=  StoDLoadMax(s,mo) $OnS(s);
ZQ_StoDLoadAbs1(s,mo)       ..  +StoDLoad(s,mo)    =L=  StoDLoadAbs(s,mo) $OnS(s);
ZQ_StoDLoadAbs2(s,mo)       ..  -StoDLoad(s,mo)    =L=  StoDLoadAbs(s,mo) $OnS(s);

# OBS: ZQ_StoFirstReset dækker med én ligning pr. lager perioden frem til og med først nulstilling. Denne ligning tilknyttes første måned.
# TODO: Lageret fyldes op frem mod slutningen af planperioden, fordi modtageindkomsten gør det lukrativt.
#       Planperioden bør derfor indeholde et krav om tømning af lageret i dens sidste måned.
$OffOrder
ZQ_StoFirstReset(s,mo) $OnS(s)  ..  sum(moa $(ord(mo) EQ 1 AND ord(mo) LE StoFirstReset(s)), bOnSto(s,moa))  =L=  StoFirstReset(s) - 1;
ZQ_StoResetIntv(s,mo) $OnS(s)   ..  sum(moa $(ord(mo) GT StoFirstReset(s) AND ord(moa) GE ord(mo) AND ord(moa) LE (ord(mo) - 1 + StoIntvReset(s))), bOnSto(s,moa))  =L=  StoIntvReset(s) - 1;
$OnOrder


#--- # DEBUG: Udskrivning af modeldata før solve.
#--- $gdxout "REFAmain.gdx"
#--- $unload
#--- $gdxout

$If not errorfree $exit

# ------------------------------------------------------------------------------------------------
# Loesning af modellen.
# ------------------------------------------------------------------------------------------------
model modelREFA / all /;
option MIP=gurobi;
modelREFA.optFile = 1;
#--- option MIP=CBC

option LIMROW=250, LIMCOL=250;
#--- option LIMROW=0, LIMCOL=0;

solve modelREFA maximizing NPV using MIP;


if (modelREFA.modelStat GE 3 AND modelREFA.modelStat NE 8,
  display "Ingen løsning fundet.";
  execute_unload "REFAmain.gdx";
  abort "Solve af model mislykkedes.";
);


# ------------------------------------------------------------------------------------------------
# Efterbehandling af resultater.
# ------------------------------------------------------------------------------------------------

# OBS: Penalty_bOnU skal tilbagebetales til NPV.
Scalar Penalty_bOnUTotal;
Penalty_bOnUTotal = Penalty_bOnU * sum(mo, sum(u, bOnU.L(u,mo)));
display Penalty_bOnUTotal, NPV.L;

# ------------------------------------------------------------------------------------------------
# Udskriv resultater til Excel output fil.
# ------------------------------------------------------------------------------------------------

# Tidsstempel for beregningens udfoerelse.
Scalar TimeOfWritingMasterResults;
TimeOfWritingMasterResults = jnow;
Scalar PerStart;
Scalar PerSlut;
PerStart = Schedule('dato','firstPeriod');
PerSlut  = Schedule('dato','lastPeriod');

# Tilbageføring til NPV af penalty costs og omkostninger fra ikke-inkluderede anlaeg og braendsler.
Scalar NPV_REFA_V, NPV_Total_V;
Scalar Penalty_bOnUTotal, Penalty_QRgkMissTotal;

Penalty_bOnUTotal = Penalty_bOnU * sum(mo, sum(u, bOnU.L(u,mo)));
Penalty_QRgkMissTotal = Penalty_QRgkMiss * sum(mo, QRgkMiss.L(mo));

# NPV_Total_V er den samlede NPV med tilbageførte penalties.
NPV_Total_V = NPV.L + Penalty_bOnUTotal + Penalty_QRgkMissTotal;

# NPV_REFA_V er REFAs andel af NPV med tilbageførte penalties og tilbageførte GSF-omkostninger.
NPV_REFA_V  = NPV.L + Penalty_bOnUTotal + Penalty_QRgkMissTotal
              + sum(mo,
                  + sum(ugsf $(OnU(ugsf)), CostsU.L(ugsf,mo))
                  + sum(fgsf $(OnF(fgsf)), CostsPurchaseF.L(fgsf,mo) + TaxCO2F.L(fgsf,mo) + TaxNOxF.L(fgsf,mo)) + TaxEnr.L(mo)
                );

display Penalty_bOnUTotal, Penalty_QRgkMissTotal, NPV.L, NPV_Total_V, NPV_REFA_V;


# Sammenfatning af aggregerede resultater på maanedsniveau.
set topics / FJV-behov, Var-Varmeproduktions-Omk-Total, Var-Varmeproduktions-Omk-REFA,
             REFA-Daekningsbidrag, REFA-Total-Var-Indkomst, REFA-Affald-Modtagelse, REFA-RGK-Rabat, REFA-Elsalg,
             REFA-Total-Var-Omkostning, REFA-AnlaegsVarOmk, REFA-BraendselOmk, REFA-Afgifter, REFA-CO2-Kvoteomk, REFA-Lageromkostning,
             REFA-CO2-Emission-Afgift, REFA-CO2-Emission-Kvote, REFA-El-produktion,
             REFA-Total-Varme-Produktion, REFA-Modtryk-Varme, REFA-RGK-Varme, REFA-RGK-Andel, REFA-Bortkoelet-Varme,
             GSF-Total-Var-Omkostning,  GSF-AnlaegsVarOmk,  GSF-BraendselOmk,  GSF-Afgifter,  GSF-CO2-Emission,  GSF-Total-Varme-Produktion
             /;

Parameter DataCtrl_V(labDataCtrl);
Parameter DataU_V(u,labDataU);
Parameter DataSto_V(s,labDataSto);
Parameter DataFuel_V(f,labDataFuel);
Parameter Prognoses_V(labProgn,moall)      'Prognoser transponeret';
Parameter FuelBounds_V(f,bound,moall);
Parameter FuelDeliv_V(f,moall)             'Leveret brændsel';
Parameter FuelCons_V(u,f,moall)            'Afbrændt brændsel for givet anlæg';
Parameter StoDLoadF_V(s,f,moall)           'Lagerændring for givet lager og brændsel';
Parameter StoLoadF_V(s,f,moall)            'Lagerbeholdning for givet lager og brændsel';
Parameter StoLoadAll_V(s,moall)            'Lagerbeholdning ialt for givet lager';
Parameter IncomeFuel_V(f,moall);
Parameter Q_V(u,moall);

Parameter Overview(topics,moall);
Parameter RefaDaekningsbidrag_V(moall)     'Daekningsbidrag for REFA [DKK]';
Parameter RefaTotalVarIndkomst_V(moall)    'REFA Total variabel indkomst [DKK]';
Parameter RefaAffaldModtagelse_V(moall)    'REFA Affald modtageindkomst [DKK]';
Parameter RefaRgkRabat_V(moall)            'REFA RGK-rabat for affald [DKK]';
Parameter RefaElsalg_V(moall)              'REFA Indkomst elsalg [DKK]';

Parameter RefaTotalVarOmk_V(moall)         'REFA Total variabel indkomst [DKK]';
Parameter RefaAnlaegsVarOmk_V(moall)       'REFA Var anlaegs omk [DKK]';
Parameter RefaBraendselsVarOmk_V(moall)    'REFA Var braendsels omk. [DKK]';
Parameter RefaAfgifter_V(moall)            'REFA afgifter [DKK]';
Parameter RefaKvoteOmk_V(moall)            'REFA CO2 kvote-omk. [DKK]';
Parameter RefaStoCost_V(moall)             'REFA Lageromkostning [DKK]';
Parameter RefaCO2emission_V(moall,typeCO2) 'REFA CO2 emission [ton]';
Parameter RefaElproduktion_V(moall)        'REFA elproduktion [MWhe]';

Parameter RefaVarmeProd_V(moall)           'REFA Total varmeproduktion [MWhq]';
Parameter RefaModtrykProd_V(moall)         'REFA Total modtryksvarmeproduktion [MWhq]';
Parameter RefaRgkProd_V(moall)             'REFA RGJ-varmeproduktion [MWhq]';
Parameter RefaRgkShare_V(moall)            'RGK-varmens andel af REFA energiproduktion';
Parameter RefaBortkoeletVarme_V(moall)     'REFA bortkoelet varme [MWhq]';
Parameter VarmeVarProdOmkTotal_V(moall)    'Variabel varmepris på tvaers af alle produktionsanlæg DKK/MWhq';
Parameter VarmeVarProdOmkRefa_V(moall)     'Variabel varmepris på tvaers af REFA-produktionsanlæg DKK/MWhq';
Parameter RefaLagerBeholdning_V(s,moall)   'Lagerbeholdning [ton]';
Parameter Usage_V(u,moall)                 'Kapacitetsudnyttelse af anlæg';
Parameter LhvCons_V(u,moall)               'Realiseret brændværdi';
Parameter Tonnage_V(u,moall)               'Tonnage afbrændt pr. time';

Parameter GsfTotalVarOmk_V(moall)          'Guldborgsund Forsyning Total indkomst [DKK]';
Parameter GsfAnlaegsVarOmk_V(moall)        'Guldborgsund Forsyning Var anlaegs omk [DKK]';
Parameter GsfBraendselsVarOmk_V(moall)     'Guldborgsund Forsyning Var braendsels omk. [DKK]';
Parameter GsfAfgifter_V(moall)             'Guldborgsund Forsyning Afgifter [DKK]';
Parameter GsfCO2emission_V(moall)          'Guldborgsund Forsyning CO2 emission [ton]';
Parameter GsfTotalVarmeProd_V(moall)       'Guldborgsund Forsyning Total Varmeproduktion [MWhq]';

loop (mo $(NOT sameas(mo,'mo0')),
  RefaAffaldModtagelse_V(mo)            = sum(fa $OnF(fa), IncomeAff.L(fa,mo));
  RefaRgkRabat_V(mo)                    = RgkRabat.L(mo);
  RefaElsalg_V(mo)                      = IncomeElec(mo);
  RefaTotalVarIndkomst_V(mo)            = RefaAffaldModtagelse_V(mo) + RefaRgkRabat_V(mo) + RefaElsalg_V(mo);
  OverView('REFA-Affald-Modtagelse',mo) = max(tiny, RefaAffaldModtagelse_V(mo) );
  OverView('REFA-RGK-Rabat',mo)         = max(tiny, RefaRgkRabat_V(mo) );
  OverView('REFA-Elsalg',mo)            = max(tiny, RefaElsalg_V(mo) );

  RefaAnlaegsVarOmk_V(mo)                  = sum(urefa $OnU(urefa), CostsU.L(urefa,mo));
  RefaBraendselsVarOmk_V(mo)               = sum(frefa, CostsPurchaseF.L(frefa,mo));
  RefaAfgifter_V(mo)                       = TaxAFV.L(mo) + TaxATL.L(mo) + sum(frefa, TaxCO2F.L(frefa,mo) + TaxNOxF.L(frefa,mo));
  RefaKvoteOmk_V(mo)                       = CostsETS.L(mo);  # Kun REFA er kvoteomfattet.
  RefaStoCost_V(mo)                        = sum(s $OnS(s), StoCostAll.L(s,mo));
  RefaTotalVarOmk_V(mo)                    = RefaAnlaegsVarOmk_V(mo) + RefaBraendselsVarOmk_V(mo) + RefaAfgifter_V(mo) + RefaKvoteOmk_V(mo);
  RefaDaekningsbidrag_V(mo)                = RefaTotalVarIndkomst_V(mo) - RefaTotalVarOmk_V(mo);
  OverView('REFA-AnlaegsVarOmk',mo)        = max(tiny, RefaAnlaegsVarOmk_V(mo) );
  OverView('REFA-BraendselOmk',mo)         = max(tiny, RefaBraendselsVarOmk_V(mo) );
  OverView('REFA-Afgifter',mo)             = max(tiny, RefaAfgifter_V(mo) );
  OverView('REFA-CO2-Kvoteomk',mo)         = max(tiny, RefaKvoteOmk_V(mo) );
  OverView('REFA-Lageromkostning',mo)      = max(tiny, RefaStoCost_V(mo) );
  OverView('REFA-Total-Var-Indkomst',mo)   = max(tiny, RefaTotalVarIndkomst_V(mo) );
  OverView('REFA-Total-Var-Omkostning',mo) = max(tiny, RefaTotalVarOmk_V(mo) );
  OverView('REFA-Daekningsbidrag',mo)      = ifthen(RefaDaekningsbidrag_V(mo) EQ 0.0, tiny, RefaDaekningsbidrag_V(mo));

  RefaCO2emission_V(mo,typeCO2)            = max(tiny, sum(frefa $OnF(frefa), CO2emis.L(frefa,mo,typeCO2)) );
  RefaElproduktion_V(mo)                   = max(tiny, PowerProd(mo));
  OverView('REFA-CO2-Emission-afgift',mo)  = RefaCO2emission_V(mo,'afgift');
  OverView('REFA-CO2-Emission-kvote',mo)   = RefaCO2emission_V(mo,'kvote');
  OverView('REFA-El-produktion',mo)        = RefaElproduktion_V(mo);

  RefaVarmeProd_V(mo)       = max(tiny, sum(uprefa $OnU(uprefa), Q.L(uprefa,mo)) );
  RefaModtrykProd_V(mo)     = max(tiny, sum(ua $OnU(ua), QAffM.L(ua,mo)) );
  RefaRgkProd_V(mo)         = max(tiny, sum(ua $OnU(ua), Qrgk.L(ua,mo)) );
  RefaRgkShare_V(mo)        = max(tiny, sum(ua $OnU(ua), Qrgk.L(ua,mo)) / sum(ua $OnU(ua), Q.L(ua,mo)) );
  RefaBortkoeletVarme_V(mo) = max(tiny, sum(uv $OnU(uv), Q.L(uv,mo)) );
  OverView('REFA-Total-Varme-Produktion',mo) = RefaVarmeProd_V(mo);
  OverView('REFA-Modtryk-Varme',mo)          = RefaModtrykProd_V(mo);
  OverView('REFA-RGK-Varme',mo)              = RefaRgkProd_V(mo);
  OverView('REFA-RGK-Andel',mo)              = RefaRgkShare_V(mo);
  OverView('REFA-Bortkoelet-Varme',mo)       = RefaBortkoeletVarme_V(mo);

  GsfAnlaegsVarOmk_V(mo)                    = sum(ugsf, CostsU.L(ugsf, mo) );
  GsfBraendselsVarOmk_V(mo)                 = sum(fgsf, CostsPurchaseF.L(fgsf,mo) );
  GsfAfgifter_V(mo)                         = sum(fgsf, TaxCO2F.L(fgsf, mo) + taxNOxF.L(fgsf,mo)) + TaxEnr.L(mo);
  GsfCO2emission_V(mo)                      = sum(fgsf, CO2emis.L(fgsf,mo,'afgift') );
  GsfTotalVarmeProd_V(mo)                   = sum(ugsf, Q.L(ugsf,mo) );
  GsfTotalVarOmk_V(mo)                      = GsfAnlaegsVarOmk_V(mo) + GsfBraendselsVarOmk_V(mo) + GsfAfgifter_V(mo);
  OverView('GSF-AnlaegsVarOmk',mo)          = max(tiny, GsfAnlaegsVarOmk_V(mo) );
  OverView('GSF-BraendselOmk',mo)           = max(tiny, GsfBraendselsVarOmk_V(mo) );
  OverView('GSF-Afgifter',mo)               = max(tiny, GsfAfgifter_V(mo) );
  OverView('GSF-CO2-Emission',mo)           = max(tiny, GsfCO2emission_V(mo) );
  OverView('GSF-Total-Varme-Produktion',mo) = max(tiny, GsfTotalVarmeProd_V(mo) );
  OverView('GSF-Total-Var-Omkostning',mo)   = max(tiny, GsfTotalVarOmk_V(mo) );

#---  VarmeVarProdOmkTotal_V(mo) = (sum(u $OnU(u), CostsU.L(u,mo)) + sum(owner, CostsTotalF.L(owner,mo)) - IncomeTotal.L(mo)) / (sum(up, Q.L(up,mo) - sum(uv, Q.L(uv,mo))));
#---  VarmeVarProdOmkRefa_V(mo)  = (sum(urefa, CostsU.L(urefa,mo)) + CostsTotalF.L('refa',mo) - IncomeTotal.L(mo)) / (sum(uprefa, Q.L(uprefa,mo)) - sum(uv, Q.L(uv,mo)));
  VarmeVarProdOmkTotal_V(mo)  = (RefaTotalVarOmk_V(mo) - RefaTotalVarIndkomst_V(mo) + GsfTotalVarOmk_V(mo)) / Qdemand(mo);
  VarmeVarProdOmkRefa_V(mo)   = (RefaTotalVarOmk_V(mo) - RefaTotalVarIndkomst_V(mo)) / (sum(uprefa, Q.L(uprefa,mo)) - sum(uv, Q.L(uv,mo)));
  Overview('FJV-behov',mo)                      = max(tiny, Qdemand(mo));
  OverView('Var-Varmeproduktions-Omk-Total',mo) = ifthen(VarmeVarProdOmkTotal_V(mo) EQ 0.0, tiny, VarmeVarProdOmkTotal_V(mo));
  OverView('Var-Varmeproduktions-Omk-REFA',mo)  = ifthen(VarmeVarProdOmkRefa_V(mo) EQ 0.0,  tiny, VarmeVarProdOmkRefa_V(mo));


  loop (f,
    FuelDeliv_V(f,mo) = max(tiny, FuelDeliv.L(f,mo));
    IncomeFuel_V(f,mo) = IncomeAff.L(f,mo) - CostsPurchaseF.L(f,mo);
    if (IncomeFuel_V(f,mo) EQ 0.0, IncomeFuel_V(f,mo) = tiny; );
  );
  
  FuelCons_V(u,f,mo) = max(tiny, FuelCons.L(u,f,mo));
  
  loop (f $(OnF(f) AND fa(f) AND fsto(f)),
    StoDLoadF_V(sa,f,mo)  = max(tiny, StoDLoadF.L(sa,f,mo));
    StoLoadF_V(sa,f,mo)   = max(tiny, StoLoadF.L(sa,f,mo));
  );

  StoLoadAll_V(s,mo) = max(tiny, StoLoad.L(s,mo));
  

  Q_V(u,mo)  = ifthen (Q.L(u,mo) EQ 0.0, tiny, Q.L(u,mo));
  Q_V(uv,mo) = -Q_V(uv,mo);  # Negation aht. afbildning i sheet Overblik.
  #--- RefaRgkProd_V(mo) = sum(ua, Qrgk.L(ua,mo));
  loop (u $OnU(u),
    if (Q.L(u,mo) GT 0.0,
      Usage_V(u,mo) = Q.L(u,mo) / (KapMax(u) * ShareAvailU(u,mo) * Hours(mo));
    else
      Usage_V(u,mo) = tiny;
    );
    if (up(u), 
      # Realiseret brændværdi.
      tmp1 = sum(f $(OnF(f) AND u2f(u,f)), FuelCons.L(u,f,mo));
      if (tmp1 GT 0.0, 
        LhvCons_V(u,mo) = 3.6 * sum(f $(OnF(f) AND u2f(u,f)), FuelCons.L(u,f,mo) * LhvMWh(f)) / tmp1;
      );
      # Tonnage indfyret.
      tmp2 = ShareAvailU(u,mo) * Hours(mo);
      if (tmp2 GT 0.0, 
        Tonnage_V(u,mo) = sum(f $(OnF(f) AND u2f(u,f)), FuelCons.L(u,f,mo)) / tmp2;
      );
    );
  );
);

DataCtrl_V(labDataCtrl)     = ifthen(DataCtrl(labDataCtrl)   EQ 0.0, tiny, DataCtrl(labDataCtrl));
DataU_V(u,labDataU)         = ifthen(DataU(u,labDataU)       EQ 0.0, tiny, DataU(u,labDataU)); 
DataSto_V(s,labDataSto)     = ifthen(DataSto(s,labDataSto)   EQ 0.0, tiny, DataSto(s,labDataSto)); 
DataFuel_V(f,labDataFuel)   = ifthen(DataFuel(f,labDataFuel) EQ 0.0, tiny, DataFuel(f,labDataFuel)); 
Prognoses_V(labProgn,mo)    = ifthen(Prognoses(mo,labProgn) EQ 0.0, tiny, Prognoses(mo,labProgn));
Prognoses_V(labProgn,'mo0') = tiny;  # Sikrer udskrivning af tom kolonne i output-udgaven af Prognoses.
FuelBounds_V(f,bound,mo)    = max(tiny, FuelBounds(f,bound,mo));
FuelBounds_V(f,bound,'mo0') = 0.0;   # Sikrer at kolonne 'mo0' ikke udskrives til Excel.
FuelDeliv_V(f,'mo0')        = 0.0;   # Sikrer at kolonne 'mo0' ikke udskrives til Excel.
StoDLoadF_V(s,f,'mo0')      = 0.0;
FuelCons_V(u,f,'mo0')       = 0.0;

execute_unload 'REFAoutput.gdx',
TimeOfWritingMasterResults,
bound, moall, mo, fkind, f, fa, fb, fc, fr, u, up, ua, ub, uc, ur, u2f, s2f, 
labDataU, labDataFuel, labScheduleRow, labScheduleCol, labProgn, taxkind, topics, typeCO2,
Schedule, DataCtrl_V, DataU_V, DataSto_V, Prognoses_V, AvailDaysU, DataFuel_V, FuelBounds_V, 
OnU, OnF, OnM, OnS, Hours, ShareAvailU, EtaQ, KapMin, KapNom, KapRgk, KapMax, Qdemand, PowerProd, LhvMWh, 
TaxAfvMWh, TaxAtlMWh, TaxCO2AffTon, TaxCO2peakTon,
EaffGross, QaffMmax, QrgkMax, QaffTotalMax, TaxATLMax, RgkRabatMax,
OverView, NPV_Total_V, NPV_REFA_V, Prognoses_V, FuelDeliv_V, FuelCons_V, StoLoadF_V, StoDLoadF_V, IncomeFuel_V, Q_V,
PerStart, PerSlut,

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
RefaElproduktion_V,

RefaVarmeProd_V,
RefaModtrykProd_V,
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
text="Styringsparameter"  rng=Inputs!B3:B3
par=Schedule              rng=Inputs!B13        cdim=1  rdim=1
text="Schedule"           rng=Inputs!B13:B13
par=DataU_V               rng=Inputs!B19        cdim=1  rdim=1
text="DataU"              rng=Inputs!B19:B19
par=DataSto_V             rng=Inputs!B27        cdim=1  rdim=1
text="DataSto"            rng=Inputs!B27:B27
par=DataFuel_V            rng=Inputs!B38        cdim=1  rdim=1
text="DataFuel"           rng=Inputs!B38:B38
par=Prognoses_V           rng=Inputs!R13        cdim=1  rdim=1
text="Prognoser"          rng=Inputs!R13:R13
par=FuelBounds_V          rng=Inputs!R38        cdim=1  rdim=2
text="FuelBounds"         rng=Inputs!R38:R38

*end   Individuelle dataark

* Overview is the last sheet to be written hence becomes the actual sheet when opening Excel file.

*begin sheet Overblik
par=TimeOfWritingMasterResults      rng=Overblik!C1:C1
text="Tidsstempel"                  rng=Overblik!A1:A1
par=PerStart                        rng=Overblik!B2:B2
par=PerSlut                         rng=Overblik!C2:C2
par=NPV_Total_V                     rng=Overblik!B3:B3
text="NPV Total"                    rng=Overblik!A3:A3
par=NPV_REFA_V                      rng=Overblik!B4:B4
text="NPV_REFA"                     rng=Overblik!A4:A4
par=OverView                        rng=Overblik!C6          cdim=1  rdim=1
text="Overblik"                     rng=Overblik!C6:C6
par=Q_V                             rng=Overblik!C36         cdim=1  rdim=1
text="Varmemængder"                 rng=Overblik!A36:A36
par=FuelDeliv_V                     rng=Overblik!C44         cdim=1  rdim=1
text="Brændselsforbrug"             rng=Overblik!A44:A44
par=IncomeFuel_V                    rng=Overblik!C76         cdim=1  rdim=1
text="Brøndselsindkomst"            rng=Overblik!A76:A76
par=Usage_V                         rng=Overblik!C108        cdim=1  rdim=1
text="Kapacitetsudnyttelse"         rng=Overblik!A108:A108
par=StoLoadAll_V                    rng=Overblik!C117        cdim=1 rdim=1
text="Lagerbeholdning totalt"       rng=Overblik!A117:A117   
text="Lager"                        rng=Overblik!C117:C117   
par=StoLoadF_V                      rng=Overblik!B125        cdim=1 rdim=2
text="Lagerbeh. pr fraktion"        rng=Overblik!A125:A125   
text="Lager"                        rng=Overblik!B125:B125   
text="Fraktion"                     rng=Overblik!C125:C125   
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
  fpathNew = os.path.join(wkdir, r'REFAoutput (' + str(currentDate) + ').xlsm')

  shutil.copyfile(fpathOld, fpathNew)
  gams.printLog('Excel file "' + os.path.split(fpathNew)[1] + '" written to folder: ' + wkdir)

  # Copy gdx file assigning it a name including current iteration, no. of periods and a timestamp.
  fpathOld = os.path.join(wkdir, r'REFAmain.gdx')
  fpathNew = os.path.join(wkdir, r'REFAmain (' + str(currentDate) + ').gdx')

  shutil.copyfile(fpathOld, fpathNew)
  gams.printLog('GDX file "' + os.path.split(fpathNew)[1] + '" written to folder: ' + wkdir)

endEmbeddedCode
# ======================================================================================================================
