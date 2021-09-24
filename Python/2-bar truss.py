import numpy as np

# import gekko, pip install if needed
from gekko import GEKKO

# create new model
m = GEKKO()

# declare model parameters
width = m.Param(value=60)
thickness = m.Param(value=0.15)
density = m.Param(value=0.3)
modulus = m.Param(value=30000)
load = m.Param(value=66)

# declare variables and initial guesses
height = m.Var(value=30.00,lb=10.0,ub=50.0)
diameter = m.Var(value=3.00,lb=1.0,ub=4.0)
weight = m.Var()

# intermediate variables with explicit equations
leng = m.Intermediate(m.sqrt((width/2)**2 + height**2))
area = m.Intermediate(np.pi * diameter * thickness)
iovera = m.Intermediate((diameter**2 + thickness**2)/8)
stress = m.Intermediate(load * leng / (2*area*height))
buckling = m.Intermediate(np.pi**2 * modulus \
              * iovera / (leng**2))
deflection = m.Intermediate(load * leng**3 \
              / (2 * modulus * area * height**2))

# implicit equations
m.Equation(weight==2*density*area*leng)
m.Equation(weight < 24)
m.Equation(stress < 100)
m.Equation(stress < buckling)
m.Equation(deflection < 0.25)

# minimize weight
m.Minimize(weight)

# solve optimization
m.solve()  # remote=False for local solve

print ('')
print ('--- Results of the Optimization Problem ---')
print ('Height: ' + str(height.value))
print ('Diameter: ' + str(diameter.value))
print ('Weight: ' + str(weight.value))