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
option dispwidth = 40; 

# Shorthand for boolean constants.
Scalar FALSE 'Shorthand for false = 0 (zero)' / 0 /;
Scalar TRUE  'Shorthand for true  = 1 (one)'  / 1 /;

# Arbejdsvariable
Scalar Found      'Angiver at logisk betingelse er opfyldt';
Scalar FoundError 'Angiver at fejl er fundet';
Scalar tiny / 1E-14 /;
Scalar tmp1, tmp2, tmp3;

# ------------------------------------------------------------------------------------------------
# Erklaering af sets
# ------------------------------------------------------------------------------------------------

set bound     'Bounds'         / Min, Max, Lhv, ModtPris, CO2tonton/;
set dir       'Flowretning'    / drain, source /;

set phiKind   'Type af phi-faktor' / 85, 95 /;
set iter      'iterationer' / iter0 * iter30 /; 

#--- set mo   'Aarsmaaneder'   / jan, feb, mar, apr, maj, jun, jul, aug, sep, okt, nov, dec /;
#--- set mo   'Aarsmaaneder'   / jan /;
set moall     'Aarsmaaneder'   / mo0 * mo36 /;  # Daekker op til 3 aar. Elementet 'mo0' anvendes kun for at sikre tom kolonne i udskrivning til Excel.
set mo(moall) 'Aktive maaneder';
alias(mo,moa);

set labDataCtrl       'Styringparms'       / IncludeGSF, VirtuelVarme, RgkRabatSats, RgkAndelRabat, Varmesalgspris, SkorstensMetode, EgetforbrugKVV /;
set labScheduleCol    'Periodeomfang'      / FirstYear, LastYear, FirstPeriod, LastPeriod /;
set labScheduleRow    'Periodeomfang'      / aar, maaned, dato /;
set labDataU          'DataU labels'       / Aktiv, Ukind, Prioritet, MinLhv, MaxLhv, MinTon, MaxTon, kapNom, kapRgk, kapMax, MinLast, KapMin, EtaE, EtaQ, DVMWhq, DVtime /;
set labProgn          'Prognose labels'    / Aktiv, Ndage, Ovn2, Ovn3, FlisK, NS, Cooler, PeakK, Varmebehov, NSprod, ELprod, Bypass, Elpris,
                                             ETS, AFV, ATL, CO2aff, ETSaff, CO2afgAff, NOxAff, NOxFlis, EnrPeak, CO2peak, NOxPeak /;
set labDataFuel       'DataFuel labels'    / Aktiv, Fkind, Lagerbar, Fri, Bortskaf, TilOvn2, TilOvn3, MinTonnage, MaxTonnage, InitSto1, InitSto2, Pris, Brandv, NOxKgTon, CO2kgGJ /;
set labDataSto        'DataSto labels'     / Aktiv, StoKind, LoadMin, LoadMax, DLoadMax, LossRate, LoadCost, DLoadCost, ResetFirst, ResetIntv, ResetLast /;  # stoKind=1 er affalds-, stoKind=2 er varmelager.
set taxkind(labProgn) 'Omkostningstyper'   / ETS, AFV, ATL, CO2aff, ETSaff, CO2afgAff, NOxAff, NOxFlis, EnrPeak, CO2peak, NOxPeak /;
set typeCO2           'CO2-Opg�relsestype' / afgift, kvote, total /;


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
set fnegpris(f)   'Braendsler med negativ pris (k�bspris))';
set fbiogen(f)    'Biogene br�ndsler (uden afgifter)';

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
set uprio2up(up,up) 'Anlaegsprioriteter';   # R�kkef�lge af prioriteter oprettes p� basis af DataU(up,'prioritet')

set s     'Lagre' / sto1 * sto2 /;          # I f�rste omgang tilt�nkt affaldslagre.
set sa(s) 'Affaldslagre';
set sq(s) 'Varmelagre';

set u2f(u,f)  'Gyldige kombinationer af anl�g og drivmidler';
set s2f(s,f)  'Gyldige kombinationer af lagre og drivmidler';


# ------------------------------------------------------------------------------------------------
# Erklaering af input parametre
# ------------------------------------------------------------------------------------------------
# Penalty faktorer til objektfunktionen.
Scalar    Penalty_bOnU              'Penalty p� bOnU'           / 0000E+5 /;
Scalar    Penalty_QRgkMiss          'Penalty p� QRgkMiss'       /   20    /;      # Denne penalty m� ikke v�re h�jere end tillaegsafgiften.
Scalar    Penalty_QInfeas           'Penalty p� QInfeasDir'     / 5000    /;      # P�l�gges virtuel varmekilder og -dr�n.
Scalar    Penalty_AffaldsGensalg    'Affald gensalgspris'       / 150.00  /;      # P�l�gges ikke-udnyttet affald.
Scalar    Gain_Ovn3                 'Gevinst for OVn3-varme'    / 100.00  /;      # Till�gges varmeproduktion p� Ovn3 for at sikre udlastning f�r NS-varmen.
Scalar    OnQInfeas                 'On/Off p� virtual varme'   / 0       /;

# Indl�ses via DataCtrl.
Scalar    RgkRabatSats              'Rabatsats p� ATL'          / 0.10    /;
Scalar    RgkRabatMinShare          'Taerskel for RGK rabat'    / 0.07    /;
Scalar    VarmeSalgspris            'Varmesalgspris DKK/MWhq'   / 200.00  /;
Scalar    AffaldsOmkAndel           'Affaldssiden omk.andel'    / 0.45    /;
Scalar    SkorstensMetode           '0/1 for skorstensmetode'   / 0       /;
Scalar    EgetforbrugKVV            'Angiver egetforbrug MWhe/d�gn';  

Scalar    NactiveM                  'Antal aktive m�neder';

Parameter IncludeOwner(owner)       '<>0 => Ejer med i OBJ'     / refa 1, gsf 0 /;
Parameter IncludePlant(u);
Parameter IncludeFuel(f);

Parameter Schedule(labScheduleRow, labScheduleCol)  'Periode start/stop';
Parameter DataCtrl(labDataCtrl)          'Data for styringsparametre';
Parameter DataU(u, labDataU)             'Data for anlaeg';
Parameter DataSto(s, labDataSto)         'Lagerspecifikationer';
Parameter Prognoses(moall,labProgn)      'Data for prognoser';
Parameter DataFuel(f, labDataFuel)       'Data for drivmidler';
Parameter FuelBounds(f,bound,moall)      'Maengdegraenser for drivmidler';

$If not errorfree $exit

# Indlaesning af input parametre

$onecho > REFAinput.txt
par=DataCtrl            rng=DataCtrl!B4:C10          rdim=1 cdim=0
par=Schedule            rng=DataU!A3:E6              rdim=1 cdim=1
par=DataU               rng=DataU!A11:O17            rdim=1 cdim=1
par=DataSto             rng=DataU!Q11:AB17           rdim=1 cdim=1
par=Prognoses           rng=DataU!D22:AB58           rdim=1 cdim=1
par=DataFuel            rng=DataFuel!C4:T33          rdim=1 cdim=1
par=FuelBounds          rng=DataFuel!B39:AM178       rdim=2 cdim=1
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

