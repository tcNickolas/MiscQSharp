using System;

using Microsoft.Quantum.Simulation.Simulators;

namespace Quantum.DecoratingTheTree
{
    class Driver
    {
        static void Main(string[] args)
        {
            int nLayers = 3;
            using QuantumSimulator qsim = new QuantumSimulator();
            bool[] result = GroversSearch_Main.Run(qsim, nLayers).Result.ToArray();

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