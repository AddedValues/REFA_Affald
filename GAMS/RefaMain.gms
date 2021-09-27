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
set bound 'Bounds'         / min, max /;
set mo    'Aarsmaaneder'   / jan, feb, mar, apr, maj, jun, jul, aug, sep, okt, nov, dec /;
#--- set mo    'Aarsmaaneder'   / jan, feb /;


# ¤¤¤¤¤  TODO: INDFØR fkind FOR BIOGENT AFFALD   ¤¤¤¤¤¤¤¤¤
# ¤¤¤¤¤  TODO: INDFØR fkind FOR BIOGENT AFFALD   ¤¤¤¤¤¤¤¤¤
# ¤¤¤¤¤  TODO: INDFØR fkind FOR BIOGENT AFFALD   ¤¤¤¤¤¤¤¤¤
# ¤¤¤¤¤  TODO: INDFØR fkind FOR BIOGENT AFFALD   ¤¤¤¤¤¤¤¤¤
# ¤¤¤¤¤  TODO: INDFØR fkind FOR BIOGENT AFFALD   ¤¤¤¤¤¤¤¤¤
# ¤¤¤¤¤  TODO: INDFØR fkind FOR BIOGENT AFFALD   ¤¤¤¤¤¤¤¤¤

set fkind 'Drivm.-typer'  / 1 'affald', 2 'biomasse', 3 'varme', 4 'peakfuel' /;

Set f     'Drivmidler'    / DepoSort, DepoSmaat, DepoNedd, Dagren, AndetBrand, Trae, 
                            DagrenRast, DagrenInst, DagrenHandel, DagrenRestau, Erhverv, DagrenErhverv, 
                            HandelKontor, Privat, TyskRest, PolskRest, PcbTrae, FlisAffald, TraeRekv, Halm, Pulver, 
                            Flis, NSvarme, PeakFuel /;
#--- Set f     'Drivmidler'    / Dagren, 
#---                             Flis, NSvarme /;
set fa(f) 'Affaldstyper';
set fb(f) 'Biobraendsler';
set fc(f) 'Overskudsvarme';

set ukind 'Anlaegstyper'   / 1 'affald', 2 'biomasse', 3 'varme', 4 'peak', 5 'koeler' /;
set u     'Anlaeg'         / ovn2, ovn3, flisk, peak, ns, cooler /;
set up(u) 'Prod-anlaeg'    / ovn2, ovn3, flisk, peak, NS /;
set ua(u) 'Affaldsanlaeg'  / ovn2, ovn3 /;
set ub(u) 'Bioanlaeg'      / flisk /;
set uc(u) 'OV-leverance'   / NS /;

set u2f(u,f) 'Gyldige kombinationer af anlaeg og drivmidler';

set uprio(up) 'Prioriterede anlaeg' / ovn3, NS /;
set uprio2up(up,up) 'Anlaegsprioriteter';
uprio2up('ovn3',up) = NOT sameas(up,'peak');
uprio2up('NS',  up) = NOT sameas(up,'ovn3') AND NOT sameas(up,'peak');
loop (up, uprio2up(up,up) = no; );

set lblDataU     'DataU labels'     / aktiv, kapTon, kapNom, kapRgk, minlast, kapMin, etaq, DV, aux /;
set lblDataFuel  'DataFuel labels'  / aktiv, fkind, lagerbart, tonnage, pris, brandv, co2andel, prisbv /;
set lblProgn     'Prognose labels'  / ndage, varmebehov, NSprod, ELprod, ets, afv, atl /;

set taxkind(lblProgn) 'Omkostningstyper' / ets, afv, atl /;

# ------------------------------------------------------------------------------------------------
# Erklaering af input parametre
# ------------------------------------------------------------------------------------------------
Scalar    Penalty_bOnU             'Penalty på bOnU'         / 1E+3 /;
Scalar    Penalty_QRgkMiss         'Penalty på QRgkMiss'     /   20 /;  # Denne penalty må ikke være højere end tillaegsafgiften.
Scalar    RgkRabatSats             'Rabatsats paa ATL'       / 0.10 /;
Scalar    RgkRabatMinShare         'Taerskel for RGK rabat'  / 0.07 /;

Parameter DataU(u, lblDataU)       'Data for anlaeg';
Parameter Prognoses(mo, lblProgn)  'Data for prognoser';
Parameter AvailDaysU(mo,u)         'Raadige dage for hvert anlaeg';