#--- display DataCtrl, DataU, Schedule, Prognoses, DataFuel, FuelBounds, DataSto;

IncludeOwner('gsf') = DataCtrl('IncludeGSF');
OnQInfeas           = DataCtrl('VirtuelVarme');
RgkRabatSats        = DataCtrl('RgkRabatSats');
RgkRabatMinShare    = DataCtrl('RgkAndelRabat');
VarmeSalgspris      = DataCtrl('VarmeSalgspris');
SkorstensMetode     = DataCtrl('SkorstensMetode');
EgetforbrugKVV      = DataCtrl('EgetforbrugKVV');

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

# Anl�gsprioriteter.
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
#--- display uprio, uprio2up;

# Braendselstyper.
fa(f) = DataFuel(f,'fkind') EQ 1;
fb(f) = DataFuel(f,'fkind') EQ 2;
fc(f) = DataFuel(f,'fkind') EQ 3;
fr(f) = DataFuel(f,'fkind') EQ 4;

u2f(u,f)   = no;
u2f(ub,fb) = yes;
u2f(uc,fc) = yes;
u2f(ur,fr) = yes;

# Brugergivne restriktioner p� kombinationer af affaldsanl�g og br�ndselsfraktioner.
singleton set ufparm(u,f);
ufparm(u,f) = no;

loop (fa, 
  u2f('Ovn2',fa) = DataFuel(fa,'TilOvn2') NE 0;
  u2f('Ovn3',fa) = DataFuel(fa,'TilOvn3') NE 0;
);

# Undertyper af br�ndsler:
# fsto: Br�ndsler, som m� lagres (bem�rk af t�mning af lagre er en s�rskilt restriktion)
# fdis: Br�ndsler, som skal modtages og forbr�ndes hhv. om muligt lagres. 
# ffri: Br�ndsler, hvor den �vre gr�nse aftagem�ngde er en optimeringsvariabel.
# faux: Br�ndsler, som ikke er affaldsbr�ndsler.

fsto(f) = DataFuel(f,'lagerbar') NE 0;
fdis(f) = DataFuel(f,'bortskaf') NE 0;
ffri(f) = DataFuel(f,'fri') NE 0 AND fa(f);
faux(f) = NOT fa(f);

# Identifikation af lagertyper.
sa(s) = DataSto(s,'stoKind') EQ 1;
sq(s) = DataSto(s,'stoKind') EQ 2;

# Tilknytning af affaldsfraktioner til lagre.
# Brugergivne restriktioner p� kombinationer af lagre og br�ndselsfraktioner.
singleton set sfparm(s,f);
sfparm(s,f) = no;

s2f(s,f)   = no;
s2f(sa,fa) = DataFuel(fa,'lagerbar') AND DataSto(sa,'aktiv');

