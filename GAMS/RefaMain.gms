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

# ------------------------------------------------------------------------------------------------
# Erklaering af sets
# ------------------------------------------------------------------------------------------------
set bound     'Bounds'         / min, max, lhv, pris, co2andel /;
#--- set mo    'Aarsmaaneder'   / jan, feb, mar, apr, maj, jun, jul, aug, sep, okt, nov, dec /;
#--- set mo    'Aarsmaaneder'   / jan /;
set moall     'Aarsmaaneder'  / mo0 * mo36 /;  # Daekker op til 3 aar.
set mo(moall) 'Aktive maaneder';

set fkind 'Drivm.-typer'  / 1 'affald', 2 'biomasse', 3 'varme', 4 'peakfuel' /;

Set f     'Drivmidler'    / DepoSort, DepoSmaat, DepoNedd, Dagren, AndetBrand, Trae,
                            DagrenRast, DagrenInst, DagrenHandel, DagrenRestau, Erhverv, DagrenErhverv,
                            HandelKontor, Privat, TyskRest, PolskRest, PcbTrae, TraeRekv, Halm, Pulver, FlisAffald,
                            NyAff1, NyAff2, NyAff13 NyAff4, NyAff5,
                            Flis, NSvarme, PeakFuel /;
#--- Set f     'Drivmidler'    / Dagren,
#---                             Flis, NSvarme /;
set fa(f)   'Affaldstyper';
set fb(f)   'Biobraendsler';
set fc(f)   'Overskudsvarme';
set fr(f)   'Peak braendsel';
set fsto(f) 'Lagerbare braendsler';
set fdis(f) 'Braendsler som skal bortskaffes';
set ffri(f) 'Braendsler med fri tonnage';
set faux(f) 'Andre braendsler end affald';

set ukind  'Anlaegstyper'   / 1 'affald', 2 'biomasse', 3 'varme', 4 'peak', 5 'cooler' /;
set u      'Anlaeg'         / ovn2, ovn3, flisk, peak, ns, cooler /;
set up(u)  'Prod-anlaeg'    / ovn2, ovn3, flisk, peak, NS /;
set ua(u)  'Affaldsanlaeg'  / ovn2, ovn3 /;
set ub(u)  'Bioanlaeg'      / flisk /;
set uc(u)  'OV-leverance'   / NS /;
set ur(u)  'SR-kedler'      / peak /;
set uv(u)  'Koelere'        / cooler /;
set uaux(u)'Andre prod-anlaeg end affald' / flisk, peak, ns /;

set u2f(u,f) 'Gyldige kombinationer af anlaeg og drivmidler';

set uprio(up)       'Prioriterede anlaeg';
set uprio2up(up,up) 'Anlaegsprioriteter';   # Rækkefølge af prioriteter oprettes på basis af DataU(up,'prioritet')

set labDataU        'DataU labels'     / aktiv, ukind, prioritet, minLhv, kapTon, kapNom, kapRgk, kapMax, minlast, kapMin, etaq, DV, aux /;
set labScheduleCol  'Periodeomfang' / firstYear, lastYear, firstPeriod, lastPeriod /;
set labScheduleRow  'Periodeomfang' / aar, maaned, dato /;
set labProgn        'Prognose labels'  / aktiv, Ndage, Ovn2, Ovn3, Fliskedel, NS-varme, SR-kedler, Cooler, Varmebehov, NS-prod, ELprod, Elpris, ETS, AFV, ATL, co2aff, co2peak /;
set labDataFuel     'DataFuel labels'  / aktiv, fkind, lagerbar, fri, bortskaffes, minTonnage, maxTonnage, pris, brandv, co2andel, prisbv /;
#--- set labFuelparms 'Fuel parms'       / MindsteBVaffald /;

set taxkind(labProgn) 'Omkostningstyper' / ets, afv, atl, affco2, auxco2 /;

# ------------------------------------------------------------------------------------------------
# Erklaering af input parametre
# ------------------------------------------------------------------------------------------------
Scalar    Penalty_bOnU             'Penalty paa bOnU'        / 00000E+5 /;
Scalar    Penalty_QRgkMiss         'Penalty paa QRgkMiss'    /   20 /;      # Denne penalty må ikke være højere end tillaegsafgiften.
Scalar    RgkRabatSats             'Rabatsats paa ATL'       / 0.10 /;
Scalar    RgkRabatMinShare         'Taerskel for RGK rabat'  / 0.07 /;
Scalar    VarmeSalgspris           'Varmesalgspris DKK/MWhq' / 0.0 /;
Scalar    AffaldsOmkAndel          'Affaldssiden omk.andel'  / 0.45 /;

Parameter DataU(u, labDataU)       'Data for anlaeg';
Parameter Schedule(labScheduleRow, labScheduleCol);

Parameter Prognoses(moall, labProgn)  'Data for prognoser';
#--- Parameter AvailDaysU(moall,u)         'Raadige dage for hvert anlaeg';

Parameter DataFuel(f, labDataFuel) 'Data for drivmidler';
Parameter FuelBounds(f,bound,moall)   'Maengdegraenser for drivmidler';
#--- Parameter FuelParms(labFuelparms)  'Tvaergaaende parametre for braendsler';

$If not errorfree $exit

# Indlaesning af input parametre

$onecho > REFAinput.txt
par=DataU               rng=DataU!B4:L10             rdim=1 cdim=1
par=Schedule            rng=DataU!A15:E15            rdim=1 cdim=1
par=Prognoses           rng=DataFuel!D20:U56         rdim=1 cdim=1

