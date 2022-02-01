$log Entering file: %system.incName%

# Filnavn: RefaSolveModel.gms
# Denne fil inkluderes af RefaMain.gms.
# Indeholder kode til iteration over ulineær model, hvor ulineariteten ligger i afgiftsberegningen.


# Initialisering før iteration af Phi-faktorer.
ConvergenceFound = FALSE;
PhiIter(phiKind,mo,iter) = 0.0;
dPhiIter(phiKind,mo,iter) = 0.0;

Nfbiogen = 0;  # Initialisering nødvendig, hvis ingen biogene fraktioner er aktive.
Loop (fbiogen $OnGF(fbiogen), Nfbiogen = Nfbiogen + 1; );

Phi(phiKind,mo)              = 0.2 $Nfbiogen;    # Startgæt: Bør være positivt når biogene fraktioner er aktive.
PhiIter(phiKind,mo,'iter0')  = Phi(phiKind,mo);
dPhiIter(phiKind,mo,'iter0') = 0.0;

# Der skal kun udføres én iteration, hvis der ikke er aktive biogene fraktioner.
Loop (iter $(ord(iter) GE 2 AND ord(iter) LE 2 + (card(iter)-2) $Nfbiogen),
  IterNo = ord(iter) - 1;
  display "Før SOLVE i Iteration no.", IterNo;

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
    display "Ingen løsning fundet.";
    execute_unload "REFAmain.gdx";
    abort "Solve af model mislykkedes.";
  );

  # Phi opdateres på basis af seneste optimeringsløsning.
  QcoolTotal(mo)      = sum(uv $OnU(uv,mo), Q.L(uv,mo));
  Qtotal(mo)          = sum(ua $OnU(ua,mo), Q.L(ua,mo));
  EnergiTotal(mo)     = Qtotal(mo) + Pbrut.L(mo);
  FEBiogenTotal(mo)   = sum(ua $OnU(ua,mo), FEBiogen.L(ua,mo));
  Fenergi(phiKind,mo) = [sum(ua $OnU(ua,mo), Q.L(ua,mo)) + Pbrut.L(mo)] / eE(phiKind);
  Phi(phiKind,mo)     = ifthen(Fenergi(phiKind,mo) EQ 0.0, 0.0, FEBiogenTotal(mo) / Fenergi(phiKind,mo) );
  PhiIter(phiKind,mo,iter) = Phi(phiKind,mo);

  # Beregn afgiftssum og sammenlign med forrige iteration.
  # AffaldVarme-afgift: Qafg = Qtotal - Qkøl - 0.85 * Fbiogen
  # Tillægs-afgift for bOnRgkRabat = 0:     Qafg = Qtotal * (1 - phi85) / 1.2
  # Tillægs-afgift for bOnRgkRabat = 1:     Qafg = [Qtotal - 0.1 * (Qtotal + Pbrut)] * (1 - phi95) / 1.2
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

  # BEREGNING AF METRIK FOR KONVERGENS (DÆKNINGSBIDRAG)
  # DeltaConvMetric beregnes på månedsniveau som relativ ændring for at sikre at dårligt konvergerende måneder vejer tungt ind i konvergensvurderingen.
  ConvMetric(mo)            = IncomeTotal.L(mo) - CostsTotal.L(mo);
  ConvMetricIter(mo,iter)   = ConvMetric(mo);
  DeltaConvMetric           = 2 * (sum(mo, abs(ConvMetricIter(mo,iter) - ConvMetricIter(mo,iter-1)))) / sum(mo, abs(ConvMetricIter(mo,iter) + ConvMetricIter(mo,iter-1))) / card(mo);
  DeltaConvMetricIter(iter) = max(tiny, DeltaConvMetric);

  # Check for oscillationer på månedsbasis.
  Found = FALSE
  #--- display "Detektering af oscillation af Phi:", IterNo, Phi;
  Loop (mo,
    dPhi(phiKind)       = PhiIter(phiKind,mo,iter) - PhiIter(phiKind,mo,iter-1);
    dPhiChange(phiKind) = abs(abs(dPhi(phiKind) - abs(dPhiIter(phiKind,mo,iter-1))));

    dPhiIter(phiKind,mo,iter)       = dPhi(phiKind);
    dPhiChangeIter(phiKind,mo,iter) = dPhiChange(phiKind);

    Loop (phiKind,
      if (IterNo GE 3 AND dPhi(phiKind) GT 1E-3,  # Kun oscillation hvis Phi har ændret sig siden forrige iteration.
        if (dPhiChange(phiKind) LE 1E-4,
          # Oscillation detekteret - justér begge Phi-faktorer for aktuel måned.
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
  #--- display "Iteration på ulineære afgiftsberegning:", IterNo, DeltaConvMetric, DeltaConvMetricTol;

  # Konvergens opnået i forrige iteration - aktuelle iteration er en finpudsning.
  if (ConvergenceFound,
    display "Konvergens opnået og finpudset", IterNo;
    break;
  );

  # Max. antal iterationer.
  if (IterNo GE NiterMax,
    display 'Max. antal iterationer anvendt.';
    break;
  );

  if (DeltaConvMetric <= DeltaConvMetricTol,
    display 'Konvergens opnået. Ændring af afgiftsbetaling opfylder accepttolerancen.', IterNo, DeltaConvMetric, DeltaConvMetricTol;
    ConvergenceFound = TRUE;
    break;
    #--- Udfør endnu en iteration, så modelvariable bliver opdateret med seneste justering af phi.
  else
    display "Endnu ingen konvergens opnået.";
  );
);

