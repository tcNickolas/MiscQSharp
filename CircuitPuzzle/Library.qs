namespace Quantum.CircuitPuzzle {

    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    
    /// # Summary
    /// Applies a single-qubit gate based on its string representation.
    operation ApplyGate (q : Qubit, gateStr : String) : Unit is Adj + Ctl {
        let gate = gateStr == "H" ? H | gateStr == "X" ? X | gateStr == "Z" ? Z | I;
        gate(q);
    }


    /// # Summary
    /// Applies the circuit from the puzzle to a pair of qubits
    /// based on the sequence of gates provided as their string names.
    /// The order of gates in the array is "top left" - "top right" - "bottom left" - "bottom right".
    operation ApplyCircuit (qs : Qubit[], gatesStr : String[]) : Unit is Adj + Ctl {
        ApplyGate(qs[0], gatesStr[0]);
        ApplyGate(qs[1], gatesStr[2]);
        CNOT(qs[0], qs[1]);
        ApplyGate(qs[0], gatesStr[1]);
        ApplyGate(qs[1], gatesStr[3]);
    }


    /// # Summary
    /// Test the third constraint ("Swapping the two gates that act on the bottom qubit changes the state").
    /// The constraint is satisfied if this code throws an exception.
    operation TestThirdConstraint (gates : String[]) : Unit {
        use qs = Qubit[2];
        // Run the circuit as is.
        ApplyCircuit(qs, gates);
        // Swap the two gates acting on the bottom qubit (indices 2 and 3) and apply adjoint of the circuit.
        Adjoint ApplyCircuit(qs, Swapped(2, 3, gates));
        // If the result is not 00, the constraint is satisfied.
        // This will be tested by catching the exception from classical host.
        AssertAllZero(qs);
    }


    /// # Summary
    /// Test the fourth constraint ("Swapping the two gates applied after the CNOT gate 
    /// (on the right side of the circuit) does not change the state but changes its global phase").
    /// The constraint is satisfied if this code does not throw an exception.
    operation TestFourthConstraint (gates : String[]) : Unit {
        // Test the first part of the constraint.
        use qs = Qubit[2];
        // Run the circuit as is.
        ApplyCircuit(qs, gates);
        // Swap the two gates acting on the right (indices 1 and 3) and apply adjoint of the circuit.
        Adjoint ApplyCircuit(qs, Swapped(1, 3, gates));
        // If the result is 00, the first part of the constraint (does not change the state) is satisfied.
        AssertAllZero(qs);

        // Test the second part of the constraint.
        use qCtrl = Qubit();
        H(qCtrl);
        // Run the controlled circuit as is.
        Controlled ApplyCircuit([qCtrl], (qs, gates));
        // Swap the two gates acting on the right (indices 1 and 3) and apply controlled adjoint of the circuit.
        Controlled Adjoint ApplyCircuit([qCtrl], (qs, Swapped(1, 3, gates)));
        // We know that if the phase changed, it must've changed by -1 (only Z gate can introduce the phase),
        // so the state after this should be |-⟩ |00⟩.
        H(qCtrl);
        X(qCtrl);
        AssertAllZero([qCtrl] + qs);
    }
}