par=DataFuel            rng=DataFuel!C4:N33          rdim=1 cdim=1
par=FuelBounds          rng=DataFuel!B38:AM174       rdim=2 cdim=1

*--- par=AvailDaysU         rng=DataU!B15:K27            rdim=1 cdim=1
*--- par=FuelParms          rng=Fuel!B41:C43             rdim=1 cdim=0
$offecho

$call "ERASE  REFAinputM.gdx"
$call "GDXXRW REFAinputM.xlsm RWait=1 Trace=3 @REFAinput.txt"

# Indlaesning fra GDX-fil genereret af GDXXRW.
# $LoadDC bruges for at sikre, at der ikke findes elementer, som ikke er gyldige for den aktuelle parameter.
# $Load udfoerer samme operation som $LoadDC, men ignorerer ugyldige elementer.
# $Load anvendes her for at tillade at indsaette linjer med beskrivende tekst.

$GDXIN REFAinput.gdx

$LOAD   DataU
$LOAD   Schedule
$LOAD   Prognoses
$LOAD   DataFuel
$LOAD   FuelBounds
#--- $LOAD   AvailDaysU
#--- $LOAD   FuelParms

$GDXIN   # Close GDX file.
$log  Finished loading input data from GDXIN.

display DataU, Schedule, Prognoses, DataFuel, FuelBounds;

$If not errorfree $exit

# ------------------------------------------------------------------------------------------------
# Erklaering af mellemregnings og output parametre.
# ------------------------------------------------------------------------------------------------

# NEDENSTAAENDE DYNAMISKE SAETY BEVIRKER, AT DE IKKE KAN BRUGES TIL ERKLAERING AF VARIABLE OG LIGNINGER.
#--- # Anlaegstyper
#--- ua(u)   = DataU(u,'ukind') EQ 1;
#--- ub(u)   = DataU(u,'ukind') EQ 2;
#--- uc(u)   = DataU(u,'ukind') EQ 3;
#--- ur(u)   = DataU(u,'ukind') EQ 4;
#--- uv(u)   = DataU(u,'ukind') EQ 5;
#--- up(u)   = NOT uv(u);
#--- uaux(u) = NOT ua(u);

# Anlaegsprioriteter.
Scalar dbup, dbupa;
alias(upa, up);
uprio(up) = no;
uprio2up(up,upa) = no;
loop (up $(DataU(up,'aktiv') NE 0 AND DataU(up,'prioritet') GT 0),
  dbup = ord(up);
  uprio(up) = yes;
  #--- display dbup;
  loop (upa $(DataU(upa,'aktiv') NE 0 AND DataU(upa,'prioritet') LT DataU(up,'prioritet') AND NOT sameas(up,upa)),
    dbupa = ord(upa);
    uprio2up(up,upa) = yes;
    #--- display dbup, dbupa;
  );
);
display uprio, uprio2up;

# Braendselstyper.
fa(f) = DataFuel(f,'fkind') EQ 1;
fb(f) = DataFuel(f,'fkind') EQ 2;
fc(f) = DataFuel(f,'fkind') EQ 3;
fr(f) = DataFuel(f,'fkind') EQ 4;
u2f(u,f)   = no;
u2f(ua,fa) = yes;
u2f(ub,fb) = yes;
u2f(uc,fc) = yes;
u2f(ur,fr) = yes;

fsto(f) = DataFuel(f,'lagerbar') NE 0;
fdis(f) = DataFuel(f,'bortskaffes') NE 0;
ffri(f) = DataFuel(f,'fri') NE 0 AND fa(f);
faux(f) = NOT fa(f);

display f, fa, fb, fc, fr, fsto, fdis, ffri, u2f;

Parameter OnU(u)            'Angiver om anlaeg er til raadighed';
Parameter OnF(f)            'Angiver om drivmiddel er til raadighed';
Parameter OnM(moall)           'Angiver om en given maaned er aktiv';
Parameter Hours(moall)         'Antal timer i maaned';
Parameter AvailDaysU(moall,u)  'Antal raadige dage';
Parameter ShareAvailU(u,moall) 'Andel af fuld raadighed';
Parameter EtaQ(u)           'Varmevirkningsgrad';

OnU(u)     = DataU(u,'aktiv');
OnF(f)     = DataFuel(f,'aktiv');
OnM(moall)    = Prognoses(moall,'aktiv')
Hours(moall)  = 24 * Prognoses(moall,'ndage');
EtaQ(u)    = DataU(u,'etaq');

loop (u,
  loop (labProgn $sameas(u,labProgn))
    AvailDaysU(moall,u)  = Prognoses(moall,labProgn) $OnU(u);
    ShareAvailU(u,moall) = max(0.0, min(1.0, AvailDaysU(moall,u) / Prognoses(moall,'Ndage') ));
  );
);

display OnU, OnF, OnM, Hours, AvailDaysU, ShareAvailU, EtaQ;

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