# Brugergivet tilknytning af lagre til affaldsfraktioner kr�ver oprettelse af nye elementer i labDataFuel.
loop (fa, 
  loop (sa,
    loop (labDataFuel $sameas(sa,labDataFuel),
      tmp1 = DataFuel(fa,labDataFuel);
      # En negativ v�rdi DataFuel(fa,labDataFuel) angiver, at lageret ikke kan opbevare br�ndslet fa.
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

#--- display f, fa, fb, fc, fr, fsto, fdis, ffri, u2f, IncludeOwner, IncludePlant, IncludeFuel;


Parameter OnU(u)               'Angiver om anlaeg er til raadighed';
Parameter OnF(f)               'Angiver om drivmiddel er til raadighed';
Parameter OnS(s)               'Angiver om lager er til raadighed';
Parameter OnM(moall)           'Angiver om en given maaned er aktiv';
Parameter Hours(moall)         'Antal timer i maaned';
Parameter AvailDaysU(moall,u)  'Antal raadige dage';
Parameter ShareAvailU(u,moall) 'Andel af fuld r�dighed p� m�nedsbasis';
Parameter ShareBypass(moall)   'Andel af bypass-drift p� m�nedsbasis';
Parameter Peget(moall)       'Elektrisk egetforbrug KKV-anl�gget';
Parameter HoursBypass(moall) 'Antal timer med turbine-bypass';

OnU(u)       = DataU(u,'aktiv');
OnF(f)       = DataFuel(f,'aktiv');
Ons(s)       = DataSto(s,'aktiv');
OnM(moall)   = Prognoses(moall,'aktiv');
Hours(moall) = 24 * Prognoses(moall,'ndage');

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


# Ovn3 er KV-anl�g med mulighed for turbine-bypass-drift.
ShareBypass(mo) = max(0.0, min(1.0, Prognoses(mo,'Bypass') / (24 * Prognoses(mo,'Ovn3')) ));
HoursBypass(mo) = Prognoses(mo,'Bypass');
Peget(mo)       = EgetforbrugKVV * (AvailDaysU(mo,'Ovn3'));  #---   - HoursBypass(mo));

#--- display mo, OnU, OnF, OnM, Hours, AvailDaysU, ShareAvailU, ShareBypass;

# Rimelighedskontrol af inputtabeller.
loop (labDataU $(NOT sameas(labDataU,'KapMin') AND NOT sameas(labDataU,'MinLast')),
  tmp1 = sum(u, DataU(u,labDataU));
  tmp2 = ord(labDataU);
  if (tmp1 EQ 0, 
    display tmp2;
    abort "ERROR: Mindst �n kolonne (se tmp2) i DataU summer til nul.";
  );
);

loop (labDataSto $(NOT sameas(labDataSto,'Aktiv') AND NOT sameas(labDataSto,'LoadMin') AND NOT sameas(labDataSto,'LossRate')),
  tmp1 = sum(s, DataSto(s,labDataSto));
  tmp2 = ord(labDataSto);
  if (tmp1 EQ 0, 
    display tmp2;
    abort "ERROR: Mindst �n kolonne (se tmp2) i DataSto summer til nul.";
  );
);

singleton set labPrognSingle(labProgn);
$OffOrder
loop (labProgn,
  labPrognSingle(labProgn) = yes;
  tmp1 = sum(moall, Prognoses(moall,labProgn));
  if (tmp1 EQ 0, 
    display labPrognSingle;
    abort "ERROR: Mindst �n kolonne (se labPrognSingle) i Prognoses summer til nul.";
  );
);
$OnOrder

loop (labDataFuel,
  tmp1 = sum(f, DataFuel(f,labDataFuel));
  tmp2 = ord(labDataFuel);
  if (tmp1 EQ 0, 
    display tmp2;
    abort "ERROR: Mindst �n kolonne (se tmp2) i DataFuel summer til nul.";
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
      abort "ERROR: Mindst �n r�kke (se bound=tmp3, fa=tmp2) i FuelBounds summer til nul.";
    );
  );
);
$OnOrder

# Produktionsanl�g og k�lere.
Parameter MinLhvMWh(u)   'Mindste braendvaerdi affaldsanlaeg GJ/ton';
Parameter MaxLhvMWh(u)   'St�rste braendvaerdi affaldsanlaeg GJ/ton';
Parameter MinTon(u)      'Mindste indfyringskapacitet ton/h';
Parameter MaxTon(u)      'Stoerste indfyringskapacitet ton/h';
Parameter KapMin(u)      'Mindste modtrykslast MWq';
Parameter KapNom(u)      'Stoerste modtrykskapacitet MWq';
Parameter KapMax(u)      'Stoerste samlede varmekapacitet MWq';
Parameter KapRgk(u)      'RGK kapacitet MWq';
Parameter KapRgk(u)      'RGK kapacitet MWq';
Parameter EtaQ(u)        'Varmevirkningsgrad';
Parameter EtaRgk(u)      'Varmevirkningsgrad';
Parameter EtaE(u)        'RGK kapacitet MWq';
Parameter EtaE(u)        'RGK kapacitet MWq';
Parameter DvMWhq(u)      'DV-omkostning pr. MWhf';
Parameter DvTime(u)      'DV-omkostning pr. driftstimer'; 

MinLhvMWh(ua) = DataU(ua,'MinLhv') / 3.6;
MaxLhvMWh(ua) = DataU(ua,'MaxLhv') / 3.6;
MinTon(ua)    = DataU(ua,'MinTon');
MaxTon(ua)    = DataU(ua,'Maxton');
KapMin(u)     = DataU(u, 'KapMin');
KapRgk(ua)    = DataU(ua,'KapRgk');
KapNom(u)     = DataU(u, 'KapNom');
KapMax(u)     = KapNom(u) + KapRgk(u);
EtaE(u)       = DataU(u,'EtaE');
EtaQ(u)       = DataU(u,'EtaQ');
EtaRgk(u)     = DataU(u,'KapRgk') / DataU(u,'KapNom') * EtaQ(u);
DvMWhq(u)     = DataU(u,'DvMWhq');
DvTime(u)     = DataU(u,'DvTime');

#--- display MinLhvMWh, MinTon, MaxTon, KapMin, KapNom, KapRgk, KapMax, EtaE, EtaQ, EtaRgk, DvMWhq, DvTime;

# Lagre. Parametre g�res alment periodeafh�ngige, da det giver max. fleksiblitet ift. scenarie-specifikation.
Parameter StoLoadInitF(s,f)          'Initial lagerbeholdning for hvert br�ndsel';
Parameter StoLoadMin(s,moall)        'Min. lagerbeholdning';
Parameter StoLoadMax(s,moall)        'Max. lagerbeholdning';
Parameter StoDLoadMax(s,moall)       'Max. lager�ndring i periode';
Parameter StoLoadCostRate(s,moall)   'Omkostning for opbevaring';
Parameter StoDLoadCostRate(s,moall)  'Omkostning for lager�ndring';
Parameter StoLossRate(s,moall)       'Max. lagertab ift. forrige periodes beholdning';
Parameter StoFirstReset(s)           'Antal initielle perioder som omslutter f�rste nulstiling af lagerstand';
Parameter StoIntvReset(s)            'Antal perioder som omslutter f�rste nulstiling af lagerstand, efter f�rste nulstilling';

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
#--- Parameter FuelBoundsModif(f,bound,moall) 'Maengdegraenser for drivmidler som inddrager anl�gsr�dighed';
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

fpospris(f)       = yes;
fpospris(f)       = DataFuel(f,'pris') GE 0.0;
fnegpris(f)       = NOT fpospris(f);
fbiogen(f)        = fa(f) AND (DataFuel(f,'CO2kgGJ') EQ 0);

MinTonnageYear(f) = DataFuel(f,'minTonnage');
MaxTonnageYear(f) = DataFuel(f,'maxTonnage');
LhvMWh(f)         = DataFuel(f,'brandv') / 3.6;

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

# EaffGross skal v�re mininum af energiindhold af r�dige m�ngder affald hhv. affaldsanl�ggets fuldlastkapacitet.
Parameter EaffGross(moall)     'Max energiproduktion for affaldsanlaeg MWh';
Parameter QaffMmax(ua,moall)   'Max. modtryksvarme fra affaldsanl�g';
Parameter QrgkMax(ua,moall)    'Max. RGK-varme fra affaldsanl�g';
Parameter QaffTotalMax(moall)  'Max. total varme fra affaldsanl�g';
QaffMmax(ua,moall)  = min(ShareAvailU(ua,moall) * Hours(moall) * KapNom(ua), [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelBounds(fa,'max',moall) * EtaQ(ua) * LhvMWh(fa))]) $OnU(ua);
QrgkMax(ua,moall)   = KapRgk(ua) / KapNom(ua) * QaffMmax(ua,moall);
QaffTotalMax(moall) = sum(ua $OnU(ua), ShareAvailU(ua,moall) * (QaffMmax(ua,moall) + QrgkMax(ua,moall)) );
#--- EaffGross(moall)    = QaffTotalMax(moall) + PowerProd(moall);
#--- display QaffMmax, QrgkMax, QaffTotalMax, EaffGross;

Parameter TaxATLMax(moall) 'Oevre graense for ATL';
Parameter RgkRabatMax(moall) 'Oevre graense for ATL rabat';
Parameter QRgkMissMax     'Oevre graense for QRgkMiss';
TaxATLMax(mo) = sum(ua $OnU(ua), ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua)) * TaxAtlMWh(mo);
RgkRabatMax(mo) = RgkRabatSats * TaxATLMax(mo);
QRgkMissMax = 2 * RgkRabatMinShare * sum(ua $OnU(ua), 31 * 24 * KapNom(ua));  # Faktoren 2 er en sikkerhedsfaktor mod inffeasibilitet.
#--- display TaxATLMax, RgkRabatMax, QRgkMissMax;

$If not errorfree $exit

# Ekl�ring af parametre til iterativ l�sning af uline�r afgiftsberegning.
Parameter Phi(phiKind,moall)           'Aktuel v�rdi af Phi = Fbiogen/F';


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
                                                
Positive variable QInfeasDir(dir,moall)         'Virtual varmedraen og -kilde [MWhq]';

# @@@@@@@@@@@@@@@@@@@@@@@@  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG
IncomeTotal.up(moall) = 1E+8;
IncomeAff.up(f,moall) = 1E+8;
RgkRabat.up(moall)    = 1E+8;
# @@@@@@@@@@@@@@@@@@@@@@@@  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG


#--- # Initial lagerbeholdning.  DISABLED: H�ndteres nu i equation ZQ_StoDLoadFMin.
#--- $OffOrder
#--- StoLoadF.fx(sa,fa,mo-1) $(ord(mo) EQ 1) = StoLoadInitF(sa,fa);
#--- $OnOrder

