open System.Diagnostics
// Namespace in which quantum simulator resides
open Microsoft.Quantum.Simulation.Simulators
// Namespace in which QArray resides
open Microsoft.Quantum.Simulation.Core

[<EntryPoint>]
let main argv =
    printfn "Hello Classical World!"
    // Create a full-state simulator
    use simulator = new QuantumSimulator()
    // Construct the parameter
    // QArray is a data type for fixed-length arrays
    let bits = new QArray<int64>([| 0L; 1L; 1L |])
    printfn "%A" bits
    
    // Run the quantum algorithm
    let ret = QuantumCode.RunAlgorithm.Run(simulator, bits).Result
    printfn "%A" ret

    // Process the results: in this case, verify that:
    // - the length of the return array equals the length of the input array
    Debug.Assert(ret.Length = bits.Length, "Return array length differs from the input array length")
    // - each element of the array is 0 or 1
    Debug.Assert(ret |> Seq.filter (fun (x:int64) -> x <> 0L && x <> 1L) |> Seq.length = 0, "Each element of the return array must be 0 or 1")
    // - the parity of the returned array matches the parity of the input one
    Debug.Assert((ret |> Seq.sum) % 2L = (bits |> Seq.sum) % 2L, "Return array should have the same parity as the input one")

    0 // return an integer exit code