Parameter IncomeElec(moall)'El-indkomst [DKK]';
Parameter MinTonnageAar(f) 'Braendselstonnage min aarsniveau [ton/aar]';
Parameter MaxTonnageAar(f) 'Braendselstonnage max aarsniveau [ton/aar]';
Parameter LhvMWh(f)        'Braendvaerdi [MWf]';
Parameter Qdemand(moall)      'FJV-behov';
Parameter PowerProd(moall)    'Elproduktion MWhe';
Parameter PowerPrice(moall)   'El-pris DKK/MWhe';
Parameter TaxAfvMWh(moall)    'Affaldsvarmeafgift [DKK/MWhq]';
Parameter TaxAtlMWh(moall)    'Affaldstillaegsafgift [DKK/MWhf]';
Parameter TaxEtsTon(moall)    'CO2 Kvotepris [DKK/tom]';
Parameter TaxCO2AffTon(moall) 'CO2 afgift affald [DKK/tom]';
Parameter TaxCO2AuxTon(moall) 'CO2 afgift aux [DKK/tom]';

MinTonnageAar(f) = DataFuel(f,'minTonnage');
MaxTonnageAar(f) = DataFuel(f,'maxTonnage');
LhvMWh(f)        = DataFuel(f,'brandv') / 3.6;
Qdemand(moall)      = Prognoses(moall,'varmebehov');
PowerProd(moall)    = Prognoses(moall,'ELprod');
PowerPrice(moall)   = Prognoses(moall,'ELpris');
IncomeElec(mo)      = PowerProd(moall) * PowerPrice(moall) $OnU('ovn3');
TaxAfvMWh(moall)    = Prognoses(moall,'afv') * 3.6;
TaxAtlMWh(moall)    = Prognoses(moall,'atl') * 3.6;
TaxEtsTon(moall)    = Prognoses(moall,'ets');
TaxCO2AffTon(moall) = Prognoses(moall,'co2aff');
TaxCO2AuxTon(moall) = Prognoses(moall,'co2aux');
display MinTonnageAar, MaxTonnageAar, LhvMWh, Qdemand, PowerProd, PowerPrice, IncomeElec, TaxAfvMWh, TaxAtlMWh, TaxEtsTon, TaxCO2AffTon, TaxCO2AuxTon;

# Special-haandtering af oevre graense for Nordic Sugar varme.
FuelBounds('NSvarme','max',moall) = Prognoses(moall,'NSvarme');

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

Parameter CostsATLMax(moall) 'Oevre graense for ATL';
Parameter RgkRabatMax(moall) 'Oevre graense for ATL rabat';
Parameter QRgkMissMax     'Oevre graense for QRgkMiss';
CostsATLMax(moall) = sum(ua $OnU(ua), ShareAvailU(ua,moall) * Hours(moall) * KapMax(ua)) * TaxAtlMWh(moall);
RgkRabatMax(moall) = RgkRabatSats * CostsATLMax(moall);
QRgkMissMax = 2 * RgkRabatMinShare * sum(ua $OnU(ua), 31 * 24 * KapNom(ua));  # Faktoren 2 er en sikkerhedsfaktor mod inffeasibilitet.
display CostsATLMax, RgkRabatMax, QRgkMissMax;

$If not errorfree $exit

# ------------------------------------------------------------------------------------------------
# Erklaering af variable.
# ------------------------------------------------------------------------------------------------
Free     variable NPV                      'Nutidsvaerdi af affaldsdisponering';

Binary   variable bOnU(u,moall)               'Anlaeg on-off';
Binary   variable bOnRgk(ua,moall)            'Affaldsanlaeg RGK on-off';
Binary   variable bOnRgkRabat(moall)          'Indikator for om der i paagaeldende maaned kan opnaas RGK rabat';

Positive variable FuelDemand(u,f,moall)       'Drivmiddel forbrug paa hvert anlaeg';
Positive variable FuelDemandFreeSum(f)     'Samlet braendselsmængde frie fraktioner';
Positive variable Q(u,moall)                  'Grundlast MWq';
Positive variable QaffM(ua,moall)             'Modtryksvarme paa affaldsanlaeg MWq';
Positive variable Qrgk(u,moall)               'RGK produktion MWq';
Positive variable Qafv(moall)                 'Varme paalagt affaldvarmeafgift';
Positive variable QRgkMiss(moall)             'Slack variabel til beregning om RGK-rabat kan opnaas';

Positive variable IncomeTotal(moall)          'Indkomst total';
Positive variable IncomeAff(f,moall)          'Indkomnst for affaldsmodtagelse DKK';
Positive variable RgkRabat(moall)             'RGK rabat paa tillaegsafgift';
Positive variable CostsU(u,moall)             'Omkostninger anlægsdrift DKK';
Positive variable CostsTotalF(moall)          'Omkostninger Total paa drivmidler DKK';
Positive variable CostsAuxF(f,moall)          'Omkostninger til braendselsindkoeb DKK';
Positive variable CostsTotalAuxF(moall)       'Omkostninger til braendselsindkoeb DKK';
Positive variable CostsAFV(moall)             'Omkostninger til affaldvarmeafgift DKK';
Positive variable CostsATL(moall)             'Omkostninger til affaldstillaegsafgift DKK';
Positive variable CostsETS(moall)             'Omkostninger til CO2-kvoter DKK';
Positive variable CostsCO2(moall)             'Omkostninger til CO2-afgift DKK';
Positive variable CO2emis(f,moall)            'CO2-emission';
Positive variable TotalAffEProd(moall)        'Samlet energiproduktion affaldsanlaeg';
#--- Positive variable RgkShare(moall)             'RGK-andel af samlet affalds-energiproduktion';

# @@@@@@@@@@@@@@@@@@@@@@@@  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG
IncomeTotal.up(moall) = 1E+8;
IncomeAff.up(f,moall) = 1E+8;
RgkRabat.up(moall)    = 1E+8;