# Fiksering af ikke-forbundne anl�g+drivmidler, samt af ikke-aktive anlaeg og ikke-aktive drivmidler.
loop (u $(NOT OnU(u)),
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

loop (s $(NOT OnS(s)),
  bOnSto.fx(s,mo)      = 0.0;
  StoLoad.fx(s,mo)     = 0.0;
  StoLoss.fx(s,mo)     = 0.0;
  StoDLoad.fx(s,mo)    = 0.0;
  StoDLoadAbs.fx(s,mo) = 0.0;
  StoCostAll.fx(s,mo)  = 0.0;
  StoDLoadF.fx(s,f,mo) = 0.0;
);

loop (f $(NOT OnF(f)),
  CostsPurchaseF.fx(f,mo)    = 0.0;
  IncomeAff.fx(f,mo)         = 0.0;
  CO2emisF.fx(f,mo,typeCO2)  = 0.0;
  FuelDelivT.fx(f,mo)        = 0.0;
  FuelConsT.fx(u,f,mo)       = 0.0;
  FuelConsP.fx(f,mo)         = 0.0;
  StoDLoadF.fx(s,f,mo)       = 0.0;
);

loop (f,
  if (fpospris(f),
    CostsPurchaseF.fx(f,mo) = 0.0;
  else
    IncomeAff.fx(f,mo) = 0.0;
  );
);

# Fiksering (betinget) af lagerbeholdning i sidste m�ned.
$OffOrder
loop (s $OnS(s),
  if (DataSto(s,'ResetLast') NE 0, 
    bOnSto.fx(s,mo)  $(ord(mo) EQ NactiveM) = 0; 
    StoLoad.fx(s,mo) $(ord(mo) EQ NactiveM) = 0.0;
  );
);
$OnOrder

# Fiksering af RGK-produktion til nul p� ikke-aktive affaldsanlaeg.
loop (ua $(NOT OnU(ua)), bOnRgk.fx(ua,mo) = 0.0; );

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
#   Den p�l�gges en overskudsvarmeafgift, som kan resultere i en lavere VPO end REFA kan pr�stere med indk�bt affald hhv. flis.
#   Dermed er det ikke umiddelbart let at afg�re, om NS-varmen indeb�rer en omkostning for REFA.
#   NS-varmen leveres h�jst i m�nederne okt-feb med tyngden i nov-jan, en periode hvor REFAs affaldsanl�g er udlastede.

ZQ_Obj  ..  NPV  =E=  sum(mo,
                         IncomeTotal(mo)
                         + Gain_Ovn3 * Q('Ovn3',mo)
                         - CostsTotal(mo)
                         - [ 
                             + Penalty_bOnU * sum(u $OnU(u), bOnU(u,mo))
                             + Penalty_QRgkMiss * QRgkMiss(mo)
                             + [Penalty_QInfeas * sum(dir, QInfeasDir(dir,mo))] $OnQInfeas
                             + [Penalty_AffaldsGensalg * sum(f $OnF(f), FuelResaleT(f,mo))]
                           ] );

ZQ_IncomeTotal(mo)   .. IncomeTotal(mo)   =E=  sum(fa $OnF(fa), IncomeAff(fa,mo)) + RgkRabat(mo) + IncomeElec(mo) + IncomeHeat(mo);

ZQ_IncomeElec(mo)   ..  IncomeElec(mo)    =E=  Pnet(mo) * (PowerPrice(mo) - TariffElProd(mo));

ZQ_IncomeHeat(mo)   ..  IncomeHeat(mo)    =E=  VarmeSalgspris * sum(u $(OnU(u) AND up(u) AND urefa(u)), Q(u,mo));

ZQ_IncomeAff(fa,mo)  .. IncomeAff(fa,mo)  =E=  FuelDelivT(fa,mo) * FuelBounds(fa,'ModtPris',mo) $(OnF(fa) AND fpospris(fa));

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
#---                                  sum(f $(OnF(f) AND fown(f,owner) AND fnegpris(f)), CostsPurchaseF(f,mo))
#---                                  + sum(f $(OnF(f) AND fown(f,owner)), TaxCO2F(f,mo) + TaxNOxF(f,mo))
#---                                  + TaxEnr(mo) $sameas(owner,'gsf')
#---                                  + (TaxAFV(mo) + TaxATL(mo) + CostsETS(mo)) $sameas(owner,'refa');


ZQ_CostsPurchaseF(f,mo) $(OnF(f) AND fnegpris(f)) .. CostsPurchaseF(f,mo)  =E=  FuelDelivT(f,mo) * (-FuelBounds(f,'ModtPris',mo));

# Beregning af afgiftspligtigt affald.

ZQ_FuelConsP(fa,mo) $OnF(fa) .. FuelConsP(fa,mo)  =E=  sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelConsT(ua,fa,mo) * LhvMWh(fa));

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
Parameter QtotalAffMax(moall) 'Max. aff-varme';
QtotalAffMax(mo) = sum(ua $OnU(ua), (EtaQ(ua) + EtaRgk(ua)) * sum(fa $(OnF(fa) AND u2f(ua,fa)), LhvMWh(fa) * FuelBounds(fa,'max',mo)) );
display QtotalAffMax;

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

# Den fulde CO2-emission uden hensyntagen til fradrag for elproduktion.
ZQ_CO2emisF(f,mo,typeCO2) $OnF(f) .. CO2emisF(f,mo,typeCO2)  =E=  sum(u $(OnU(u) AND u2f(u,f)), FuelConsT(u,f,mo)) * CO2potenTon(f,typeCO2,mo);
ZQ_CO2emisAff(mo,typeCO2)         .. CO2emisAff(mo,typeCO2)  =E=  QudenRgk(mo) * CO2ContentAff(mo) $sameas(typeCO2,'afgift') + sum(fa, CO2emisF(fa,mo,typeCO2)) $sameas(typeCO2,'kvote');

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

# Prioritering af anl�gsdrift:
ZQ_PrioUp(uprio,up,mo) $(OnU(uprio) AND OnU(up) AND AvailDaysU(mo,uprio) AND AvailDaysU(mo,up)) ..  bOnU(up,mo)  =L=  bOnU(uprio,mo);

#TODO Beregning herunder skal korrigeres - br�ndsel til elproduktion samt biogent skal undtages.


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
Equation ZQ_PbrutMax(moall)              'Brutto elproduktion uden hensyn til bypass';
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
Equation  ZQ_Qmin(u,moall)               'Sikring af nedre graense p� varmeproduktion';
Equation  ZQ_QMax(u,moall)               'Aktiv status begraenset af total raadighed';
Equation  ZQ_bOnRgk(ua,moall)            'Angiver om RGK er aktiv';