Parameter DataFuel(f, lblDataFuel) 'Data for drivmidler';
Parameter FuelBounds(f,bound,mo)   'Maengdegraenser for drivmidler';

$If not errorfree $exit

# Indlaesning af input parametre

$onecho > REFAinput.txt
par=DataU               rng=DataU!B4:L10             rdim=1 cdim=1
par=Prognoses           rng=DataU!B15:J27            rdim=1 cdim=1
par=AvailDaysU          rng=DataU!B31:H43            rdim=1 cdim=1
par=DataFuel            rng=Fuel!C4:K28              rdim=1 cdim=1
par=FuelBounds          rng=Fuel!O4:AB52             rdim=2 cdim=1
$offecho

$call "ERASE  REFAinput.gdx"
$call "GDXXRW REFAinput.xlsm RWait=1 Trace=3 @REFAinput.txt"

# Indlaesning fra GDX-fil genereret af GDXXRW.
# $LoadDC bruges for at sikre, at der ikke findes elementer, som ikke er gyldige for den aktuelle parameter.
# $Load udfoerer samme operation som $LoadDC, men ignorerer ugyldige elementer.
# $Load anvendes her for at tillade at indsaette linjer med beskrivende tekst.

$GDXIN REFAinput.gdx

$LOAD   DataU     
$LOAD   Prognoses 
$LOAD   AvailDaysU
$LOAD   DataFuel  
$LOAD   FuelBounds

$GDXIN   # Close GDX file.
$log  Finished loading input data from GDXIN.

display DataU, Prognoses, AvailDaysU, DataFuel, FuelBounds;

$If not errorfree $exit

# ------------------------------------------------------------------------------------------------
# Erklaering af mellemregnings og output parametre.
# ------------------------------------------------------------------------------------------------

fa(f) = DataFuel(f,'fkind') EQ 1;
fb(f) = DataFuel(f,'fkind') EQ 2;
fc(f) = DataFuel(f,'fkind') EQ 3;
u2f(u,f)   = no;
u2f(ua,fa) = yes;
u2f(ub,fb) = yes;
u2f(uc,fc) = yes;

display f, fa, fb, fc, u2f;

Parameter OnU(u)      'Angiver om anlaeg er til raadighed';
OnU(u) = DataU(u,'aktiv');

Parameter OnF(f)      'Angiver om drivmiddel er til raadighed';
OnF(f) = DataFuel(f,'aktiv');

Parameter Hours(mo)   'Antal timer i maaned';
Hours(mo) = 24 * Prognoses(mo,'ndage');

Parameter ShareAvailU(u,mo) 'Andel af fuld raadighed';
ShareAvailU(u,mo) = max(0.0, min(1.0, AvailDaysU(mo,u) / Prognoses(mo,'ndage') )) $OnU(u);

Parameter EtaQ(u)     'Varmevirkningsgrad';
EtaQ(u) = DataU(u,'etaq');

Parameter KapTon(up) 'Stoerste indfyringskapacitet ton/h';
Parameter KapMin(u)  'Mindste modtrykslast MWq';
Parameter KapNom(u)  'Stoerste modtrykskapacitet MWq';
Parameter KapMax(u)  'Stoerste samlede varmekapacitet MWq';
Parameter KapRgk(u)  'RGK kapacitet MWq';
KapTon(up) = DataU(up,'kapTon');
KapMin(u)  = DataU(u, 'kapMin');
KapRgk(ua) = DataU(ua,'kapRgk');
KapNom(u)  = DataU(u, 'KapNom');
KapMax(u)  = KapNom(u) + KapRgk(u);

Parameter Qdemand(mo) 'FJV-behov';
Qdemand(mo) = Prognoses(mo,'varmebehov');

Parameter Power(mo)  'Elproduktion MWhe';
Power(mo) = Prognoses(mo,'ELprod');

Parameter LhvMWh(f)     'Braendvaerdi [MWf]';
Parameter TaxAfvMWh(mo) 'Affaldsvarmeafgift [DKK/MWhq]';
Parameter TaxAtlMWh(mo) 'Affaldstillaegsafgift [DKK/MWhf]';
Parameter TaxEtsTon(mo) 'CO2 Kvotepris [DKK/tpm]';
LhvMWh(f) = DataFuel(f,'brandv') / 3.6;
TaxAfvMWh(mo) = Prognoses(mo,'afv') * 3.6;
TaxAtlMWh(mo) = Prognoses(mo,'atl') * 3.6;
TaxEtsTon(mo) = Prognoses(mo,'ets');