# @@@@@@@@@@@@@@@@@@@@@@@@  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG  DEBUG



# Fiksering af ikke-aktive anlaeg og ikke-aktive drivmidler.
loop (u $(NOT OnU(u)),
  bOnU.fx(u,moall)   = 0.0;
  Q.fx(u,moall)      = 0.0;
  CostsU.fx(u,moall) = 0.0;
  loop (f $(NOT OnF(f) OR NOT u2f(u,f)),
    FuelDemand.fx(u,f,moall) = 0.0;
  );
);

loop (f $(NOT OnF(f)),
  IncomeAff.fx(f,moall) = 0.0;
  CO2emis.fx(f,moall) = 0.0;
);

IncomeAff.fx(faux,moall) = 0.0;
CostsAuxF.fx(fa,moall)   = 0.0;
loop (u,
  loop (f $(NOT u2f(u,f)),
    FuelDemand.fx(u,f,moall) = 0.0;
  );
);


# Fiksering af RGK-produktion til nul paa ikke-aktive affaldsanlaeg.
loop (ua $(NOT OnU(ua)), bOnRgk.fx(ua,moall) = 0.0; );

# DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#--- FuelDemand.fx('ovn3','Dagren','jan') = 2400.0;
#--- Q.up('cooler',moall) = 10000;
#--- CostsU.up('peak',moall) = 1E+9;
#--- bOnRgk.fx(ua,'jan') = 0.0;

# ------------------------------------------------------------------------------------------------
# Erklaering af ligninger.
# RGK kan moduleres kontinuert: RGK deaktiveres hvis Qdemand < Qmodtryk
# ------------------------------------------------------------------------------------------------
# Fordeling af omkostninger mellem affalds- og varmesiden:
# * AffaldsOmkAndel er andelen, som affaldssiden skal bære.
# * Til affaldssiden 100 pct: Kvoteomkostning
# * Til fordeling: Alle afgifter
# ------------------------------------------------------------------------------------------------

Equation  ZQ_Obj                      'Objective';
Equation  ZQ_IncomeTotal(moall)          'Indkomst Total';
Equation  ZQ_IncomeAff(f,moall)          'Indkomst paa affaldsfraktioner';
Equation  ZQ_CostsU(u,moall)             'Omkostninger paa anlaeg';
Equation  ZQ_CostsTotalF(moall)          'Omkostninger totalt paa drivmidler';
Equation  ZQ_CostsTotalAuxF(moall)       'Omkostninger totalt paa ikke-affaldsbraendsel';
Equation  ZQ_CostsAuxF(f,moall)          'Omkostninger til ikke-affaldsfraktioner';
Equation  ZQ_CostsAFV(moall)             'Affaldsvarmeafgift DKK';
Equation  ZQ_CostsATL(moall)             'Affaldstillaegsafgift foer evt. rabat DKK';
Equation  ZQ_CostsETS(moall)             'CO2-kvoteomkostning DKK';
Equation  ZQ_CostsCO2(moall)             'CO2-afgift DKK';
Equation  ZQ_Qafv(moall)                 'Varme hvoraf der skal svares AFV [MWhq]';
Equation  ZQ_CO2emis(f,moall)            'CO2-maengde hvoraf der skal svares ETS [ton]';
Equation  ZQ_PrioUp(up,up,moall)         'Prioritet af uprio over visse up anlaeg';


ZQ_Obj  ..  NPV  =E=  sum(mo, IncomeTotal(mo)
                      - [
                           sum(u $OnU(u), CostsU(u,mo))
                         + CostsTotalF(mo)
                         + Penalty_bOnU * sum(u, bOnU(u,mo))
                         + Penalty_QRgkMiss * QRgkMiss(mo)
                        ] );

ZQ_IncomeTotal(mo)       .. IncomeTotal(mo)   =E=  sum(fa $OnF(fa), IncomeAff(fa,mo)) + RgkRabat(mo) + IncomeElec(mo) + VarmeSalgspris * sum(up $OnU(up), Q(up,mo));
ZQ_IncomeAff(fa,mo)      .. IncomeAff(fa,mo)  =E=  sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * DataFuel(fa,'pris')) $OnF(fa);

ZQ_CostsU(u,mo)          .. CostsU(u,mo)      =E=  Q(u,mo) * (DataU(u,'dv') + DataU(u,'aux') ) $OnU(u);

# SKAT har i 2010 kommunikeret (Røggasreglen), at tillægsafgiften betales af den totale producerede varme, og ikke af den indfyrede energi, da elproduktion ikke må beskattes (jf. EU).
# ¤¤¤¤¤¤¤¤ TODO Tillægsafgiftsberegningen skal korrigeres, så den matcher Kulafgiftsloven § 5.
# ¤¤¤¤¤¤¤¤      Det gælder beregning af faktisk energiindhold (som er KV-afhængigt) og hensyntagen til andre brændsler (biogene).

#TODO Affaldvarmeafgiften skal betales af varmesiden, og skal derfor ikke indgaa i en isoleret optimering for affaldssiden.