# Beregning af elproduktion. Det antages, at oms�tning fra bypass-damp til fjernvarme er 1-til-1, dvs. 100 pct. effektiv bypass-drift.
ZQ_PbrutMax(mo)$OnU('Ovn3')  .. PbrutMax(mo) =E=  EtaE('Ovn3') * sum(fa $(OnF(fa) AND u2f('Ovn3',fa)), FuelConsT('Ovn3',fa,mo) * LhvMWh(fa));
ZQ_Pbrut(mo)   $OnU('Ovn3')  .. Pbrut(mo)    =E=  PbrutMax(mo) * (1 - ShareBypass(mo));
ZQ_Pnet(mo)    $OnU('Ovn3')  .. Pnet(mo)     =E=  Pbrut(mo) - Peget(mo) * (1 - ShareBypass(mo));  # Peget har taget hensyn til bypass.
ZQ_Qbypass(mo) $OnU('Ovn3')  .. Qbypass(mo)  =E=  (PbrutMax(mo) - Peget(mo)) * ShareBypass(mo);

ZQ_Qdemand(mo)               ..  Qdemand(mo)   =E=  sum(up $OnU(up), Q(up,mo)) - sum(uv $OnU(uv), Q(uv,mo)) + [QInfeasDir('source',mo) - QInfeasDir('drain',mo)] $OnQInfeas;
ZQ_Qaff(ua,mo)     $OnU(ua)  ..  Q(ua,mo)      =E=  [QaffM(ua,mo) + Qrgk(ua,mo)] + Qbypass(mo) $sameas(ua,'Ovn3');
ZQ_QaffM(ua,mo)    $OnU(ua)  ..  QaffM(ua,mo)  =E=  [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelConsT(ua,fa,mo) * EtaQ(ua) * LhvMWh(fa))] $OnU(ua);
ZQ_QaffMmax(ua,mo) $OnU(ua)  ..  QAffM(ua,mo)  =L=  QaffMmax(ua,mo);    
ZQ_Qrgk(ua,mo)     $OnU(ua)  ..  Qrgk(ua,mo)   =L=  KapRgk(ua) / KapNom(ua) * QaffM(ua,mo);
ZQ_QrgkMax(ua,mo)  $OnU(ua)  ..  Qrgk(ua,mo)   =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);

ZQ_Qaux(uaux,mo) $OnU(uaux)  ..  Q(uaux,mo)  =E=  [sum(faux $(OnF(faux) AND u2f(uaux,faux)), FuelConsT(uaux,faux,mo) * EtaQ(uaux) * LhvMWh(faux))] $OnU(uaux);

ZQ_CoolMax(mo)               ..  sum(uv $OnU(uv), Q(uv,mo))  =L=  sum(ua $OnU(ua), Q(ua,mo));

#OBS: Qbypass indg�r i Q('Ovn3',mo).
ZQ_QMin(u,mo)      $OnU(u)   ..  Q(u,mo)      =G=  ShareAvailU(u,mo) * Hours(mo) * KapMin(u) * bOnU(u,mo) + Qbypass(mo) $sameas(u,'Ovn3');   #  Restriktionen p� timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
ZQ_QMax(u,mo)      $OnU(u)   ..  Q(u,mo)      =L=  ShareAvailU(u,mo) * Hours(mo) * KapMax(u) * bOnU(u,mo) + Qbypass(mo) $sameas(u,'Ovn3');
ZQ_bOnRgk(ua,mo)   $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);

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

Equation ZQ_StoDLoad(s,moall)   'Samlet lagerm�ngde';
Equation ZQ_FuelCons(f,moall)   'Relation mellem afbr�ndt, leveret og lagerf�rt br�ndsel (if any)';

ZQ_StoDLoad(sa,mo) $OnS(sa) ..  sum(fsto $(OnF(fsto) AND s2f(sa,fsto)), StoDLoadF(sa,fsto,mo))  =E=  StoDLoad(sa,mo);
ZQ_FuelCons(f,mo)  $OnF(f)  ..  sum(u $(OnU(u) AND u2f(u,f)), FuelConsT(u,f,mo))                =E=  FuelDelivT(f,mo) - [sum(sa $(OnS(sa) and s2f(sa,f)), StoDLoadF(sa,f,mo))] $fsto(f);

# Gr�nser for leverancer.

Equation  ZQ_FuelMin(f,moall)   'Mindste drivmiddelforbrug p� m�nedsniveau';
Equation  ZQ_FuelMax(f,moall)   'Stoerste drivmiddelforbrug p� m�nedsniveau';

#-- ZQ_FuelMin(f,mo) $(OnF(f) AND fdis(f) AND NOT fsto(f) AND NOT ffri(f))  ..  sum(u $(OnU(u)  AND u2f(u,f)),  FuelDelivT(u,f,mo))   =G=  FuelBounds(f,'min',mo);
#-- ZQ_FuelMax(f,mo) $(OnF(f) AND fdis(f)) ..  sum(u $(OnU(u)  AND u2f(u,f)),  FuelDelivT(u,f,mo))  =L=  FuelBounds(f,'max',mo) * 1.0001;  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.

#--- ZQ_FuelMin(f,mo) $(OnF(f) AND fdis(f) AND NOT fsto(f) AND NOT ffri(f))  ..  FuelDelivT(f,mo)  =G=  FuelBounds(f,'min',mo);
ZQ_FuelMin(f,mo) $(OnF(f) AND fdis(f) AND NOT ffri(f))  ..  FuelDelivT(f,mo) + FuelResaleT(f,mo)  =G=  FuelBounds(f,'min',mo);
ZQ_FuelMax(f,mo) $(OnF(f) AND fdis(f))                  ..  FuelDelivT(f,mo) + FuelResaleT(f,mo)  =L=  FuelBounds(f,'max',mo) * 1.0001;  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.

Equation  ZQ_FuelMinYear(f)  'Mindste braendselsforbrug p� �rsniveau';
Equation  ZQ_FuelMaxYear(f)  'Stoerste braendselsforbrug p� �rsniveau';

#--- ZQ_FuelMinYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDelivT(u,fdis,mo)))  =G=  MinTonnageYear(fdis) * card(mo) / 12;
#--- ZQ_FuelMaxYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDelivT(u,fdis,mo)))  =L=  MaxTonnageYear(fdis) * card(mo) / 12;

ZQ_FuelMinYear(fdis)  $(OnF(fdis) AND FALSE) ..  sum(mo $OnM(mo), FuelDelivT(fdis,mo) - FuelResaleT(fdis,mo))  =G=  MinTonnageYear(fdis) * card(mo) / 12;
ZQ_FuelMaxYear(fdis)  $(OnF(fdis) AND FALSE) ..  sum(mo $OnM(mo), FuelDelivT(fdis,mo) - FuelResaleT(fdis,mo))  =L=  MaxTonnageYear(fdis) * card(mo) / 12;

# Krav til frie affaldsfraktioner.
Equation ZQ_FuelDelivFreeSum(f)              'Aarstonnage af frie affaldsfraktioner';
Equation ZQ_FuelMinFreeNonStorable(f,moall)  'Ligeligt tonnageforbrug af ikke-lagerbare frie affaldsfraktioner';
#--- Equation ZQ_FuelMinFree(f,moall)     'Mindste maengde ikke-lagerbare frie affaldsfraktioner';
#--- Equation ZQ_FuelMaxFree(f,moall)     'stoerste maengde til ikke-lagerbare frie affaldsfraktioner';

