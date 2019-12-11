namespace Quantum.DecoratingTheTree
{
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Canon;
    
    // The tree is represented as nSlots qubits arranged in nLayers layers;
    // for example, for nLayers = 3 nSlots = 9, arranged as follows:
    // ..X..
    // .XXX.
    // XXXXX

    // The ornaments placed on a tree should satisfy 2 types of constraints:
    // 1) There should be no two ornaments that are vertically adjacent.
    //    This can be expressed more concisely: for layer number i, its qubit number j can not be in state |1⟩
    //    simultaneously with qubit number j+1 of layer i+1.
    operation Oracle_NoVerticallyAdjacentOrnaments (nLayers : Int, branches: Qubit[][], target: Qubit) : Unit is Adj {
        // Allocate as many extra qubits as there are constraints ((nLayers - 1)²)
        using (extra = Qubit[(nLayers - 1) ^ 2]) {
            // Partition the extra qubits into layers corresponding to the top qubit of the vertical pair
            let extraLayered = Partitioned(RangeAsIntArray(1 .. 2 .. 2 * (nLayers - 1) - 1), extra);
            within {
                for (layerInd in 0 .. nLayers - 2) {
                    for (branchInd in 0 .. 2 * layerInd) {
                        Controlled X([branches[layerInd][branchInd], branches[layerInd + 1][branchInd + 1]],
                                     extraLayered[layerInd][branchInd]);
                        X(extraLayered[layerInd][branchInd]);
                    }
                }
            } apply {
                // The target qubit needs to be flipped if all extra qubits are in state |1⟩.
                Controlled X(extra, target);
            }
        }
    }

    // 2) Each layer of the tree should have exactly one ornament
    //    The easiest way to check this is as follows: either the first qubit is in state 1 and the rest are in state 0,
    //    or the second qubit is in state 1 and the rest are in state 0, and so on.
    operation Oracle_OneOrnamentPerLayer (nLayers : Int, branches: Qubit[][], target: Qubit) : Unit is Adj {
        // Allocate as many extra qubits as there are constraints (one per layer)
        using (extra = Qubit[nLayers]) {
            within {
                for (layerInd in 0 .. nLayers - 1) {
                    let bits = new Bool[2 * layerInd + 1];
                    for (branchInd in 0 .. 2 * layerInd) {
                        (ControlledOnBitString(bits w/ branchInd <- true, X))(branches[layerInd], extra[layerInd]);
                    }
                }
            } apply {
                // The target qubits needs to be flipped if all extra qubits are in state |1⟩
                Controlled X(extra, target);
            }
        }
    }

    // Finally, we need to combine two constraints into one to check that the tree decoration is valid.
    operation Oracle_IsValidTreeDecoration (nLayers : Int, register: Qubit[], target: Qubit) : Unit is Adj {
        // Arrange the branches of the tree (the qubits) as a jagged array
        // by partitioning the elements of the input register into batches of 1, 3, ... , 2 * nLayers - 1 qubits
        let branches = Partitioned(RangeAsIntArray(1 .. 2 .. 2 * nLayers - 1), register);

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
    }


    // -------------------------------------------------------------
    operation EmulatedOracle (nLayers : Int, register: Qubit[], target: Qubit) : Unit is Adj {
        fail "Not implemented in Q#";
    }
}