# EaffGross skal være mininum af energiindhold af rådige mængder affald hhv. affaldsanlæggets fuldlastkapacitet.
Parameter EaffGross(mo)     'Max energiproduktion for affaldsanlaeg MWh';
Parameter QaffMmax(ua,mo)   'Max. modtryksvarme fra affaldsanlæg';
Parameter QrgkMax(ua,mo)    'Max. RGK-varme fra affaldsanlæg';
Parameter QaffTotalMax(mo)  'Max. total varme fra affaldsanlæg';
QaffMmax(ua,mo)  = min(ShareAvailU(ua,mo) * Hours(mo) * KapNom(ua), [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelBounds(fa,'max',mo) * EtaQ(ua) * LhvMWh(fa))]) $OnU(ua);
QrgkMax(ua,mo)   = KapRgk(ua) / KapNom(ua) * QaffMmax(ua,mo);
QaffTotalMax(mo) = sum(ua $OnU(ua), ShareAvailU(ua,mo) * (QaffMmax(ua,mo) + QrgkMax(ua,mo)) );
EaffGross(mo)    = QaffTotalMax(mo) + Power(mo);

Parameter CostsATLMax(mo) 'oevre graense for ATL';
Parameter RgkRabatMax(mo) 'oevre graense for ATL rabat';
Parameter QRgkMissMax  'Oevre graense for QRgkMiss';
CostsATLMax(mo) = sum(ua $OnU(ua), ShareAvailU(ua,mo) * Hours(mo) * KapMax(ua)) * TaxAtlMWh(mo);
RgkRabatMax(mo) = RgkRabatSats * CostsATLMax(mo);
QRgkMissMax = 2 * RgkRabatMinShare * sum(ua $OnU(ua), 31 * 24 * KapNom(ua));  # Faktoren 2 er en sikkerhedsfaktor mod inffeasibilitet.

display OnU, OnF, Hours, ShareAvailU, EtaQ, KapMin, KapNom, KapRgk, KapMax, Qdemand, Power, LhvMWh, TaxAfvMWh, TaxAtlMWh;
display QaffMmax, QrgkMax, QaffTotalMax, EaffGross, CostsATLMax, RgkRabatMax, QRgkMissMax;

$If not errorfree $exit

# ------------------------------------------------------------------------------------------------
# Erklaering af variable.
# ------------------------------------------------------------------------------------------------
Free     variable NPV                      'Nutidsvaerdi af affaldsdisponering';

Binary   variable bOnU(u,mo)               'Anlaeg on-off';
Binary   variable bOnRgk(ua,mo)            'Affaldsanlaeg RGK on-off';
Binary   variable bOnRgkRabat(mo)          'Indikator for om der i paagaeldende maaned kan opnaas RGK rabat';

Positive variable FuelDemand(u,f,mo)       'Drivmiddel forbrug paa hvert anlaeg';
Positive variable Q(u,mo)                  'Grundlast MWq';
Positive variable QaffM(ua,mo)             'Modtryksvarme på affaldsanlaeg MWq';
Positive variable Qrgk(u,mo)               'RGK produktion MWq';
Positive variable Qafv(mo)                 'Varme paalagt affaldvarmeafgift';
Positive variable QRgkMiss(mo)             'Slack variabel til beregning om RGK-rabat kan opnaas';

Positive variable IncomeTotal(mo)          'Indkomst total';
Free     variable IncomeF(f,mo)            'Indkomst fra drivmidler';
Positive variable RgkRabat(mo)             'RGK rabat paa tillaegsafgift';
Positive variable CostsU(u,mo)             'Omkostninger anlægsdrift DKK';
Positive variable CostsTotalF(mo)          'Omkostninger Total på drivmidler DKK';
Positive variable CostsAFV(mo)             'Omkostninger til affaldvarmeafgift DKK';
Positive variable CostsATL(mo)             'Omkostninger til affaldstillaegsafgift DKK';
Positive variable CostsETS(mo)             'Omkostninger til CO2-kvoter DKK';
Positive variable CO2emis(f,mo)            'CO2-emission';
Positive variable TotalAffEProd(mo)        'Samlet energiproduktion affaldsanlaeg';
#--- Positive variable RgkShare(mo)             'RGK-andel af samlet affalds-energiproduktion';