ZQ_FuelDelivFreeSum(ffri) $(OnF(ffri) AND card(mo) GT 1)                             ..  FuelDelivFreeSumT(ffri)  =E=  sum(mo, FuelDelivT(ffri,mo));
ZQ_FuelMinFreeNonStorable(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri) AND card(mo) GT 1) ..  FuelDelivT(ffri,mo)      =E=  FuelDelivFreeSumT(ffri) / card(mo);
#--- ZQ_FuelDelivFreeSum(ffri) $(OnF(ffri) AND card(mo) GT 1)                             .. FuelDelivFreeSumT(ffri)  =E=  sum(mo, sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDelivT(ua,ffri,mo) ) );
#--- ZQ_FuelMinFreeNonStorable(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri) AND card(mo) GT 1) ..  sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDelivT(ua,ffri,mo))  =E=  FuelDelivFreeSumT(ffri) / card(mo);
#--- ZQ_FuelMinFree(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri)) ..  sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDelivT(ua,ffri,mo))  =G=  FuelDelivFreeSumT(ffri);
#--- ZQ_FuelMaxFree(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri)) ..  sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDelivT(ua,ffri,mo))  =L=  FuelDelivFreeSumT(ffri) * 1.0001;

# Restriktioner p� tonnage og braendvaerdi for affaldsanlaeg.
Equation ZQ_MinTonnage(u,moall)    'Mindste tonnage for affaldsanlaeg';
Equation ZQ_MaxTonnage(u,moall)    'Stoerste tonnage for affaldsanlaeg';
Equation ZQ_MinLhvAffald(u,moall)  'Mindste braendvaerdi for affaldsblanding';

#--- ZQ_MaxTonnage(ua,mo) $OnU(ua)    ..  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDelivT(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * KapTon(ua);
#--- ZQ_MinLhvAffald(ua,mo) $OnU(ua)  ..  MinLhvMWh(ua) * sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDelivT(ua,fa,mo))
#---                                       =L=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDelivT(ua,fa,mo) * LhvMWh(fa));

ZQ_MinTonnage(ua,mo) $OnU(ua)    ..  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelConsT(ua,fa,mo))  =G=  ShareAvailU(ua,mo) * Hours(mo) * MinTon(ua);
ZQ_MaxTonnage(ua,mo) $OnU(ua)    ..  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelConsT(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * MaxTon(ua);
ZQ_MinLhvAffald(ua,mo) $OnU(ua)  ..  MinLhvMWh(ua) * sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelConsT(ua,fa,mo))  =L=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelConsT(ua,fa,mo) * LhvMWh(fa));

# Lagerdisponering.
Equation ZQ_StoCostAll(s,moall)       'Samlet lageromkostning';
Equation ZQ_StoCostLoad(s,moall)      'Lageromkostning opbevaring';
Equation ZQ_StoCostDLoad(s,moall)     'Lageromkostning transport';
Equation ZQ_StoLoadMin(s,moall)       'Nedre gr�nse for lagerbeholdning';
Equation ZQ_StoLoadMax(s,moall)       '�vre gr�nse for lagerbeholdning';
Equation ZQ_StoLoad(s,moall)          'Lagerbeholdning og -�ndring';
Equation ZQ_StoLoss(s,moall)          'Lagertab proport. til beholdning';
Equation ZQ_StoDLoadMax(s,moall)      'Max. lager�ndring';
Equation ZQ_StoDLoadAbs1(s,moall)     'Abs funktion p� lager�ndring StoDLoad';
Equation ZQ_StoDLoadAbs2(s,moall)     'Abs funktion p� lager�ndring StoDLoad';
Equation ZQ_StoFirstReset(s,moall)    'F�rste nulstilling af lagerbeholdning';
Equation ZQ_StoResetIntv(s,moall)     '�vrige nulstillinger af lagerbeholdning';

ZQ_StoCostAll(s,mo)   $OnS(s)  ..  StoCostAll(s,mo)    =E=  StoCostLoad(s,mo) + StoCostDLoad(s,mo);
ZQ_StoCostLoad(s,mo)  $OnS(s)  ..  StoCostLoad(s,mo)   =E=  StoLoadCostRate(s,mo) * StoLoad(s,mo);
ZQ_StoCostDLoad(s,mo) $OnS(s)  ..  StoCostDLoad(s,mo)  =E=  StoDLoadCostRate(s,mo) * StoDLoadAbs(s,mo);


ZQ_StoLoadMin(s,mo) $OnS(s) ..  StoLoad(s,mo)      =G=  StoLoadMin(s,mo);
ZQ_StoLoadMax(s,mo) $OnS(s) ..  StoLoad(s,mo)      =L=  StoLoadMax(s,mo);

# Lageret af en given fraktion kan h�jst t�mmes.

Equation ZQ_StoDLoadFMin(s,f,moall)  'Lagerbeholdnings�ndring af given fraktion';
Equation ZQ_StoLoadSum(s,moall)     'Sum af fraktioner p� givet lager';

# Sikring af at StoDLoadF ikke overstiger lagerbeholdningen fra forrige m�ned.
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

# Initialisering.
ConvergenceFound = FALSE;
Phi(phiKind,mo)             = 0.2;    # Startg�t (b�r v�re positivt).
PhiIter(phiKind,mo,'iter0') = Phi(phiKind,mo);
dPhiIter(phiKind,mo,'iter0') = 0.0;

