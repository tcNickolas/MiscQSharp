namespace Quantum.DecoratingTheTree
{
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Canon;
    
    // The tree is represented as nSlots qubits arranged in nLayers layers;
    // for example, for nLayers = 3 nSlots = 9, arranged as follows:
    // ..X.. layer 0: qubit 0
    // .XXX. layer 1: qubits 1..3
    // XXXXX layer 2: qubits 4..8
    // In short, layer number i contains qubits i² through (i+1)²-1 (a total of 2i+1 qubits).

    // Step 0: let's migrate the code to 0.10 and take advantage of the latest language features
    // Optimizations/improvements: 
    // 1) jagged arrays: store qubits of each layer in a separate array instead of computing indices in 1D array
    // 2) rewrite in a way that allows to scale
    // 3) for equality of adjacent qubits: do each pair in-place, starting with the lowest layers, and do a one CNOT (no extra qubits allocated)
    // 4*) for one ornament per layer: implement a small counter which uses 2 extra qubits but smaller gates
    // 
    // Resource estimation:
    // Run resource estimation on the current implementation before starting to optimize it
    // Explain where all those qubits come from and why we care (the 4-layer tree is not possible to solve using the same approach)
    // Compare the results before/after optimization

    // The ornaments placed on a tree should satisfy 2 types of constraints:
    // 1) There should be no two ornaments that are vertically adjacent.
    //    This can be expressed more concisely: for layer number i, its qubit number j can not be in state |1⟩
    //    simultaneously with qubit number j+1 of layer i+1.

    // Helper function which marks pairs of qubits which are not in state |1⟩ simultaneously
    operation MarkValidPairs (register: Qubit[], targets: Qubit[], pairs: (Int, Int)[]) : Unit is Adj {
        // Each of the qubits in targets array will be flipped if qubits in the corresponding pair
        // are not in state |1⟩ simultaneously.
        for (((q1, q2), target) in Zip(pairs, targets)) {
            Controlled X([register[q1], register[q2]], target);
            X(target);
        }
    }

    operation Oracle_NoVerticallyAdjacentOrnaments (register: Qubit[], target: Qubit) : Unit is Adj {
        // Allocate as many extra qubits as there are constraints (for a 3-layer tree it's 4)
        using (extra = Qubit[4]) {
            let pairs = [(0, 2), (1, 5), (2, 6), (3, 7)];

            within {
                MarkValidPairs(register, extra, pairs);
            } apply {
                // The target qubit needs to be flipped if all extra qubits are in state |1⟩.
                Controlled X(extra, target);
            }
        }
    }

    // 2) Each layer of the tree should have exactly one ornament
    //    The easiest way to check this is as follows: either the first qubit is in state 1 and the rest are in state 0,
    //    or the second qubit is in state 1 and the rest are in state 0, and so on.

    // Helper function to mark layers which have exactly 1 qubit in state |1⟩ in them
    operation MarkValidLayers (register: Qubit[], targets: Qubit[]) : Unit is Adj {
        for (i in 0..2) {
            // Iterate over all possible bit strings which have exactly one bit set to 1
            let startInd = i * i;
            let endInd = (i + 1) * (i + 1);
            mutable bits = new Bool[endInd - startInd];
            for (ind in startInd .. endInd - 1) {
                (ControlledOnBitString(bits w/ ind - startInd <- true, X))(register[startInd..endInd-1], targets[i]);
            }
        }
    }

    operation Oracle_OneOrnamentPerLayer (register: Qubit[], target: Qubit) : Unit is Adj {
        // Allocate as many extra qubits as there are constraints (for a 3-layer tree it's 3)
        using (extra = Qubit[3]) {
            within {
                MarkValidLayers(register, extra);
            } apply {
                // The target qubits needs to be flipped if all extra qubits are in state |1⟩.
                Controlled X(extra, target);
            }
        }
    }

    // Finally, we need to combine two constraints into one to check that the tree decoration is valid.
    operation Oracle_IsValidTreeDecoration (register: Qubit[], target: Qubit) : Unit is Adj {
        using ((a1, a2) = (Qubit(), Qubit())) {
            within {
                Oracle_NoVerticallyAdjacentOrnaments(register, a1);
                Oracle_OneOrnamentPerLayer(register, a2);
            } apply {
                Controlled X( [a1, a2], target);
            }
        }
    }
}