# Fiksering af ikke-aktive anlaeg og ikke-aktive drivmidler.
loop (u $(NOT OnU(u)), 
  bOnU.fx(u,mo)   = 0.0; 
  Q.fx(u,mo)      = 0.0;
  CostsU.fx(u,mo) = 0.0;
  loop (f $(NOT OnF(f) OR NOT u2f(u,f)), 
    FuelDemand.fx(u,f,mo) = 0.0; 
  ); 
);

loop (f $(NOT OnF(f)),
  IncomeF.fx(f,mo) = 0.0;
  CO2emis.fx(f,mo) = 0.0;
);

# Fiksering af RGK-produktion til nul paa ikke-aktive affaldsanlaeg.
loop (ua $(NOT OnU(ua)), bOnRgk.fx(ua,mo) = 0.0; );

# DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG DEBUG !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#--- FuelDemand.fx('ovn3','Dagren','jan') = 2400.0;
#--- Q.up('cooler',mo) = 10000;
#--- CostsU.up('peak',mo) = 1E+9;
#--- bOnRgk.fx(ua,'jan') = 0.0;

# ------------------------------------------------------------------------------------------------
# Erklaering af ligninger.
# RGK kan moduleres kontinuert: RGK deaktiveres hvis Qdemand < Qmodtryk
# ------------------------------------------------------------------------------------------------
Equation  ZQ_Obj                      'Objective';
Equation  ZQ_IncomeTotal(mo)          'Indkomst Total';
Equation  ZQ_IncomeF(f,mo)            'Indkomst paa drivmidler';
Equation  ZQ_CostsU(u,mo)             'Omkostninger paa anlaeg';
Equation  ZQ_CostsTotalF(mo)          'Omkostninger totalt paa drivmidler';
Equation  ZQ_CostsAFV(mo)             'Affaldsvarmeafgift DKK';
Equation  ZQ_CostsATL(mo)             'Affaldstillaegsafgift foer evt. rabat DKK';
Equation  ZQ_CostsETS(mo)             'CO2-kvoteomkostning DKK';
Equation  ZQ_Qafv(mo)                 'Varme hvoraf der skal svares AFV [MWhq]';
Equation  ZQ_CO2emis(f,mo)            'CO2-maengde hvoraf der skal svares ETS [ton]';
Equation  ZQ_PrioUp(uprio,up,mo)      'Prioritet af uprio over visse up anlaeg';


ZQ_Obj  ..  NPV  =E=  sum(mo, IncomeTotal(mo) 
                      - [
                           sum(u $OnU(u), CostsU(u,mo)) 
                         + CostsTotalF(mo) 
                         + Penalty_bOnU * sum(u, bOnU(u,mo)) 
                         + Penalty_QRgkMiss * QRgkMiss(mo)
                        ] );

ZQ_IncomeTotal(mo)       .. IncomeTotal(mo)  =E=  sum(f $OnF(f), IncomeF(f,mo)) + RgkRabat(mo);
ZQ_IncomeF(f,mo) $OnF(f) .. IncomeF(f,mo)    =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelDemand(up,f,mo) * DataFuel(f,'pris')) $OnF(f);

ZQ_CostsU(u,mo) $OnU(u)  .. CostsU(u,mo)     =E=  Q(u,mo) * (DataU(u,'dv') + DataU(u,'aux') ) $OnU(u);

ZQ_CostsTotalF(mo)       .. CostsTotalF(mo)  =E=  CostsAFV(mo) + CostsATL(mo) + CostsETS(mo);
ZQ_CostsAFV(mo)          .. CostsAFV(mo)     =E=  Qafv(mo) * TaxAfvMWh(mo);

# SKAT har i 2010 kommunikeret (Røggasreglen), at tillægsafgiften betales af den totale producerede varme, og ikke af den indfyrede energi, da elproduktion ikke må beskattes (jf. EU).

# ¤¤¤¤¤¤¤¤¤¤¤¤¤          TODO Tillægsafgiftsberegningen skal korrigeres, så den matcher Kulafgiftsloven § 5.
# ¤¤¤¤¤¤¤¤¤¤¤¤¤          TODO Tillægsafgiftsberegningen skal korrigeres, så den matcher Kulafgiftsloven § 5.
# ¤¤¤¤¤¤¤¤¤¤¤¤¤          TODO Tillægsafgiftsberegningen skal korrigeres, så den matcher Kulafgiftsloven § 5.
# ¤¤¤¤¤¤¤¤¤¤¤¤¤          TODO Tillægsafgiftsberegningen skal korrigeres, så den matcher Kulafgiftsloven § 5.
# ¤¤¤¤¤¤¤¤¤¤¤¤¤          TODO Tillægsafgiftsberegningen skal korrigeres, så den matcher Kulafgiftsloven § 5.