loop (iter $(ord(iter) GE 2),
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
  loop (mo,
    dPhi(phiKind)       = PhiIter(phiKind,mo,iter) - PhiIter(phiKind,mo,iter-1);
    dPhiChange(phiKind) = abs(abs(dPhi(phiKind) - abs(dPhiIter(phiKind,mo,iter-1))));

    dPhiIter(phiKind,mo,iter)       = dPhi(phiKind);
    dPhiChangeIter(phiKind,mo,iter) = dPhiChange(phiKind);

    loop (phiKind,
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
    #--- break;
    # Udf�r endnu en iteration, s� modelvariable bliver opdateret  med seneste justering af phi.
  else
    display "Endnu ingen konvergens opn�et.";
  );
);


# ------------------------------------------------------------------------------------------------
# Efterbehandling af resultater.
# ------------------------------------------------------------------------------------------------

# Tilbagef�ring til NPV af penalty costs og omkostninger fra ikke-inkluderede anlaeg og braendsler samt gevinst for Ovn3-varme.
Scalar NPV_REFA_V, NPV_Total_V;
Scalar Penalty_bOnUTotal, Penalty_QRgkMissTotal, Penalty_AffaldsGensalgTotal;
Scalar Gain_Ovn3Total 'Samlede virtuelle gevinst';

Penalty_bOnUTotal           = Penalty_bOnU * sum(mo, sum(u, bOnU.L(u,mo)));
Penalty_QRgkMissTotal       = Penalty_QRgkMiss * sum(mo, QRgkMiss.L(mo));
Penalty_AffaldsGensalgTotal = Penalty_AffaldsGensalg * sum(mo, sum(f $OnF(f), FuelResaleT.L(f,mo)));
Gain_Ovn3Total              = Gain_Ovn3 * sum(mo, Q.L('Ovn3',mo));

# NPV_Total_V er den samlede NPV med tilbagef�rte penalties.
NPV_Total_V = NPV.L + Penalty_bOnUTotal + Penalty_QRgkMissTotal + Penalty_AffaldsGensalgTotal - Gain_Ovn3Total;

# NPV_REFA_V er REFAs andel af NPV med tilbagef�rte penalties og tilbagef�rte GSF-omkostninger.
NPV_REFA_V  = NPV_Total_V + sum(mo, CostsTotalOwner.L('gsf',mo));

#---          + sum(ugsf $(OnU(ugsf)), CostsU.L(ugsf,mo))
#---          + sum(fgsf $(OnF(fgsf)), CostsPurchaseF.L(fgsf,mo) + TaxCO2F.L(fgsf,mo) + TaxNOxF.L(fgsf,mo)) + TaxEnr.L(mo)
#---        );

#--- display Penalty_bOnUTotal, Penalty_QRgkMissTotal, NPV.L, NPV_Total_V, NPV_REFA_V;


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


# Sammenfatning af aggregerede resultater p� maanedsniveau.
set topics / FJV-behov, Var-Varmeproduktions-Omk-Total, Var-Varmeproduktions-Omk-REFA,
             REFA-Daekningsbidrag, REFA-Total-Var-Indkomst, REFA-Affald-Modtagelse, REFA-RGK-Rabat, REFA-Elsalg,
             REFA-Total-Var-Omkostning, REFA-AnlaegsVarOmk, REFA-BraendselOmk, REFA-Afgifter, REFA-CO2-Kvoteomk, REFA-Lageromkostning,
             REFA-CO2-Emission-Afgift, REFA-CO2-Emission-Kvote, REFA-El-produktion-Brutto, REFA-El-produktion-Netto,
             REFA-Total-Varme-Produktion, REFA-Modtryk-Varme, REFA-Bypass-Varme, REFA-RGK-Varme, REFA-RGK-Andel, REFA-Bortkoelet-Varme,
             GSF-Total-Var-Omkostning,  GSF-AnlaegsVarOmk,  GSF-BraendselOmk,  GSF-Afgifter,  GSF-CO2-Emission,  GSF-Total-Varme-Produktion
             /;

Parameter DataCtrl_V(labDataCtrl);
Parameter DataU_V(u,labDataU);
Parameter DataSto_V(s,labDataSto);
Parameter DataFuel_V(f,labDataFuel);
Parameter Prognoses_V(labProgn,moall)      'Prognoser transponeret';
Parameter FuelBounds_V(f,bound,moall);
Parameter FuelDeliv_V(f,moall)             'Leveret br�ndsel';
Parameter FuelCons_V(u,f,moall)            'Afbr�ndt br�ndsel for givet anl�g';
Parameter StoDLoadF_V(s,f,moall)           'Lager�ndring for givet lager og br�ndsel';
Parameter StoLoadF_V(s,f,moall)            'Lagerbeholdning for givet lager og br�ndsel';
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
Parameter RefaElproduktionBrutto_V(moall)  'REFA brutto elproduktion [MWhe]';
Parameter RefaElproduktionNetto_V(moall)   'REFA netto elproduktion [MWhe]';

Parameter RefaVarmeProd_V(moall)           'REFA Total varmeproduktion [MWhq]';
Parameter RefaModtrykProd_V(moall)         'REFA Total modtryksvarmeproduktion [MWhq]';
Parameter RefaBypassVarme_V(moall)         'REFA Bypass-varme p� Ovn3 [MWhq]';
Parameter RefaRgkProd_V(moall)             'REFA RGK-varmeproduktion [MWhq]';
Parameter RefaRgkShare_V(moall)            'RGK-varmens andel af REFA energiproduktion';
Parameter RefaBortkoeletVarme_V(moall)     'REFA bortkoelet varme [MWhq]';
Parameter VarmeVarProdOmkTotal_V(moall)    'Variabel varmepris p� tvaers af alle produktionsanl�g DKK/MWhq';
Parameter VarmeVarProdOmkRefa_V(moall)     'Variabel varmepris p� tvaers af REFA-produktionsanl�g DKK/MWhq';
Parameter RefaLagerBeholdning_V(s,moall)   'Lagerbeholdning [ton]';
Parameter Usage_V(u,moall)                 'Kapacitetsudnyttelse af anl�g';
Parameter LhvCons_V(u,moall)               'Realiseret br�ndv�rdi';
Parameter Tonnage_V(u,moall)               'Tonnage afbr�ndt pr. time';

Parameter GsfTotalVarOmk_V(moall)          'Guldborgsund Forsyning Total indkomst [DKK]';
Parameter GsfAnlaegsVarOmk_V(moall)        'Guldborgsund Forsyning Var anlaegs omk [DKK]';
Parameter GsfBraendselsVarOmk_V(moall)     'Guldborgsund Forsyning Var braendsels omk. [DKK]';
Parameter GsfAfgifter_V(moall)             'Guldborgsund Forsyning Afgifter [DKK]';
Parameter GsfCO2emission_V(moall)          'Guldborgsund Forsyning CO2 emission [ton]';
Parameter GsfTotalVarmeProd_V(moall)       'Guldborgsund Forsyning Total Varmeproduktion [MWhq]';

loop (mo $(NOT sameas(mo,'mo0')),
  RefaAffaldModtagelse_V(mo)            = sum(fa $OnF(fa), IncomeAff.L(fa,mo));
  RefaRgkRabat_V(mo)                    = RgkRabat.L(mo);
  RefaElsalg_V(mo)                      = IncomeElec.L(mo);
  RefaTotalVarIndkomst_V(mo)            = RefaAffaldModtagelse_V(mo) + RefaRgkRabat_V(mo) + RefaElsalg_V(mo);
  OverView('REFA-Affald-Modtagelse',mo) = max(tiny, RefaAffaldModtagelse_V(mo) );
  OverView('REFA-RGK-Rabat',mo)         = max(tiny, RefaRgkRabat_V(mo) );
  OverView('REFA-Elsalg',mo)            = max(tiny, RefaElsalg_V(mo) );

  RefaAnlaegsVarOmk_V(mo)                  = sum(urefa $OnU(urefa), CostsU.L(urefa,mo));
  RefaBraendselsVarOmk_V(mo)               = sum(frefa, CostsPurchaseF.L(frefa,mo));
  RefaAfgifter_V(mo)                       = TaxAFV.L(mo) + TaxATL.L(mo) + sum(frefa, TaxCO2Aff.L(mo) + TaxNOxF.L(frefa,mo));
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

# TODO: Skal tilrettes �ndrede CO2-opg�relser.
  RefaCO2emission_V(mo,typeCO2)            = max(tiny, sum(frefa $OnF(frefa), CO2emisF.L(frefa,mo,typeCO2)) );
  RefaElproduktionBrutto_V(mo)             = max(tiny, Pbrut.L(mo));
  RefaElproduktionNetto_V(mo)              = max(tiny, Pnet.L(mo));
  
  OverView('REFA-CO2-Emission-afgift',mo)  = RefaCO2emission_V(mo,'afgift');
  OverView('REFA-CO2-Emission-kvote',mo)   = RefaCO2emission_V(mo,'kvote');
  OverView('REFA-El-produktion-Brutto',mo) = RefaElproduktionBrutto_V(mo);
  OverView('REFA-El-produktion-Netto',mo)  = RefaElproduktionNetto_V(mo);

  RefaVarmeProd_V(mo)       = max(tiny, sum(uprefa $OnU(uprefa), Q.L(uprefa,mo)) );
  RefaModtrykProd_V(mo)     = max(tiny, sum(ua $OnU(ua), QAffM.L(ua,mo)) );
  RefaBypassVarme_V(mo)     = max(tiny, Qbypass.L(mo));
  RefaRgkProd_V(mo)         = max(tiny, sum(ua $OnU(ua), Qrgk.L(ua,mo)) );
  RefaRgkShare_V(mo)        = max(tiny, sum(ua $OnU(ua), Qrgk.L(ua,mo)) / sum(ua $OnU(ua), Q.L(ua,mo)) );
  RefaBortkoeletVarme_V(mo) = max(tiny, sum(uv $OnU(uv), Q.L(uv,mo)) );
  OverView('REFA-Total-Varme-Produktion',mo) = RefaVarmeProd_V(mo);
  OverView('REFA-Modtryk-Varme',mo)          = RefaModtrykProd_V(mo);
  OverView('REFA-Bypass-Varme',mo)          = RefaBypassVarme_V(mo);
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

#---  VarmeVarProdOmkTotal_V(mo) = (sum(u $OnU(u), CostsU.L(u,mo)) + sum(owner, CostsTotalF.L(owner,mo)) - IncomeTotal.L(mo)) / (sum(up, Q.L(up,mo) - sum(uv, Q.L(uv,mo))));
#---  VarmeVarProdOmkRefa_V(mo)  = (sum(urefa, CostsU.L(urefa,mo)) + CostsTotalF.L('refa',mo) - IncomeTotal.L(mo)) / (sum(uprefa, Q.L(uprefa,mo)) - sum(uv, Q.L(uv,mo)));
  VarmeVarProdOmkTotal_V(mo)  = (RefaTotalVarOmk_V(mo) - RefaTotalVarIndkomst_V(mo) + GsfTotalVarOmk_V(mo)) / Qdemand(mo);
  VarmeVarProdOmkRefa_V(mo)   = (RefaTotalVarOmk_V(mo) - RefaTotalVarIndkomst_V(mo)) / (sum(uprefa, Q.L(uprefa,mo)) - sum(uv, Q.L(uv,mo)));
  Overview('FJV-behov',mo)                      = max(tiny, Qdemand(mo));
  OverView('Var-Varmeproduktions-Omk-Total',mo) = ifthen(VarmeVarProdOmkTotal_V(mo) EQ 0.0, tiny, VarmeVarProdOmkTotal_V(mo));
  OverView('Var-Varmeproduktions-Omk-REFA',mo)  = ifthen(VarmeVarProdOmkRefa_V(mo) EQ 0.0,  tiny, VarmeVarProdOmkRefa_V(mo));


  loop (f,
    FuelDeliv_V(f,mo) = max(tiny, FuelDelivT.L(f,mo));
    IncomeFuel_V(f,mo) = IncomeAff.L(f,mo) - CostsPurchaseF.L(f,mo);
    if (IncomeFuel_V(f,mo) EQ 0.0, IncomeFuel_V(f,mo) = tiny; );
  );
  
  FuelCons_V(u,f,mo) = max(tiny, FuelConsT.L(u,f,mo));
  
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
      # Realiseret br�ndv�rdi.
      tmp1 = sum(f $(OnF(f) AND u2f(u,f)), FuelConsT.L(u,f,mo));
      if (tmp1 GT 0.0, 
        LhvCons_V(u,mo) = 3.6 * sum(f $(OnF(f) AND u2f(u,f)), FuelConsT.L(u,f,mo) * LhvMWh(f)) / tmp1;
      );
      # Tonnage indfyret.
      tmp2 = ShareAvailU(u,mo) * Hours(mo);
      if (tmp2 GT 0.0, 
        Tonnage_V(u,mo) = sum(f $(OnF(f) AND u2f(u,f)), FuelConsT.L(u,f,mo)) / tmp2;
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
OnU, OnF, OnM, OnS, Hours, ShareAvailU, EtaQ, KapMin, KapNom, KapRgk, KapMax, Qdemand, LhvMWh, 
Pbrut, Pnet, Qbypass, 
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
RefaElproduktionBrutto_V, 
RefaElproduktionNetto_V,

RefaVarmeProd_V,
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
text="Styringsparameter"  rng=Inputs!B3:B3
par=Schedule              rng=Inputs!B13        cdim=1  rdim=1
text="Schedule"           rng=Inputs!B13:B13
par=DataU_V               rng=Inputs!B19        cdim=1  rdim=1
text="DataU"              rng=Inputs!B19:B19
par=DataSto_V             rng=Inputs!B27        cdim=1  rdim=1
text="DataSto"            rng=Inputs!B27:B27
par=DataFuel_V            rng=Inputs!B38        cdim=1  rdim=1
text="DataFuel"           rng=Inputs!B38:B38
par=Prognoses_V           rng=Inputs!T13        cdim=1  rdim=1
text="Prognoser"          rng=Inputs!T13:T13
par=FuelBounds_V          rng=Inputs!T38        cdim=1  rdim=2
text="FuelBounds"         rng=Inputs!T38:T38

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
par=Q_V                             rng=Overblik!C39         cdim=1  rdim=1
text="Varmem�ngder"                 rng=Overblik!A39:A39
par=FuelDeliv_V                     rng=Overblik!C47         cdim=1  rdim=1
text="Br�ndselsforbrug"             rng=Overblik!A47:A47
par=IncomeFuel_V                    rng=Overblik!C79         cdim=1  rdim=1
text="Br�ndselsindkomst"            rng=Overblik!A79:A79
par=Usage_V                         rng=Overblik!C111        cdim=1  rdim=1
text="Kapacitetsudnyttelse"         rng=Overblik!A111:A111
par=StoLoadAll_V                    rng=Overblik!C120        cdim=1 rdim=1
text="Lagerbeholdning totalt"       rng=Overblik!A120:A120   
text="Lager"                        rng=Overblik!C120:C120   
par=StoLoadF_V                      rng=Overblik!B128        cdim=1 rdim=2
text="Lagerbeh. pr fraktion"        rng=Overblik!A128:A128   
text="Lager"                        rng=Overblik!B128:B128   
text="Fraktion"                     rng=Overblik!C128:C128   
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
