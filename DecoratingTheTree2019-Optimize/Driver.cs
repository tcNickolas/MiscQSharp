using System;
using System.Diagnostics;
using Microsoft.Quantum.Extensions.Oracles;
using Microsoft.Quantum.Simulation.Simulators;

namespace Quantum.DecoratingTheTree
{
    class Driver
    {
        static int DecorationsCheck(long nLayers, long x) {
            // Implement the same logic as the quantum oracle, but classically.
            // x uses little-endian notation: the least-significant bit of x corresponds to the first bit of the tree (top branch).

            // unroll x into bits
            bool[][] branches = new bool[nLayers][];
            for (int layerInd = 0; layerInd < nLayers; ++layerInd) {
                branches[layerInd] = new bool[2 * layerInd + 1];
                for (int branchInd = 0; branchInd < 2 * layerInd + 1; ++branchInd) {
                    branches[layerInd][branchInd] = (x % 2 == 1);
                    x /= 2;
                }
            }

            // "exactly 1 ornament per layer"
            foreach (bool[] layer in branches) {
                int nOrnaments = 0;
                foreach (bool branch in layer) {
                    if (branch)
                        nOrnaments++;
                }
                if (nOrnaments != 1)
                    return 0;
            }

            // "no ornaments vertically adjacent to each other"
            for (int layerInd = 0; layerInd < nLayers - 1; ++layerInd) {
                for (int branchInd = 0; branchInd < 2 * layerInd + 1; ++branchInd) {
                    if (branches[layerInd][branchInd] && branches[layerInd + 1][branchInd + 1]) {
                        return 0;
                    }
                }
            }

            return 1;
        }

        static void Main(string[] args)
        {
            int nLayers = 4;
            bool emulate = true;

            Stopwatch stopWatch = new Stopwatch();
            stopWatch.Start();
            using QuantumSimulator qsim = new QuantumSimulator();

            // define EmulatedOracle (operation declared in Q# code without a body implementation) as an emulation described by DecorationsCheck
            EmulatedOracleFactory.Register<EmulatedOracle>(qsim, (n, x, y) => DecorationsCheck(n, x) ^ y);

            bool[] result = GroversSearch_Main.Run(qsim, nLayers, emulate).Result.ToArray();

            stopWatch.Stop();
            // Get the elapsed time as a TimeSpan value.
            TimeSpan ts = stopWatch.Elapsed;

            // Format and display the TimeSpan value.
            string elapsedTime = String.Format("{0:00}:{1:00}:{2:00}.{3:00}",
                ts.Hours, ts.Minutes, ts.Seconds,
                ts.Milliseconds / 10);
            Console.WriteLine("RunTime " + elapsedTime);

            // Convert the result into a tree decoration instruction
            for (int i = 0; i < nLayers; ++i)
            {
                for (int j = 0; j < nLayers - i; ++j)
                    Console.Write(" ");
                for (int j = i * i; j < (i + 1) * (i + 1); j++)
                    Console.Write(result[j] ? "0" : "X");
                Console.WriteLine();
            }
            for (int j = 0; j < nLayers; ++j)
                Console.Write(" ");
            Console.WriteLine("|");

            Console.WriteLine("Press any key to continue...");
            Console.ReadKey();
        }
    }
}