# ¤¤¤¤¤¤¤¤     Det gælder beregning af faktisk energiindhold (som er KV-afhængigt) og hensyntagen til andre brændsler (biogene).
# ¤¤¤¤¤¤¤¤     Det gælder beregning af faktisk energiindhold (som er KV-afhængigt) og hensyntagen til andre brændsler (biogene).
# ¤¤¤¤¤¤¤¤     Det gælder beregning af faktisk energiindhold (som er KV-afhængigt) og hensyntagen til andre brændsler (biogene).
# ¤¤¤¤¤¤¤¤     Det gælder beregning af faktisk energiindhold (som er KV-afhængigt) og hensyntagen til andre brændsler (biogene).
# ¤¤¤¤¤¤¤¤     Det gælder beregning af faktisk energiindhold (som er KV-afhængigt) og hensyntagen til andre brændsler (biogene).
# ¤¤¤¤¤¤¤¤     Det gælder beregning af faktisk energiindhold (som er KV-afhængigt) og hensyntagen til andre brændsler (biogene).

ZQ_CostsATL(mo)          .. CostsATL(mo)     =E=  sum(ua $OnU(ua), Q(ua,mo)) * TaxAtlMWh(mo);

ZQ_CostsETS(mo)          .. CostsETS(mo)     =E=  sum(f $OnF(f), CO2emis(f,mo)) * TaxEtsTon(mo);
ZQ_Qafv(mo)              .. Qafv(mo)         =E=  sum(ua $OnU(ua), Q(ua,mo)) - Q('cooler',mo);   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.
ZQ_CO2emis(f,mo) $OnF(f) .. CO2emis(f,mo)    =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelDemand(up,f,mo)) * DataFuel(f,'co2andel');  

ZQ_PrioUp(uprio,up,mo) $(OnU(uprio) AND OnU(up) AND AvailDaysU(mo,uprio) AND AvailDaysU(mo,up)) ..  bOnU(up,mo)  =L=  bOnU(uprio,mo); 


#begin Beregning af RGK-rabat
# -------------------------------------------------------------------------------------------------------------------------------
# Beregning af RGK-rabatten indebærer 2 trin:
#   1: Bestem den manglende RGK-varme QRgkMiss, som er nødvendig for at opnå rabatten.
#      Det gøres med en ulighed samt en penalty på QRgkMiss i objektfunktionen for at tvinge den mod nul, når rabatten er i hus.
#   2: Beregn rabatten ved den ulineære ligning: RgkRabat =E= bOnRgkRabat * (RgkRabatSats * CostsATL);
#      Produktet af de 2 variable bOnRgkRabat og CostsATL omformuleres vha. 4 ligninger, som indhegner RgkRabat.
# --------------------------------------------------------------------------------------------------------------------------------
Equation  ZQ_TotalAffEprod(mo)  'Samlet energiproduktion MWh';
Equation  ZQ_QRgkMiss(mo)       'Bestem manglende RGK-varme for at opnaa rabat';
Equation  ZQ_bOnRgkRabat(mo)    'Bestem bOnRgkRabat';

ZQ_TotalAffEprod(mo)  ..  TotalAffEProd(mo)  =E=  Power(mo) + sum(ua $OnU(ua), Q(ua,mo));       # Samlet energioutput fra affaldsanlæg. Bruges til beregning af RGK-rabat.
ZQ_QRgkMiss(mo)       ..  sum(ua $OnU(ua), Qrgk(ua,mo)) + QRgkMiss(mo)  =G=  RgkRabatMinShare * TotalAffEProd(mo);
ZQ_bOnRgkRabat(mo)    ..  QRgkMiss(mo)  =L=  (1 - bOnRgkRabat(mo)) * QRgkMissMax;

#--- Equation  ZQ_RgkShare(mo)             'RGK-varmens andel af energiproduktion';
#--- Equation  ZQ_bOnRgkRabat(mo)          'Kriteriet for opnaaelse af rabat er mindst 7 % RGK-varme ift. samlet energiproduktion';
#--- ZQ_RgkShare(mo)       ..  RgkShare(mo)        =E=  sum(ua $OnU(ua), Qrgk(ua,mo)) / EaffGross(mo);
#--- ZQ_bOnRgkRabat(mo)    ..  bOnRgkRabat(mo)     =L=  RgkShare(mo) / RgkRabatMinShare;                 # Kriteriet for opnåelse af rabat er mindst 7 % RGK-varme ift. samlet energiproduktion.

