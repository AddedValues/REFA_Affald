#%% 
#region ORTOOLS example 4: Cloned from the MIP-package: Two-Dimensional Level Packing 
# See: https://docs.python-mip.com/en/latest/examples.html
# from mip import Model, BINARY, minimize, xsum
from ortools.linear_solver import pywraplp
import ortools.sat as sat
from ortools.linear_solver.linear_solver_natural_api import VariableExpr



#region Data
#    0  1  2  3  4  5  6  7
w = [4, 3, 5, 2, 1, 4, 7, 3]  # widths
h = [2, 4, 1, 5, 6, 3, 5, 4]  # heights
n = len(w)
I = set(range(n))
S = [[j for j in I if h[j] <= h[i]] for i in I]
G = [[j for j in I if h[j] >= h[i]] for i in I]

# raw material width
W = 10
#endregion 

# m = Model()
m:pywraplp.Solver = pywraplp.Solver.CreateSolver('SCIP')

x = [{j: m.IntVar(name='x[{0}][{1}]'.format(j,i), lb=0.0, ub=1.0) for j in S[i]} for i in I]

m.Minimize(m.Sum(h[i] * x[i][i] for i in I))

# each item should appear as larger item of the level
# or as an item which belongs to the level of another item
for i in I:
    # m += xsum(x[j][i] for j in G[i]) == 1
    m.Add(m.Sum(x[j][i] for j in G[i]) == 1, name='OnlyOne[{0}]'.format(i))

# represented items should respect remaining width
for i in I:
    # m += xsum(w[j] * x[i][j] for j in S[i] if j != i) <= (W - w[i]) * x[i][i]
    m.Add(m.Sum(w[j] * x[i][j] for j in S[i] if j != i) <= (W - w[i]) * x[i][i], name='MaxWidth[{0}]'.format(i))

# m.optimize()
status = m.Solve()

# xx:pywraplp.VariableExpr = x[0][0]
# print(xx.solution_value())

# [START print_solution]
if status == pywraplp.Solver.OPTIMAL:
    print('Solution:')
    print('Objective value =', m.Objective().Value())
    for i in [j for j in I if x[j][j].solution_value() >= 0.99]:
        print(
            "Items grouped with {} : {}".format(
                i, [j for j in S[i] if i != j and x[i][j].solution_value() >= 0.99]
            )
        )
    print('\nAdvanced usage:')
    print('Problem solved in %f milliseconds' % m.wall_time())
    print('Problem solved in %d iterations' % m.iterations())
    print('Problem solved in %d branch-and-bound nodes' % m.nodes())

else:
    print('The problem does not have an optimal solution.')
# [END print_solution]

#endregion 

#%%

aaa = m.Add(m.Sum(w[j] * x[i][j] for j in S[i] if j != i) <= (W - w[i]) * x[i][i], name='Dummy[{0}]'.format(i))


#%% ORTOOLS example 3

from ortools.linear_solver import pywraplp

def create_data_model():
    """Stores the data for the problem."""
    data = {}
    data['constraint_coeffs'] = [
        [5, 7, 9, 2, 1],
        [18, 4, -9, 10, 12],
        [4, 7, 3, 8, 5],
        [5, 13, 16, 3, -7],
    ]
    data['bounds'] = [250, 285, 211, 315]
    data['obj_coeffs'] = [7, 8, 2, 9, 6]
    data['num_vars'] = 5
    data['num_constraints'] = 4
    return data

def main():
    data = create_data_model()
    # Create the mip solver with the SCIP backend.
    solver = pywraplp.Solver.CreateSolver('SCIP')

    infinity = solver.infinity()
    x = {}
    for j in range(data['num_vars']):
        x[j] = solver.IntVar(0, infinity, 'x[%i]' % j)
    print('Number of variables =', solver.NumVariables())

    for i in range(data['num_constraints']):
        constraint = solver.RowConstraint(0, data['bounds'][i], '')
        for j in range(data['num_vars']):
            constraint.SetCoefficient(x[j], data['constraint_coeffs'][i][j])
    print('Number of constraints =', solver.NumConstraints())
    # In Python, you can also set the constraints as follows.
    # for i in range(data['num_constraints']):
    #  constraint_expr = \
    # [data['constraint_coeffs'][i][j] * x[j] for j in range(data['num_vars'])]
    #  solver.Add(sum(constraint_expr) <= data['bounds'][i])

    objective = solver.Objective()
    for j in range(data['num_vars']):
        objective.SetCoefficient(x[j], data['obj_coeffs'][j])
    objective.SetMaximization()
    # In Python, you can also set the objective as follows.
    # obj_expr = [data['obj_coeffs'][j] * x[j] for j in range(data['num_vars'])]
    # solver.Maximize(solver.Sum(obj_expr))

    status = solver.Solve()

    if status == pywraplp.Solver.OPTIMAL:
        print('Objective value =', solver.Objective().Value())
        for j in range(data['num_vars']):
            print(x[j].name(), ' = ', x[j].solution_value())
        print()
        print('Problem solved in %f milliseconds' % solver.wall_time())
        print('Problem solved in %d iterations' % solver.iterations())
        print('Problem solved in %d branch-and-bound nodes' % solver.nodes())
    else:
        print('The problem does not have an optimal solution.')

