// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

namespace Microsoft.Quantum.Samples.ColoringGroverWithConstraints {
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Measurement;

    /// # Summary
    /// Read color from a register.
    ///
    /// # Input
    /// ## register
    /// The register of qubits to be measured.
    operation MeasureColor (register : Qubit[]) : Int {
        return MeasureInteger(LittleEndian(register));
    }

    /// # Summary
    /// Read coloring from a register.
    ///
    /// # Input
    /// ## bitsPerColor
    /// Number of bits per color.
    /// ## register
    /// The register of qubits to be measured.
    operation MeasureColoring (bitsPerColor : Int, register : Qubit[]) : Int[] {
        let numVertices = Length(register) / bitsPerColor;
        let colorPartitions = Partitioned(ConstantArray(numVertices - 1, bitsPerColor), register);
        return ForEach(MeasureColor, colorPartitions);
    }

    /// # Summary
    /// N-bit color equality oracle (no extra qubits.)
    ///
    /// # Input
    /// ## color0
    /// First color.
    /// ## color1
    /// Second color.
    /// ## target
    /// Will be flipped if colors are the same.
    operation ApplyColorEqualityOracle(
        color0 : Qubit[], color1 : Qubit[],
        target : Qubit
    )
    : Unit is Adj + Ctl {
        within {
            // compute XOR of q0 and q1 in place (storing it in q1).
            ApplyToEachCA(CNOT, Zipped(color0, color1));
        } apply {
            // if all XORs are 0, the bit strings are equal.
            ControlledOnInt(0, X)(color1, target);
        }
    }

    /// # Summary
    /// Oracle for verifying vertex coloring, excluding color constraints from
    /// non qubit vertices.
    operation ApplyVertexColoringOracle (
        numVertices : Int, 
        bitsPerColor : Int, 
        edges : (Int, Int)[],
        colorsRegister : Qubit[],
        target : Qubit
    )
    : Unit is Adj + Ctl {
        let nEdges = Length(edges);
        // We are looking for a solution that:
        // has no edge with same color at both ends.
        use edgeConflictQubits = Qubit[nEdges];
        within {
            for ((start, end), conflictQubit) in Zipped(edges, edgeConflictQubits) {
                // Check that endpoints of the edge have different colors:
                // apply ApplyColorEqualityOracle oracle;
                // if the colors are the same the result will be 1, indicating a conflict
                ApplyColorEqualityOracle(
                    colorsRegister[start * bitsPerColor .. (start + 1) * bitsPerColor - 1],
                    colorsRegister[end * bitsPerColor .. (end + 1) * bitsPerColor - 1],
                    conflictQubit
                );
            }
        } apply {
            // If there are no conflicts (all qubits are in 0 state), the vertex coloring is valid.
            ControlledOnInt(0, X)(edgeConflictQubits, target);
        }
    }


    /// # Summary
    /// Using Grover's search to find vertex coloring.
    ///
    /// # Input
    /// ## numVertices
    /// The number of vertices in the graph.
    /// ## bitsPerColor
    /// The number of bits per color.
    /// ## maxIterations
    /// An estimate of the maximum iterations needed.
    /// ## oracle
    /// The oracle used to find solution.
    /// ## statePrep
    /// Routine that prepares an equal superposition of all basis states in the search space.
    ///
    /// # Output
    /// Int Array giving the color of each vertex.
    ///
    /// # Remarks
    /// See https://github.com/microsoft/QuantumKatas/tree/main/SolveSATWithGrover
    /// for original implementation in SolveSATWithGrover Kata.
    operation FindColorsWithGrover (
        numVertices : Int, bitsPerColor : Int, nIterations : Int,
        oracle : ((Qubit[], Qubit) => Unit is Adj),
        statePrep : (Qubit[] => Unit is Adj)
    ) : Int[] {
        // Note that coloring register has the number of qubits that is
        // twice the number of vertices (bitsPerColor qubits per vertex).
        use register = Qubit[bitsPerColor * numVertices];

        Message($"Trying search with {nIterations} iterations...");
        ApplyGroversAlgorithmLoop(register, oracle, statePrep, nIterations);
        let res = MultiM(register);
        // We check whether the result is correct in the classic code.
        let coloring = MeasureColoring(bitsPerColor, register);
        ResetAll(register);
        return coloring;
    }

    /// # Summary
    /// Grover algorithm loop
    ///
    /// # Input
    /// ## oracle
    /// The oracle which will mark the valid solutions.
    ///
    /// # Remarks
    /// See https://github.com/microsoft/QuantumKatas/tree/main/SolveSATWithGrover
    /// for the original implementation from the SolveSATWithGrover kata.
    operation ApplyPhaseOracle (oracle : ((Qubit[], Qubit) => Unit is Adj),
        register : Qubit[]
    )
    : Unit is Adj {
        use target = Qubit();
        within {
            // Put the target into the |-⟩ state.
            X(target);
            H(target);
        } apply {
            // Apply the marking oracle; since the target is in the |-⟩ state,
            // flipping the target if the register satisfies the oracle condition
            // will apply a -1 factor to the state.
            oracle(register, target);
        }
        // We put the target back into |0⟩ so we can return it.
    }

    /// # Summary
    /// Grover's Algorithm loop.
    ///
    /// # Input
    /// ## register
    /// The register of qubits.
    /// ## oracle
    /// The oracle defining the solution we want.
    /// ## iterations
    /// The number of iterations to try.
    ///
    /// # Output
    /// Unitary implementing Grover's search algorithm.
    operation ApplyGroversAlgorithmLoop(
        register : Qubit[],
        oracle : ((Qubit[], Qubit) => Unit is Adj),
        statePrep : (Qubit[] => Unit is Adj),
        iterations : Int
    )
    : Unit {
        let applyPhaseOracle = ApplyPhaseOracle(oracle, _);
        statePrep(register);

        for i in 1 .. iterations {
            applyPhaseOracle(register);
            Message($"{i}: oracle done");
            within {
                Adjoint statePrep(register);
                ApplyToEachA(X, register);
            } apply {
                Controlled Z(Most(register), Tail(register));
            }
            Message($"{i}: reflections done");
        }
    }
}