# Beregning af produktet: RgkRabat =E= bOnRgkRabat * (RgkRabatSats * CostsATL);
#--- Equation  ZQ_RgkRabatMin1(mo);
Equation  ZQ_RgkRabatMax1(mo);
Equation  ZQ_RgkRabatMin2(mo);
Equation  ZQ_RgkRabatMax2(mo);

#--- ZQ_RgkRabatMin1(mo) .. 0  =L=  RgkRabat(mo);
ZQ_RgkRabatMax1(mo) .. RgkRabat(mo)  =L=  RgkRabatMax(mo) * bOnRgkRabat(mo);
ZQ_RgkRabatMin2(mo) ..  0 * (1 - bOnRgkRabat(mo))                   =L=  RgkRabatSats * CostsATL(mo) - RgkRabat(mo);
ZQ_RgkRabatMax2(mo) ..  RgkRabatSats * CostsATL(mo) - RGKrabat(mo)  =L=  RgkRabatMax(mo) * (1 - bOnRgkRabat(mo));

#--- ZQ_RgkRabatMin2(mo) ..  0 * (1 - bOnRgkRabat(mo))       =L=  RgkRabatMax(mo)  - RgkRabat(mo);
#--- ZQ_RgkRabatMax2(mo) ..  RgkRabatMax(mo) - RgkRabat(mo)  =L=  RgkRabatMax(mo) * (1 - bOnRgkRabat(mo));

#end Beregning af RGK-rabat

Equation  ZQ_Qdemand(mo)              'Opfyldelse af fjv-behov';
Equation  ZQ_Qaff(ua,mo)              'Samlet varmeprod. affaldsanlaeg';
Equation  ZQ_QaffM(ua,mo)             'Samlet modtryks-varmeprod. affaldsanlaeg';
Equation  ZQ_Qbio(ub,mo)              'Samlet varmeprod. biomasseanlaeg';
Equation  ZQ_Qvarme(uc,mo)            'Samlet varmeprod. overskudsvarme';
Equation  ZQ_Qrgk(ua,mo)              'RGK produktion paa affaldsanlaeg';
Equation  ZQ_QrgkMax(ua,mo)           'RGK produktion oevre graense';
Equation  ZQ_QaffMmax(ua,mo)          'Max. modtryksvarmeproduktion';
Equation  ZQ_Qmin(u,mo)               'Sikring af nedre graense paa varmeproduktion';
Equation  ZQ_bOnU(u,mo)               'Aktiv status begraenset af total raadighed';
Equation  ZQ_bOnRgk(ua,mo)            'Angiver om RGK er aktiv';

ZQ_Qdemand(mo)               ..  Qdemand(mo)  =E=  sum(up $OnU(up), Q(up,mo)) - Q('cooler',mo) $OnU('cooler');
ZQ_Qaff(ua,mo)     $OnU(ua)  ..  Q(ua,mo)     =E=  [QaffM(ua,mo) + Qrgk(ua,mo)];
ZQ_QaffM(ua,mo)    $OnU(ua)  ..  QaffM(ua,mo) =E=  [sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelDemand(ua,fa,mo) * EtaQ(ua) * LhvMWh(fa))] $OnU(ua);
ZQ_Qbio(ub,mo)     $OnU(ub)  ..  Q(ub,mo)     =E=  [sum(fb $(OnF(fb) AND u2f(ub,fb)), FuelDemand(ub,fb,mo) * EtaQ(ub) * LhvMWh(fb))]  $OnU(ub);
ZQ_Qvarme(uc,mo)   $OnU(uc)  ..  Q(uc,mo)     =E=  [sum(fc $(OnF(fc) AND u2f(uc,fc)), FuelDemand(uc,fc,mo))] $OnU(uc);  # Varme er i MWhq, mens øvrige drivmidler er i ton.
ZQ_Qrgk(ua,mo)     $OnU(ua)  ..  Qrgk(ua,mo)  =L=  KapRgk(ua) / KapNom(ua) * QaffM(ua,mo);  
ZQ_QrgkMax(ua,mo)  $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);  
                   
ZQ_QaffMmax(ua,mo) $OnU(ua)  ..  QAffM(ua,mo) =L=  QaffMmax(ua,mo);
                   