ZQ_CostsTotalF(mo)       .. CostsTotalF(mo)     =E=  CostsTotalAuxF(mo) + CostsAFV(mo) + CostsATL(mo) + CostsETS(mo) + CostsCO2(mo);
ZQ_CostsAFV(mo)          .. CostsAFV(mo)        =E=  Qafv(mo) * TaxAfvMWh(mo);
ZQ_CostsATL(mo)          .. CostsATL(mo)        =E=  sum(ua $OnU(ua), Q(ua,mo)) * TaxAtlMWh(mo);
ZQ_CostsETS(mo)          .. CostsETS(mo)        =E=  sum(f $OnF(f), CO2emis(f,mo)) * TaxEtsTon(mo);
ZQ_CostsCO2(mo)          .. CostsCO2(mo)        =E=  sum(fa $OnF(fa), sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelDemand(ua,fa,mo))) * TaxCO2AffTon(mo) 
                                                     + sum(faux $OnF(faux), sum(uaux $(OnU(uaux) AND u2f(uaux,faux)), FuelDemand(uaux,faux,mo))) * TaxCO2AuxTon(mo);
ZQ_CostsTotalAuxF(mo)    .. CostsTotalAuxF(mo)  =E=  sum(faux, CostsAuxF(faux,mo));
ZQ_CostsAuxF(faux,mo)    .. CostsAuxF(faux,mo)  =E=  sum(uaux $(OnU(uaux) AND u2f(uaux,faux)), FuelDemand(uaux,faux,mo) * DataFuel(faux,'pris') );

ZQ_Qafv(mo)              .. Qafv(mo)         =E=  sum(ua $OnU(ua), Q(ua,mo)) - Q('cooler',mo);   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.
ZQ_CO2emis(f,mo) $OnF(f) .. CO2emis(f,mo)    =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelDemand(up,f,mo)) * DataFuel(f,'co2andel');

ZQ_PrioUp(uprio,up,mo) $(OnU(uprio) AND OnU(up) AND AvailDaysU(mo,uprio) AND AvailDaysU(mo,up)) ..  bOnU(up,mo)  =L=  bOnU(uprio,mo);


#begin Beregning af RGK-rabat
# -------------------------------------------------------------------------------------------------------------------------------
# Beregning af RGK-rabatten indebærer 2 trin:
#   1: Bestem den manglende RGK-varme QRgkMiss, som er nødvendig for at opnå rabatten.
#      Det gøres med en ulighed samt en penalty paa QRgkMiss i objektfunktionen for at tvinge den mod nul, når rabatten er i hus.
#   2: Beregn rabatten ved den ulineære ligning: RgkRabat =E= bOnRgkRabat * (RgkRabatSats * CostsATL);
#      Produktet af de 2 variable bOnRgkRabat og CostsATL omformuleres vha. 4 ligninger, som indhegner RgkRabat.
# --------------------------------------------------------------------------------------------------------------------------------
Equation  ZQ_TotalAffEprod(mo)  'Samlet energiproduktion MWh';
Equation  ZQ_QRgkMiss(mo)       'Bestem manglende RGK-varme for at opnaa rabat';
Equation  ZQ_bOnRgkRabat(mo)    'Bestem bOnRgkRabat';

ZQ_TotalAffEprod(mo)  ..  TotalAffEProd(mo)  =E=  PowerProd(mo) + sum(ua $OnU(ua), Q(ua,mo));       # Samlet energioutput fra affaldsanlæg. Bruges til beregning af RGK-rabat.
ZQ_QRgkMiss(mo)       ..  sum(ua $OnU(ua), Qrgk(ua,mo)) + QRgkMiss(mo)  =G=  RgkRabatMinShare * TotalAffEProd(mo);
ZQ_bOnRgkRabat(mo)    ..  QRgkMiss(mo)  =L=  (1 - bOnRgkRabat(mo)) * QRgkMissMax;

#OBS: Udkommenteresde inaktive / ugyldige restriktioner slettet

# Beregning af produktet: RgkRabat =E= bOnRgkRabat * (RgkRabatSats * CostsATL);
#--- Equation  ZQ_RgkRabatMin1(moall);
Equation  ZQ_RgkRabatMax1(moall);
Equation  ZQ_RgkRabatMin2(moall);
Equation  ZQ_RgkRabatMax2(moall);

#--- ZQ_RgkRabatMin1(mo) .. 0  =L=  RgkRabat(mo);
ZQ_RgkRabatMax1(mo) .. RgkRabat(mo)  =L=  RgkRabatMax(mo) * bOnRgkRabat(mo);
ZQ_RgkRabatMin2(mo) ..  0 * (1 - bOnRgkRabat(mo))                   =L=  RgkRabatSats * CostsATL(mo) - RgkRabat(mo);
ZQ_RgkRabatMax2(mo) ..  RgkRabatSats * CostsATL(mo) - RGKrabat(mo)  =L=  RgkRabatMax(mo) * (1 - bOnRgkRabat(mo));

#end Beregning af RGK-rabat

#begin Varmebalancer
Equation  ZQ_Qdemand(moall)              'Opfyldelse af fjv-behov';
Equation  ZQ_Qaff(ua,moall)              'Samlet varmeprod. affaldsanlaeg';
Equation  ZQ_QaffM(ua,moall)             'Samlet modtryks-varmeprod. affaldsanlaeg';
Equation  ZQ_Qrgk(ua,moall)              'RGK produktion paa affaldsanlaeg';
Equation  ZQ_QrgkMax(ua,moall)           'RGK produktion oevre graense';
Equation  ZQ_Qaux(u,moall)               'Samlet varmeprod. oeavrige anlaeg end affald';
Equation  ZQ_QaffMmax(ua,moall)          'Max. modtryksvarmeproduktion';
Equation  ZQ_CoolMax(moall)              'Loft over bortkoeling';
Equation  ZQ_Qmin(u,moall)               'Sikring af nedre graense paa varmeproduktion';
Equation  ZQ_QMax(u,moall)               'Aktiv status begraenset af total raadighed';
Equation  ZQ_bOnRgk(ua,moall)            'Angiver om RGK er aktiv';

