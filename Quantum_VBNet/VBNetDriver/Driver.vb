' Namespace in which quantum simulator resides
Imports Microsoft.Quantum.Simulation.Simulators
' Namespace in which QArray resides
Imports Microsoft.Quantum.Simulation.Core

Module VBNetDriver
    Sub Main(args As String())
        Console.WriteLine("Hello Classical World!")

        ' Create a full-state simulator
        Using simulator As QuantumSimulator = New QuantumSimulator

            ' Construct the parameter: the bit vector used to initialize the oracle
            ' QArray is a data type for fixed-length arrays
            Dim bits As New QArray(Of Long)({0, 1, 1, 0, 1})
            Console.WriteLine(bits)

            ' Run the quantum algorithm
            Dim ret As QArray(Of Long)
            ret = QuantumCode.RunAlgorithm.Run(simulator, bits).Result
            Console.WriteLine(ret)

            ' Process the results: in this case, verify that:
            ' - the length of the return array equals the length of the input array
            Debug.Assert(ret.Length = bits.Length, "Return array length differs from the input array length")
            ' - each element of the array is 0 or 1
            Debug.Assert(ret.Where(Function(n) (n <> 1 And n <> 0)).Count = 0, "Each element of the return array must be 0 or 1")
            ' - the parity of the returned array matches the parity of the input one
            Debug.Assert(ret.Sum Mod 2 = bits.Sum Mod 2, "Return array should have the same parity as the input one")

        End Using

    End Sub
End Module