if __name__ == '__main__':
    main()

#%% ORTOOLS example 2
#region ORTOOLS Example 2
from ortools.linear_solver import pywraplp

def main():
    # Create the mip solver with the SCIP backend.
    solver = pywraplp.Solver.CreateSolver('SCIP')

    infinity = solver.infinity()
    # x and y are integer non-negative variables.
    x = solver.IntVar(0.0, infinity, 'x')
    y = solver.IntVar(0.0, infinity, 'y')

    print('Number of variables =', solver.NumVariables())

    # x + 7 * y <= 17.5.
    solver.Add(x + 7 * y <= 17.5)

    # x <= 3.5.
    solver.Add(x <= 3.5)

    print('Number of constraints =', solver.NumConstraints())

    # Maximize x + 10 * y.
    solver.Maximize(x + 10 * y)

    status = solver.Solve()

    if status == pywraplp.Solver.OPTIMAL:
        print('Solution:')
        print('Objective value =', solver.Objective().Value())
        print('x =', x.solution_value())
        print('y =', y.solution_value())
    else:
        print('The problem does not have an optimal solution.')

    print('\nAdvanced usage:')
    print('Problem solved in %f milliseconds' % solver.wall_time())
    print('Problem solved in %d iterations' % solver.iterations())
    print('Problem solved in %d branch-and-bound nodes' % solver.nodes())


if __name__ == '__main__':
    main()
#endregion 

#%% ORTOOLS example 1
#region ORTOOLS Example 1
from ortools.linear_solver import pywraplp
from ortools.init import pywrapinit

def main():
    # Create the linear solver with the GLOP backend.
    solver = pywraplp.Solver.CreateSolver('GLOP')

    # Create the variables x and y.
    x = solver.NumVar(0, 1, 'x')
    y = solver.NumVar(0, 2, 'y')

    print('Number of variables =', solver.NumVariables())

    # Create a linear constraint, 0 <= x + y <= 2.
    ct = solver.Constraint(0, 2, 'ct')
    ct.SetCoefficient(x, 1)
    ct.SetCoefficient(y, 1)

    print('Number of constraints =', solver.NumConstraints())

    # Create the objective function, 3 * x + y.
    objective = solver.Objective()
    objective.SetCoefficient(x, 3)
    objective.SetCoefficient(y, 1)
    objective.SetMaximization()

    solver.Solve()

    print('Solution:')
    print('Objective value =', objective.Value())
    print('x =', x.solution_value())
    print('y =', y.solution_value())


if __name__ == '__main__':
    pywrapinit.CppBridge.InitLogging('basic_example.py')
    cpp_flags = pywrapinit.CppFlags()
    cpp_flags.logtostderr = True
    cpp_flags.log_prefix = False
    pywrapinit.CppBridge.SetFlags(cpp_flags)

    main()
#endregion 

#%% MIP examples
#region 
# See: https://docs.python-mip.com/en/latest/examples.html
import matplotlib.pyplot as plt
from math import sqrt, log
from itertools import product
from mip import Model, xsum, minimize, OptimizationStatus

# possible plants
F = [1, 2, 3, 4, 5, 6]

# possible plant installation positions
pf = {1: (1, 38), 2: (31, 40), 3: (23, 59), 4: (76, 51), 5: (93, 51), 6: (63, 74)}

# maximum plant capacity
c = {1: 1955, 2: 1932, 3: 1987, 4: 1823, 5: 1718, 6: 1742}

# clients
C = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

# position of clients
pc = {1: (94, 10), 2: (57, 26), 3: (74, 44), 4: (27, 51), 5: (78, 30), 6: (23, 30), 
      7: (20, 72), 8: (3, 27), 9: (5, 39), 10: (51, 1)}