ZQ_Qdemand(mo)               ..  Qdemand(mo)  =E=  sum(up $OnU(up), Q(up,mo)) - Q('cooler',mo) $OnU('cooler');
ZQ_Qaff(ua,mo)     $OnU(ua)  ..  Q(ua,mo)     =E=  [QaffM(ua,mo) + Qrgk(ua,mo)];
ZQ_QaffM(ua,mo)    $OnU(ua)  ..  QaffM(ua,mo) =E=  [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * EtaQ(ua) * LhvMWh(fa))] $OnU(ua);
ZQ_Qrgk(ua,mo)     $OnU(ua)  ..  Qrgk(ua,mo)  =L=  KapRgk(ua) / KapNom(ua) * QaffM(ua,mo);
ZQ_QrgkMax(ua,mo)  $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);

ZQ_Qaux(uaux,mo) $OnU(uaux)  ..  Q(uaux,mo)   =E=  [sum(faux $(OnF(faux) AND u2f(uaux,faux)), FuelDemand(uaux,faux,mo) * EtaQ(uaux) * LhvMWh(faux))] $OnU(uaux);


ZQ_QaffMmax(ua,mo) $OnU(ua)  ..  QAffM(ua,mo)    =L=  QaffMmax(ua,mo);
ZQ_CoolMax(mo)               ..  Q('cooler',mo)  =L=  sum(ua $OnU(ua), Q(ua,mo));

ZQ_QMin(u,mo)      $OnU(u)   ..  Q(u,mo)      =G=  ShareAvailU(u,mo) * Hours(mo) * KapMin(u) * bOnU(u,mo);   #  Restriktionen paa timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
ZQ_QMax(u,mo)      $OnU(u)   ..  Q(u,mo)      =L=  ShareAvailU(u,mo) * Hours(mo) * KapMax(u) * bOnU(u,mo);
ZQ_bOnRgk(ua,mo)   $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);

#end Varmebalancer

# Restriktioner paa affaldsforbrug paa aars- hhv. maanedsniveau.

# Dagrenovation skal bortskaffes hurtigt, hvilket sikres ved at angive mindstegraenser for affaldsforbrug paa maanedsniveau.
# Andre drivmidler er lagerbarer og kan derfor disponeres over hele året, men skal også bortskaffes.

# Alle braendsler skal respektere nedre og oevre graense for forbrug.
# Alle ikke-lagerbare og bortskafbare braendsler skal respektere mindsteforbrug paa maanedsniveau.
# Alle ikke-bortskafbare affaldsfraktioner skal respektere et jævn
# Ikke-bortskafbare braendsler (fdis(f)) skal kun respektere mindste- og størsteforbruget paa maanedsniveau.
# Alle braendsler markeret som bortskaffes, skal bortskaffes indenfor et løbende aar (lovkrav for affald).
# Braendvaerdi af indfyret affaldsmix skal overholde mindstevaerdi.
# Kapaciteten af affaldsanlaeg er både bundet af tonnage [ton/h] og varmeeffekt.

# Disponering af affaldsfraktioner
Equation  ZQ_FuelMin(f,moall)   'Mindste drivmiddelforbrug paa maanedsniveau';
Equation  ZQ_FuelMax(f,moall)   'Stoerste drivmiddelforbrug paa maanedsniveau';

ZQ_FuelMin(f,mo) $(OnF(f) AND NOT fsto(f) AND NOT ffri(f) AND fdis(f))  ..  sum(u $(OnU(u)  AND u2f(u,f)),  FuelDemand(u,f,mo))   =G=  FuelBounds(f,'min',mo);
ZQ_FuelMax(f,mo) $(OnF(f) AND fdis(f)) ..  sum(u $(OnU(u)  AND u2f(u,f)),  FuelDemand(u,f,mo))   =L=  FuelBounds(f,'max',mo) * 1.0001;  # Faktor 1.0001 indsat da afrundingsfejl giver infeasibility.

# Aarskrav til affaldsfraktioner, som skal bortskaffes.
Equation  ZQ_FuelMinYear(f)  'Mindste braendselsforbrug paa aarsniveau';
Equation  ZQ_FuelMaxYear(f)  'Stoerste braendselsforbrug paa aarsniveau';

ZQ_FuelMinYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDemand(u,fdis,mo)))  =G=  MinTonnageAar(fdis) * card(mo) / 12;
ZQ_FuelMaxYear(fdis)  $OnF(fdis)  ..  sum(mo, sum(u $(OnU(u) AND u2f(u,fdis)), FuelDemand(u,fdis,mo)))  =L=  MaxTonnageAar(fdis) * card(mo) / 12;

# Krav til frie affaldsfraktioner.
Equation ZQ_FuelDemandFreeSum(f)          'Aarstonnage af frie affaldsfraktioner';
Equation ZQ_FuelMinFreeNonStorable(f,moall)  'Ligeligt tonnageforbrug af ikke-lagerbare frie affaldsfraktioner';
#--- Equation ZQ_FuelMinFree(f,moall)     'Mindste maengde ikke-lagerbare frie affaldsfraktioner';
#--- Equation ZQ_FuelMaxFree(f,moall)     'stoerste maengde til ikke-lagerbare frie affaldsfraktioner';

