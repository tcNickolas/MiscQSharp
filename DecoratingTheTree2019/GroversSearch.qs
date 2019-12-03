namespace Quantum.DecoratingTheTree
{
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Canon;

    operation OracleConverterImpl (markingOracle : ((Qubit[], Qubit) => Unit is Adj), register : Qubit[]) : Unit is Adj {
        using (target = Qubit()) {
            within {
                // Put the target into the |-⟩ state
                X(target);
                H(target);
            } apply {
                // Apply the marking oracle; since the target is in the |-⟩ state,
                // flipping the target if the register satisfies the oracle condition will apply a -1 factor to the state
                markingOracle(register, target);
            }
        }
    }
    
    operation GroversSearch_Loop (register : Qubit[], oracle : ((Qubit[], Qubit) => Unit is Adj), iterations : Int) : Unit {
        let phaseOracle = OracleConverterImpl(oracle, _);
        ApplyToEach(H, register);
            
        for (i in 1 .. iterations) {
            phaseOracle(register);
            within {
                ApplyToEachA(H, register);
                ApplyToEachA(X, register);
            } apply {
                Controlled Z(Most(register), Tail(register));
            }
        }
    }

    operation GroversSearch_Main (nLayers : Int) : Bool[] {
        let nBranches = nLayers ^ 2;   // number of branches in the tree
        let oracle = Oracle_IsValidTreeDecoration(nLayers, _, _);

        let searchSpaceSize = 2 ^ (nLayers ^ 2);
        mutable solutionsNumber = 1;
        for (layerInd in 2 .. nLayers) {
            set solutionsNumber *= 2 * layerInd - 2;
        }
        let iter = Round(PI() / 4.0 * Sqrt(IntAsDouble(searchSpaceSize) / IntAsDouble(solutionsNumber)));

        mutable answer = new Bool[nBranches];
        using ((register, output) = (Qubit[nBranches], Qubit())) {
            mutable correct = false;
            repeat {
                GroversSearch_Loop(register, oracle, iter);
                let res = MultiM(register);
                // check whether the result is correct
                oracle(register, output);
                if (MResetZ(output) == One) {
                    set correct = true;
                    set answer = ResultArrayAsBoolArray(res);
                }
                ResetAll(register);
            } until (correct);
        }
        return answer;
    }
}
