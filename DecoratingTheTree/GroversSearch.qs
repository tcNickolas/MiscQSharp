namespace Quantum.DecoratingTheTree
{
    open Microsoft.Quantum.Primitive;
    open Microsoft.Quantum.Canon;

    operation OracleConverterImpl (markingOracle : ((Qubit[], Qubit) => Unit : Adjoint), register : Qubit[]) : Unit {
        body (...) {
            using (target = Qubit()) {
                // Put the target into the |-⟩ state
                X(target);
                H(target);
                
                // Apply the marking oracle; since the target is in the |-⟩ state,
                // flipping the target if the register satisfies the oracle condition will apply a -1 factor to the state
                markingOracle(register, target);
                
                // Put the target back into |0⟩ so we can return it
                H(target);
                X(target);
            }
        }
        adjoint invert;
    }
    
    function OracleConverter (markingOracle : ((Qubit[], Qubit) => Unit : Adjoint)) : (Qubit[] => Unit : Adjoint) {
        return OracleConverterImpl(markingOracle, _);
    }

    operation GroversSearch_Loop (register : Qubit[], oracle : ((Qubit[], Qubit) => Unit : Adjoint), iterations : Int) : Unit {
        let phaseOracle = OracleConverter(oracle);
        ApplyToEach(H, register);
            
        for (i in 1 .. iterations) {
            phaseOracle(register);
            ApplyToEach(H, register);
            ApplyToEach(X, register);
            Controlled Z(Most(register), Tail(register));
            ApplyToEach(X, register);
            ApplyToEach(H, register);
        }
    }

    operation GroversSearch_Main () : Bool[] {
        let n = 9;  // number of qubits
        let oracle = Oracle_IsValidTreeDecoration;
        let iter = 6;
        mutable answer = new Bool[n];
        using ((register, output) = (Qubit[n], Qubit())) {
            mutable correct = false;
            repeat {
                GroversSearch_Loop(register, oracle, iter);
                let res = MultiM(register);
                // to check whether the result is correct, apply the oracle to the register plus ancilla after measurement
                oracle(register, output);
                if (MResetZ(output) == One) {
                    set correct = true;
                    set answer = BoolArrFromResultArr(res);
                }
                ResetAll(register);
            } until (correct) 
            fixup {
            }
        }
        return answer;
    }
}