# demands
d = {1: 302, 2: 273, 3: 275, 4: 266, 5: 287, 6: 296, 7: 297, 8: 310, 9: 302, 10: 309}

# plotting possible plant locations
for i, p in pf.items():
    plt.scatter((p[0]), (p[1]), marker="^", color="purple", s=50)
    plt.text((p[0]), (p[1]), "$f_%d$" % i)

# plotting location of clients
for i, p in pc.items():
    plt.scatter((p[0]), (p[1]), marker="o", color="black", s=15)
    plt.text((p[0]), (p[1]), "$c_{%d}$" % i)

plt.text((20), (78), "Region 1")
plt.text((70), (78), "Region 2")
plt.plot((50, 50), (0, 80))

dist = {(f, c): round(sqrt((pf[f][0] - pc[c][0]) ** 2 + (pf[f][1] - pc[c][1]) ** 2), 1)
        for (f, c) in product(F, C) }

m = Model()

z = {i: m.add_var(ub=c[i]) for i in F}  # plant capacity

# Type 1 SOS: only one plant per region
for r in [0, 1]:
    # set of plants in region r
    Fr = [i for i in F if r * 50 <= pf[i][0] <= 50 + r * 50]
    m.add_sos([(z[i], i - 1) for i in Fr], 1)

# amount that plant i will supply to client j
x = {(i, j): m.add_var() for (i, j) in product(F, C)}

# satisfy demand
for j in C:
    m += xsum(x[(i, j)] for i in F) == d[j]

# SOS type 2 to model installation costs for each installed plant
y = {i: m.add_var() for i in F}
for f in F:
    D = 6  # nr. of discretization points, increase for more precision
    v = [c[f] * (v / (D - 1)) for v in range(D)]  # points
    # non-linear function values for points in v
    vn = [0 if k == 0 else 1520 * log(v[k]) for k in range(D)]  
    # w variables
    w = [m.add_var() for v in range(D)]
    m += xsum(w) == 1  # convexification
    # link to z vars
    m += z[f] == xsum(v[k] * w[k] for k in range(D))
    # link to y vars associated with non-linear cost
    m += y[f] == xsum(vn[k] * w[k] for k in range(D))
    m.add_sos([(w[k], v[k]) for k in range(D)], 2)

# plant capacity
for i in F:
    m += z[i] >= xsum(x[(i, j)] for j in C)

# objective function
m.objective = minimize(
    xsum(dist[i, j] * x[i, j] for (i, j) in product(F, C)) + xsum(y[i] for i in F) )

m.write('mipmodel.lp')
m.write('mipmodel.mps')
m.optimize()

plt.savefig("location.pdf")

if m.num_solutions:
    print("Solution with cost {} found.".format(m.objective_value))
    print("Facilities capacities: {} ".format([z[f].x for f in F]))
    print("Facilities cost: {}".format([y[f].x for f in F]))

    # plotting allocations
    for (i, j) in [(i, j) for (i, j) in product(F, C) if x[(i, j)].x >= 1e-6]:
        plt.plot(
            (pf[i][0], pc[j][0]), (pf[i][1], pc[j][1]), linestyle="--", color="darkgray"
        )

    plt.savefig("location-sol.pdf")

#endregion 

#%%
#region 
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
#endregion 

#%%
#region 
uprio2up = np.zeros((2,6), dtype=bool)
print (uprio2up)
# %%
dic = {'a':1, 'c':2}
n = 2
x = dic['b'] if n == 2 else 'not found'
print(x)
#endregion
# %%
#region Python program to demonstrate iterator module
# See: https://www.geeksforgeeks.org/python-itertools/
# See: https://more-itertools.readthedocs.io/en/stable/api.html#
import operator
import time
 
# Defining lists
L1 = [1, 2, 3]
L2 = [2, 3, 4]
 
# Starting time before map
# function
t1 = time.time()
 
# Calculating result
a, b, c = map(operator.mul, L1, L2)
 
# Ending time after map
# function
t2 = time.time()
 
# Time taken by map function
print("Result:", a, b, c)
print("Time taken by map function: %.10f" %(t2 - t1))
 
# Starting time before naive
# method
t1 = time.time()
 
# Calculating result using for loop
print("Result:", end = " ")
for i in range(3):
    print(L1[i] * L2[i], end = " ")
     
# Ending time after naive
# method
t2 = time.time()
print("\nTime taken by for loop: %.10f" %(t2 - t1))

#endregion 
# %%
