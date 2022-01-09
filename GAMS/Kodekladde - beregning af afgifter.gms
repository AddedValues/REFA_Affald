
    WORK-IN-PROGRESS  :  BEREGNING AF AFGIFTER

#begin Detaljeret nær-korrekt beregning af afgifter
$OnText 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Beregning af CO2-afgift og kvoteomkostning er relativt kompliceret for affaldsanlæg:
Følgende faktorer spiller ind:
1. Skorstensmetode ja / nej
2. Emissionsopgørelse er forskellig fra CO2-afgift til CO2-kvote !!!
3. Kun brændsel til varmeproduktion er pålagt CO2-afgift, men CO2-kvote betales af alt brændsel.
   Fordeling af brændsel mellem el og varme følger V- eller E-formel, hvor V-formlen er ulineær  F-el = F-total - min(Q-total / 1.2,  P-el / 0.35)
   Reelt kommer værnsreglen ikke i indgreb, hvis bypass køres i mindre end 43% af tiden (se OneNote siden "Tilretninger 28 DEC 2021").
4. Der svares hverken CO2-afgift eller CO2-kvoteomk. af biogent affald (som har CO2-andel == 0).


# OBS: KULAL § 7a : Der skal ikke betales AFV- hhv. Tillægsafgift af biogene brændsler, ejheller CO2-afgift. Brændslerne skal dog leveres i hele læs adskilt fra øvrigt affald.

# Den afgiftspligtige mængde CO2 skal opgøres for hver linje for sig jf. "E.A.4.2.7.3 Affaldsforbrændingsanlæg med flere affaldslinjer m.v."
# Dette gælder ikke for affaldvarme- og tillægsafgiften.

# Opgørelse af biogen affaldsmængde for hver ovn-linje.
Positive variable FEBiogen(u,moall) 'Indfyret biogen affaldsenergi [GJ]';
Equation ZQ_FEBiogen(u,moall);
ZQ_FEBiogen(ua,mo) .. FEBiogen(ua,mo)  =E=  sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelCons(ua,fa,mo) * LhvMWh(fa));

# Opgørelse af RGK-andelsen af den indfyrede biogene affaldsenergi FEBiogen.
# Andelen indgår ulineært (produkt af bOnRgk og FuelConsBiogen):  Qafgift = (Qtotal - (eqM + eqR * bOnRgk) * FEBiogen) / 1.2
# Produktet FbioR = bOnRgk * FEBiogen beregnes ved følgende MIP-formulering:
Parameter FEBiogenMax(mo) 'Max. biogen affaldsenergi [GJ]';
FEBiogenMax(mo) = sum(fa $OnF(fa), FuelBounds(fa,'max',mo) * LhvMWh(fa));

Positive variable FbioRgk(ua,moall) 'Biogen RGK-andel [GJ]';
Equation ZQ_FbioRMax1(u,moall);
Equation ZQ_FbioRMin2(u,moall);
Equation ZQ_FbioRMax2(u,moall);

ZQ_FbioRMax1(ua,mo) ..  FbioRgk(ua,mo)                    =L=  bOnRgk(ua,mo) * FEBiogenMax(mo);  
ZQ_FbioRMin2(ua,mo) ..  0                                 =L=  FEBiogenMax(mo) - FbioRgk(ua,mo);
ZQ_FbioRMax2(ua,mo) ..  FEBiogenMax(mo) - FbioRgk(ua,mo)  =L=  (1 - bOnRgk(ua,mo)) * FEBiogenMaxMax(mo);

Positive variable QBiogen(u,moall) 'Biogen affaldsvarme [GJ]';
ZQ_QBiogen(ua,mo)   ..  QBiogen(ua,mo)  =E=  EtaQ(ua) * FEBiogen(ua,mo) + EtaRgk(ua) * FbioRgk(ua,mo);

# Beregning af varme, hvoraf der skal betales affaldvarmeafgift.
ZQ_Qafv(mo)         ..  Qafv(mo)  =E=  sum(ua $OnU(ua), Q(ua,mo) - QBiogen(ua,mo)) - sum(uv $OnU(uv), Q(uv,mo));   # Antagelse: Kun affaldsanlaeg giver anledning til bortkoeling.

# Beregning af brændsel, hvoraf der skal betales tillægsafgift.
# Qafgift = Qtotal - (eqM + bOnRgk * eqR) * FEBiogen

PSEUDO-CODE BEGIN

if (SkorstensMetode) then
  # CO2-emission beregnes for hver fraktion for sig. Både energiindhold og CO2-indhold måles for hver fraktion.

  # DIN: EQ_FuelHeat(t,cp)$OnU(cp)   .. FuelHeat(t,cp)   =E=  (PowInU(t,cp) - Pnet(t,cp)/0.67)$(TaxEForm(cp) EQ 1) + (Q(t,cp)/1.2)$(TaxEForm(cp) EQ 0);

  ZQ_FuelHeatAff(mo) .. FuelHeatAff(mo)  =E=  sum(ua $OnU(ua), sum(f $(fa(f) AND OnF(f) AND u2f(ua,f) AND NOT fbiogen(f)), FuelCons(ua,f,mo));
  ZQ_FuelHeatAff(mo) .. FuelHeatAff(mo) =E= sum(ua $OnU(ua), sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelCons(ua,fa,mo))) - sum(ua $OnU(ua), Q(ua,mo));
  
  ZQ_CO2emisAff(fa,mo,typeCO2) $OnF(fa) .. CO2emis(fa,mo,typeCO2)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelHeatAff(ua,fa,mo)) * CO2potenTon(f,typeCO2);
  ZQ_CO2emis(f,mo,typeCO2) $OnF(f)   .. CO2emis(f,mo,typeCO2)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelCons(up,f,mo)) * CO2potenTon(f,typeCO2);

else
  # CO2-emission beregnes takstmæssigt ift. energiindhold i brændsler.
  # Emissionen har forskellig takst (sats) for CO2-afgift hhv. CO2-kvote.

endif

PSEUDO-CODE END    


#  Kun Ovn3 har elproduktion, så den totale el-virkningsgrad for de to ovne set under ét, bliver lav, cirka 25 procent.
#  V-formlen giver at brændslet allokeret til elproduktion er givet ved: Fel = Ftotal - min(Qtotal / 1.2, Pel / 0.35)
#  Pga. den lave elvirkningsgrad, hvor Pel = 0.25 Qtotal, bliver V-formlen: Fel = Ftotal - Qtotal * min (1 / 1.2, 0.25 / 0.35) = Ftotal - Qtotal * min (0.8333, 0.7142).
#  Dermed kan mindsteværdien altid sættes af faktoren Pel / 0.35, sålænge der ikke sker drastiske omprioriteringer (fx lukning af Ovn2).


ZQ_FuelElAff(mo) .. FuelElAff(mo) =E= sum(ua $OnU(ua), sum(fa $(OnF(fa) AND u2f(ua,fa)), FuelCons(ua,fa,mo)) - sum(ua $OnU(ua), Q(ua,mo));
ZQ_CO2emisAff(fa,mo,typeCO2) $OnF(fa) .. CO2emis(fa,mo,typeCO2)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelHeatAff(ua,fa,mo)) * CO2potenTon(f,typeCO2);

ZQ_CO2emis(f,mo,typeCO2) $OnF(f)   .. CO2emis(f,mo,typeCO2)  =E=  sum(up $(OnU(up) AND u2f(up,f)), FuelCons(up,f,mo)) * CO2potenTon(f,typeCO2);

<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$OffText

#end Detaljeret nær-korrekt beregning af afgifter