ZQ_QMin(u,mo)      $OnU(u)   ..  Q(u,mo)      =G=  ShareAvailU(u,mo) * Hours(mo) * KapMin(u) * bOnU(u,mo);   #  Restriktionen på timeniveau tager hoejde for, at NS leverer mindre end 1 dags kapacitet.
ZQ_bOnU(u,mo)      $OnU(u)   ..  Q(u,mo)      =L=  ShareAvailU(u,mo) * Hours(mo) * KapMax(u) * bOnU(u,mo);  
ZQ_bOnRgk(ua,mo)   $OnU(ua)  ..  Qrgk(ua,mo)  =L=  QrgkMax(ua,mo) * bOnRgk(ua,mo);  


# Restriktioner på affaldsforbrug på aars- hhv. maanedsniveau.
# Dagrenovation skal bortskaffes hurtigt, hvilket sikres ved at angive mindstegraenser for affaldsforbrug på maanedsniveau.
# Andre drivmidler er lagerbarer og kan derfor disponeres over hele året, men skal også bortskaffes.
Equation  ZQ_AffUseYear(f)   'Affaldsforbrug på aarsniveau';
Equation  ZQ_FuelMin(f,mo)    'Mindste  drivmiddelforbrug paa maanedsniveau';
Equation  ZQ_BioUseYear(f)   'Biomasseforbrug på aarsniveau';
Equation  ZQ_OVUseYear(f)    'Overskudsvarmeforbrug på aarsniveau';

#TODO Introducere 'lagerbart' angivelse fra DataFuel til at styre om et brændsel skal bruges fuldstændigt paa aarsniveau.
ZQ_AffUseYear(fa) $OnF(fa) ..  sum(mo, sum(ua $(OnU(ua) AND u2f(ua,fa)), FuelDemand(ua,fa,mo)))  =E=  sum(mo, FuelBounds(fa,'max',mo));
ZQ_FuelMin(f,mo) $OnF(f) ..            sum(u  $(OnU(u)  AND u2f(u,f)),   FuelDemand(u,f,mo))     =G=  FuelBounds(f,'min',mo);
ZQ_BioUseYear(fb) $OnF(fb) ..  sum(mo, sum(ub $(OnU(ub) AND u2f(ub,fb)), FuelDemand(ub,fb,mo)))  =L=  sum(mo, FuelBounds(fb,'max',mo));
ZQ_OVUseYear(fc)  $OnF(fc) ..  sum(mo, sum(uc $(OnU(uc) AND u2f(uc,fc)), FuelDemand(uc,fc,mo)))  =E=  sum(mo, FuelBounds(fc,'max',mo));

$If not errorfree $exit

# ------------------------------------------------------------------------------------------------
# Loesning af modellen.
# ------------------------------------------------------------------------------------------------
model modelREFA / all /;
option MIP=gurobi;
modelREFA.optFile = 1;

option LIMROW=250, LIMCOL=250;
#--- option LIMROW=0, LIMCOL=0;

solve modelREFA maximizing NPV using MIP;

# ------------------------------------------------------------------------------------------------
# Efterbehandling af resultater.
# ------------------------------------------------------------------------------------------------

# Penalty_bOnU skal tilbagebetales til NPV.
Scalar Penalty_bOnUTotal;
Penalty_bOnUTotal = Penalty_bOnU * sum(mo, sum(u, bOnU.L(u,mo))); 
NPV.L = NPV.L + Penalty_bOnUTotal;
display Penalty_bOnUTotal, NPV.L; 


# ------------------------------------------------------------------------------------------------
# Udskriv resultager til Excel output fil.
# ------------------------------------------------------------------------------------------------
set topics / Varmepris, Indkomst, AnlaegsOmk, BraendselOmk, CO2emis, TotalVarme, RGKvarme, RGKandel, RGKrabat /;

Scalar tiny / 1E-14/;
Scalar tmp1, tmp2, tmp3;

Parameter NPV_V;
Parameter IncomeF_V(f,mo);
Parameter FuelDemand_V(f,mo);
Parameter Q_V(u,mo);
Parameter Qrgk_V(ua,mo);
Parameter RgkShare(mo);
Parameter Overview(topics,mo);
Parameter Varmepris(mo)    'Variabel varmepris på tvaers af produktionsanlæg DKK/MWhq';

