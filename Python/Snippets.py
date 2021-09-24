#%%

import numpy as np
from gekko import GEKKO

m = GEKKO(remote=False)

# Random 3x3
A = np.random.rand(3,3)
# Random 3x1
b = np.random.rand(3)
# Gekko array 3x1
x = m.Array(m.Var,(3))

# solve Ax = b
eqn = np.dot(A,x)
for i in range(3):
   m.Equation(eqn[i]==b[i])
m.solve(disp=True)
X = [x[i].value for i in range(3)]
print(X)
print(b)
print(eqn)
X = (np.transpose(X))[0]
print(np.dot(A,X))
print(np.dot(A,X) - b)

#%%