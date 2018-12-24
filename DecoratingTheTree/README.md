# Decorating the Christmas Tree Using Grover's Search

_This post was written for the [Q# Advent Calendar 2018](https://blogs.msdn.microsoft.com/visualstudio/2018/11/15/q-advent-calendar-2018/) in co-authorship with [Paige Frederick](https://github.com/paigehf). 
Check out the calendar for other cool posts!_

Santa's elves decorate all of the Christmas trees in the North Pole. This is not a demanding task in general, but there is one special tree which is Mrs. Claus' favorite and has to be decorated in a very particular way.

	  X
	 XXX
	XXXXX
	  |

First, there has to be exactly one ornament on each layer of the tree. Second, no two ornaments should be vertically adjacent to each other.

Fortunately, the tree in question is very small, having only three layers, and it's fairly easy to find some way to place the ornaments on it to satisfy the constraints. But why do it by hand when you can use quantum computing to find it instead?

## Constraint Satisfaction Problem

The problem of decorating the tree is a constraint satisfaction problem: we need to find an assignment of values to a set of variables to satisfy the given constraints on them. 

Our variables are 9 boolean values, each one representing one position on the tree: true means there is an ornament in this position, and false means there is none. Here is how they are arranged:

          x0
	   x1 x2 x3
    x4 x5 x6 x7 x8

The first constraint requires that each layer of the tree has exactly one ornament on it; in terms of variables, this means that exactly one variable of each set `{x0}`, `{x1, x2, x3}` and `{x4, ..., x8}` has to be true, and the rest of them should be false. (We can of course immediately see that `x0` has to be true, but let's keep it general.)

The second constraint prohibits any two ornaments to be vertically adjacent. This means, for example, that `x0` and `x2` can not be true at the same time (and since we know that `x0` is true, `x2` has to be false).

The overall problem is solved if we find an assignment which satisfies both constraints.

## Quantum Oracle

To solve this kind of a problem using a quantum algorithm, we need to represent the problem as a quantum oracle - a circuit which will evaluate the constraints and output 1 if they are satisfied and 0 otherwise. You can read more about the quantum oracles [here](https://docs.microsoft.com/en-us/quantum/concepts/oracles).

To build the oracle, it's useful to start with small building blocks - logic functions which will then be assembled into constraints.

* The AND function takes several inputs and outputs 1 if all of them are in state |1⟩. This can be implemented using a controlled NOT gate with inputs as controls. We'll use this to check that both constraints are satisfied.
* The "two inputs are not |1⟩ simultaneously" function can be thought of as a negation of the AND function - it is 0 only if both inputs are |1⟩. This can be implemented using a controlled NOT gate, followed by an X gate on the target qubit.
* The "exactly one input is in state |1⟩" function can be represented as a set of mutually exclusive if statements: it is 1 if the first input is |1⟩ and the rest are |0⟩s, or if the second input is |1⟩ and the rest are |0⟩s, and so on. Each statement is represented as a NOT gate, controlled on a certain bit pattern of the inputs (see [`ControlledOnBitString`](https://docs.microsoft.com/en-us/qsharp/api/canon/microsoft.quantum.canon.controlledonbitstring) library function).

## Grover's Algorithm

Now that we have a quantum oracle which can tell us whether a certain interpretation of variables satisfies the constraints, we can finally solve the problem! This can be done using Grover's algorithm - one of the most famous quantum computing algorithms. It has even been covered in the Q# Advent Calendar - check out how it saved Christmas [here](https://github.com/anraman/quantum/blob/master/GroverDatabaseSearch/BlogPost/GroversBlog_Festive.md)! And if you're looking to learn how to implement Grover's search in Q#, we suggest you try [the eponymous quantum kata](https://github.com/Microsoft/QuantumKatas/tree/master/GroversAlgorithm).

The only thing we need to figure out before applying the Grover's search is how many iterations to use. The search space size N is the total number of possible ways to decorate the tree; there are 9 independent boolean variables, so N = 2<sup>9</sup>. The number of valid ways k is straightforward to estimate too: the first layer is defined uniquely, and each next layer can have an ornament in any position except one (the one which is directly below the ornament of the layer above), so k = 1 * (3 - 1) * (5 - 1) = 8. The number of iterations for the search is thus π/4 * sqrt(N/k) = 2π ≈ 6.

## So, about those decorations...

With all that said and done, we can go ahead and finally write the code to solve the problem! You can find the full code for both the oracles and the Grover's search [here](https://github.com/tcNickolas/MiscQSharp/tree/master/DecoratingTheTree) (use `DecoratingTheTree.sln` to open the projects in Visual Studio).

Run the project, and it will output one of the eight valid ways to decorate the tree:

	  0
	 0XX
	XXX0X
	  |
	Press any key to continue...

The elves have actually gone off and decorated the tree while we were discussing the proper quantum way to do it. Oh well, at least we're covered for the next year. Unless the tree grows taller...