RgkShare(mo) = max(tiny, sum(ua $OnU(ua), Qrgk.L(ua,mo)) / sum(ua $OnU(ua), Q.L(ua,mo)) );
Varmepris(mo) = (sum(u $OnU(u), CostsU.L(u,mo)) + CostsTotalF.L(mo) - IncomeTotal.L(mo)) / (sum(up, Q.L(up,mo) - Q.L('cooler',mo)));

display RgkShare, Varmepris;

Scalar TimeOfWritingMasterResults;
TimeOfWritingMasterResults = jnow;

NPV_V = NPV.L;

loop (mo,
  OverView('Varmepris',mo)    = ifthen(Varmepris(mo) EQ 0.0, tiny, Varmepris(mo));
  OverView('Indkomst',mo)     = max(tiny, IncomeTotal.L(mo));
  OverView('BraendselOmk',mo) = max(tiny, CostsTotalF.L(mo));
  OverView('AnlaegsOmk',mo)   = max(tiny, sum(u $OnU(u), CostsU.L(u,mo)));
  OverView('TotalVarme',mo)   = max(tiny, sum(up $OnU(up), Q.L(up,mo)));
  OverView('RGKvarme',mo)     = max(tiny, sum(ua $OnU(ua), Qrgk.L(ua,mo)));
  OverView('RGKandel',mo)     = max(tiny, RgkShare(mo));
  OverView('RGKrabat',mo)     = max(tiny, RgkRabat.L(mo));

  loop (f $OnF(f), 
    tmp1 = sum(u $OnU(u), FuelDemand.L(u,f,mo));
    FuelDemand_V(f,mo) = max(tiny, tmp1);
  );

  Q_V(u,mo)        = ifthen (Q.L(u,mo) EQ 0.0, tiny, Q.L(u,mo));
  Q_V('cooler',mo) = -Q_V('cooler',mo);
  Qrgk_V(ua,mo)    = ifthen (Qrgk.L(ua,mo) EQ 0.0, tiny, Qrgk.L(ua,mo));
);


execute_unload 'REFAoutput.gdx',
TimeOfWritingMasterResults,
bound, mo, fkind, f, fa, fb, fc, u, up, ua, ub,uc, u2f, lblDataU, lblDataFuel, lblProgn, taxkind, topics,
DataU, Prognoses, AvailDaysU, DataFuel, FuelBounds,        
OnU, OnF, Hours, ShareAvailU, EtaQ, KapMin, KapNom, KapRgk, KapMax, Qdemand, Power, LhvMWh, TaxAfvMWh, TaxAtlMWh, 
EaffGross, QaffMmax, QrgkMax, QaffTotalMax, CostsATLMax, RgkRabatMax,
NPV_V, FuelDemand_V, Q_V, Qrgk_V, 
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

*begin Individuelle dataark

* sheet Inputs
par=DataU             rng=Inputs!B3       cdim=1  rdim=1
text="DataU"          rng=Inputs!B3:B3
par=Prognoses         rng=Inputs!B14      cdim=1  rdim=1
text="Prognoser"      rng=Inputs!B14:B14
par=AvailDaysU        rng=Inputs!B30      cdim=1  rdim=1
text="AvailDaysU"     rng=Inputs!B30:B30

par=DataFuel          rng=Inputs!N3       cdim=1  rdim=1
text="DataFuel"       rng=Inputs!N3:N3
par=FuelBounds        rng=Inputs!N30      cdim=1  rdim=2
text="FuelBounds"     rng=Inputs!N30:N30

*end   Individuelle dataark

* Overview as the last sheet to be written hence the actual sheet when opening Excel file.

*begin sheet Overblik 
par=TimeOfWritingMasterResults      rng=Overblik!B1:B1
text="Tidsstempel"                  rng=Overblik!A1:A1
par=NPV_V                           rng=Overblik!C4:C4
text="NPV [DKK]"                    rng=Overblik!B4:B4
par=OverView                        rng=Overblik!B6         cdim=1  rdim=1
text="Overblik"                     rng=Overblik!B6:B6
par=Q_V                             rng=Overblik!B17        cdim=1  rdim=1
text="Varmemaengder [MWhq]"         rng=Overblik!B17:B17
par=FuelDemand_V                    rng=Overblik!B26        cdim=1  rdim=1
text="Braendselsforbrug [ton]"      rng=Overblik!B26:B26
*end

$offecho

# Write the output Excel file using GDXXRW.
execute "gdxxrw.exe REFAoutput.gdx o=REFAoutput.xlsm trace=1 @REFAoutput.txt";

execute_unload "RefaMain.gdx";