ZQ_FuelDemandFreeSum(ffri) $(OnF(ffri) AND card(mo) GT 1)                            .. FuelDemandFreeSum(ffri)  =E=  sum(mo, sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDemand(ua,ffri,mo) ) );
ZQ_FuelMinFreeNonStorable(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri) AND card(mo) GT 1) ..  sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDemand(ua,ffri,mo))  =E=  FuelDemandFreeSum(ffri) / card(mo);
#--- ZQ_FuelMinFree(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri)) ..  sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDemand(ua,ffri,mo))  =G=  FuelDemandFreeSum(ffri);
#--- ZQ_FuelMaxFree(ffri,mo) $(OnF(ffri) AND NOT fsto(ffri)) ..  sum(ua $(OnU(ua)  AND u2f(ua,ffri)), FuelDemand(ua,ffri,mo))  =L=  FuelDemandFreeSum(ffri) * 1.0001;

# Restriktioner paa tonnage og braendvaerdi for affaldsanlaeg.
Equation ZQ_MaxTonnage(u,moall)    'Stoerste tonnage for affaldsanlaeg';
Equation ZQ_MinLhvAffald(u,moall)  'Mindste braendvaerdi for affaldsblanding';

ZQ_MaxTonnage(ua,mo) $OnU(ua)    ..  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo))  =L=  ShareAvailU(ua,mo) * Hours(mo) * KapTon(ua);
ZQ_MinLhvAffald(ua,mo) $OnU(ua)  ..  MinLhvMWh(ua) * sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo))
                                      =L=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * LhvMWh(fa));

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

# ------------------------------------------------------------------------------------------------
# Efterbehandling af resultater.
# ------------------------------------------------------------------------------------------------

# Penalty_bOnU skal tilbagebetales til NPV.
Scalar Penalty_bOnUTotal;
Penalty_bOnUTotal = Penalty_bOnU * sum(mo, sum(u, bOnU.L(u,mo)));
display Penalty_bOnUTotal, NPV.L;


# ------------------------------------------------------------------------------------------------
# Udskriv resultager til Excel output fil.
# ------------------------------------------------------------------------------------------------
set topics / Varmepris, IndkomstAffald, IndkomstElsalg, AnlaegsOmk, BraendselOmk, CO2-emission, FJV-behov, Elprod, VarmeProd, RGKvarme, RGKandel, RGKrabat, Bortkoeling /;

Scalar tiny / 1E-14/;
Scalar tmp1, tmp2, tmp3;

Parameter NPV_V;
Parameter Overview(topics,moall);
Parameter IncomeF_V(f,moall);
Parameter FuelDemand_V(f,moall);
Parameter FuelBounds_V(f,bound,moall);
Parameter Q_V(u,moall);
Parameter Qrgk_V(ua,moall);
Parameter RgkShare(moall);
Parameter Varmepris(moall)    'Variabel varmepris paa tvaers af produktionsanlæg DKK/MWhq';
Parameter Usage(u,moall)      'Kapacitetsudnyttelse af anlæg';
Parameter Prognoses_V(moall,labProgn) 'Prognoser';

RgkShare(mo) = max(tiny, sum(ua $OnU(ua), Qrgk.L(ua,mo)) / sum(ua $OnU(ua), Q.L(ua,mo)) );
Varmepris(mo) = (sum(u $OnU(u), CostsU.L(u,mo)) + CostsTotalF.L(mo) - IncomeTotal.L(mo)) / (sum(up, Q.L(up,mo) - Q.L('cooler',mo)));
display RgkShare, Varmepris;

Scalar TimeOfWritingMasterResults;
TimeOfWritingMasterResults = jnow;

# Penalty_bOnU skal tilbagebetales til NPV.
Scalar Penalty_bOnUTotal, Penalty_QRgkMissTotal;
Penalty_bOnUTotal = Penalty_bOnU * sum(mo, sum(u, bOnU.L(u,mo)));
Penalty_QRgkMissTotal = Penalty_QRgkMiss * sum(mo, QRgkMiss.L(mo));
NPV_V = NPV.L + Penalty_bOnUTotal + Penalty_QRgkMissTotal;
display Penalty_bOnUTotal, Penalty_QRgkMissTotal, NPV.L, NPV_V;

