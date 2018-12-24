namespace Quantum.DecoratingTheTree
{
    open Microsoft.Quantum.Primitive;
    open Microsoft.Quantum.Canon;
    
    // The tree is represented with 9 qubits arranged in 3 layers
    // ..X.. layer 0: qubit 0
    // .XXX. layer 1: qubits 1..3
    // XXXXX layer 2: qubits 4..8
    // In short, layer number i contains qubits i² through (i+1)²-1 (a total of 2i+1 qubits).

    // The ornaments placed on a tree should satisfy 2 types of constraints:
    // 1) There should be no two ornaments that are vertically adjacent.
    //    This constraint is violated if qubits 0 and 2 are in state |1⟩ simultaneously,
    //    or qubits 1 and 5, 2 and 6 or 3 and 7.
    //    This can be expressed more concisely: for layer number i, its qubit number j can not be in state |1⟩
    //    simultaneously with qubit number j+1 of layer i+1; or, in absolute indexes, 
    //    qubits i²+j and (i+1)²+j+1 can not be in state |1⟩ simultaneously.

    // Helper function which marks pairs of qubits which are not in state |1⟩ simultaneously
    operation MarkValidPairs (register: Qubit[], targets: Qubit[], pairs: (Int, Int)[]) : Unit {
        body(...) {
            // Each of the qubits in targets array will be flipped if qubits in the corresponding pair
            // are not in state |1⟩ simultaneously.
            for (ind in 0..Length(pairs)-1) {
                let (q1, q2) = pairs[ind];
                Controlled X([register[q1], register[q2]], targets[ind]);
                X(targets[ind]);
            }
        }    
        adjoint self;
    }

    operation Oracle_NoVerticallyAdjacentOrnaments (register: Qubit[], target: Qubit) : Unit {
        body(...) {
            // Allocate as many extra qubits as there are constraints (for a 3-layer tree it's 4)
            using (extra = Qubit[4]) {
                let pairs = [(0, 2), (1, 5), (2, 6), (3, 7)];

                MarkValidPairs(register, extra, pairs);
                // The target qubit needs to be flipped if all extra qubits are in state |1⟩.
                Controlled X(extra, target);

                // Uncompute the extra qubits
                Adjoint MarkValidPairs(register, extra, pairs);
            }
        }
        adjoint self;
    }

    // 2) Each layer of the tree should have exactly one ornament
    //    The easiest way to check this is as follows: either the first qubit is in state 1 and the rest are in state 0,
    //    or the second qubit is in state 1 and the rest are in state 0, and so on.

    // Helper function to mark layers which have exactly 1 qubit in state |1⟩ in them
    operation MarkValidLayers (register: Qubit[], targets: Qubit[]) : Unit {
        body(...) {
            for (i in 0..2) {
                // Iterate over all possible bit strings which have exactly one bit set to 1
                let startInd = i * i;
                let endInd = (i + 1) * (i + 1);
                mutable bits = new Bool[endInd - startInd];
                for (ind in startInd .. endInd - 1) {
                    set bits[ind - startInd] = true;
                    (ControlledOnBitString(bits, X))(register[startInd..endInd-1], targets[i]);
                    set bits[ind - startInd] = false;
                }
            }
        }
        adjoint self;
    }

    operation Oracle_OneOrnamentPerLayer (register: Qubit[], target: Qubit) : Unit {
        body(...) {
            // Allocate as many extra qubits as there are constraints (for a 3-layer tree it's 3)
            using (extra = Qubit[3]) {
                MarkValidLayers(register, extra);

                // The target qubits needs to be flipped if all extra qubits are in state |1⟩.
                Controlled X(extra, target);

                // Uncompute the extra qubits
                Adjoint MarkValidLayers(register, extra);
            }
        }
        adjoint self;
    }

    // Finally, we need to combine two constraints into one to check that the tree decoration is valid.
    operation Oracle_IsValidTreeDecoration (register: Qubit[], target: Qubit) : Unit {
        body(...) {
            using ((a1, a2) = (Qubit(), Qubit())) {
                Oracle_NoVerticallyAdjacentOrnaments(register, a1);
                Oracle_OneOrnamentPerLayer(register, a2);
                Controlled X( [a1, a2], target);
                Adjoint Oracle_NoVerticallyAdjacentOrnaments(register, a1);
                Adjoint Oracle_OneOrnamentPerLayer(register, a2);
            }
        }
        adjoint self;
    }
}
