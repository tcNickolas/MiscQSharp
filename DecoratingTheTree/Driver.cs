using System;

using Microsoft.Quantum.Simulation.Simulators;

namespace Quantum.DecoratingTheTree
{
    class Driver
    {
        static void Main(string[] args)
        {
            using (var qsim = new QuantumSimulator())
            {
                var result = GroversSearch_Main.Run(qsim).Result.ToArray();
                // Convert the result into a tree decoration instruction
                for (int i = 0; i < 3; ++i) {
                    for (int j = 0; j < 2 - i; ++j) 
                        Console.Write(" ");
                    for (int j = i*i; j < (i+1)*(i+1); j++)
                        Console.Write(result[j] ? "0" : "X");
                    Console.WriteLine();
                }
                Console.WriteLine("  |");

                Console.WriteLine("Press any key to continue...");
                Console.ReadKey();
            }
        }
    }
}