loop (mo,
  OverView('Varmepris',mo)      = ifthen(Varmepris(mo) EQ 0.0, tiny, Varmepris(mo));
  OverView('IndkomstAffald',mo) = max(tiny, IncomeAff.L(mo) + RgkRabat.L(mo));
  OverView('IndkomstElsalg',mo) = max(tiny, IncomeElec(mo));
  OverView('BraendselOmk',mo)   = max(tiny, CostsTotalF.L(mo));
  OverView('CO2-emission',mo)   = max(tiny, sum(f $OnF(f), CO2emis.L(f,mo)) );
  OverView('AnlaegsOmk',mo)     = max(tiny, sum(u $OnU(u), CostsU.L(u,mo)));
  OverView('ElProd',mo)         = max(tiny, PowerProd(mo));
  OverView('VarmeProd',mo)      = max(tiny, sum(up $OnU(up), Q.L(up,mo)));
  Overview('FJV-behov',mo)      = max(tiny, Qdemand(mo));
  OverView('RGKvarme',mo)       = max(tiny, sum(ua $OnU(ua), Qrgk.L(ua,mo)));
  OverView('RGKandel',mo)       = max(tiny, RgkShare(mo));
  OverView('RGKrabat',mo)       = max(tiny, RgkRabat.L(mo));
  OverView('Bortkoeling',mo)    = max(tiny, Q.L('cooler',mo));

  Prognoses_V('mo0',labProgn) = tiny;  # Sikrer tom kolonne i output-tabellen.
  FuelDemand_V(f,mo) = tiny;
  IncomeF_V(f,mo) = tiny;
  FuelBounds_V(f,bound,mo) = ifthen(FuelBounds(f,bound,mo) EQ 0.0, tiny, FuelBounds(f,bound,mo));

  loop (f $OnF(f),
    tmp1 = sum(u $OnU(u), FuelDemand.L(u,f,mo));
    FuelDemand_V(f,mo) = max(tiny, tmp1);
    IncomeF_V(f,mo)    = ifthen(IncomeAff.L(f,mo) EQ 0.0, tiny, IncomeAff.L(f,mo));
  );
  loop (faux,
    IncomeF_V(faux,mo) = ifthen(CostsAuxF.L(faux,mo) EQ 0.0, tiny, -CostsAuxF.L(faux,mo));
  );

  Q_V(u,mo)        = ifthen (Q.L(u,mo) EQ 0.0, tiny, Q.L(u,mo));
  Q_V('cooler',mo) = -Q_V('cooler',mo);  # Negation aht. afbildning i sheet Overblik.
  Qrgk_V(ua,mo)    = ifthen (Qrgk.L(ua,mo) EQ 0.0, tiny, Qrgk.L(ua,mo));
  loop (u $OnU(u),
    if (Q.L(u,mo) GT 0.0,
      Usage(u,mo) = Q.L(u,mo) / (KapMax(u) * ShareAvailU(u,mo) * Hours(mo));
    else
      Usage(u,mo) = tiny;
    );
  );
);


execute_unload 'REFAoutput.gdx',
TimeOfWritingMasterResults,
bound, moall, mo, fkind, f, fa, fb, fc, fr, u, up, ua, ub, uc, ur, u2f, labDataU, labDataFuel, labScheduleRow, labScheduleCol, labProgn, taxkind, topics,
DataU, Prognoses, AvailDaysU, DataFuel, FuelBounds,
OnU, OnF, Hours, ShareAvailU, EtaQ, KapMin, KapNom, KapRgk, KapMax, Qdemand, PowerProd, LhvMWh, TaxAfvMWh, TaxAtlMWh, TaxCO2AffTon, TaxCO2AuxTon,
EaffGross, QaffMmax, QrgkMax, QaffTotalMax, CostsATLMax, RgkRabatMax,
NPV_V, Prognoses_V, FuelDemand_V, FuelBounds_V, IncomeF_V, Q_V, Qrgk_V, Usage,
OverView
;


$OnText
* NOTE on using GDXXRW to export GDX results to Excel. McCarl
* Any item to be exported must be unloaded (saved) to a gdx file using the execute_unload stmt (see above).
* 1: By default an item is assumed to be a table (2D) and the first index being the row index.
* 2: By vectors (1D) do specify cdim=0 to obtain a column vector, otherwise a row vector is obtained.
* 3: GDXXRW args options cdim and rdim control how a multi-dim item is written to the Excel sheet:
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
par=Schedule            rng=Inputs!B2       cdim=1  rdim=1
text="Schedule"         rng=Inputs!B2   
par=DataU               rng=Inputs!B10      cdim=1  rdim=1
text="DataU"            rng=Inputs!B10:B10
par=DataFuel            rng=Inputs!B20      cdim=1  rdim=1
text="DataFuel"         rng=Inputs!B20:B20
par=Prognoses_V         rng=Inputs!P3       cdim=1  rdim=1
text="Prognoser"        rng=Inputs!P3:P3
par=FuelBounds_V        rng=Inputs!P22      cdim=1  rdim=2
text="FuelBounds"       rng=Inputs!P22:P22

*end   Individuelle dataark

* Overview is the last sheet to be written hence becomes the actual sheet when opening Excel file.

*begin sheet Overblik
par=TimeOfWritingMasterResults      rng=Overblik!C1:C1
text="Tidsstempel"                  rng=Overblik!A1:A1
par=NPV_V                           rng=Overblik!A4:A4
text="NPV"                          rng=Overblik!A3:A3
par=OverView                        rng=Overblik!C6         cdim=1  rdim=1
text="Overblik"                     rng=Overblik!C6:C6
par=Q_V                             rng=Overblik!C21        cdim=1  rdim=1
text="Varmemaengder"                rng=Overblik!C21:C21
par=FuelDemand_V                    rng=Overblik!C29        cdim=1  rdim=1
text="Braendselsforbrug"            rng=Overblik!C29:C29
par=IncomeF_V                       rng=Overblik!C61        cdim=1  rdim=1
text="Braendselsindkomst"           rng=Overblik!C61:C61
par=Usage                           rng=Overblik!C89        cdim=1  rdim=1
text="Kapacitetsudnyttelse"         rng=Overblik!C89:C89
*end

$offecho

# Write the output Excel file using GDXXRW.
execute "gdxxrw.exe REFAoutput.gdx o=REFAoutput.xlsm trace=1 @REFAoutput.txt";

execute_unload "REFAmain.gdx";

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
