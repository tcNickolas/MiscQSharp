# Decorating the Christmas Tree Using Grover's Search
## Part 3: Optimizing the Simulation

_This post was written for the [Q# Advent Calendar 2019](https://devblogs.microsoft.com/qsharp/q-advent-calendar-2019/). 
Check out the calendar for other cool posts!_

_This post is the third one in the series that describe solving a simple constraint-satisfaction problem using quantum computing and Grover's search. You might want to read [part 1](https://github.com/tcNickolas/MiscQSharp/tree/master/DecoratingTheTree#decorating-the-christmas-tree-using-grovers-search) and [part 2](https://github.com/tcNickolas/MiscQSharp/tree/master/DecoratingTheTree2019#decorating-the-christmas-tree-using-grovers-search) of the series before continuing reading this post._


In the end of previous episode we found ourselves in front of our favorite Christmas tree with four layers of branches in need of decorating, looking at a quantum program ready to tell us how exactly to decorate the tree. 

	   ?
	  ???
	 ?????
	???????
	   |

Alas, the program was taking a suspiciously long time to run - almost 21 minutes, longer than it would take to put up the ornaments!

In this episode we'll take a look at why this happens, and how to speed the things up.

## This is a simulation!

Let's keep in mind that we are not running this program on a quantum computer. Instead we're running it using a [quantum simulator](https://docs.microsoft.com/quantum/machines/full-state-simulator) - a classical program which models the behavior of a quantum system without accessing an actual quantum device. To do this, it represents the state of a quantum system as a vector of numbers and simulates primitive quantum operations like applying gates and performing measurements by updating these numbers. 

> We will not get into low-level implementation details of the simulator here (if you're curious, you can read its source [here](https://github.com/microsoft/qsharp-runtime/tree/master/src/Simulation)).

In general a state of an N-qubit system can be described using 2ᴺ complex numbers - the amplitudes of the system's wave function  (if you're not sure why, [this tutorial](https://github.com/microsoft/QuantumKatas/tree/master/tutorials/MultiQubitSystems) might be helpful). Each complex number is associated with one of the basis vectors of the system; for example, for N = 2 the basis vectors will be |00⟩, |01⟩, |10⟩ and |11⟩.

Applying a quantum gate to some of these qubits is going to affect a certain subset of those numbers; for example, if you apply an X gate to the leftmost qubit of your system, you'll need to swap the amplitudes of states |00⟩ and |10⟩ and of states |01⟩ and |11⟩, so all numbers will be affected. If you apply a CNOT gate with the leftmost qubit as a control and the rightmost qubit as target, you'll need to swap the amplitudes of states |10⟩ and |11⟩, and the amplitudes of states |00⟩ and |01⟩ will remain unchanged.

Now, what happens if you add an extra qubit to the system and try to simulate applying the same gates to the same qubits? With 3 qubits, there are 8 numbers to describe the state of the system, all of them will need to be updated when applying an X gate, and 4 of them will need to be updated when applying a CNOT gate. This pattern continues with addition of the next qubits: *the more qubits you have allocated, the longer applying each gate will take*.

> Optimizations, such as performing updates of different parts of the wave function in parallel, are possible, but they will take us only so far - and optimizing the simulation is outside of the scope of this post.

## Tweaking circuit width

Getting back to our program, how many qubits is our simulation using (i.e., what is the width of the circuit that represents this program)? Typically this question would be answered using [resource estimation](https://docs.microsoft.com/quantum/machines/resources-estimator), but our use case is relatively simple, so we can do it manually. For a tree with 4 layers, 

* `GroversSearch_Main` allocates 4² + 1 = 17 qubits to store the register of variables "does this branch have an ornament in it?" and the output variable to check that the algorithm result is correct.
* `Oracle_IsValidTreeDecoration` allocates 2 qubits to store the evaluation results of the two constraints.
* `Oracle_NoVerticallyAdjacentOrnaments` allocates (4 - 1)² = 9 qubits to store the results of checking whether any of the possible locations on the tree contains a pair of vertically adjacent ornaments.
* `Oracle_OneOrnamentPerLayer` allocates 4 qubits to store the results of checking whether any of the layers of branches contains 0 or 2+ ornaments.
* Note that the last two oracles deallocate the qubits they used before returning, so these qubits are allocated sequentially and not in parallel; thus the width of the circuit will only be affected by the larger of these two allocations (i.e., the allocation in `Oracle_NoVerticallyAdjacentOrnaments`).
* In total the program allocates at most 17 + 2 + 9 = 28 qubits at any given time.

This doesn't sound like a lot, but given that each extra qubit doubles the memory necessary to store the system state and increases the simulation time per gate, it might be the cause of the slowdown (for comparison, a tree with 3 layers required 16 qubits and took less than a minute to solve). Can we cut back on the number of qubits and see whether that helps our runtime?

1. Let's take a closer look at the order of qubit allocation and use inside `Oracle_IsValidTreeDecoration`:

       using ((a1, a2) = (Qubit(), Qubit())) {
           within {
               Oracle_NoVerticallyAdjacentOrnaments(nLayers, branches, a1);
               Oracle_OneOrnamentPerLayer(nLayers, branches, a2);
           } apply {
               Controlled X( [a1, a2], target);
           }
       }

   We allocate both auxiliary qubits `a1` and `a2`, then allocate extra qubits during the call  to `Oracle_NoVerticallyAdjacentOrnaments` (and compute `a1` in the process), then allocate extra qubits during the call to `Oracle_OneOrnamentPerLayer` (and compute `a2`), then compute `target` using both `a1` and `a2`, and then uncompute `a1` and `a2` in reverse order. 

   Notice that the qubit `a2` is allocated at the beginning of the computation but is used  only when evaluating `Oracle_OneOrnamentPerLayer`. If we can allocate that qubit after `Oracle_NoVerticallyAdjacentOrnaments` is executed and deallocate it before `Adjoint Oracle_NoVerticallyAdjacentOrnaments` is executed, we will reduce the circuit width by 1 qubit!

   And indeed, once we rewrite this code fragment as follows:

       using (a1 = Qubit()) {
           within {
               Oracle_NoVerticallyAdjacentOrnaments(nLayers, branches, a1);
           } apply {
               using (a2 = Qubit()) {
                   within {
                       Oracle_OneOrnamentPerLayer(nLayers, branches, a2);
                   } apply {
                       Controlled X([a1, a2], target);
                   }
               }
           }
       }

    the program execution time is reduced from 20 minutes to 13!

2. Similarly, we can notice that `GroversSearch_Main` allocates the qubit `output` together with the qubits `register` that are used in the oracles, but actually uses it only to check whether the measured answer is correct after the main loop. Bringing this qubit allocation closer to its use reduces program execution time further to 7 minutes.

We could probably squeeze out a couple more qubits by micro-optimizations here and there, but these two examples provide ample illustration for the idea - the more qubits are there in the simulated system, the more time it takes to simulate the same sequence of gates.

## Oracle emulation

Now let's take a look at a different approach to running this program, one that relies entirely on the fact that it happens on a classical device and not on a real one, called *emulation*.

The unitary transformations we consider in this blog are "permutation oracles" - each of them is defined by a certain permutation of basis states. If an oracle U implements a classical function f(x) as U|x⟩|y⟩ = |x⟩|y ⊕ f(x)⟩, it will permute the basis states as follows: for any x for which f(x) = 0 the basis states |x⟩|y⟩ will remain in their place in the permutation, and for any x for which f(x) = 1 the basis states |x⟩|0⟩ and |x⟩|1⟩ will be swapped. 

> Consider, for example, the CNOT gate: the permutation it implements is |00⟩, |01⟩, |10⟩, |11⟩ → |00⟩, |01⟩, |11⟩, |10⟩ (the first two basis states remain in their places, the last two are swapped).

Such structure of the unitaries allows to efficiently implement them in simulation, bypassing the Q# implementation of the unitary transformation altogether and performing the permutation of the basis states directly instead. To do this, you need to perform the following steps:

* define a classical function of an integer parameter f(x) that needs to be implemented by the oracle (individual variables can be accessed as bits of the integer). In our case the function takes an additional parameter `nLayers` to define the structure of the variables that comprise the integer parameter.
* define a permutation of the basis states based on this function.
* every time an oracle is called, invoke a specialized entry point in the simulator which applies this permutation of the basis states.

You can find the full code that defines the emulated version of the oracle [here](https://github.com/tcNickolas/MiscQSharp/tree/master/DecoratingTheTree2019-Optimize), together with the optimized version of Q# implementation we discussed in the previous section. The core part of the infrastructure code necessary to implement a permutation oracle as an emulation is based on [this sample](https://github.com/microsoft/Quantum/tree/master/samples/runtime/oracle-emulation).


## Are we done yet?

Yes! With the emulated version of the oracle, the Grover's search finds a solution in about 5 seconds - a nice improvement over the baseline of 20 minutes that we had at the beginning of the post.

	   0
	  0XX
	 XXX0X
	X0XXXXX
	   |

Finally, the tree is decorated (with two weeks to spare until Christmas!), and in the process we've learned several neat tricks for speeding up quantum simulations.

